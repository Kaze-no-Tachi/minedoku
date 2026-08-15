/// How hard a board is expected to be, driven mostly by grid size.
enum Difficulty {
  gentle('Gentle'),
  easy('Easy'),
  medium('Medium'),
  hard('Hard'),
  expert('Expert');

  const Difficulty(this.label);

  final String label;
}

/// Everything needed to rebuild one level: its size and its seed.
///
/// Boards are not shipped as data. A level number maps to a (size, seed) pair,
/// and the generator turns that back into the identical board on every device,
/// so the whole campaign costs no storage at all.
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

  /// Set for special boards such as the daily puzzle.
  final String? title;

  String get displayName => title ?? 'Level $number';

  @override
  String toString() => '$displayName (${size}x$size, ${difficulty.label})';
}

/// The level campaign: an endless run of boards that grow with the player.
abstract final class Levels {
  /// Grid size for a level, ramping 5x5 up to 9x9 and staying there.
  static int sizeForLevel(int level) {
    if (level <= 8) return 5;
    if (level <= 20) return 6;
    if (level <= 40) return 7;
    if (level <= 70) return 8;
    return 9;
  }

  static Difficulty difficultyForLevel(int level) {
    return switch (sizeForLevel(level)) {
      5 => Difficulty.gentle,
      6 => Difficulty.easy,
      7 => Difficulty.medium,
      8 => Difficulty.hard,
      _ => Difficulty.expert,
    };
  }

  /// The spec for campaign level [level] (1-based).
  static LevelSpec forLevel(int level) {
    final n = level < 1 ? 1 : level;
    return LevelSpec(
      number: n,
      size: sizeForLevel(n),
      // An odd multiplier keeps consecutive levels from sharing PRNG state.
      seed: n * 7919 + 13,
      difficulty: difficultyForLevel(n),
    );
  }

  /// A puzzle keyed to a calendar day: everyone gets the same board.
  static LevelSpec daily(DateTime date) {
    final day = DateTime(date.year, date.month, date.day);
    final key = day.year * 10000 + day.month * 100 + day.day;
    // Sizes rotate through 6..9 so dailies stay varied.
    final size = 6 + (key % 4);
    return LevelSpec(
      number: key,
      size: size,
      seed: key * 31 + 7,
      difficulty: switch (size) {
        6 => Difficulty.easy,
        7 => Difficulty.medium,
        8 => Difficulty.hard,
        _ => Difficulty.expert,
      },
      title: 'Daily ${day.month}/${day.day}',
    );
  }

  /// A one-off board of a chosen size, for the practice/free-play mode.
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
