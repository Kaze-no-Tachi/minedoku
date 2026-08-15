/// Exposes the engine to JavaScript so the browser prototype can reuse the
/// exact same, unit-tested rules instead of a re-implementation.
///
/// Compile with:
///   dart compile js -O2 tool/web_bridge.dart -o build/engine.js
library;

import 'dart:convert';
import 'dart:js_interop';

import 'package:minedoku_engine/minedoku_engine.dart';

@JS('minedokuGenerate')
external set _generateHook(JSFunction value);

@JS('minedokuHint')
external set _hintHook(JSFunction value);

const _generator = PuzzleGenerator();
const _hints = HintEngine();

/// Returns `{size, regions, solution}` as JSON.
String _generate(int size, int seed) {
  final puzzle = _generator.generate(size: size, seed: seed);
  return jsonEncode({
    'size': puzzle.size,
    'regions': puzzle.regions,
    'solution': puzzle.solution,
  });
}

/// Takes the board description plus the player's marks and returns the next
/// hint as `{kind, cell, message}` JSON.
String _hint(int size, String regionsCsv, String solutionCsv, String marks) {
  final regions = regionsCsv.split(',').map(int.parse).toList();
  final solution = solutionCsv.split(',').map(int.parse).toList();
  final puzzle = Puzzle(size: size, regions: regions, solution: solution);
  final board = GameBoard(puzzle, autoBlock: false)..restoreMarks(marks);
  final hint = _hints.next(board);
  return jsonEncode({
    'kind': hint.kind.name,
    'cell': hint.cell,
    'message': hint.message,
  });
}

void main() {
  _generateHook = _generate.toJS;
  _hintHook = _hint.toJS;
}
