// Searches for boards at each (size, difficulty) and writes the curated table
// the campaign and endless mode draw from.
//
//   dart run tool/build_level_table.dart
//
// Grading has to happen somewhere, and doing it here rather than on the device
// keeps the app instant and every board reproducible. The output is committed.
import 'dart:io';

import 'package:minedoku_engine/minedoku_engine.dart';

const _generator = PuzzleGenerator();

/// Boards to collect per (size, difficulty).
const _perBucket = 40;

/// How many seeds to try before giving up on a bucket. Some combinations are
/// rare or impossible: a 5x5 has too little room to be expert.
const _seedLimit = 6000;

/// Abandon a bucket that has produced nothing at all after this many seeds.
///
/// Without this the impossible combinations dominate the run: a 9x9 costs
/// about 33ms per candidate, so scanning the full limit for a bucket that will
/// never yield anything burns several minutes for no result.
const _barrenLimit = 700;

void main() {
  final rows = <String>[];
  final summary = <String>[];
  var total = 0;

  for (final size in [5, 6, 7, 8, 9]) {
    for (final difficulty in Difficulty.values) {
      final found = <(int seed, int score)>[];
      var seed = 1;

      while (found.length < _perBucket && seed < _seedLimit) {
        if (found.isEmpty && seed > _barrenLimit) break;
        final puzzle = _generator.generate(size: size, seed: seed);
        final report = DifficultyRater.rate(puzzle);
        // Boards solvable by forced moves alone are rejected everywhere except
        // Gentle, where they are precisely the point. Measuring showed that at
        // small sizes boards are either trivial or need real deduction, with
        // very little in between, so excluding them left Gentle empty and the
        // campaign with no on-ramp.
        final acceptable = difficulty == Difficulty.gentle || !report.isTrivial;
        if (acceptable && report.solved && report.difficulty == difficulty) {
          found.add((seed, report.score));
        }
        seed++;
      }

      for (final entry in found) {
        rows.add('  [$size, ${entry.$1}, ${difficulty.index}, ${entry.$2}],');
      }
      total += found.length;
      summary.add('${size}x$size ${difficulty.label.padRight(7)} '
          '${found.length.toString().padLeft(3)} boards '
          '(searched ${seed - 1} seeds)');
      stdout.writeln(summary.last);
    }
  }

  final buffer = StringBuffer()
    ..writeln('// GENERATED FILE. Do not edit by hand.')
    ..writeln('//')
    ..writeln('// Regenerate with: dart run tool/build_level_table.dart')
    ..writeln('//')
    ..writeln('// Each row is [size, seed, difficultyIndex, score]. Difficulty')
    ..writeln('// was measured by solving the board, not guessed from its size.')
    ..writeln('// Boards solvable by forced moves alone are excluded.')
    ..writeln('library;')
    ..writeln()
    ..writeln('/// $total graded boards, ordered by size then difficulty.')
    ..writeln('const List<List<int>> gradedBoardData = [')
    ..writeAll(rows, '\n')
    ..writeln()
    ..writeln('];');

  File('lib/src/level_table.g.dart').writeAsStringSync(buffer.toString());
  stdout.writeln('\nWrote lib/src/level_table.g.dart with $total boards.');
}
