import 'package:flutter/material.dart';

import 'screens/home_screen.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Progress and settings are read once, up front, so no screen has to deal
  // with a "not loaded yet" state.
  final appState = await AppState.load();
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
            home: const HomeScreen(),
          );
        },
      ),
    );
  }
}
