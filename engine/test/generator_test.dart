import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:test/test.dart';

/// Independent rule check, written without reusing the solver, so a bug in the
/// solver cannot make a broken board look valid.
void expectLegalSolution(Puzzle puzzle) {
  final size = puzzle.size;
  final cells = [for (var r = 0; r < size; r++) r * size + puzzle.solution[r]];

  expect(cells.length, size, reason: 'one mine per row');
  expect(puzzle.solution.toSet().length, size, reason: 'columns are distinct');
  expect(
    {for (final c in cells) puzzle.regions[c]}.length,
    size,
    reason: 'regions are distinct',
  );
  for (var i = 0; i < cells.length; i++) {
    for (var j = i + 1; j < cells.length; j++) {
      final dr = (cells[i] ~/ size) - (cells[j] ~/ size);
      final dc = (cells[i] % size) - (cells[j] % size);
      expect(dr.abs() <= 1 && dc.abs() <= 1, isFalse,
          reason: 'mines must not touch');
    }
  }
}

/// Every region must be a single orthogonally-connected blob, or the board
/// looks broken to the player.
void expectConnectedRegions(Puzzle puzzle) {
  final size = puzzle.size;
  for (var id = 0; id < size; id++) {
    final members = puzzle.cellsOfRegion(id).toSet();
    expect(members, isNotEmpty, reason: 'region $id must exist');

    final seen = <int>{members.first};
    final stack = <int>[members.first];
    while (stack.isNotEmpty) {
      final cell = stack.removeLast();
      final row = cell ~/ size;
      final col = cell % size;
      for (final step in const [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
        final r = row + step[0];
        final c = col + step[1];
        if (r < 0 || r >= size || c < 0 || c >= size) continue;
        final next = r * size + c;
        if (members.contains(next) && seen.add(next)) stack.add(next);
      }
    }
    expect(seen.length, members.length, reason: 'region $id must be connected');
  }
}

void main() {
  const generator = PuzzleGenerator();

  group('generated puzzles', () {
    for (final size in [4, 5, 6, 7, 8, 9]) {
      test('${size}x$size boards are legal, connected and unique', () {
        for (var seed = 1; seed <= 12; seed++) {
          final puzzle = generator.generate(size: size, seed: seed);

          expect(puzzle.size, size);
          expect(puzzle.regions.length, size * size);
          expectLegalSolution(puzzle);
          expectConnectedRegions(puzzle);

          final solver = Solver(size, puzzle.regions);
          expect(
            solver.countSolutions(limit: 5),
            1,
            reason: '${size}x$size seed $seed must have exactly one solution',
          );
          expect(solver.solve(), puzzle.solution,
              reason: 'the solver must find the intended answer');
        }
      });
    }
  });

  test('every region contains at least one cell and ids cover 0..size-1', () {
    final puzzle = generator.generate(size: 8, seed: 99);
    expect(puzzle.regions.toSet(), {for (var i = 0; i < 8; i++) i});
  });

  test('generation is deterministic across runs', () {
    final a = generator.generate(size: 7, seed: 4242);
    final b = generator.generate(size: 7, seed: 4242);
    expect(a.regions, b.regions);
    expect(a.solution, b.solution);
  });

  test('different seeds give different boards', () {
    final boards = {
      for (var seed = 1; seed <= 20; seed++)
        generator.generate(size: 6, seed: seed).encode(),
    };
    expect(boards.length, greaterThan(15),
        reason: 'seeds should not collapse onto the same board');
  });

  test('rejects sizes below 4', () {
    expect(() => generator.generate(size: 3, seed: 1), throwsArgumentError);
  });

  test('generating a full campaign page stays fast', () {
    final watch = Stopwatch()..start();
    for (var level = 1; level <= 30; level++) {
      final spec = Levels.forLevel(level);
      generator.generate(size: spec.size, seed: spec.seed);
    }
    watch.stop();
    // Generous ceiling: this is a smoke test against pathological slowdowns,
    // not a benchmark. Real timings are far below this.
    expect(watch.elapsedMilliseconds, lessThan(20000),
        reason: 'took ${watch.elapsedMilliseconds}ms for 30 levels');
  });
}
