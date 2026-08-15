import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// How a cell's surface is rendered.
enum CellSurface {
  /// A plain fill. Modern, quiet, lets the region colours do the work.
  flat,

  /// A raised 3D edge: light on the top and left, dark on the bottom and
  /// right. The look of a 1990s Windows button.
  bevel,

  /// A soft top highlight and rounded inset, like moulded plastic or a sweet.
  glossy,
}

/// The marker used for a placed mine. Purely cosmetic: the rules never change.
enum MineGlyph { mine, heart, candy, flag }

/// The marker for a cell the player has ruled out.
enum BlockedGlyph { cross, dot }

/// Draws cell surfaces and the markers on top of them.
///
/// Everything is painted rather than loaded, so themes cost no assets, stay
/// sharp at any size, and render identically on every platform.
abstract final class CellArt {
  static void paintSurface(
    Canvas canvas,
    Rect rect, {
    required Color fill,
    required CellSurface surface,
  }) {
    final paint = Paint()..color = fill;

    switch (surface) {
      case CellSurface.flat:
        canvas.drawRect(rect, paint);

      case CellSurface.bevel:
        canvas.drawRect(rect, paint);
        final depth = math.max(2.0, rect.width * 0.09);
        // Light comes from the top left, so that edge catches it and the
        // opposite edge falls into shadow.
        final light = Paint()..color = const Color(0x99FFFFFF);
        final shadow = Paint()..color = const Color(0x55000000);
        canvas.drawPath(
          Path()
            ..moveTo(rect.left, rect.bottom)
            ..lineTo(rect.left, rect.top)
            ..lineTo(rect.right, rect.top)
            ..lineTo(rect.right - depth, rect.top + depth)
            ..lineTo(rect.left + depth, rect.top + depth)
            ..lineTo(rect.left + depth, rect.bottom - depth)
            ..close(),
          light,
        );
        canvas.drawPath(
          Path()
            ..moveTo(rect.right, rect.top)
            ..lineTo(rect.right, rect.bottom)
            ..lineTo(rect.left, rect.bottom)
            ..lineTo(rect.left + depth, rect.bottom - depth)
            ..lineTo(rect.right - depth, rect.bottom - depth)
            ..lineTo(rect.right - depth, rect.top + depth)
            ..close(),
          shadow,
        );

      case CellSurface.glossy:
        final inset = rect.deflate(rect.width * 0.04);
        final radius = RRect.fromRectAndRadius(
          inset,
          Radius.circular(rect.width * 0.22),
        );
        canvas.drawRRect(radius, paint);
        // A highlight across the top half reads as moulded plastic.
        canvas.drawRRect(
          radius,
          Paint()
            ..shader = const LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0x66FFFFFF),
                Color(0x00FFFFFF),
                Color(0x1A000000),
              ],
              stops: [0, 0.55, 1],
            ).createShader(inset),
        );
    }
  }

  static void paintMine(
    Canvas canvas,
    Rect rect, {
    required MineGlyph glyph,
    required Color color,
  }) {
    final centre = rect.center;
    final unit = rect.width;
    final fill = Paint()..color = color;

    switch (glyph) {
      case MineGlyph.mine:
        final body = unit * 0.30;
        final spike = Paint()
          ..color = color
          ..strokeWidth = unit * 0.10
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final direction = Offset(math.cos(angle), math.sin(angle));
          canvas.drawLine(
            centre + direction * (body * 0.7),
            centre + direction * (unit * 0.46),
            spike,
          );
        }
        canvas.drawCircle(centre, body, fill);
        canvas.drawCircle(
          centre.translate(-body * 0.32, -body * 0.32),
          body * 0.22,
          Paint()..color = const Color(0xBFFFFFFF),
        );

      case MineGlyph.heart:
        final size = unit * 0.42;
        final path = Path()..moveTo(centre.dx, centre.dy + size * 0.85);
        path.cubicTo(
          centre.dx - size * 1.5, centre.dy - size * 0.2, //
          centre.dx - size * 0.55, centre.dy - size * 1.25, //
          centre.dx, centre.dy - size * 0.35,
        );
        path.cubicTo(
          centre.dx + size * 0.55, centre.dy - size * 1.25, //
          centre.dx + size * 1.5, centre.dy - size * 0.2, //
          centre.dx, centre.dy + size * 0.85,
        );
        canvas.drawPath(path, fill);
        canvas.drawCircle(
          centre.translate(-size * 0.42, -size * 0.42),
          size * 0.16,
          Paint()..color = const Color(0x99FFFFFF),
        );

      case MineGlyph.candy:
        // A wrapped sweet: round body with pinched ends.
        final body = unit * 0.26;
        final wing = unit * 0.22;
        final wrapper = Path()
          ..moveTo(centre.dx - body, centre.dy)
          ..lineTo(centre.dx - body - wing, centre.dy - wing * 0.8)
          ..lineTo(centre.dx - body - wing, centre.dy + wing * 0.8)
          ..close()
          ..moveTo(centre.dx + body, centre.dy)
          ..lineTo(centre.dx + body + wing, centre.dy - wing * 0.8)
          ..lineTo(centre.dx + body + wing, centre.dy + wing * 0.8)
          ..close();
        canvas.drawPath(wrapper, fill);
        canvas.drawCircle(centre, body, fill);
        canvas.drawCircle(
          centre.translate(-body * 0.3, -body * 0.35),
          body * 0.26,
          Paint()..color = const Color(0xCCFFFFFF),
        );

      case MineGlyph.flag:
        final poleX = centre.dx - unit * 0.02;
        final top = centre.dy - unit * 0.34;
        final bottom = centre.dy + unit * 0.30;
        canvas.drawRect(
          Rect.fromLTRB(poleX - unit * 0.03, top, poleX + unit * 0.03, bottom),
          fill,
        );
        canvas.drawRect(
          Rect.fromLTRB(
            centre.dx - unit * 0.26,
            bottom - unit * 0.07,
            centre.dx + unit * 0.26,
            bottom,
          ),
          fill,
        );
        canvas.drawPath(
          Path()
            ..moveTo(poleX, top)
            ..lineTo(poleX - unit * 0.30, top + unit * 0.15)
            ..lineTo(poleX, top + unit * 0.30)
            ..close(),
          Paint()..color = const Color(0xFFD32F2F),
        );
    }
  }

  static void paintBlocked(
    Canvas canvas,
    Rect rect, {
    required BlockedGlyph glyph,
    required Color color,
  }) {
    final centre = rect.center;
    final unit = rect.width;

    switch (glyph) {
      case BlockedGlyph.cross:
        final arm = unit * 0.20;
        final stroke = Paint()
          ..color = color
          ..strokeWidth = unit * 0.11
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          centre.translate(-arm, -arm),
          centre.translate(arm, arm),
          stroke,
        );
        canvas.drawLine(
          centre.translate(arm, -arm),
          centre.translate(-arm, arm),
          stroke,
        );

      case BlockedGlyph.dot:
        canvas.drawCircle(centre, unit * 0.11, Paint()..color = color);
    }
  }
}
