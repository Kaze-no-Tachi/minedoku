/// The rules of Minedoku, in one place.
///
/// On an `n x n` grid split into `n` coloured regions, place exactly `n` mines
/// so that:
///
/// 1. every row holds exactly one mine;
/// 2. every column holds exactly one mine;
/// 3. every coloured region holds exactly one mine;
/// 4. no two mines touch, not even diagonally.
abstract final class MinedokuRules {
  /// Short player-facing rule summaries, in the order above.
  static const List<String> summaries = [
    '1 mine per row',
    '1 mine per column',
    '1 mine per colour',
    'Mines cannot touch',
  ];

  /// Why two mines cannot both be right.
  static const String rowRule = 'Two mines in the same row';
  static const String columnRule = 'Two mines in the same column';
  static const String regionRule = 'Two mines in the same colour';
  static const String touchRule = 'These mines are touching';

  /// The up-to-eight cells surrounding [index] on a [size] grid.
  static List<int> neighbours(int size, int index) {
    final row = index ~/ size;
    final col = index % size;
    final result = <int>[];
    for (var dr = -1; dr <= 1; dr++) {
      for (var dc = -1; dc <= 1; dc++) {
        if (dr == 0 && dc == 0) continue;
        final r = row + dr;
        final c = col + dc;
        if (r < 0 || r >= size || c < 0 || c >= size) continue;
        result.add(r * size + c);
      }
    }
    return result;
  }

  /// True when the two cells are orthogonally or diagonally adjacent.
  static bool touching(int size, int a, int b) {
    if (a == b) return false;
    final dr = (a ~/ size) - (b ~/ size);
    final dc = (a % size) - (b % size);
    return dr.abs() <= 1 && dc.abs() <= 1;
  }

  /// Every rule broken by the given set of placed [mines].
  ///
  /// Returns one [RuleViolation] per offending pair, so the UI can highlight
  /// both cells and explain which rule they break.
  static List<RuleViolation> violations(
    int size,
    List<int> regions,
    Iterable<int> mines,
  ) {
    final placed = mines.toList()..sort();
    final result = <RuleViolation>[];
    for (var i = 0; i < placed.length; i++) {
      for (var j = i + 1; j < placed.length; j++) {
        final a = placed[i];
        final b = placed[j];
        if (a ~/ size == b ~/ size) {
          result.add(RuleViolation(a, b, rowRule));
        } else if (a % size == b % size) {
          result.add(RuleViolation(a, b, columnRule));
        } else if (regions[a] == regions[b]) {
          result.add(RuleViolation(a, b, regionRule));
        } else if (touching(size, a, b)) {
          result.add(RuleViolation(a, b, touchRule));
        }
      }
    }
    return result;
  }
}

/// A single broken rule, naming the two cells responsible.
class RuleViolation {
  const RuleViolation(this.a, this.b, this.reason);

  final int a;
  final int b;
  final String reason;

  @override
  String toString() => '$reason ($a, $b)';
}
