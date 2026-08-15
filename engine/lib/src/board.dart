import 'puzzle.dart';
import 'rules.dart';

/// What the player has put in a cell.
enum CellMark {
  /// Untouched.
  empty,

  /// "I know a mine cannot go here" (the X marker).
  blocked,

  /// "I suspect this one, but I have not committed" (the question mark).
  ///
  /// Purely a note to the player. It never constrains anything and is not a
  /// mine, so it costs nothing to leave one behind.
  maybe,

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

  /// Cells X'd out by [autoBlock] rather than by the player. Tracking who put
  /// a mark there is what lets an automatic one be withdrawn later.
  final Set<int> _autoBlocked = {};

  final List<_Snapshot> _undo = [];
  final List<_Snapshot> _redo = [];

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

  /// Advances a cell through the note-taking marks: empty, ruled out, unsure,
  /// and back to empty.
  ///
  /// Mines are deliberately not in this cycle. Putting one in meant the only
  /// way out of an X was through "mine", and in hard mode that step costs a
  /// life, so taking back your own mark could not be done without being
  /// punished for it. Committing a mine is its own gesture now.
  void cycle(int index) {
    final next = switch (_marks[index]) {
      CellMark.empty => CellMark.blocked,
      CellMark.blocked => CellMark.maybe,
      CellMark.maybe => CellMark.empty,
      CellMark.mine => CellMark.empty,
    };
    setMark(index, next);
  }

  /// Sets a single cell, recording an undo point.
  void setMark(int index, CellMark mark) {
    if (_marks[index] == mark) return;
    _pushUndo();
    _marks[index] = mark;
    // The player has taken explicit control of this cell, so it is no longer
    // something auto-marking may take back.
    _autoBlocked.remove(index);
    _refreshAutoBlocks();
    _redo.clear();
  }

  /// Rebuilds every auto-placed X from the mines currently on the board.
  ///
  /// Auto-marks are derived, never accumulated: they are all withdrawn and then
  /// worked out again from scratch. That is what makes removing a mine tidy up
  /// after itself instead of leaving its X's stranded on the board. Marks the
  /// player made by hand are untouched, and switching [autoBlock] off withdraws
  /// the automatic ones without disturbing them either.
  void _refreshAutoBlocks() {
    for (final cell in _autoBlocked) {
      if (_marks[cell] == CellMark.blocked) _marks[cell] = CellMark.empty;
    }
    _autoBlocked.clear();
    if (!autoBlock) return;

    for (final mine in mineCells) {
      final row = mine ~/ size;
      final col = mine % size;
      final region = puzzle.regions[mine];
      for (var i = 0; i < _marks.length; i++) {
        if (i == mine || _marks[i] != CellMark.empty) continue;
        final sameRow = i ~/ size == row;
        final sameColumn = i % size == col;
        final sameRegion = puzzle.regions[i] == region;
        final touches = MinedokuRules.touching(size, i, mine);
        if (sameRow || sameColumn || sameRegion || touches) {
          _marks[i] = CellMark.blocked;
          _autoBlocked.add(i);
        }
      }
    }
  }

  void undo() {
    if (_undo.isEmpty) return;
    _redo.add(_snapshot());
    _restore(_undo.removeLast());
  }

  void redo() {
    if (_redo.isEmpty) return;
    _undo.add(_snapshot());
    _restore(_redo.removeLast());
  }

  /// Wipes the board back to empty (undoable).
  void clear() {
    if (_marks.every((m) => m == CellMark.empty)) return;
    _pushUndo();
    for (var i = 0; i < _marks.length; i++) {
      _marks[i] = CellMark.empty;
    }
    _autoBlocked.clear();
    _redo.clear();
  }

  _Snapshot _snapshot() => _Snapshot(
        List<CellMark>.from(_marks),
        Set<int>.from(_autoBlocked),
      );

  void _pushUndo() {
    _undo.add(_snapshot());
    // Small boards, but there is no reason to grow without bound.
    if (_undo.length > 500) _undo.removeAt(0);
  }

  void _restore(_Snapshot snapshot) {
    for (var i = 0; i < _marks.length; i++) {
      _marks[i] = snapshot.marks[i];
    }
    _autoBlocked
      ..clear()
      ..addAll(snapshot.autoBlocked);
  }

  /// Compact string of the player's marks, for saving a game in progress.
  String encodeMarks() => _marks
      .map((m) => switch (m) {
            CellMark.empty => '.',
            CellMark.blocked => 'x',
            CellMark.maybe => '?',
            CellMark.mine => 'm',
          })
      .join();

  /// Restores marks saved by [encodeMarks]. Unknown or wrong-length input is
  /// ignored so a corrupt save can never crash the app.
  void restoreMarks(String encoded) {
    if (encoded.length != _marks.length) return;
    _undo.clear();
    _redo.clear();
    _autoBlocked.clear();
    for (var i = 0; i < encoded.length; i++) {
      _marks[i] = switch (encoded[i]) {
        'x' => CellMark.blocked,
        '?' => CellMark.maybe,
        'm' => CellMark.mine,
        _ => CellMark.empty,
      };
    }
    // A save records marks but not who placed them. Any X that a mine on the
    // board already explains is treated as automatic, which is exactly what it
    // would be after a fresh placement, so removing that mine still clears it.
    if (autoBlock) {
      for (final mine in mineCells) {
        for (var i = 0; i < _marks.length; i++) {
          if (i == mine || _marks[i] != CellMark.blocked) continue;
          final sameRow = i ~/ size == mine ~/ size;
          final sameColumn = i % size == mine % size;
          final sameRegion = puzzle.regions[i] == puzzle.regions[mine];
          if (sameRow ||
              sameColumn ||
              sameRegion ||
              MinedokuRules.touching(size, i, mine)) {
            _autoBlocked.add(i);
          }
        }
      }
    }
  }
}

/// One point in the undo timeline: the marks plus which of them were placed
/// automatically.
class _Snapshot {
  const _Snapshot(this.marks, this.autoBlocked);

  final List<CellMark> marks;
  final Set<int> autoBlocked;
}
