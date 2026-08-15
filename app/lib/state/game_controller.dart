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
  bool _lost = false;
  int _seconds = 0;
  int _hintsUsed = 0;
  int _mistakes = 0;
  int? _rejectedCell;
  late GameMode _mode;

  GameBoard? get board => _board;

  bool get loading => _loading;

  bool get hasWon => _won;

  int get seconds => _seconds;

  int get hintsUsed => _hintsUsed;

  /// The hint currently being shown, cleared as soon as the player moves.
  Hint? get hint => _hint;

  /// Difficulty for this board, fixed when it was opened. Changing the setting
  /// mid-game would move the goalposts under the player.
  GameMode get mode => _mode;

  bool get hasLost => _lost;

  /// True once the board is over, won or lost.
  bool get isFinished => _won || _lost;

  int get mistakes => _mistakes;

  int get livesLeft => MistakeRules.livesLeft(_mistakes);

  /// The cell of the most recent rejected placement, for a brief flash.
  int? get rejectedCell => _rejectedCell;

  /// Hints are what hard mode gives up. Limited mistakes mean little if the
  /// answer is a button press away.
  bool get hintsAllowed => !_mode.isHard;

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
    _mode = appState.settings.gameMode;
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
    if (board == null || isFinished) return;
    _hint = null;
    _clearRejection();
    // Cycling empty -> blocked -> mine, so only the step onto a mine can be a
    // mistake. Marking a cell clear is never punished, even when wrong.
    final becomingMine = board.markAt(index) == CellMark.blocked;
    if (becomingMine && _rejectPlacement(index)) return;
    board.cycle(index);
    _afterMove(placed: board.markAt(index) == CellMark.mine);
  }

  /// Long press puts a mine down directly, skipping the X step.
  void placeMine(int index) {
    final board = _board;
    if (board == null || isFinished) return;
    _hint = null;
    _clearRejection();
    final removing = board.markAt(index) == CellMark.mine;
    if (!removing && _rejectPlacement(index)) return;
    board.setMark(
      index,
      removing ? CellMark.empty : CellMark.mine,
    );
    _afterMove(placed: board.markAt(index) == CellMark.mine);
  }

  /// In hard mode, refuses a mine that cannot be part of the solution and
  /// charges a life for it.
  ///
  /// The mine is not left on the board: it is known to be wrong, and leaving a
  /// wrong mine sitting there while the game says "mistake" reads as a bug.
  bool _rejectPlacement(int index) {
    if (!_mode.isHard) return false;
    if (!MistakeRules.isMistake(_board!.puzzle, index)) return false;

    _mistakes++;
    _rejectedCell = index;
    _buzz(HapticFeedback.heavyImpact);
    if (MistakeRules.isLost(_mistakes)) {
      _lose();
    } else {
      notifyListeners();
    }
    return true;
  }

  /// Drops the highlight and message from the last refused placement.
  ///
  /// Called at the start of the next action rather than on a timer: the player
  /// should still be able to read why a mine was refused when they look back
  /// at the screen, and a self-expiring message is one they can miss entirely.
  void _clearRejection() => _rejectedCell = null;

  Future<void> _lose() async {
    _lost = true;
    _timer?.cancel();
    _timer = null;
    _buzz(HapticFeedback.heavyImpact);
    notifyListeners();
    // A lost board is not resumable: it would restore into a dead game.
    if (isCampaign) await appState.progress.clearSavedGame();
  }

  /// Starts the same board again from empty, keeping its difficulty.
  void retry() {
    _mistakes = 0;
    _lost = false;
    _won = false;
    _rejectedCell = null;
    _hint = null;
    _hintsUsed = 0;
    _seconds = 0;
    _board?.clear();
    notifyListeners();
    _startTimer();
  }

  void undo() {
    if (_board == null || isFinished) return;
    _hint = null;
    _clearRejection();
    _board!.undo();
    _afterMove(placed: false);
  }

  void redo() {
    if (_board == null || isFinished) return;
    _hint = null;
    _clearRejection();
    _board!.redo();
    _afterMove(placed: false);
  }

  void clearBoard() {
    if (_board == null || isFinished) return;
    _hint = null;
    _clearRejection();
    _board!.clear();
    _afterMove(placed: false);
  }

  /// Asks the engine for the easiest next step and highlights it.
  void requestHint() {
    final board = _board;
    if (board == null || isFinished || !hintsAllowed) return;
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
