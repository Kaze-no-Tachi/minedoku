import 'package:flutter/material.dart';

import 'cell_art.dart';
import 'color_vision.dart';

/// A complete visual identity for the game.
///
/// A theme owns the nine region colours, the chrome around them, how a cell is
/// rendered and what a mine looks like. It owns no rules: every theme plays
/// exactly the same game.
@immutable
class GameTheme {
  const GameTheme({
    required this.id,
    required this.name,
    required this.tagline,
    required this.regionColors,
    required this.seed,
    required this.glyphColor,
    required this.boardOutline,
    required this.gridLine,
    required this.surface,
    required this.mineGlyph,
    this.blockedGlyph = BlockedGlyph.cross,
    this.patternColor = const Color(0x33000000),
    this.forcedBrightness,
    this.cornerRadius = 14,
  });

  /// Stable key stored in settings. Never rename an id in a shipped release.
  final String id;

  final String name;

  /// One line shown under the name in the theme picker.
  final String tagline;

  /// Fill for each region id, in order.
  final List<Color> regionColors;

  /// Drives the Material colour scheme for everything outside the board.
  final Color seed;

  /// Mines and X marks drawn on top of a region fill.
  final Color glyphColor;

  /// The heavy line between two different regions.
  final Color boardOutline;

  /// The hairline between two cells of the same region.
  final Color gridLine;

  final CellSurface surface;
  final MineGlyph mineGlyph;
  final BlockedGlyph blockedGlyph;

  /// Ink used for accessibility patterns.
  final Color patternColor;

  /// Set when a theme only works in one brightness, such as a period-accurate
  /// grey desktop that would be absurd in dark mode.
  final Brightness? forcedBrightness;

  final double cornerRadius;

  Color regionColor(int id) => regionColors[id % regionColors.length];

  /// Audits are pure functions of a fixed palette, but cost a few hundred
  /// colour-space conversions, and [isColorBlindSafe] is read on every build.
  static final Map<String, PaletteAudit> _auditCache = {};

  /// How well the palette survives colour blindness, measured rather than
  /// assumed. The theme picker and the test suite both use it.
  PaletteAudit get audit =>
      _auditCache[id] ??= ColorVisionCheck.audit(regionColors);

  /// True when the colours alone are enough to tell every region apart.
  ///
  /// Themes that fail this are not rejected: a candy-bright palette is allowed
  /// to be candy-bright. They simply get patterns switched on by default.
  bool get isColorBlindSafe => audit.isSafe;
}
