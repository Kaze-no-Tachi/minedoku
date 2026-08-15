import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:minedoku/state/app_state.dart';
import 'package:minedoku/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('theme catalogue', () {
    test('every theme defines exactly nine region colours', () {
      // The GameTheme constructor is const and so cannot assert on list length.
      // This is where that invariant is enforced instead.
      for (final theme in GameThemes.all) {
        expect(theme.regionColors.length, 9, reason: '${theme.id} palette');
      }
    });

    test('theme ids are unique and stable-looking', () {
      final ids = GameThemes.all.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'ids must be unique');
      for (final id in ids) {
        expect(id, matches(RegExp(r'^[a-z0-9-]+$')),
            reason: '$id should be a plain slug, it is a storage key');
      }
    });

    test('an unknown id falls back rather than throwing', () {
      // A theme removed in a future release must not brick the app on launch.
      expect(GameThemes.byId('no-such-theme').id, GameThemes.fallback.id);
      expect(GameThemes.byId(null).id, GameThemes.fallback.id);
    });

    test('every theme is either colour-blind safe or uses patterns', () {
      // This is the accessibility contract. A theme is free to be unsafe on
      // colour alone, but then it must be one that automatic mode gives
      // patterns to. What is not allowed is an unsafe theme that quietly
      // claims to be fine.
      for (final theme in GameThemes.all) {
        final audit = theme.audit;
        final claimsSafe = theme.isColorBlindSafe;
        expect(
          claimsSafe,
          audit.separation >= ColorVisionCheck.minimumSeparation,
          reason: '${theme.id} claim does not match its measurement: $audit',
        );
      }
    });

    test('the high contrast theme really is safe on colour alone', () {
      final audit = GameThemes.highContrast.audit;
      expect(
        GameThemes.highContrast.isColorBlindSafe,
        isTrue,
        reason: 'a theme named High Contrast must earn it: $audit',
      );
    });

    test('at least one theme stands on colour alone', () {
      expect(
        GameThemes.all.any((t) => t.isColorBlindSafe),
        isTrue,
        reason: 'players who dislike patterns need somewhere to go',
      );
    });

    test('glyphs stay legible on every region colour', () {
      // A mine drawn in the theme's glyph colour has to be visible on all nine
      // fills, or some regions become unreadable.
      for (final theme in GameThemes.all) {
        final glyph = ColorVisionCheck.luminance(theme.glyphColor);
        for (var i = 0; i < theme.regionColors.length; i++) {
          final fill = ColorVisionCheck.luminance(theme.regionColors[i]);
          final lighter = glyph > fill ? glyph : fill;
          final darker = glyph > fill ? fill : glyph;
          final ratio = (lighter + 0.05) / (darker + 0.05);
          expect(ratio, greaterThan(3.0),
              reason: '${theme.id} glyph on region $i has only '
                  '${ratio.toStringAsFixed(1)}:1');
        }
      }
    });
  });

  group('colour vision simulation', () {
    test('typical vision leaves a colour unchanged', () {
      const color = Color(0xFF4FD1FF);
      final simulated = ColorVisionCheck.simulate(color, ColorVision.typical);
      expect(ColorVisionCheck.separation(color, simulated, ColorVision.typical),
          lessThan(1.0));
    });

    test('red and green collapse under deuteranopia', () {
      // The check has to be able to detect the very failure it exists to catch.
      const red = Color(0xFFD52B1E);
      const green = Color(0xFF2BA84A);
      final typical =
          ColorVisionCheck.separation(red, green, ColorVision.typical);
      final deutan =
          ColorVisionCheck.separation(red, green, ColorVision.deuteranopia);

      expect(typical, greaterThan(60), reason: 'obvious to typical vision');
      expect(deutan, lessThan(typical / 2),
          reason: 'and much closer without green cones');
    });

    test('blue and orange survive every form of colour blindness', () {
      const blue = Color(0xFF2E7BC4);
      const orange = Color(0xFFE8871E);
      for (final vision in ColorVision.values) {
        expect(
          ColorVisionCheck.separation(blue, orange, vision),
          greaterThan(ColorVisionCheck.minimumSeparation),
          reason: 'blue against orange under ${vision.label}',
        );
      }
    });

    test('an audit names the closest pair', () {
      const palette = [
        Color(0xFF000000),
        Color(0xFFFFFFFF),
        Color(0xFFFEFEFE),
      ];
      final audit = ColorVisionCheck.audit(palette);
      expect(audit.closestPair, (1, 2));
      expect(audit.isSafe, isFalse);
    });
  });

  group('pattern mode', () {
    late AppState appState;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      appState = await AppState.load();
    });

    test('automatic turns patterns on exactly for unsafe palettes', () async {
      await appState.settings.setPatternMode(PatternMode.auto);

      await appState.settings.setThemeId(GameThemes.highContrast.id);
      expect(appState.showPatterns, isFalse,
          reason: 'a safe palette does not need them');

      await appState.settings.setThemeId(GameThemes.candy.id);
      expect(appState.showPatterns, GameThemes.candy.isColorBlindSafe == false,
          reason: 'an unsafe palette gets them automatically');
    });

    test('always and never override the theme', () async {
      await appState.settings.setThemeId(GameThemes.highContrast.id);

      await appState.settings.setPatternMode(PatternMode.always);
      expect(appState.showPatterns, isTrue);

      await appState.settings.setPatternMode(PatternMode.never);
      expect(appState.showPatterns, isFalse);
    });

    test('theme choice survives a reload', () async {
      await appState.settings.setThemeId(GameThemes.girliePop.id);
      final reloaded = await AppState.load();
      expect(reloaded.gameTheme.id, GameThemes.girliePop.id);
    });

    test('resetting progress keeps the chosen theme', () async {
      await appState.settings.setThemeId(GameThemes.sweeper95.id);
      await appState.resetProgress();
      expect(appState.gameTheme.id, GameThemes.sweeper95.id);
    });
  });
}
