import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The mine marker, drawn rather than loaded.
///
/// Material has no bomb glyph and emoji rendering differs wildly between
/// Android, iOS and browsers, so the shape is painted directly. That keeps it
/// identical everywhere and sharp at any size.
class MineIcon extends StatelessWidget {
  const MineIcon({super.key, required this.size, this.color});

  final double size;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: CustomPaint(
        painter: _MinePainter(color ?? const Color(0xFF241E33)),
      ),
    );
  }
}

class _MinePainter extends CustomPainter {
  const _MinePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width / 2, size.height / 2);
    final bodyRadius = size.width * 0.30;
    final spikeLength = size.width * 0.46;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final spikePaint = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.10
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4;
      canvas.drawLine(
        centre + Offset(math.cos(angle), math.sin(angle)) * (bodyRadius * 0.7),
        centre + Offset(math.cos(angle), math.sin(angle)) * spikeLength,
        spikePaint,
      );
    }

    canvas.drawCircle(centre, bodyRadius, paint);

    // A small highlight stops the body reading as a flat blob.
    canvas.drawCircle(
      centre.translate(-bodyRadius * 0.32, -bodyRadius * 0.32),
      bodyRadius * 0.22,
      Paint()..color = Colors.white.withValues(alpha: 0.75),
    );
  }

  @override
  bool shouldRepaint(_MinePainter oldDelegate) => oldDelegate.color != color;
}
