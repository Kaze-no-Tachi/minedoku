import 'package:flutter/widgets.dart';
import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// How well a level was finished.
///
/// Stars are earned once and kept: a later, sloppier run never takes one away.
class LevelResult {
  const LevelResult({
    required this.seconds,
    required this.hintsUsed,
    required this.stars,
  });

  final int seconds;
  final int hintsUsed;

  /// 1 for finishing, 2 for finishing without hints, 3 for also beating the
  /// target time for that board size.
  final int stars;

  static int starsFor({
    required int seconds,
    required int hintsUsed,
    required int size,
  }) {
    var earned = 1;
    if (hintsUsed == 0) earned++;
    if (hintsUsed == 0 && seconds <= targetSeconds(size)) earned++;
    return earned;
  }

  /// A pace a comfortable player can hit without rushing. Roughly quadratic,
  /// because the search space grows with the square of the board.
  static int targetSeconds(int size) => size * size * 2;
}

/// Campaign progress: what is unlocked, what is finished, and how well.
class ProgressStore extends ChangeNotifier {
  ProgressStore(this._prefs);

  static const _kHighestLevel = 'highest_level';
  static const _kCompleted = 'completed_levels';
  static const _kBestTimePrefix = 'best_time_';
  static const _kStarsPrefix = 'stars_';
  static const _kHintsPrefix = 'best_hints_';
  static const _kSavedLevel = 'saved_level';
  static const _kSavedMarks = 'saved_marks';
  static const _kSavedSeconds = 'saved_seconds';
  static const _kDailyDay = 'daily_saved_day';
  static const _kDailyMarks = 'daily_saved_marks';
  static const _kDailySeconds = 'daily_saved_seconds';

  final SharedPreferences _prefs;

  /// Highest campaign level the player may open (1-based).
  int get highestUnlockedLevel => _prefs.getInt(_kHighestLevel) ?? 1;

  Set<int> get completedLevels =>
      (_prefs.getStringList(_kCompleted) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  bool isCompleted(int level) => completedLevels.contains(level);

  /// Best time in seconds for a level, or null if never finished.
  int? bestTime(int level) => _prefs.getInt('$_kBestTimePrefix$level');

  /// Best star rating earned on a level, 0 when unfinished.
  int stars(int level) => _prefs.getInt('$_kStarsPrefix$level') ?? 0;

  int? fewestHints(int level) => _prefs.getInt('$_kHintsPrefix$level');

  /// Stars earned across every level. The number the star chase is about.
  int get totalStars {
    var sum = 0;
    for (final key in _prefs.getKeys()) {
      if (key.startsWith(_kStarsPrefix)) sum += _prefs.getInt(key) ?? 0;
    }
    return sum;
  }

  /// Records a win: unlocks the next level and keeps every personal best.
  Future<void> recordWin({
    required int level,
    required int size,
    required int seconds,
    required int hintsUsed,
  }) async {
    final completed = completedLevels..add(level);
    await _prefs.setStringList(
      _kCompleted,
      completed.map((e) => e.toString()).toList(),
    );

    if (level + 1 > highestUnlockedLevel) {
      await _prefs.setInt(_kHighestLevel, level + 1);
    }

    final previousTime = bestTime(level);
    if (previousTime == null || seconds < previousTime) {
      await _prefs.setInt('$_kBestTimePrefix$level', seconds);
    }

    final previousHints = fewestHints(level);
    if (previousHints == null || hintsUsed < previousHints) {
      await _prefs.setInt('$_kHintsPrefix$level', hintsUsed);
    }

    final earned = LevelResult.starsFor(
      seconds: seconds,
      hintsUsed: hintsUsed,
      size: size,
    );
    if (earned > stars(level)) {
      await _prefs.setInt('$_kStarsPrefix$level', earned);
    }
    notifyListeners();
  }

  // -------------------------------------------------------------- saved game

  /// Campaign level of the board in progress, if any.
  int? get savedLevel => _prefs.getInt(_kSavedLevel);

  String? get savedMarks => _prefs.getString(_kSavedMarks);

  int get savedSeconds => _prefs.getInt(_kSavedSeconds) ?? 0;

  /// Stores a board in progress so closing the app does not lose it.
  ///
  /// Only a change of *which* level is saved notifies listeners. Autosave runs
  /// on every move, and telling the whole app about each one would rebuild it
  /// constantly; but the title screen has to learn when a resumable game
  /// appears, or its Continue button never shows up.
  Future<void> saveGame({
    required int level,
    required String marks,
    required int seconds,
  }) async {
    final changed = savedLevel != level;
    await _prefs.setInt(_kSavedLevel, level);
    await _prefs.setString(_kSavedMarks, marks);
    await _prefs.setInt(_kSavedSeconds, seconds);
    if (changed) notifyListeners();
  }

  Future<void> clearSavedGame() async {
    final had = savedLevel != null;
    await _prefs.remove(_kSavedLevel);
    await _prefs.remove(_kSavedMarks);
    await _prefs.remove(_kSavedSeconds);
    if (had) notifyListeners();
  }

  // -------------------------------------------------------- saved daily board

  /// The daily gets its own slot rather than sharing the campaign one.
  ///
  /// There is exactly one daily board a day, so leaving it half-finished and
  /// losing the work is a much worse outcome than on a campaign level, which
  /// can simply be opened again.

  /// Marks for today's daily, or null when there is no usable save.
  ///
  /// A save from an earlier day is ignored: that board is gone, and restoring
  /// its marks onto today's would be nonsense.
  String? savedDailyMarks(DateTime day) =>
      _prefs.getInt(_kDailyDay) == DayKey.of(day)
          ? _prefs.getString(_kDailyMarks)
          : null;

  int savedDailySeconds(DateTime day) =>
      _prefs.getInt(_kDailyDay) == DayKey.of(day)
          ? _prefs.getInt(_kDailySeconds) ?? 0
          : 0;

  Future<void> saveDaily({
    required DateTime day,
    required String marks,
    required int seconds,
  }) async {
    await _prefs.setInt(_kDailyDay, DayKey.of(day));
    await _prefs.setString(_kDailyMarks, marks);
    await _prefs.setInt(_kDailySeconds, seconds);
  }

  Future<void> clearSavedDaily() async {
    await _prefs.remove(_kDailyDay);
    await _prefs.remove(_kDailyMarks);
    await _prefs.remove(_kDailySeconds);
  }

  /// Wipes campaign progress. Settings and lifetime stats are untouched.
  Future<void> reset() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith(_kBestTimePrefix) ||
          key.startsWith(_kStarsPrefix) ||
          key.startsWith(_kHintsPrefix)) {
        await _prefs.remove(key);
      }
    }
    await _prefs.remove(_kHighestLevel);
    await _prefs.remove(_kCompleted);
    await clearSavedGame();
    notifyListeners();
  }
}
