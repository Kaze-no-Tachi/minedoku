import 'package:flutter/material.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/board_view.dart';
import 'game_screen.dart';
import 'how_to_play_screen.dart';

/// Teaches the game by playing it.
///
/// A fixed 4x4 board, solved one step at a time, where the player performs
/// every move themselves. Reading the rules and understanding them turn out to
/// be different things: the rules are four sentences and still leave a first
/// timer staring at a grid with no idea what to touch. So nothing here advances
/// on a timer or on a "Next" button when there is a move to make. You place the
/// mine, and the board answers.
///
/// The board is a literal rather than a generated puzzle so the script and what
/// is on screen can never drift apart.
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

/// What the player has to do to move on.
enum _Do {
  /// Read, then press Next.
  read,

  /// Cycle the highlighted cell all the way round, X to ? and back to empty.
  cycle,

  /// Press and hold the highlighted cell to commit a mine.
  hold,

  /// The end.
  finish,
}

class _Step {
  const _Step({
    required this.title,
    required this.body,
    required this.act,
    this.target,
    this.spotlight = const [],
  });

  final String title;
  final String body;
  final _Do act;

  /// The cell the player must act on.
  final int? target;

  /// The row, column or colour being talked about. Everything else dims.
  final List<int> spotlight;
}

/// The board:
///
///     A A B B
///     A C B B
///     C C D B
///     D D D B
///
/// with mines at (0,1), (1,3), (2,0) and (3,2).
const _regions = [
  0, 0, 1, 1, //
  0, 2, 1, 1, //
  2, 2, 3, 1, //
  3, 3, 3, 1, //
];
const _solution = [1, 3, 0, 2];

const _script = <_Step>[
  _Step(
    title: 'Four mines, four rules',
    body: 'Every row, every column and every colour holds exactly one mine, '
        'and no two mines may touch, not even at a corner. This board is 4x4, '
        'so four mines. Every board can be worked out. You never have to guess.',
    act: _Do.read,
  ),
  _Step(
    title: 'Hold to place a mine',
    body: 'Press and hold the highlighted cell. Holding is the only way to '
        'place a mine, so you can never lay one by accident.',
    act: _Do.hold,
    target: 1,
    spotlight: [0, 1, 2, 3],
  ),
  _Step(
    title: 'The board did that for you',
    body: 'Every X appeared on its own. Those cells share a row, a column, a '
        'colour or a corner with your mine, so not one of them can hold '
        'another. That is the whole game: each mine tells you where the next '
        'one cannot be.',
    act: _Do.read,
  ),
  _Step(
    title: 'Tap to take notes',
    body: 'Tap the highlighted cell three times. Once for an X, meaning you '
        'have ruled it out yourself. Again for a question mark, meaning you '
        'suspect it. Once more to clear it. Notes are free and can never be '
        'wrong.',
    act: _Do.cycle,
    target: 11,
  ),
  _Step(
    title: 'Now read the board',
    body: 'This row has four cells and three are ruled out. So the mine in '
        'this row can only be in the one that is left. No guessing, just the '
        'last cell standing.',
    act: _Do.read,
    spotlight: [4, 5, 6, 7],
  ),
  _Step(
    title: 'Place it',
    body: 'Hold the cell the row has left you.',
    act: _Do.hold,
    target: 7,
    spotlight: [4, 5, 6, 7],
  ),
  _Step(
    title: 'Colours work the same way',
    body: 'This colour has three cells and two of them are ruled out. Same '
        'reasoning, different shape.',
    act: _Do.read,
    spotlight: [5, 8, 9],
  ),
  _Step(
    title: 'Take it',
    body: 'Hold the only cell this colour has left.',
    act: _Do.hold,
    target: 8,
    spotlight: [5, 8, 9],
  ),
  _Step(
    title: 'One cell left on the board',
    body: 'The last row has one cell that is not ruled out, and it is the last '
        'column and the last colour too. Every rule points at the same square.',
    act: _Do.hold,
    target: 14,
    spotlight: [12, 13, 14, 15],
  ),
  _Step(
    title: 'That is the whole game',
    body: 'Tap to think, hold to commit, and let the X marks narrow it down. '
        'Real boards are bigger, but they are never harder than this, only '
        'longer.',
    act: _Do.finish,
  ),
];

class _TutorialScreenState extends State<TutorialScreen> {
  static final _puzzle = Puzzle(size: 4, regions: _regions, solution: _solution);

  // Auto-marking is forced on regardless of the player's settings: the third
  // step is about the X marks appearing, and it cannot teach that if they do
  // not.
  final GameBoard _board = GameBoard(_puzzle, autoBlock: true);

  int _index = 0;
  int _taps = 0;
  String? _nudge;

  _Step get _step => _script[_index];

  void _advance() {
    setState(() {
      _nudge = null;
      _taps = 0;
      if (_index < _script.length - 1) _index++;
    });
  }

  void _onTap(int cell) {
    final step = _step;
    if (step.act != _Do.cycle || cell != step.target) {
      setState(() => _nudge = 'Try the highlighted cell.');
      return;
    }
    setState(() {
      _nudge = null;
      _board.cycle(cell);
      _taps++;
    });
    // Round the whole cycle and back to empty, so all three notes are seen.
    if (_taps >= 3 && _board.markAt(cell) == CellMark.empty) _advance();
  }

  void _onHold(int cell) {
    final step = _step;
    if (step.act != _Do.hold || cell != step.target) {
      setState(() => _nudge = 'Hold the highlighted cell.');
      return;
    }
    setState(() {
      _nudge = null;
      _board.setMark(cell, CellMark.mine);
    });
    _advance();
  }

  Future<void> _finish() async {
    final appState = AppScope.of(context);
    final navigator = Navigator.of(context);
    await appState.settings.setHasSeenTutorial(true);
    if (mounted) navigator.pop();
  }

  Future<void> _playNow() async {
    final appState = AppScope.of(context);
    final navigator = Navigator.of(context);
    await appState.settings.setHasSeenTutorial(true);
    if (!mounted) return;
    navigator.pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => GameScreen(spec: Levels.forLevel(1)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final appState = AppScope.of(context);
    final step = _step;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Learn to play'),
        actions: [
          TextButton(
            onPressed: _finish,
            child: Text(_index == _script.length - 1 ? 'Done' : 'Skip'),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                LinearProgressIndicator(
                  value: (_index + 1) / _script.length,
                  minHeight: 4,
                ),
                // The board and the words scroll; the buttons do not. A
                // tutorial whose only way forward is below the fold on a small
                // phone teaches nothing but frustration.
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(24, 20, 24, 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Center(
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 300),
                            child: BoardView(
                              board: _board,
                              theme: appState.gameTheme,
                              showPatterns: appState.showPatterns,
                              hintCell: step.target,
                              relatedCells: step.spotlight,
                              onTapCell: _onTap,
                              onLongPressCell: _onHold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 22),
                        Text(
                          step.title,
                          style: theme.textTheme.titleLarge
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          step.body,
                          style:
                              theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                        ),
                        // A correction belongs next to the instruction it is
                        // correcting, not marooned at the foot of the screen.
                        // The space is reserved so nothing shifts when it
                        // appears.
                        SizedBox(
                          height: 34,
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              _nudge ?? '',
                              style: theme.textTheme.bodyMedium?.copyWith(
                                color: AppTheme.conflict,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 4, 24, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: _actions(step),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _actions(_Step step) {
    switch (step.act) {
      case _Do.read:
        return [
          FilledButton(onPressed: _advance, child: const Text('Next')),
        ];
      case _Do.finish:
        return [
          FilledButton(
            onPressed: _playNow,
            child: const Text('Play level 1'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const HowToPlayScreen()),
            ),
            child: const Text('Read the rules again'),
          ),
        ];
      case _Do.cycle:
      case _Do.hold:
        // No button on purpose: the move on the board is the way forward.
        return const [];
    }
  }
}
