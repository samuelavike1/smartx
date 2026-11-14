import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/scale_sleuth/scale_puzzle.dart';

/// Every fake (coin and way) that fits [log], found by brute force.
Set<(int, bool)> fitting(int coins, Told told, List<Weighing> log) => {
  for (var c = 1; c <= coins; c++)
    for (final heavy in [true, false])
      if ((told != Told.heavier || heavy) &&
          (told != Told.lighter || !heavy) &&
          log.every((w) {
            final sign = heavy ? 1 : -1;
            final tip = w.left.contains(c)
                ? sign
                : (w.right.contains(c) ? -sign : 0);
            return w.tilt ==
                (tip > 0 ? Tilt.left : (tip < 0 ? Tilt.right : Tilt.balanced));
          }))
        (c, heavy),
};

/// Plays the solver's own suggestions against the scale.
ScalePuzzle playWell(ScalePuzzle p) {
  while (p.suspects.coins.length > 1) {
    final w = p.solver.suggest(p.suspects, p.weighingsLeft);
    expect(w, isNotNull, reason: 'stuck at ${p.log.map((w) => w.coins)}');
    p = p.weigh(w!.left, w.right);
  }
  return p;
}

void main() {
  test('every level starts solvable, and good play always wins', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 25; seed++) {
        final p = ScalePuzzle.generate(level: level, seed: seed);
        expect(
          p.solver.solvable(p.suspects, p.setup.weighings),
          isTrue,
          reason: 'level $level, ${p.coins} coins',
        );
        final end = playWell(p);
        expect(end.weighingsLeft, greaterThanOrEqualTo(0));
        final coin = end.suspects.coins.single;
        final r = end.name(coin);
        expect(r.correct, isTrue);
        expect(end.slip, isNull);
        expect(end.feedbackFor(r), startsWith('Only coin $coin fits'));
      }
    }
  });

  test('the levels match the rules', () {
    final rng = Random(1);
    for (var i = 0; i < 40; i++) {
      final one = ScaleSetup.forLevel(1, rng);
      expect((one.coins, one.weighings), (3, 1));
      expect(one.told, isNot(Told.either));
      final six = ScaleSetup.forLevel(6, rng);
      expect(six.coins, inInclusiveRange(15, 18));
      final ten = ScaleSetup.forLevel(10, rng);
      expect((ten.coins, ten.weighings, ten.told), (12, 3, Told.either));
    }
  });

  test('the scale only ever shows a result some fake explains', () {
    final rng = Random(7);
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 20; seed++) {
        var p = ScalePuzzle.generate(level: level, seed: seed);
        while (p.weighingsLeft > 0) {
          // Random, often poor, weighings.
          final coins = [for (var c = 1; c <= p.coins; c++) c]..shuffle(rng);
          final n = 1 + rng.nextInt(p.coins ~/ 2);
          p = p.weigh(coins.take(n).toList(), coins.skip(n).take(n).toList());
          final truth = fitting(p.coins, p.setup.told, p.log);
          expect(truth, isNotEmpty);
          expect({
            for (final c in p.suspects.heavy) (c, true),
            for (final c in p.suspects.light) (c, false),
          }, truth);
        }
        final guess = 1 + rng.nextInt(p.coins);
        final r = p.name(guess);
        expect(p.suspects.coins, contains(r.fake));
        expect(r.correct, p.suspects.coins.length == 1 && r.fake == guess);
        if (!r.correct && p.suspects.coins.length > 1) {
          // A guess among several suspects always loses, and a lost puzzle
          // with weighings used up names the slip.
          expect(p.slip, isNotNull);
        }
      }
    }
  });

  test('a weak second weighing is named as the slip, with a better one', () {
    var p = ScalePuzzle(
      level: 10,
      seed: 0,
      setup: const ScaleSetup(12, 3, Told.either),
    );
    p = p.weigh([1, 2, 3, 4], [5, 6, 7, 8]);
    final first = p.log.single.tilt;
    expect(first, isNot(Tilt.balanced), reason: 'leaves more coins in doubt');
    // Suspects: 1–4 one way, 5–8 the other. Weighing four of them against
    // the other four can't split eight suspects three ways.
    p = p.weigh([1, 2, 5, 6], [3, 4, 7, 8]);
    final (slipAt, better) = p.slip!;
    expect(slipAt, 2);
    expect(better, isNotNull);
    expect(p.slipNote(2), startsWith('The slip: '));
  });
}
