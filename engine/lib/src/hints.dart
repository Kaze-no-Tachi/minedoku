import 'board.dart';
import 'solver.dart';

/// What a hint is telling the player to do.
enum HintKind {
  /// Nothing left to do.
  solved,

  /// A placed mine cannot be part of any solution.
  removeMine,

  /// A cell is the only remaining option for its row, column or colour.
  forcedMine,

  /// A cell looks available but can be ruled out.
  ruledOut,

  /// No short explanation was found, so a correct cell is simply shown.
  reveal,
}

/// A single suggestion, ready to display and highlight.
class Hint {
  const Hint(
    this.kind, {
    this.cell,
    this.relatedCells = const [],
    required this.message,
  });

  final HintKind kind;

  /// Cell the UI should highlight, if any.
  final int? cell;

  /// The row, column or colour the explanation is talking about.
  ///
  /// Highlighting these alongside the message is what makes a hint teach
  /// something. "This colour has no room left" is vague on its own and obvious
  /// once the colour in question is lit up.
  final List<int> relatedCells;

  /// Player-facing explanation.
  final String message;

  @override
  String toString() => '$kind${cell == null ? '' : ' @$cell'}: $message';
}

/// A row, column or colour, and the cells that make it up.
class _Unit {
  const _Unit(this.label, this.cells);

  /// Reads naturally mid-sentence, for example "row 4" or "this colour".
  final String label;
  final List<int> cells;
}

/// Produces the easiest useful next step for a board.
///
/// Hints are tiered, most instructive first: fix a wrong mine, then a forced
/// placement, then a cell that can be eliminated, and only as a last resort an
/// unexplained reveal. Every tier states the reason, and names the row, column
/// or colour the reason rests on so the UI can show it.
class HintEngine {
  const HintEngine();

  Hint next(GameBoard board) {
    if (board.isSolved) {
      return const Hint(HintKind.solved, message: 'This board is already done.');
    }

    final wrong = board.misplacedMines;
    if (wrong.isNotEmpty) {
      return _wrongMineHint(board, wrong.first);
    }

    final size = board.size;
    final candidates = _candidates(board, board.mineCells);

    final forced = _forcedPlacement(board, candidates);
    if (forced != null) return forced;

    final solver = Solver(size, board.puzzle.regions);
    final fixed = _fixedRows(board);
    for (final cell in candidates) {
      // No point repeating something the player has already worked out.
      if (board.markAt(cell) == CellMark.blocked) continue;
      if (board.puzzle.solutionCells.contains(cell)) continue;

      final trial = List<int?>.from(fixed);
      trial[cell ~/ size] = cell % size;
      if (solver.countSolutions(limit: 1, fixed: trial) == 0) {
        return _ruledOutHint(board, cell);
      }
    }

    for (final cell in board.puzzle.solutionCells) {
      if (board.markAt(cell) != CellMark.mine) {
        return Hint(
          HintKind.reveal,
          cell: cell,
          message: 'Working this one out takes a longer chain of steps than a '
              'hint can spell out. A mine belongs here.',
        );
      }
    }

    return const Hint(HintKind.solved, message: 'This board is already done.');
  }

  /// Explains why a placed mine cannot be right.
  ///
  /// Usually some row, column or colour has been left with nowhere to go, and
  /// naming it is far more useful than "this is wrong".
  Hint _wrongMineHint(GameBoard board, int cell) {
    final starved = _starvedUnit(board, board.mineCells);
    if (starved != null) {
      return Hint(
        HintKind.removeMine,
        cell: cell,
        relatedCells: starved.cells,
        message: 'With the mines as they are, ${starved.label} has no cell '
            'left that a mine could go in. This one is the mistake, so take '
            'it off.',
      );
    }
    return Hint(
      HintKind.removeMine,
      cell: cell,
      message: 'No arrangement of the remaining mines works while this one is '
          'here, so it cannot be right. Take it off.',
    );
  }

  /// Explains why a cell can be crossed out.
  Hint _ruledOutHint(GameBoard board, int cell) {
    final starved = _starvedUnit(board, [...board.mineCells, cell]);
    if (starved != null) {
      return Hint(
        HintKind.ruledOut,
        cell: cell,
        relatedCells: starved.cells,
        message: 'A mine here would rule out every remaining cell of '
            '${starved.label}, leaving it nowhere to go. Mark this one with '
            'an X.',
      );
    }
    return Hint(
      HintKind.ruledOut,
      cell: cell,
      message: 'A mine here leaves the rest of the board impossible to '
          'finish, though it takes a few steps to see. Mark it with an X.',
    );
  }

  /// The first row, column or colour with no legal cell left, given [mines].
  ///
  /// Colours are checked first: highlighting one is the easiest thing to take
  /// in at a glance.
  _Unit? _starvedUnit(GameBoard board, List<int> mines) {
    final size = board.size;
    final candidates = _candidates(board, mines);

    final usedRows = <int>{};
    final usedColumns = <int>{};
    final usedRegions = <int>{};
    for (final mine in mines) {
      usedRows.add(mine ~/ size);
      usedColumns.add(mine % size);
      usedRegions.add(board.puzzle.regions[mine]);
    }

    for (var region = 0; region < size; region++) {
      if (usedRegions.contains(region)) continue;
      if (candidates.any((c) => board.puzzle.regions[c] == region)) continue;
      return _Unit('this colour', board.puzzle.cellsOfRegion(region));
    }
    for (var row = 0; row < size; row++) {
      if (usedRows.contains(row)) continue;
      if (candidates.any((c) => c ~/ size == row)) continue;
      return _Unit(
        'row ${row + 1}',
        [for (var c = 0; c < size; c++) row * size + c],
      );
    }
    for (var col = 0; col < size; col++) {
      if (usedColumns.contains(col)) continue;
      if (candidates.any((c) => c % size == col)) continue;
      return _Unit(
        'column ${col + 1}',
        [for (var r = 0; r < size; r++) r * size + col],
      );
    }
    return null;
  }

  /// Cells that are still legal given [mines].
  ///
  /// The player's own X marks are ignored on purpose: a hint should reason from
  /// the rules, not from guesses the player may have got wrong.
  Set<int> _candidates(GameBoard board, List<int> mines) {
    final size = board.size;
    final usedRows = <int>{};
    final usedColumns = <int>{};
    final usedRegions = <int>{};
    for (final cell in mines) {
      usedRows.add(cell ~/ size);
      usedColumns.add(cell % size);
      usedRegions.add(board.puzzle.regions[cell]);
    }

    final result = <int>{};
    for (var cell = 0; cell < size * size; cell++) {
      if (mines.contains(cell)) continue;
      if (usedRows.contains(cell ~/ size)) continue;
      if (usedColumns.contains(cell % size)) continue;
      if (usedRegions.contains(board.puzzle.regions[cell])) continue;
      final row = cell ~/ size;
      final col = cell % size;
      final touchesMine = mines.any((m) =>
          ((m ~/ size) - row).abs() <= 1 && ((m % size) - col).abs() <= 1);
      if (touchesMine) continue;
      result.add(cell);
    }
    return result;
  }

  /// A row, column or colour with exactly one legal cell left.
  Hint? _forcedPlacement(GameBoard board, Set<int> candidates) {
    final size = board.size;
    final byRow = <int, List<int>>{};
    final byColumn = <int, List<int>>{};
    final byRegion = <int, List<int>>{};
    for (final cell in candidates) {
      byRow.putIfAbsent(cell ~/ size, () => []).add(cell);
      byColumn.putIfAbsent(cell % size, () => []).add(cell);
      byRegion.putIfAbsent(board.puzzle.regions[cell], () => []).add(cell);
    }

    // Colours first: they are the most satisfying deduction to be shown.
    for (final entry in byRegion.entries) {
      if (entry.value.length == 1) {
        final cells = board.puzzle.cellsOfRegion(entry.key);
        return Hint(
          HintKind.forcedMine,
          cell: entry.value.single,
          relatedCells: cells,
          // A one-cell colour is forced from the start, with nothing eliminated
          // yet, so claiming mines ruled the others out would be untrue.
          message: cells.length == 1
              ? 'This colour is a single cell. Every colour needs a mine, so '
                  'this one has no choice about where it goes.'
              : 'Every other cell of this colour is ruled out by the mines '
                  'already placed, so this is the only spot its mine can take.',
        );
      }
    }
    for (final entry in byRow.entries) {
      if (entry.value.length == 1) {
        return Hint(
          HintKind.forcedMine,
          cell: entry.value.single,
          relatedCells: [
            for (var c = 0; c < size; c++) entry.key * size + c,
          ],
          message: 'Every other cell in row ${entry.key + 1} is already ruled '
              'out, so this row\'s mine has nowhere else to go.',
        );
      }
    }
    for (final entry in byColumn.entries) {
      if (entry.value.length == 1) {
        return Hint(
          HintKind.forcedMine,
          cell: entry.value.single,
          relatedCells: [
            for (var r = 0; r < size; r++) r * size + entry.key,
          ],
          message: 'Every other cell in column ${entry.key + 1} is already '
              'ruled out, so this column\'s mine has nowhere else to go.',
        );
      }
    }
    return null;
  }

  /// Placed mines expressed as the solver's per-row constraint list.
  List<int?> _fixedRows(GameBoard board) {
    final fixed = List<int?>.filled(board.size, null);
    for (final cell in board.mineCells) {
      fixed[cell ~/ board.size] = cell % board.size;
    }
    return fixed;
  }
}
