import 'dart:math';

import 'package:flutter/foundation.dart';

import '../odds_on/odds_math.dart';

// Better Bet: two bets, pick the one worth more on average (or Same).
// Every expected value is an exact fraction, so ties are real ties.

enum BetPick { a, same, b }

/// Something that can happen, with its exact chance and why.
@immutable
class BetEvent {
  const BetEvent(this.name, this.chance, this.why);

  /// "a 5 or a 6", "heads", "a heart".
  final String name;
  final Frac chance;

  /// "2 of 6 faces".
  final String why;
}

/// What a bet is played with.
enum BetSource {
  die('roll a die'),
  coin('flip a coin'),
  twoCoins('flip two coins'),
  card('draw a card'),
  twoDice('roll two dice');

  const BetSource(this.action);
  final String action;
}

final _events = <BetSource, List<BetEvent>>{
  BetSource.die: [
    BetEvent('a 6', Frac(1, 6), '1 of 6 faces'),
    BetEvent('a 5 or a 6', Frac(2, 6), '2 of 6 faces'),
    BetEvent('an even number', Frac(3, 6), '3 of 6 faces'),
    BetEvent('more than 2', Frac(4, 6), '4 of 6 faces'),
  ],
  BetSource.coin: [BetEvent('heads', Frac(1, 2), '1 of 2 sides')],
  BetSource.twoCoins: [
    BetEvent('two heads', Frac(1, 4), '1 of 4 outcomes'),
    BetEvent('a match', Frac(2, 4), 'HH or TT: 2 of 4 outcomes'),
    BetEvent('at least one head', Frac(3, 4), '3 of 4 outcomes'),
  ],
  BetSource.card: [
    BetEvent('an ace', Frac(4, 52), '4 of 52 cards'),
    BetEvent('a face card', Frac(12, 52), '12 of 52 cards'),
    BetEvent('a heart', Frac(13, 52), '13 of 52 cards'),
    BetEvent('a red card', Frac(26, 52), '26 of 52 cards'),
  ],
  BetSource.twoDice: [
    BetEvent('a total of 7', Frac(6, 36), '6 of 36 rolls'),
    BetEvent('a double', Frac(6, 36), '6 of 36 rolls'),
    BetEvent('a total of 9 or more', Frac(10, 36), '10 of 36 rolls'),
    BetEvent('at least one six', Frac(11, 36), '11 of 36 rolls'),
  ],
};

/// The events each source offers, for tests to recount.
@visibleForTesting
Map<BetSource, List<BetEvent>> get betEvents => _events;

/// One way a bet can pay: [amount] dollars (negative = a loss).
@immutable
class Payout {
  const Payout(this.event, this.amount);

  final BetEvent event;
  final int amount;
}

@immutable
class Bet {
  const Bet({
    required this.title,
    required this.detail,
    required this.payouts,
    this.cost = 0,
    this.working,
  });

  /// "Pay $1, roll a die".
  final String title;

  /// "Win $6 if it lands on a 5 or a 6."
  final String detail;
  final List<Payout> payouts;

  /// Paid up front to play.
  final int cost;

  /// Overrides the generated working (e.g. "faces average 3.5").
  final String? working;

  /// Expected value per go, exact.
  Frac get value =>
      payouts.fold(Frac.zero, (s, p) => s + p.event.chance * Frac(p.amount)) -
      Frac(cost);

  /// Biggest single prize.
  int get topPrize => payouts.fold(0, (m, p) => max(m, p.amount));

  /// Chance of winning something.
  Frac get winChance => payouts
      .where((p) => p.amount > 0)
      .fold(Frac.zero, (s, p) => s + p.event.chance);

  /// "a 5 or 6 is 2 of 6 faces, so 1/3 × $6 = $2, minus the $1 to play:
  /// $1 a go."
  String explain() {
    if (working != null) return working!;
    if (payouts.isEmpty) return 'Walking away is ${money(value)}.';
    if (payouts.length == 1 && payouts.single.event.chance == Frac.one) {
      return '${money(value)} for sure.';
    }
    final parts = [
      for (final p in payouts)
        '${p.event.name} is ${p.event.why}, so ${p.event.chance} × '
            '${money(Frac(p.amount))} = ${money(p.event.chance * Frac(p.amount))}',
    ];
    final cost = this.cost > 0 ? ', minus the \$${this.cost} to play' : '';
    final total = payouts.length > 1 || this.cost > 0
        ? '. Together$cost: ${money(value)} a go.'
        : ' a go.';
    return '${parts.join('; ')}$total';
  }
}

/// "$2", "$3.50", "−$0.25", "about $1.67".
String money(Frac f) {
  final neg = f.n < 0;
  final a = Frac(f.n.abs(), f.d);
  final String body;
  if (a.d == 1) {
    body = '\$${a.n}';
  } else if (100 % a.d == 0) {
    body = '\$${(a.n * (100 ~/ a.d) / 100).toStringAsFixed(2)}';
  } else {
    body = 'about \$${a.value.toStringAsFixed(2)}';
  }
  return neg
      ? (body.startsWith('about') ? 'about −${body.substring(6)}' : '−$body')
      : body;
}

@immutable
class BetQuestion {
  const BetQuestion({
    required this.level,
    required this.seed,
    required this.a,
    required this.b,
    required this.walkAway,
  });

  final int level;
  final int seed;
  final Bet a;
  final Bet b;

  /// Bet B is "walk away with $0": the question is whether A is worth it.
  final bool walkAway;

  BetPick get answer {
    final c = a.value.compareTo(b.value);
    return c > 0 ? BetPick.a : (c < 0 ? BetPick.b : BetPick.same);
  }

  String get question => walkAway
      ? 'Is it worth paying to play?'
      : 'Which bet is worth more on average?';

  /// "Working it out": one line per bet, then the verdict.
  List<String> get steps => [
    'Bet A: ${a.explain()}',
    walkAway ? 'Bet B: ${b.explain()}' : 'Bet B: ${b.explain()}',
    switch (answer) {
      BetPick.same => 'Both average ${money(a.value)}, so they\'re the same.',
      BetPick.a =>
        walkAway
            ? 'Playing averages ${money(a.value)} a go, more than walking '
                  'away, so play.'
            : 'Bet A averages more: ${money(a.value)} against '
                  '${money(b.value)}.',
      BetPick.b =>
        walkAway
            ? 'Playing averages ${money(a.value)} a go, a loss, so walk away.'
            : 'Bet B averages more: ${money(b.value)} against '
                  '${money(a.value)}.',
    },
  ];

  String get insight => walkAway
      ? 'A bet is worth paying for only when its average win beats the cost.'
      : 'Average win = chance × prize, added up, minus any cost to play.';

  /// Why a pick was wrong, naming the trap it fell into.
  String feedbackFor(BetPick pick) {
    if (pick == answer) return insight;
    String name(BetPick p) => p == BetPick.a ? 'Bet A' : 'Bet B';
    if (pick == BetPick.same) {
      return 'They\'re not equal: Bet A averages ${money(a.value)}, Bet B '
          '${money(b.value)}.';
    }
    final mine = pick == BetPick.a ? a : b;
    final other = pick == BetPick.a ? b : a;
    // Cost forgotten: without it, this pick would have been right.
    if (mine.cost > 0 && mine.value + Frac(mine.cost) > other.value) {
      return 'Don\'t forget the \$${mine.cost} it costs to play ${name(pick)}. '
          '${answer == BetPick.same ? 'That cost brings it level.' : 'That cost tips it.'}';
    }
    if (answer == BetPick.same) {
      final evens = 'it evens out: both average ${money(a.value)} a go.';
      if (mine.topPrize > other.topPrize) {
        return '${name(pick)} has the bigger prize but wins less often, and $evens';
      }
      if (mine.winChance > other.winChance) {
        return '${name(pick)} wins more often but pays less, and $evens';
      }
      return 'Both average ${money(a.value)} a go, so neither is better.';
    }
    if (mine.topPrize > other.topPrize && mine.winChance < other.winChance) {
      return '${name(pick)} has the bigger prize, but wins less often '
          '(${mine.winChance} against ${other.winChance}).';
    }
    if (mine.winChance > other.winChance && mine.topPrize < other.topPrize) {
      return '${name(pick)} wins more often, but its prizes are smaller.';
    }
    if (answer == BetPick.same) {
      return 'Both average ${money(a.value)} a go, so neither is better.';
    }
    return 'Bet A averages ${money(a.value)}, Bet B ${money(b.value)}.';
  }
}

@immutable
class BetDifficulty {
  const BetDifficulty(this.band, this.hint);

  factory BetDifficulty.forLevel(int level) =>
      _bands[(level.clamp(1, 10) - 1) ~/ 2];

  final int band;
  final String hint;

  static const _bands = [
    BetDifficulty(1, 'one prize each, free to play'),
    BetDifficulty(2, 'costs to play and sure things'),
    BetDifficulty(3, 'several prizes per bet'),
    BetDifficulty(4, 'win-or-lose bets, two dice and cards'),
    BetDifficulty(5, 'pay to play or walk away'),
  ];
}

class BetGenerator {
  const BetGenerator();

  BetQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final band = BetDifficulty.forLevel(level).band;
    final tie = rng.nextInt(6) == 0;

    if (band == 5) {
      // Pay to play, or walk away with $0.
      for (var i = 0; i < 400; i++) {
        final a = _paid(rng);
        final v = a.value;
        if (tie ? v == Frac.zero : (v != Frac.zero && v.value.abs() <= 1.5)) {
          return BetQuestion(
            level: level,
            seed: seed,
            a: a,
            b: const Bet(
              title: 'Walk away',
              detail: 'Keep your money: \$0.',
              payouts: [],
            ),
            walkAway: true,
          );
        }
      }
    }

    // Prefer pairs where the bigger prize is the worse bet (the trap).
    final wantTrap = rng.nextBool();
    final gap = [0.5, 0.5, 0.25, 0.25, 0.1][band - 1];
    BetQuestion? fallback;
    for (var i = 0; i < 600; i++) {
      final a = _bet(band, rng), b = _bet(band, rng);
      if (a.title == b.title && a.detail == b.detail) continue;
      final diff = (a.value - b.value).value.abs();
      final q = BetQuestion(
        level: level,
        seed: seed,
        a: a,
        b: b,
        walkAway: false,
      );
      if (tie) {
        if (diff == 0) return q;
        continue;
      }
      if (diff < gap) continue;
      final better = a.value.compareTo(b.value) > 0 ? a : b;
      final worse = identical(better, a) ? b : a;
      final trap = worse.topPrize > better.topPrize;
      if (trap == wantTrap) return q;
      fallback ??= q;
    }
    return fallback ??
        (throw StateError('no bet pair for band $band, seed $seed'));
  }

  BetEvent _event(BetSource s, Random rng) {
    final list = _events[s]!;
    return list[rng.nextInt(list.length)];
  }

  int _in(Random rng, int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

  String _cap(String s) => s[0].toUpperCase() + s.substring(1);

  Bet _single(BetSource s, Random rng, {int cost = 0}) {
    final e = _event(s, rng);
    final prize = _in(rng, 2, 12);
    final title = cost > 0 ? 'Pay \$$cost, ${s.action}' : _cap(s.action);
    return Bet(
      title: title,
      detail: 'Win \$$prize on ${e.name}.',
      payouts: [Payout(e, prize)],
      cost: cost,
    );
  }

  Bet _bet(int band, Random rng) {
    final simple = [
      BetSource.die,
      BetSource.coin,
      BetSource.twoCoins,
      BetSource.card,
    ];
    switch (band) {
      case 1:
        return _single(simple[rng.nextInt(simple.length)], rng);
      case 2:
        final r = rng.nextInt(4);
        if (r == 0) {
          final x = _in(rng, 1, 4);
          return Bet(
            title: 'A sure thing',
            detail: 'Take \$$x, no dice, no risk.',
            payouts: [Payout(BetEvent('certain', Frac.one, 'certain'), x)],
          );
        }
        return _single(
          simple[rng.nextInt(simple.length)],
          rng,
          cost: r == 1 ? 0 : _in(rng, 1, 3),
        );
      case 3:
        return _multi(rng);
      default:
        return rng.nextBool() ? _winLose(rng) : _multi(rng);
    }
  }

  Bet _multi(Random rng) {
    switch (rng.nextInt(3)) {
      case 0:
        final k = _in(rng, 1, 2);
        return Bet(
          title: 'Roll a die',
          detail: k == 1
              ? 'Win the number it shows, in dollars.'
              : 'Win twice the number it shows, in dollars.',
          payouts: [
            for (var f = 1; f <= 6; f++)
              Payout(BetEvent('a $f', Frac(1, 6), '1 of 6 faces'), f * k),
          ],
          working: k == 1
              ? 'the faces average (1 + 2 + … + 6) ÷ 6 = 3.5, so \$3.50 a go.'
              : 'the faces average 3.5, doubled: \$7 a go.',
        );
      case 1:
        final big = _in(rng, 6, 18), small = _in(rng, 1, 5);
        return Bet(
          title: 'Roll a die',
          detail: 'Win \$$big on a 6 and \$$small on a 4 or a 5.',
          payouts: [
            Payout(BetEvent('a 6', Frac(1, 6), '1 of 6 faces'), big),
            Payout(BetEvent('a 4 or 5', Frac(1, 3), '2 of 6 faces'), small),
          ],
        );
      default:
        final per = _in(rng, 1, 6);
        return Bet(
          title: 'Flip two coins',
          detail: 'Win \$$per for each head.',
          payouts: [
            Payout(
              BetEvent('two heads', Frac(1, 4), '1 of 4 outcomes'),
              2 * per,
            ),
            Payout(BetEvent('one head', Frac(1, 2), '2 of 4 outcomes'), per),
          ],
        );
    }
  }

  Bet _winLose(Random rng) {
    final sources = [
      BetSource.coin,
      BetSource.card,
      BetSource.twoDice,
      BetSource.twoCoins,
    ];
    final s = sources[rng.nextInt(sources.length)];
    final e = _event(s, rng);
    final win = _in(rng, 3, 20), lose = _in(rng, 1, 6);
    final miss = BetEvent(
      'anything else',
      Frac.one - e.chance,
      'the other ${_rest(e.why)}',
    );
    return Bet(
      title: _cap(s.action),
      detail: 'Win \$$win on ${e.name}, lose \$$lose otherwise.',
      payouts: [Payout(e, win), Payout(miss, -lose)],
    );
  }

  /// "2 of 6 faces" → "4 of 6 faces".
  String _rest(String why) {
    final m = RegExp(r'(\d+) of (\d+)(.*)$').firstMatch(why);
    if (m == null) return 'outcomes';
    final k = int.parse(m[1]!), n = int.parse(m[2]!);
    return '${n - k} of $n${m[3]}';
  }

  Bet _paid(Random rng) {
    final b = _oneIn3(rng)
        ? _winLose(rng)
        : _single(
            [
              BetSource.die,
              BetSource.card,
              BetSource.twoDice,
              BetSource.twoCoins,
            ][rng.nextInt(4)],
            rng,
          );
    final cost = _in(rng, 1, 6);
    return Bet(
      title: 'Pay \$$cost, ${b.title[0].toLowerCase()}${b.title.substring(1)}',
      detail: b.detail,
      payouts: b.payouts,
      cost: cost,
    );
  }

  bool _oneIn3(Random rng) => rng.nextInt(3) == 0;
}
