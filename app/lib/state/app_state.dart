import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Everything the app remembers between launches: campaign progress, best
/// times, settings and any half-finished board.
///
/// Kept deliberately small. Boards themselves are never stored, because a level
/// number regenerates its board exactly (see `Levels` in the engine).
class AppState extends ChangeNotifier {
  AppState(this._prefs);

  static const _kHighestLevel = 'highest_level';
  static const _kCompleted = 'completed_levels';
  static const _kBestTimePrefix = 'best_time_';
  static const _kAutoBlock = 'auto_block';
  static const _kHaptics = 'haptics';
  static const _kSavedLevel = 'saved_level';
  static const _kSavedMarks = 'saved_marks';
  static const _kSavedSeconds = 'saved_seconds';

  final SharedPreferences _prefs;

  /// Loads state from disk. Call once, before `runApp`.
  static Future<AppState> load() async {
    return AppState(await SharedPreferences.getInstance());
  }

  // ---------------------------------------------------------------- progress

  /// Highest campaign level the player may open (1-based).
  int get highestUnlockedLevel => _prefs.getInt(_kHighestLevel) ?? 1;

  Set<int> get completedLevels =>
      (_prefs.getStringList(_kCompleted) ?? const <String>[])
          .map(int.tryParse)
          .whereType<int>()
          .toSet();

  bool isCompleted(int level) => completedLevels.contains(level);

  /// Best time in seconds for a campaign level, or null if never finished.
  int? bestTime(int level) => _prefs.getInt('$_kBestTimePrefix$level');

  /// Records a win: unlocks the next level and keeps the better time.
  Future<void> recordWin(int level, int seconds) async {
    final completed = completedLevels..add(level);
    await _prefs.setStringList(
      _kCompleted,
      completed.map((e) => e.toString()).toList(),
    );

    if (level + 1 > highestUnlockedLevel) {
      await _prefs.setInt(_kHighestLevel, level + 1);
    }

    final previous = bestTime(level);
    if (previous == null || seconds < previous) {
      await _prefs.setInt('$_kBestTimePrefix$level', seconds);
    }
    notifyListeners();
  }

  /// Wipes progress and settings. Used by the "reset progress" action.
  Future<void> resetProgress() async {
    for (final key in _prefs.getKeys().toList()) {
      if (key.startsWith(_kBestTimePrefix)) await _prefs.remove(key);
    }
    await _prefs.remove(_kHighestLevel);
    await _prefs.remove(_kCompleted);
    await clearSavedGame();
    notifyListeners();
  }

  // ---------------------------------------------------------------- settings

  /// Placing a mine also X's out every cell the rules rule out.
  bool get autoBlock => _prefs.getBool(_kAutoBlock) ?? true;

  Future<void> setAutoBlock(bool value) async {
    await _prefs.setBool(_kAutoBlock, value);
    notifyListeners();
  }

  /// Small vibration on placing, winning and on a mistake.
  bool get haptics => _prefs.getBool(_kHaptics) ?? true;

  Future<void> setHaptics(bool value) async {
    await _prefs.setBool(_kHaptics, value);
    notifyListeners();
  }

  // -------------------------------------------------------------- saved game

  /// Campaign level of the board in progress, if any.
  int? get savedLevel => _prefs.getInt(_kSavedLevel);

  String? get savedMarks => _prefs.getString(_kSavedMarks);

  int get savedSeconds => _prefs.getInt(_kSavedSeconds) ?? 0;

  /// Stores a board in progress so closing the app does not lose it.
  ///
  /// Only campaign levels are resumable; dailies and practice boards are
  /// cheap to restart and would complicate the "Continue" button.
  Future<void> saveGame({
    required int level,
    required String marks,
    required int seconds,
  }) async {
    await _prefs.setInt(_kSavedLevel, level);
    await _prefs.setString(_kSavedMarks, marks);
    await _prefs.setInt(_kSavedSeconds, seconds);
  }

  Future<void> clearSavedGame() async {
    await _prefs.remove(_kSavedLevel);
    await _prefs.remove(_kSavedMarks);
    await _prefs.remove(_kSavedSeconds);
  }
}

/// Makes [AppState] available to the widget tree and rebuilds listeners when it
/// changes. This is Flutter's built-in mechanism, so the app needs no state
/// management package.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({
    super.key,
    required AppState state,
    required super.child,
  }) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree');
    return scope!.notifier!;
  }
}
