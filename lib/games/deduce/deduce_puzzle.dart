import 'dart:math';

import 'package:flutter/foundation.dart';

import '../pattern_sequence/sequence_puzzle.dart' show PatternToken, TokenShape;

/// The shapes a Deduce puzzle places. Colours index the shared puzzle
/// palette (`tokenPalette`), so they match the Pattern Sequence tiles.
enum DeduceItem {
  circle(TokenShape.circle, 1),
  square(TokenShape.square, 0),
  triangle(TokenShape.triangle, 2),
  diamond(TokenShape.diamond, 4),
  star(TokenShape.star, 5);

  const DeduceItem(this.shape, this.color);

  final TokenShape shape;
  final int color;

  PatternToken get token =>
      PatternToken(shape: shape.index, color: color, count: 0);
}

const _ordinals = ['first', 'second', 'third', 'fourth', 'fifth'];

String _spot(int pos, int n) => pos == n - 1 ? 'last' : _ordinals[pos];

enum ClueKind { at, notAt, leftOf, nextTo, notNextTo, between }

/// A statement about the order. `order` is the full left-to-right row.
sealed class Clue {
  const Clue();

  bool holds(List<DeduceItem> order);
  String get text;
}

final class IsAt extends Clue {
  const IsAt(this.item, this.pos, this.n);
  final DeduceItem item;
  final int pos;
  final int n;

  @override
  bool holds(List<DeduceItem> o) => o.indexOf(item) == pos;
  @override
  String get text => 'The ${item.name} is ${_spot(pos, n)}.';
}

final class NotAt extends Clue {
  const NotAt(this.item, this.pos, this.n);
  final DeduceItem item;
  final int pos;
  final int n;

  @override
  bool holds(List<DeduceItem> o) => o.indexOf(item) != pos;
  @override
  String get text => 'The ${item.name} is not ${_spot(pos, n)}.';
}

final class LeftOf extends Clue {
  const LeftOf(this.a, this.b);
  final DeduceItem a;
  final DeduceItem b;

  @override
  bool holds(List<DeduceItem> o) => o.indexOf(a) < o.indexOf(b);
  @override
  String get text => 'The ${a.name} is somewhere left of the ${b.name}.';
}

final class NextTo extends Clue {
  const NextTo(this.a, this.b);
  final DeduceItem a;
  final DeduceItem b;

  @override
  bool holds(List<DeduceItem> o) => (o.indexOf(a) - o.indexOf(b)).abs() == 1;
  @override
  String get text => 'The ${a.name} is next to the ${b.name}.';
}

final class NotNextTo extends Clue {
  const NotNextTo(this.a, this.b);
  final DeduceItem a;
  final DeduceItem b;

  @override
  bool holds(List<DeduceItem> o) => (o.indexOf(a) - o.indexOf(b)).abs() != 1;
  @override
  String get text => 'The ${a.name} is not next to the ${b.name}.';
}

/// [mid] sits somewhere between [a] and [b] (in either order).
final class Between extends Clue {
  const Between(this.mid, this.a, this.b);
  final DeduceItem mid;
  final DeduceItem a;
  final DeduceItem b;

  @override
  bool holds(List<DeduceItem> o) {
    final m = o.indexOf(mid), x = o.indexOf(a), y = o.indexOf(b);
    return (x < m && m < y) || (y < m && m < x);
  }

  @override
  String get text =>
      'The ${mid.name} is between the ${a.name} and the ${b.name}.';
}

@immutable
class DeduceDifficulty {
  const DeduceDifficulty(this.count, this.kinds);

  factory DeduceDifficulty.forLevel(int level) {
    final l = level.clamp(1, 10);
    const all = ClueKind.values;
    return switch (l) {
      <= 2 => const DeduceDifficulty(3, {
        ClueKind.at,
        ClueKind.leftOf,
        ClueKind.nextTo,
      }),
      <= 4 => const DeduceDifficulty(4, {
        ClueKind.at,
        ClueKind.notAt,
        ClueKind.leftOf,
        ClueKind.nextTo,
      }),
      <= 6 => DeduceDifficulty(4, all.toSet()),
      <= 8 => DeduceDifficulty(5, all.toSet()),
      _ => DeduceDifficulty(5, all.where((k) => k != ClueKind.at).toSet()),
    };
  }

  /// How many shapes (and spots).
  final int count;
  final Set<ClueKind> kinds;
}

@immutable
class DeducePuzzle {
  const DeducePuzzle({
    required this.level,
    required this.seed,
    required this.tray,
    required this.solution,
    required this.clues,
  });

  final int level;
  final int seed;

  /// Shapes in the order they start in the tray.
  final List<DeduceItem> tray;
  final List<DeduceItem> solution;
  final List<Clue> clues;

  int get size => solution.length;

  bool isSolution(List<DeduceItem?> order) => listEquals(order, solution);

  /// Indices of clues that are false for a complete [order].
  List<int> brokenClues(List<DeduceItem> order) => [
    for (final (i, c) in clues.indexed)
      if (!c.holds(order)) i,
  ];

  String explain(List<DeduceItem> order) {
    if (isSolution(order)) return 'Every clue is true. Nicely reasoned.';
    final broken = brokenClues(order).map((i) => '${i + 1}').toList();
    final list = broken.length == 1
        ? 'Clue ${broken.single} isn’t'
        : 'Clues ${broken.sublist(0, broken.length - 1).join(', ')} and ${broken.last} aren’t';
    return '$list true in your order. Compare it with the solution.';
  }
}

/// Number of arrangements of [items] that satisfy every clue (stops at 2).
int countSolutions(List<DeduceItem> items, List<Clue> clues) {
  var found = 0;
  for (final p in permutations(items)) {
    if (clues.every((c) => c.holds(p)) && ++found > 1) break;
  }
  return found;
}

/// All orderings of [items], in a fixed order (deterministic).
List<List<DeduceItem>> permutations(List<DeduceItem> items) {
  if (items.length <= 1) return [items];
  return [
    for (final (i, first) in items.indexed)
      for (final rest in permutations([...items]..removeAt(i)))
        [first, ...rest],
  ];
}

/// Builds a puzzle with exactly one solution and no spare clues.
class DeduceGenerator {
  const DeduceGenerator();

  DeducePuzzle generate({required int level, required int seed}) {
    final rng = Random(seed);
    final d = DeduceDifficulty.forLevel(level);
    final tray = ([...DeduceItem.values]..shuffle(rng)).take(d.count).toList();
    final solution = [...tray]..shuffle(rng);
    final perms = permutations(tray);

    // 1. Add true clues (in random order) while they narrow the answers.
    final candidates = _trueClues(solution, d.kinds, rng)..shuffle(rng);
    var clues = <Clue>[];
    var remaining = perms;
    for (final c in candidates) {
      if (remaining.length == 1) break;
      final narrowed = remaining.where(c.holds).toList();
      if (narrowed.length < remaining.length) {
        clues.add(c);
        remaining = narrowed;
      }
    }
    // Safety net: pin shapes until unique (only reachable if kinds are thin).
    for (var i = 0; remaining.length > 1 && i < solution.length; i++) {
      final pin = IsAt(solution[i], i, solution.length);
      clues.add(pin);
      remaining = remaining.where(pin.holds).toList();
    }

    // 2. Drop any clue the answer doesn't need, so every clue matters.
    for (final c in [...clues]..shuffle(rng)) {
      final without = [...clues]..remove(c);
      if (countSolutions(tray, without) == 1) clues = without;
    }
    clues.shuffle(rng);

    // Start the tray in a different order from the answer.
    final trayOrder = [...tray];
    while (listEquals(trayOrder, solution)) {
      trayOrder.shuffle(rng);
    }

    return DeducePuzzle(
      level: level,
      seed: seed,
      tray: trayOrder,
      solution: solution,
      clues: clues,
    );
  }

  List<Clue> _trueClues(List<DeduceItem> s, Set<ClueKind> kinds, Random rng) {
    final n = s.length;
    int pos(DeduceItem x) => s.indexOf(x);
    final out = <Clue>[];
    for (final a in s) {
      if (kinds.contains(ClueKind.at)) out.add(IsAt(a, pos(a), n));
      if (kinds.contains(ClueKind.notAt)) {
        for (var p = 0; p < n; p++) {
          if (p != pos(a)) out.add(NotAt(a, p, n));
        }
      }
      for (final b in s) {
        if (a == b) continue;
        final gap = pos(b) - pos(a);
        if (kinds.contains(ClueKind.leftOf) && gap > 0) out.add(LeftOf(a, b));
        // Symmetric clues: one per pair.
        if (a.index < b.index) {
          if (kinds.contains(ClueKind.nextTo) && gap.abs() == 1) {
            out.add(rng.nextBool() ? NextTo(a, b) : NextTo(b, a));
          }
          if (kinds.contains(ClueKind.notNextTo) && gap.abs() > 1) {
            out.add(rng.nextBool() ? NotNextTo(a, b) : NotNextTo(b, a));
          }
        }
        if (kinds.contains(ClueKind.between) && a.index < b.index) {
          for (final m in s) {
            final pm = pos(m);
            if ((pos(a) < pm && pm < pos(b)) || (pos(b) < pm && pm < pos(a))) {
              out.add(rng.nextBool() ? Between(m, a, b) : Between(m, b, a));
            }
          }
        }
      }
    }
    return out;
  }
}
