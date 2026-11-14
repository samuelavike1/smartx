import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/odds_on/odds_math.dart';
import 'package:smartx/games/stop_or_roll/stop_puzzle.dart';

/// Best average from scratch in doubles, by listing every roll.
double best(StopSetup s, int left, int hold) {
  if (left == 0) return hold.toDouble();
  return [
    hold.toDouble(),
    rollWorth(s, left, hold),
  ].reduce((a, b) => a > b ? a : b);
}

double rollWorth(StopSetup s, int left, int hold) {
  final faces = <int>[];
  if (s.dice.pair) {
    for (var a = 1; a <= 6; a++) {
      for (var b = 1; b <= 6; b++) {
        faces.add(a + b);
      }
    }
  } else {
    for (var f = 1; f <= s.dice.sides; f++) {
      faces.add(f);
    }
  }
  var sum = 0.0;
  for (final f in faces) {
    if (s.adding) {
      sum += s.bust.contains(f) ? 0 : best(s, left - 1, hold + f);
    } else {
      sum += best(s, left - 1, f);
    }
  }
  return sum / faces.length - s.cost;
}

StopGame scripted(StopSetup s, List<int> rolls) =>
    StopGame(level: 1, seed: 0, setup: s, rolls: rolls);

void main() {
  test('the classic values come out exactly', () {
    final one = StopValues(const StopSetup(dice: Dice(6), rolls: 4));
    expect(one.rollValue(1, 0), Frac(7, 2));
    expect(one.rollValue(2, 0), Frac(17, 4));
    expect(one.rollValue(3, 0), Frac(14, 3));
    final paid = StopValues(const StopSetup(dice: Dice(6), rolls: 3, cost: 1));
    expect(paid.rollValue(1, 0), Frac(5, 2));
    expect(paid.rollValue(2, 0), Frac(17, 6));
    final pair = StopValues(const StopSetup(dice: Dice.pair(), rolls: 2));
    expect(pair.rollValue(1, 0), Frac(7));
    final add = StopValues(
      const StopSetup(
        dice: Dice(6),
        rolls: 3,
        mode: StopMode.add,
        bust: {1, 2},
      ),
    );
    // 2/3 × 9 + (3 + 4 + 5 + 6)/6 = 9: stopping on 9 is a toss-up.
    expect(add.rollValue(1, 9), Frac(9));
    expect(add.stopFrom(1), 9);
    expect(one.rule(1), 'with 1 roll left, keep a 4 or more');
    expect(one.rule(2), 'with 2 rolls left, keep a 5 or more');
    expect(
      pair.rule(1),
      'with 1 roll left, keep an 8 or more (a 7 is a toss-up)',
    );
  });

  test('every level\'s values match a plain recount', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 12; seed++) {
        final g = StopGame.generate(level: level, seed: seed);
        final s = g.setup;
        for (var left = 1; left < s.rolls; left++) {
          for (final hold in s.adding ? [3, 7, 9, 12, 16] : [0]) {
            expect(
              g.values.rollValue(left, hold).value,
              closeTo(rollWorth(s, left, hold), 1e-9),
              reason: 'level $level, $left left, holding $hold',
            );
          }
        }
      }
    }
  });

  test('good play is always right; bad play is named', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 60; seed++) {
        var good = StopGame.generate(level: level, seed: seed);
        final s = good.setup;
        expect(good.rolls, hasLength(s.rolls));
        expect(
          s.adding
              ? s.bust.contains(good.rolls.first)
              : good.rolls.first == s.dice.top,
          isFalse,
        );
        var bad = good;
        while (!good.over) {
          final v = good.values.rollValue(good.left, good.hold);
          good = good.choose(v > Frac(good.hold) ? Choice.roll : Choice.keep);
        }
        expect(good.calls, isNotEmpty);
        expect(good.allRight, isTrue);
        expect(good.feedback(), startsWith('Every call was right: with '));
        var wrong = false;
        while (!bad.over) {
          final v = bad.values.rollValue(bad.left, bad.hold);
          final h = Frac(bad.hold);
          if (v != h) wrong = true;
          bad = bad.choose(v > h ? Choice.keep : Choice.roll);
        }
        if (wrong) {
          expect(bad.allRight, isFalse);
          expect(bad.feedback(), startsWith('You '));
        }
      }
    }
  });

  test('the board\'s game: a 4 rolled away with one roll left', () {
    var g = scripted(const StopSetup(dice: Dice(6), rolls: 3), [2, 4, 3]);
    expect(g.keepLabel, r'Keep $2');
    g = g.choose(Choice.roll);
    expect((g.face, g.left), (4, 1));
    g = g.choose(Choice.roll);
    expect(g.over, isTrue);
    expect(g.payout, 3);
    expect(g.calls.map((c) => c.right), [true, false]);
    expect(
      g.feedback(),
      'You rolled away a 4, but with 1 roll left a roll is only worth '
      r'$3.50 on average. Keep a 4 or more.',
    );
  });

  test('keeping stops on the face shown, and costs come off', () {
    var g = scripted(const StopSetup(dice: Dice(6), rolls: 3, cost: 1), [
      1,
      5,
      2,
    ]);
    g = g.choose(Choice.roll).choose(Choice.keep);
    expect(g.over, isTrue);
    expect((g.face, g.payout), (5, 4));
    expect(g.feedback(), startsWith('Every call was right: with 2 rolls left'));
  });

  test('a bust ends the game with nothing', () {
    var g = scripted(
      const StopSetup(
        dice: Dice(6),
        rolls: 4,
        mode: StopMode.add,
        bust: {1, 2},
      ),
      [5, 2, 6, 6],
    );
    expect(g.keepLabel, 'Stop at 5');
    g = g.choose(Choice.roll);
    expect(g.busted, isTrue);
    expect(g.over, isTrue);
    expect(g.payout, 0);
    expect(g.calls.single.right, isTrue);
  });
}
