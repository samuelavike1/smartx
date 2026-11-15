import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/expect_it/expect_puzzle.dart';
import 'package:smartx/games/odds_on/odds_math.dart';

/// The answer worked out again in plain doubles, by brute force or by
/// numeric integration where possible (no shared code with the generator).
double recompute(ExpQuestion q) {
  double p(String k) => q.params[k]!.value;
  int i(String k) => p(k).round();
  switch (q.kind) {
    case ExpKind.average:
      return [for (var f = 0; f < 6; f++) p('f$f')].reduce((a, b) => a + b) / 6;
    case ExpKind.sum:
      return switch (i('variant')) {
        0 => 3.5 * p('n'),
        1 => 3.5 * p('n') + p('m') / 2,
        _ => 3.5 * p('k') + 3.5,
      };
    case ExpKind.waiting:
      // Sum of P(still waiting after t tries), the tail-sum formula.
      final hit = p('p');
      var e = 0.0;
      for (var t = 0; t < 4000; t++) {
        e += pow(1 - hit, t);
      }
      return e - p('before');
    case ExpKind.indicator:
      return switch (i('variant')) {
        0 => p('n') / 6,
        1 => _hatMatches(i('n')),
        2 => p('k') * 4 / 52,
        3 => (p('n') - 1) / 2,
        _ => p('n') * (p('n') - 1) / 2 / 7,
      };
    case ExpKind.maxMin:
      final n = i('n');
      var total = 0;
      for (var a = 1; a <= n; a++) {
        for (var b = 1; b <= n; b++) {
          total += i('high') == 1 ? max(a, b) : min(a, b);
        }
      }
      return total / (n * n);
    case ExpKind.coupon:
      final n = i('n');
      if (i('all') == 1) {
        // Chain of states "j faces seen": solve backwards.
        var e = 0.0;
        for (var j = n - 1; j >= 0; j--) {
          e += n / (n - j);
        }
        return e;
      }
      final r = i('r');
      var distinct = 0;
      final outcomes = pow(n, r).toInt();
      for (var o = 0; o < outcomes; o++) {
        final seen = <int>{};
        var x = o;
        for (var t = 0; t < r; t++) {
          seen.add(x % n);
          x ~/= n;
        }
        distinct += seen.length;
      }
      return distinct / outcomes;
    case ExpKind.compound:
      switch (i('variant')) {
        case 0:
          var e = 0.0;
          for (var k = 1; k <= 6; k++) {
            e += (i('coins') == 1 ? k / 2 : 3.5 * k) / 6;
          }
          return e;
        case 1:
          var e = 0.0;
          for (var f = 1; f <= 6; f++) {
            e += (f > i('t') ? f : 3.5) / 6;
          }
          return e;
        default:
          // E0 = 1 + p·E1 + q·E0 and E1 = 1 + q·E0.
          final hit = p('p');
          final q = 1 - hit;
          return (1 + hit) / (1 - q - hit * q);
      }
    case ExpKind.stick:
      final l = p('l');
      const steps = 400;
      double mid(int k) => (k + 0.5) / steps;
      var e = 0.0;
      switch (i('variant')) {
        case 0:
        case 1:
          for (var a = 0; a < steps; a++) {
            final x = mid(a);
            e += (i('variant') == 0 ? max(x, 1 - x) : min(x, 1 - x)) / steps;
          }
        case 2:
        case 3:
          for (var a = 0; a < steps; a++) {
            for (var b = 0; b < steps; b++) {
              final x = mid(a), y = mid(b);
              e +=
                  (i('variant') == 2 ? (x - y).abs() : max(x, y)) /
                  (steps * steps);
            }
          }
        default:
          // P(nearest > x) = (1 − x)^n; integrate the tail.
          for (var a = 0; a < steps; a++) {
            e += pow(1 - mid(a), i('points')) / steps;
          }
      }
      return e * l;
    case ExpKind.deck:
      // E[cards turned] = Σ P(the first j cards are all ordinary).
      final n = i('n'), k = i('k');
      var e = 0.0;
      var allPlain = 1.0;
      for (var j = 0; j <= n - k; j++) {
        e += allPlain;
        allPlain *= (n - k - j) / (n - j);
      }
      return e - p('before');
  }
}

/// Average fixed points of a random shuffle of n, by brute force (n ≤ 8)
/// or the known answer.
double _hatMatches(int n) {
  if (n > 8) return 1;
  final perm = List.generate(n, (i) => i);
  var fixed = 0, count = 0;
  void go(int at) {
    if (at == n) {
      count++;
      for (var i = 0; i < n; i++) {
        if (perm[i] == i) fixed++;
      }
      return;
    }
    void swap(int a, int b) {
      final t = perm[a];
      perm[a] = perm[b];
      perm[b] = t;
    }

    for (var j = at; j < n; j++) {
      swap(at, j);
      go(at + 1);
      swap(at, j);
    }
  }

  go(0);
  return fixed / count;
}

void main() {
  const gen = ExpGenerator();

  test('every answer matches an independent recount, at every level', () {
    final kinds = <ExpKind>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 120; seed++) {
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
        for (final v in q.optionValues) {
          expect(v > Frac.zero, isTrue, reason: '${q.options}');
        }
        final tolerance = q.kind == ExpKind.stick ? 1e-3 * 60 : 1e-9;
        expect(
          q.answerValue.value,
          closeTo(recompute(q), tolerance),
          reason: why,
        );
      }
    }
    expect(kinds, ExpKind.values.toSet());
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

  test('most wrong answers are named mistakes, not plain near misses', () {
    var named = 0, all = 0;
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 100; seed++) {
        for (final t in gen.generate(level: level, seed: seed).traps) {
          all++;
          if (!t.why.startsWith('Check the numbers')) named++;
        }
      }
    }
    expect(named / all, greaterThan(0.6), reason: '$named of $all');
  });

  test('the boards\' numbers', () {
    // The higher of two dice: 161/36, about 4.47.
    var total = 0;
    for (var a = 1; a <= 6; a++) {
      for (var b = 1; b <= 6; b++) {
        total += max(a, b);
      }
    }
    expect(Frac(total, 36), Frac(161, 36));
    expect(ev(Frac(161, 36)), '161/36');
    expect(about(Frac(161, 36)), 'about 4.47');
    // Every face of a die: 6 × (1 + ½ + … + 1/6) = 14.7.
    var h = Frac.zero;
    for (var k = 1; k <= 6; k++) {
      h = h + Frac(6, k);
    }
    expect(ev(h), '14.7');
    expect(about(h), isNull);
    // A 12 cm stick, one break: the longer piece averages 9 cm.
    expect(Frac(12) * Frac(3, 4), Frac(9));
    // Cards up to the first ace: 53/5 = 10.6.
    expect(ev(Frac(53, 5)), '10.6');
    expect(ev(Frac(7, 2)), '3.5');
    expect(ev(Frac(49, 4)), '12.25');
  });
}
