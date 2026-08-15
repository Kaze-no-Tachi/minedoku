// Measures how hard each campaign level actually is, by solving it with the
// hint engine and recording which class of deduction each step needed.
import 'package:minedoku_engine/minedoku_engine.dart';

const _gen = PuzzleGenerator();
const _hints = HintEngine();

/// Cost of each kind of step. A forced placement is something a beginner sees;
/// an unexplained rule-out needs a contradiction chased several moves deep.
const _cost = {
  HintKind.forcedMine: 1,
  HintKind.ruledOut: 3,
  HintKind.reveal: 12,
};

({int score, int steps, int forced, int ruled, int deep}) rate(Puzzle puzzle) {
  final board = GameBoard(puzzle, autoBlock: true);
  var score = 0, steps = 0, forced = 0, ruled = 0, deep = 0;

  while (!board.isSolved && steps < 400) {
    final hint = _hints.next(board);
    steps++;
    switch (hint.kind) {
      case HintKind.forcedMine:
        forced++;
        score += _cost[HintKind.forcedMine]!;
        board.setMark(hint.cell!, CellMark.mine);
      case HintKind.ruledOut:
        // An explained rule-out names the unit it starves; an unexplained one
        // needed a deeper search, so it costs more.
        final explained = hint.relatedCells.isNotEmpty;
        if (explained) {
          ruled++;
          score += _cost[HintKind.ruledOut]!;
        } else {
          deep++;
          score += 8;
        }
        board.setMark(hint.cell!, CellMark.blocked);
      case HintKind.reveal:
        deep++;
        score += _cost[HintKind.reveal]!;
        board.setMark(hint.cell!, CellMark.mine);
      case HintKind.removeMine:
      case HintKind.solved:
        return (score: score, steps: steps, forced: forced, ruled: ruled, deep: deep);
    }
  }
  return (score: score, steps: steps, forced: forced, ruled: ruled, deep: deep);
}

void main() {
  print('level size  score  steps  forced  ruled  deep');
  for (var level = 1; level <= 45; level++) {
    final spec = Levels.forLevel(level);
    final r = rate(_gen.generate(size: spec.size, seed: spec.seed));
    print('${level.toString().padLeft(5)} '
        '${spec.size}x${spec.size} '
        '${r.score.toString().padLeft(6)} '
        '${r.steps.toString().padLeft(6)} '
        '${r.forced.toString().padLeft(7)} '
        '${r.ruled.toString().padLeft(6)} '
        '${r.deep.toString().padLeft(5)}');
  }
}
