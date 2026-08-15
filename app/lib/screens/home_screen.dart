import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../state/app_state.dart';
import '../theme.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'levels_screen.dart';

/// Main menu: continue, campaign, daily and practice.
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final theme = Theme.of(context);
    final level = appState.highestUnlockedLevel;
    final savedLevel = appState.savedLevel;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'MINEDOKU',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Settings',
                        onPressed: () => _showSettings(context),
                        icon: const Icon(Icons.settings_outlined),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'One mine per row, column and colour. '
                    'None of them may touch.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 28),
                  const _RulesStrip(),
                  const SizedBox(height: 28),

                  if (savedLevel != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: FilledButton.icon(
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => GameScreen(
                              spec: Levels.forLevel(savedLevel),
                              restoreMarks: appState.savedMarks,
                              restoreSeconds: appState.savedSeconds,
                            ),
                          ),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded),
                        label: Text('Continue level $savedLevel'),
                      ),
                    ),

                  FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => GameScreen(spec: Levels.forLevel(level)),
                      ),
                    ),
                    child: Text(
                      savedLevel == null ? 'Play level $level' : 'Level $level',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const LevelsScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.grid_view_rounded),
                    label: const Text('All levels'),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      final spec = Levels.daily(DateTime.now());
                      Navigator.of(context).push(
                        MaterialPageRoute<void>(
                          builder: (_) =>
                              GameScreen(spec: spec, isCampaign: false),
                        ),
                      );
                    },
                    icon: const Icon(Icons.today_rounded),
                    label: const Text('Daily puzzle'),
                  ),
                  const SizedBox(height: 24),

                  Text(
                    'PRACTICE',
                    style: theme.textTheme.labelSmall?.copyWith(
                      letterSpacing: 1.6,
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final size in const [5, 6, 7, 8, 9])
                        ActionChip(
                          label: Text('${size}x$size'),
                          onPressed: () {
                            final seed =
                                DateTime.now().millisecondsSinceEpoch % 1000000;
                            Navigator.of(context).push(
                              MaterialPageRoute<void>(
                                builder: (_) => GameScreen(
                                  spec: Levels.custom(size: size, seed: seed),
                                  isCampaign: false,
                                ),
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  TextButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(
                        builder: (_) => const HowToPlayScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.help_outline_rounded),
                    label: const Text('How to play'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => const _SettingsSheet(),
    );
  }
}

/// The four rules, shown as coloured chips so the menu teaches the game.
class _RulesStrip extends StatelessWidget {
  const _RulesStrip();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < MinedokuRules.summaries.length; i++)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: MinedokuTheme.regionColor(i * 2).withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              MinedokuRules.summaries[i],
              style: theme.textTheme.labelMedium?.copyWith(
                color: const Color(0xFF241E33),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
      ],
    );
  }
}

class _SettingsSheet extends StatefulWidget {
  const _SettingsSheet();

  @override
  State<_SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<_SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SwitchListTile(
            value: appState.autoBlock,
            title: const Text('Auto-mark ruled-out cells'),
            subtitle: const Text(
              'Placing a mine X\'s out every cell it rules out.',
            ),
            onChanged: (value) async {
              await appState.setAutoBlock(value);
              if (mounted) setState(() {});
            },
          ),
          SwitchListTile(
            value: appState.haptics,
            title: const Text('Vibration'),
            subtitle: const Text('A short buzz on placing and winning.'),
            onChanged: (value) async {
              await appState.setHaptics(value);
              if (mounted) setState(() {});
            },
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restart_alt_rounded),
            title: const Text('Reset progress'),
            subtitle: const Text('Clears unlocked levels and best times.'),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Reset progress?'),
                  content: const Text(
                    'Every unlocked level and best time is removed. '
                    'This cannot be undone.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Reset'),
                    ),
                  ],
                ),
              );
              if (confirmed != true) return;
              await appState.resetProgress();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
