import 'dart:math';

import 'package:flutter/foundation.dart';

/// How many floors [eggs] eggs and [drops] drops can always settle:
/// f(e, d) = f(e − 1, d − 1) + f(e, d − 1) + 1. The first drop splits the
/// building into the floors below it (settled by the other eggs if it
/// breaks), the floor itself, and the floors above (if it survives).
int floorsSettled(int eggs, int drops) {
  if (eggs <= 0 || drops <= 0) return 0;
  var row = List<int>.filled(eggs + 1, 0);
  for (var d = 1; d <= drops; d++) {
    final next = List<int>.filled(eggs + 1, 0);
    for (var e = 1; e <= eggs; e++) {
      next[e] = row[e - 1] + row[e] + 1;
    }
    row = next;
  }
  return row[eggs];
}

/// The fewest drops that always settle [floors] floors with [eggs] eggs, or
/// null when there are floors to settle and no eggs to do it.
int? dropsNeeded(int eggs, int floors) {
  if (floors <= 0) return 0;
  if (eggs <= 0) return null;
  var d = 1;
  while (floorsSettled(eggs, d) < floors) {
    d++;
  }
  return d;
}

/// A drop that keeps the floor in reach: the highest floor whose break the
/// other eggs can still settle. [lo]..[hi] are the floors that could still be
/// the highest safe one. Null when the position is already lost or settled.
int? keepInReach(int lo, int hi, int eggs, int drops) {
  if (lo >= hi) return null;
  final need = dropsNeeded(eggs, hi - lo);
  if (need == null || need > drops) return null;
  return min(lo + floorsSettled(eggs - 1, drops - 1) + 1, hi);
}

/// One drop and what the egg did.
@immutable
class EggDrop {
  const EggDrop(this.floor, {required this.broke});

  final int floor;
  final bool broke;
}

/// Eggs, floors and the drop budget for one round.
@immutable
class EggSetup {
  const EggSetup._(this.eggs, this.floors, this.drops);

  /// The budget is the best possible worst case.
  factory EggSetup.of(int eggs, int floors) =>
      EggSetup._(eggs, floors, dropsNeeded(eggs, floors)!);

  final int eggs;
  final int floors;
  final int drops;

  /// Setups whose budget is exactly tight: one more floor needs one more
  /// drop. Level 10 picks from these.
  static const tight = [(2, 21), (2, 28), (3, 14), (3, 25), (2, 36), (3, 41)];

  static EggSetup forLevel(int level, Random rng) {
    int pick(int lo, int hi) => lo + rng.nextInt(hi - lo + 1);
    return switch (level.clamp(1, 10)) {
      1 => EggSetup.of(1, pick(4, 6)),
      2 => EggSetup.of(2, pick(6, 10)),
      3 => EggSetup.of(2, pick(11, 15)),
      4 => EggSetup.of(2, pick(20, 21)),
      5 => EggSetup.of(2, pick(27, 28)),
      6 => EggSetup.of(3, pick(13, 14)),
      7 => EggSetup.of(3, pick(24, 25)),
      8 => EggSetup.of(2, pick(35, 36)),
      9 => EggSetup.of(3, pick(40, 41)),
      _ => () {
        final (e, f) = tight[rng.nextInt(tight.length)];
        return EggSetup.of(e, f);
      }(),
    };
  }

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'one egg, 4–6 floors',
    2 => 'two eggs, 6–10 floors',
    3 => 'two eggs, 11–15 floors',
    4 => 'two eggs, 20–21 floors',
    5 => 'two eggs, 27–28 floors',
    6 => 'three eggs, 13–14 floors',
    7 => 'three eggs, 24–25 floors',
    8 => 'two eggs, 35–36 floors',
    9 => 'three eggs, 40–41 floors',
    _ => 'two or three eggs, a tight budget',
  };
}

/// One round in play. The highest safe floor isn't fixed in advance: each
/// drop gets the answer (break or survive) that leaves the player needing
/// more drops, and every answer fits all the earlier ones, so the building is
/// fair and only a sound plan wins.
@immutable
class EggPuzzle {
  EggPuzzle({
    required this.level,
    required this.seed,
    required this.setup,
    this.log = const [],
    this.lo = 0,
    int? hi,
  }) : hi = hi ?? setup.floors;

  factory EggPuzzle.generate({required int level, required int seed}) =>
      EggPuzzle(
        level: level,
        seed: seed,
        setup: EggSetup.forLevel(level, Random(seed)),
      );

  final int level;
  final int seed;
  final EggSetup setup;
  final List<EggDrop> log;

  /// The highest safe floor is somewhere in [lo]..[hi] (0 means none).
  final int lo;
  final int hi;

  int get floors => setup.floors;
  int get eggs => setup.eggs;
  int get budget => setup.drops;
  int get eggsLeft => eggs - log.where((d) => d.broke).length;
  int get dropsLeft => budget - log.length;

  bool get settled => lo == hi;
  bool get outOfEggs => !settled && eggsLeft == 0;
  bool get outOfDrops => !settled && eggsLeft > 0 && dropsLeft == 0;
  bool get over => settled || eggsLeft == 0 || dropsLeft == 0;
  bool get won => settled;

  /// A drop from [floor] would still tell the player something.
  bool canDrop(int floor) => !over && floor > lo && floor <= hi;

  /// Known safe (at or below the lowest possible answer).
  bool safe(int floor) => floor <= lo;

  /// Can the floor still be pinned down with best play from here?
  bool get inReach => _inReach(lo, hi, eggsLeft, dropsLeft);

  static bool _inReach(int lo, int hi, int eggs, int drops) {
    final need = dropsNeeded(eggs, hi - lo);
    return need != null && need <= drops;
  }

  String get question =>
      '$floors floors, $eggs ${eggs == 1 ? 'egg' : 'eggs'}, $budget drops. '
      'A broken egg is gone.';

  String get range => rangeText(lo, hi);

  static String rangeText(int lo, int hi) => switch (hi - lo) {
    0 => '$lo',
    1 => '$lo or $hi',
    _ => '$lo to $hi',
  };

  EggPuzzle drop(int floor) {
    assert(canDrop(floor));
    final rng = Random(seed * 31 + log.length * 7919 + 1);
    // Break: the answer is below, with one egg fewer. Survive: at or above.
    final breakNeed = dropsNeeded(eggsLeft - 1, floor - 1 - lo) ?? 1 << 20;
    final surviveNeed = dropsNeeded(eggsLeft, hi - floor) ?? 1 << 20;
    final bool broke;
    if (breakNeed != surviveNeed) {
      broke = breakNeed > surviveNeed;
    } else if (floor - lo != hi - floor + 1) {
      // Same drops either way: leave more floors in doubt.
      broke = floor - lo > hi - floor + 1;
    } else {
      broke = rng.nextBool();
    }
    return EggPuzzle(
      level: level,
      seed: seed,
      setup: setup,
      log: [
        ...log,
        EggDrop(floor, broke: broke),
      ],
      lo: broke ? lo : floor,
      hi: broke ? floor - 1 : hi,
    );
  }

  /// The state (lo, hi, eggs, drops left) before drop [n] (1-based), or
  /// after the last drop when [n] is past the end.
  (int, int, int, int) before(int n) {
    var l = 0, h = floors, e = eggs;
    for (final d in log.take(n - 1)) {
      if (d.broke) {
        h = d.floor - 1;
        e--;
      } else {
        l = d.floor;
      }
    }
    return (l, h, e, budget - min(n - 1, log.length));
  }

  /// The first drop after which the floor was out of reach (1-based), with
  /// a floor that would have kept it in reach.
  (int, int)? get slip {
    for (var n = 1; n <= log.length; n++) {
      final (l, h, e, d) = before(n);
      final (l2, h2, e2, d2) = before(n + 1);
      if (_inReach(l, h, e, d) && !_inReach(l2, h2, e2, d2)) {
        return (n, keepInReach(l, h, e, d)!);
      }
    }
    return null;
  }

  /// The rose note under the drop that lost the round.
  String slipNote(int n) {
    final (l, h, e, d) = before(n + 1);
    return 'The slip: ${rangeText(l, h)} left for ${_eggs(e)} and '
        '${_drops(d)}';
  }

  /// The best first drop for this setup.
  int get bestStart => keepInReach(0, floors, eggs, budget)!;

  /// Best play's floors while every egg survives.
  List<int> get climb {
    final out = <int>[];
    var x = 0;
    for (var d = budget; d > 0 && x < floors; d--) {
      x = min(x + floorsSettled(eggs - 1, d - 1) + 1, floors);
      out.add(x);
    }
    return out;
  }

  /// Three short steps for the best first drop.
  List<String> get steps {
    final f = floorsSettled(eggs, budget);
    final start = bestStart;
    final seq = climb.join(', ');
    if (eggs == 1) {
      return [
        'With one egg, a break ends the tests, so no floor can be skipped.',
        'Start at floor 1 and go up one floor at a time: $seq.',
        'At worst every floor gets a drop: $floors floors need $floors drops.',
      ];
    }
    final below = floorsSettled(eggs - 1, budget - 1);
    final above = floorsSettled(eggs, budget - 1);
    final fit = f == floors
        ? 'just enough'
        : 'enough for $floors (${budget - 1} drops settle only $above)';
    if (eggs == 2) {
      final sum = [for (var d = budget; d >= 1; d--) '$d'].join(' + ');
      return [
        'If the first egg breaks, the last one must go floor by floor with '
            '${budget - 1} drops left, so start at floor $start.',
        'Each time it survives, a drop is gone, so climb one floor less: '
            '$seq.',
        '$sum = $f floors: $fit.',
      ];
    }
    return [
      'If the first egg breaks, ${eggs - 1} eggs and ${budget - 1} drops are '
          'left. They settle $below floors, so start at floor $start.',
      'Each time it survives, climb 1 more than the eggs could settle below: '
          '$seq.',
      '$below below + floor ${below + 1} + $above above = $f floors in '
          '$budget drops: $fit.',
    ];
  }

  String get feedback {
    final used = log.length;
    if (won) {
      final found = 'Found in $used of $budget drops.';
      return lo == 0
          ? 'No floor is safe: the egg breaks even from floor 1. $found'
          : 'The highest safe floor is $lo. $found';
    }
    final head = outOfEggs ? 'Out of eggs' : 'Out of drops';
    final fits = hi - lo > 1 ? 'anything from $lo to $hi' : range;
    final text = '$head: it could still be $fits.';
    final s = slip;
    if (s == null) return text;
    final (n, better) = s;
    final d = log[n - 1];
    final (l, h, e, left) = before(n + 1);
    return '$text Drop $n ${d.broke ? 'broke' : 'survived'} at floor '
        '${d.floor} and left ${_eggs(e)} and ${_drops(left)} for '
        '${rangeText(l, h)}; floor $better would have kept it in reach.';
  }

  static String _eggs(int n) => switch (n) {
    0 => 'no eggs',
    1 => '1 egg',
    _ => '$n eggs',
  };

  static String _drops(int n) => switch (n) {
    0 => 'no drops',
    1 => '1 drop',
    _ => '$n drops',
  };
}
