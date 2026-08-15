import 'prng.dart';
import 'puzzle.dart';
import 'solver.dart';

/// Builds puzzles that are guaranteed to have exactly one solution.
///
/// The approach is "solution first":
///
/// 1. pick a random legal mine layout (that becomes the answer);
/// 2. seed one region on each mine and flood-fill the rest of the board,
///    using lopsided weights so region sizes come out uneven (even, blobby
///    regions constrain the player far too little);
/// 3. hill-climb: repeatedly move a single boundary cell into a neighbouring
///    region, keeping any change that does not increase the solution count,
///    until only one solution is left.
///
/// Step 3 is what makes larger boards practical. Pure generate-and-reject
/// succeeds often enough at 5x5 and 6x6 but collapses from 7x7 upward.
class PuzzleGenerator {
  const PuzzleGenerator();

  static const List<List<int>> _orthogonal = [
    [1, 0],
    [-1, 0],
    [0, 1],
    [0, -1],
  ];

  /// Generates the puzzle for [seed] at the given [size].
  ///
  /// The same (size, seed) pair always yields the same board on every platform,
  /// so a level number is all that needs to be stored or shared.
  ///
  /// Throws [StateError] if no puzzle could be produced within [maxAttempts],
  /// which does not happen for the sizes the app ships (4 to 9).
  Puzzle generate({required int size, required int seed, int maxAttempts = 60}) {
    if (size < 4) {
      throw ArgumentError.value(size, 'size', 'must be at least 4');
    }
    final random = Prng(seed * 2654435761 + size);

    for (var attempt = 0; attempt < maxAttempts; attempt++) {
      final solution = _randomSolution(size, random);
      if (solution == null) {
        throw StateError('No legal mine layout exists for size $size');
      }
      final regions = _growRegions(size, solution, random);
      if (regions == null) continue;
      if (_repairToUnique(size, regions, solution, random)) {
        return Puzzle(
          size: size,
          regions: regions,
          solution: solution,
          seed: seed,
        );
      }
    }
    throw StateError('Could not generate a ${size}x$size puzzle for seed $seed');
  }

  /// A random legal set of mines: one per row and column, never touching.
  List<int>? _randomSolution(int size, Prng random) {
    final columns = List<int>.filled(size, -1);
    final used = List<bool>.filled(size, false);

    bool place(int row, int previous) {
      if (row == size) return true;
      final order = List<int>.generate(size, (i) => i);
      random.shuffle(order);
      for (final col in order) {
        if (used[col]) continue;
        if (previous >= 0 && (col - previous).abs() < 2) continue;
        used[col] = true;
        columns[row] = col;
        if (place(row + 1, col)) return true;
        used[col] = false;
      }
      return false;
    }

    return place(0, -1) ? columns : null;
  }

  /// Flood-fills the board outward from the solution cells.
  ///
  /// Each region gets a cubed random weight, which produces a few large regions
  /// and several small ones. Small regions are the backbone of a good puzzle:
  /// a two-cell colour immediately pins down part of the answer.
  List<int>? _growRegions(int size, List<int> solution, Prng random) {
    final regions = List<int>.filled(size * size, -1);
    final frontiers = List.generate(size, (_) => <int>[]);
    final weights = List<double>.generate(size, (_) {
      final r = random.nextDouble();
      return r * r * r + 0.02;
    });

    for (var row = 0; row < size; row++) {
      regions[row * size + solution[row]] = row;
    }
    for (var row = 0; row < size; row++) {
      _pushOpenNeighbours(size, regions, frontiers[row], row * size + solution[row]);
    }

    var remaining = size * size - size;
    var guard = size * size * 64;
    while (remaining > 0) {
      if (guard-- <= 0) return null;
      final live = <int>[];
      for (var i = 0; i < size; i++) {
        if (frontiers[i].isNotEmpty) live.add(i);
      }
      if (live.isEmpty) return null;

      final choice = live[random.pickWeighted([for (final i in live) weights[i]])];
      final frontier = frontiers[choice];
      final pick = random.nextInt(frontier.length);
      final cell = frontier[pick];
      frontier[pick] = frontier.last;
      frontier.removeLast();
      if (regions[cell] != -1) continue;

      regions[cell] = choice;
      remaining--;
      _pushOpenNeighbours(size, regions, frontier, cell);
    }
    return regions;
  }

  void _pushOpenNeighbours(int size, List<int> regions, List<int> frontier, int cell) {
    final row = cell ~/ size;
    final col = cell % size;
    for (final step in _orthogonal) {
      final r = row + step[0];
      final c = col + step[1];
      if (r < 0 || r >= size || c < 0 || c >= size) continue;
      final next = r * size + c;
      if (regions[next] == -1) frontier.add(next);
    }
  }

  /// Nudges region borders until the board has a single solution.
  ///
  /// Returns true on success. [regions] is modified in place.
  bool _repairToUnique(
    int size,
    List<int> regions,
    List<int> solution,
    Prng random, {
    int solutionCap = 60,
    int maxIterations = 4000,
  }) {
    final solver = Solver(size, regions);
    final seeds = <int>{
      for (var row = 0; row < size; row++) row * size + solution[row],
    };
    var score = solver.countSolutions(limit: solutionCap);

    for (var i = 0; i < maxIterations && score != 1; i++) {
      final cell = random.nextInt(size * size);
      if (seeds.contains(cell)) continue;

      final from = regions[cell];
      final candidates = _adjacentRegions(size, regions, cell, from);
      if (candidates.isEmpty) continue;
      if (!_staysConnectedWithout(size, regions, from, cell)) continue;

      final to = candidates[random.nextInt(candidates.length)];
      regions[cell] = to;
      final next = solver.countSolutions(limit: solutionCap);
      // The intended solution must survive, so never drop to zero. Accepting
      // equal scores lets the search slide along plateaus instead of stalling.
      if (next >= 1 && next <= score) {
        score = next;
      } else {
        regions[cell] = from;
      }
    }
    return score == 1;
  }

  List<int> _adjacentRegions(int size, List<int> regions, int cell, int exclude) {
    final row = cell ~/ size;
    final col = cell % size;
    final found = <int>{};
    for (final step in _orthogonal) {
      final r = row + step[0];
      final c = col + step[1];
      if (r < 0 || r >= size || c < 0 || c >= size) continue;
      final id = regions[r * size + c];
      if (id != exclude) found.add(id);
    }
    return found.toList()..sort();
  }

  /// True when region [id] is still one connected blob after [drop] leaves it.
  bool _staysConnectedWithout(int size, List<int> regions, int id, int drop) {
    final members = <int>[];
    for (var i = 0; i < regions.length; i++) {
      if (regions[i] == id && i != drop) members.add(i);
    }
    if (members.isEmpty) return false;

    final seen = <int>{members.first};
    final stack = <int>[members.first];
    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      final row = cell ~/ size;
      final col = cell % size;
      for (final step in _orthogonal) {
        final r = row + step[0];
        final c = col + step[1];
        if (r < 0 || r >= size || c < 0 || c >= size) continue;
        final next = r * size + c;
        if (next == drop || regions[next] != id || seen.contains(next)) continue;
        seen.add(next);
        stack.add(next);
      }
    }
    return seen.length == members.length;
  }
}
