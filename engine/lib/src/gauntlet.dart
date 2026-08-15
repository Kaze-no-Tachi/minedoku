import 'game_mode.dart';
import 'levels.dart';

/// A run of boards played back to back on one shared set of lives.
///
/// The campaign is a ladder you climb once. This is the loop you come back to:
/// the boards get harder, the mistakes carry over, and the only thing that
/// improves is you. Losing costs the whole run, which is what makes the next
/// one worth starting.
class GauntletRun {
  const GauntletRun({
    this.stage = 0,
    this.mistakes = 0,
    this.clearedSeconds = 0,
  });

  /// How many boards have been cleared so far. Also the index of the board
  /// being played.
  final int stage;

  /// Mistakes made across the whole run, not just this board.
  final int mistakes;

  /// Time spent on boards already cleared.
  final int clearedSeconds;

  /// Lives are shared by the run, so a careless first board is felt on the
  /// fifth.
  int get livesLeft => MistakeRules.livesLeft(mistakes);

  bool get isOver => MistakeRules.isLost(mistakes);

  /// One-based number of the board being played, for display.
  int get boardNumber => stage + 1;

  /// Difficulty of the board at [stage].
  ///
  /// Climbs one tier every [stagesPerTier] boards and then holds at expert, so
  /// a run starts approachable and ends punishing however good the player is.
  Difficulty get difficulty {
    final tier = stage ~/ stagesPerTier;
    final index = tier + Difficulty.easy.index;
    return index >= Difficulty.values.length
        ? Difficulty.expert
        : Difficulty.values[index];
  }

  /// Boards at each tier before it steps up.
  static const int stagesPerTier = 3;

  /// The board for the current stage.
  ///
  /// [seed] comes from the caller so the engine keeps no random source. Passing
  /// the run's own seed plus the stage means one run is reproducible while
  /// different runs differ.
  LevelSpec specFor(int seed) =>
      Levels.endless(difficulty, seed + stage * 7919);

  GauntletRun cleared(int seconds) => GauntletRun(
        stage: stage + 1,
        mistakes: mistakes,
        clearedSeconds: clearedSeconds + seconds,
      );

  GauntletRun withMistake() => GauntletRun(
        stage: stage,
        mistakes: mistakes + 1,
        clearedSeconds: clearedSeconds,
      );
}
