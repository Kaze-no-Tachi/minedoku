import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// A distinct texture for each colour region.
///
/// Nine colours cannot all be told apart under every form of colour blindness,
/// so shape carries what colour cannot. Patterns are deliberately quiet: they
/// mark a region without competing with the mines drawn on top.
enum RegionPattern {
  dots,
  diagonalUp,
  diagonalDown,
  crosshatch,
  rings,
  grid,
  chevron,
  waves,
  checks;

  /// The pattern for a region id, wrapping if a board ever exceeds nine.
  static RegionPattern forRegion(int id) => values[id % values.length];

  /// Draws this pattern across [rect].
  ///
  /// [unit] is the cell size, so spacing scales with the board rather than
  /// turning into noise on a 9x9.
  void paint(Canvas canvas, Rect rect, Color color, double unit) {
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(1.0, unit * 0.045)
      ..strokeCap = StrokeCap.round;
    final fill = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    canvas.save();
    canvas.clipRect(rect);
    switch (this) {
      case RegionPattern.dots:
        _grid(rect, unit / 3, (offset) {
          canvas.drawCircle(offset, unit * 0.055, fill);
        });
      case RegionPattern.diagonalUp:
        _diagonals(canvas, rect, unit / 3.2, stroke, up: true);
      case RegionPattern.diagonalDown:
        _diagonals(canvas, rect, unit / 3.2, stroke, up: false);
      case RegionPattern.crosshatch:
        _diagonals(canvas, rect, unit / 2.8, stroke, up: true);
        _diagonals(canvas, rect, unit / 2.8, stroke, up: false);
      case RegionPattern.rings:
        _grid(rect, unit / 2, (offset) {
          canvas.drawCircle(offset, unit * 0.13, stroke);
        });
      case RegionPattern.grid:
        for (var x = rect.left; x <= rect.right; x += unit / 3) {
          canvas.drawLine(Offset(x, rect.top), Offset(x, rect.bottom), stroke);
        }
        for (var y = rect.top; y <= rect.bottom; y += unit / 3) {
          canvas.drawLine(Offset(rect.left, y), Offset(rect.right, y), stroke);
        }
      case RegionPattern.chevron:
        final step = unit / 2.6;
        for (var y = rect.top - step; y <= rect.bottom + step; y += step) {
          final path = Path()
            ..moveTo(rect.left, y + step / 2)
            ..lineTo(rect.center.dx, y)
            ..lineTo(rect.right, y + step / 2);
          canvas.drawPath(path, stroke);
        }
      case RegionPattern.waves:
        final step = unit / 2.6;
        for (var y = rect.top; y <= rect.bottom + step; y += step) {
          final path = Path()..moveTo(rect.left, y);
          for (var x = rect.left; x < rect.right; x += unit / 4) {
            path.relativeQuadraticBezierTo(
              unit / 8,
              -unit * 0.09,
              unit / 4,
              0,
            );
          }
          canvas.drawPath(path, stroke);
        }
      case RegionPattern.checks:
        final step = unit / 3.5;
        var row = 0;
        for (var y = rect.top; y < rect.bottom; y += step) {
          var column = 0;
          for (var x = rect.left; x < rect.right; x += step) {
            if ((row + column).isEven) {
              canvas.drawRect(Rect.fromLTWH(x, y, step, step), fill);
            }
            column++;
          }
          row++;
        }
    }
    canvas.restore();
  }

  void _grid(Rect rect, double step, void Function(Offset) draw) {
    for (var y = rect.top + step / 2; y < rect.bottom; y += step) {
      for (var x = rect.left + step / 2; x < rect.right; x += step) {
        draw(Offset(x, y));
      }
    }
  }

  void _diagonals(
    Canvas canvas,
    Rect rect,
    double step,
    Paint paint, {
    required bool up,
  }) {
    // Start a full height before the rect so the slanted lines cover the
    // top-left corner instead of leaving it bare.
    for (var x = rect.left - rect.height; x <= rect.right; x += step) {
      canvas.drawLine(
        Offset(x, up ? rect.bottom : rect.top),
        Offset(x + rect.height, up ? rect.top : rect.bottom),
        paint,
      );
    }
  }
}
