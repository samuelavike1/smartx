import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/brownian_path/brown_puzzle.dart';
import 'package:smartx/games/brownian_path/brownian_path_game.dart';
import 'package:smartx/games/odds_on/odds_math.dart';
import 'package:smartx/ui/widgets/math_text.dart';

// Everything here is worked out a second way, written for the test alone:
// numeric integrals against the normal density, finite-difference solves of
// the hitting equations, discrete Itô sums, and an evaluator for the
// formulas the player sees.

/// Simpson's rule on [a, b].
double simpson(double Function(double) f, double a, double b, [int n = 4000]) {
  final h = (b - a) / n;
  var s = f(a) + f(b);
  for (var i = 1; i < n; i++) {
    s += f(a + i * h) * (i.isOdd ? 4 : 2);
  }
  return s * h / 3;
}

/// The density of N(mean, variance) at x.
double density(double x, double mean, double variance) =>
    exp(-(x - mean) * (x - mean) / (2 * variance)) / sqrt(2 * pi * variance);

/// P(X > c) for X ~ N(mean, variance), by integrating the density.
double above(double c, double mean, double variance) {
  final sd = sqrt(variance);
  final hi = mean + 12 * sd;
  if (c >= hi) return 0;
  final lo = max(c, mean - 12 * sd);
  return simpson((x) => density(x, mean, variance), lo, hi);
}

/// E[g(X)] for X ~ N(mean, variance).
double average(double Function(double) g, double mean, double variance) {
  final sd = sqrt(variance);
  return simpson(
    (x) => g(x) * density(x, mean, variance),
    mean - 12 * sd,
    mean + 12 * sd,
    8000,
  );
}

/// Solves a·u″ + b·u′ = −c on [lo, hi] with u(lo) = left, u(hi) = right,
/// by central differences with step [h] (0 must be a grid point); returns
/// u at 0.
double solveAt0({
  required double lo,
  required double hi,
  double a = 0.5,
  double b = 0,
  double c = 0,
  required double left,
  required double right,
  double h = 1 / 200,
}) {
  final n = ((hi - lo) / h).round();
  final m = n - 1;
  final sub = List.filled(m, a / (h * h) - b / (2 * h));
  final diag = List.filled(m, -2 * a / (h * h));
  final sup = List.filled(m, a / (h * h) + b / (2 * h));
  final rhs = List.filled(m, -c);
  rhs[0] -= sub[0] * left;
  rhs[m - 1] -= sup[m - 1] * right;
  for (var i = 1; i < m; i++) {
    final k = sub[i] / diag[i - 1];
    diag[i] -= k * sup[i - 1];
    rhs[i] -= k * rhs[i - 1];
  }
  final u = List.filled(m, 0.0);
  u[m - 1] = rhs[m - 1] / diag[m - 1];
  for (var i = m - 2; i >= 0; i--) {
    u[i] = (rhs[i] - sup[i] * u[i + 1]) / diag[i];
  }
  final at = (-lo / h).round();
  return at == 0 ? left : u[at - 1];
}

/// Evaluates the shorthand the game shows for formulas: numbers, w (for
/// W_t), t, e, +, −, implicit products, powers, \frac and brackets.
class Eval {
  Eval(String source)
    : s = source
          .replaceAll('W_{t}', 'w')
          .replaceAll(' ', '')
          .replaceAll(' ', '');

  final String s;
  int i = 0;

  bool get done => i >= s.length;
  String get ch => s[i];

  double run(double t, double w) {
    i = 0;
    _t = t;
    _w = w;
    final v = _expr();
    if (!done) throw FormatException('left over at $i', s);
    return v;
  }

  late double _t, _w;

  double _expr() {
    var v = _term();
    while (!done && (ch == '+' || ch == '-')) {
      final plus = ch == '+';
      i++;
      final t = _term();
      v = plus ? v + t : v - t;
    }
    return v;
  }

  double _term() {
    var sign = 1.0;
    while (!done && ch == '-') {
      sign = -sign;
      i++;
    }
    var v = _factor();
    while (!done && RegExp(r'[0-9.a-z({\\]').hasMatch(ch)) {
      v *= _factor();
    }
    return sign * v;
  }

  double _factor() {
    var b = _base();
    if (!done && ch == '^') {
      i++;
      b = pow(b, _group()).toDouble();
    }
    return b;
  }

  double _group() {
    if (ch == '{') {
      i++;
      final v = _expr();
      i++; // }
      return v;
    }
    return _base();
  }

  double _base() {
    final c = ch;
    if (c == '(' || c == '{') {
      i++;
      final v = _expr();
      i++;
      return v;
    }
    if (s.startsWith(r'\frac', i)) {
      i += 5;
      final top = _group();
      final bottom = _group();
      return top / bottom;
    }
    if (RegExp('[0-9.]').hasMatch(c)) {
      final start = i;
      while (!done && RegExp('[0-9.]').hasMatch(ch)) {
        i++;
      }
      return double.parse(s.substring(start, i));
    }
    i++;
    return switch (c) {
      'w' => _w,
      't' => _t,
      'e' => e,
      _ => throw FormatException('unknown $c at ${i - 1}', s),
    };
  }
}

/// The drift f_t + ½f_ww of f(t, W_t), by finite differences.
double drift(Eval f, double t, double w) {
  const h = 1e-3;
  final ft = (f.run(t + h, w) - f.run(t - h, w)) / (2 * h);
  final fww = (f.run(t, w + h) - 2 * f.run(t, w) + f.run(t, w - h)) / (h * h);
  return ft + fww / 2;
}

/// The value of a number option: a decimal, a fraction, a percentage, or
/// (for powers of e) the power.
double plainValue(String o) {
  if (o.endsWith('%')) return double.parse(o.substring(0, o.length - 1)) / 100;
  final f = RegExp(r'^(-?)\\frac\{(\d+)\}\{(\d+)\}$').firstMatch(o);
  if (f != null) {
    return (f[1] == '-' ? -1 : 1) * int.parse(f[2]!) / int.parse(f[3]!);
  }
  final p = RegExp(r'^(?:100)?e\^\{(-?[0-9.]+)\}$').firstMatch(o);
  if (p != null) return double.parse(p[1]!);
  return double.parse(o);
}

/// The right answer, worked out from the question's numbers without the
/// generator's formulas. For percentages from the table the generator
/// rounds, so this returns the exact value and a tolerance.
(double, double) recompute(BrownQuestion q) {
  double p(String k) => q.params[k]!.toDouble();
  const exact = 1e-9, table = 0.0011;
  switch (q.kind) {
    case BrownKind.scaling:
      switch (q.variant) {
        case 0:
          return (sqrt(average((x) => x * x, 0, p('t'))), 1e-6);
        case 1:
          final s = p('s');
          return (sqrt(average((x) => s * x * s * x, 0, p('t'))), 1e-6);
        case 2:
          // Bisection for the time whose variance gives SD k.
          var lo = 0.0, hi = 100.0;
          for (var i = 0; i < 80; i++) {
            final mid = (lo + hi) / 2;
            sqrt(average((x) => x * x, 0, mid)) < p('k') ? lo = mid : hi = mid;
          }
          return (lo, 1e-4);
        default:
          return (above(0, 0, p('t') - p('s')), 1e-6);
      }
    case BrownKind.increments:
      // a·W_s + b·W_t through its independent pieces: (a + b) on [0, s],
      // b on [s, t].
      final s = p('s'), t = p('t');
      double v(double a, double b) => (a + b) * (a + b) * s + b * b * (t - s);
      final cov = (v(1, 1) - v(1, 0) - v(0, 1)) / 2;
      return switch (q.variant) {
        0 => (v(-1, 1), exact),
        1 => (v(1, 1), exact),
        2 => (cov, exact),
        _ => (cov / sqrt(v(1, 0) * v(0, 1)), exact),
      };
    case BrownKind.table:
      final t = p('t'), a = p('a');
      return switch (q.variant) {
        0 => (above(a, 0, t), table),
        1 => (1 - above(-a, 0, t), table),
        2 => (above(a, 0, t) + 1 - above(-a, 0, t), table),
        _ => (1 - above(a, 0, t), table),
      };
    case BrownKind.reflection:
      // The first time W reaches a has density a / √(2πs³) · e^(−a²/2s).
      final t = p('t'), a = p('a');
      final touch = simpson(
        (s) =>
            s <= 0 ? 0 : a / sqrt(2 * pi * s * s * s) * exp(-a * a / (2 * s)),
        0,
        t,
        20000,
      );
      return switch (q.variant) {
        0 => (touch, table),
        1 => (1 - touch, table),
        // Ending above a means it touched a; take those away.
        _ => (touch - above(a, 0, t), table),
      };
    case BrownKind.martingale:
      switch (q.variant) {
        case 1:
          // e^(σW − ct) keeps its average 1 when c = log E[e^(σW_1)].
          final s = p('s');
          return (log(average((x) => exp(s * x), 0, 1)), 1e-6);
        default:
          final s = p('s'), t = p('t');
          return (log(average((x) => exp(s * x), 0, t)), 1e-6);
      }
    case BrownKind.stopping:
      final a = p('a'), b = p('b');
      return switch (q.variant) {
        0 => (solveAt0(lo: -b, hi: a, left: 0, right: 1), 1e-9),
        _ => (solveAt0(lo: -b, hi: a, c: 1, left: 0, right: 0), 1e-6),
      };
    case BrownKind.drift:
      switch (q.variant) {
        case 0 || 1:
          final mu = p('mu'), sigma = p('sigma'), t = p('t');
          final up = above(0, mu * t, sigma * sigma * t);
          return (p('below') == 1 ? 1 - up : up, table);
        case 2:
          // The chance of reaching −b before a far-off ceiling.
          final mu = p('mu'), sigma = p('sigma'), b = p('b');
          final u = solveAt0(
            lo: -b,
            hi: 40,
            a: sigma * sigma / 2,
            b: mu,
            left: 1,
            right: 0,
          );
          return (log(u), 1e-3);
        default:
          final a = p('a'), b = p('b');
          final u = solveAt0(lo: -b, hi: a, b: log(2) / 2, left: 0, right: 1);
          return (u, 1e-6);
      }
    case BrownKind.ito:
      final t = p('t');
      switch (q.variant) {
        case 0:
          return (average((x) => pow(x, 4).toDouble(), 0, t), 1e-6);
        case 1:
          final m4 = average((x) => pow(x, 4).toDouble(), 0, t);
          final m2 = average((x) => x * x, 0, t);
          return (m4 - m2 * m2, 1e-6);
        default:
          // The discrete Itô sum Σ g(s_i)ΔW_i has variance Σ E[g(s_i)²]Δ.
          const n = 200000;
          final dt = t / n;
          var v = 0.0;
          for (var i = 0; i < n; i++) {
            final s = i * dt;
            v += (p('w') == 1 ? s : s * s) * dt;
          }
          return (v, 1e-3 * max(1, v));
      }
    case BrownKind.gbm:
      final mu = p('mu'), sigma = p('sigma'), t = p('t');
      // log(S/100) is normal: the model itself, not the answer's formula.
      final m = (mu - sigma * sigma / 2) * t, v = sigma * sigma * t;
      switch (q.variant) {
        case 0:
          return (log(average((x) => exp(x), m, v)), 1e-6);
        case 1:
          var lo = -5.0, hi = 5.0;
          for (var i = 0; i < 80; i++) {
            final mid = (lo + hi) / 2;
            1 - above(mid, m, v) < 0.5 ? lo = mid : hi = mid;
          }
          return (lo, 1e-6);
        default:
          return (above(0, m, v), m == 0 ? 1e-9 : table);
      }
  }
}

void main() {
  const gen = BrownGenerator();

  test('every number answer matches a second way of working it out', () {
    var checked = 0;
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 150; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) continue;
        final (want, tol) = recompute(q);
        expect(
          plainValue(q.answer),
          closeTo(want, tol),
          reason: 'level $level seed $seed ${q.card}',
        );
        expect(q.answerValue!.value, closeTo(plainValue(q.answer), 1e-9));
        checked++;
      }
    }
    expect(checked, greaterThan(1000));
  });

  test('the table matches the normal curve to 0.1%', () {
    for (final MapEntry(key: z2, value: share) in normalTable.entries) {
      expect(
        share.value,
        closeTo(above(z2 / 2, 0, 1), 0.0005),
        reason: 'z = ${z2 / 2}',
      );
    }
  });

  test('exactly one martingale among the four', () {
    var checked = 0;
    for (var level in [5, 10]) {
      for (var seed = 0; seed < 300; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (q.kind != BrownKind.martingale || q.variant != 0) continue;
        for (final o in q.options) {
          final f = Eval(o);
          final worst = [
            (1.0, 0.3),
            (2.0, -0.7),
            (0.5, 1.2),
          ].map((x) => drift(f, x.$1, x.$2).abs()).reduce(max);
          if (o == q.answer) {
            expect(worst, lessThan(1e-3), reason: o);
          } else {
            expect(worst, greaterThan(0.05), reason: o);
          }
        }
        checked++;
      }
    }
    expect(checked, greaterThan(100));
  });

  test('Itô differentials: f′ goes with dW, ½f″ with dt', () {
    var checked = 0;
    for (var seed = 0; seed < 400; seed++) {
      final q = gen.generate(level: 8, seed: seed);
      if (q.kind != BrownKind.ito || q.variant != 2) continue;
      final inside = RegExp(r'^d\((.*)\) = \?$').firstMatch(q.card)![1]!;
      final f = Eval(inside);
      for (final o in q.options) {
        // "A dW_t + B dt", in either order; no coefficient means 1.
        var dw = '0', dt = '0';
        for (final term in o.split(' + ')) {
          if (term.endsWith('dW_{t}')) {
            final c = term.substring(0, term.length - 6).trim();
            dw = c.isEmpty ? '1' : c;
          } else {
            expect(term, endsWith('dt'), reason: o);
            final c = term.substring(0, term.length - 2).trim();
            dt = c.isEmpty ? '1' : c;
          }
        }
        final a = Eval(dw), b = Eval(dt);
        final right = [-0.8, 0.1, 0.9].every((w) {
          const h = 1e-3;
          final f1 = (f.run(0, w + h) - f.run(0, w - h)) / (2 * h);
          final f2 =
              (f.run(0, w + h) - 2 * f.run(0, w) + f.run(0, w - h)) / (h * h);
          return (a.run(0, w) - f1).abs() < 1e-3 &&
              (b.run(0, w) - f2 / 2).abs() < 1e-3;
        });
        expect(right, o == q.answer, reason: '${q.card}: $o');
      }
      checked++;
    }
    expect(checked, greaterThan(40));
  });

  test('the Itô integral of W: dI = W dW, starting at 0', () {
    var checked = 0;
    for (var seed = 0; seed < 400; seed++) {
      final q = gen.generate(level: 8, seed: seed);
      if (q.kind != BrownKind.ito || q.variant != 4) continue;
      for (final o in q.options) {
        final f = Eval(o);
        const h = 1e-3;
        final ok = [(1.0, 0.4), (2.0, -1.1)].every((x) {
          final (t, w) = x;
          final fw = (f.run(t, w + h) - f.run(t, w - h)) / (2 * h);
          return (fw - w).abs() < 1e-3 && drift(f, t, w).abs() < 1e-3;
        });
        expect(ok && f.run(0, 0).abs() < 1e-9, o == q.answer, reason: o);
      }
      checked++;
    }
    expect(checked, greaterThan(40));
  });

  test('options: four, distinct, sorted, with the answer and feedback', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        final why = 'level $level seed $seed ${q.options}';
        expect(q.options, hasLength(4), reason: why);
        expect(q.options.toSet(), hasLength(4), reason: why);
        expect(q.options, contains(q.answer), reason: why);
        expect(q.traps, hasLength(3), reason: why);
        expect(q.steps, hasLength(3), reason: why);
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty, reason: why);
        }
        expect(q.feedbackFor(q.answer), startsWith('Right'));
        // Every piece of maths uses commands MathText knows.
        for (final m in [
          q.card,
          ?q.given,
          ...q.options,
          for (final s in q.steps) ?s.math,
        ]) {
          expect(mathPlain(m), isNot(contains(r'\')), reason: m);
        }
        // Plain text never shows raw shorthand.
        for (final t in [
          q.question,
          q.hint,
          q.caption,
          q.insight,
          for (final s in q.steps) s.text,
          for (final t in q.traps) t.why,
        ]) {
          expect(t, isNot(matches(RegExp(r'[\\{}]|W_'))), reason: t);
        }
        if (q.numeric) {
          final v = q.optionValues!;
          for (var i = 1; i < 4; i++) {
            expect(v[i - 1] < v[i], isTrue, reason: why);
          }
          // The option's text is its value.
          for (final (i, o) in q.options.indexed) {
            expect(plainValue(o), closeTo(v[i].value, 1e-9), reason: why);
          }
        }
      }
    }
  });

  test('chances stay between 0 and 1, and nothing is at or below 0', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) continue;
        final card = q.card;
        final chance = card.startsWith('P(') || card.startsWith('Corr');
        for (final o in q.options) {
          final v = plainValue(o);
          if (o.startsWith('e^')) {
            // e to a power: below 1 when it's a chance, above 1 otherwise.
            expect(chance ? v < 0 : v > 0, isTrue, reason: '$card $o');
          } else if (o.startsWith('100e^')) {
            continue; // a price: any power of e
          } else {
            expect(v, greaterThan(0), reason: '$card $o');
            if (chance) expect(v, lessThan(1), reason: '$card $o');
          }
        }
      }
    }
  });

  test('the answer is not the odd one out by its format', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 300; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) continue;
        String kind(String o) => o.endsWith('%')
            ? '%'
            : o.contains('e^')
            ? 'e'
            : o.contains(r'\frac')
            ? 'frac'
            : 'decimal';
        // Percentages with percentages, powers of e with powers of e.
        final kinds = q.options.map(kind).toSet();
        expect(
          kinds.difference({'frac', 'decimal'}).length <= 1 &&
              (kinds.contains('%') || kinds.contains('e')
                  ? kinds.length == 1
                  : true),
          isTrue,
          reason: '${q.options}',
        );
        final mine = kind(q.answer);
        expect(
          q.options.where((o) => kind(o) == mine).length,
          greaterThanOrEqualTo(2),
          reason: 'level $level seed $seed ${q.options}',
        );
        // "about …" goes under fractions, and under every price.
        for (final (i, o) in q.options.indexed) {
          if (o.startsWith('100e^')) {
            expect(q.notes[i], startsWith('about '));
          } else {
            expect(q.notes[i] != null, o.contains(r'\frac'), reason: o);
          }
        }
      }
    }
  });

  test('the right answer is not given away by its place', () {
    for (var level = 1; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (var seed = 0; seed < 400; seed++) {
        at[gen.generate(level: level, seed: seed).answerIndex]++;
      }
      for (final c in at) {
        expect(
          c / 400,
          inInclusiveRange(0.15, 0.35),
          reason: 'level $level: $at',
        );
      }
    }
  });

  test('formulas are shuffled: the answer can be anywhere', () {
    final at = List.filled(4, 0);
    var n = 0;
    for (final level in [5, 8, 10]) {
      for (var seed = 0; seed < 600; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (q.numeric) continue;
        at[q.answerIndex]++;
        n++;
      }
    }
    expect(n, greaterThan(300));
    for (final c in at) {
      expect(c / n, inInclusiveRange(0.15, 0.35), reason: '$at');
    }
  });

  test('most wrong answers are named mistakes, not plain near misses', () {
    for (var level = 1; level <= 10; level++) {
      var named = 0, all = 0;
      for (var seed = 0; seed < 200; seed++) {
        for (final t in gen.generate(level: level, seed: seed).traps) {
          all++;
          if (!t.why.startsWith('Check the numbers')) named++;
        }
      }
      expect(
        named / all,
        greaterThan(0.6),
        reason: 'level $level: $named of $all',
      );
    }
  });

  test('every question kind and variant comes up', () {
    final seen = <String>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 300; seed++) {
        final q = gen.generate(level: level, seed: seed);
        seen.add('${q.kind.name}/${q.variant}');
      }
    }
    expect(seen, {
      for (final v in [0, 1, 2, 3]) 'scaling/$v',
      for (final v in [0, 1, 2, 3]) 'increments/$v',
      for (final v in [0, 1, 2, 3]) 'table/$v',
      for (final v in [0, 1, 2]) 'reflection/$v',
      for (final v in [0, 1, 2]) 'martingale/$v',
      for (final v in [0, 1, 2]) 'stopping/$v',
      for (final v in [0, 1, 2, 3]) 'drift/$v',
      for (final v in [0, 1, 2, 3, 4]) 'ito/$v',
      for (final v in [0, 1, 2]) 'gbm/$v',
    });
  });

  test('levels bring in their kinds; level 10 mixes 4 to 9', () {
    for (var level = 1; level <= 9; level++) {
      for (var seed = 0; seed < 40; seed++) {
        expect(
          gen.generate(level: level, seed: seed).kind,
          BrownKind.values[level - 1],
        );
      }
    }
    final mixed = {
      for (var seed = 0; seed < 200; seed++)
        gen.generate(level: 10, seed: seed).kind,
    };
    expect(mixed, BrownKind.values.sublist(3).toSet());
  });

  test('pictures fit their questions', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 100; seed++) {
        final q = gen.generate(level: level, seed: seed);
        expect(
          (q.path == null) != (q.bell == null),
          isTrue,
          reason: 'one picture',
        );
        final path = q.path;
        if (path != null) {
          expect(path.ys.length, greaterThan(10));
          expect(path.ys.first, q.kind == BrownKind.gbm ? 100 : 0);
          expect(path.ys.every((y) => y.isFinite), isTrue);
          for (final m in path.marks) {
            expect(m.t, inInclusiveRange(0, path.tEnd + 1e-9));
          }
          if (q.kind == BrownKind.reflection) {
            // The level asked about, in spark orange.
            final level = path.levels.single;
            expect(level.spark, isTrue);
            expect(level.y.abs(), closeTo(q.params['a']!.toDouble(), 1e-9));
          }
          if (path.endDot && q.kind == BrownKind.stopping) {
            // A stopped path ends on one of its levels (if it got there).
            final ends = path.levels.map((l) => l.y).toSet();
            final last = path.ys.last;
            expect(
              ends.contains(last) || path.ys.length > 200,
              isTrue,
              reason: '$last not in $ends',
            );
          }
        }
        final table = q.table;
        if (table != null) {
          expect(table, hasLength(4));
          for (var i = 1; i < 4; i++) {
            expect(table[i], table[i - 1] + 1);
          }
          for (final c in table) {
            expect(normalTable.containsKey(c), isTrue);
          }
          // Every percentage on offer can be made from the table shown.
          final shown = [for (final c in table) normalTable[c]!.value];
          final made = {
            0.5,
            for (final x in shown) ...[x, 1 - x, 2 * x, 1 - 2 * x],
          };
          for (final o in q.options) {
            expect(
              made.any((m) => (m - plainValue(o)).abs() < 1e-9),
              isTrue,
              reason: '$o from $shown',
            );
          }
        }
      }
    }
  });

  test('how to play follows the house rules', () {
    final how = const BrownianPathGame().howTo;
    expect(how.steps, hasLength(3));
    for (final s in how.steps) {
      expect(s.title.length, lessThanOrEqualTo(42), reason: s.title);
      expect(s.text.length, lessThanOrEqualTo(110), reason: s.text);
      expect(s.text, endsWith('.'));
    }
    expect(how.levels, isNotEmpty);
  });

  test('formatting', () {
    expect(bnum(Frac(2, 3)), r'\frac{2}{3}');
    expect(bnum(Frac(3, 8)), '0.375');
    expect(bnum(Frac(-1, 2)), '-0.5');
    expect(fracNote(Frac(2, 3)), 'about 0.67');
    expect(fracNote(Frac(3, 4)), isNull);
    expect(pc(Frac(159, 1000)), '15.9%');
    expect(pc(Frac(318, 1000)), '31.8%');
    expect(pc(Frac(1, 2)), '50%');
    expect(tail(-2), Frac(841, 1000));
    expect(tail(0), Frac(1, 2));
    expect(tail(7), isNull);
    expect(root(Frac(4, 9)), Frac(2, 3));
    expect(root(Frac(2)), isNull);
  });

  test('the evaluator reads the shorthand', () {
    expect(Eval(r'W_{t}^{2} - t').run(2, 3), 7);
    expect(
      Eval(r'e^{3W_{t} - \frac{9t}{2}}').run(1, 0.5),
      closeTo(exp(1.5 - 4.5), 1e-12),
    );
    expect(Eval(r'\frac{1}{2}(W_{t}^{2} - t)').run(1, 2), 1.5);
    expect(Eval(r'tW_{t}').run(3, 2), 6);
    expect(Eval(r'W_{t}^{3} - 3tW_{t}').run(2, 1), 1 - 6);
    expect(Eval(r'2e^{2W_{t}}').run(0, 0.5), closeTo(2 * e, 1e-12));
  });

  test('the boards\' numbers', () {
    BrownQuestion find(int level, bool Function(BrownQuestion) ok) {
      for (var seed = 0; seed < 60000; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (ok(q)) return q;
      }
      throw StateError('not generated');
    }

    // Level 4: touching 2 by time 4 is 2 × 15.9% = 31.8%.
    final play = find(
      4,
      (q) =>
          q.card == r'P(\max_{s \le 4} W_{s} \ge 2)' &&
          q.options.join(' ') == '15.9% 31.8% 61.8% 68.2%',
    );
    expect(play.answer, '31.8%');
    expect(play.table, [1, 2, 3, 4]);
    expect(play.feedbackFor('15.9%'), contains('factor 2'));
    // Level 3: above 4 at time 4 is z = 2, 2.3%.
    final alt = find(
      3,
      (q) =>
          q.card == 'P(W_{4} > 4)' &&
          q.options.join(' ') == '2.3% 4.6% 15.9% 97.7%',
    );
    expect(alt.answer, '2.3%');
    expect(alt.table, [2, 3, 4, 5]);
    // Level 8: d(W³) with the dt term dropped.
    final review = find(8, (q) => q.card == r'd(W_{t}^{3}) = ?');
    expect(review.answer, r'3W_{t}^{2} dW_{t} + 3W_{t} dt');
    expect(
      review.feedbackFor(r'3W_{t}^{2} dW_{t}'),
      'That drops the dt term. Itô adds ½f″ dt, which is 3W dt here.',
    );
  });
}
