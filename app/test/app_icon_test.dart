import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minedoku/theme/app_theme.dart';
import 'package:minedoku/widgets/mine_icon.dart';

/// Draws the launcher icon from the same glyph the board uses, and writes it to
/// `assets/icon/`.
///
/// Regenerate after changing the mark:
///
///   flutter test test/app_icon_test.dart --update-goldens
///   dart run flutter_launcher_icons
///
/// Generating rather than hand-drawing means the icon on the home screen and a
/// mine on the board are the same shape by construction, and the icon is a
/// build artifact that can be reproduced instead of a binary nobody can edit.
void main() {
  const brand = Color(0xFF6B3FE0);
  const brandDeep = Color(0xFF3F1FA8);

  Widget canvas({required Widget child, Gradient? background}) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Container(
        width: 512,
        height: 512,
        decoration: BoxDecoration(gradient: background),
        child: Center(child: child),
      ),
    );
  }

  /// A single board cell holding a mine.
  ///
  /// A bare white mine on a flat field reads as a sun or a gear, and its own
  /// highlight disappears. Framing it the way the board does, dark ink on a
  /// coloured cell, makes it unmistakably this game.
  Widget cell({required double size}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: GameThemes.enamel.regionColor(7),
        borderRadius: BorderRadius.circular(size * 0.2),
        border: Border.all(
          color: GameThemes.enamel.boardOutline,
          width: size * 0.055,
        ),
      ),
      child: Center(
        child: MineIcon(
          size: size * 0.66,
          color: GameThemes.enamel.glyphColor,
        ),
      ),
    );
  }

  testWidgets('full-bleed icon', (tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      canvas(
        background: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [brand, brandDeep],
        ),
        // Sized well below the frame: launchers on both platforms crop and
        // round the corners, and a mark that runs to the edge loses its ends.
        child: cell(size: 300),
      ),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../assets/icon/app_icon.png'),
    );
  });

  testWidgets('android adaptive foreground', (tester) async {
    tester.view.physicalSize = const Size(512, 512);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    // Adaptive icons are masked and can be moved by the launcher, so the mark
    // must sit inside the safe zone, roughly the middle two thirds.
    await tester.pumpWidget(
      canvas(child: cell(size: 250)),
    );
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../assets/icon/app_icon_foreground.png'),
    );
  });
}
