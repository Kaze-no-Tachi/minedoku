import 'puzzle.dart';

/// How forgiving a board is.
enum GameMode {
  /// Place anything, take it back, ask for hints. Mistakes cost nothing.
  relaxed('Relaxed'),

  /// A wrong mine is rejected and costs a life. Run out and the board
  /// detonates. No hints.
  hard('Hard');

  const GameMode(this.label);

  final String label;

  bool get isHard => this == GameMode.hard;
}

/// What counts as a mistake, and how many are allowed.
///
/// This lives in the engine rather than the UI because it is a rule, and
/// because the definition of "mistake" is a genuine design decision worth
/// stating once, in the open, where it can be tested.
abstract final class MistakeRules {
  /// Lives in hard mode, whatever the board size.
  ///
  /// Flat rather than scaled: a player needs to know what hard mode costs
  /// before they start, and "three mistakes" is a promise that does not need a
  /// table to understand.
  static const int lives = 3;

  /// True when placing a mine on [cell] is wrong.
  ///
  /// A placement counts as a mistake when it is not part of the solution, even
  /// if it breaks no rule *yet*. That is fair here in a way it would not be in
  /// a guessing game: every board has exactly one solution and can be reached
  /// by logic alone, so a mine anywhere else is an error the player could have
  /// avoided, not bad luck.
  static bool isMistake(Puzzle puzzle, int cell) =>
      !puzzle.solutionCells.contains(cell);

  /// Lives left after [mistakes] wrong placements, never below zero.
  static int livesLeft(int mistakes) {
    final left = lives - mistakes;
    return left < 0 ? 0 : left;
  }

  /// Whether the board is lost.
  static bool isLost(int mistakes) => mistakes >= lives;
}
