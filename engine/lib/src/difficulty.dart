import 'board.dart';
import 'hints.dart';
import 'levels.dart';
import 'puzzle.dart';

/// What it took to solve a board, and how hard that makes it.
class DifficultyReport {
  const DifficultyReport({
    required this.score,
    required this.steps,
    required this.forced,
    required this.eliminations,
    required this.deep,
    required this.size,
    required this.solved,
  });

  /// Total weighted cost of the deductions needed.
  final int score;

  /// Deductions made in total.
  final int steps;

  /// Steps where a row, column or colour had exactly one cell left. The
  /// easiest thing to spot, and what auto-marking hands the player for free.
  final int forced;

  /// Steps where a cell had to be ruled out because it would starve some other
  /// row, column or colour. Real deduction.
  final int eliminations;

  /// Steps needing a contradiction chased further than one move.
  final int deep;

  final int size;

  /// False if the rater gave up, which should not happen for a valid board.
  final bool solved;

  /// Cost per mine, so boards of different sizes can be compared.
  ///
  /// A board solvable entirely by forced placements scores 1.0 here, whatever
  /// its size, which is exactly the "there was nothing to work out" case.
  double get density => size == 0 ? 0 : score / size;

  Difficulty get difficulty => Difficulty.values.firstWhere(
        (d) => density < DifficultyRater.ceilingFor(d),
        orElse: () => Difficulty.expert,
      );

  /// True when the board can be finished without a single real deduction.
  ///
  /// These are the boards that make a campaign feel pointless, and they are
  /// common: a third of the size-ordered levels this replaced were like this.
  bool get isTrivial => density < DifficultyRater.trivialCeiling;

  @override
  String toString() => '${size}x$size score $score '
      '(${density.toStringAsFixed(1)}/mine, ${difficulty.label}) '
      'forced $forced, ruled out $eliminations, deep $deep';
}

/// Rates a puzzle by solving it and recording what kind of thinking each step
/// needed.
///
/// This is a proxy, and worth being honest about what it measures: the cost of
/// a step is judged by which tier of [HintEngine] could explain it, so a board
/// that needs reasoning deeper than the hint engine can articulate lands in the
/// most expensive bucket. That is the right direction (those boards really are
/// harder for a person) but it is a rating of *this* solver's effort, not a
/// measurement of human difficulty.
abstract final class DifficultyRater {
  static const _hints = HintEngine();

  /// A forced placement: the only cell left in some row, column or colour.
  static const int forcedCost = 1;

  /// An elimination with a nameable reason.
  static const int eliminationCost = 3;

  /// A contradiction that needed a deeper search.
  static const int deepCost = 8;

  /// No logical step could be found at all, so the answer had to be looked up.
  static const int revealCost = 12;

  /// Below this cost per mine, a board is solvable by forced moves alone.
  static const double trivialCeiling = 1.6;

  /// Upper bound on cost-per-mine for each tier.
  static double ceilingFor(Difficulty difficulty) => switch (difficulty) {
        Difficulty.gentle => 4.0,
        Difficulty.easy => 9.0,
        Difficulty.medium => 16.0,
        Difficulty.hard => 25.0,
        Difficulty.expert => double.infinity,
      };

  static DifficultyReport rate(Puzzle puzzle) {
    // Auto-marking on, because that is how the game is actually played: the
    // rating should reflect the work left to the player, not the work the app
    // already does for them.
    final board = GameBoard(puzzle, autoBlock: true);
    var score = 0;
    var steps = 0;
    var forced = 0;
    var eliminations = 0;
    var deep = 0;

    // Generous ceiling; a real board needs a few dozen steps at most.
    final limit = puzzle.size * puzzle.size * 4;

    while (!board.isSolved && steps < limit) {
      final hint = _hints.next(board);
      steps++;
      switch (hint.kind) {
        case HintKind.forcedMine:
          forced++;
          score += forcedCost;
          board.setMark(hint.cell!, CellMark.mine);
        case HintKind.ruledOut:
          // An explained elimination names the unit it would starve. One
          // without a reason needed a deeper contradiction.
          if (hint.relatedCells.isNotEmpty) {
            eliminations++;
            score += eliminationCost;
          } else {
            deep++;
            score += deepCost;
          }
          board.setMark(hint.cell!, CellMark.blocked);
        case HintKind.reveal:
          deep++;
          score += revealCost;
          board.setMark(hint.cell!, CellMark.mine);
        case HintKind.removeMine:
        case HintKind.solved:
          // The rater only ever plays correct moves, so neither can happen.
          return _report(puzzle, score, steps, forced, eliminations, deep,
              board.isSolved);
      }
    }

    return _report(
        puzzle, score, steps, forced, eliminations, deep, board.isSolved);
  }

  static DifficultyReport _report(
    Puzzle puzzle,
    int score,
    int steps,
    int forced,
    int eliminations,
    int deep,
    bool solved,
  ) =>
      DifficultyReport(
        score: score,
        steps: steps,
        forced: forced,
        eliminations: eliminations,
        deep: deep,
        size: puzzle.size,
        solved: solved,
      );
}
