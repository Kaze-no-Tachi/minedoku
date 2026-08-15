import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../state/app_state.dart';
import '../state/game_controller.dart';
import '../theme.dart';
import '../widgets/board_view.dart';

/// Plays one board.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.spec,
    this.isCampaign = true,
    this.restoreMarks,
    this.restoreSeconds = 0,
  });

  final LevelSpec spec;
  final bool isCampaign;
  final String? restoreMarks;
  final int restoreSeconds;

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with WidgetsBindingObserver {
  GameController? _controller;
  bool _winShown = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_controller != null) return;

    final controller = GameController(
      spec: widget.spec,
      appState: AppScope.of(context),
      isCampaign: widget.isCampaign,
    );
    controller.addListener(_onControllerChanged);
    _controller = controller;
    controller.start(
      restoreMarks: widget.restoreMarks,
      restoreSeconds: widget.restoreSeconds,
    );
  }

  void _onControllerChanged() {
    if (!mounted) return;
    if (_controller!.hasWon && !_winShown) {
      _winShown = true;
      // Let the winning move paint before the sheet slides over it.
      Future<void>.delayed(const Duration(milliseconds: 420), () {
        if (mounted) _showWinSheet();
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _controller?.resume();
    } else {
      _controller?.pause();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _showWinSheet() async {
    final controller = _controller!;
    final appState = AppScope.of(context);
    final best = widget.isCampaign ? appState.bestTime(widget.spec.number) : null;

    final action = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (context) => _WinSheet(
        spec: widget.spec,
        time: controller.formattedTime,
        hintsUsed: controller.hintsUsed,
        bestSeconds: best,
        showNext: widget.isCampaign,
      ),
    );
    if (!mounted) return;

    switch (action) {
      case 'next':
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => GameScreen(
              spec: Levels.forLevel(widget.spec.number + 1),
            ),
          ),
        );
      case 'replay':
        setState(() {
          _winShown = false;
          _controller?.removeListener(_onControllerChanged);
          _controller?.dispose();
          _controller = null;
        });
        didChangeDependencies();
      default:
        Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(widget.spec.displayName),
            actions: [
              IconButton(
                tooltip: 'Restart this board',
                onPressed: controller.loading ? null : controller.clearBoard,
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          body: SafeArea(
            child: controller.loading
                ? const Center(child: CircularProgressIndicator())
                : _buildGame(context, controller),
          ),
        );
      },
    );
  }

  Widget _buildGame(BuildContext context, GameController controller) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _Readouts(controller: controller),
                      const SizedBox(height: 16),
                      BoardView(
                        board: controller.board!,
                        conflictCells: controller.conflictCells,
                        hintCell: controller.hint?.cell,
                        relatedCells: controller.hint?.relatedCells ?? const [],
                        onTapCell: controller.tapCell,
                        onLongPressCell: controller.placeMine,
                      ),
                      const SizedBox(height: 14),
                      // Minimum, not fixed: explanations run to a few lines and
                      // must not be clipped.
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: Center(
                          child: Text(
                            controller.hint?.message ??
                                (controller.conflictCells.isNotEmpty
                                    ? 'Those mines break a rule.'
                                    : ''),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: controller.conflictCells.isNotEmpty &&
                                      controller.hint == null
                                  ? MinedokuTheme.conflict
                                  : theme.colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      _Controls(controller: controller),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Readouts extends StatelessWidget {
  const _Readouts({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _Readout(
            label: 'Mines left',
            value: '${controller.minesRemaining}',
            highlight: controller.hasWon,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Readout(label: 'Time', value: controller.formattedTime),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _Readout(
            label: 'Board',
            value: '${controller.spec.size}x${controller.spec.size}',
          ),
        ),
      ],
    );
  }
}

class _Readout extends StatelessWidget {
  const _Readout({
    required this.label,
    required this.value,
    this.highlight = false,
  });

  final String label;
  final String value;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: theme.textTheme.labelSmall?.copyWith(
              letterSpacing: 1.2,
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: highlight ? MinedokuTheme.hintGlow : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.controller});

  final GameController controller;

  @override
  Widget build(BuildContext context) {
    final done = controller.hasWon;
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.undo_rounded,
            label: 'Undo',
            onPressed: done || !controller.canUndo ? null : controller.undo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.redo_rounded,
            label: 'Redo',
            onPressed: done || !controller.canRedo ? null : controller.redo,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.lightbulb_outline_rounded,
            label: 'Hint',
            onPressed: done ? null : controller.requestHint,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _ActionButton(
            icon: Icons.delete_outline_rounded,
            label: 'Clear',
            onPressed: done ? null : controller.clearBoard,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(58),
        padding: EdgeInsets.zero,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20),
          const SizedBox(height: 3),
          Text(label, style: const TextStyle(fontSize: 11)),
        ],
      ),
    );
  }
}

class _WinSheet extends StatelessWidget {
  const _WinSheet({
    required this.spec,
    required this.time,
    required this.hintsUsed,
    required this.bestSeconds,
    required this.showNext,
  });

  final LevelSpec spec;
  final String time;
  final int hintsUsed;
  final int? bestSeconds;
  final bool showNext;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Board cleared', style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          Text(
            '${spec.displayName}, ${spec.size}x${spec.size}, '
            '${spec.difficulty.label}',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _Stat(label: 'Time', value: time),
              _Stat(
                label: 'Best',
                value: bestSeconds == null
                    ? '--'
                    : '${(bestSeconds! ~/ 60).toString().padLeft(2, '0')}:'
                        '${(bestSeconds! % 60).toString().padLeft(2, '0')}',
              ),
              _Stat(label: 'Hints', value: '$hintsUsed'),
            ],
          ),
          const SizedBox(height: 24),
          if (showNext)
            FilledButton(
              onPressed: () => Navigator.of(context).pop('next'),
              child: const Text('Next level'),
            ),
          if (showNext) const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).pop('replay'),
            child: const Text('Play again'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop('home'),
            child: const Text('Back to menu'),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Text(
          value,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.2,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
