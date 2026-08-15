import 'package:flutter/material.dart';

import '../theme/cell_art.dart';

/// A single marker drawn on its own, away from a board.
///
/// Used for the app icon, the title lockup and anywhere a glyph appears in
/// running text. It paints through [CellArt] so there is exactly one definition
/// of each shape: the mine on the board and the mine on the icon can never
/// drift apart.
class MineIcon extends StatelessWidget {
  const MineIcon({
    super.key,
    required this.size,
    this.color,
    this.glyph = MineGlyph.mine,
  });

  final double size;
  final Color? color;
  final MineGlyph glyph;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _GlyphPainter(
          glyph: glyph,
          color: color ?? const Color(0xFF241E33),
        ),
      ),
    );
  }
}

class _GlyphPainter extends CustomPainter {
  const _GlyphPainter({required this.glyph, required this.color});

  final MineGlyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    CellArt.paintMine(
      canvas,
      Offset.zero & size,
      glyph: glyph,
      color: color,
    );
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.color != color || old.glyph != glyph;
}
