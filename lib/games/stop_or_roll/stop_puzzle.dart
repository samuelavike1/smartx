import 'dart:math';

import 'package:flutter/foundation.dart';

import '../better_bet/bet_puzzle.dart' show money;
import '../odds_on/odds_math.dart';

/// What gets rolled: one die with [sides] faces, or two six-sided dice added.
@immutable
class Dice {
  const Dice(this.sides) : count = 1;
  const Dice.pair() : sides = 6, count = 2;

  final int sides;
  final int count;

  bool get pair => count == 2;
  int get top => sides * count;

  /// Each result and how many of the equally likely ways give it.
  Map<int, int> get ways {
    if (!pair) return {for (var f = 1; f <= sides; f++) f: 1};
    final m = <int, int>{};
    for (var a = 1; a <= 6; a++) {
      for (var b = 1; b <= 6; b++) {
        m[a + b] = (m[a + b] ?? 0) + 1;
      }
    }
    return m;
  }

  int get outcomes => pair ? 36 : sides;

  String get name => pair
      ? 'two dice'
      : (sides == 6 ? 'a die' : '${_a(sides)} $sides-sided die');

  int roll(Random rng) =>
      pair ? 2 + rng.nextInt(6) + rng.nextInt(6) : 1 + rng.nextInt(sides);
}

/// "a 4", "an 8", "an 11", "an 18".
String _a(int n) =>
    (n == 8 || n == 11 || n == 18 || (n >= 80 && n < 90)) ? 'an' : 'a';

String withArticle(int n) => '${_a(n)} $n';

enum StopMode {
  /// Keep one roll: win its face.
  keep,

  /// Roll and add up; a bust face loses the lot.
  add,
}

@immutable
class StopSetup {
  const StopSetup({
    required this.dice,
    required this.rolls,
    this.mode = StopMode.keep,
    this.cost = 0,
    this.bust = const {},
  });

  final Dice dice;

  /// Rolls in all, the first one free.
  final int rolls;
  final StopMode mode;

  /// Dollars to pay for each roll after the first (keep games).
  final int cost;

  /// Faces that lose everything (add games).
  final Set<int> bust;

  bool get adding => mode == StopMode.add;

  String get rules {
    if (adding) {
      final b = (bust.toList()..sort()).join(' or ');
      return 'Roll ${dice.name} up to $rolls times and add them up. '
          'A $b loses it all.';
    }
    final pay = cost == 0 ? '' : ' Each roll after the first costs \$$cost.';
    final win = dice.pair
        ? 'Win their total, in dollars, on the roll you keep.'
        : (dice.sides == 6
              ? 'Win \$1 a pip on the roll you keep.'
              : 'Win the number you keep, in dollars.');
    return 'Roll ${dice.name} up to $rolls times. $win$pay';
  }

  static StopSetup forLevel(int level, Random rng) {
    T pick<T>(List<T> xs) => xs[rng.nextInt(xs.length)];
    return switch (level.clamp(1, 10)) {
      1 => const StopSetup(dice: Dice(6), rolls: 2),
      2 => const StopSetup(dice: Dice(6), rolls: 3),
      3 => const StopSetup(dice: Dice(6), rolls: 3, cost: 1),
      4 => StopSetup(dice: Dice(pick([8, 12])), rolls: 3),
      5 => StopSetup(dice: const Dice(6), rolls: pick([4, 5])),
      6 => StopSetup(dice: const Dice.pair(), rolls: pick([2, 3])),
      7 => StopSetup(
        dice: Dice(pick([10, 12, 20])),
        rolls: pick([3, 4]),
        cost: pick([1, 2]),
      ),
      final l => StopSetup(
        dice: const Dice(6),
        rolls: l - 5,
        mode: StopMode.add,
        bust: const {1, 2},
      ),
    };
  }

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'one die, two rolls',
    2 => 'one die, three rolls',
    3 => 'a cost to roll again',
    4 => 'bigger dice',
    5 => 'more rolls',
    6 => 'two dice added',
    7 => 'big dice, a cost to roll',
    _ => 'roll and add; a 1 or 2 busts',
  };
}

/// Exact values by working backwards from the last roll.
class StopValues {
  StopValues(this.setup);

  final StopSetup setup;
  final _memo = <(int, int), Frac>{};

  /// What rolling again is worth on average, with [left] rolls still to
  /// come (counting this one), holding [hold] (a face, or a running total).
  /// Keep games ignore [hold]: what's been paid is gone either way.
  Frac rollValue(int left, int hold) {
    assert(left >= 1);
    final key = (left, setup.adding ? hold : 0);
    final hit = _memo[key];
    if (hit != null) return hit;
    final d = setup.dice;
    var sum = Frac.zero;
    for (final MapEntry(key: r, value: w) in d.ways.entries) {
      final Frac after;
      if (setup.adding) {
        after = setup.bust.contains(r) ? Frac.zero : value(left - 1, hold + r);
      } else {
        after = value(left - 1, r);
      }
      sum = sum + after * Frac(w, d.outcomes);
    }
    final v = sum - Frac(setup.cost);
    _memo[key] = v;
    return v;
  }

  /// Best average from holding [hold] with [left] rolls to come.
  Frac value(int left, int hold) {
    final h = Frac(hold);
    if (left == 0) return h;
    final r = rollValue(left, hold);
    return r > h ? r : h;
  }

  /// Keep games: the smallest face worth keeping outright, and whether some
  /// face is exactly a toss-up.
  (int, int?) keepFrom(int left) {
    final c = rollValue(left, 0);
    final faces = setup.dice.ways.keys.toList()..sort();
    final above = faces.firstWhere((f) => Frac(f) > c);
    final tie = faces.where((f) => Frac(f) == c).firstOrNull;
    return (above, tie);
  }

  /// Add games: the smallest total worth stopping on.
  int stopFrom(int left) {
    for (var t = 1; t < 500; t++) {
      if (Frac(t) >= rollValue(left, t)) return t;
    }
    return 500;
  }

  /// "with 2 rolls left, keep a 5 or more", or after the first clause of a
  /// list, the [short] "with 1 left, a 4 or more".
  String rule(int left, {bool short = false}) {
    final rolls = short ? '$left' : (left == 1 ? '1 roll' : '$left rolls');
    if (setup.adding) {
      final verb = short ? '' : 'stop once you have ';
      return 'with $rolls left, $verb${stopFrom(left)} or more';
    }
    final (above, tie) = keepFrom(left);
    final toss = tie == null ? '' : ' (${withArticle(tie)} is a toss-up)';
    return 'with $rolls left, ${short ? '' : 'keep '}'
        '${withArticle(above)} or more$toss';
  }
}

enum Choice { keep, roll }

/// One decision: what was held, how many rolls were left, what the player
/// chose, and what each option was worth.
@immutable
class Call {
  const Call({
    required this.face,
    required this.hold,
    required this.left,
    required this.choice,
    required this.rollWorth,
  });

  /// The roll just made.
  final int face;

  /// What stopping now pays (face, or running total).
  final int hold;
  final int left;
  final Choice choice;
  final Frac rollWorth;

  Frac get holdWorth => Frac(hold);
  bool get tie => rollWorth == holdWorth;
  Choice get best => rollWorth > holdWorth ? Choice.roll : Choice.keep;
  bool get right => tie || choice == best;
}

/// One game in play: the rolls are fixed by the seed, the calls are the
/// player's.
@immutable
class StopGame {
  StopGame({
    required this.level,
    required this.seed,
    required this.setup,
    required this.rolls,
    this.calls = const [],
    StopValues? values,
  }) : values = values ?? StopValues(setup);

  factory StopGame.generate({required int level, required int seed}) {
    final rng = Random(seed);
    final setup = StopSetup.forLevel(level, rng);
    final d = setup.dice;
    final rolls = <int>[];
    // The first roll leaves a real call: never the top face, never a bust.
    do {
      rolls
        ..clear()
        ..addAll([for (var i = 0; i < setup.rolls; i++) d.roll(rng)]);
    } while (setup.adding
        ? setup.bust.contains(rolls.first)
        : rolls.first == d.top);
    return StopGame(level: level, seed: seed, setup: setup, rolls: rolls);
  }

  final int level;
  final int seed;
  final StopSetup setup;
  final List<int> rolls;
  final List<Call> calls;
  final StopValues values;

  bool get stopped => calls.isNotEmpty && calls.last.choice == Choice.keep;

  /// Index of the roll on show: the kept one after a Keep.
  int get shown => stopped ? calls.length - 1 : calls.length;
  int get face => rolls[shown];

  /// Rolls still to come after the one on show.
  int get left => setup.rolls - 1 - shown;

  bool get busted =>
      setup.adding && rolls.take(shown + 1).any(setup.bust.contains);

  /// Running total (add games) or the face on show (keep games).
  int get hold {
    if (!setup.adding) return face;
    if (busted) return 0;
    return rolls.take(shown + 1).fold(0, (s, r) => s + r);
  }

  bool get over => busted || left == 0 || stopped;

  bool get allRight => calls.every((c) => c.right);

  /// First wrong call, if any.
  Call? get slip => calls.where((c) => !c.right).firstOrNull;

  /// Dollars won: the hold, less what was paid to roll again.
  int get payout => hold - setup.cost * shown;
  StopGame choose(Choice c) {
    assert(!over);
    return StopGame(
      level: level,
      seed: seed,
      setup: setup,
      rolls: rolls,
      values: values,
      calls: [
        ...calls,
        Call(
          face: face,
          hold: hold,
          left: left,
          choice: c,
          rollWorth: values.rollValue(left, hold),
        ),
      ],
    );
  }

  String get keepLabel => setup.adding ? 'Stop at $hold' : 'Keep \$$hold';

  String get rollLabel =>
      setup.cost == 0 ? 'Roll again' : 'Roll again · \$${setup.cost}';

  String feedback() {
    final s = slip;
    if (s == null) {
      final lefts = {for (final c in calls) c.left}.toList()
        ..sort((a, b) => b.compareTo(a));
      final rules = [
        for (final (i, l) in lefts.indexed) values.rule(l, short: i > 0),
      ];
      return 'Every call was right: ${rules.join('; ')}.';
    }
    final worth = money(s.rollWorth);
    final paid = setup.cost == 0 ? '' : ', after the \$${setup.cost}';
    final rolls = s.left == 1 ? '1 roll' : '${s.left} rolls';
    final rule = values.rule(s.left);
    final ruleTail = rule.substring(rule.indexOf(', ') + 2);
    final r = ruleTail[0].toUpperCase() + ruleTail.substring(1);
    if (setup.adding) {
      return s.choice == Choice.keep
          ? 'You stopped on ${s.hold}, but with $rolls left rolling on is '
                'worth $worth on average. $r.'
          : 'You rolled on from ${s.hold}, but with $rolls left that was only '
                'worth $worth on average. $r.';
    }
    return s.choice == Choice.keep
        ? 'You kept ${withArticle(s.face)}, but with $rolls left a roll is '
              'worth $worth on average$paid. $r.'
        : 'You rolled away ${withArticle(s.face)}, but with $rolls left a '
              'roll is only worth $worth on average$paid. $r.';
  }
}
