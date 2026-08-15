import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:test/test.dart';

void main() {
  const generator = PuzzleGenerator();
  final bands0Length = Levels.bands.first.length;

  group('the graded table', () {
    test('is populated', () {
      expect(LevelTable.all, isNotEmpty,
          reason: 'run: dart run tool/build_level_table.dart');
      expect(LevelTable.all.length, greaterThan(100));
    });

    test('holds no trivial board above Gentle', () {
      // The point of the table. A board solvable by forced moves alone is not
      // a puzzle, and a third of the old size-ordered levels were exactly that.
      // Gentle is the deliberate exception: those boards are the on-ramp.
      for (final board in LevelTable.all) {
        if (board.difficulty == Difficulty.gentle) continue;
        final report = DifficultyRater.rate(
          generator.generate(size: board.size, seed: board.seed),
        );
        expect(report.isTrivial, isFalse,
            reason: '${board.size}x${board.size} seed ${board.seed}');
      }
    });

    test('every board is filed under the difficulty it measures', () {
      for (final board in LevelTable.all) {
        final report = DifficultyRater.rate(
          generator.generate(size: board.size, seed: board.seed),
        );
        expect(report.difficulty, board.difficulty,
            reason: '${board.size}x${board.size} seed ${board.seed}');
        expect(report.score, board.score);
      }
    });

    test('covers every difficulty', () {
      for (final difficulty in Difficulty.values) {
        expect(LevelTable.atDifficulty(difficulty), isNotEmpty,
            reason: 'no boards graded ${difficulty.label}');
      }
    });

    test('nearest falls back rather than returning nothing', () {
      for (final size in [5, 6, 7, 8, 9]) {
        for (final difficulty in Difficulty.values) {
          expect(LevelTable.nearest(size, difficulty), isNotEmpty,
              reason: '${size}x$size ${difficulty.label}');
        }
      }
    });
  });

  group('the campaign', () {
    test('difficulty never goes backwards', () {
      // The failure this replaced: level 22 was a trivial 7x7 sitting after a
      // brutal 6x6, because size was standing in for difficulty.
      var previous = -1;
      for (var level = 1; level <= Levels.bandedLevels; level++) {
        final spec = Levels.forLevel(level);
        expect(spec.difficulty.index, greaterThanOrEqualTo(previous),
            reason: 'level $level dropped in difficulty');
        previous = spec.difficulty.index;
      }
    });

    test('board size never goes backwards either', () {
      var previous = 0;
      for (var level = 1; level <= Levels.bandedLevels; level++) {
        final size = Levels.forLevel(level).size;
        expect(size, greaterThanOrEqualTo(previous), reason: 'level $level');
        previous = size;
      }
    });

    test('starts gentle and ends expert', () {
      expect(Levels.forLevel(1).difficulty, Difficulty.gentle);
      expect(Levels.forLevel(1).size, 5);
      expect(Levels.forLevel(Levels.bandedLevels).difficulty, Difficulty.expert);
      expect(Levels.forLevel(500).size, 9);
      expect(Levels.forLevel(500).difficulty, Difficulty.expert);
    });

    test('no level past the opening warm-up is trivial', () {
      // Levels 1 to 5 are the Gentle band and may be solvable by forced moves.
      // Everything after that has to be a real puzzle.
      for (var level = bands0Length + 1; level <= 60; level++) {
        final spec = Levels.forLevel(level);
        final report = DifficultyRater.rate(
          generator.generate(size: spec.size, seed: spec.seed),
        );
        expect(report.isTrivial, isFalse, reason: 'level $level');
      }
    });

    test('a level is the same board every time', () {
      for (var level = 1; level <= 30; level++) {
        final a = Levels.forLevel(level);
        final b = Levels.forLevel(level);
        expect(a.seed, b.seed);
        expect(a.size, b.size);
      }
    });

    test('consecutive levels are different boards', () {
      final seen = <String>{};
      for (var level = 1; level <= Levels.bandedLevels; level++) {
        final spec = Levels.forLevel(level);
        seen.add('${spec.size}:${spec.seed}');
      }
      expect(seen.length, Levels.bandedLevels,
          reason: 'every banded level should be a distinct board');
    });

    test('levels below 1 are clamped', () {
      expect(Levels.forLevel(0).number, 1);
      expect(Levels.forLevel(-4).number, 1);
    });
  });

  group('endless', () {
    test('returns a board of the difficulty asked for', () {
      for (final difficulty in Difficulty.values) {
        for (final roll in [0, 7, 129, 5000]) {
          final spec = Levels.endless(difficulty, roll);
          expect(spec.difficulty, difficulty);
          expect(spec.title, contains(difficulty.label));
        }
      }
    });

    test('different rolls give different boards', () {
      final seen = {
        for (var roll = 0; roll < 40; roll++)
          Levels.endless(Difficulty.medium, roll).seed,
      };
      expect(seen.length, greaterThan(5));
    });

    test('by size returns that size and is never trivial', () {
      for (final size in [5, 6, 7, 8, 9]) {
        final spec = Levels.endlessAtSize(size, 17);
        expect(spec.size, size);
        final report = DifficultyRater.rate(
          generator.generate(size: spec.size, seed: spec.seed),
        );
        expect(report.isTrivial, isFalse, reason: '${size}x$size');
      }
    });
  });

  group('the daily', () {
    test('is stable for a date and changes the next day', () {
      final first = Levels.daily(DateTime(2026, 8, 15));
      final same = Levels.daily(DateTime(2026, 8, 15, 23, 59));
      final next = Levels.daily(DateTime(2026, 8, 16));

      expect(first.seed, same.seed);
      expect(first.size, same.size);
      expect(first.title, 'Daily 8/15');
      expect(
        '${first.size}:${first.seed}' != '${next.size}:${next.seed}',
        isTrue,
      );
    });

    test('is never a trivial board', () {
      for (var day = 1; day <= 28; day++) {
        final spec = Levels.daily(DateTime(2026, 3, day));
        final report = DifficultyRater.rate(
          generator.generate(size: spec.size, seed: spec.seed),
        );
        expect(report.isTrivial, isFalse, reason: 'March $day');
      }
    });
  });
}
