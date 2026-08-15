import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:test/test.dart';

void main() {
  const generator = PuzzleGenerator();
  const hints = HintEngine();

  test('an empty board still yields a usable hint', () {
    final puzzle = generator.generate(size: 6, seed: 21);
    final board = GameBoard(puzzle, autoBlock: false);
    final hint = hints.next(board);

    expect(hint.kind, isNot(HintKind.solved));
    expect(hint.cell, isNotNull);
    expect(hint.message, isNotEmpty);
  });

  test('a hint never points at a cell that already holds a mine', () {
    final puzzle = generator.generate(size: 6, seed: 33);
    final board = GameBoard(puzzle, autoBlock: false);
    board.setMark(puzzle.solutionCells.first, CellMark.mine);

    final hint = hints.next(board);
    expect(board.markAt(hint.cell!), isNot(CellMark.mine));
  });

  test('a wrong placement is called out first', () {
    final puzzle = generator.generate(size: 6, seed: 7);
    final board = GameBoard(puzzle, autoBlock: false);
    final wrong = List.generate(puzzle.size * puzzle.size, (i) => i)
        .firstWhere((i) => !puzzle.solutionCells.contains(i));
    board.setMark(wrong, CellMark.mine);

    final hint = hints.next(board);
    expect(hint.kind, HintKind.removeMine);
    expect(hint.cell, wrong);
  });

  test('a solved board reports nothing left to do', () {
    final puzzle = generator.generate(size: 5, seed: 3);
    final board = GameBoard(puzzle, autoBlock: false);
    for (final cell in puzzle.solutionCells) {
      board.setMark(cell, CellMark.mine);
    }
    expect(hints.next(board).kind, HintKind.solved);
  });

  test('forced and reveal hints always name a true solution cell', () {
    for (var seed = 1; seed <= 10; seed++) {
      final puzzle = generator.generate(size: 7, seed: seed);
      final board = GameBoard(puzzle, autoBlock: false);
      final hint = hints.next(board);
      if (hint.kind == HintKind.forcedMine || hint.kind == HintKind.reveal) {
        expect(puzzle.solutionCells, contains(hint.cell),
            reason: 'seed $seed suggested a cell that is not a mine');
      }
      if (hint.kind == HintKind.ruledOut) {
        expect(puzzle.solutionCells, isNot(contains(hint.cell)),
            reason: 'seed $seed ruled out a real mine');
      }
    }
  });

  test('following hints alone always finishes the board', () {
    for (var seed = 1; seed <= 6; seed++) {
      final puzzle = generator.generate(size: 7, seed: seed);
      final board = GameBoard(puzzle, autoBlock: true);

      var guard = 0;
      while (!board.isSolved) {
        expect(guard++, lessThan(200), reason: 'hints must make progress');
        final hint = hints.next(board);
        switch (hint.kind) {
          case HintKind.forcedMine:
          case HintKind.reveal:
            board.setMark(hint.cell!, CellMark.mine);
          case HintKind.ruledOut:
            board.setMark(hint.cell!, CellMark.blocked);
          case HintKind.removeMine:
            board.setMark(hint.cell!, CellMark.empty);
          case HintKind.solved:
            fail('reported solved while unsolved');
        }
      }
      expect(board.isSolved, isTrue);
    }
  });
}
