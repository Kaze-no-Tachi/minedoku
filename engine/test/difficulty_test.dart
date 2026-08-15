import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:test/test.dart';

void main() {
  const generator = PuzzleGenerator();

  group('rating', () {
    test('always finishes the board it is rating', () {
      for (var seed = 1; seed <= 20; seed++) {
        final report = DifficultyRater.rate(generator.generate(size: 6, seed: seed));
        expect(report.solved, isTrue, reason: 'seed $seed was not solved');
        expect(report.steps, greaterThanOrEqualTo(6));
      }
    });

    test('is deterministic', () {
      final puzzle = generator.generate(size: 7, seed: 99);
      final first = DifficultyRater.rate(puzzle);
      final second = DifficultyRater.rate(puzzle);
      expect(first.score, second.score);
      expect(first.difficulty, second.difficulty);
    });

    test('a board of pure forced moves is trivial', () {
      // Search for one; they are common, which is the whole problem this
      // rater exists to detect.
      DifficultyReport? trivial;
      for (var seed = 1; seed <= 60 && trivial == null; seed++) {
        final report = DifficultyRater.rate(generator.generate(size: 5, seed: seed));
        if (report.eliminations == 0 && report.deep == 0) trivial = report;
      }

      expect(trivial, isNotNull, reason: 'expected at least one such board');
      expect(trivial!.isTrivial, isTrue);
      expect(trivial.density, closeTo(1.0, 0.001),
          reason: 'one unit of cost per mine and nothing more');
      expect(trivial.difficulty, Difficulty.gentle);
    });

    test('density lets sizes be compared', () {
      // A board solved entirely by forced moves scores 1.0 per mine whatever
      // its size, which is what makes the tiers meaningful across sizes.
      for (final size in [5, 6, 7, 8]) {
        for (var seed = 1; seed <= 40; seed++) {
          final report =
              DifficultyRater.rate(generator.generate(size: size, seed: seed));
          if (report.eliminations == 0 && report.deep == 0) {
            expect(report.density, closeTo(1.0, 0.001), reason: '${size}x$size');
            break;
          }
        }
      }
    });

    test('harder boards need more than forced placements', () {
      DifficultyReport? hard;
      for (var seed = 1; seed <= 200 && hard == null; seed++) {
        final report = DifficultyRater.rate(generator.generate(size: 7, seed: seed));
        if (report.difficulty == Difficulty.hard ||
            report.difficulty == Difficulty.expert) {
          hard = report;
        }
      }

      expect(hard, isNotNull);
      expect(hard!.eliminations + hard.deep, greaterThan(0),
          reason: 'a hard board must need real deduction');
      expect(hard.isTrivial, isFalse);
    });

    test('tier ceilings are ordered', () {
      var previous = 0.0;
      for (final difficulty in Difficulty.values) {
        final ceiling = DifficultyRater.ceilingFor(difficulty);
        expect(ceiling, greaterThan(previous), reason: difficulty.label);
        previous = ceiling;
      }
      expect(DifficultyRater.ceilingFor(Difficulty.expert), double.infinity);
    });
  });
}
