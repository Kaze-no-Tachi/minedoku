import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import 'game_screen.dart';

/// Grid of campaign levels, showing what is finished and what is still locked.
class LevelsScreen extends StatelessWidget {
  const LevelsScreen({super.key, this.count = 120});

  /// How many levels to list. The campaign itself is endless.
  final int count;

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final unlocked = appState.progress.highestUnlockedLevel;

    return Scaffold(
      appBar: AppBar(title: const Text('Levels')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate:
                  const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 1,
              ),
              itemCount: count,
              itemBuilder: (context, index) {
                final level = index + 1;
                return _LevelTile(
                  level: level,
                  locked: level > unlocked,
                  completed: appState.progress.isCompleted(level),
                  bestSeconds: appState.progress.bestTime(level),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.locked,
    required this.completed,
    required this.bestSeconds,
  });

  final int level;
  final bool locked;
  final bool completed;
  final int? bestSeconds;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spec = Levels.forLevel(level);
    // Tinted by measured difficulty rather than board size: difficulty is what
    // the campaign actually ramps, and size no longer tracks it.
    final game = AppScope.of(context).gameTheme;
    final tint = game.regionColor(spec.difficulty.index);

    return Opacity(
      opacity: locked ? 0.4 : 1,
      child: Material(
        color: completed
            ? tint.withValues(alpha: 0.9)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: locked
              ? null
              : () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => GameScreen(spec: spec),
                    ),
                  ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (locked)
                  Icon(
                    Icons.lock_outline_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurfaceVariant,
                  )
                else
                  Text(
                    '$level',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: completed ? game.glyphColor : null,
                    ),
                  ),
                const SizedBox(height: 2),
                Text(
                  '${spec.size}x${spec.size} ${spec.difficulty.label[0]}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: completed
                        ? game.glyphColor.withValues(alpha: 0.7)
                        : theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                if (bestSeconds != null)
                  Text(
                    '${(bestSeconds! ~/ 60).toString().padLeft(2, '0')}:'
                    '${(bestSeconds! % 60).toString().padLeft(2, '0')}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: game.glyphColor.withValues(alpha: 0.7),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
