import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../theme/app_theme.dart';
import 'board_view.dart';

/// A decorative board that quietly solves itself, over and over.
///
/// Driven by an [AnimationController] rather than a [Timer] on purpose:
/// controllers are muted by [TickerMode] when their route is covered, so
/// pushing a game on top stops this without any bookkeeping, and it cannot sit
/// burning battery behind another screen.
class AmbientBoard extends StatefulWidget {
  const AmbientBoard({
    super.key,
    required this.theme,
    this.showPatterns = false,
    this.size = 6,
    this.cycle = const Duration(seconds: 11),
  });

  final GameTheme theme;
  final bool showPatterns;

  /// Board size. Small on purpose: it generates in about a millisecond and
  /// reads clearly at a glance.
  final int size;

  /// How long one solve-and-reset takes.
  final Duration cycle;

  @override
  State<AmbientBoard> createState() => _AmbientBoardState();
}

class _AmbientBoardState extends State<AmbientBoard>
    with SingleTickerProviderStateMixin {
  static const _generator = PuzzleGenerator();

  late final AnimationController _controller;
  late Puzzle _puzzle;
  int _seed = 1;
  double _previous = 0;

  /// Extra beats at the end of a cycle where the solved board simply rests.
  static const _restBeats = 3;

  @override
  void initState() {
    super.initState();
    _seed = DateTime.now().millisecondsSinceEpoch % 100000;
    _puzzle = _generate();
    _controller = AnimationController(vsync: this, duration: widget.cycle)
      ..addListener(_onTick)
      ..repeat();
  }

  Puzzle _generate() =>
      _generator.generate(size: widget.size, seed: _seed);

  void _onTick() {
    // A wrap back to the start means the cycle finished, so deal a new board.
    if (_controller.value < _previous) {
      _seed = (_seed + 7919) % 1000000;
      _puzzle = _generate();
    }
    _previous = _controller.value;
    setState(() {});
  }

  @override
  void dispose() {
    _controller
      ..removeListener(_onTick)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final board = GameBoard(_puzzle, autoBlock: false);

    // With reduced motion the board is simply shown solved, still and complete,
    // rather than animating.
    final placed = reduceMotion
        ? widget.size
        : (_controller.value * (widget.size + _restBeats))
            .floor()
            .clamp(0, widget.size);

    for (var row = 0; row < placed; row++) {
      board.setMark(row * widget.size + _puzzle.solution[row], CellMark.mine);
    }

    return IgnorePointer(
      child: BoardView(
        board: board,
        theme: widget.theme,
        showPatterns: widget.showPatterns,
        interactive: false,
        onTapCell: (_) {},
        onLongPressCell: (_) {},
      ),
    );
  }
}
