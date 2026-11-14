import 'dart:math';

import 'package:flutter/foundation.dart';

/// Knobs derived from the 1–10 difficulty level (see the games plan:
/// grid 3×3 to 6×6, 3–10 lit cells, recall in order at high levels).
@immutable
class GridDifficulty {
  const GridDifficulty({
    required this.size,
    required this.cellCount,
    required this.ordered,
  });

  factory GridDifficulty.forLevel(int level) {
    final l = level.clamp(1, 10);
    final size = l <= 2 ? 3 : (l <= 5 ? 4 : (l <= 8 ? 5 : 6));
    // Never light more than ~45% of the grid, or it becomes guesswork.
    final cap = (size * size * 0.45).floor();
    return GridDifficulty(
      size: size,
      cellCount: min(2 + l, min(10, cap)),
      ordered: l >= 8,
    );
  }

  /// Grid is [size] × [size].
  final int size;

  /// How many cells light up.
  final int cellCount;

  /// Cells flash one at a time and must be tapped in the same order.
  final bool ordered;
}

@immutable
class GridPuzzle {
  const GridPuzzle({
    required this.level,
    required this.seed,
    required this.size,
    required this.cells,
    required this.ordered,
  });

  final int level;
  final int seed;
  final int size;

  /// Lit cell indices (row-major, 0 … size²−1). For ordered puzzles this is
  /// the order they flash in.
  final List<int> cells;
  final bool ordered;

  static const flashStep = Duration(milliseconds: 650);

  /// How long the pattern is shown before the player recalls it.
  Duration get memorizeDuration => ordered
      ? flashStep * (cells.length + 1)
      : Duration(milliseconds: 1000 + 300 * cells.length);

  /// Checks a finished recall attempt.
  bool isCorrect(List<int> taps) => ordered
      ? listEquals(taps, cells)
      : setEquals(taps.toSet(), cells.toSet());

  /// Shown after answering, so players learn from a miss.
  String explain(List<int> taps) {
    final n = cells.length;
    if (isCorrect(taps)) {
      return ordered
          ? 'All $n cells, in the right order.'
          : 'All $n cells. Perfect recall.';
    }
    if (ordered) {
      var step = 0;
      while (step < taps.length && taps[step] == cells[step]) {
        step++;
      }
      return 'The order slipped at step ${step + 1} of $n. '
          'The numbers show the right order.';
    }
    final found = taps.where(cells.contains).length;
    final missed = n - found;
    return 'You found $found of $n. '
        '${missed == 1 ? 'The missed cell is' : 'The $missed missed cells are'} outlined.';
  }
}

/// Builds puzzles from a seed: the same (level, seed) is always the same grid.
class GridRecallGenerator {
  const GridRecallGenerator();

  GridPuzzle generate({required int level, required int seed}) {
    final d = GridDifficulty.forLevel(level);
    final rng = Random(seed);
    final all = List.generate(d.size * d.size, (i) => i)..shuffle(rng);
    return GridPuzzle(
      level: level,
      seed: seed,
      size: d.size,
      cells: all.take(d.cellCount).toList(),
      ordered: d.ordered,
    );
  }
}
