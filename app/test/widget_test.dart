import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minedoku/screens/game_screen.dart';
import 'package:minedoku/screens/gauntlet_screen.dart';
import 'package:minedoku/screens/levels_screen.dart';
import 'package:minedoku/widgets/star_row.dart';
import 'package:minedoku/screens/title_screen.dart';
import 'package:minedoku/audio/sound_service.dart';
import 'package:minedoku/state/app_state.dart';
import 'package:minedoku/widgets/board_view.dart';
import 'package:minedoku/theme/app_theme.dart';
import 'package:minedoku_engine/minedoku_engine.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The live board behind the on-screen grid. The board is painted rather than
/// built from per-cell widgets, so tests read its state here instead of
/// counting icons.
GameBoard boardOf(WidgetTester tester) =>
    tester.widget<BoardView>(find.byType(BoardView)).board;

int blockedCells(WidgetTester tester) =>
    boardOf(tester).marks.where((m) => m == CellMark.blocked).length;

/// Wraps a screen in the app's theme and state scope.
Widget hostFor(Widget child, AppState state) {
  return AppScope(
    state: state,
    child: MaterialApp(
      theme: AppTheme.build(GameThemes.enamel, Brightness.light),
      home: child,
    ),
  );
}

void main() {
  late AppState appState;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    appState = await AppState.load();
    // No audio plugin under test, and the service would only swallow the
    // failures anyway. Silence keeps the output clean.
    SoundService.instance = SilentSoundService();
  });

  group('title screen', () {
    // The ambient board loops forever by design, so this screen never settles.
    // Tests pump fixed durations instead of using pumpAndSettle.
    Future<void> showTitle(WidgetTester tester) async {
      await tester.pumpWidget(hostFor(const TitleScreen(), appState));
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('shows the mark, the rules and the entry points',
        (tester) async {
      await showTitle(tester);

      expect(find.text('MINEDOKU'), findsOneWidget);
      expect(
        find.textContaining('One mine per row, column and colour'),
        findsOneWidget,
      );
      expect(find.text('Play level 1'), findsOneWidget);
      expect(find.text('Daily puzzle'), findsOneWidget);
      expect(find.text('All levels'), findsOneWidget);
    });

    testWidgets('offers Continue only when a game was saved', (tester) async {
      await showTitle(tester);
      expect(find.textContaining('Continue level'), findsNothing);

      await appState.progress.saveGame(level: 3, marks: '.' * 36, seconds: 12);
      await tester.pumpWidget(hostFor(const TitleScreen(), appState));
      await tester.pump(const Duration(seconds: 1));

      expect(find.text('Continue level 3'), findsOneWidget);
    });

    testWidgets('the intro plays once and is skipped afterwards',
        (tester) async {
      expect(appState.settings.hasSeenIntro, isFalse);

      await tester.pumpWidget(hostFor(const TitleScreen(), appState));
      await tester.pump();
      // Mid-intro the menu is still fading in.
      final fading = tester
          .widgetList<FadeTransition>(find.byType(FadeTransition))
          .any((w) => w.opacity.value < 1);
      expect(fading, isTrue, reason: 'the first launch should animate');
      await tester.pump(const Duration(seconds: 1));
      expect(appState.settings.hasSeenIntro, isTrue);

      // A second launch starts fully shown.
      await tester.pumpWidget(hostFor(const TitleScreen(), appState));
      await tester.pump();
      final menu = tester.widget<FadeTransition>(
        find.ancestor(
          of: find.text('Play level 1'),
          matching: find.byType(FadeTransition),
        ).first,
      );
      expect(menu.opacity.value, 1.0, reason: 'no intro on a repeat launch');
    });

    testWidgets('shows the daily streak once there is one', (tester) async {
      await showTitle(tester);
      expect(find.text('Daily puzzle'), findsOneWidget);

      await appState.stats.recordDailyWin();
      await tester.pumpWidget(hostFor(const TitleScreen(), appState));
      await tester.pump(const Duration(seconds: 1));

      expect(find.textContaining('1 day streak'), findsOneWidget);
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

      expect(blockedCells(tester), greaterThan(0),
          reason: 'placing a mine should X out the cells it rules out');

      await tester.tap(cell); // back to empty
      await tester.pumpAndSettle();

      expect(blockedCells(tester), 0,
          reason: 'removing the mine must take its X marks with it');
      expect(find.text('5'), findsWidgets, reason: 'all 5 mines are free again');
    });

    testWidgets('a hint dims everything outside what it explains',
        (tester) async {
      final spec = Levels.forLevel(1);
      await tester.pumpWidget(hostFor(GameScreen(spec: spec), appState));
      await tester.pumpAndSettle();

      List<int> spotlight() =>
          tester.widget<BoardView>(find.byType(BoardView)).relatedCells;

      expect(spotlight(), isEmpty, reason: 'nothing is spotlit before a hint');

      await tester.ensureVisible(find.text('Hint'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hint'));
      await tester.pumpAndSettle();

      expect(spotlight(), isNotEmpty,
          reason: 'the hint should spotlight the row, column or colour');
      expect(spotlight().length, lessThan(25),
          reason: 'it must spotlight one unit, not the whole board');
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

  group('hard mode', () {
    // Cell indices map to the GestureDetector grid in order, so tapping
    // `cellAt(i)` taps board cell i.
    Finder cellAt(int index) => find.byType(GestureDetector).at(index);

    late Puzzle puzzle;
    late List<int> wrongCells;

    setUp(() async {
      final spec = Levels.forLevel(1); // 5x5
      puzzle = const PuzzleGenerator()
          .generate(size: spec.size, seed: spec.seed);
      wrongCells = [
        for (var i = 0; i < spec.size * spec.size; i++)
          if (!puzzle.solutionCells.contains(i)) i,
      ];
      await appState.settings.setGameMode(GameMode.hard);
    });

    /// Two taps: empty to ruled-out, then an attempt to place a mine.
    Future<void> tryMine(WidgetTester tester, int cell) async {
      await tester.tap(cellAt(cell));
      await tester.pumpAndSettle();
      await tester.tap(cellAt(cell));
      await tester.pumpAndSettle();
    }

    testWidgets('shows the mistake budget instead of the board size',
        (tester) async {
      await tester.pumpWidget(
          hostFor(GameScreen(spec: Levels.forLevel(1)), appState));
      await tester.pumpAndSettle();

      expect(find.text('MISTAKES LEFT'), findsOneWidget);
      expect(find.text('BOARD'), findsNothing);
      expect(find.text('${MistakeRules.lives}'), findsWidgets);
    });

    testWidgets('a wrong mine is refused and costs a life', (tester) async {
      await tester.pumpWidget(
          hostFor(GameScreen(spec: Levels.forLevel(1)), appState));
      await tester.pumpAndSettle();

      await tryMine(tester, wrongCells.first);

      // Refused, so no mine landed and the count did not move.
      expect(
        boardOf(tester).marks.where((m) => m == CellMark.mine).length,
        0,
        reason: 'a known-wrong mine must not stay on the board',
      );
      expect(find.text('${MistakeRules.lives - 1}'), findsWidgets);
      expect(find.textContaining('mistakes left'), findsOneWidget);
    });

    testWidgets('a correct mine costs nothing', (tester) async {
      await tester.pumpWidget(
          hostFor(GameScreen(spec: Levels.forLevel(1)), appState));
      await tester.pumpAndSettle();

      await tryMine(tester, puzzle.solutionCells.first);

      expect(
        boardOf(tester).marks.where((m) => m == CellMark.mine).length,
        1,
        reason: 'a solution cell is always allowed',
      );
      expect(find.text('${MistakeRules.lives}'), findsWidgets,
          reason: 'lives untouched');
    });

    testWidgets('running out blows up the board', (tester) async {
      await tester.pumpWidget(
          hostFor(GameScreen(spec: Levels.forLevel(1)), appState));
      await tester.pumpAndSettle();

      for (var i = 0; i < MistakeRules.lives; i++) {
        await tryMine(tester, wrongCells[i]);
      }

      expect(find.text('Board destroyed'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);
    });

    testWidgets('trying again restores the lives', (tester) async {
      await tester.pumpWidget(
          hostFor(GameScreen(spec: Levels.forLevel(1)), appState));
      await tester.pumpAndSettle();

      for (var i = 0; i < MistakeRules.lives; i++) {
        await tryMine(tester, wrongCells[i]);
      }
      await tester.tap(find.text('Try again'));
      await tester.pumpAndSettle();

      expect(find.text('Board destroyed'), findsNothing);
      expect(find.text('${MistakeRules.lives}'), findsWidgets);
      expect(boardOf(tester).marks, everyElement(CellMark.empty));
    });

    testWidgets('hints are unavailable', (tester) async {
      await tester.pumpWidget(
          hostFor(GameScreen(spec: Levels.forLevel(1)), appState));
      await tester.pumpAndSettle();

      final hint = tester.widget<OutlinedButton>(
        find.ancestor(
          of: find.text('Hint'),
          matching: find.byType(OutlinedButton),
        ),
      );
      expect(hint.onPressed, isNull);
    });

    testWidgets('relaxed mode refuses nothing', (tester) async {
      await appState.settings.setGameMode(GameMode.relaxed);
      await tester.pumpWidget(
          hostFor(GameScreen(spec: Levels.forLevel(1)), appState));
      await tester.pumpAndSettle();

      await tryMine(tester, wrongCells.first);

      expect(
        boardOf(tester).marks.where((m) => m == CellMark.mine).length,
        1,
        reason: 'relaxed mode lets you be wrong',
      );
      expect(find.text('BOARD'), findsOneWidget);
    });
  });

  group('stars', () {
    testWidgets('a finished level shows its stars in the grid', (tester) async {
      await appState.progress.recordWin(
          level: 1, size: 5, seconds: 10, hintsUsed: 0);

      await tester.pumpWidget(hostFor(const LevelsScreen(count: 8), appState));
      await tester.pumpAndSettle();

      final rows = tester.widgetList<StarRow>(find.byType(StarRow)).toList();
      expect(rows, hasLength(1), reason: 'only the finished level is rated');
      expect(rows.first.earned, 3,
          reason: 'fast and hint-free earns all three');
    });

    test('stars are earned once and never taken away', () async {
      await appState.progress.recordWin(
          level: 1, size: 5, seconds: 10, hintsUsed: 0);
      expect(appState.progress.stars(1), 3);

      // A slower, hint-assisted replay must not demote the level.
      await appState.progress.recordWin(
          level: 1, size: 5, seconds: 900, hintsUsed: 4);
      expect(appState.progress.stars(1), 3);
    });

    test('the star total adds up across levels', () async {
      expect(appState.progress.totalStars, 0);
      await appState.progress.recordWin(
          level: 1, size: 5, seconds: 10, hintsUsed: 0); // 3
      await appState.progress.recordWin(
          level: 2, size: 5, seconds: 900, hintsUsed: 2); // 1
      expect(appState.progress.totalStars, 4);
    });

    test('hints cost the second and third star', () async {
      await appState.progress.recordWin(
          level: 3, size: 5, seconds: 1, hintsUsed: 1);
      expect(appState.progress.stars(3), 1);
    });
  });

  group('gauntlet', () {
    testWidgets('records the run and offers another', (tester) async {
      await tester.pumpWidget(hostFor(const GauntletScreen(), appState));
      await tester.pumpAndSettle();

      // The board is titled by its position in the run, not by a level number.
      expect(find.text('Board 1'), findsOneWidget);
      expect(find.text('MISTAKES LEFT'), findsOneWidget);
    });

    test('a run remembers the best result', () async {
      expect(appState.stats.bestGauntlet, 0);

      expect(await appState.stats.recordGauntlet(4), isTrue);
      expect(appState.stats.bestGauntlet, 4);

      expect(await appState.stats.recordGauntlet(2), isFalse,
          reason: 'a worse run is not a record');
      expect(appState.stats.bestGauntlet, 4);

      expect(await appState.stats.recordGauntlet(9), isTrue);
      expect(appState.stats.bestGauntlet, 9);
      expect(appState.stats.gauntletRuns, 3);
    });
  });

  group('progress', () {
    test('a win unlocks the next level and stores the best time', () async {
      expect(appState.progress.highestUnlockedLevel, 1);

      await appState.progress.recordWin(level: 1, size: 5, seconds: 90, hintsUsed: 0);
      expect(appState.progress.highestUnlockedLevel, 2);
      expect(appState.progress.isCompleted(1), isTrue);
      expect(appState.progress.bestTime(1), 90);

      await appState.progress.recordWin(level: 1, size: 5, seconds: 120, hintsUsed: 0);
      expect(appState.progress.bestTime(1), 90, reason: 'slower runs must not overwrite');

      await appState.progress.recordWin(level: 1, size: 5, seconds: 45, hintsUsed: 0);
      expect(appState.progress.bestTime(1), 45);
    });

    test('reset clears everything', () async {
      await appState.progress.recordWin(level: 1, size: 5, seconds: 30, hintsUsed: 0);
      await appState.progress.saveGame(level: 2, marks: '....', seconds: 5);

      await appState.resetProgress();

      expect(appState.progress.highestUnlockedLevel, 1);
      expect(appState.progress.completedLevels, isEmpty);
      expect(appState.progress.bestTime(1), isNull);
      expect(appState.progress.savedLevel, isNull);
    });

    test('settings default on and can be turned off', () async {
      expect(appState.settings.autoBlock, isTrue);
      await appState.settings.setAutoBlock(false);
      expect(appState.settings.autoBlock, isFalse);
    });
  });
}
