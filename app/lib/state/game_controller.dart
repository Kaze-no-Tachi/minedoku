import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:minedoku_engine/minedoku_engine.dart';

import 'app_state.dart';

/// Drives a single board: generation, taps, timer, hints and the win check.
///
/// The puzzle rules all live in the engine; this class is the bridge between
/// them and the widget tree.
class GameController extends ChangeNotifier {
  GameController({
    required this.spec,
    required this.appState,
    this.isCampaign = true,
    this.isDaily = false,
  });

  final LevelSpec spec;
  final AppState appState;

  /// Campaign boards save progress and unlock the next level. Dailies and
  /// practice boards do neither.
  final bool isCampaign;

  /// Set for the daily puzzle, which feeds the streak.
  final bool isDaily;

  static const _generator = PuzzleGenerator();
  static const _hintEngine = HintEngine();

  GameBoard? _board;
  Timer? _timer;
  Hint? _hint;
  bool _loading = true;
  bool _won = false;
  int _seconds = 0;
  int _hintsUsed = 0;

  GameBoard? get board => _board;

  bool get loading => _loading;

  bool get hasWon => _won;

  int get seconds => _seconds;

  int get hintsUsed => _hintsUsed;

  /// The hint currently being shown, cleared as soon as the player moves.
  Hint? get hint => _hint;

  int get minesRemaining => _board?.minesRemaining ?? spec.size;

  bool get canUndo => _board?.canUndo ?? false;

  bool get canRedo => _board?.canRedo ?? false;

  Set<int> get conflictCells => _board?.conflictCells ?? const {};

  String get formattedTime {
    final minutes = (_seconds ~/ 60).toString().padLeft(2, '0');
    final secs = (_seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$secs';
  }

  /// Builds the board and restores a saved game when there is one.
  ///
  /// Generation is fast (a few milliseconds, ~60ms for the largest boards), but
  /// it still happens off the first frame so the screen can paint immediately.
  Future<void> start({String? restoreMarks, int restoreSeconds = 0}) async {
    _loading = true;
    notifyListeners();

    // Yield once so the loading state actually renders before we block.
    await Future<void>.delayed(Duration.zero);

    final puzzle = _generator.generate(size: spec.size, seed: spec.seed);
    final board = GameBoard(puzzle, autoBlock: appState.settings.autoBlock);
    if (restoreMarks != null) {
      board.restoreMarks(restoreMarks);
    }

    _board = board;
    _seconds = restoreSeconds;
    _loading = false;
    _won = board.isSolved;
    notifyListeners();

    // Counted once per board opened, not per attempt, so the win rate means
    // "boards I finished" rather than "times I pressed replay".
    if (restoreMarks == null) {
      unawaited(appState.stats.recordStart(spec.size));
    }
    if (!_won) _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _seconds++;
      notifyListeners();
    });
  }

  /// Pauses the clock, for when the app goes to the background.
  void pause() {
    _timer?.cancel();
    _timer = null;
    _persist();
  }

  void resume() {
    if (!_won && _board != null && _timer == null) _startTimer();
  }

  // ------------------------------------------------------------------- moves

  void tapCell(int index) {
    final board = _board;
    if (board == null || _won) return;
    _hint = null;
    board.cycle(index);
    _afterMove(placed: board.markAt(index) == CellMark.mine);
  }

  /// Long press puts a mine down directly, skipping the X step.
  void placeMine(int index) {
    final board = _board;
    if (board == null || _won) return;
    _hint = null;
    board.setMark(
      index,
      board.markAt(index) == CellMark.mine ? CellMark.empty : CellMark.mine,
    );
    _afterMove(placed: board.markAt(index) == CellMark.mine);
  }

  void undo() {
    if (_board == null || _won) return;
    _hint = null;
    _board!.undo();
    _afterMove(placed: false);
  }

  void redo() {
    if (_board == null || _won) return;
    _hint = null;
    _board!.redo();
    _afterMove(placed: false);
  }

  void clearBoard() {
    if (_board == null || _won) return;
    _hint = null;
    _board!.clear();
    _afterMove(placed: false);
  }

  /// Asks the engine for the easiest next step and highlights it.
  void requestHint() {
    final board = _board;
    if (board == null || _won) return;
    _hint = _hintEngine.next(board);
    _hintsUsed++;
    _buzz(HapticFeedback.selectionClick);
    notifyListeners();
  }

  void _afterMove({required bool placed}) {
    final board = _board!;
    if (placed) {
      if (board.conflictCells.isEmpty) {
        _buzz(HapticFeedback.selectionClick);
      } else {
        _buzz(HapticFeedback.mediumImpact);
      }
    }
    if (board.isSolved) {
      _win();
    } else {
      _persist();
      notifyListeners();
    }
  }

  Future<void> _win() async {
    _won = true;
    _timer?.cancel();
    _timer = null;
    _buzz(HapticFeedback.heavyImpact);
    notifyListeners();

    // Lifetime stats count every finished board, campaign or not. Only the
    // campaign unlocks levels and awards stars.
    await appState.stats.recordWin(
      size: spec.size,
      seconds: _seconds,
      hints: _hintsUsed,
    );
    if (isDaily) {
      await appState.stats.recordDailyWin();
    }
    if (isCampaign) {
      await appState.progress.clearSavedGame();
      await appState.progress.recordWin(
        level: spec.number,
        size: spec.size,
        seconds: _seconds,
        hintsUsed: _hintsUsed,
      );
    }
  }

  /// Stars this run earned, for the win sheet. Zero outside the campaign.
  int get starsEarned => isCampaign
      ? LevelResult.starsFor(
          seconds: _seconds,
          hintsUsed: _hintsUsed,
          size: spec.size,
        )
      : 0;

  void _persist() {
    if (!isCampaign || _board == null) return;
    unawaited(appState.progress.saveGame(
      level: spec.number,
      marks: _board!.encodeMarks(),
      seconds: _seconds,
    ));
  }

  void _buzz(Future<void> Function() effect) {
    if (appState.settings.haptics) unawaited(effect());
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}
