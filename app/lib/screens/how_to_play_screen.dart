import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/mine_icon.dart';

/// Explains the rules with a small worked example.
class HowToPlayScreen extends StatelessWidget {
  const HowToPlayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('How to play')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
              children: [
                Text(
                  'The goal',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Place one mine in every row, every column and every colour, '
                  'and never let two mines touch. On a 7x7 board that means '
                  'seven mines.',
                  style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                ),
                const SizedBox(height: 24),
                const _ExampleBoard(),
                const SizedBox(height: 8),
                Text(
                  'A solved 4x4 board. Every row, column and colour holds '
                  'exactly one mine, and no two of them are neighbours, not '
                  'even corner to corner.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  'Controls',
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 12),
                const _Step(
                  icon: Icons.touch_app_outlined,
                  title: 'Tap to cycle',
                  body: 'Once marks a cell clear (X), twice places a mine, '
                      'a third time empties it again.',
                ),
                const _Step(
                  icon: Icons.pan_tool_outlined,
                  title: 'Hold to place',
                  body: 'Press and hold a cell to drop a mine straight away.',
                ),
                const _Step(
                  icon: Icons.lightbulb_outline_rounded,
                  title: 'Hints explain themselves',
                  body: 'A hint names the reason, for example that a colour '
                      'has only one cell left, rather than just giving away '
                      'the answer.',
                ),
                const _Step(
                  icon: Icons.verified_outlined,
                  title: 'No guessing needed',
                  body: 'Every board has exactly one solution and can always '
                      'be worked out by logic alone.',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A small solved board, built from a fixed layout rather than the generator so
/// the illustration never changes.
class _ExampleBoard extends StatelessWidget {
  const _ExampleBoard();

  static const _regions = [
    0, 0, 1, 1, //
    0, 2, 1, 1, //
    2, 2, 3, 1, //
    3, 3, 3, 1, //
  ];
  static const _solution = [1, 3, 0, 2];

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final mines = {for (var r = 0; r < 4; r++) r * 4 + _solution[r]};

    return Center(
      child: SizedBox(
        width: 200,
        height: 200,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(
              color: MinedokuTheme.regionBorder(brightness),
              width: 3,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(9),
            child: GridView.count(
              crossAxisCount: 4,
              physics: const NeverScrollableScrollPhysics(),
              children: [
                for (var i = 0; i < 16; i++)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: MinedokuTheme.regionColor(_regions[i]),
                      border: Border(
                        top: BorderSide(
                          color: i >= 4 && _regions[i - 4] != _regions[i]
                              ? MinedokuTheme.regionBorder(brightness)
                              : MinedokuTheme.cellBorder(brightness),
                          width: i >= 4 && _regions[i - 4] != _regions[i]
                              ? 2.5
                              : 0.5,
                        ),
                        left: BorderSide(
                          color: i % 4 != 0 && _regions[i - 1] != _regions[i]
                              ? MinedokuTheme.regionBorder(brightness)
                              : MinedokuTheme.cellBorder(brightness),
                          width: i % 4 != 0 && _regions[i - 1] != _regions[i]
                              ? 2.5
                              : 0.5,
                        ),
                      ),
                    ),
                    child: mines.contains(i)
                        ? const Center(child: MineIcon(size: 28))
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: theme.colorScheme.primary),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
