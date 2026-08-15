import 'rules.dart';

/// An immutable, generated puzzle.
///
/// A puzzle is an `size x size` grid divided into exactly [size] coloured
/// regions. It has exactly one solution: a set of [size] mines obeying every
/// rule in [MinedokuRules].
class Puzzle {
  Puzzle({
    required this.size,
    required List<int> regions,
    required List<int> solution,
    this.seed = 0,
  })  : regions = List.unmodifiable(regions),
        solution = List.unmodifiable(solution) {
    if (this.regions.length != size * size) {
      throw ArgumentError('regions must hold size * size entries');
    }
    if (this.solution.length != size) {
      throw ArgumentError('solution must hold one column per row');
    }
  }

  /// Grid width and height, also the number of regions and of mines.
  final int size;

  /// Region id (`0 <= id < size`) for every cell, in row-major order.
  final List<int> regions;

  /// `solution[row]` is the column of that row's mine.
  final List<int> solution;

  /// Seed the puzzle was generated from. Useful for reproducing a board.
  final int seed;

  int index(int row, int col) => row * size + col;

  int regionAt(int row, int col) => regions[index(row, col)];

  /// Cell indices that make up region [id].
  List<int> cellsOfRegion(int id) {
    final cells = <int>[];
    for (var i = 0; i < regions.length; i++) {
      if (regions[i] == id) cells.add(i);
    }
    return cells;
  }

  /// True when the mine of [row] sits in [col] in the intended solution.
  bool isSolutionCell(int row, int col) => solution[row] == col;

  /// Cell indices of the solution's mines.
  Set<int> get solutionCells =>
      {for (var r = 0; r < size; r++) index(r, solution[r])};

  /// Compact text form, safe to store in preferences or a URL.
  ///
  /// Format: `v1:size:seed:regions:solution`, with regions and solution written
  /// as base-36 digits (one character per cell / per row).
  String encode() {
    final buffer = StringBuffer('v1:$size:$seed:');
    for (final r in regions) {
      buffer.write(r.toRadixString(36));
    }
    buffer.write(':');
    for (final c in solution) {
      buffer.write(c.toRadixString(36));
    }
    return buffer.toString();
  }

  /// Parses the output of [encode]. Throws [FormatException] on bad input.
  static Puzzle decode(String text) {
    final parts = text.split(':');
    if (parts.length != 5 || parts[0] != 'v1') {
      throw FormatException('Not a Minedoku puzzle string', text);
    }
    final size = int.parse(parts[1]);
    final seed = int.parse(parts[2]);
    if (parts[3].length != size * size || parts[4].length != size) {
      throw FormatException('Puzzle string has the wrong length', text);
    }
    final regions = [
      for (final ch in parts[3].split('')) int.parse(ch, radix: 36),
    ];
    final solution = [
      for (final ch in parts[4].split('')) int.parse(ch, radix: 36),
    ];
    return Puzzle(size: size, regions: regions, solution: solution, seed: seed);
  }

  @override
  String toString() => 'Puzzle(${size}x$size, seed: $seed)';
}
