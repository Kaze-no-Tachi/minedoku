import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/ambient_board.dart';
import '../widgets/logo_lockup.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';
import 'levels_screen.dart';
import 'theme_screen.dart';

/// The front door: the mark animates in, then a board comes alive behind the
/// menu and solves itself on a loop.
///
/// The intro plays once. An animation you have seen forty times is not
/// atmosphere, it is latency, so after the first launch the screen simply
/// appears and the ambient board fades in behind it.
class TitleScreen extends StatefulWidget {
  const TitleScreen({super.key});

  @override
  State<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends State<TitleScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _intro;
  bool _resolved = false;

  @override
  void initState() {
    super.initState();
    _intro = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_resolved) return;
    _resolved = true;

    final settings = AppScope.of(context).settings;
    final reduceMotion = MediaQuery.maybeDisableAnimationsOf(context) ?? false;

    if (settings.hasSeenIntro || reduceMotion) {
      _intro.value = 1;
    } else {
      _intro.forward();
      settings.setHasSeenIntro(true);
    }
  }

  @override
  void dispose() {
    _intro.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final game = appState.gameTheme;

    // The mark lands first, then everything else arrives under it.
    final markIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0, 0.55, curve: Curves.easeOutBack),
    );
    final contentIn = CurvedAnimation(
      parent: _intro,
      curve: const Interval(0.35, 1, curve: Curves.easeOut),
    );

    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: _AmbientBackdrop(theme: game, fade: contentIn),
          ),
          SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 480),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: ScaleTransition(
                              scale: Tween<double>(begin: 0.7, end: 1)
                                  .animate(markIn),
                              alignment: Alignment.centerLeft,
                              child: FadeTransition(
                                opacity: markIn,
                                child: LogoLockup(theme: game),
                              ),
                            ),
                          ),
                          FadeTransition(
                            opacity: contentIn,
                            child: IconButton(
                              tooltip: 'Settings',
                              onPressed: () => _showSettings(context),
                              icon: const Icon(Icons.settings_outlined),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 28),
                      FadeTransition(
                        opacity: contentIn,
                        child: SlideTransition(
                          position: Tween<Offset>(
                            begin: const Offset(0, 0.08),
                            end: Offset.zero,
                          ).animate(contentIn),
                          child: const _Menu(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSettings(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => const SettingsSheet(),
    );
  }
}

/// The self-solving board behind the menu, held large and faint.
class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop({required this.theme, required this.fade});

  final GameTheme theme;
  final Animation<double> fade;

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(begin: 0, end: 0.13).animate(fade),
      child: OverflowBox(
        maxWidth: double.infinity,
        maxHeight: double.infinity,
        child: Transform.rotate(
          angle: -0.12,
          child: SizedBox(
            width: 940,
            height: 940,
            // Larger board, no patterns: this is wallpaper, so smaller cells
            // sit quieter behind the menu and the accessibility textures would
            // only add noise where nothing is being read.
            child: AmbientBoard(theme: theme, size: 8),
          ),
        ),
      ),
    );
  }
}

class _Menu extends StatelessWidget {
  const _Menu();

  /// A throwaway number to pick a board with. Endless boards are meant to be
  /// different every time, so unlike the campaign they are not reproducible.
  static int _roll() => DateTime.now().microsecondsSinceEpoch % 1000000;

  static void _startEndless(
    BuildContext context,
    LevelSpec spec,
    Difficulty difficulty,
  ) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(
          spec: spec,
          isCampaign: false,
          endlessDifficulty: difficulty,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);
    final theme = Theme.of(context);
    final level = appState.progress.highestUnlockedLevel;
    final savedLevel = appState.progress.savedLevel;
    final streak = appState.stats.currentStreak();
    final playedToday = appState.stats.playedDaily();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (savedLevel != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => GameScreen(
                    spec: Levels.forLevel(savedLevel),
                    restoreMarks: appState.progress.savedMarks,
                    restoreSeconds: appState.progress.savedSeconds,
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
            MaterialPageRoute<void>(builder: (_) => const LevelsScreen()),
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
                    GameScreen(spec: spec, isCampaign: false, isDaily: true),
              ),
            );
          },
          icon: Icon(
            playedToday ? Icons.event_available_rounded : Icons.today_rounded,
          ),
          label: Text(
            streak > 0 ? 'Daily puzzle  ·  $streak day streak' : 'Daily puzzle',
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'ENDLESS',
          style: theme.textTheme.labelSmall?.copyWith(
            letterSpacing: 1.6,
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'A fresh board at the difficulty you pick, every time.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final difficulty in Difficulty.values)
              ActionChip(
                label: Text(difficulty.label),
                onPressed: () => _startEndless(
                  context,
                  Levels.endless(difficulty, _roll()),
                  difficulty,
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          'OR BY SIZE',
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
                  final spec = Levels.endlessAtSize(size, _roll());
                  _startEndless(context, spec, spec.difficulty);
                },
              ),
          ],
        ),
        const SizedBox(height: 20),
        TextButton.icon(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const HowToPlayScreen()),
          ),
          icon: const Icon(Icons.help_outline_rounded),
          label: const Text('How to play'),
        ),
      ],
    );
  }
}

/// Settings, shown as a sheet from the title screen.
class SettingsSheet extends StatefulWidget {
  const SettingsSheet({super.key});

  @override
  State<SettingsSheet> createState() => _SettingsSheetState();
}

class _SettingsSheetState extends State<SettingsSheet> {
  @override
  Widget build(BuildContext context) {
    final appState = AppScope.of(context);

    return SafeArea(
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Look and feel'),
              subtitle: Text(appState.gameTheme.name),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.of(context).pop();
                Navigator.of(context).push(
                  MaterialPageRoute<void>(builder: (_) => const ThemeScreen()),
                );
              },
            ),
            SwitchListTile(
              value: appState.settings.gameMode.isHard,
              secondary: const Icon(Icons.local_fire_department_outlined),
              title: const Text('Hard mode'),
              subtitle: const Text(
                'A wrong mine is refused and costs one of '
                '${MistakeRules.lives}. Run out and the board blows up. '
                'No hints.',
              ),
              onChanged: (value) async {
                await appState.settings.setGameMode(
                  value ? GameMode.hard : GameMode.relaxed,
                );
                if (mounted) setState(() {});
              },
            ),
            const Divider(height: 1),
            SwitchListTile(
              value: appState.settings.showTimer,
              title: const Text('Show the timer'),
              subtitle: const Text('Your time is still recorded either way.'),
              onChanged: (value) async {
                await appState.settings.setShowTimer(value);
                if (mounted) setState(() {});
              },
            ),
            SwitchListTile(
              value: appState.settings.autoBlock,
              title: const Text('Auto-mark ruled-out cells'),
              subtitle: const Text(
                'Placing a mine X\'s out every cell it rules out.',
              ),
              onChanged: (value) async {
                await appState.settings.setAutoBlock(value);
                if (mounted) setState(() {});
              },
            ),
            SwitchListTile(
              value: appState.settings.haptics,
              title: const Text('Vibration'),
              subtitle: const Text('A short buzz on placing and winning.'),
              onChanged: (value) async {
                await appState.settings.setHaptics(value);
                if (mounted) setState(() {});
              },
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.restart_alt_rounded),
              title: const Text('Reset progress'),
              subtitle: const Text('Clears levels, best times and stats.'),
              onTap: () => _confirmReset(context, appState),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmReset(BuildContext context, AppState appState) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reset progress?'),
        content: const Text(
          'Every unlocked level, best time and statistic is removed. Your '
          'theme and other settings are kept. This cannot be undone.',
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
  }
}
