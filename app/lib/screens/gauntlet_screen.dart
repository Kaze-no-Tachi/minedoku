import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../state/app_state.dart';
import 'game_screen.dart';

/// A run of boards played back to back on three shared lives.
///
/// The campaign is a ladder you climb once. This is the loop worth coming back
/// to: boards climb in difficulty, mistakes carry across all of them, and the
/// run ends the moment the third one lands.
class GauntletScreen extends StatefulWidget {
  const GauntletScreen({super.key});

  @override
  State<GauntletScreen> createState() => _GauntletScreenState();
}

class _GauntletScreenState extends State<GauntletScreen> {
  GauntletRun _run = const GauntletRun();

  /// Fixed for the whole run, so its boards are reproducible together while
  /// separate runs differ.
  late final int _seed =
      DateTime.now().microsecondsSinceEpoch % 1000000;

  @override
  Widget build(BuildContext context) {
    return GameScreen(
      // A new key per stage so each board gets a fresh controller rather than
      // inheriting the last one's timer and marks.
      key: ValueKey('gauntlet-$_seed-${_run.stage}'),
      spec: _run.specFor(_seed),
      isCampaign: false,
      gauntlet: _run,
      onGauntletCleared: _onCleared,
      onGauntletLost: _onLost,
    );
  }

  void _onCleared(int seconds, int mistakes) {
    // Mistakes come back from the board because they may have gone up during
    // it, and the run owns the total.
    final next = GauntletRun(
      stage: _run.stage,
      mistakes: mistakes,
      clearedSeconds: _run.clearedSeconds,
    ).cleared(seconds);

    setState(() => _run = next);
    _showStageCleared(next);
  }

  Future<void> _showStageCleared(GauntletRun next) async {
    await showModalBottomSheet<void>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (context) => _StageClearedSheet(run: next),
    );
  }

  Future<void> _onLost(int mistakes) async {
    final appState = AppScope.of(context);
    final cleared = _run.stage;
    final record = await appState.stats.recordGauntlet(cleared);
    if (!mounted) return;

    final again = await showModalBottomSheet<bool>(
      context: context,
      isDismissible: false,
      enableDrag: false,
      showDragHandle: true,
      builder: (context) => _RunOverSheet(
        cleared: cleared,
        best: appState.stats.bestGauntlet,
        isRecord: record,
      ),
    );
    if (!mounted) return;

    if (again ?? false) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const GauntletScreen()),
      );
    } else {
      Navigator.of(context).pop();
    }
  }
}

class _StageClearedSheet extends StatelessWidget {
  const _StageClearedSheet({required this.run});

  final GauntletRun run;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '${run.stage} cleared',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Next up: board ${run.boardNumber}, ${run.difficulty.label}.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 16),
          _Lives(left: run.livesLeft),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Keep going'),
          ),
        ],
      ),
    );
  }
}

class _RunOverSheet extends StatelessWidget {
  const _RunOverSheet({
    required this.cleared,
    required this.best,
    required this.isRecord,
  });

  final int cleared;
  final int best;
  final bool isRecord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            isRecord ? 'Best run yet' : 'Run over',
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            cleared == 0
                ? 'No boards cleared this time.'
                : '$cleared board${cleared == 1 ? '' : 's'} cleared.',
            style: theme.textTheme.bodyLarge,
          ),
          const SizedBox(height: 4),
          Text(
            isRecord ? 'A new personal best.' : 'Best so far: $best.',
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Run it again'),
          ),
          const SizedBox(height: 10),
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Back to menu'),
          ),
        ],
      ),
    );
  }
}

class _Lives extends StatelessWidget {
  const _Lives({required this.left});

  final int left;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < MistakeRules.lives; i++)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 3),
            child: Icon(
              i < left ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              size: 22,
              color: i < left
                  ? const Color(0xFFE8536B)
                  : scheme.onSurfaceVariant.withValues(alpha: 0.4),
            ),
          ),
      ],
    );
  }
}
