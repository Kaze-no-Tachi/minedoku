import 'package:flutter/material.dart';

import '../state/app_state.dart';
import 'game_theme.dart';
import 'themes.dart';

export 'cell_art.dart';
export 'color_vision.dart';
export 'game_theme.dart';
export 'region_patterns.dart';
export 'themes.dart';

/// Builds the Material theme for the chrome around the board.
///
/// The board itself is painted directly from the [GameTheme]; this covers
/// everything else, so the menus, buttons and sheets pick up the same identity.
abstract final class AppTheme {
  /// Feedback colours are shared across themes. A red that means "wrong" and a
  /// green that means "right" should not change meaning when the skin does.
  static const Color conflict = Color(0xFFD32F2F);
  static const Color hintGlow = Color(0xFF00A85A);

  static ThemeData build(GameTheme game, Brightness brightness) {
    final resolved = game.forcedBrightness ?? brightness;
    final scheme = ColorScheme.fromSeed(
      seedColor: game.seed,
      brightness: resolved,
    );

    return ThemeData(
      colorScheme: scheme,
      scaffoldBackgroundColor: scheme.surface,
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        centerTitle: true,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          textStyle: const TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(game.cornerRadius),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(game.cornerRadius),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(game.cornerRadius + 6),
        ),
      ),
    );
  }

  /// Wash laid over a cell the player has X'd out.
  static Color blockedOverlay(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0x47000000)
          : const Color(0x6BFFFFFF);
}

/// Resolves the player's stored choices into the theme the board should use.
extension ThemeSelection on AppState {
  GameTheme get gameTheme => GameThemes.byId(settings.themeId);

  /// Whether region patterns are drawn.
  ///
  /// On automatic, a theme gets patterns exactly when its palette cannot carry
  /// the board on its own. That lets a candy-bright theme stay bright while
  /// still being playable by someone who cannot separate its colours.
  bool get showPatterns => switch (settings.patternMode) {
        PatternMode.always => true,
        PatternMode.never => false,
        PatternMode.auto => !gameTheme.isColorBlindSafe,
      };
}
