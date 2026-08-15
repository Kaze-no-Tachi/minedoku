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
  const Hint(this.kind, {this.cell, required this.message});

  final HintKind kind;

  /// Cell the UI should highlight, if any.
  final int? cell;

  /// Player-facing explanation.
  final String message;

  @override
  String toString() => '$kind${cell == null ? '' : ' @$cell'}: $message';
}

/// Produces the easiest useful next step for a board.
///
/// Hints are tiered, cheapest and most instructive first: fix a wrong mine,
/// then a forced placement with a one-line reason, then a cell that can be
/// eliminated, and only as a last resort an unexplained reveal.
class HintEngine {
  const HintEngine();

  Hint next(GameBoard board) {
    if (board.isSolved) {
      return const Hint(HintKind.solved, message: 'This board is already done.');
    }

    final wrong = board.misplacedMines;
    if (wrong.isNotEmpty) {
      final cell = wrong.first;
      return Hint(
        HintKind.removeMine,
        cell: cell,
        message: 'This mine cannot be right. Take it off and try elsewhere.',
      );
    }

    final size = board.size;
    final candidates = _candidates(board);

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
        return Hint(
          HintKind.ruledOut,
          cell: cell,
          message: 'No mine can go here. Mark it with an X.',
        );
      }
    }

    for (final cell in board.puzzle.solutionCells) {
      if (board.markAt(cell) != CellMark.mine) {
        return Hint(
          HintKind.reveal,
          cell: cell,
          message: 'A mine belongs here.',
        );
      }
    }

    return const Hint(HintKind.solved, message: 'This board is already done.');
  }

  /// Cells that are still legal given the mines already on the board.
  ///
  /// The player's own X marks are ignored on purpose: a hint should reason from
  /// the rules, not from guesses the player may have got wrong.
  Set<int> _candidates(GameBoard board) {
    final size = board.size;
    final mines = board.mineCells;
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
      if (board.markAt(cell) == CellMark.mine) continue;
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

  /// A row, column or region with exactly one legal cell left.
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
        return Hint(
          HintKind.forcedMine,
          cell: entry.value.single,
          message: 'This colour has only one cell left, so the mine goes here.',
        );
      }
    }
    for (final entry in byRow.entries) {
      if (entry.value.length == 1) {
        return Hint(
          HintKind.forcedMine,
          cell: entry.value.single,
          message: 'Row ${entry.key + 1} has only one cell left.',
        );
      }
    }
    for (final entry in byColumn.entries) {
      if (entry.value.length == 1) {
        return Hint(
          HintKind.forcedMine,
          cell: entry.value.single,
          message: 'Column ${entry.key + 1} has only one cell left.',
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
