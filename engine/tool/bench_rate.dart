import 'package:minedoku_engine/minedoku_engine.dart';
void main() {
  const g = PuzzleGenerator();
  for (final size in [5, 6, 7, 8, 9]) {
    final w = Stopwatch()..start();
    var trivial = 0;
    const n = 30;
    for (var s = 1; s <= n; s++) {
      final r = DifficultyRater.rate(g.generate(size: size, seed: s * 131));
      if (r.isTrivial) trivial++;
    }
    w.stop();
    print('${size}x$size: ${(w.elapsedMicroseconds / n / 1000).toStringAsFixed(1)} ms per board '
        '(generate+rate), trivial $trivial/$n');
  }
}
