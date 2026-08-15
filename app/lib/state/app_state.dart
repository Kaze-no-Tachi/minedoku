import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'progress_store.dart';
import 'settings_store.dart';
import 'stats_store.dart';

export 'progress_store.dart';
export 'settings_store.dart';
export 'stats_store.dart';

/// Everything the app remembers between launches, in three stores that own
/// clearly different things: what the player chose, how far they have got, and
/// what they have done overall.
///
/// The three share one [SharedPreferences] instance and re-broadcast their
/// changes through this object, so the widget tree still listens to exactly one
/// notifier.
class AppState extends ChangeNotifier {
  AppState({
    required this.settings,
    required this.progress,
    required this.stats,
  }) {
    settings.addListener(notifyListeners);
    progress.addListener(notifyListeners);
    stats.addListener(notifyListeners);
  }

  final SettingsStore settings;
  final ProgressStore progress;
  final StatsStore stats;

  /// Loads state from disk. Call once, before `runApp`.
  static Future<AppState> load() async {
    final prefs = await SharedPreferences.getInstance();
    return AppState(
      settings: SettingsStore(prefs),
      progress: ProgressStore(prefs),
      stats: StatsStore(prefs),
    );
  }

  /// Clears campaign progress, lifetime stats and first-run state.
  ///
  /// Preferences survive on purpose: someone resetting their progress wants a
  /// fresh run, not their theme and accessibility choices thrown away. Having
  /// seen the intro and the tutorial is not a preference though, it is first-run
  /// state, and a reset is exactly what you reach for when handing the game to
  /// somebody new, so those two go.
  Future<void> resetProgress() async {
    await progress.reset();
    await stats.reset();
    await settings.forgetFirstRun();
  }

  @override
  void dispose() {
    settings.removeListener(notifyListeners);
    progress.removeListener(notifyListeners);
    stats.removeListener(notifyListeners);
    super.dispose();
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
