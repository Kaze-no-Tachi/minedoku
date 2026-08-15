/// A small, fully deterministic pseudo-random number generator.
///
/// The engine deliberately avoids `dart:math`'s [Random]: its sequence is not
/// guaranteed to stay identical across Dart releases or platforms. Puzzle
/// number 42 must be the same board on an old Android phone, a new iPhone and
/// the web build, so the generator ships its own PRNG.
///
/// This is a 32-bit linear congruential generator (the "Numerical Recipes"
/// constants). Arithmetic is kept below 2^53 so it behaves identically on the
/// native VM (64-bit ints) and on the web (doubles).
class Prng {
  Prng(int seed) : _state = _mix(seed);

  static const int _modulus = 4294967296; // 2^32
  static const int _multiplier = 1664525;
  static const int _increment = 1013904223;

  int _state;

  /// Spreads out sequential seeds so that puzzle 1 and puzzle 2 do not start
  /// from near-identical states.
  static int _mix(int seed) {
    var s = seed % _modulus;
    if (s < 0) s += _modulus;
    for (var i = 0; i < 4; i++) {
      s = (_multiplier * s + _increment) % _modulus;
    }
    return s;
  }

  int _next() {
    _state = (_multiplier * _state + _increment) % _modulus;
    return _state;
  }

  /// A double in `[0, 1)`.
  double nextDouble() => _next() / _modulus;

  /// An integer in `[0, max)`. Throws if [max] is not positive.
  int nextInt(int max) {
    if (max <= 0) {
      throw ArgumentError.value(max, 'max', 'must be positive');
    }
    return (nextDouble() * max).floor();
  }

  /// Shuffles [items] in place (Fisher-Yates).
  void shuffle<T>(List<T> items) {
    for (var i = items.length - 1; i > 0; i--) {
      final j = nextInt(i + 1);
      final tmp = items[i];
      items[i] = items[j];
      items[j] = tmp;
    }
  }

  /// Picks an index in `[0, weights.length)` with probability proportional to
  /// its weight. Assumes at least one weight is greater than zero.
  int pickWeighted(List<double> weights) {
    var total = 0.0;
    for (final w in weights) {
      total += w;
    }
    var roll = nextDouble() * total;
    for (var i = 0; i < weights.length; i++) {
      roll -= weights[i];
      if (roll < 0) return i;
    }
    return weights.length - 1;
  }
}
