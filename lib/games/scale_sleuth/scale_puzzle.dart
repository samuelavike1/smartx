import 'dart:math';

import 'package:flutter/foundation.dart';

/// What the player is told about the fake coin.
enum Told { heavier, lighter, either }

/// Which way the balance went.
enum Tilt { left, balanced, right }

extension TiltLabel on Tilt {
  String get label => switch (this) {
    Tilt.left => 'Left heavier',
    Tilt.balanced => 'Balanced',
    Tilt.right => 'Right heavier',
  };
}

/// Coins on each pan and what the scale showed.
@immutable
class Weighing {
  const Weighing(this.left, this.right, this.tilt);

  final List<int> left;
  final List<int> right;
  final Tilt tilt;

  String get coins => '${left.join(' ')} vs ${right.join(' ')}';
}

/// The coins that could still be the fake, split by how they could be fake.
@immutable
class Suspects {
  const Suspects({required this.heavy, required this.light});

  factory Suspects.start(int coins, Told told) {
    final all = {for (var c = 1; c <= coins; c++) c};
    return Suspects(
      heavy: told == Told.lighter ? const {} : all,
      light: told == Told.heavier ? const {} : all,
    );
  }

  /// Coins that could be the fake by being heavier / lighter.
  final Set<int> heavy;
  final Set<int> light;

  Set<int> get coins => {...heavy, ...light};
  int get pairs => heavy.length + light.length;

  /// Could be either way.
  int get both => heavy.where(light.contains).length;

  Suspects after(List<int> left, List<int> right, Tilt tilt) {
    final l = left.toSet(), r = right.toSet();
    return switch (tilt) {
      Tilt.balanced => Suspects(
        heavy: {...heavy.where((c) => !l.contains(c) && !r.contains(c))},
        light: {...light.where((c) => !l.contains(c) && !r.contains(c))},
      ),
      Tilt.left => Suspects(
        heavy: {...heavy.where(l.contains)},
        light: {...light.where(r.contains)},
      ),
      Tilt.right => Suspects(
        heavy: {...heavy.where(r.contains)},
        light: {...light.where(l.contains)},
      ),
    };
  }
}

/// Answers "can this still be pinned down?" for any position, by searching
/// every weighing up to symmetry. Coins fall into four kinds (could be
/// either way, only heavier, only lighter, proven real), so a position is
/// just four counts and the number of weighings left.
class ScaleSolver {
  ScaleSolver(this.coins);

  final int coins;
  final _memo = <int, bool>{};

  bool solvable(Suspects s, int weighingsLeft) {
    final both = s.both;
    return _solvable(
      both,
      s.heavy.length - both,
      s.light.length - both,
      weighingsLeft,
    );
  }

  bool _solvable(int u, int h, int l, int k) {
    if (u + h + l <= 1) return true;
    if (k <= 0) return false;
    // Each final result names one coin, and only the coin that never touched
    // the scale can keep both of its ways in one result.
    if (2 * u + h + l > _pow3(k) + 1) return false;
    final key = ((u * 32 + h) * 32 + l) * 8 + k;
    final hit = _memo[key];
    if (hit != null) return hit;
    final ok = _plans(
      u,
      h,
      l,
    ).any((p) => p.every((o) => _solvable(o.$1, o.$2, o.$3, k - 1)));
    _memo[key] = ok;
    return ok;
  }

  /// Every weighing (as counts) with its three outcomes as (u, h, l).
  Iterable<List<(int, int, int)>> _plans(int u, int h, int l) sync* {
    for (final w in _counts(u, h, l)) {
      yield _outcomes(u, h, l, w);
    }
  }

  Iterable<_Counts> _counts(int u, int h, int l) sync* {
    final real = coins - u - h - l;
    for (var u1 = 0; u1 <= u; u1++) {
      for (var u2 = 0; u2 <= u - u1; u2++) {
        for (var h1 = 0; h1 <= h; h1++) {
          for (var h2 = 0; h2 <= h - h1; h2++) {
            for (var l1 = 0; l1 <= l; l1++) {
              for (var l2 = 0; l2 <= l - l1; l2++) {
                final a = u1 + h1 + l1, b = u2 + h2 + l2;
                if (a + b == 0 || (a - b).abs() > real) continue;
                // Mirror images weigh the same; keep one of each pair.
                if (a < b) continue;
                yield _Counts(u1, u2, h1, h2, l1, l2, (a - b).abs());
              }
            }
          }
        }
      }
    }
  }

  List<(int, int, int)> _outcomes(int u, int h, int l, _Counts w) => [
    (u - w.u1 - w.u2, h - w.h1 - w.h2, l - w.l1 - w.l2),
    (0, w.u1 + w.h1, w.u2 + w.l2),
    (0, w.u2 + w.h2, w.u1 + w.l1),
  ];

  /// A weighing that keeps [s] solvable with [weighingsLeft], using actual
  /// coin numbers, or null when there is none. Prefers the one whose worst
  /// result leaves the fewest suspects.
  Weighing? suggest(Suspects s, int weighingsLeft) {
    final both = s.both;
    final u = both, h = s.heavy.length - both, l = s.light.length - both;
    _Counts? best;
    (int, int, int)? bestScore;
    for (final w in _counts(u, h, l)) {
      final outs = _outcomes(u, h, l, w);
      if (!outs.every((o) => _solvable(o.$1, o.$2, o.$3, weighingsLeft - 1))) {
        continue;
      }
      final worst = outs.map((o) => o.$1 + o.$2 + o.$3).reduce(max);
      final score = (worst, w.u1 + w.u2 + w.h1 + w.h2 + w.l1 + w.l2, w.fill);
      if (bestScore == null ||
          score.$1 < bestScore.$1 ||
          (score.$1 == bestScore.$1 &&
              (score.$2 < bestScore.$2 ||
                  (score.$2 == bestScore.$2 && score.$3 < bestScore.$3)))) {
        best = w;
        bestScore = score;
      }
    }
    if (best == null) return null;
    final all = [for (var c = 1; c <= coins; c++) c];
    final suspects = s.coins;
    final uCoins = [
      ...all.where((c) => s.heavy.contains(c) && s.light.contains(c)),
    ];
    final hCoins = [
      ...all.where((c) => s.heavy.contains(c) && !s.light.contains(c)),
    ];
    final lCoins = [
      ...all.where((c) => s.light.contains(c) && !s.heavy.contains(c)),
    ];
    final real = [...all.where((c) => !suspects.contains(c))];
    final left = [
      ...uCoins.take(best.u1),
      ...hCoins.take(best.h1),
      ...lCoins.take(best.l1),
    ];
    final right = [
      ...uCoins.skip(best.u1).take(best.u2),
      ...hCoins.skip(best.h1).take(best.h2),
      ...lCoins.skip(best.l1).take(best.l2),
      ...real.take(best.fill),
    ];
    left.sort();
    right.sort();
    return Weighing(left, right, Tilt.balanced);
  }

  static int _pow3(int k) => k <= 0 ? 1 : 3 * _pow3(k - 1);
}

class _Counts {
  const _Counts(
    this.u1,
    this.u2,
    this.h1,
    this.h2,
    this.l1,
    this.l2,
    this.fill,
  );

  final int u1, u2, h1, h2, l1, l2;

  /// Proven-real coins added to the right pan to even the count.
  final int fill;
}

/// How many coins, weighings, and what the player is told, per level.
@immutable
class ScaleSetup {
  const ScaleSetup(this.coins, this.weighings, this.told);

  final int coins;
  final int weighings;
  final Told told;

  static ScaleSetup forLevel(int level, Random rng) {
    final lvl = level.clamp(1, 10);
    final known = rng.nextBool() ? Told.heavier : Told.lighter;
    int pick(int lo, int hi) => lo + rng.nextInt(hi - lo + 1);
    return switch (lvl) {
      1 => ScaleSetup(3, 1, known),
      2 => ScaleSetup(pick(4, 6), 2, known),
      3 => ScaleSetup(pick(7, 8), 2, known),
      4 => ScaleSetup(9, 2, known),
      5 => ScaleSetup(pick(10, 14), 3, known),
      6 => ScaleSetup(pick(15, 18), 3, known),
      7 => ScaleSetup(pick(3, 4), 2, Told.either),
      8 => ScaleSetup(pick(5, 8), 3, Told.either),
      9 => ScaleSetup(pick(9, 11), 3, Told.either),
      _ => const ScaleSetup(12, 3, Told.either),
    };
  }

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => '3 coins, one weighing',
    2 || 3 || 4 => 'up to 9 coins, two weighings',
    5 || 6 => 'up to 18 coins, three weighings',
    7 => 'heavier or lighter, not said',
    _ => 'heavier or lighter, three weighings',
  };
}

/// What happened when the player named a coin.
@immutable
class ScaleReveal {
  const ScaleReveal({
    required this.named,
    required this.fake,
    required this.heavier,
  });

  final int named;
  final int fake;
  final bool heavier;

  bool get correct => named == fake;
}

/// One puzzle in play. The fake is not fixed in advance: each weighing gets
/// the result that keeps the most coins in doubt (and exploits a weak
/// weighing), and naming a coin only wins when no other coin fits. Every
/// result shown is consistent with some fake, so the scale is fair, and only
/// a sound plan wins.
@immutable
class ScalePuzzle {
  ScalePuzzle({
    required this.level,
    required this.seed,
    required this.setup,
    this.log = const [],
    Suspects? suspects,
    ScaleSolver? solver,
  }) : suspects = suspects ?? Suspects.start(setup.coins, setup.told),
       solver = solver ?? ScaleSolver(setup.coins);

  factory ScalePuzzle.generate({required int level, required int seed}) =>
      ScalePuzzle(
        level: level,
        seed: seed,
        setup: ScaleSetup.forLevel(level, Random(seed)),
      );

  final int level;
  final int seed;
  final ScaleSetup setup;
  final List<Weighing> log;
  final Suspects suspects;
  final ScaleSolver solver;

  int get coins => setup.coins;
  int get weighingsLeft => setup.weighings - log.length;
  bool get told => setup.told != Told.either;

  String get question => switch (setup.told) {
    Told.heavier => '$coins coins. One is fake, and heavier.',
    Told.lighter => '$coins coins. One is fake, and lighter.',
    Told.either => '$coins coins. One is fake: heavier or lighter.',
  };

  /// True when coin [c] is proven real.
  bool cleared(int c) => !suspects.coins.contains(c);

  ScalePuzzle weigh(List<int> left, List<int> right) {
    assert(left.length == right.length && left.isNotEmpty);
    assert(weighingsLeft > 0);
    final rng = Random(seed * 31 + log.length * 7919 + 1);
    Tilt? pick;
    (int, int, int, int)? bestScore;
    for (final t in Tilt.values) {
      final next = suspects.after(left, right, t);
      if (next.pairs == 0) continue;
      final score = (
        solver.solvable(next, weighingsLeft - 1) ? 0 : 1,
        next.coins.length,
        next.pairs,
        rng.nextInt(1000),
      );
      if (bestScore == null || _better(score, bestScore)) {
        pick = t;
        bestScore = score;
      }
    }
    final tilt = pick!;
    return ScalePuzzle(
      level: level,
      seed: seed,
      setup: setup,
      log: [
        ...log,
        Weighing([...left]..sort(), [...right]..sort(), tilt),
      ],
      suspects: suspects.after(left, right, tilt),
      solver: solver,
    );
  }

  static bool _better((int, int, int, int) a, (int, int, int, int) b) {
    if (a.$1 != b.$1) return a.$1 > b.$1;
    if (a.$2 != b.$2) return a.$2 > b.$2;
    if (a.$3 != b.$3) return a.$3 > b.$3;
    return a.$4 > b.$4;
  }

  /// Settles the fake. Only a coin that is the sole suspect is a win.
  ScaleReveal name(int coin) {
    final rng = Random(seed * 17 + 3);
    final left = suspects.coins.toList()..sort();
    final fake = left.length == 1
        ? left.single
        : (left.where((c) => c != coin).toList()..shuffle(rng)).first;
    final h = suspects.heavy.contains(fake), l = suspects.light.contains(fake);
    return ScaleReveal(
      named: coin,
      fake: fake,
      heavier: h && l ? rng.nextBool() : h,
    );
  }

  /// The first weighing after which the fake could no longer be pinned down
  /// in time (1-based), with a weighing that would have kept it solvable.
  (int, Weighing?)? get slip {
    var s = Suspects.start(coins, setup.told);
    for (final (i, w) in log.indexed) {
      final before = s;
      s = s.after(w.left, w.right, w.tilt);
      final left = setup.weighings - i - 1;
      if (solver.solvable(before, left + 1) && !solver.solvable(s, left)) {
        return (i + 1, solver.suggest(before, left + 1));
      }
    }
    return null;
  }

  /// Suspects left after weighing [n] (1-based), and weighings to go then.
  (int, int) suspectsAfter(int n) {
    var s = Suspects.start(coins, setup.told);
    for (final w in log.take(n)) {
      s = s.after(w.left, w.right, w.tilt);
    }
    return (s.coins.length, setup.weighings - n);
  }

  /// The rose note under the weighing that lost the puzzle.
  String slipNote(int n) {
    final (count, togo) = suspectsAfter(n);
    final rest = switch (togo) {
      0 => 'and no weighings to go',
      1 => 'for 1 weighing',
      _ => 'for $togo weighings',
    };
    return 'The slip: $count suspects left $rest';
  }

  String feedbackFor(ScaleReveal r) {
    final way = r.heavier ? 'heavier' : 'lighter';
    if (r.correct) {
      final used = log.length;
      return 'Only coin ${r.fake} fits every weighing: it\'s the fake, and '
          '$way. Found in $used ${used == 1 ? 'weighing' : 'weighings'}.';
    }
    final fits = suspects.coins.toList()..sort();
    if (fits.length == 1) {
      return 'Only coin ${r.fake} fits what the scale showed: it was the '
          'fake, and $way.';
    }
    final who = switch (fits.length) {
      2 => 'Coins ${_list(fits)} both fit',
      <= 4 => 'Coins ${_list(fits)} all fit',
      _ => '${fits.length} coins still fit',
    };
    final head = '$who; the fake was ${r.fake}, $way.';
    final s = slip;
    if (s != null && s.$2 != null) {
      return '$head Each weighing has three results, so leave each a third '
          'of the suspects. Weighing ${s.$1} could have been '
          '${s.$2!.coins}.';
    }
    if (weighingsLeft > 0) {
      return '$head You had $weighingsLeft '
          '${weighingsLeft == 1 ? 'weighing' : 'weighings'} left to split them.';
    }
    return head;
  }

  static String _list(List<int> xs) => xs.length == 1
      ? '${xs.single}'
      : '${xs.take(xs.length - 1).join(', ')} and ${xs.last}';
}
