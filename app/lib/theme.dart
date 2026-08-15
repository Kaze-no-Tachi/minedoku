import 'package:flutter/material.dart';

/// Colours and text styles for the whole app.
abstract final class MinedokuTheme {
  /// One colour per region, in region-id order.
  ///
  /// Chosen to stay distinguishable next to each other and to keep dark icons
  /// readable on top. Boards never use more than nine regions.
  static const List<Color> regionColors = [
    Color(0xFFB39DFF), // violet
    Color(0xFFFF6FA5), // pink
    Color(0xFFFFB8E0), // light pink
    Color(0xFF4FD1FF), // sky
    Color(0xFFE8863C), // orange
    Color(0xFFFFC49B), // peach
    Color(0xFFA8E063), // green
    Color(0xFFFFC93C), // yellow
    Color(0xFF57E0C8), // teal
  ];

  static Color regionColor(int id) =>
      regionColors[id % regionColors.length];

  /// Wash used for a cell the player has X'd out.
  static Color blockedOverlay(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.black.withValues(alpha: 0.28)
          : Colors.white.withValues(alpha: 0.42);

  /// Line drawn between two different regions.
  static Color regionBorder(Brightness brightness) =>
      brightness == Brightness.dark
          ? const Color(0xFFE8E6F0)
          : const Color(0xFF2A2438);

  /// Line drawn between two cells of the same region.
  static Color cellBorder(Brightness brightness) =>
      brightness == Brightness.dark
          ? Colors.white.withValues(alpha: 0.22)
          : Colors.black.withValues(alpha: 0.16);

  static const Color conflict = Color(0xFFD32F2F);
  static const Color hintGlow = Color(0xFF00C853);

  static ThemeData light() => _base(Brightness.light);

  static ThemeData dark() => _base(Brightness.dark);

  static ThemeData _base(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF7C4DFF),
      brightness: brightness,
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
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        color: scheme.surfaceContainerHighest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
    );
  }
}
