import 'package:flutter/material.dart';

/// Three stars, filled to show what a level earned.
///
/// The rating has been recorded since progress was first stored and was never
/// shown anywhere, which meant a finished level gave no reason to go back. This
/// is that reason.
class StarRow extends StatelessWidget {
  const StarRow({
    super.key,
    required this.earned,
    this.size = 20,
    this.color,
    this.emptyColor,
  });

  final int earned;
  final double size;
  final Color? color;
  final Color? emptyColor;

  static const int max = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < max; i++)
          Icon(
            i < earned ? Icons.star_rounded : Icons.star_outline_rounded,
            size: size,
            color: i < earned
                ? (color ?? const Color(0xFFFFC93C))
                : (emptyColor ?? scheme.onSurfaceVariant.withValues(alpha: 0.35)),
          ),
      ],
    );
  }
}

/// Stars that land one at a time, with a callback per star so a sound can be
/// played in time with each.
class AnimatedStars extends StatefulWidget {
  const AnimatedStars({
    super.key,
    required this.earned,
    this.size = 40,
    this.onStarLanded,
  });

  final int earned;
  final double size;

  /// Called with 1, 2, 3 as each star arrives.
  final ValueChanged<int>? onStarLanded;

  @override
  State<AnimatedStars> createState() => _AnimatedStarsState();
}

class _AnimatedStarsState extends State<AnimatedStars>
    with SingleTickerProviderStateMixin {
  static const _perStar = Duration(milliseconds: 420);

  late final AnimationController _controller;
  var _announced = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: _perStar * StarRow.max,
    )..addListener(_announce);
    _controller.forward();
  }

  void _announce() {
    // One callback per star, as it lands rather than as it starts, so the
    // sound and the pop happen together.
    final landed = (_controller.value * StarRow.max).floor();
    while (_announced < landed && _announced < widget.earned) {
      _announced++;
      widget.onStarLanded?.call(_announced);
    }
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_announce)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < StarRow.max; i++)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: _star(i, scheme),
              ),
          ],
        );
      },
    );
  }

  Widget _star(int index, ColorScheme scheme) {
    final start = index / StarRow.max;
    final progress =
        ((_controller.value - start) * StarRow.max).clamp(0.0, 1.0);
    final filled = index < widget.earned;

    if (!filled) {
      return Icon(
        Icons.star_outline_rounded,
        size: widget.size,
        color: scheme.onSurfaceVariant.withValues(alpha: 0.3),
      );
    }

    // Overshoot then settle, so each star lands rather than fades in.
    final scale = progress == 0
        ? 0.0
        : Curves.easeOutBack.transform(progress).clamp(0.0, 1.4);

    return Transform.scale(
      scale: scale,
      child: Icon(
        Icons.star_rounded,
        size: widget.size,
        color: const Color(0xFFFFC93C),
      ),
    );
  }
}
