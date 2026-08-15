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

  group('explanations', () {
    test('a rule-out hint names the row, column or colour it rests on', () {
      // Search seeds until one produces a rule-out hint, then check it is
      // explained rather than merely asserted.
      Hint? ruledOut;
      for (var seed = 1; seed <= 40 && ruledOut == null; seed++) {
        final puzzle = generator.generate(size: 6, seed: seed);
        final board = GameBoard(puzzle, autoBlock: false);
        final hint = hints.next(board);
        if (hint.kind == HintKind.ruledOut) ruledOut = hint;
      }

      expect(ruledOut, isNotNull,
          reason: 'expected at least one rule-out hint across 40 boards');
      expect(ruledOut!.message, contains('nowhere to go'));
      expect(
        ruledOut.message,
        anyOf(contains('this colour'), contains('row '), contains('column ')),
      );
      expect(ruledOut.relatedCells, isNotEmpty,
          reason: 'the UI needs cells to highlight');
    });

    test('a forced-placement hint says what ruled the others out', () {
      final puzzle = generator.generate(size: 6, seed: 21);
      final board = GameBoard(puzzle, autoBlock: false);
      final hint = hints.next(board);

      if (hint.kind == HintKind.forcedMine) {
        // Wording varies by case (a one-cell colour is forced for a different
        // reason than one whose other cells were eliminated), so check that it
        // names the unit and gives a reason rather than pinning a phrase.
        expect(
          hint.message,
          anyOf(contains('colour'), contains('row '), contains('column ')),
        );
        expect(hint.message, contains('so'));
        expect(hint.relatedCells, isNotEmpty);
        expect(hint.relatedCells, contains(hint.cell));
      }
    });

    test('highlighted cells really are one row, column or colour', () {
      for (var seed = 1; seed <= 25; seed++) {
        final puzzle = generator.generate(size: 6, seed: seed);
        final board = GameBoard(puzzle, autoBlock: false);
        final hint = hints.next(board);
        if (hint.relatedCells.isEmpty) continue;

        final size = puzzle.size;
        final rows = hint.relatedCells.map((c) => c ~/ size).toSet();
        final columns = hint.relatedCells.map((c) => c % size).toSet();
        final regions = hint.relatedCells.map((c) => puzzle.regions[c]).toSet();

        expect(
          rows.length == 1 || columns.length == 1 || regions.length == 1,
          isTrue,
          reason: 'seed $seed highlighted an incoherent group',
        );
      }
    });

    test('every hint explains itself rather than just asserting', () {
      for (var seed = 1; seed <= 20; seed++) {
        final puzzle = generator.generate(size: 7, seed: seed);
        final board = GameBoard(puzzle, autoBlock: false);
        final hint = hints.next(board);
        expect(hint.message.length, greaterThan(40),
            reason: 'seed $seed gave a bare instruction: "${hint.message}"');
        expect(
          hint.message,
          anyOf(
            contains('so'),
            contains('because'),
            contains('leaving'),
            contains('takes'),
            contains('while'),
          ),
          reason: 'seed $seed gave no reasoning: "${hint.message}"',
        );
      }
    });
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
