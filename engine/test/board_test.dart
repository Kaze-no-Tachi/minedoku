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
    test('tapping cycles empty -> blocked -> mine -> empty', () {
      final board = GameBoard(fixture(), autoBlock: false);
      expect(board.markAt(0), CellMark.empty);
      board.cycle(0);
      expect(board.markAt(0), CellMark.blocked);
      board.cycle(0);
      expect(board.markAt(0), CellMark.mine);
      board.cycle(0);
      expect(board.markAt(0), CellMark.empty);
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
