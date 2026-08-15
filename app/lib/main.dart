import 'package:flutter/material.dart';

import 'audio/sound_service.dart';
import 'screens/title_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Progress and settings are read once, up front, so no screen has to deal
  // with a "not loaded yet" state.
  final appState = await AppState.load();
  // Players are created up front so the first tap is not the one that pays for
  // it. Failures here are swallowed by the service.
  SoundService.instance.enabled = appState.settings.sound;
  await SoundService.instance.warmUp();
  runApp(MinedokuApp(appState: appState));
}

class MinedokuApp extends StatelessWidget {
  const MinedokuApp({super.key, required this.appState});

  final AppState appState;

  @override
  Widget build(BuildContext context) {
    return AppScope(
      state: appState,
      // Rebuilt on any settings change so switching theme repaints the whole
      // app, not just the board.
      child: ListenableBuilder(
        listenable: appState,
        builder: (context, _) {
          final game = appState.gameTheme;
          return MaterialApp(
            title: 'Minedoku',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.build(game, Brightness.light),
            darkTheme: AppTheme.build(game, Brightness.dark),
            home: const TitleScreen(),
          );
        },
      ),
    );
  }
}
