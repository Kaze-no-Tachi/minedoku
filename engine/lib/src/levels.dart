import 'level_table.g.dart';

/// How hard a board is expected to be.
///
/// This is measured, not assumed. See `DifficultyRater`.
enum Difficulty {
  gentle('Gentle'),
  easy('Easy'),
  medium('Medium'),
  hard('Hard'),
  expert('Expert');

  const Difficulty(this.label);

  final String label;
}

/// A board whose difficulty has been measured.
class GradedBoard {
  const GradedBoard({
    required this.size,
    required this.seed,
    required this.difficulty,
    required this.score,
  });

  final int size;
  final int seed;
  final Difficulty difficulty;

  /// Weighted cost of the deductions needed, from `DifficultyRater`.
  final int score;
}

/// The curated boards, graded offline and shipped as a table.
///
/// Grading has to happen somewhere. Doing it at build time keeps the app
/// instant and every board reproducible from a seed, at the cost of a
/// generated file in the repository.
abstract final class LevelTable {
  static final List<GradedBoard> all = List.unmodifiable([
    for (final row in gradedBoardData)
      GradedBoard(
        size: row[0],
        seed: row[1],
        difficulty: Difficulty.values[row[2]],
        score: row[3],
      ),
  ]);

  static final Map<(int, Difficulty), List<GradedBoard>> _buckets = () {
    final map = <(int, Difficulty), List<GradedBoard>>{};
    for (final board in all) {
      map.putIfAbsent((board.size, board.difficulty), () => []).add(board);
    }
    return map;
  }();

  static final Map<Difficulty, List<GradedBoard>> _byDifficulty = () {
    final map = <Difficulty, List<GradedBoard>>{};
    for (final board in all) {
      map.putIfAbsent(board.difficulty, () => []).add(board);
    }
    return map;
  }();

  /// Boards of exactly this size and difficulty, possibly empty.
  static List<GradedBoard> bucket(int size, Difficulty difficulty) =>
      _buckets[(size, difficulty)] ?? const [];

  /// Every board at a difficulty, across all sizes. What endless mode draws
  /// from, so the size varies too.
  static List<GradedBoard> atDifficulty(Difficulty difficulty) =>
      _byDifficulty[difficulty] ?? const [];

  /// The requested bucket, or the nearest populated one at that size.
  ///
  /// Some combinations barely exist: a 5x5 has too little room to be expert.
  /// Rather than fail, this walks outward through neighbouring difficulties so
  /// a campaign band always has boards to draw on.
  static List<GradedBoard> nearest(int size, Difficulty wanted) {
    final exact = bucket(size, wanted);
    if (exact.isNotEmpty) return exact;

    for (var distance = 1; distance < Difficulty.values.length; distance++) {
      for (final step in [-distance, distance]) {
        final index = wanted.index + step;
        if (index < 0 || index >= Difficulty.values.length) continue;
        final candidate = bucket(size, Difficulty.values[index]);
        if (candidate.isNotEmpty) return candidate;
      }
    }
    return all.where((b) => b.size == size).toList();
  }
}

/// Everything needed to rebuild one board.
///
/// Boards are never stored. A level maps to a (size, seed) pair and the
/// generator rebuilds the identical board from it, so the campaign costs no
/// storage and a level number names a board exactly.
class LevelSpec {
  const LevelSpec({
    required this.number,
    required this.size,
    required this.seed,
    required this.difficulty,
    this.title,
  });

  final int number;
  final int size;
  final int seed;
  final Difficulty difficulty;

  /// Set for boards that are not campaign levels.
  final String? title;

  String get displayName => title ?? 'Level $number';

  @override
  String toString() => '$displayName (${size}x$size, ${difficulty.label})';
}

/// One stretch of the campaign: a board size and a difficulty, for so many
/// levels.
class CampaignBand {
  const CampaignBand(this.size, this.difficulty, this.length);

  final int size;
  final Difficulty difficulty;
  final int length;
}

/// The campaign: an endless run of boards that gets harder in two directions.
///
/// Board size was the only thing that used to increase, which turned out to be
/// a poor proxy: measured across the old size-ordered levels, roughly a third
/// needed no deduction at all, and an 8x8 could be easier than a 5x5. The ramp
/// now moves through both size and measured difficulty, and trivial boards are
/// excluded from the table entirely.
abstract final class Levels {
  static const List<CampaignBand> bands = [
    CampaignBand(5, Difficulty.gentle, 5),
    CampaignBand(5, Difficulty.easy, 7),
    CampaignBand(6, Difficulty.easy, 8),
    CampaignBand(6, Difficulty.medium, 12),
    CampaignBand(7, Difficulty.medium, 16),
    CampaignBand(7, Difficulty.hard, 18),
    CampaignBand(8, Difficulty.hard, 20),
    CampaignBand(8, Difficulty.expert, 24),
  ];

  /// Levels covered by the bands. Beyond this the campaign continues on 9x9
  /// expert boards.
  static final int bandedLevels =
      bands.fold(0, (sum, band) => sum + band.length);

  /// Size for a campaign level.
  static int sizeForLevel(int level) => forLevel(level).size;

  static Difficulty difficultyForLevel(int level) => forLevel(level).difficulty;

  /// The spec for campaign level [level] (1-based).
  static LevelSpec forLevel(int level) {
    final n = level < 1 ? 1 : level;

    var remaining = n - 1;
    for (final band in bands) {
      if (remaining < band.length) {
        return _fromBucket(
          number: n,
          boards: LevelTable.nearest(band.size, band.difficulty),
          offset: remaining,
          fallbackSize: band.size,
          fallbackDifficulty: band.difficulty,
        );
      }
      remaining -= band.length;
    }

    // The tail: 9x9 expert, forever.
    return _fromBucket(
      number: n,
      boards: LevelTable.nearest(9, Difficulty.expert),
      offset: remaining,
      fallbackSize: 9,
      fallbackDifficulty: Difficulty.expert,
    );
  }

  static LevelSpec _fromBucket({
    required int number,
    required List<GradedBoard> boards,
    required int offset,
    required int fallbackSize,
    required Difficulty fallbackDifficulty,
  }) {
    if (boards.isEmpty) {
      // Only reachable if the generated table is missing or empty. Falling
      // back to a derived seed keeps the game playable rather than crashing.
      return LevelSpec(
        number: number,
        size: fallbackSize,
        seed: number * 7919 + 13,
        difficulty: fallbackDifficulty,
      );
    }
    final board = boards[offset % boards.length];
    return LevelSpec(
      number: number,
      size: board.size,
      seed: board.seed,
      difficulty: board.difficulty,
    );
  }

  /// A fresh board at a chosen difficulty, for endless play.
  ///
  /// [roll] is supplied by the caller so the engine stays free of any random
  /// source of its own.
  static LevelSpec endless(Difficulty difficulty, int roll) {
    final boards = LevelTable.atDifficulty(difficulty);
    if (boards.isEmpty) {
      return LevelSpec(
        number: roll,
        size: 7,
        seed: roll,
        difficulty: difficulty,
        title: '${difficulty.label} board',
      );
    }
    final board = boards[roll.abs() % boards.length];
    return LevelSpec(
      number: roll,
      size: board.size,
      seed: board.seed,
      difficulty: board.difficulty,
      title: '${difficulty.label} board',
    );
  }

  /// A fresh graded board of a chosen size, whatever its difficulty.
  ///
  /// For players who want a big grid rather than a particular challenge. It
  /// still comes from the graded table, so it will never be a board that
  /// solves itself.
  static LevelSpec endlessAtSize(int size, int roll) {
    // Gentle boards are excluded here. They exist as the campaign's opening
    // warm-up, and someone deliberately asking for a 9x9 wants a puzzle, not a
    // board that fills itself in.
    final boards = LevelTable.all
        .where((b) => b.size == size && b.difficulty != Difficulty.gentle)
        .toList();
    if (boards.isEmpty) return custom(size: size, seed: roll);
    final board = boards[roll.abs() % boards.length];
    return LevelSpec(
      number: roll,
      size: board.size,
      seed: board.seed,
      difficulty: board.difficulty,
      title: '${board.size}x${board.size} board',
    );
  }

  /// A puzzle keyed to a calendar day: everyone gets the same board.
  static LevelSpec daily(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final key = day.year * 10000 + day.month * 100 + day.day;
    final graded = LevelTable.all;
    if (graded.isEmpty) {
      return LevelSpec(
        number: key,
        size: 7,
        seed: key * 31 + 7,
        difficulty: Difficulty.medium,
        title: 'Daily ${day.month}/${day.day}',
      );
    }
    // Drawn from the graded table so a daily is never a trivial board.
    final board = graded[key % graded.length];
    return LevelSpec(
      number: key,
      size: board.size,
      seed: board.seed,
      difficulty: board.difficulty,
      title: 'Daily ${day.month}/${day.day}',
    );
  }

  /// A one-off board of a chosen size, for free play. Ungraded on purpose:
  /// practice is about the size, not the challenge.
  static LevelSpec custom({required int size, required int seed}) {
    return LevelSpec(
      number: seed,
      size: size,
      seed: seed,
      difficulty: switch (size) {
        <= 5 => Difficulty.gentle,
        6 => Difficulty.easy,
        7 => Difficulty.medium,
        8 => Difficulty.hard,
        _ => Difficulty.expert,
      },
      title: '${size}x$size practice',
    );
  }
}
