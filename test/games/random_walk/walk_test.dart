import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/odds_on/odds_math.dart';
import 'package:smartx/games/random_walk/walk_puzzle.dart';

/// Solves x(lo..hi) with x(lo) = left, x(hi) = right and, inside,
/// x(k) = c + up·x(k+1) + down·x(k−1) + stay·x(k). A tridiagonal system
/// (Thomas algorithm); nothing shared with the generator's formulas.
List<double> solve({
  required int lo,
  required int hi,
  required double up,
  required double down,
  double stay = 0,
  required double c,
  required double left,
  required double right,
}) {
  final n = hi - lo - 1; // unknowns lo+1 .. hi-1
  final a = List.filled(n, -down);
  final b = List.filled(n, 1 - stay);
  final cc = List.filled(n, -up);
  final d = List.filled(n, c);
  d[0] += down * left;
  d[n - 1] += up * right;
  for (var i = 1; i < n; i++) {
    final m = a[i] / b[i - 1];
    b[i] -= m * cc[i - 1];
    d[i] -= m * d[i - 1];
  }
  final x = List.filled(n, 0.0);
  x[n - 1] = d[n - 1] / b[n - 1];
  for (var i = n - 2; i >= 0; i--) {
    x[i] = (d[i] - cc[i] * x[i + 1]) / b[i];
  }
  return [left, ...x, right];
}

double recompute(WalkQuestion q) {
  double p(String k) => q.params[k]!.value;
  int i(String k) => p(k).round();
  switch (q.kind) {
    case WalkKind.reach:
      return solve(
        lo: 0,
        hi: i('n'),
        up: .5,
        down: .5,
        c: 0,
        left: 0,
        right: 1,
      )[i('a')];
    case WalkKind.steps:
      return solve(
        lo: 0,
        hi: i('n'),
        up: .5,
        down: .5,
        c: 1,
        left: 0,
        right: 0,
      )[i('a')];
    case WalkKind.fairGame:
      if (i('variant') == 0) {
        final win = solve(
          lo: 0,
          hi: i('n'),
          up: .5,
          down: .5,
          c: 0,
          left: 0,
          right: 1,
        )[i('a')];
        return win * p('n');
      }
      return p('a');
    case WalkKind.afterN:
      // Distribution after n steps, step by step.
      final n = i('n');
      var dist = {0: 1.0};
      for (var t = 0; t < n; t++) {
        final next = <int, double>{};
        dist.forEach((k, v) {
          next[k + 1] = (next[k + 1] ?? 0) + v / 2;
          next[k - 1] = (next[k - 1] ?? 0) + v / 2;
        });
        dist = next;
      }
      return dist[i('k')] ?? 0;
    case WalkKind.biased:
      final up = p('up');
      return solve(
        lo: 0,
        hi: i('n'),
        up: up,
        down: 1 - up,
        c: 0,
        left: 0,
        right: 1,
      )[i('a')];
    case WalkKind.drift:
      switch (i('variant')) {
        case 0:
          final up = p('up');
          var e = 0.0;
          for (var t = 0; t < i('n'); t++) {
            e += up - (1 - up);
          }
          return e;
        case 1:
          final win = p('win');
          var e = p('a');
          for (var t = 0; t < i('k'); t++) {
            e += win - (1 - win);
          }
          return e;
        default:
          // A far-off floor stands in for "no floor": with this drift the
          // walk essentially never gets there.
          final up = p('up');
          const floor = -300;
          return solve(
            lo: floor,
            hi: i('n'),
            up: up,
            down: 1 - up,
            c: 1,
            left: 0,
            right: 0,
          )[-floor];
      }
    case WalkKind.cliff:
      final toward = p('toward');
      return solve(
        lo: 0,
        hi: 600,
        up: 1 - toward,
        down: toward,
        c: 0,
        left: 1,
        right: 0,
      )[i('k')];
    case WalkKind.lazy:
      final stay = p('stay');
      final move = (1 - stay) / 2;
      return solve(
        lo: 0,
        hi: i('n'),
        up: move,
        down: move,
        stay: stay,
        c: i('steps') == 1 ? 1 : 0,
        left: 0,
        right: i('steps') == 1 ? 0 : 1,
      )[i('a')];
  }
}

void main() {
  const gen = WalkGenerator();

  test('every answer matches the solved walk, at every level', () {
    final kinds = <WalkKind>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 150; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        final why = '${q.kind} ${q.params}';
        expect(q.options, hasLength(4), reason: why);
        expect(q.options.toSet(), hasLength(4), reason: '${q.options}');
        expect(q.options, contains(q.answer));
        expect(q.optionValues[q.answerIndex], q.answerValue);
        expect(q.steps, hasLength(3));
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty);
        }
        expect(q.answerValue.value, closeTo(recompute(q), 1e-6), reason: why);
      }
    }
    expect(kinds, WalkKind.values.toSet());
  });

  test('a chance is never offered above 1, nothing at or below 0', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        final chance = switch (q.kind) {
          WalkKind.reach ||
          WalkKind.afterN ||
          WalkKind.biased ||
          WalkKind.cliff => true,
          WalkKind.lazy => q.params['steps'] == Frac.zero,
          _ => false,
        };
        for (final v in q.optionValues) {
          expect(v > Frac.zero, isTrue, reason: '${q.options}');
          if (chance) {
            expect(v <= Frac.one, isTrue, reason: '${q.kind} ${q.options}');
          }
        }
      }
    }
  });

  test('the right answer is not given away by its size', () {
    for (var level = 1; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        expect(
          q.optionValues,
          orderedEquals([...q.optionValues]..sort((a, b) => a.compareTo(b))),
        );
        at[q.answerIndex]++;
      }
      final total = at.fold(0, (a, b) => a + b);
      for (final c in at) {
        expect(
          c / total,
          inInclusiveRange(0.15, 0.35),
          reason: 'level $level: $at',
        );
      }
    }
  });

  test('a sample walk follows the rules on the card', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 60; seed++) {
        final s = gen.generate(level: level, seed: seed).scene;
        final path = s.sample(Random(seed));
        expect(path.first, s.start);
        for (var t = 1; t < path.length; t++) {
          expect((path[t] - path[t - 1]).abs(), lessThanOrEqualTo(1));
        }
        if (s.fixedSteps != null) {
          expect(path, hasLength(s.fixedSteps! + 1));
        } else {
          // It stops the moment it hits an end, and never passes one.
          final inner = path.sublist(0, path.length - 1);
          for (final x in inner) {
            if (s.stopsAtLo) expect(x, greaterThan(s.lo));
            if (s.flag) expect(x, lessThan(s.hi));
          }
        }
      }
    }
  });

  test('the boards\' numbers', () {
    // $3 between $0 and $5: 3/5. From $2 between $0 and $6: 2 × 4 = 8.
    expect(
      solve(lo: 0, hi: 5, up: .5, down: .5, c: 0, left: 0, right: 1)[3],
      closeTo(0.6, 1e-12),
    );
    expect(
      solve(lo: 0, hi: 6, up: .5, down: .5, c: 1, left: 0, right: 0)[2],
      closeTo(8, 1e-9),
    );
    // One step from the cliff, away ⅔: falls with chance ½.
    expect(
      solve(lo: 0, hi: 600, up: 2 / 3, down: 1 / 3, c: 0, left: 1, right: 0)[1],
      closeTo(0.5, 1e-9),
    );
    expect(WalkGenerator.chance(Frac(2, 3)), '⅔');
  });
}
