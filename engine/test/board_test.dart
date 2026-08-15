import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:test/test.dart';

/// A hand-built 4x4 board, so the expectations do not depend on the generator.
///
/// Regions (letters) and the intended solution (*):
///
///     A A B B        . * . .
///     A C B B        . . . *
///     C C D B   ->   * . . .
///     D D D B        . . * .
Puzzle fixture() {
  const a = 0, b = 1, c = 2, d = 3;
  return Puzzle(
    size: 4,
    regions: [
      a, a, b, b, //
      a, c, b, b, //
      c, c, d, b, //
      d, d, d, b, //
    ],
    solution: [1, 3, 0, 2],
  );
}

void main() {
  test('the fixture really is a legal, unique puzzle', () {
    final puzzle = fixture();
    final solver = Solver(puzzle.size, puzzle.regions);
    expect(solver.countSolutions(limit: 5), 1);
    expect(solver.solve(), puzzle.solution);
  });

  group('marks', () {
    test('tapping cycles empty -> ruled out -> unsure -> empty', () {
      final board = GameBoard(fixture(), autoBlock: false);
      expect(board.markAt(0), CellMark.empty);
      board.cycle(0);
      expect(board.markAt(0), CellMark.blocked);
      board.cycle(0);
      expect(board.markAt(0), CellMark.maybe);
      board.cycle(0);
      expect(board.markAt(0), CellMark.empty);
    });

    test('the cycle never reaches a mine', () {
      // Mines are committed with their own gesture. When they sat in this
      // cycle, the only way out of an X was through "mine", which in hard mode
      // costs a life: taking back your own mark could not be done without
      // being punished for it.
      final board = GameBoard(fixture(), autoBlock: false);
      for (var i = 0; i < 12; i++) {
        board.cycle(0);
        expect(board.markAt(0), isNot(CellMark.mine));
      }
    });

    test('a mine placed directly is cleared by one tap', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(0, CellMark.mine);
      board.cycle(0);
      expect(board.markAt(0), CellMark.empty);
    });

    test('an unsure mark is not a mine and constrains nothing', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(0, CellMark.maybe);
      board.setMark(5, CellMark.maybe);
      expect(board.minesPlaced, 0);
      expect(board.violations, isEmpty);
      expect(board.isSolved, isFalse);
    });

    test('mine counters track placements', () {
      final board = GameBoard(fixture(), autoBlock: false);
      expect(board.minesRemaining, 4);
      board.setMark(1, CellMark.mine);
      expect(board.minesPlaced, 1);
      expect(board.minesRemaining, 3);
    });
  });

  group('auto-block', () {
    test('X\'s out the row, column, colour and neighbours of a mine', () {
      final board = GameBoard(fixture(), autoBlock: true);
      board.setMark(1, CellMark.mine); // row 0, col 1, region A

      expect(board.markAt(0), CellMark.blocked, reason: 'same row');
      expect(board.markAt(5), CellMark.blocked, reason: 'diagonally touching');
      expect(board.markAt(9), CellMark.blocked, reason: 'same column');
      expect(board.markAt(4), CellMark.blocked, reason: 'same colour A');
      expect(board.markAt(11), CellMark.empty,
          reason: 'unrelated cells stay open');
    });

    test('can be switched off', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(1, CellMark.mine);
      expect(board.markAt(0), CellMark.empty);
    });

    test('removing a mine takes its X marks back with it', () {
      final board = GameBoard(fixture(), autoBlock: true);
      board.setMark(1, CellMark.mine);
      expect(board.markAt(0), CellMark.blocked);
      expect(board.markAt(9), CellMark.blocked);

      board.setMark(1, CellMark.empty);

      expect(board.markAt(1), CellMark.empty);
      expect(board.markAt(0), CellMark.empty, reason: 'row X must clear');
      expect(board.markAt(9), CellMark.empty, reason: 'column X must clear');
      expect(board.marks, everyElement(CellMark.empty));
    });

    test('one tap on a mine clears it and its X marks', () {
      final board = GameBoard(fixture(), autoBlock: true);
      board.setMark(1, CellMark.mine);
      expect(board.markAt(0), CellMark.blocked);

      board.cycle(1); // straight back to empty
      expect(board.marks, everyElement(CellMark.empty));
    });

    test('auto-marking leaves an unsure cell alone', () {
      // The player put it there on purpose, so it is theirs, not the board's.
      final board = GameBoard(fixture(), autoBlock: true);
      board.setMark(0, CellMark.maybe); // same row and colour as (0,1)
      board.setMark(1, CellMark.mine);

      expect(board.markAt(0), CellMark.maybe,
          reason: 'auto-marking must not overwrite a deliberate note');
    });

    test('removing one mine keeps the X marks of the other', () {
      final board = GameBoard(fixture(), autoBlock: true);
      board.setMark(1, CellMark.mine); // (0,1)
      board.setMark(7, CellMark.mine); // (1,3)
      expect(board.markAt(15), CellMark.blocked,
          reason: '(3,3) is in column 3 with the second mine');

      board.setMark(1, CellMark.empty);

      expect(board.markAt(15), CellMark.blocked,
          reason: 'the surviving mine still rules this out');
      // (3,1) shares only column 1 with the removed mine, and nothing with the
      // one still on the board, so it is the cell that must come back.
      expect(board.markAt(13), CellMark.empty,
          reason: 'only the removed mine ruled this out');
    });

    test('marks the player made by hand survive a mine being removed', () {
      final board = GameBoard(fixture(), autoBlock: true);
      board.setMark(10, CellMark.blocked); // player's own call
      board.setMark(1, CellMark.mine);
      board.setMark(1, CellMark.empty);

      expect(board.markAt(10), CellMark.blocked);
    });

    test('a hand-placed X is not reclaimed by auto-marking', () {
      final board = GameBoard(fixture(), autoBlock: true);
      // The player X's a cell first; a later mine also rules it out, but the
      // player owns that cell, so removing the mine must leave it alone.
      board.setMark(0, CellMark.blocked);
      board.setMark(1, CellMark.mine);
      board.setMark(1, CellMark.empty);

      expect(board.markAt(0), CellMark.blocked);
    });

    test('a restored save still tidies up after a removed mine', () {
      final board = GameBoard(fixture(), autoBlock: true);
      board.setMark(1, CellMark.mine);
      final saved = board.encodeMarks();

      final resumed = GameBoard(fixture(), autoBlock: true)
        ..restoreMarks(saved);
      expect(resumed.markAt(0), CellMark.blocked);

      resumed.setMark(1, CellMark.empty);
      expect(resumed.marks, everyElement(CellMark.empty));
    });
  });

  group('rule violations', () {
    test('two mines in a row are flagged', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(0, CellMark.mine);
      board.setMark(2, CellMark.mine);
      expect(board.violations.single.reason, MinedokuRules.rowRule);
      expect(board.conflictCells, {0, 2});
    });

    test('two mines in a column are flagged', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(0, CellMark.mine);
      board.setMark(8, CellMark.mine);
      expect(board.violations.single.reason, MinedokuRules.columnRule);
    });

    test('two mines in one colour are flagged', () {
      final board = GameBoard(fixture(), autoBlock: false);
      // Different rows and columns, so colour is the only rule they break.
      board.setMark(2, CellMark.mine); // (0,2), region B
      board.setMark(11, CellMark.mine); // (2,3), region B
      expect(board.violations.single.reason, MinedokuRules.regionRule);
    });

    test('diagonally touching mines are flagged', () {
      final board = GameBoard(fixture(), autoBlock: false);
      // Different rows, columns and colours, so only adjacency is broken.
      board.setMark(0, CellMark.mine); // (0,0), region A
      board.setMark(5, CellMark.mine); // (1,1), region C
      expect(board.violations.single.reason, MinedokuRules.touchRule);
    });

    test('a legal partial board has no violations', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(1, CellMark.mine);
      board.setMark(7, CellMark.mine);
      expect(board.violations, isEmpty);
    });
  });

  group('solved state', () {
    test('the intended solution wins', () {
      final puzzle = fixture();
      final board = GameBoard(puzzle, autoBlock: false);
      for (final cell in puzzle.solutionCells) {
        board.setMark(cell, CellMark.mine);
      }
      expect(board.isSolved, isTrue);
      expect(board.misplacedMines, isEmpty);
    });

    test('a partial board is not solved', () {
      final puzzle = fixture();
      final board = GameBoard(puzzle, autoBlock: false);
      board.setMark(1, CellMark.mine);
      expect(board.isSolved, isFalse);
    });

    test('four mines that break a rule are not a win', () {
      final board = GameBoard(fixture(), autoBlock: false);
      for (final cell in [0, 2, 8, 10]) {
        board.setMark(cell, CellMark.mine);
      }
      expect(board.minesPlaced, 4);
      expect(board.isSolved, isFalse);
    });
  });

  group('history', () {
    test('undo and redo walk the timeline', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(0, CellMark.mine);
      board.setMark(5, CellMark.blocked);
      expect(board.canUndo, isTrue);

      board.undo();
      expect(board.markAt(5), CellMark.empty);
      expect(board.markAt(0), CellMark.mine);

      board.redo();
      expect(board.markAt(5), CellMark.blocked);
    });

    test('undo restores every cell auto-block touched', () {
      final board = GameBoard(fixture(), autoBlock: true);
      board.setMark(1, CellMark.mine);
      expect(board.markAt(0), CellMark.blocked);
      board.undo();
      expect(board.markAt(0), CellMark.empty);
      expect(board.markAt(1), CellMark.empty);
    });

    test('a new move clears the redo stack', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(0, CellMark.mine);
      board.undo();
      expect(board.canRedo, isTrue);
      board.setMark(3, CellMark.blocked);
      expect(board.canRedo, isFalse);
    });

    test('clear empties the board but is undoable', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(0, CellMark.mine);
      board.clear();
      expect(board.minesPlaced, 0);
      board.undo();
      expect(board.markAt(0), CellMark.mine);
    });

    test('undo with no history is a no-op', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.undo();
      expect(board.minesPlaced, 0);
    });
  });

  group('saving', () {
    test('marks survive a round trip', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.setMark(0, CellMark.mine);
      board.setMark(3, CellMark.blocked);
      board.setMark(6, CellMark.maybe);

      final restored = GameBoard(fixture(), autoBlock: false)
        ..restoreMarks(board.encodeMarks());
      expect(restored.marks, board.marks);
    });

    test('a corrupt save is ignored rather than crashing', () {
      final board = GameBoard(fixture(), autoBlock: false);
      board.restoreMarks('nonsense');
      expect(board.minesPlaced, 0);
    });

    test('puzzles survive a round trip', () {
      final puzzle = fixture();
      final decoded = Puzzle.decode(puzzle.encode());
      expect(decoded.size, puzzle.size);
      expect(decoded.regions, puzzle.regions);
      expect(decoded.solution, puzzle.solution);
    });

    test('a bad puzzle string throws FormatException', () {
      expect(() => Puzzle.decode('not-a-puzzle'), throwsFormatException);
    });
  });
}
