import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/expect_it/expect_puzzle.dart' show about;
import 'package:smartx/games/odds_on/odds_math.dart';
import 'package:smartx/games/spread_bell/bell_puzzle.dart';

/// Variance of a distribution given as value → chance.
double _var(Map<double, double> dist) {
  var m = 0.0, total = 0.0;
  dist.forEach((x, p) {
    m += x * p;
    total += p;
  });
  m /= total;
  var v = 0.0;
  dist.forEach((x, p) => v += (x - m) * (x - m) * p / total);
  return v;
}

/// The distribution of a sum, by convolving two distributions.
Map<double, double> _convolve(Map<double, double> a, Map<double, double> b) {
  final out = <double, double>{};
  a.forEach((x, p) {
    b.forEach((y, q) => out[x + y] = (out[x + y] ?? 0) + p * q);
  });
  return out;
}

Map<double, double> _uniform(List<double> xs) {
  final out = <double, double>{};
  for (final x in xs) {
    out[x] = (out[x] ?? 0) + 1 / xs.length;
  }
  return out;
}

/// Heads in n fair-or-not flips, by repeated convolution of one flip.
Map<double, double> _heads(int n, double p) {
  var d = <double, double>{0: 1};
  for (var i = 0; i < n; i++) {
    d = _convolve(d, {0: 1 - p, 1: p});
  }
  return d;
}

Map<double, double> _poisson(double lambda) {
  final out = <double, double>{};
  var term = exp(-lambda);
  for (var k = 0; k <= 4 * lambda + 60; k++) {
    out[k.toDouble()] = term;
    term *= lambda / (k + 1);
  }
  return out;
}

/// Var of X + s·Y where X = σx·U, Y = σy·V, U and V are ±1 coins that agree
/// with chance (1 + ρ) / 2: a four-point joint law with that correlation.
double _jointVar(double sx, double sy, double rho, double s) {
  final agree = (1 + rho) / 2;
  final dist = <double, double>{};
  for (final (u, v, p) in [
    (1, 1, agree / 2),
    (-1, -1, agree / 2),
    (1, -1, (1 - agree) / 2),
    (-1, 1, (1 - agree) / 2),
  ]) {
    final z = sx * u + s * sy * v;
    dist[z] = (dist[z] ?? 0) + p;
  }
  return _var(dist);
}

/// Shares below mean + k SDs, from the three "within" shares of the rule.
double _ruleBelow(int k) {
  const within = {1: .68, 2: .95, 3: .997};
  if (k <= -4) return 0;
  if (k >= 4) return 1;
  if (k == 0) return .5;
  final up = .5 + within[k.abs()]! / 2;
  return k > 0 ? up : 1 - up;
}

/// The card's table, read for any z (negative by symmetry).
double _tableBelow(double z) {
  final t = {0.5: .69, 1.0: .84, 1.5: .93, 2.0: .975, 2.5: .994};
  if (z == 0) return .5;
  return z > 0 ? t[z]! : 1 - t[-z]!;
}

/// The answer worked out again in plain doubles, by enumerating the
/// distribution (no shared code with the generator).
double recompute(BellQuestion q) {
  double p(String k) => q.params[k]!.value;
  int i(String k) => p(k).round();
  switch (q.kind) {
    case BellKind.spread:
      final xs = i('variant') == 0
          ? [for (var j = 0; j < i('n'); j++) p('x$j')]
          : [for (var j = 0; j < 6; j++) p('f$j')];
      return _var(_uniform(xs));
    case BellKind.add:
      final die = _uniform([1, 2, 3, 4, 5, 6]);
      switch (i('variant')) {
        case 0:
          var d = <double, double>{0: 1};
          for (var j = 0; j < i('n'); j++) {
            d = _convolve(d, die);
          }
          return _var(d);
        case 1:
          var d = _heads(i('m'), .5);
          for (var j = 0; j < i('n'); j++) {
            d = _convolve(d, die);
          }
          return _var(d);
        default:
          final h = _heads(i('n'), .5);
          return sqrt(
            _var({for (final e in h.entries) 2 * e.key - p('n'): e.value}),
          );
      }
    case BellKind.scale:
      final sd = i('sd') == 1;
      final half = sd ? p('s') : sqrt(p('s'));
      final y = {p('a') * half + p('b'): .5, -p('a') * half + p('b'): .5};
      return sd ? sqrt(_var(y)) : _var(y);
    case BellKind.rule:
      final inside = _ruleBelow(i('hi')) - _ruleBelow(i('lo'));
      return i('both') == 1 ? 1 - inside : inside;
    case BellKind.zscore:
      final mu = p('mu'), sigma = p('sigma');
      switch (i('variant')) {
        case 0 || 2:
          return _tableBelow((p('x') - mu) / sigma);
        case 1:
          return 1 - _tableBelow((p('x') - mu) / sigma);
        case 3:
          return _tableBelow((p('x') - mu) / sigma) -
              _tableBelow((p('x1') - mu) / sigma);
        default:
          for (final z in [0.5, 1.0, 1.5, 2.0, 2.5]) {
            if ((1 - _tableBelow(z) - p('top')).abs() < 1e-9) {
              return mu + z * sigma;
            }
          }
          throw StateError('no z for ${p('top')}');
      }
    case BellKind.average:
      final n = i('n'), sigma = p('sigma');
      double sdOfAverage(int draws) {
        final h = _heads(draws, .5);
        return sqrt(
          _var({
            for (final e in h.entries)
              sigma * (2 * e.key - draws) / draws: e.value,
          }),
        );
      }
      switch (i('variant')) {
        case 0:
          return sdOfAverage(n);
        case 1:
          return pow(sdOfAverage(n), 2).toDouble();
        case 2:
          // The fewest draws whose average is k times narrower.
          final goal = 1 / sqrt(p('n0')) / p('k');
          var m = 1;
          while (1 / sqrt(m) > goal + 1e-12) {
            m++;
          }
          return m.toDouble();
        default:
          return 2 * sdOfAverage(n);
      }
    case BellKind.binomial:
      final n = i('n'), chance = p('p');
      switch (i('variant')) {
        case 0:
          return _var(_heads(n, chance));
        case 1:
          return sqrt(_var(_heads(n, chance)));
        default:
          // Scaled down by n the convolution is just as long; use the
          // average of n draws of one 0-or-1 answer instead.
          final one = _var({0: 1 - chance, 1: chance});
          return sqrt(one / n);
      }
    case BellKind.poisson:
      switch (i('variant')) {
        case 0 || 1:
          var d = <double, double>{0: 1};
          final one = _poisson(p('lambda'));
          for (var j = 0; j < i('t'); j++) {
            d = _convolve(d, one);
            d.removeWhere((_, v) => v < 1e-15);
          }
          final v = _var(d);
          return i('variant') == 0 ? v : sqrt(v);
        case 2:
          return sqrt(_var(_convolve(_poisson(p('a')), _poisson(p('b')))));
        default:
          final minusB = {
            for (final e in _poisson(p('b')).entries) -e.key: e.value,
          };
          return _var(_convolve(_poisson(p('a')), minusB));
      }
    case BellKind.covar:
      switch (i('variant')) {
        case 0:
          final a = p('a'), b = p('b');
          return _jointVar(sqrt(a), sqrt(b), p('c') / sqrt(a * b), p('s'));
        case 1:
          return _jointVar(p('sx'), p('sy'), p('rho'), p('s'));
        default:
          return sqrt(_jointVar(p('sx'), p('sy'), p('rho'), p('s')));
      }
  }
}

void main() {
  const gen = BellGenerator();

  test('every answer matches an independent recount, at every level', () {
    final kinds = <BellKind>{};
    final variants = <String>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 120; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        variants.add('${q.kind} ${q.params['variant']}');
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
    expect(kinds, BellKind.values.toSet());
    // Every variant of every kind turns up.
    expect(variants, hasLength(28), reason: '$variants');
  });

  test('a share is never offered at 100% or above, nothing at or below 0', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        for (final (i, v) in q.optionValues.indexed) {
          expect(v > Frac.zero, isTrue, reason: '${q.options}');
          if (q.isShare) {
            expect(v < Frac.one, isTrue, reason: '${q.options}');
            expect(q.options[i], endsWith('%'));
            expect(q.options[i], isNot(contains('/')));
          }
        }
      }
    }
  });

  test('the answer is never the only fraction, or the only tidy number', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (q.isShare) {
          expect(q.notes.every((n) => n == null), isTrue);
          continue;
        }
        bool untidy(Frac v) => about(v) != null;
        final mine = untidy(q.answerValue);
        expect(
          q.optionValues.where((v) => untidy(v) == mine).length,
          greaterThanOrEqualTo(2),
          reason: 'level $level: ${q.options}',
        );
        for (final (i, v) in q.optionValues.indexed) {
          expect(q.notes[i], about(v));
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
        reason:
            'level $level: '
            '$named of $all',
      );
    }
  });

  test('the scene fits its picture', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 100; seed++) {
        final s = gen.generate(level: level, seed: seed).scene;
        expect(s.chips, isNotEmpty);
        expect(s.chips.length, lessThanOrEqualTo(4));
        switch (s.visual) {
          case BellVisual.bars:
            expect(s.bars.length, inInclusiveRange(4, 45));
            expect(s.bars.every((b) => b >= 0 && b.isFinite), isTrue);
            expect(s.bars.reduce(max), greaterThan(0));
          case BellVisual.bell:
            expect(s.ticks, hasLength(7));
            for (final (a, b) in s.shade) {
              expect(a, lessThan(b));
            }
          case BellVisual.dots:
            expect(s.values.every((v) => v >= 0 && v <= 10), isTrue);
          case BellVisual.dice:
            expect(s.faces.isNotEmpty || s.dice + s.coins > 0, isTrue);
          case BellVisual.twoBells:
            expect(s.ratio, greaterThan(0));
          case BellVisual.scatter:
            expect(s.rho.abs(), lessThan(1));
        }
      }
    }
  });

  test('the boards\' numbers', () {
    // Level 4: mean 100, SD 15, above 130 is 2.5%; options 2.5, 5, 16, 97.5.
    expect(_ruleBelow(4) - _ruleBelow(2), closeTo(.025, 1e-12));
    expect(pct(Frac(1, 40)), '2.5%');
    expect(pct(Frac(3, 2000)), '0.15%');
    // Level 8: 4 calls a minute for 9 minutes: SD √36 = 6.
    expect(root(Frac(36)), Frac(6));
    expect(root(Frac(35, 12)), isNull);
    // Level 5: z = (650 − 500) ÷ 100 = 1.5, so 93% below.
    expect(_tableBelow(1.5), .93);
    // A die's variance.
    expect(_var(_uniform([1, 2, 3, 4, 5, 6])), closeTo(35 / 12, 1e-12));
    expect(signed(Frac(-1, 4)), '−0.25');
    // Look for the boards' questions among real seeds.
    bool seen(int level, bool Function(BellQuestion q) match) {
      for (var seed = 0; seed < 4000; seed++) {
        if (match(gen.generate(level: level, seed: seed))) return true;
      }
      return false;
    }

    expect(
      seen(
        4,
        (q) =>
            q.question == 'What share of test scores are above 130?' &&
            q.scene.chips.join() == 'Mean 100SD 15' &&
            q.options.join(' ') == '2.5% 5% 16% 97.5%',
      ),
      isTrue,
    );
    expect(
      seen(
        8,
        (q) =>
            q.question ==
                'What\'s the standard deviation of the calls in 9 minutes?' &&
            q.scene.chips.first == '4 calls a minute' &&
            q.options.join(' ') == '6 12 18 36',
      ),
      isTrue,
    );
    expect(
      seen(
        5,
        (q) =>
            q.question == 'What share of scores are below 650?' &&
            q.scene.chips.join(' · ') == 'Mean 500 · SD 100 · z 1.5 → 93%' &&
            q.options.join(' ') == '7% 43% 86% 93%',
      ),
      isTrue,
    );
  });
}
