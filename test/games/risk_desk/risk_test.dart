import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/odds_on/odds_math.dart';
import 'package:smartx/games/risk_desk/risk_puzzle.dart';

/// Portfolio variance from the covariance matrix, w' Σ w, in plain doubles.
double _quadForm(List<double> w, List<double> vol, double rho) {
  var v = 0.0;
  for (var i = 0; i < w.length; i++) {
    for (var j = 0; j < w.length; j++) {
      final corr = i == j ? 1.0 : rho;
      v += w[i] * w[j] * corr * vol[i] * vol[j];
    }
  }
  return v;
}

/// The weight in A (0 to 1) with the lowest variance, by a fine search.
double _bestWeight(double sa, double sb, double rho) {
  var best = 0.0, bestVar = double.infinity;
  for (var i = 0; i <= 100000; i++) {
    final w = i / 100000;
    final v = _quadForm([w, 1 - w], [sa, sb], rho);
    if (v < bestVar - 1e-15) {
      bestVar = v;
      best = w;
    }
  }
  return best;
}

/// The answer worked out again from the question's numbers, without the
/// generator's formulas: covariance matrices, searches and counting.
double recompute(RiskQuestion q) {
  double p(String k) => q.params[k]!.value;
  int i(String k) => p(k).round();
  switch (q.kind) {
    case RiskKind.mixReturn:
      final w = p('w') / 100;
      // Grow $1 split between the two for one year.
      final end = w * (1 + p('ra') / 100) + (1 - w) * (1 + p('rb') / 100);
      return (end - 1) * 100;
    case RiskKind.twoVol:
      final w = p('w') / 100;
      return sqrt(_quadForm([w, 1 - w], [p('sa'), p('sb')], p('rho')));
    case RiskKind.hedge:
      if (i('variant') == 0) {
        final inA = _bestWeight(p('sa'), p('sb'), -1) * 100;
        return i('askA') == 1 ? inA : 100 - inA;
      }
      final w = p('w') / 100;
      return sqrt(max(0, _quadForm([w, 1 - w], [p('sa'), p('sb')], -1)));
    case RiskKind.sharpe:
      if (i('variant') == 0) return (p('r') - p('rf')) / p('s');
      // Search for the return whose Sharpe ratio is the target.
      var lo = 0.0, hi = 100.0;
      for (var k = 0; k < 200; k++) {
        final mid = (lo + hi) / 2;
        (mid - p('rf')) / p('s') < p('sr') ? lo = mid : hi = mid;
      }
      return lo;
    case RiskKind.capm:
      if (i('variant') == 0) {
        return p('rf') + p('beta') * (p('rm') - p('rf'));
      }
      // Beta = cov(stock, market) ÷ var(market).
      final cov = p('rho') * p('si') * p('sm');
      return cov / (p('sm') * p('sm'));
    case RiskKind.diversify:
      switch (i('variant')) {
        case 0:
          final n = i('n');
          return sqrt(
            _quadForm(List.filled(n, 1 / n), List.filled(n, p('s')), 0),
          );
        case 1:
          // The fewest assets that reach the target.
          var n = 1;
          while (sqrt(
                _quadForm(List.filled(n, 1 / n), List.filled(n, p('s')), 0),
              ) >
              p('t') + 1e-9) {
            n++;
          }
          return n.toDouble();
        default:
          // Equal weights over a huge number of assets.
          const n = 1e8;
          final s = p('s'), rho = p('rho');
          return sqrt(s * s / n + (1 - 1 / n) * rho * s * s);
      }
    case RiskKind.covariance:
      switch (i('variant')) {
        case 0:
          return p('rho') * p('sa') * p('sb');
        case 1:
          return p('cov') / (p('sa') * p('sb'));
        default:
          final w = p('w');
          return _quadForm([w, 1 - w], [p('sa'), p('sb')], p('rho'));
      }
    case RiskKind.valueAtRisk:
      // The given multipliers: 1.65 for 95%, 2.33 for 99%.
      final z = i('conf') == 95 ? 1.65 : 2.33;
      final days = i('days');
      // Daily variances add up over independent days.
      final sd = sqrt(days * pow(p('sd') / 100 * p('v'), 2));
      return z * sd;
    case RiskKind.minVariance:
      if (i('variant') == 0) {
        return _bestWeight(p('sa'), p('sb'), 0) * 100;
      }
      final w = _bestWeight(p('sa'), p('sb'), 0);
      return sqrt(_quadForm([w, 1 - w], [p('sa'), p('sb')], 0));
  }
}

void main() {
  const gen = RiskGenerator();

  bool isWeight(RiskQuestion q) =>
      (q.kind == RiskKind.hedge && q.params['variant'] == Frac.zero) ||
      (q.kind == RiskKind.minVariance && q.params['variant'] == Frac.zero);
  bool isCorrelation(RiskQuestion q) =>
      q.kind == RiskKind.covariance && q.params['variant'] == Frac.one;

  test('every answer matches an independent recount, at every level', () {
    final kinds = <RiskKind>{};
    final variants = <String>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 150; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        variants.add('${q.kind} ${q.params['variant'] ?? q.params['rho']}');
        final why = '${q.kind} ${q.params} ${q.options}';
        expect(q.options, hasLength(4), reason: why);
        expect(q.options.toSet(), hasLength(4), reason: why);
        expect(q.optionValues.toSet(), hasLength(4), reason: why);
        expect(q.options, contains(q.answer), reason: why);
        expect(q.optionValues[q.answerIndex], q.answerValue, reason: why);
        expect(q.steps, hasLength(3), reason: why);
        expect(q.traps, hasLength(3), reason: why);
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty, reason: why);
          // Nothing is written as a fraction or "about": every option is
          // exact, so the format never gives the answer away.
          expect(o, isNot(contains('/')), reason: why);
          expect(o, isNot(contains('about')), reason: why);
        }
        for (final v in q.optionValues) {
          expect(v > Frac.zero, isTrue, reason: why);
          if (isWeight(q)) expect(v <= Frac(100), isTrue, reason: why);
          if (isCorrelation(q)) expect(v <= Frac.one, isTrue, reason: why);
        }
        final tolerance = switch (q.kind) {
          RiskKind.minVariance || RiskKind.hedge => 1e-2,
          RiskKind.diversify => 1e-6,
          _ => 1e-7,
        };
        expect(
          q.answerValue.value,
          closeTo(recompute(q), tolerance * max(1, q.answerValue.value)),
          reason: why,
        );
      }
    }
    expect(kinds, RiskKind.values.toSet());
    // Both correlations at level 2, and every variant of the others.
    expect(variants, containsAll(['RiskKind.twoVol 1', 'RiskKind.twoVol 0']));
    for (final k in [
      'hedge 0',
      'hedge 1',
      'sharpe 0',
      'sharpe 1',
      'capm 0',
      'capm 1',
      'diversify 0',
      'diversify 1',
      'diversify 2',
      'covariance 0',
      'covariance 1',
      'covariance 2',
      'valueAtRisk 0',
      'valueAtRisk 1',
      'minVariance 0',
      'minVariance 1',
    ]) {
      expect(variants, contains('RiskKind.$k'));
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

  test('the answer\'s format matches the wrong ones', () {
    // Decimal places: the answer has as many as the wrong options, on
    // average, so counting digits doesn't find it.
    int places(String s) {
      final m = RegExp(r'\.(\d+)').firstMatch(s);
      return m == null ? 0 : m.group(1)!.length;
    }

    for (var level = 1; level <= 10; level++) {
      var answer = 0.0, wrong = 0.0;
      for (var seed = 0; seed < 300; seed++) {
        final q = gen.generate(level: level, seed: seed);
        answer += places(q.answer);
        for (final t in q.traps) {
          wrong += places(t.label) / 3;
        }
      }
      expect(
        (answer - wrong).abs() / 300,
        lessThan(0.5),
        reason: 'level $level',
      );
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

  test('numbers are written the house way', () {
    expect(pct(Frac(8)), '8%');
    expect(pct(Frac(25, 2)), '12.5%');
    expect(pct(Frac(-1, 2)), '−0.5%');
    expect(dec(Frac(3, 200)), '0.015');
    expect(dec(Frac(1, 2)), '0.5');
    expect(dec(Frac(-3, 400)), '−0.0075');
    expect(usd(Frac(49500)), '\$49,500');
    expect(usd(Frac(1000000)), '\$1,000,000');
    expect(usd(Frac(825)), '\$825');
    expect(exactRoot(Frac(9, 4)), Frac(3, 2));
    expect(exactRoot(Frac(2)), isNull);
  });

  test('the boards\' numbers', () {
    // Play: 60% in A (vol 10%), 40% in B (vol 20%), independent.
    final ab = sqrt(_quadForm([0.6, 0.4], [10, 20], 0));
    expect(ab, closeTo(10, 1e-9));
    // Alt: return 13%, risk-free 3%, vol 20%: Sharpe 0.5; 13/20 = 0.65.
    expect((13 - 3) / 20, 0.5);
    // Review: $1,000,000, daily vol 1%, 95%, 9 days.
    expect(1.65 * 0.01 * 1000000 * 3, closeTo(49500, 1e-6));
    expect(1.65 * 0.01 * 1000000 * 9, closeTo(148500, 1e-6));

    // The generator really draws these setups.
    bool seen(bool Function(RiskQuestion q) match, int level) {
      for (var seed = 0; seed < 4000; seed++) {
        if (match(gen.generate(level: level, seed: seed))) return true;
      }
      return false;
    }

    expect(
      seen(
        (q) =>
            q.kind == RiskKind.twoVol &&
            q.params['w'] == Frac(60) &&
            q.params['sa'] == Frac(10) &&
            q.params['sb'] == Frac(20) &&
            q.params['rho'] == Frac.zero,
        2,
      ),
      isTrue,
    );
    expect(
      seen(
        (q) =>
            q.kind == RiskKind.sharpe &&
            q.params['variant'] == Frac.zero &&
            q.params['rf'] == Frac(3) &&
            q.params['s'] == Frac(20) &&
            q.params['r'] == Frac(13),
        4,
      ),
      isTrue,
    );
    expect(
      seen((q) {
        final hit =
            q.kind == RiskKind.valueAtRisk &&
            q.params['variant'] == Frac.zero &&
            q.params['v'] == Frac(1000000) &&
            q.params['sd'] == Frac.one &&
            q.params['conf'] == Frac(95) &&
            q.params['days'] == Frac(9);
        if (hit) {
          expect(q.answer, '\$49,500');
          expect(
            q.traps.map((t) => t.label).followedBy([q.answer]),
            anyOf(contains('\$148,500'), isNotEmpty),
          );
        }
        return hit;
      }, 8),
      isTrue,
    );
  });
}
