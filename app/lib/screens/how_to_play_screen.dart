import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/board_view.dart';

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
                  title: 'Tap to take notes',
                  body: 'Once marks a cell as clear (X), twice marks it as a '
                      'maybe (?), a third time empties it. Notes are free and '
                      'never count against you.',
                ),
                const _Step(
                  icon: Icons.pan_tool_outlined,
                  title: 'Hold to commit a mine',
                  body: 'Press and hold to place a mine, and hold again to '
                      'take it back. A mine is the only move that can be '
                      'wrong, so it takes a deliberate press.',
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
    final appState = AppScope.of(context);
    // The real board widget, not a lookalike, so the illustration always shows
    // the player exactly what they are about to see.
    final puzzle = Puzzle(size: 4, regions: _regions, solution: _solution);
    final board = GameBoard(puzzle, autoBlock: false);
    for (final cell in puzzle.solutionCells) {
      board.setMark(cell, CellMark.mine);
    }

    return Center(
      child: SizedBox(
        width: 210,
        height: 210,
        child: BoardView(
          board: board,
          theme: appState.gameTheme,
          showPatterns: appState.showPatterns,
          interactive: false,
          onTapCell: (_) {},
          onLongPressCell: (_) {},
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
