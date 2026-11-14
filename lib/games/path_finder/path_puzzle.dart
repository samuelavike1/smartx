import 'dart:collection';
import 'dart:math';

import 'package:flutter/foundation.dart';

enum Dir {
  up(-1, 0, '↑', 'up'),
  down(1, 0, '↓', 'down'),
  left(0, -1, '←', 'left'),
  right(0, 1, '→', 'right');

  const Dir(this.dr, this.dc, this.arrow, this.word);

  final int dr;
  final int dc;
  final String arrow;
  final String word;
}

enum Cell {
  floor,
  wall,
  exit,
  key,
  gate,
  arrowUp,
  arrowDown,
  arrowLeft,
  arrowRight;

  /// The direction an arrow tile turns a slide, or null.
  Dir? get arrow => switch (this) {
    Cell.arrowUp => Dir.up,
    Cell.arrowDown => Dir.down,
    Cell.arrowLeft => Dir.left,
    Cell.arrowRight => Dir.right,
    _ => null,
  };

  static Cell arrowFor(Dir d) => switch (d) {
    Dir.up => Cell.arrowUp,
    Dir.down => Cell.arrowDown,
    Dir.left => Cell.arrowLeft,
    Dir.right => Cell.arrowRight,
  };
}

/// Outcome of one slide.
@immutable
class SlideResult {
  const SlideResult(this.end, this.hasKey, this.path, this.won);

  final int end;
  final bool hasKey;

  /// Cells passed through, in order, ending at [end] (empty = no move).
  final List<int> path;
  final bool won;

  bool get moved => path.isNotEmpty;
}

/// A square board and the slide rules.
@immutable
class PathBoard {
  const PathBoard(this.size, this.cells);

  final int size;
  final List<Cell> cells;

  int get exit => cells.indexOf(Cell.exit);
  bool get hasKey => cells.contains(Cell.key);

  /// Slides from [from] in [d]: straight on until a wall, the edge or a
  /// locked gate stops it. Sliding over the key picks it up (gates open);
  /// arrow tiles turn the slide; reaching the exit wins.
  SlideResult slide(int from, bool hasKey, Dir d) {
    var r = from ~/ size, c = from % size;
    var dir = d;
    var key = hasKey;
    final path = <int>[];
    final seen = <(int, Dir)>{};
    while (true) {
      final nr = r + dir.dr, nc = c + dir.dc;
      if (nr < 0 || nr >= size || nc < 0 || nc >= size) break;
      final next = nr * size + nc;
      final cell = cells[next];
      if (cell == Cell.wall || (cell == Cell.gate && !key)) break;
      r = nr;
      c = nc;
      path.add(next);
      if (cell == Cell.key) key = true;
      if (cell == Cell.exit) return SlideResult(next, key, path, true);
      final turn = cell.arrow;
      if (turn != null) {
        dir = turn;
        if (!seen.add((next, dir))) break; // arrows in a loop: stop here
      }
    }
    return SlideResult(r * size + c, key, path, false);
  }

  /// Shortest list of moves from [start] to the exit, or null if none.
  List<Dir>? solve(int start) {
    int id(int pos, bool key) => pos * 2 + (key ? 1 : 0);
    final prev = <int, (int, Dir)>{};
    final seen = <int>{id(start, false)};
    final queue = Queue<(int, bool)>()..add((start, false));
    while (queue.isNotEmpty) {
      final (pos, key) = queue.removeFirst();
      for (final d in Dir.values) {
        final r = slide(pos, key, d);
        if (!r.moved) continue;
        if (r.won) {
          final moves = <Dir>[d];
          var s = id(pos, key);
          while (prev.containsKey(s)) {
            final (p, pd) = prev[s]!;
            moves.add(pd);
            s = p;
          }
          return moves.reversed.toList();
        }
        final ns = id(r.end, r.hasKey);
        if (seen.add(ns)) {
          prev[ns] = (id(pos, key), d);
          queue.add((r.end, r.hasKey));
        }
      }
    }
    return null;
  }
}

@immutable
class PathDifficulty {
  const PathDifficulty({
    required this.size,
    required this.walls,
    required this.minMoves,
    required this.maxMoves,
    required this.slack,
    required this.useKey,
    required this.arrows,
  });

  factory PathDifficulty.forLevel(int level) => switch (level.clamp(1, 10)) {
    <= 2 => const PathDifficulty(
      size: 5,
      walls: 4,
      minMoves: 2,
      maxMoves: 4,
      slack: 2,
      useKey: false,
      arrows: 0,
    ),
    <= 4 => const PathDifficulty(
      size: 6,
      walls: 7,
      minMoves: 3,
      maxMoves: 5,
      slack: 1,
      useKey: false,
      arrows: 0,
    ),
    <= 6 => const PathDifficulty(
      size: 6,
      walls: 6,
      minMoves: 4,
      maxMoves: 6,
      slack: 1,
      useKey: true,
      arrows: 0,
    ),
    <= 8 => const PathDifficulty(
      size: 7,
      walls: 8,
      minMoves: 5,
      maxMoves: 7,
      slack: 0,
      useKey: true,
      arrows: 1,
    ),
    _ => const PathDifficulty(
      size: 7,
      walls: 10,
      minMoves: 6,
      maxMoves: 9,
      slack: 0,
      useKey: true,
      arrows: 2,
    ),
  };

  final int size;

  /// Walls placed at random (gate-guarding walls come on top).
  final int walls;
  final int minMoves;
  final int maxMoves;

  /// Spare moves on top of the shortest route.
  final int slack;
  final bool useKey;
  final int arrows;
}

@immutable
class PathPuzzle {
  const PathPuzzle({
    required this.level,
    required this.seed,
    required this.board,
    required this.start,
    required this.solution,
    required this.moveLimit,
  });

  final int level;
  final int seed;
  final PathBoard board;
  final int start;

  /// A shortest route (found by breadth-first search).
  final List<Dir> solution;
  final int moveLimit;

  int get size => board.size;
  int get shortest => solution.length;

  String get route => solution.map((d) => d.arrow).join(' ');

  /// Cells the shortest route passes through: cell → move number when a
  /// move stops there, 0 when it only passes over.
  Map<int, int> routeMarks() {
    final marks = <int, int>{};
    var pos = start;
    var key = false;
    for (final (i, d) in solution.indexed) {
      final r = board.slide(pos, key, d);
      for (final cell in r.path) {
        marks.putIfAbsent(cell, () => 0);
      }
      marks[r.end] = i + 1;
      pos = r.end;
      key = r.hasKey;
    }
    return marks;
  }

  String explain({required bool won, required int movesUsed}) {
    if (won && movesUsed <= shortest) {
      return 'Shortest route, $movesUsed moves. Perfect planning.';
    }
    if (won) {
      return 'Solved in $movesUsed moves. The shortest takes $shortest: $route.';
    }
    return 'Out of moves. The shortest route takes $shortest: $route. '
        'The numbers show where each move stops.';
  }
}

/// Builds boards whose shortest route fits the level, checked by search.
class PathGenerator {
  const PathGenerator();

  PathPuzzle generate({required int level, required int seed}) {
    final rng = Random(seed);
    final d = PathDifficulty.forLevel(level);
    final n = d.size;
    var minMoves = d.minMoves;

    for (var attempt = 1; ; attempt++) {
      // Rarely, a seed struggles to hit the target length: relax slowly.
      if (attempt % 300 == 0 && minMoves > 2) minMoves--;

      final cells = List<Cell>.filled(n * n, Cell.floor);
      final free = List<int>.generate(n * n, (i) => i)..shuffle(rng);
      final taken = <int>{};
      int take() {
        final i = free.firstWhere((x) => !taken.contains(x));
        taken.add(i);
        return i;
      }

      final start = take();
      final exit = take();
      cells[exit] = Cell.exit;

      if (d.useKey) {
        // Guard the exit: a gate on one side, walls on the others, so the
        // only way in is through the gate — the key is always needed.
        final er = exit ~/ n, ec = exit % n;
        final sides = [
          for (final dir in Dir.values)
            if (er + dir.dr >= 0 &&
                er + dir.dr < n &&
                ec + dir.dc >= 0 &&
                ec + dir.dc < n)
              (er + dir.dr) * n + (ec + dir.dc),
        ]..shuffle(rng);
        if (sides.contains(start)) continue;
        cells[sides.first] = Cell.gate;
        taken.add(sides.first);
        for (final s in sides.skip(1)) {
          cells[s] = Cell.wall;
          taken.add(s);
        }
        cells[take()] = Cell.key;
      }
      for (var i = 0; i < d.walls; i++) {
        cells[take()] = Cell.wall;
      }
      for (var i = 0; i < d.arrows; i++) {
        cells[take()] = Cell.arrowFor(Dir.values[rng.nextInt(4)]);
      }

      final board = PathBoard(n, List.unmodifiable(cells));
      final solution = board.solve(start);
      if (solution == null) continue;
      if (solution.length < minMoves || solution.length > d.maxMoves) continue;

      return PathPuzzle(
        level: level,
        seed: seed,
        board: board,
        start: start,
        solution: solution,
        moveLimit: solution.length + d.slack,
      );
    }
  }
}
