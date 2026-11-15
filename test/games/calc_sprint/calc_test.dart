import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/calc_sprint/calc_puzzle.dart';
import 'package:smartx/games/odds_on/odds_math.dart';

/// Evaluates the maths shorthand shown on screen (the subset the game
/// uses): numbers, one variable, e, +, −, implicit products, powers,
/// \frac, \sqrt, \sin, \cos, \ln, \log_{10}. Written for the test alone, so
/// the answers are checked against what the player actually sees.
class Eval {
  Eval(String source, this.vars)
    : s = source.replaceAll(' ', '').replaceAll(' ', '').replaceAll(r'$', '');

  final String s;
  final Map<String, double> vars;
  int i = 0;

  static const _commands = [
    'frac',
    'sqrt',
    'cdot',
    'sin',
    'cos',
    'log',
    'ln',
    'pi',
  ];

  bool get done => i >= s.length;
  String get ch => s[i];

  double run() {
    final v = _expr();
    if (!done) throw FormatException('left over at $i', s);
    return v;
  }

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
    while (!done && (ch == '-' || ch == '+')) {
      if (ch == '-') sign = -sign;
      i++;
    }
    var v = _factor();
    while (!done) {
      if (ch == '*') {
        i++;
      } else if (s.startsWith(r'\cdot', i)) {
        i += 5;
      } else if (!_startsFactor()) {
        break;
      }
      v *= _factor();
    }
    return sign * v;
  }

  bool _startsFactor() {
    final c = ch;
    return RegExp(r'[0-9.a-zA-Z({\\]').hasMatch(c);
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
      _expect('}');
      return v;
    }
    return _base();
  }

  void _expect(String c) {
    if (done || ch != c) throw FormatException('expected $c at $i', s);
    i++;
  }

  double _base() {
    final c = ch;
    if (c == '(') {
      i++;
      final v = _expr();
      _expect(')');
      return v;
    }
    if (c == '{') return _group();
    if (RegExp(r'[0-9.]').hasMatch(c)) {
      final start = i;
      while (!done && RegExp(r'[0-9.]').hasMatch(ch)) {
        i++;
      }
      return double.parse(s.substring(start, i));
    }
    if (c == '\\') {
      i++;
      final name = _commands.firstWhere(
        (n) => s.startsWith(n, i),
        orElse: () => throw FormatException('unknown command at $i', s),
      );
      i += name.length;
      switch (name) {
        case 'frac':
          final top = _group();
          return top / _group();
        case 'sqrt':
          return sqrt(_group());
        case 'pi':
          return pi;
      }
      var base = e;
      if (name == 'log') {
        _expect('_');
        base = _group();
      }
      final x = !done && ch == '(' ? _base() : _factor();
      return switch (name) {
        'sin' => sin(x),
        'cos' => cos(x),
        'ln' => log(x),
        _ => log(x) / log(base),
      };
    }
    i++;
    if (c == 'e') return e;
    final v = vars[c];
    if (v == null) throw FormatException('unknown letter $c', s);
    return v;
  }
}

double value(String source, [Map<String, double> vars = const {}]) =>
    Eval(source, vars).run();

/// f at x, for a question's function.
double Function(double) fn(CalcQuestion q) =>
    (x) => value(q.expr, {q.variable: x});

/// The k-th derivative by central differences, sharpened twice (Richardson).
double derivative(
  double Function(double) f,
  double x,
  int k, {
  double h = .04,
}) {
  double raw(double h) {
    var s = 0.0;
    for (var j = 0; j <= k; j++) {
      s += (j.isEven ? 1 : -1) * _choose(k, j) * f(x + (k / 2 - j) * h);
    }
    return s / pow(h, k);
  }

  double once(double h) => (4 * raw(h / 2) - raw(h)) / 3;
  return (16 * once(h / 2) - once(h)) / 15;
}

int _choose(int n, int k) {
  var r = 1;
  for (var i = 0; i < k; i++) {
    r = r * (n - i) ~/ (i + 1);
  }
  return r;
}

int _fact(int n) => n <= 1 ? 1 : n * _fact(n - 1);

double simpson(double Function(double) f, double a, double b) {
  const n = 2000;
  final h = (b - a) / n;
  var s = f(a) + f(b);
  for (var i = 1; i < n; i++) {
    s += (i.isOdd ? 4 : 2) * f(a + i * h);
  }
  return s * h / 3;
}

/// The one turning point of the asked kind inside (lo, hi): grid, then a
/// golden-section search.
(double, double) turningPoint(
  double Function(double) f,
  double lo,
  double hi,
  int want,
) {
  const n = 4000;
  final xs = [for (var i = 0; i <= n; i++) lo + (hi - lo) * i / n];
  final ys = [for (final x in xs) want * f(x)];
  final peaks = [
    for (var i = 1; i < n; i++)
      if (ys[i] > ys[i - 1] && ys[i] >= ys[i + 1]) i,
  ];
  expect(peaks, hasLength(1), reason: 'turning points on ($lo, $hi)');
  var a = xs[peaks.single - 1], b = xs[peaks.single + 1];
  final g = (sqrt(5) - 1) / 2;
  for (var it = 0; it < 200; it++) {
    final c = b - g * (b - a), d = a + g * (b - a);
    if (want * f(c) > want * f(d)) {
      b = d;
    } else {
      a = c;
    }
  }
  final x = (a + b) / 2;
  return (x, f(x));
}

/// The right answer, worked out from the function on the card.
double truth(CalcQuestion q) {
  final f = fn(q);
  final p = q.params;
  switch (q.check) {
    case CalcCheck.slope:
      return derivative(f, p['at']!.toDouble(), 1, h: 1e-2);
    case CalcCheck.integral:
      return simpson(f, p['lo']!.toDouble(), p['hi']!.toDouble());
    case CalcCheck.limit:
      if (p['inf'] == 1) return f(1e7);
      final c = p['to']!.toDouble();
      return (f(c + 1e-5) + f(c - 1e-5)) / 2;
    case CalcCheck.estimate:
      final a = p['a']!.toDouble(), h = p['h']!.toDouble();
      var est = f(a) + derivative(f, a, 1, h: 1e-2) * h;
      if (p['order'] == 2) est += derivative(f, a, 2, h: 1e-2) * h * h / 2;
      return est;
    case CalcCheck.coefficient:
      final k = p['k']!.toInt();
      return derivative(f, 0, k, h: .05) / _fact(k);
    case CalcCheck.extremum:
      final (x, y) = turningPoint(
        f,
        p['lo']!.toDouble(),
        p['hi']!.toDouble(),
        p['want']!.toInt(),
      );
      return p['ask'] == 0 ? x : y;
    case CalcCheck.derivative:
      throw StateError('a formula, checked at several points');
  }
}

double tolerance(CalcQuestion q, double v) => switch (q.check) {
  CalcCheck.limit when q.params['inf'] == 1 => 1e-4 * v.abs(),
  CalcCheck.extremum => 1e-4 * max(1, v.abs()),
  CalcCheck.coefficient => 1e-5 * max(1, v.abs()),
  _ => 1e-6 * max(1, v.abs()),
};

void main() {
  const gen = CalcGenerator();
  const points = [0.6, 1.3, 2.2];

  test('every answer matches the maths on the card, at every level', () {
    final kinds = <CalcKind>{};
    final checks = <CalcCheck>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 150; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        checks.add(q.check);
        final why = 'level $level seed $seed: ${q.card} ${q.options}';
        expect(q.options, hasLength(4), reason: why);
        expect(q.options.toSet(), hasLength(4), reason: why);
        expect(q.options, contains(q.answer), reason: why);
        expect(q.steps, hasLength(3), reason: why);
        expect(q.notes, hasLength(4), reason: why);
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty, reason: why);
        }
        if (q.check == CalcCheck.derivative) {
          final f = fn(q);
          final wrong = {for (final o in q.options) o: false};
          for (final x in points) {
            final want = derivative(f, x, 1, h: 1e-2);
            final got = value(q.answer, {q.variable: x});
            expect(got, closeTo(want, 1e-6 * max(1, want.abs())), reason: why);
            for (final o in q.options) {
              if ((value(o, {q.variable: x}) - want).abs() > 1e-6) {
                wrong[o] = true;
              }
            }
          }
          // Every other option really is a different function.
          expect(wrong.values.where((w) => w), hasLength(3), reason: why);
          continue;
        }
        final want = truth(q);
        final got = [for (final o in q.options) value(o)];
        expect(
          got[q.answerIndex],
          closeTo(want, tolerance(q, want)),
          reason: why,
        );
        for (final (i, v) in got.indexed) {
          if (i != q.answerIndex) {
            expect((v - want).abs(), greaterThan(1e-6), reason: why);
          }
        }
        if (q.check == CalcCheck.estimate) {
          // The card names the number being estimated.
          final a = q.params['a']!, h = q.params['h']!;
          expect(value(q.card), closeTo(fn(q)(a + h.toDouble()), 1e-9));
        } else {
          expect(q.card, contains(q.expr), reason: why);
        }
      }
    }
    expect(kinds, CalcKind.values.toSet());
    expect(checks, CalcCheck.values.toSet());
  });

  test('numbers are sorted, formulas are in random order', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 300; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) {
          expect(q.check, anyOf(CalcCheck.derivative, CalcCheck.integral));
          continue;
        }
        final shown = [for (final o in q.options) value(o)];
        expect(
          shown,
          orderedEquals([...shown]..sort()),
          reason: '${q.options}',
        );
        expect(
          q.optionValues,
          orderedEquals([...q.optionValues!]..sort((a, b) => a.compareTo(b))),
        );
      }
    }
  });

  test('nothing at or below 0 where only positive answers make sense', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        // 0 only where the answer itself can be 0 (a slope, a turning
        // point); elsewhere it would always be wrong.
        if (q.numeric &&
            q.check != CalcCheck.slope &&
            q.check != CalcCheck.extremum) {
          for (final o in q.options) {
            expect(value(o), isNot(0), reason: '${q.card} ${q.options}');
          }
        }
        if (!q.positive) continue;
        for (final o in q.options) {
          expect(value(o), greaterThan(0), reason: '${q.card} ${q.options}');
        }
      }
    }
  });

  test('the answer is never the only fraction, or the only tidy number', () {
    var checked = 0;
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) continue;
        bool frac(String o) => o.contains(r'\frac');
        final mine = frac(q.answer);
        expect(
          q.options.where((o) => frac(o) == mine).length,
          greaterThanOrEqualTo(2),
          reason: 'level $level: ${q.options}',
        );
        // "about …" goes under fractions and nothing else.
        for (final (i, o) in q.options.indexed) {
          expect(q.notes[i] != null, frac(o), reason: '${q.options}');
          if (frac(o)) {
            expect(
              q.notes[i],
              'about ${value(o).toStringAsFixed(2).replaceFirst('-', '−')}',
            );
          }
        }
        checked++;
      }
    }
    expect(checked, greaterThan(1000));
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

  test('pictures fit their questions', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 100; seed++) {
        final q = gen.generate(level: level, seed: seed);
        final g = q.graph;
        if (q.check == CalcCheck.extremum) {
          // A graph would show where the turning point is.
          expect(g, isNull);
          final p = q.params;
          final (x, _) = turningPoint(
            fn(q),
            p['lo']!.toDouble(),
            p['hi']!.toDouble(),
            p['want']!.toInt(),
          );
          expect(q.reviewGraph!.at, closeTo(x, 1e-3), reason: q.card);
          expect(q.reviewGraph!.slope, 0);
          continue;
        }
        if (g == null) continue;
        expect(g.lo, lessThan(g.hi));
        for (final x in [g.at, g.target, g.from, g.to]) {
          if (x != null) expect(x, inInclusiveRange(g.lo, g.hi));
        }
        if (q.check == CalcCheck.slope) {
          expect(g.slope, closeTo(value(q.answer), 1e-9));
          expect(g.at, q.params['at']);
        }
        if (q.check == CalcCheck.integral) {
          expect(g.from, q.params['lo']);
          expect(g.to, q.params['hi']);
        }
        // The graph draws the card's function.
        for (var i = 0; i <= 10; i++) {
          final x = g.lo + (g.hi - g.lo) * i / 10;
          expect(g.f(x), closeTo(fn(q)(x), 1e-9 * max(1, g.f(x).abs())));
        }
      }
    }
  });

  test('the evaluator reads the shorthand', () {
    expect(value(r'\frac{16}{3}'), closeTo(16 / 3, 1e-12));
    expect(value(r'-\frac{4}{3}'), closeTo(-4 / 3, 1e-12));
    expect(value(r'2x^{3} - 5x + 1', {'x': 2}), 7);
    expect(value(r'\frac{1}{2}(e^{4} - 1)'), closeTo((exp(4) - 1) / 2, 1e-9));
    expect(value(r'\log_{10} 5'), closeTo(log(5) / ln10, 1e-12));
    expect(
      value(r'-\sin x e^{\cos x}', {'x': 1}),
      closeTo(-sin(1) * exp(cos(1)), 1e-12),
    );
    expect(value(r'2x\ln x + x', {'x': 2}), closeTo(4 * log(2) + 2, 1e-12));
    expect(value(r'(1 + \frac{2}{n})^{3n}', {'n': 1}), 27);
    expect(value(r'x(18 - 2x)^{2}', {'x': 3}), 432);
    expect(
      value(r'\frac{4x}{(2x^{2} + 1)\ln 10}', {'x': 1}),
      closeTo(4 / (3 * ln10), 1e-12),
    );
  });

  test('formatting', () {
    expect(mnum(Frac(16, 3)), r'\frac{16}{3}');
    expect(mnum(Frac(-7, 2)), '-3.5');
    expect(note(Frac(16, 3)), 'about 5.33');
    expect(note(Frac(-4, 3)), 'about −1.33');
    expect(mdec(Frac(201, 20)), '10.05');
    expect(mdec(Frac(13, 1000)), '0.013');
    expect(
      poly([(Frac(2), 3), (Frac(-5), 1), (Frac(1), 0)]),
      '2x^{3} - 5x + 1',
    );
    expect(poly([(Frac(1, 3), 3), (Frac(1), 2)]), r'\frac{1}{3}x^{3} + x^{2}');
    expect(ePow(-2), 'e^{-2}');
    expect(sup(10), '¹⁰');
    // A thin space after a function name, so "sin x" doesn't run together.
    expect(spaced(r'-\sin x \cdot e^{\cos x}'), '-\\sin x \\cdot e^{\\cos x}');
    expect(spaced(r'2\log_{10} 7'), '2\\log_{10} 7');
    expect(spaced(r'\sin(2x)'), r'\sin(2x)');
  });

  test('the boards\' numbers', () {
    CalcQuestion find(int level, bool Function(CalcQuestion) ok) {
      for (var seed = 0; seed < 60000; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (ok(q)) return q;
      }
      throw StateError('not generated');
    }

    // Level 1: f(x) = 2x³ − 5x + 1, f′(2) = 19; slips 38, 3, 7 and 20.
    final play = find(
      1,
      (q) => q.card == 'f(x) = 2x^{3} - 5x + 1' && q.params['at'] == 2,
    );
    expect(play.answer, '19');
    for (final o in play.options) {
      expect([
        '7',
        '19',
        '20',
        '38',
        '3',
        '18',
        '17',
        '21',
        '16',
        '22',
      ], contains(o));
    }
    // Level 4: ∫₁² (x² + 2x) dx = 16/3; F(2) = 20/3, no divide 13, old power 9.5.
    final alt = find(4, (q) => q.card == r'\int_{1}^{2} (x^{2} + 2x) dx');
    expect(alt.answer, r'\frac{16}{3}');
    expect(alt.notes[alt.answerIndex], 'about 5.33');
    expect(simpson((x) => x * x + 2 * x, 1, 2), closeTo(16 / 3, 1e-12));
    // Level 7: √101 ≈ 10 + 1/20 = 10.05 (true 10.0499); 1/√x gives 10.1.
    final review = find(7, (q) => q.card == r'\sqrt{101}');
    expect(review.answer, '10.05');
    expect(review.traps.map((t) => t.label), contains('10.1'));
    expect(
      review.feedbackFor('10.1'),
      'That uses 1/√x as the slope. The slope of √x is 1/(2√x), half of that.',
    );
    expect(review.steps.last.text, 'Add slope × step. True value: 10.0499.');
  });
}
