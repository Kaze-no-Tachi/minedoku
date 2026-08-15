import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minedoku/theme/app_theme.dart';
import 'package:minedoku/widgets/board_view.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

/// Renders every theme to a golden image.
///
/// Regenerate after a deliberate visual change:
///
///   flutter test test/theme_preview_test.dart --update-goldens
///
/// The value here is less about catching pixel drift and more about having a
/// single sheet that shows what every theme actually looks like, patterns on
/// and off, without clicking through the app.
void main() {
  final puzzle = Puzzle(
    size: 5,
    regions: const [
      0, 0, 1, 1, 1, //
      0, 2, 2, 1, 3, //
      4, 2, 2, 3, 3, //
      4, 4, 5, 5, 3, //
      6, 6, 7, 8, 8, //
    ],
    solution: const [1, 4, 0, 2, 4],
  );

  Widget preview(GameTheme theme, {required bool patterns}) {
    final board = GameBoard(puzzle, autoBlock: true);
    // A part-played board: some mines down, some cells ruled out, so the
    // preview shows every mark a theme has to render.
    board.setMark(1, CellMark.mine);
    board.setMark(14, CellMark.mine);

    return SizedBox(
      width: 190,
      height: 190,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: BoardView(
          board: board,
          theme: theme,
          showPatterns: patterns,
          interactive: false,
          onTapCell: (_) {},
          onLongPressCell: (_) {},
        ),
      ),
    );
  }

  testWidgets('every theme, with and without patterns', (tester) async {
    tester.view.physicalSize = const Size(800, 1120);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: AppTheme.build(GameThemes.enamel, Brightness.light),
        home: Scaffold(
          backgroundColor: const Color(0xFFF2F0F6),
          body: SingleChildScrollView(
            child: Column(
              children: [
                for (final theme in GameThemes.all)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      preview(theme, patterns: false),
                      preview(theme, patterns: true),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/themes.png'),
    );
  });
}
