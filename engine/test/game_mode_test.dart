import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:test/test.dart';

void main() {
  const generator = PuzzleGenerator();

  test('a solution cell is never a mistake', () {
    final puzzle = generator.generate(size: 6, seed: 11);
    for (final cell in puzzle.solutionCells) {
      expect(MistakeRules.isMistake(puzzle, cell), isFalse);
    }
  });

  test('every other cell is a mistake', () {
    final puzzle = generator.generate(size: 6, seed: 11);
    var counted = 0;
    for (var cell = 0; cell < puzzle.size * puzzle.size; cell++) {
      if (puzzle.solutionCells.contains(cell)) continue;
      expect(MistakeRules.isMistake(puzzle, cell), isTrue);
      counted++;
    }
    expect(counted, puzzle.size * puzzle.size - puzzle.size);
  });

  test('lives count down and stop at zero', () {
    expect(MistakeRules.livesLeft(0), MistakeRules.lives);
    expect(MistakeRules.livesLeft(1), MistakeRules.lives - 1);
    expect(MistakeRules.livesLeft(MistakeRules.lives), 0);
    expect(MistakeRules.livesLeft(MistakeRules.lives + 5), 0);
  });

  test('the board is lost only once the lives are gone', () {
    for (var i = 0; i < MistakeRules.lives; i++) {
      expect(MistakeRules.isLost(i), isFalse, reason: '$i mistakes');
    }
    expect(MistakeRules.isLost(MistakeRules.lives), isTrue);
  });

  test('modes report their own difficulty', () {
    expect(GameMode.hard.isHard, isTrue);
    expect(GameMode.relaxed.isHard, isFalse);
    expect(GameMode.values.map((m) => m.label), ['Relaxed', 'Hard']);
  });
}
