import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The board blowing up.
///
/// Plays over the board when the last life is spent: the grid shakes, a
/// shockwave rolls out from each mine, and the screen flashes. Everything is
/// painted, so it costs no assets and works in any theme.
class Detonation extends StatefulWidget {
  const Detonation({
    super.key,
    required this.child,
    required this.active,
    required this.origins,
    this.onComplete,
  });

  /// The board being destroyed.
  final Widget child;

  /// Set true to fire once.
  final bool active;

  /// Where the blasts start, as fractions of the board (0 to 1 on each axis).
  final List<Offset> origins;

  final VoidCallback? onComplete;

  @override
  State<Detonation> createState() => _DetonationState();
}

class _DetonationState extends State<Detonation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) widget.onComplete?.call();
      });
    if (widget.active) _controller.forward();
  }

  @override
  void didUpdateWidget(Detonation oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !oldWidget.active) {
      _controller.forward(from: 0);
    } else if (!widget.active && oldWidget.active) {
      _controller.value = 0;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = _controller.value;
        // A decaying shake: violent at first, settled well before the end.
        final shake = reduceMotion || t == 0
            ? Offset.zero
            : Offset(
                math.sin(t * math.pi * 14) * 10 * (1 - t) * (1 - t),
                math.cos(t * math.pi * 11) * 7 * (1 - t) * (1 - t),
              );

        return Stack(
          fit: StackFit.passthrough,
          children: [
            Transform.translate(offset: shake, child: child),
            if (t > 0)
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _BlastPainter(
                      progress: t,
                      origins: widget.origins,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
      child: widget.child,
    );
  }
}

class _BlastPainter extends CustomPainter {
  const _BlastPainter({required this.progress, required this.origins});

  final double progress;
  final List<Offset> origins;

  @override
  void paint(Canvas canvas, Size size) {
    final extent = size.shortestSide;
    // Kept inside the board: rings that spill onto the page read as a glitch
    // rather than an explosion happening on the grid.
    canvas.save();
    canvas.clipRect(Offset.zero & size);

    // A hot flash across the whole board, gone in the first third.
    final flash = (1 - (progress / 0.33)).clamp(0.0, 1.0);
    if (flash > 0) {
      canvas.drawRect(
        Offset.zero & size,
        Paint()..color = const Color(0xFFFF7043).withValues(alpha: flash * 0.55),
      );
    }

    for (var i = 0; i < origins.length; i++) {
      // Stagger the blasts so they read as a chain rather than one thud.
      final delay = (i / math.max(origins.length, 1)) * 0.25;
      final local = ((progress - delay) / (1 - delay)).clamp(0.0, 1.0);
      if (local <= 0) continue;

      final centre = Offset(
        origins[i].dx * size.width,
        origins[i].dy * size.height,
      );
      final fade = (1 - local).clamp(0.0, 1.0);

      // Shockwave ring, kept near the size of a cell or two.
      canvas.drawCircle(
        centre,
        extent * 0.30 * Curves.easeOutCubic.transform(local),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = extent * 0.03 * fade
          ..color = const Color(0xFFFFC107).withValues(alpha: fade * 0.85),
      );

      // Core, which collapses as the ring expands.
      canvas.drawCircle(
        centre,
        extent * 0.14 * (1 - local),
        Paint()
          ..color = const Color(0xFFFF5252).withValues(alpha: fade),
      );

      // Short, fat sparks. Long thin ones read as scratches on the screen.
      final sparkPaint = Paint()
        ..color = const Color(0xFFFFE082).withValues(alpha: fade)
        ..strokeWidth = extent * 0.022 * fade
        ..strokeCap = StrokeCap.round;
      for (var s = 0; s < 6; s++) {
        final angle = (s / 6) * math.pi * 2 + i * 0.7;
        final direction = Offset(math.cos(angle), math.sin(angle));
        final reach = extent * 0.22 * Curves.easeOutCubic.transform(local);
        canvas.drawLine(
          centre + direction * (reach * 0.72),
          centre + direction * reach,
          sparkPaint,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_BlastPainter old) => old.progress != progress;
}
