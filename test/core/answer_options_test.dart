import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/core/game/answer_options.dart';
import 'package:smartx/games/mental_math/math_puzzle.dart';
import 'package:smartx/games/odds_on/odds_puzzle.dart';

/// Fails if any of the four spots gets less than 15% or more than 35% of
/// the right answers (25% each if it's fair).
void expectSpread(List<int> counts, String what) {
  final total = counts.fold(0, (a, b) => a + b);
  for (final (i, c) in counts.indexed) {
    expect(
      c / total,
      inInclusiveRange(0.15, 0.35),
      reason: '$what: spot ${i + 1} got $c of $total ($counts)',
    );
  }
}

void main() {
  test('the answer lands anywhere, and options stay sorted', () {
    final rng = Random(3);
    final at = List.filled(4, 0);
    for (var i = 0; i < 2000; i++) {
      final options = balancedOptions(
        50,
        const [40],
        [
          for (var k = 1; k <= 12; k++) ...[50 + k, 50 - k],
        ]..shuffle(rng),
        rng,
        compare: (a, b) => a.compareTo(b),
      );
      expect(options, hasLength(4));
      expect(options.toSet(), hasLength(4));
      expect(options, orderedEquals([...options]..sort()));
      at[options.indexOf(50)]++;
    }
    expectSpread(at, 'helper');
  });

  test('a named mistake is kept when it fits its side', () {
    final rng = Random(1);
    var kept = 0, below = 0;
    for (var i = 0; i < 400; i++) {
      final options = balancedOptions(
        50,
        const [40],
        const [49, 51, 52, 53, 48, 47],
        rng,
        compare: (a, b) => a.compareTo(b),
      );
      if (options.indexOf(50) > 0) below++;
      if (options.contains(40)) kept++;
    }
    // Whenever anything sits below the answer, the named 40 is first in.
    expect(kept, below);
  });

  test('short on one side: the other side makes up the numbers', () {
    for (var seed = 0; seed < 50; seed++) {
      final options = balancedOptions(
        1,
        const <int>[],
        const [2, 3, 4, 5],
        Random(seed),
        compare: (a, b) => a.compareTo(b),
      );
      expect(options, [1, 2, 3, 4]);
    }
  });

  test('Mental Math: the right answer is spread over all four spots', () {
    const g = MathGenerator();
    final rng = Random(11);
    for (final kind in MathKind.values) {
      final at = List.filled(4, 0);
      for (var i = 0; i < 400; i++) {
        final t = g.trial(kind, rng);
        expect(t.options, hasLength(4));
        expect(t.options.toSet(), hasLength(4));
        expect(t.options, orderedEquals([...t.options]..sort()));
        expect(t.options.every((o) => o > 0), isTrue);
        at[t.options.indexOf(t.answer)]++;
      }
      expectSpread(at, 'Mental Math, ${kind.name}');
    }
  });

  test('Odds On: the right answer is spread over all four spots', () {
    const g = OddsGenerator();
    for (var level = 1; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (var seed = 0; seed < 300; seed++) {
        final q = g.generate(level: level, seed: seed);
        expect(q.options, hasLength(4));
        at[q.answerIndex]++;
      }
      expectSpread(at, 'Odds On, level $level');
    }
  });
}
