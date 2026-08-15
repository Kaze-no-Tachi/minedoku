// Prints a few hints so their wording can be reviewed by eye.
import 'package:minedoku_engine/minedoku_engine.dart';

void main() {
  const gen = PuzzleGenerator();
  const hints = HintEngine();
  for (var seed = 1; seed <= 6; seed++) {
    final puzzle = gen.generate(size: 6, seed: seed);
    final board = GameBoard(puzzle, autoBlock: true);
    for (var step = 0; step < 3 && !board.isSolved; step++) {
      final h = hints.next(board);
      print('[seed $seed] ${h.kind.name} (${h.relatedCells.length} highlighted)');
      print('    ${h.message}');
      if (h.kind == HintKind.forcedMine || h.kind == HintKind.reveal) {
        board.setMark(h.cell!, CellMark.mine);
      } else if (h.kind == HintKind.ruledOut) {
        board.setMark(h.cell!, CellMark.blocked);
      } else {
        break;
      }
    }
  }
}
