import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/odds_on/odds_math.dart';
import 'package:smartx/games/odds_on/odds_puzzle.dart';

/// Every way [n] dice can land, as lists of faces.
Iterable<List<int>> rolls(int n) sync* {
  if (n == 0) {
    yield [];
    return;
  }
  for (final rest in rolls(n - 1)) {
    for (var f = 1; f <= 6; f++) {
      yield [...rest, f];
    }
  }
}

/// Every way [n] coins can land (true = heads).
Iterable<List<bool>> flips(int n) sync* {
  for (var m = 0; m < (1 << n); m++) {
    yield [for (var i = 0; i < n; i++) (m >> i) & 1 == 1];
  }
}

/// Chance of [hit] over all [outcomes], counted one by one.
Frac count<T>(Iterable<T> outcomes, bool Function(T) hit) {
  var yes = 0, all = 0;
  for (final o in outcomes) {
    all++;
    if (hit(o)) yes++;
  }
  return Frac(yes, all);
}

/// Chance of [hit] among outcomes where [given] holds.
Frac countGiven<T>(
  Iterable<T> outcomes,
  bool Function(T) given,
  bool Function(T) hit,
) => count(outcomes.where(given), hit);

/// Ordered draws of two different balls from a bag (true = red).
Iterable<(bool, bool)> twoBalls(int red, int blue) sync* {
  final bag = [
    for (var i = 0; i < red; i++) true,
    for (var i = 0; i < blue; i++) false,
  ];
  for (var i = 0; i < bag.length; i++) {
    for (var j = 0; j < bag.length; j++) {
      if (i != j) yield (bag[i], bag[j]);
    }
  }
}

/// The answer worked out independently of the generator.
Frac bruteForce(OddsQuestion q) {
  final p = q.params;
  return switch (q.kind) {
    OddsKind.dieEvent => Frac(p['count']!, 6),
    OddsKind.twoCoins => count(flips(2), (f) {
      final heads = f.where((h) => h).length;
      return switch (p['which']!) {
        0 => heads == 1,
        1 => heads == 2,
        _ => heads >= 1,
      };
    }),
    OddsKind.cardDraw => Frac(p['count']!, 52),
    OddsKind.diceTotal => count(rolls(2), (r) => r[0] + r[1] == p['total']),
    OddsKind.doubles => count(rolls(2), (r) => r[0] == r[1]),
    OddsKind.threeCoins => count(
      flips(3),
      (f) => f.where((h) => h).length == p['heads'],
    ),
    OddsKind.bagDraw => Frac(p['red']!, p['red']! + p['blue']! + p['green']!),
    OddsKind.atLeastOneSix => count(rolls(p['dice']!), (r) => r.contains(6)),
    OddsKind.bothSameColour => count(
      twoBalls(p['red']!, p['blue']!),
      (d) => d.$1 && d.$2,
    ),
    OddsKind.oneOfEach => count(
      twoBalls(p['red']!, p['blue']!),
      (d) => d.$1 != d.$2,
    ),
    OddsKind.atLeastOneHead => count(
      flips(p['coins']!),
      (f) => f.contains(true),
    ),
    OddsKind.twoHearts => () {
      // Cards 0..51; hearts are 0..12. Ordered pairs of different cards.
      var yes = 0, all = 0;
      for (var a = 0; a < 52; a++) {
        for (var b = 0; b < 52; b++) {
          if (a == b) continue;
          all++;
          if (a < 13 && b < 13) yes++;
        }
      }
      return Frac(yes, all);
    }(),
    OddsKind.givenTotal => countGiven(
      rolls(2),
      (r) => r[0] + r[1] == p['total'],
      (r) => r[0] == r[1],
    ),
    OddsKind.givenASix => countGiven(
      rolls(2),
      (r) => r.contains(6),
      (r) => r[0] == 6 && r[1] == 6,
    ),
    OddsKind.threeDiceDifferent => count(
      rolls(3),
      (r) => r.toSet().length == 3,
    ),
    OddsKind.bayesTest => () {
      final prior = Frac(1, p['n']!);
      final sens = Frac(p['sens']!, 100), fp = Frac(p['fp']!, 100);
      return prior * sens / (prior * sens + (Frac.one - prior) * fp);
    }(),
    OddsKind.whichCoin => () {
      final k = p['coins']!, m = p['heads']!;
      final twoHeaded = Frac(1, k);
      final fair = Frac(k - 1, k) * Frac(1, 2).pow(m);
      return twoHeaded / (twoHeaded + fair);
    }(),
    OddsKind.takingTurns => () {
      // Sum the chance you win on your 1st, 2nd, 3rd … turn.
      final hit = Frac(p['faces']!, 6), miss = Frac.one - hit;
      var total = 0.0, bothMiss = 1.0;
      for (var round = 0; round < 400; round++) {
        total += bothMiss * hit.value;
        bothMiss *= miss.value * miss.value;
      }
      return Frac((total * 1e6).round(), 1000000);
    }(),
  };
}

void main() {
  const gen = OddsGenerator();

  test('fractions stay exact and in lowest terms', () {
    expect(Frac(10, 36), Frac(5, 18));
    expect('${Frac(10, 36)}', '5/18');
    expect(Frac(1, 6) + Frac(1, 6), Frac(1, 3));
    expect(Frac.one - Frac(5, 6).pow(2), Frac(11, 36));
    expect(Frac(5, 36).percent, 'about 14%');
    expect(Frac(1, 216).percent, 'under 1%');
    expect(choose(5, 2), 10);
  });

  for (final kind in OddsKind.values) {
    test('${kind.name}: the answer matches a brute-force count', () {
      for (var seed = 0; seed < 40; seed++) {
        final q = gen.generateKind(kind, seed: seed);
        final truth = bruteForce(q);
        if (kind == OddsKind.takingTurns) {
          expect(q.answer.value, closeTo(truth.value, 1e-6));
        } else {
          expect(q.answer, truth, reason: '${q.question} (seed $seed)');
        }
      }
    });
  }

  for (var level = 1; level <= 10; level++) {
    test('level $level questions are well formed', () {
      final d = OddsDifficulty.forLevel(level);
      for (var seed = 0; seed < 200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        expect(d.kinds, contains(q.kind));
        expect(q.options, hasLength(4), reason: q.question);
        expect(q.options.toSet(), hasLength(4), reason: 'distinct options');
        expect(q.options, contains(q.answer));
        expect(q.options, [...q.options]..sort(), reason: 'smallest first');
        for (final o in q.options) {
          expect(o.isProbability, isTrue, reason: '$o in ${q.question}');
        }
        expect(q.steps, isNotEmpty);
        expect(q.steps.last, contains('${q.answer}'));
        for (final slip in q.slips.keys) {
          expect(slip, isNot(q.answer));
          expect(q.options, contains(slip));
        }
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty);
        }
      }
    });
  }

  test('same level and seed give the same question', () {
    final a = gen.generate(level: 7, seed: 11);
    final b = gen.generate(level: 7, seed: 11);
    expect(a.question, b.question);
    expect(a.options, b.options);
  });

  test('a wrong pick names the slip behind it', () {
    // The answer's rank is random, so a slip on one side isn't offered
    // every time; find a question that offers it.
    for (var seed = 0; seed < 60; seed++) {
      final q = gen.generateKind(OddsKind.atLeastOneSix, seed: seed);
      final adding = Frac(q.params['dice']!, 6);
      if (!q.options.contains(adding)) continue;
      expect(q.feedbackFor(adding), contains('counts rolls with two sixes'));
      expect(q.feedbackFor(q.answer), q.insight);
      return;
    }
    fail('the adding slip never came up in 60 seeds');
  });
}
