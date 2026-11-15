import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/bond_desk/bond_puzzle.dart';
import 'package:smartx/games/odds_on/odds_math.dart';

/// Today's value of [flows] (year → amount) at yield [y], in doubles.
double _price(Map<int, double> flows, double y) {
  var p = 0.0;
  flows.forEach((t, cf) => p += cf / pow(1 + y, t));
  return p;
}

/// Macaulay duration from the slope of the price: −(1 + y) × P′ ÷ P,
/// with P′ from a central difference (no weighting of years at all).
double _durationBySlope(Map<int, double> flows, double y) {
  const h = 1e-6;
  final slope = (_price(flows, y + h) - _price(flows, y - h)) / (2 * h);
  return -(1 + y) * slope / _price(flows, y);
}

/// The answer worked out again in plain doubles, by a different route where
/// there is one (no shared code with the generator).
double recompute(BondQuestion q) {
  double p(String k) => q.params[k]!.value;
  int i(String k) => p(k).round();
  switch (q.kind) {
    case BondKind.presentValue:
      // Today's value is what grows into f: solve x(1 + r) = f by bisection.
      var lo = 0.0, hi = p('f');
      for (var k = 0; k < 200; k++) {
        final mid = (lo + hi) / 2;
        mid * (1 + p('r')) < p('f') ? lo = mid : hi = mid;
      }
      return lo;
    case BondKind.futureValue:
      // Year by year: add the interest on what's there.
      var m = p('p');
      for (var t = 0; t < i('n'); t++) {
        m += m * p('r');
      }
      return m;
    case BondKind.zeroPrice:
      return _price({i('n'): p('f')}, p('r'));
    case BondKind.couponPrice:
      final n = i('n');
      return _price({
        for (var t = 1; t <= n; t++) t: p('c') + (t == n ? p('face') : 0),
      }, p('y'));
    case BondKind.premium:
      return double.nan;
    case BondKind.zeroYield:
      // Bisection on the yield that prices the zero at p.
      var lo = 0.0, hi = 1.0;
      for (var k = 0; k < 200; k++) {
        final mid = (lo + hi) / 2;
        _price({i('n'): p('f')}, mid) > p('p') ? lo = mid : hi = mid;
      }
      return lo * 100;
    case BondKind.forward:
      // From the two spot rates: (1 + s2)² ÷ (1 + s1) − 1.
      final s1 = 100 / p('p1') - 1;
      final s2 = sqrt(100 / p('p2')) - 1;
      return (pow(1 + s2, 2) / (1 + s1) - 1) * 100;
    case BondKind.macaulay:
      final n = i('n');
      return _durationBySlope({
        for (var t = 1; t <= n; t++) t: p('c') + (t == n ? p('face') : 0),
      }, p('y'));
    case BondKind.priceMove:
      final dMod = p('dMac') > 0 ? p('dMac') / (1 + p('y')) : p('dMod');
      final change = -dMod * p('move') / 100 * p('price');
      return i('askNew') == 1 ? p('price') + change : change;
    case BondKind.zeroDuration:
      final mac = _durationBySlope({i('n'): 100}, p('y'));
      return i('modified') == 1 ? mac / (1 + p('y')) : mac;
    case BondKind.portfolio:
      // Model each bond as a zero with the same duration and value, and
      // read the mix's duration off the slope of its total price.
      const y0 = 0.05;
      double total(double y) =>
          p('va') * pow(1 + y0, p('da')) / pow(1 + y, p('da')) +
          p('vb') * pow(1 + y0, p('db')) / pow(1 + y, p('db'));
      const h = 1e-6;
      final slope = (total(y0 + h) - total(y0 - h)) / (2 * h);
      return -(1 + y0) * slope / total(y0);
  }
}

/// The right word answer from the rules, written out again.
String expectedWords(BondQuestion q) {
  double p(String k) => q.params[k]!.value;
  switch (p('which').round()) {
    case 0:
      final cp = p('cp'), yp = p('yp');
      return yp > cp
          ? 'Below face: a discount'
          : yp < cp
          ? 'Above face: a premium'
          : 'At face: par';
    case 1:
      return p('up') == 1 ? 'It falls' : 'It rises';
    case 2:
      final cp = p('cp').round();
      return p('price') < 100 ? 'Above $cp%' : 'Below $cp%';
    case 3:
      return 'A ${p('n').round()}-year zero';
    default:
      return p('price') > 100 ? 'Drifts down to \$100' : 'Rises to \$100';
  }
}

void main() {
  const gen = BondGenerator();

  test('every answer matches an independent recount, at every level', () {
    final kinds = <BondKind>{};
    final premiumTemplates = <int>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 120; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        final why = '${q.kind} ${q.params}';
        expect(q.options, hasLength(4), reason: why);
        expect(q.options.toSet(), hasLength(4), reason: '${q.options}');
        expect(q.options, contains(q.answer));
        expect(q.steps, hasLength(3));
        for (final s in q.steps) {
          expect(s, isNot(contains('{A}')));
        }
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty);
        }
        if (q.words) {
          premiumTemplates.add(q.params['which']!.value.round());
          expect(q.answer, expectedWords(q), reason: why);
          continue;
        }
        expect(q.optionValues[q.answerIndex], q.answerValue);
        for (final v in q.optionValues) {
          if (q.unit == BondUnit.change) {
            expect(v, isNot(Frac.zero));
          } else {
            expect(v > Frac.zero, isTrue, reason: '${q.options}');
          }
        }
        final slope =
            q.kind == BondKind.macaulay ||
            q.kind == BondKind.zeroDuration ||
            q.kind == BondKind.portfolio;
        expect(
          q.answerValue!.value,
          closeTo(recompute(q), slope ? 1e-5 : 1e-9),
          reason: why,
        );
      }
    }
    expect(kinds, BondKind.values.toSet());
    expect(premiumTemplates, {0, 1, 2, 3, 4});
  });

  test('the right answer is not given away by its size or place', () {
    for (var level = 1; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.words) {
          expect(
            q.optionValues,
            orderedEquals([...q.optionValues]..sort((a, b) => a.compareTo(b))),
          );
        }
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

  test('the right answer is not given away by its format', () {
    final digits = RegExp(r'\d[\d,]*(\.(\d+))?');
    var approx = 0, exact = 0;
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 300; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (q.words) continue;
        final abouts = q.options.where((o) => o.startsWith('about ')).length;
        // All four read "about", or none do.
        expect(abouts == 0 || abouts == 4, isTrue, reason: '${q.options}');
        expect(abouts == 4, q.approx);
        expect(q.approx, !exactCents(q.answerValue!));
        q.approx ? approx++ : exact++;
        // Every option has the same number of decimal places, the same
        // unit and the same shape apart from the digits.
        final places = {
          for (final o in q.options)
            digits.firstMatch(o)!.group(2)?.length ?? 0,
        };
        expect(places, hasLength(1), reason: '${q.options}');
        // Signs aside (a change can go either way), and "1 year" against
        // "2 years", every option has the same shape.
        final shapes = {
          for (final o in q.options)
            o
                .replaceAll(digits, '#')
                .replaceAll(RegExp('[+−]'), '')
                .replaceAll(RegExp('years?'), 'years'),
        };
        expect(shapes, hasLength(1), reason: '${q.options}');
        // Exact options are exact, and each label is its value.
        for (final (i, v) in q.optionValues.indexed) {
          if (!q.approx) expect(exactCents(v), isTrue, reason: '${q.options}');
          final shown = double.parse(
            digits.firstMatch(q.options[i])!.group(0)!.replaceAll(',', ''),
          );
          expect(shown, closeTo(v.value.abs(), 0.005 + 1e-9));
        }
      }
    }
    // Both kinds of question really happen.
    expect(approx, greaterThan(100));
    expect(exact, greaterThan(1000));
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

  test('labels and helpers', () {
    expect(cash(Frac(1331)), '\$1,331');
    expect(cash(Frac(7072, 100)), '\$70.72');
    expect(cash(Frac(100, 3)), 'about \$33.33');
    expect(cash(Frac(-208, 100)), '−\$2.08');
    expect(decimal(Frac(1331, 1000)), '1.331');
    expect(decimal(Frac(9261, 8000)), '1.157625');
    expect(pct(Frac(1, 8)), '12.5%');
    expect(optionLabel(Frac(100), BondUnit.money, 2, false), '\$100.00');
    expect(optionLabel(Frac(-208, 100), BondUnit.change, 2, false), '−\$2.08');
    expect(optionLabel(Frac(208, 100), BondUnit.change, 2, false), '+\$2.08');
    expect(optionLabel(Frac(21, 2), BondUnit.percent, 1, false), '10.5%');
    expect(optionLabel(Frac(9, 5), BondUnit.years, 2, false), '1.80 years');
    expect(optionLabel(Frac.one, BondUnit.years, 0, false), '1 year');
    expect(
      optionLabel(Frac(2100, 1100), BondUnit.years, 2, true),
      'about 1.91 years',
    );
  });

  test('the boards\' numbers', () {
    // Level 4: $10 coupons, $100 face, 3 years at 25%.
    final g = Frac(5, 4);
    final price = Frac(10) / g + Frac(10) / g.pow(2) + Frac(110) / g.pow(3);
    expect(cash(price), '\$70.72');
    expect(cash(Frac(130) / g.pow(3)), '\$66.56');
    // Level 7: $25 coupon, 2 years at 25%: $20 and $80 today, 1.8 years.
    final d = (Frac(20) + Frac(2) * Frac(80)) / Frac(100);
    expect(Frac(25) / g, Frac(20));
    expect(Frac(125) / g.pow(2), Frac(80));
    expect(d, Frac(9, 5));
    expect(d / g, Frac(36, 25)); // modified: 1.44
    // Level 8: −4 × 0.005 × $104 = −$2.08.
    expect(cash(Frac.zero - Frac(4) * Frac(5, 1000) * Frac(104)), '−\$2.08');
    // The generator makes these very questions.
    bool seen(int level, bool Function(BondQuestion) match) =>
        [for (var s = 0; s < 20000; s++) gen.generate(level: level, seed: s)]
            .any(match);
    expect(
      seen(
        4,
        (q) =>
            q.answer == '\$70.72' &&
            q.scene.chips.first == 'Coupon \$10 a year',
      ),
      isTrue,
    );
    expect(
      seen(
        7,
        (q) => q.answer == '1.80 years' && q.options.contains('1.44 years'),
      ),
      isTrue,
    );
    expect(
      seen(
        8,
        (q) =>
            q.answer == '−\$2.08' &&
            q.scene.chips.contains('Modified duration 4'),
      ),
      isTrue,
    );
  });
}
