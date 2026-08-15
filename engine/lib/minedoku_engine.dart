/// The Minedoku puzzle engine.
///
/// Pure Dart, no Flutter: rules, a solver, a generator that guarantees exactly
/// one solution, player board state and a tiered hint system. Everything here
/// is unit-testable with `dart test`.
library;

export 'src/board.dart';
export 'src/game_mode.dart';
export 'src/generator.dart';
export 'src/hints.dart';
export 'src/levels.dart';
export 'src/prng.dart';
export 'src/puzzle.dart';
export 'src/rules.dart';
export 'src/solver.dart';
export 'src/streaks.dart';
