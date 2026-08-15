import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:test/test.dart';

void main() {
  group('a gauntlet run', () {
    test('starts fresh with every life', () {
      const run = GauntletRun();
      expect(run.stage, 0);
      expect(run.boardNumber, 1);
      expect(run.livesLeft, MistakeRules.lives);
      expect(run.isOver, isFalse);
    });

    test('climbs a tier every few boards and holds at expert', () {
      expect(const GauntletRun(stage: 0).difficulty, Difficulty.easy);
      expect(
        const GauntletRun(stage: GauntletRun.stagesPerTier).difficulty,
        Difficulty.medium,
      );
      expect(
        const GauntletRun(stage: GauntletRun.stagesPerTier * 2).difficulty,
        Difficulty.hard,
      );
      expect(
        const GauntletRun(stage: GauntletRun.stagesPerTier * 3).difficulty,
        Difficulty.expert,
      );
      // And stays there rather than running off the end of the enum.
      expect(const GauntletRun(stage: 500).difficulty, Difficulty.expert);
    });

    test('difficulty never goes backwards as the run goes on', () {
      var previous = -1;
      for (var stage = 0; stage < 40; stage++) {
        final index = GauntletRun(stage: stage).difficulty.index;
        expect(index, greaterThanOrEqualTo(previous), reason: 'stage $stage');
        previous = index;
      }
    });

    test('lives are shared across the whole run', () {
      // The point of the mode: a careless first board is felt on the fifth.
      var run = const GauntletRun().withMistake();
      expect(run.livesLeft, MistakeRules.lives - 1);

      run = run.cleared(30);
      expect(run.stage, 1);
      expect(run.livesLeft, MistakeRules.lives - 1,
          reason: 'clearing a board does not hand lives back');
    });

    test('the run ends when the lives are gone', () {
      var run = const GauntletRun();
      for (var i = 0; i < MistakeRules.lives; i++) {
        expect(run.isOver, isFalse);
        run = run.withMistake();
      }
      expect(run.isOver, isTrue);
      expect(run.livesLeft, 0);
    });

    test('clearing accumulates time and boards', () {
      final run = const GauntletRun().cleared(20).cleared(35);
      expect(run.stage, 2);
      expect(run.clearedSeconds, 55);
      expect(run.boardNumber, 3);
    });

    test('a stage deals a board of the difficulty it claims', () {
      for (var stage = 0; stage < 12; stage++) {
        final run = GauntletRun(stage: stage);
        final spec = run.specFor(4242);
        expect(spec.difficulty, run.difficulty, reason: 'stage $stage');
      }
    });

    test('stages within one run are different boards', () {
      final seen = {
        for (var stage = 0; stage < 10; stage++)
          GauntletRun(stage: stage).specFor(99).seed,
      };
      expect(seen.length, greaterThan(6));
    });

    test('a run is reproducible from its seed', () {
      final first = const GauntletRun(stage: 3).specFor(777);
      final second = const GauntletRun(stage: 3).specFor(777);
      expect(first.seed, second.seed);
      expect(first.size, second.size);
    });
  });
}
