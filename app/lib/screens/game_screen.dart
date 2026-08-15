import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../state/app_state.dart';
import '../state/game_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/board_view.dart';
import '../audio/sound_service.dart';
import '../widgets/detonation.dart';
import '../widgets/star_row.dart';

/// Plays one board.
class GameScreen extends StatefulWidget {
  const GameScreen({
    super.key,
    required this.spec,
    this.isCampaign = true,
    this.isDaily = false,
    this.endlessDifficulty,
    this.restoreMarks,
    this.restoreSeconds = 0,
    this.gauntlet,
    this.onGauntletCleared,
    this.onGauntletLost,
  });

  final LevelSpec spec;
  final bool isCampaign;
  final bool isDaily;

  /// Set for endless boards, so winning can deal another at the same level of
  /// challenge without going back to the menu.
  final Difficulty? endlessDifficulty;

  /// The run this board belongs to, when played as part of a gauntlet.
  final GauntletRun? gauntlet;

  /// Called with the board's time and the run's mistake total once cleared.
  final void Function(int seconds, int mistakes)? onGauntletCleared;

  /// Called once the board has finished exploding and the run is over.
  final void Function(int mistakes)? onGauntletLost;
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

    final run = widget.gauntlet;
    final controller = GameController(
      spec: widget.spec,
      appState: AppScope.of(context),
      isCampaign: widget.isCampaign,
      isDaily: widget.isDaily,
      // A gauntlet carries its mistakes between boards and is always hard,
      // whatever the menu setting says.
      initialMistakes: run?.mistakes ?? 0,
      forceMode: run == null ? null : GameMode.hard,
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
        if (!mounted) return;
        final handOff = widget.onGauntletCleared;
        if (handOff != null) {
          handOff(_controller!.seconds, _controller!.mistakes);
        } else {
          _showWinSheet();
        }
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
    final best = widget.isCampaign ? appState.progress.bestTime(widget.spec.number) : null;

    final action = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (context) => _WinSheet(
        spec: widget.spec,
        time: controller.formattedTime,
        seconds: controller.seconds,
        hintsUsed: controller.hintsUsed,
        bestSeconds: best,
        stars: controller.starsEarned,
        showNext: widget.isCampaign,
        showAnother: widget.endlessDifficulty != null,
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
      case 'another':
        final difficulty = widget.endlessDifficulty!;
        final roll = DateTime.now().microsecondsSinceEpoch % 1000000;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(
            builder: (_) => GameScreen(
              spec: Levels.endless(difficulty, roll),
              isCampaign: false,
              endlessDifficulty: difficulty,
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

  /// Centres of the real mines, as fractions of the board, so the blast comes
  /// from where the mines actually were.
  List<Offset> _blastOrigins(GameController controller) {
    final puzzle = controller.board!.puzzle;
    final n = puzzle.size;
    return [
      for (final cell in puzzle.solutionCells)
        Offset((cell % n + 0.5) / n, (cell ~/ n + 0.5) / n),
    ];
  }

  String _statusLine(GameController controller) {
    if (controller.hasLost) return 'The board went up. Three mistakes is all.';
    if (controller.rejectedCell != null) {
      final left = controller.livesLeft;
      return left == 1
          ? 'No mine can go there. One mistake left.'
          : 'No mine can go there. $left mistakes left.';
    }
    if (controller.hint != null) return controller.hint!.message;
    if (controller.conflictCells.isNotEmpty) return 'Those mines break a rule.';
    if (controller.needsControlHint) {
      return 'Tap to take notes. Hold to place a mine.';
    }
    return '';
  }

  bool _statusIsWarning(GameController controller) =>
      controller.hasLost ||
      controller.rejectedCell != null ||
      (controller.conflictCells.isNotEmpty && controller.hint == null);

  Future<void> _showLossSheet() async {
    if (!mounted) return;
    final controller = _controller!;
    // In a gauntlet the run owns the aftermath, not this screen.
    final runLost = widget.onGauntletLost;
    if (runLost != null) {
      runLost(controller.mistakes);
      return;
    }
    final action = await showModalBottomSheet<String>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (context) => _LossSheet(spec: widget.spec),
    );
    if (!mounted) return;

    if (action == 'retry') {
      controller.retry();
    } else {
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
        return PopScope(
          // A back gesture is far too easy to fire by accident: on a phone it
          // is a swipe from either screen edge, and the board is drawn close to
          // both. Losing a part-solved board to a stray thumb is not acceptable,
          // so leaving one is confirmed rather than silent.
          canPop: !_shouldConfirmExit(controller),
          onPopInvokedWithResult: (didPop, _) async {
            if (didPop || !mounted) return;
            // Captured before the await, so no BuildContext crosses it.
            final navigator = Navigator.of(context);
            if (await _confirmExit() && mounted) navigator.pop();
          },
          child: _buildScaffold(context, controller),
        );
      },
    );
  }

  /// True when walking away now would throw away real work.
  bool _shouldConfirmExit(GameController controller) =>
      !controller.loading && !controller.isFinished && controller.hasProgress;

  Future<bool> _confirmExit() async {
    final resumable = widget.isCampaign || widget.isDaily;
    final answer = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Leave this board?'),
        content: Text(
          resumable
              ? 'It is saved, so you can pick it up where you left off.'
              : 'This board is not saved, so you would be starting over.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Keep playing'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Leave'),
          ),
        ],
      ),
    );
    return answer ?? false;
  }

  Widget _buildScaffold(BuildContext context, GameController controller) {
    return Scaffold(
          appBar: AppBar(
            title: Text(widget.gauntlet == null
                ? widget.spec.displayName
                : 'Board ${widget.gauntlet!.boardNumber}'),
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
  }

  Widget _buildGame(BuildContext context, GameController controller) {
    final theme = Theme.of(context);
    final appState = AppScope.of(context);

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
                      _Readouts(
                        controller: controller,
                        showTimer: appState.settings.showTimer,
                      ),
                      const SizedBox(height: 16),
                      Detonation(
                        active: controller.hasLost,
                        origins: _blastOrigins(controller),
                        onComplete: _showLossSheet,
                        child: BoardView(
                          board: controller.board!,
                          theme: appState.gameTheme,
                          showPatterns: appState.showPatterns,
                          conflictCells: {
                            ...controller.conflictCells,
                            if (controller.rejectedCell != null)
                              controller.rejectedCell!,
                          },
                          hintCell: controller.hint?.cell,
                          relatedCells:
                              controller.hint?.relatedCells ?? const [],
                          onTapCell: controller.tapCell,
                          onLongPressCell: controller.toggleMine,
                        ),
                      ),
                      const SizedBox(height: 14),
                      // Minimum, not fixed: explanations run to a few lines and
                      // must not be clipped.
                      ConstrainedBox(
                        constraints: const BoxConstraints(minHeight: 52),
                        child: Center(
                          child: Text(
                            _statusLine(controller),
                            textAlign: TextAlign.center,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: _statusIsWarning(controller)
                                  ? AppTheme.conflict
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
  const _Readouts({required this.controller, required this.showTimer});

  final GameController controller;

  /// A running clock makes some players anxious. The time is still recorded
  /// and still shown on the win sheet.
  final bool showTimer;

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
        if (showTimer) ...[
          const SizedBox(width: 10),
          Expanded(
            child: _Readout(label: 'Time', value: controller.formattedTime),
          ),
        ],
        const SizedBox(width: 10),
        Expanded(
          // In hard mode the lives matter more than the board size, and there
          // is only room for three tiles on a narrow phone.
          child: controller.mode.isHard
              ? _Readout(
                  label: 'Mistakes left',
                  value: '${controller.livesLeft}',
                  alarm: controller.livesLeft <= 1,
                )
              : _Readout(
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
    this.alarm = false,
  });

  final String label;
  final String value;
  final bool highlight;

  /// Draws the value in the warning colour, for a life count running out.
  final bool alarm;

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
              color: highlight
                  ? AppTheme.hintGlow
                  : (alarm ? AppTheme.conflict : null),
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
            icon: controller.hintsAllowed
                ? Icons.lightbulb_outline_rounded
                : Icons.lightbulb_outline,
            label: 'Hint',
            onPressed:
                done || !controller.hintsAllowed ? null : controller.requestHint,
            tooltip: controller.hintsAllowed
                ? null
                : 'Hard mode has no hints. That is the trade.',
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
    this.tooltip,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final button = _button(context);
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }

  Widget _button(BuildContext context) {
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
    required this.seconds,
    required this.hintsUsed,
    required this.bestSeconds,
    required this.stars,
    required this.showNext,
    this.showAnother = false,
  });

  final LevelSpec spec;
  final String time;
  final int seconds;
  final int hintsUsed;
  final int? bestSeconds;
  final int stars;
  final bool showNext;
  final bool showAnother;

  /// What the next star would take, or null when all three are earned.
  ///
  /// Naming the target is the difference between a rating and a reason to
  /// play the board again.
  String? get nextStarGoal {
    if (stars >= StarRow.max) return null;
    if (hintsUsed > 0) return 'Finish without hints for the second star.';
    final target = LevelResult.targetSeconds(spec.size);
    final minutes = (target ~/ 60).toString().padLeft(2, '0');
    final rest = (target % 60).toString().padLeft(2, '0');
    return 'Beat $minutes:$rest for the third star.';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (stars > 0) ...[
            AnimatedStars(
              earned: stars,
              onStarLanded: (star) => SoundService.instance.play(
                switch (star) {
                  1 => Sfx.star1,
                  2 => Sfx.star2,
                  _ => Sfx.star3,
                },
              ),
            ),
            const SizedBox(height: 12),
          ],
          Text('Board cleared', style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 6),
          Text(
            '${spec.size}x${spec.size}, ${spec.difficulty.label}',
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
          if (nextStarGoal != null) ...[
            const SizedBox(height: 12),
            Text(
              nextStarGoal!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 24),
          if (showNext)
            FilledButton(
              onPressed: () => Navigator.of(context).pop('next'),
              child: const Text('Next level'),
            ),
          if (showAnother)
            FilledButton(
              onPressed: () => Navigator.of(context).pop('another'),
              child: Text('Another ${spec.difficulty.label.toLowerCase()} board'),
            ),
          if (showNext || showAnother) const SizedBox(height: 10),
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


/// Shown once the board has finished exploding.
class _LossSheet extends StatelessWidget {
  const _LossSheet({required this.spec});

  final LevelSpec spec;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.dangerous_rounded, size: 44, color: AppTheme.conflict),
          const SizedBox(height: 10),
          Text(
            'Board destroyed',
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Hard mode allows ${MistakeRules.lives} mistakes. '
            'The board is the same one, so the logic that beats it has not '
            'changed.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('retry'),
            child: const Text('Try again'),
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
