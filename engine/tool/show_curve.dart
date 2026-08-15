import 'package:minedoku_engine/minedoku_engine.dart';
void main() {
  const g = PuzzleGenerator();
  print('level  board  difficulty  score  per-mine  profile');
  for (final level in [1, 3, 5, 6, 9, 13, 17, 21, 27, 33, 40, 49, 58, 67, 76, 87, 98, 110, 130]) {
    final s = Levels.forLevel(level);
    final r = DifficultyRater.rate(g.generate(size: s.size, seed: s.seed));
    final bar = '#' * (r.density / 2).round().clamp(0, 30);
    print('${level.toString().padLeft(5)}  ${s.size}x${s.size}  '
        '${s.difficulty.label.padRight(10)} ${r.score.toString().padLeft(5)}  '
        '${r.density.toStringAsFixed(1).padLeft(8)}  $bar');
  }
}
