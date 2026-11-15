import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/odds_on/odds_math.dart';
import 'package:smartx/games/vol_lab/vol_puzzle.dart';

// Everything here is recomputed without the generator's formulas: option
// prices come from integrating the payoff against the lognormal by
// Simpson's rule, barriers from a binomial tree, and the rest from plain
// doubles or brute-force searches.

double _phi(double z) => exp(-z * z / 2) / sqrt(2 * pi);

/// ∫ f(z) φ(z) dz from [lo] to [hi], Simpson's rule.
double _expect(double Function(double z) f, {double lo = -10, double hi = 10}) {
  const n = 4000;
  final h = (hi - lo) / n;
  var s = f(lo) * _phi(lo) + f(hi) * _phi(hi);
  for (var i = 1; i < n; i++) {
    final z = lo + i * h;
    s += (i.isOdd ? 4 : 2) * f(z) * _phi(z);
  }
  return s * h / 3;
}

/// The chance a standard normal falls below [x].
double _cdf(double x) => _expect((_) => 1, hi: x.clamp(-10, 10));

/// The x with [_cdf] x = [p].
double _inv(double p) {
  var lo = -8.0, hi = 8.0;
  for (var i = 0; i < 50; i++) {
    final mid = (lo + hi) / 2;
    _cdf(mid) < p ? lo = mid : hi = mid;
  }
  return (lo + hi) / 2;
}

double _terminal(double s, double sigma, double t, double r, double z) =>
    s * exp((r - sigma * sigma / 2) * t + sigma * sqrt(t) * z);

/// The z at which the stock ends exactly at [k], by halving.
double _edge(double s, double k, double sigma, double t, double r) {
  var lo = -10.0, hi = 10.0;
  for (var i = 0; i < 80; i++) {
    final mid = (lo + hi) / 2;
    _terminal(s, sigma, t, r, mid) < k ? lo = mid : hi = mid;
  }
  return (lo + hi) / 2;
}

/// A European option's price: the discounted average payoff, integrated
/// over the side where it pays (so the kink doesn't blur it).
double _price(
  double s,
  double k,
  double sigma,
  double t, {
  double r = 0,
  bool call = true,
}) {
  final z0 = _edge(s, k, sigma, t, r);
  double pay(double z) {
    final st = _terminal(s, sigma, t, r, z);
    return call ? st - k : k - st;
  }

  return exp(-r * t) * (call ? _expect(pay, lo: z0) : _expect(pay, hi: z0));
}

/// The volatility that makes an at-the-money call (r = 0) cost [c].
double _impliedVol(double s, double t, double c) {
  var lo = 0.001, hi = 3.0;
  for (var i = 0; i < 50; i++) {
    final mid = (lo + hi) / 2;
    _price(s, s, mid, t) < c ? lo = mid : hi = mid;
  }
  return (lo + hi) / 2;
}

final _treeCache = <String, double>{};

/// A knock-out call (S = K = 100, r = 0) as a share of the vanilla, on a
/// binomial tree that checks the barrier at every step.
double _knockOutShare(double sigma, double barrier) =>
    _treeCache.putIfAbsent('$sigma $barrier', () {
      const steps = 1500, s0 = 100.0, k = 100.0;
      final dt = 1 / steps;
      final u = exp(sigma * sqrt(dt)), d = 1 / u;
      final p = (1 - d) / (u - d);
      final up = barrier > s0;
      bool dead(double s) => up ? s >= barrier : s <= barrier;
      var out = [
        for (var j = 0; j <= steps; j++)
          dead(s0 * pow(u, j) * pow(d, steps - j))
              ? 0.0
              : max(s0 * pow(u, j) * pow(d, steps - j) - k, 0.0),
      ];
      var plain = [
        for (var j = 0; j <= steps; j++)
          max(s0 * pow(u, j) * pow(d, steps - j) - k, 0.0),
      ];
      for (var n = steps - 1; n >= 0; n--) {
        out = [
          for (var j = 0; j <= n; j++)
            dead(s0 * pow(u, j) * pow(d, n - j))
                ? 0.0
                : p * out[j + 1] + (1 - p) * out[j],
        ];
        plain = [
          for (var j = 0; j <= n; j++) p * plain[j + 1] + (1 - p) * plain[j],
        ];
      }
      return out[0] / plain[0];
    });

double _f(Object x) => (x as Frac).value;

/// "$38.00", "−0.38", "20%", "110" back to numbers.
double _read(String s) {
  final neg = s.startsWith('−');
  final body = s.replaceAll(RegExp(r'[−$%]'), '');
  final v = double.parse(body) * (s.endsWith('%') ? 0.01 : 1);
  return neg ? -v : v;
}

/// The answer's value recomputed; word questions are checked here and
/// return null.
double? recompute(VolQuestion q) {
  final p = q.params;
  switch (q.kind) {
    case VolKind.direction:
      final call = p['call']! as bool, raise = p['raise']! as bool;
      double at({
        double s = 100,
        double k = 100,
        double sigma = 0.2,
        double t = 1,
        double r = 0.03,
      }) => _price(s, k, sigma, t, r: r, call: call);
      final base = at();
      final bumped = {
        'Stock up': at(s: 110),
        'Stock down': at(s: 90),
        'Higher strike': at(k: 110),
        'Lower strike': at(k: 90),
        'Volatility up': at(sigma: 0.3),
        'Volatility down': at(sigma: 0.1),
        'More time': at(t: 2),
        'Less time': at(t: 0.5),
        'Rates up': at(r: 0.06),
        'Rates down': at(r: 0),
      };
      for (final o in q.options) {
        final up = bumped[o]! > base;
        expect(up, o == q.answer ? raise : !raise, reason: '$o $p');
      }
      return null;
    case VolKind.atm:
      final s = (p['s']! as int).toDouble();
      final sigma = _f(p['sigma']!), t = _f(p['t']!);
      final rule = 0.4 * s * sigma * sqrt(t);
      // The rule is close to the real price at the money.
      expect(rule / _price(s, s, sigma, t), closeTo(1, 0.06));
      return rule;
    case VolKind.scaling:
      final price = _f(p['p']!);
      final t0 = (p['t0']! as int) / 12, t1 = (p['t1']! as int) / 12;
      final s0 = (p['s0']! as int) / 100, s1 = (p['s1']! as int) / 100;
      final scaled = price * (s1 / s0) * sqrt(t1 / t0);
      final real = _price(100, 100, s1, t1) / _price(100, 100, s0, t0);
      expect(scaled / price / real, closeTo(1, 0.06));
      return scaled;
    case VolKind.digitalPrice:
      // Payout × chance × discount, the chance read as given.
      return (p['q']! as int) * _f(p['n2']!) * _f(p['df']!);
    case VolKind.digitalChance:
      return _f(p['price']!) / 100 / _f(p['df']!);
    case VolKind.spreadDigital:
      final h = _f(p['h']!);
      // Long one call, short the other: the payoff ramps up to h, so
      // 1/h of the spread pays $1 above K + h.
      final perDollar = (_f(p['c1']!) - _f(p['c2']!)) / h;
      return (p['q']! as int) * perDollar;
    case VolKind.spreadCount:
      final h = _f(p['h']!), q0 = p['q']! as int;
      var n = 1;
      while (n * h < q0 - 1e-9) {
        n++;
      }
      expect(n * h, closeTo(q0, 1e-9));
      return n.toDouble();
    case VolKind.inOut:
      return _f(p['v']!) - _f(p['given']!);
    case VolKind.farBarrier:
      final variant = p['variant']! as int;
      final share = _knockOutShare(
        (p['vol']! as int) / 100,
        (p['b']! as int).toDouble(),
      );
      // Knock-ins are what the knock-outs leave of the vanilla.
      final mine = variant.isOdd ? 1 - share : share;
      final alive = q.answer == 'Nearly the vanilla';
      expect(q.answer, anyOf('Nearly the vanilla', 'Nearly zero'));
      expect(alive ? mine > 0.9 : mine < 0.1, isTrue, reason: '$p $mine');
      // The vanilla quoted on the card is the real price.
      expect(
        _f(p['vanilla']!),
        closeTo(_price(100, 100, (p['vol']! as int) / 100, 1), 0.006),
      );
      return null;
    case VolKind.cap:
      final k = p['k']! as int, b = p['b']! as int;
      var best = 0.0;
      // Every price the stock can end at without touching the barrier.
      for (var c = 0; c < b * 100; c++) {
        best = max(best, c / 100 - k);
      }
      expect(best, closeTo((b - k).toDouble(), 0.011));
      return (b - k).toDouble();
    case VolKind.dOne:
    case VolKind.dTwo:
      final sigma = _f(p['sigma']!), t = _f(p['t']!);
      final v = sigma * sqrt(t);
      final fromD1 = p['fromD1'] == true;
      final l = fromD1 ? (_f(p['d1']!) - v / 2) * v : _f(p['l']!);
      final s = exp(l);
      final answer = _read(q.answer);
      // Where the stock ends at K = 1, found by halving.
      final z0 = _edge(s, 1, sigma, t, 0);
      if (q.kind == VolKind.dOne) {
        // N(d₁) = E[S_T; S_T > K] / S.
        final share = _expect((z) => _terminal(s, sigma, t, 0, z), lo: z0);
        expect(_cdf(answer), closeTo(share / s, 1e-6), reason: '$p');
      } else {
        // N(d₂) = the chance S_T ends above K.
        final chance = _expect((_) => 1, lo: z0);
        expect(_cdf(answer), closeTo(chance, 1e-6), reason: '$p');
      }
      return answer;
    case VolKind.delta:
    case VolKind.hedge:
      final call = p['call']! as bool;
      final n1 = _f(p['n1']!);
      // A stock and strike with that N(d₁), then delta by a nudge.
      const sigma = 0.3, t = 1.0;
      final l = (_inv(n1) - sigma / 2) * sigma;
      final s = exp(l);
      const e = 1e-4;
      final delta =
          (_price(s * (1 + e), 1, sigma, t, call: call) -
              _price(s * (1 - e), 1, sigma, t, call: call)) /
          (2 * e * s);
      if (q.kind == VolKind.delta) {
        expect(delta, closeTo(_read(q.answer), 2e-3));
        return (delta * 100).round() / 100;
      }
      final shares = (p['n']! as int) * delta.abs();
      expect(shares, closeTo(_read(q.answer), 0.5));
      return shares.roundToDouble();
    case VolKind.impliedVol:
      final s = (p['s']! as int).toDouble(), t = _f(p['t']!);
      final straddle = p['straddle']! as bool;
      final price = _f(p['price']!);
      final rule = price / ((straddle ? 0.8 : 0.4) * s * sqrt(t));
      // A straddle at the money with r = 0 is two calls.
      final real = _impliedVol(s, t, straddle ? price / 2 : price);
      expect(rule / real, closeTo(1, 0.06));
      return rule;
    case VolKind.richer:
      final a = _impliedVol(100, _f(p['ta']!), _f(p['ca']!));
      final b = _impliedVol(100, _f(p['tb']!), _f(p['cb']!));
      final want = (a / b - 1).abs() < 0.05
          ? 'Same volatility'
          : (a > b ? 'A is richer' : 'B is richer');
      expect(q.answer, want, reason: '$p $a $b');
      return null;
  }
}

final _formats = {
  VolFormat.usd: RegExp(r'^−?\$\d+\.\d\d$'),
  VolFormat.dec: RegExp(r'^−?\d+\.\d\d$'),
  VolFormat.pct: RegExp(r'^\d+%$'),
  VolFormat.count: RegExp(r'^\d+$'),
};

void main() {
  const gen = VolGenerator();

  test('every answer matches an independent recount, at every level', () {
    final kinds = <VolKind>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 100; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        final why = '${q.kind} ${q.params} ${q.options}';
        expect(q.options, hasLength(4), reason: why);
        expect(q.options.toSet(), hasLength(4), reason: why);
        expect(q.options, contains(q.answer), reason: why);
        expect(q.steps, hasLength(3));
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty, reason: why);
        }
        final v = recompute(q);
        if (v == null) {
          expect(q.numeric, isFalse, reason: why);
        } else {
          expect(q.numeric, isTrue, reason: why);
          expect(q.optionValues![q.answerIndex], q.answerValue);
          expect(_read(q.answer), closeTo(v, 1e-6), reason: why);
        }
      }
    }
    expect(kinds, VolKind.values.toSet());
  }, timeout: const Timeout(Duration(minutes: 5)));

  test('options share one format, so the answer never stands out', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) continue;
        final fit = [
          for (final f in _formats.values)
            if (q.options.every(f.hasMatch)) f,
        ];
        expect(fit, hasLength(1), reason: '${q.kind} ${q.options}');
        // Each label is its own value.
        for (final (i, o) in q.options.indexed) {
          expect(_read(o), closeTo(q.optionValues![i].value, 1e-9));
        }
      }
    }
  });

  test('chances stay below 1, deltas within ±1, prices above 0', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) continue;
        final values = [for (final v in q.optionValues!) v.value];
        switch (q.kind) {
          case VolKind.digitalChance:
            expect(values.every((v) => v > 0 && v < 1), isTrue);
          case VolKind.delta:
            expect(values.every((v) => v != 0 && v.abs() <= 1), isTrue);
          case VolKind.dOne || VolKind.dTwo:
            break;
          case VolKind.digitalPrice || VolKind.spreadDigital:
            final payout = (q.params['q']! as int).toDouble();
            expect(values.every((v) => v > 0 && v < payout), isTrue);
          default:
            expect(values.every((v) => v > 0), isTrue, reason: '${q.kind}');
        }
      }
    }
  });

  test('the right answer is not given away by its place', () {
    for (var level = 1; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (q.numeric) {
          expect(
            q.optionValues,
            orderedEquals([...q.optionValues!]..sort((a, b) => a.compareTo(b))),
          );
        }
        at[q.answerIndex]++;
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

  test('word options put the answer anywhere', () {
    final at = List.filled(4, 0);
    for (final level in [1, 6, 9]) {
      for (var seed = 0; seed < 1200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) at[q.answerIndex]++;
      }
    }
    final total = at.fold(0, (a, b) => a + b);
    expect(total, greaterThan(1500));
    for (final c in at) {
      expect(c / total, inInclusiveRange(0.2, 0.3), reason: '$at');
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
        reason: 'level $level: $named/$all',
      );
    }
  });

  test('the pictures match their questions', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        final pic = q.scene.picture;
        // d₁ and d₂ show the bell only afterwards: it would give them away.
        final hidden = {VolKind.dOne, VolKind.dTwo};
        if (pic != null) {
          expect(q.scene.pictureOnCard, !hidden.contains(q.kind));
        }
        switch (q.kind) {
          case VolKind.digitalChance:
            // The shaded area is the chance asked for.
            expect(normCdf(pic!.cut), closeTo(q.answerValue!.value, 1e-4));
          case VolKind.dOne || VolKind.dTwo:
            expect(pic!.cut, closeTo(q.answerValue!.value, 1e-9));
          case VolKind.cap:
            final m = pic!.marks.single;
            expect(m.unknown, isTrue);
            expect(m.y, closeTo(q.answerValue!.value, 1e-9));
            expect(pic.barrierX, (q.params['b']! as int).toDouble());
          case VolKind.inOut:
            expect(pic!.visual, VolVisual.path);
            expect(pic.barrierY, isNotNull);
          case VolKind.farBarrier:
            expect(pic!.visual, VolVisual.path);
            expect(pic.barrierY, (q.params['b']! as int).toDouble());
          case VolKind.atm || VolKind.scaling:
            if (pic == null) break;
            final m = pic.marks.firstWhere((m) => m.unknown);
            expect(m.y, closeTo(q.answerValue!.value, 1e-9));
          default:
            break;
        }
      }
    }
  });

  test('the barrier pictures draw the barrier from the chips', () {
    for (var seed = 0; seed < 300; seed++) {
      final q = gen.generate(level: 6, seed: seed);
      if (q.kind != VolKind.inOut) continue;
      final pic = q.scene.picture!;
      final b = _read(q.scene.chips.last.replaceFirst('Barrier ', ''));
      expect(pic.barrierY, b);
      // The spark path touches it; the dashed one never does.
      expect(pic.line.any((p) => p.$2 == b), isTrue);
      expect(pic.ghost.any((p) => (p.$2 - b).abs() < 1), isFalse);
    }
  });

  test('numbers are written the same way everywhere', () {
    expect(usd(Frac(38)), r'$38.00');
    expect(usd(Frac(-3, 2)), r'−$1.50');
    expect(dec2(Frac(-19, 50)), '−0.38');
    expect(dec2(Frac.zero), '0.00');
    expect(pct(Frac(1, 5)), '20%');
    expect(dollars(Frac(205, 2)), r'$102.50');
    expect(dollars(Frac(100)), r'$100');
    expect(tidy(Frac(1, 4)), '0.25');
    expect(tidy(Frac(-1, 10)), '−0.1');
    expect(mathDec(Frac(-1, 20)), '-0.05');
    expect(months(3), '3 months');
    expect(months(12), '1 year');
    expect(months(36), '3 years');
    expect(normCdf(0), closeTo(0.5, 1e-7));
    expect(normCdf(1.96), closeTo(0.975, 1e-4));
    expect(normInv(0.975), closeTo(1.96, 1e-3));
  });

  test('the boards\' numbers', () {
    // Play: a $100 digital above $105, N(d₂) = 0.40, discount 0.95.
    final play = gen.generate(level: 4, seed: 51);
    expect(play.kind, VolKind.digitalPrice);
    expect(play.scene.chips, [r'Pays $100 above $105']);
    expect(play.scene.lines, [
      'N(d_1) = 0.44',
      'N(d_2) = 0.40',
      'e^{-rT} = 0.95',
    ]);
    expect(play.options, [r'$36.10', r'$38.00', r'$40.00', r'$41.80']);
    expect(play.answer, r'$38.00');
    // Alt: in-out parity with a down barrier at $80.
    final alt = gen.generate(level: 6, seed: 106);
    expect(alt.kind, VolKind.inOut);
    expect(alt.scene.chips, [
      r'Vanilla call $7.25',
      r'Down-and-out $3.30',
      r'Barrier $80',
    ]);
    expect(alt.options, [r'$2.95', r'$3.30', r'$3.95', r'$10.55']);
    expect(alt.answer, r'$3.95');
    // Review: 4× the time is 2× the price, not 4×.
    final review = gen.generate(level: 3, seed: 11);
    expect(review.kind, VolKind.scaling);
    expect(review.scene.chips, [
      r'ATM call $3.24',
      'σ 20%',
      'T 3 months',
      'Rates 0',
    ]);
    expect(review.options, [r'$6.48', r'$7.48', r'$8.48', r'$12.96']);
    expect(review.answer, r'$6.48');
    expect(
      review.feedbackFor(r'$12.96'),
      'That scales with T. The price grows with √T: T × 4 means price × 2.',
    );
    expect(review.steps.map((s) => s.text), [
      'Time: 3 months → 1 year, so T × 4 and √T × 2.',
      'The price goes with √T, so it scales the same way.',
      r'$3.24 × 2 = $6.48.',
    ]);
  });
}
