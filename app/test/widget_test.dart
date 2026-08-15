import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minedoku/screens/game_screen.dart';
import 'package:minedoku/screens/home_screen.dart';
import 'package:minedoku/state/app_state.dart';
import 'package:minedoku/theme.dart';
import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Wraps a screen in the app's theme and state scope.
Widget hostFor(Widget child, AppState state) {
  return AppScope(
    state: state,
    child: MaterialApp(
      theme: MinedokuTheme.light(),
      home: child,
    ),
  );
}

void main() {
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    appState = await AppState.load();
  });

  group('home screen', () {
    testWidgets('shows the title, the rules and the entry points',
        (tester) async {
      await tester.pumpWidget(hostFor(const HomeScreen(), appState));

      expect(find.text('MINEDOKU'), findsOneWidget);
      expect(find.text('Play level 1'), findsOneWidget);
      expect(find.text('Daily puzzle'), findsOneWidget);
      expect(find.text('All levels'), findsOneWidget);
      for (final rule in MinedokuRules.summaries) {
        expect(find.text(rule), findsOneWidget);
      }
    });

    testWidgets('offers Continue only when a game was saved', (tester) async {
      await tester.pumpWidget(hostFor(const HomeScreen(), appState));
      expect(find.textContaining('Continue level'), findsNothing);

      await appState.saveGame(level: 3, marks: '.' * 36, seconds: 12);
      await tester.pumpWidget(hostFor(const HomeScreen(), appState));
      await tester.pump();

      expect(find.text('Continue level 3'), findsOneWidget);
    });
  });

  group('game screen', () {
    testWidgets('builds a board and reports mines left', (tester) async {
      final spec = Levels.forLevel(1); // 5x5
      await tester.pumpWidget(hostFor(GameScreen(spec: spec), appState));
      await tester.pumpAndSettle();

      expect(find.text('Level 1'), findsOneWidget);
      expect(find.text('MINES LEFT'), findsOneWidget);
      expect(find.text('5'), findsWidgets);
      expect(find.text('5x5'), findsOneWidget);
    });

    testWidgets('tapping a cell twice places a mine', (tester) async {
      final spec = Levels.forLevel(1);
      await tester.pumpWidget(hostFor(GameScreen(spec: spec), appState));
      await tester.pumpAndSettle();

      final cell = find.byType(GestureDetector).first;
      await tester.tap(cell);
      await tester.pumpAndSettle();
      await tester.tap(cell);
      await tester.pumpAndSettle();

      // One mine down, so four remain on a 5x5 board.
      expect(find.text('4'), findsWidgets);
    });

    testWidgets('removing a mine clears the marks it caused', (tester) async {
      final spec = Levels.forLevel(1); // 5x5
      await tester.pumpWidget(hostFor(GameScreen(spec: spec), appState));
      await tester.pumpAndSettle();

      final cell = find.byType(GestureDetector).first;
      await tester.tap(cell); // X
      await tester.pumpAndSettle();
      await tester.tap(cell); // mine, which auto-marks the cells it rules out
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsWidgets,
          reason: 'placing a mine should X out the cells it rules out');

      await tester.tap(cell); // back to empty
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.close_rounded), findsNothing,
          reason: 'removing the mine must take its X marks with it');
      expect(find.text('5'), findsWidgets, reason: 'all 5 mines are free again');
    });

    testWidgets('a hint dims everything outside what it explains',
        (tester) async {
      final spec = Levels.forLevel(1);
      await tester.pumpWidget(hostFor(GameScreen(spec: spec), appState));
      await tester.pumpAndSettle();

      int dimmed() => tester
          .widgetList<AnimatedOpacity>(find.byType(AnimatedOpacity))
          .where((w) => w.opacity < 1)
          .length;

      expect(dimmed(), 0, reason: 'nothing is dimmed before a hint');

      await tester.ensureVisible(find.text('Hint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();

      expect(dimmed(), greaterThan(0),
          reason: 'the hint should spotlight the row, column or colour');
      expect(dimmed(), lessThan(25), reason: 'it must not dim the whole board');
    });

    testWidgets('the hint button explains a move', (tester) async {
      final spec = Levels.forLevel(1);
      await tester.pumpWidget(hostFor(GameScreen(spec: spec), appState));
      await tester.pumpAndSettle();

      // The controls sit below the fold in the default test viewport.
      await tester.ensureVisible(find.text('Hint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();

      // No static label on this screen contains a full stop, so finding one
      // means the engine's explanation was rendered.
      expect(find.textContaining('.'), findsWidgets);
    });

    testWidgets('undo is disabled until a move is made', (tester) async {
      final spec = Levels.forLevel(1);
      await tester.pumpWidget(hostFor(GameScreen(spec: spec), appState));
      await tester.pumpAndSettle();

      OutlinedButton undoButton() => tester.widget<OutlinedButton>(
            find.ancestor(
              of: find.text('Undo'),
              matching: find.byType(OutlinedButton),
            ),
          );

      expect(undoButton().onPressed, isNull);

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pumpAndSettle();

      expect(undoButton().onPressed, isNotNull);
    });
  });

  group('progress', () {
    test('a win unlocks the next level and stores the best time', () async {
      expect(appState.highestUnlockedLevel, 1);

      await appState.recordWin(1, 90);
      expect(appState.highestUnlockedLevel, 2);
      expect(appState.isCompleted(1), isTrue);
      expect(appState.bestTime(1), 90);

      await appState.recordWin(1, 120);
      expect(appState.bestTime(1), 90, reason: 'slower runs must not overwrite');

      await appState.recordWin(1, 45);
      expect(appState.bestTime(1), 45);
    });

    test('reset clears everything', () async {
      await appState.recordWin(1, 30);
      await appState.saveGame(level: 2, marks: '....', seconds: 5);

      await appState.resetProgress();

      expect(appState.highestUnlockedLevel, 1);
      expect(appState.completedLevels, isEmpty);
      expect(appState.bestTime(1), isNull);
      expect(appState.savedLevel, isNull);
    });

    test('settings default on and can be turned off', () async {
      expect(appState.autoBlock, isTrue);
      await appState.setAutoBlock(false);
      expect(appState.autoBlock, isFalse);
    });
  });
}
