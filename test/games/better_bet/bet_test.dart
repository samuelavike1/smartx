import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/better_bet/bet_puzzle.dart';
import 'package:smartx/games/odds_on/odds_math.dart';

/// Every way each source can land, and which events each outcome hits.
Frac recount(BetSource s, String event) {
  final outcomes = <bool Function(String)>[];
  switch (s) {
    case BetSource.die:
      for (var f = 1; f <= 6; f++) {
        outcomes.add(
          (e) => switch (e) {
            'a 6' => f == 6,
            'a 5 or a 6' => f >= 5,
            'an even number' => f.isEven,
            'more than 2' => f > 2,
            _ => throw ArgumentError(e),
          },
        );
      }
    case BetSource.coin:
      for (final h in [true, false]) {
        outcomes.add((e) => e == 'heads' && h);
      }
    case BetSource.twoCoins:
      for (final a in [true, false]) {
        for (final b in [true, false]) {
          outcomes.add(
            (e) => switch (e) {
              'two heads' => a && b,
              'a match' => a == b,
              'at least one head' => a || b,
              _ => throw ArgumentError(e),
            },
          );
        }
      }
    case BetSource.card:
      // 4 suits (0 = hearts, 1 = diamonds: red) × 13 ranks (0 = ace,
      // 10–12 = jack, queen, king).
      for (var suit = 0; suit < 4; suit++) {
        for (var rank = 0; rank < 13; rank++) {
          outcomes.add(
            (e) => switch (e) {
              'an ace' => rank == 0,
              'a face card' => rank >= 10,
              'a heart' => suit == 0,
              'a red card' => suit <= 1,
              _ => throw ArgumentError(e),
            },
          );
        }
      }
    case BetSource.twoDice:
      for (var a = 1; a <= 6; a++) {
        for (var b = 1; b <= 6; b++) {
          outcomes.add(
            (e) => switch (e) {
              'a total of 7' => a + b == 7,
              'a double' => a == b,
              'a total of 9 or more' => a + b >= 9,
              'at least one six' => a == 6 || b == 6,
              _ => throw ArgumentError(e),
            },
          );
        }
      }
  }
  return Frac(outcomes.where((hit) => hit(event)).length, outcomes.length);
}

void main() {
  const gen = BetGenerator();

  test('every event\'s chance matches a full recount', () {
    for (final MapEntry(key: source, value: events) in betEvents.entries) {
      for (final e in events) {
        expect(
          e.chance,
          recount(source, e.name),
          reason: '${source.name}: ${e.name}',
        );
      }
    }
  });

  test('money reads naturally', () {
    expect(money(Frac(2)), '\$2');
    expect(money(Frac(7, 2)), '\$3.50');
    expect(money(Frac(-1, 4)), '−\$0.25');
    expect(money(Frac(5, 3)), 'about \$1.67');
    expect(money(Frac.zero), '\$0');
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level questions are fair and exact', () {
      var ties = 0;
      for (var seed = 0; seed < 150; seed++) {
        final q = gen.generate(level: level, seed: seed);
        for (final bet in [q.a, q.b]) {
          // Independent arithmetic in doubles.
          final ev =
              bet.payouts.fold<double>(
                0,
                (s, p) => s + p.event.chance.value * p.amount,
              ) -
              bet.cost;
          expect(bet.value.value, closeTo(ev, 1e-9), reason: bet.detail);
          final total = bet.payouts.fold(
            Frac.zero,
            (s, p) => s + p.event.chance,
          );
          expect(total <= Frac.one, isTrue, reason: bet.detail);
          expect(bet.explain(), isNotEmpty);
        }
        final c = q.a.value.compareTo(q.b.value);
        expect(
          q.answer,
          c > 0 ? BetPick.a : (c < 0 ? BetPick.b : BetPick.same),
        );
        if (q.answer == BetPick.same) ties++;
        expect(q.steps, hasLength(3));
        for (final pick in BetPick.values) {
          expect(q.feedbackFor(pick), isNotEmpty);
        }
        expect(q.walkAway, level >= 9);
      }
      // Real ties turn up, but stay the exception.
      expect(ties, inInclusiveRange(5, 60), reason: 'ties at level $level');
    });
  }

  test('a forgotten cost is named as the trap', () {
    final die = betEvents[BetSource.die]!.firstWhere(
      (e) => e.name == 'a 5 or a 6',
    );
    final coin = betEvents[BetSource.coin]!.single;
    final q = BetQuestion(
      level: 3,
      seed: 0,
      a: Bet(
        title: 'Pay \$1, roll a die',
        detail: '',
        payouts: [Payout(die, 6)],
        cost: 1,
      ),
      b: Bet(title: 'Flip a coin', detail: '', payouts: [Payout(coin, 2)]),
      walkAway: false,
    );
    expect(q.answer, BetPick.same);
    expect(q.feedbackFor(BetPick.a), contains('costs to play Bet A'));
    expect(q.steps.last, 'Both average \$1, so they\'re the same.');
  });

  test('the bigger prize that wins less often is named as the trap', () {
    final six = betEvents[BetSource.die]!.firstWhere((e) => e.name == 'a 6');
    final even = betEvents[BetSource.die]!.firstWhere(
      (e) => e.name == 'an even number',
    );
    final q = BetQuestion(
      level: 1,
      seed: 0,
      a: Bet(title: 'Roll a die', detail: '', payouts: [Payout(six, 9)]),
      b: Bet(title: 'Roll a die', detail: '', payouts: [Payout(even, 4)]),
      walkAway: false,
    );
    expect(q.answer, BetPick.b);
    expect(q.feedbackFor(BetPick.a), startsWith('Bet A has the bigger prize'));
  });

  test('a wrong pick on a tie says the bets even out', () {
    final heads = betEvents[BetSource.coin]!.single;
    final fiveSix = betEvents[BetSource.die]!.firstWhere(
      (e) => e.name == 'a 5 or a 6',
    );
    final q = BetQuestion(
      level: 1,
      seed: 0,
      a: Bet(title: 'Flip a coin', detail: '', payouts: [Payout(heads, 8)]),
      b: Bet(title: 'Roll a die', detail: '', payouts: [Payout(fiveSix, 12)]),
      walkAway: false,
    );
    expect(q.answer, BetPick.same);
    expect(
      q.feedbackFor(BetPick.a),
      'Bet A wins more often but pays less, and it evens out: both average '
      '\$4 a go.',
    );
    expect(
      q.feedbackFor(BetPick.b),
      'Bet B has the bigger prize but wins less often, and it evens out: '
      'both average \$4 a go.',
    );
  });
}
