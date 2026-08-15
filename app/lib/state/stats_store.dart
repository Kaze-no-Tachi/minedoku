import 'package:flutter/widgets.dart';
import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Lifetime totals for one board size.
class SizeStats {
  const SizeStats({
    required this.size,
    required this.played,
    required this.won,
    required this.bestSeconds,
    required this.totalSeconds,
  });

  final int size;
  final int played;
  final int won;
  final int? bestSeconds;
  final int totalSeconds;

  int? get averageSeconds => won == 0 ? null : totalSeconds ~/ won;

  double get winRate => played == 0 ? 0 : won / played;
}

/// Lifetime play statistics and the daily streak.
///
/// Separate from progress: wiping the campaign should not erase a year of
/// history, and vice versa.
class StatsStore extends ChangeNotifier {
  StatsStore(this._prefs);

  static const _kPlayed = 'stat_played_';
  static const _kWon = 'stat_won_';
  static const _kBest = 'stat_best_';
  static const _kTotalTime = 'stat_total_time_';
  static const _kHints = 'stat_hints';
  static const _kStreakCurrent = 'streak_current';
  static const _kStreakLongest = 'streak_longest';
  static const _kStreakLastDay = 'streak_last_day';

  /// Sizes the game ships, smallest first.
  static const List<int> sizes = [5, 6, 7, 8, 9];

  final SharedPreferences _prefs;

  // ------------------------------------------------------------------ totals

  int played(int size) => _prefs.getInt('$_kPlayed$size') ?? 0;

  int won(int size) => _prefs.getInt('$_kWon$size') ?? 0;

  int? best(int size) => _prefs.getInt('$_kBest$size');

  int totalSeconds(int size) => _prefs.getInt('$_kTotalTime$size') ?? 0;

  int get hintsUsed => _prefs.getInt(_kHints) ?? 0;

  SizeStats statsFor(int size) => SizeStats(
        size: size,
        played: played(size),
        won: won(size),
        bestSeconds: best(size),
        totalSeconds: totalSeconds(size),
      );

  List<SizeStats> get allStats => [for (final s in sizes) statsFor(s)];

  int get totalPlayed => sizes.fold(0, (sum, s) => sum + played(s));

  int get totalWon => sizes.fold(0, (sum, s) => sum + won(s));

  int get totalTimePlayed => sizes.fold(0, (sum, s) => sum + totalSeconds(s));

  /// Counts a board that was opened. Called once per board, not per attempt.
  Future<void> recordStart(int size) async {
    await _prefs.setInt('$_kPlayed$size', played(size) + 1);
    notifyListeners();
  }

  Future<void> recordWin({
    required int size,
    required int seconds,
    required int hints,
  }) async {
    await _prefs.setInt('$_kWon$size', won(size) + 1);
    await _prefs.setInt('$_kTotalTime$size', totalSeconds(size) + seconds);
    await _prefs.setInt(_kHints, hintsUsed + hints);

    final previous = best(size);
    if (previous == null || seconds < previous) {
      await _prefs.setInt('$_kBest$size', seconds);
    }
    notifyListeners();
  }

  // ------------------------------------------------------------------ streak

  Streak get streak => Streak(
        current: _prefs.getInt(_kStreakCurrent) ?? 0,
        longest: _prefs.getInt(_kStreakLongest) ?? 0,
        lastDay: _prefs.getInt(_kStreakLastDay),
      );

  /// Streak as it stands today, which is 0 once a run has lapsed.
  int currentStreak([DateTime? today]) =>
      streak.currentAsOf(today ?? DateTime.now());

  int get longestStreak => streak.longest;

  bool playedDaily([DateTime? day]) => streak.hasPlayed(day ?? DateTime.now());

  /// Records a finished daily puzzle. The arithmetic lives in the engine.
  Future<void> recordDailyWin([DateTime? day]) async {
    final next = streak.recordWin(day ?? DateTime.now());
    await _prefs.setInt(_kStreakCurrent, next.current);
    await _prefs.setInt(_kStreakLongest, next.longest);
    if (next.lastDay != null) {
      await _prefs.setInt(_kStreakLastDay, next.lastDay!);
    }
    notifyListeners();
  }

  Future<void> reset() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith('stat_') || key.startsWith('streak_')) {
        await _prefs.remove(key);
      }
    }
    notifyListeners();
  }
}
