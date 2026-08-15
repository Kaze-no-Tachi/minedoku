import 'package:minedoku_engine/minedoku_engine.dart';
void main() {
  const g = PuzzleGenerator();
  for (final size in [5, 6, 7, 8, 9]) {
    final w = Stopwatch()..start();
    for (var s = 1; s <= 50; s++) { g.generate(size: size, seed: s * 977); }
    w.stop();
    print('${size}x$size: ${(w.elapsedMicroseconds / 50 / 1000).toStringAsFixed(1)} ms avg');
  }
}
