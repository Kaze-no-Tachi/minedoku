import 'package:flutter/widgets.dart';
import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// When the board draws a distinct pattern in each colour region.
///
/// Patterns are the accessible channel: colour alone cannot separate nine
/// regions for every form of colour blindness, but shape can.
enum PatternMode {
  /// On for themes whose palette is not colour-blind safe on its own.
  auto,

  /// Always on, whatever the theme.
  always,

  /// Never, for players who find them busy.
  never;

  String get label => switch (this) {
        PatternMode.auto => 'Automatic',
        PatternMode.always => 'Always on',
        PatternMode.never => 'Off',
      };

  String get description => switch (this) {
        PatternMode.auto =>
          'Shown for themes whose colours need the extra help.',
        PatternMode.always => 'Shown in every theme.',
        PatternMode.never => 'Colour only.',
      };
}

/// Player preferences. Everything here is a choice, not progress.
class SettingsStore extends ChangeNotifier {
  SettingsStore(this._prefs);

  static const _kTheme = 'theme_id';
  static const _kPatterns = 'pattern_mode';
  static const _kAutoBlock = 'auto_block';
  static const _kHaptics = 'haptics';
  static const _kSound = 'sound';
  static const _kShowTimer = 'show_timer';
  static const _kSeenIntro = 'seen_intro';
  static const _kSeenTutorial = 'seen_tutorial';
  static const _kMode = 'game_mode';

  final SharedPreferences _prefs;

  /// Id of the chosen [GameTheme]. Defaults to the built-in one.
  String get themeId => _prefs.getString(_kTheme) ?? 'enamel';

  Future<void> setThemeId(String value) => _write(_kTheme, value);

  PatternMode get patternMode {
    final stored = _prefs.getString(_kPatterns);
    return PatternMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => PatternMode.auto,
    );
  }

  Future<void> setPatternMode(PatternMode value) =>
      _write(_kPatterns, value.name);

  /// Difficulty applied to new boards.
  ///
  /// Read once when a board opens, so changing it never moves the goalposts
  /// under a game already in progress.
  GameMode get gameMode {
    final stored = _prefs.getString(_kMode);
    return GameMode.values.firstWhere(
      (m) => m.name == stored,
      orElse: () => GameMode.relaxed,
    );
  }

  Future<void> setGameMode(GameMode value) => _write(_kMode, value.name);

  /// Placing a mine also X's out every cell the rules now forbid.
  bool get autoBlock => _prefs.getBool(_kAutoBlock) ?? true;

  Future<void> setAutoBlock(bool value) => _write(_kAutoBlock, value);

  bool get haptics => _prefs.getBool(_kHaptics) ?? true;

  Future<void> setHaptics(bool value) => _write(_kHaptics, value);

  bool get sound => _prefs.getBool(_kSound) ?? true;

  Future<void> setSound(bool value) => _write(_kSound, value);

  /// Some players find a running clock stressful. The time is still recorded.
  bool get showTimer => _prefs.getBool(_kShowTimer) ?? true;

  Future<void> setShowTimer(bool value) => _write(_kShowTimer, value);

  /// The title animation plays on first launch only. Seen forty times, it is
  /// just latency.
  bool get hasSeenIntro => _prefs.getBool(_kSeenIntro) ?? false;

  Future<void> setHasSeenIntro(bool value) => _write(_kSeenIntro, value);

  bool get hasSeenTutorial => _prefs.getBool(_kSeenTutorial) ?? false;

  Future<void> setHasSeenTutorial(bool value) => _write(_kSeenTutorial, value);

  Future<void> _write(String key, Object value) async {
    switch (value) {
      case final bool v:
        await _prefs.setBool(key, v);
      case final String v:
        await _prefs.setString(key, v);
      case final int v:
        await _prefs.setInt(key, v);
    }
    notifyListeners();
  }
}
