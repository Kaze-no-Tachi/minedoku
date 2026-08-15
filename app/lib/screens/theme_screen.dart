import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/board_view.dart';

/// Picks the board's look, and controls the accessibility patterns.
///
/// Every theme is previewed on a real board rather than a swatch row, because
/// what matters is whether you can read a board in it.
class ThemeScreen extends StatelessWidget {
  const ThemeScreen({super.key});

  /// A small fixed board for previews. Fixed, not generated, so every theme is
  /// judged on identical shapes.
  static final Puzzle _preview = Puzzle(
    size: 5,
    regions: const [
      0, 0, 1, 1, 1, //
      0, 2, 2, 1, 3, //
      4, 2, 2, 3, 3, //
      4, 4, 5, 5, 3, //
      6, 6, 7, 8, 8, //
    ],
    solution: const [1, 4, 0, 2, 4],
  );

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Look and feel')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
              children: [
                for (final theme in GameThemes.all)
                  _ThemeCard(
                    theme: theme,
                    selected: theme.id == appState.settings.themeId,
                    showPatterns: _previewPatterns(appState, theme),
                    onTap: () => appState.settings.setThemeId(theme.id),
                  ),
                const SizedBox(height: 16),
                const _PatternSection(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Whether the preview shows patterns, following the same rule the board
  /// itself uses so the preview never lies.
  static bool _previewPatterns(AppState state, GameTheme theme) =>
      switch (state.settings.patternMode) {
        PatternMode.always => true,
        PatternMode.never => false,
        PatternMode.auto => !theme.isColorBlindSafe,
      };
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.showPatterns,
    required this.onTap,
  });

  final GameTheme theme;
  final bool selected;
  final bool showPatterns;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;

    final board = GameBoard(ThemeScreen._preview, autoBlock: false);
    for (final cell in ThemeScreen._preview.solutionCells) {
      board.setMark(cell, CellMark.mine);
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: selected ? scheme.primaryContainer : scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                SizedBox(
                  width: 108,
                  height: 108,
                  child: BoardView(
                    board: board,
                    theme: theme,
                    showPatterns: showPatterns,
                    interactive: false,
                    onTapCell: (_) {},
                    onLongPressCell: (_) {},
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              theme.name,
                              style: text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (selected)
                            Icon(Icons.check_circle_rounded,
                                color: scheme.primary, size: 20),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        theme.tagline,
                        style: text.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _ContrastBadge(theme: theme),
                    ],
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

/// States plainly whether a theme's colours stand on their own.
///
/// Measured, not claimed: the number comes from simulating each form of colour
/// blindness and finding the closest pair of regions.
class _ContrastBadge extends StatelessWidget {
  const _ContrastBadge({required this.theme});

  final GameTheme theme;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final safe = theme.isColorBlindSafe;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          safe ? Icons.visibility_rounded : Icons.texture_rounded,
          size: 14,
          color: scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 6),
        Flexible(
          child: Text(
            safe
                ? 'Colours alone are enough'
                : 'Uses patterns to stay readable',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
          ),
        ),
      ],
    );
  }
}

class _PatternSection extends StatelessWidget {
  const _PatternSection();

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PATTERNS',
          style: text.labelSmall?.copyWith(
            letterSpacing: 1.6,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Each colour also gets its own texture. Nine colours cannot all be '
          'told apart with every kind of colour vision, so the texture carries '
          'what the colour cannot.',
          style: text.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            height: 1.5,
          ),
        ),
        const SizedBox(height: 12),
        RadioGroup<PatternMode>(
          groupValue: appState.settings.patternMode,
          onChanged: (value) {
            if (value != null) appState.settings.setPatternMode(value);
          },
          child: Column(
            children: [
              for (final mode in PatternMode.values)
                RadioListTile<PatternMode>(
                  value: mode,
                  title: Text(mode.label),
                  subtitle: Text(mode.description),
                  contentPadding: EdgeInsets.zero,
                ),
            ],
          ),
        ),
      ],
    );
  }
}
