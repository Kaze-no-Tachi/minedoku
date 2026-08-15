/// Backtracking solver for Minedoku boards.
///
/// The search walks one row at a time, which makes three of the four rules
/// nearly free:
///
/// * one mine per row is guaranteed by construction (one choice per row);
/// * columns and regions are tracked with "already used" flags;
/// * because each row holds exactly one mine, the only way two mines can touch
///   is across neighbouring rows, so the adjacency rule reduces to
///   `(column - previousColumn).abs() >= 2`.
class Solver {
  Solver(this.size, this.regions)
      : assert(regions.length == size * size, 'regions must be size * size');

  final int size;
  final List<int> regions;

  /// Cells the player has already committed to. `fixed[row]` is a column, or
  /// `null` when the row is still open.
  ///
  /// [banned] holds cell indices that must not be used (the player's own
  /// "definitely not here" marks, or cells ruled out by a hint search).
  int countSolutions({
    int limit = 2,
    List<int?>? fixed,
    Set<int>? banned,
  }) {
    final found = _search(
      limit: limit,
      fixed: fixed,
      banned: banned,
      collect: null,
    );
    return found;
  }

  /// The first solution found, or `null` when there is none.
  List<int>? solve({List<int?>? fixed, Set<int>? banned}) {
    final sink = <List<int>>[];
    _search(limit: 1, fixed: fixed, banned: banned, collect: sink);
    return sink.isEmpty ? null : sink.first;
  }

  /// Up to [limit] solutions, as lists of one column per row.
  List<List<int>> allSolutions({int limit = 10, List<int?>? fixed, Set<int>? banned}) {
    final sink = <List<int>>[];
    _search(limit: limit, fixed: fixed, banned: banned, collect: sink);
    return sink;
  }

  int _search({
    required int limit,
    required List<int?>? fixed,
    required Set<int>? banned,
    required List<List<int>>? collect,
  }) {
    final usedColumn = List<bool>.filled(size, false);
    final usedRegion = List<bool>.filled(size, false);
    final columns = List<int>.filled(size, -1);
    var found = 0;

    void recurse(int row, int previousColumn) {
      if (found >= limit) return;
      if (row == size) {
        found++;
        collect?.add(List<int>.from(columns));
        return;
      }
      final forced = fixed != null ? fixed[row] : null;
      for (var col = 0; col < size; col++) {
        if (forced != null && col != forced) continue;
        if (usedColumn[col]) continue;
        if (previousColumn >= 0 && (col - previousColumn).abs() < 2) continue;
        final cell = row * size + col;
        if (banned != null && banned.contains(cell)) continue;
        final region = regions[cell];
        if (usedRegion[region]) continue;

        usedColumn[col] = true;
        usedRegion[region] = true;
        columns[row] = col;
        recurse(row + 1, col);
        usedColumn[col] = false;
        usedRegion[region] = false;
        if (found >= limit) return;
      }
    }

    recurse(0, -1);
    return found;
  }
}
