import 'package:flutter/material.dart';

import 'cell_art.dart';
import 'game_theme.dart';

/// The shipped themes.
///
/// Every theme plays the identical game. They differ only in how the board
/// looks, so a player can pick the one they want to spend an hour staring at.
abstract final class GameThemes {
  /// The original look: flat enamel colours behind heavy ink outlines.
  static const enamel = GameTheme(
    id: 'enamel',
    name: 'Enamel',
    tagline: 'Bright flat colour behind heavy ink.',
    regionColors: [
      Color(0xFFB39DFF),
      Color(0xFFFF6FA5),
      Color(0xFFFFB8E0),
      Color(0xFF4FD1FF),
      Color(0xFFE8863C),
      Color(0xFFFFC49B),
      Color(0xFFA8E063),
      Color(0xFFFFC93C),
      Color(0xFF57E0C8),
    ],
    seed: Color(0xFF7C4DFF),
    glyphColor: Color(0xFF241E33),
    boardOutline: Color(0xFF2A2438),
    gridLine: Color(0x29000000),
    surface: CellSurface.flat,
    mineGlyph: MineGlyph.mine,
  );

  /// A period piece: grey bevelled buttons and the classic number colours,
  /// with a flag for every mine you plant.
  ///
  /// Locked to light, because a 1995 desktop rendered in dark mode is not a
  /// 1995 desktop.
  static const sweeper95 = GameTheme(
    id: 'sweeper95',
    name: 'Sweeper 95',
    tagline: 'Grey bevels and a little red flag.',
    regionColors: [
      Color(0xFFC0C0C0),
      Color(0xFFB4C2E4),
      Color(0xFFB2D6B2),
      Color(0xFFE8B4B4),
      Color(0xFF9BA6C4),
      Color(0xFFCFA9A9),
      Color(0xFFA8CCCC),
      Color(0xFFDEDEDE),
      Color(0xFF949494),
    ],
    seed: Color(0xFF000080),
    glyphColor: Color(0xFF1A1A1A),
    boardOutline: Color(0xFF5A5A5A),
    gridLine: Color(0x33000000),
    surface: CellSurface.bevel,
    mineGlyph: MineGlyph.flag,
    blockedGlyph: BlockedGlyph.dot,
    patternColor: Color(0x40000000),
    forcedBrightness: Brightness.light,
    cornerRadius: 2,
  );

  /// Unapologetically pink, with hearts instead of mines.
  static const girliePop = GameTheme(
    id: 'girlie-pop',
    name: 'Girlie Pop',
    tagline: 'Hearts, not mines. Glossy and very pink.',
    regionColors: [
      Color(0xFFFF7EB6),
      Color(0xFFFFD1E8),
      Color(0xFFC77DFF),
      Color(0xFFFFB5A7),
      Color(0xFFFFE5A0),
      Color(0xFF9BB8FF),
      Color(0xFFFF9ECF),
      Color(0xFFE8D5FF),
      Color(0xFFFFF0F5),
    ],
    seed: Color(0xFFFF4FA3),
    glyphColor: Color(0xFF5C1F45),
    boardOutline: Color(0xFF7A2E5C),
    gridLine: Color(0x33000000),
    surface: CellSurface.glossy,
    mineGlyph: MineGlyph.heart,
    patternColor: Color(0x38000000),
    cornerRadius: 22,
  );

  /// Saturated sweet-shop colours with a moulded plastic shine.
  static const candy = GameTheme(
    id: 'candy',
    name: 'Candy',
    tagline: 'Sweet-shop colours with a glossy shine.',
    regionColors: [
      Color(0xFFFF5252),
      Color(0xFFFF9800),
      Color(0xFFFFEB3B),
      Color(0xFF66BB6A),
      Color(0xFF26C6DA),
      Color(0xFF42A5F5),
      Color(0xFFAB47BC),
      Color(0xFFEC407A),
      Color(0xFFF5F5F5),
    ],
    seed: Color(0xFFE91E63),
    glyphColor: Color(0xFF34201B),
    boardOutline: Color(0xFF3A2A28),
    gridLine: Color(0x33000000),
    surface: CellSurface.glossy,
    mineGlyph: MineGlyph.candy,
    patternColor: Color(0x40000000),
    cornerRadius: 20,
  );

  /// Built for legibility first, and loud about it.
  ///
  /// These nine colours were not chosen by eye. They came out of a search that
  /// simulated protanopia, deuteranopia and tritanopia and maximised the
  /// closest pair across all of them, while keeping the glyph readable on every
  /// fill. A quieter, more tasteful set was tried and measured at 16.0, under
  /// the 18 needed: nine muted colours simply cannot stay separable. This set
  /// reaches 23.4, and looks it. That trade is the whole point of the theme.
  static const highContrast = GameTheme(
    id: 'high-contrast',
    name: 'High Contrast',
    tagline: 'Loud on purpose. No two colours can collapse together.',
    regionColors: [
      Color(0xFFFFFFFF),
      Color(0xFFFF661A),
      Color(0xFF6A81AF),
      Color(0xFFB3FF1A),
      Color(0xFFB31AFF),
      Color(0xFFFFB8FF),
      Color(0xFF1AFF8C),
      Color(0xFF9D877B),
      Color(0xFFFF66FF),
    ],
    seed: Color(0xFF2E7BC4),
    glyphColor: Color(0xFF101010),
    boardOutline: Color(0xFF101010),
    gridLine: Color(0x40000000),
    surface: CellSurface.flat,
    mineGlyph: MineGlyph.mine,
    patternColor: Color(0x4D000000),
    cornerRadius: 8,
  );

  static const List<GameTheme> all = [
    enamel,
    sweeper95,
    girliePop,
    candy,
    highContrast,
  ];

  static const GameTheme fallback = enamel;

  /// Looks a theme up by its stored id, falling back rather than throwing so a
  /// removed theme can never brick the app on launch.
  static GameTheme byId(String? id) => all.firstWhere(
        (theme) => theme.id == id,
        orElse: () => fallback,
      );
}
