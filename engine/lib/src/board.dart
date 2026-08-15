import 'puzzle.dart';
import 'rules.dart';

/// What the player has put in a cell.
enum CellMark {
  /// Untouched.
  empty,

  /// "I know a mine cannot go here" (the X marker).
  blocked,

  /// A placed mine.
  mine,
}

/// Mutable play state for one [Puzzle]: the player's marks, undo history and
/// derived validity information.
///
/// This class is deliberately free of Flutter imports so the rules can be
/// unit-tested without a widget tree. The app wraps it in a `ChangeNotifier`.
class GameBoard {
  GameBoard(this.puzzle, {this.autoBlock = true})
      : _marks = List<CellMark>.filled(
          puzzle.size * puzzle.size,
          CellMark.empty,
        );

  final Puzzle puzzle;

  /// When true, placing a mine also X's out every cell the rules now forbid.
  /// This is the quality-of-life behaviour these puzzle games normally ship
  /// with; turning it off gives a stricter, more manual experience.
  bool autoBlock;

  final List<CellMark> _marks;
  final List<List<CellMark>> _undo = [];
  final List<List<CellMark>> _redo = [];

  int get size => puzzle.size;

  /// Read-only view of every cell's mark, row-major.
  List<CellMark> get marks => List.unmodifiable(_marks);

  CellMark markAt(int index) => _marks[index];

  CellMark markAtCell(int row, int col) => _marks[row * size + col];

  int get minesPlaced => _marks.where((m) => m == CellMark.mine).length;

  int get minesRemaining => size - minesPlaced;

  bool get canUndo => _undo.isNotEmpty;

  bool get canRedo => _redo.isNotEmpty;

  /// Cell indices currently holding a mine.
  List<int> get mineCells {
    final cells = <int>[];
    for (var i = 0; i < _marks.length; i++) {
      if (_marks[i] == CellMark.mine) cells.add(i);
    }
    return cells;
  }

  /// Every rule the current placement breaks.
  List<RuleViolation> get violations =>
      MinedokuRules.violations(size, puzzle.regions, mineCells);

  /// Cells that should be drawn as "in conflict".
  Set<int> get conflictCells {
    final cells = <int>{};
    for (final v in violations) {
      cells..add(v.a)..add(v.b);
    }
    return cells;
  }

  /// True once every rule is satisfied and all mines are placed.
  ///
  /// With no two mines sharing a row, column or region and exactly [size] of
  /// them on the board, each row, column and region necessarily holds exactly
  /// one, so this check is complete.
  bool get isSolved => minesPlaced == size && violations.isEmpty;

  /// Placed mines that are not part of the intended solution.
  List<int> get misplacedMines {
    final answer = puzzle.solutionCells;
    return [for (final cell in mineCells) if (!answer.contains(cell)) cell];
  }

  /// Advances a cell: empty -> blocked -> mine -> empty.
  void cycle(int index) {
    final next = switch (_marks[index]) {
      CellMark.empty => CellMark.blocked,
      CellMark.blocked => CellMark.mine,
      CellMark.mine => CellMark.empty,
    };
    setMark(index, next);
  }

  /// Sets a single cell, recording an undo point.
  void setMark(int index, CellMark mark) {
    if (_marks[index] == mark) return;
    _pushUndo();
    _marks[index] = mark;
    if (mark == CellMark.mine && autoBlock) {
      _applyAutoBlock(index);
    }
    _redo.clear();
  }

  /// X's out every cell that the mine at [index] rules out and that the player
  /// has not already decided on.
  void _applyAutoBlock(int index) {
    final row = index ~/ size;
    final col = index % size;
    final region = puzzle.regions[index];
    for (var i = 0; i < _marks.length; i++) {
      if (i == index || _marks[i] != CellMark.empty) continue;
      final sameRow = i ~/ size == row;
      final sameColumn = i % size == col;
      final sameRegion = puzzle.regions[i] == region;
      final touches = MinedokuRules.touching(size, i, index);
      if (sameRow || sameColumn || sameRegion || touches) {
        _marks[i] = CellMark.blocked;
      }
    }
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(List<CellMark>.from(_marks));
    _restore(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(List<CellMark>.from(_marks));
    _restore(_redo.removeLast());
  }

  /// Wipes the board back to empty (undoable).
  void clear() {
    if (_marks.every((m) => m == CellMark.empty)) return;
    _pushUndo();
    for (var i = 0; i < _marks.length; i++) {
      _marks[i] = CellMark.empty;
    }
    _redo.clear();
  }

  void _pushUndo() {
    _undo.add(List<CellMark>.from(_marks));
    // Small boards, but there is no reason to grow without bound.
    if (_undo.length > 500) _undo.removeAt(0);
  }

  void _restore(List<CellMark> snapshot) {
    for (var i = 0; i < _marks.length; i++) {
      _marks[i] = snapshot[i];
    }
  }

  /// Compact string of the player's marks, for saving a game in progress.
  String encodeMarks() => _marks
      .map((m) => switch (m) {
            CellMark.empty => '.',
            CellMark.blocked => 'x',
            CellMark.mine => 'm',
          })
      .join();

  /// Restores marks saved by [encodeMarks]. Unknown or wrong-length input is
  /// ignored so a corrupt save can never crash the app.
  void restoreMarks(String encoded) {
    if (encoded.length != _marks.length) return;
    _undo.clear();
    _redo.clear();
    for (var i = 0; i < encoded.length; i++) {
      _marks[i] = switch (encoded[i]) {
        'x' => CellMark.blocked,
        'm' => CellMark.mine,
        _ => CellMark.empty,
      };
    }
  }
}
