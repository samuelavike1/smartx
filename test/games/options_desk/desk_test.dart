import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/odds_on/odds_math.dart';
import 'package:smartx/games/options_desk/desk_puzzle.dart';

/// The answer worked out again, in plain doubles, from the question's
/// numbers (no shared code with the generator).
double recompute(DeskQuestion q) {
  double p(String k) => q.params[k]!.value;
  bool call() => p('call') == 1;
  double callPay(double s, double k) => max(s - k, 0);
  double putPay(double s, double k) => max(k - s, 0);
  double pay(double s, double k) => call() ? callPay(s, k) : putPay(s, k);
  switch (q.kind) {
    case DeskKind.payoff:
      return pay(p('s'), p('k'));
    case DeskKind.profit:
      return pay(p('s'), p('k')) - p('p');
    case DeskKind.short:
      return p('p') - pay(p('s'), p('k'));
    case DeskKind.breakeven:
      return call() ? p('k') + p('p') : p('k') - p('p');
    case DeskKind.straddle:
      return (p('s') - p('k')).abs() - p('c') - p('p');
    case DeskKind.spread:
      return min(callPay(p('s'), p('k1')), p('k2') - p('k1')) - p('net');
    case DeskKind.parity:
      return p('askPut') == 1
          ? p('c') - p('s') + p('k')
          : p('p') + p('s') - p('k');
    case DeskKind.binomial:
      final q0 = (p('s0') - p('down')) / (p('up') - p('down'));
      return q0 * pay(p('up'), p('k')) + (1 - q0) * pay(p('down'), p('k'));
    case DeskKind.hedge:
      return (pay(p('up'), p('k')) - pay(p('down'), p('k'))) /
          (p('up') - p('down'));
    case DeskKind.deltaGamma:
      final m = p('move');
      return p('c') + p('delta') * m + 0.5 * p('gamma') * m * m;
    case DeskKind.theta:
      return p('c') + p('theta') * p('days');
    case DeskKind.vega:
      return p('c') + p('vega') * p('pts');
    case DeskKind.concept:
      return double.nan;
  }
}

void main() {
  const gen = DeskGenerator();

  test('every answer matches a plain recount, at every level', () {
    final kinds = <DeskKind>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 120; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        expect(q.options, hasLength(4), reason: '${q.kind} ${q.params}');
        expect(q.options.toSet(), hasLength(4), reason: '${q.options}');
        expect(q.options, contains(q.answer));
        expect(q.steps.length, inInclusiveRange(2, 3));
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty);
        }
        if (q.kind == DeskKind.concept) continue;
        // Every money option is in exact cents: none reads "about".
        expect(
          q.options.where((o) => o.contains('about')),
          isEmpty,
          reason: '${q.kind} ${q.options}',
        );
        expect(
          q.answerValue!.value,
          closeTo(recompute(q), 1e-9),
          reason: '${q.kind} ${q.params}',
        );
        // Every wrong option is a different number from the answer.
        for (final t in q.traps) {
          expect(t.value, isNot(q.answerValue));
        }
      }
    }
    expect(kinds, DeskKind.values.toSet());
  });

  test('the right answer is not given away by its size', () {
    for (var level = 1; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (var seed = 0; seed < 300; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (q.kind == DeskKind.concept) continue;
        final values = [
          for (final o in q.options)
            o == q.answer
                ? q.answerValue!
                : q.traps.firstWhere((t) => t.label == o).value!,
        ];
        expect(
          values,
          orderedEquals([...values]..sort((a, b) => a.compareTo(b))),
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

  test('concept questions have one right answer, in any spot', () {
    final at = List.filled(4, 0);
    for (var seed = 0; seed < 600; seed++) {
      final q = gen.generate(level: 10, seed: seed);
      if (q.kind != DeskKind.concept) continue;
      at[q.answerIndex]++;
      expect(q.traps.map((t) => t.label), isNot(contains(q.answer)));
    }
    expect(at.every((c) => c > 0), isTrue, reason: '$at');
  });

  test('the boards\' numbers', () {
    // Long call, strike 50, paid 3, stock 58: payoff 8, profit 5.
    final leg = Leg(type: OptType.call, strike: Frac(50), premium: Frac(3));
    expect(leg.payoff(Frac(58)), Frac(8));
    expect(leg.profit(Frac(58)), Frac(5));
    // Tree 100 → 120 / 80, call at 100: fair odds 1/2, price 10.
    final q = (Frac(100) - Frac(80)) / (Frac(120) - Frac(80));
    expect(q * Frac(20), Frac(10));
    // 4.20 + 0.60 × 2 + ½ × 0.05 × 4 = 5.50.
    expect(
      Frac(21, 5) + Frac(3, 5) * Frac(2) + Frac(1, 2) * Frac(1, 20) * Frac(4),
      Frac(11, 2),
    );
    expect(dec(Frac(3, 5)), '0.60');
    expect(ratio(Frac(1, 2)), '0.5');
    expect(ratio(Frac(2, 3)), '2/3');
  });
}
