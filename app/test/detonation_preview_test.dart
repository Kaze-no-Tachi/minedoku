// Renders the blast at several moments so the animation can be reviewed as a
// contact sheet. Regenerate with --update-goldens.
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minedoku/theme/app_theme.dart';
import 'package:minedoku/widgets/board_view.dart';
import 'package:minedoku/widgets/detonation.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

void main() {
  testWidgets('blast frames', (tester) async {
    tester.view.physicalSize = const Size(660, 460);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final puzzle = const PuzzleGenerator().generate(size: 5, seed: 3);
    final board = GameBoard(puzzle, autoBlock: false);
    for (final cell in puzzle.solutionCells) {
      board.setMark(cell, CellMark.mine);
    }
    final origins = [
      for (final c in puzzle.solutionCells)
        Offset((c % 5 + 0.5) / 5, (c ~/ 5 + 0.5) / 5),
    ];

    Widget frame() => SizedBox(
          width: 210,
          height: 210,
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Detonation(
              active: true,
              origins: origins,
              child: BoardView(
                board: board,
                theme: GameThemes.enamel,
                interactive: false,
                onTapCell: (_) {},
                onLongPressCell: (_) {},
              ),
            ),
          ),
        );

    await tester.pumpWidget(MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        backgroundColor: const Color(0xFF14121F),
        body: Center(
          child: Wrap(children: [frame(), frame(), frame(), frame(), frame(), frame()]),
        ),
      ),
    ));

    // Each pump advances every frame together, so capture one sheet per moment.
    for (final ms in [120, 200, 320, 500, 900]) {
      await tester.pump(Duration(milliseconds: ms));
      await expectLater(
        find.byType(MaterialApp),
        matchesGoldenFile('goldens/blast_$ms.png'),
      );
    }
  });
}
