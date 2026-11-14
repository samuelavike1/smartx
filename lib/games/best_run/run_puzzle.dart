import 'dart:math';

import 'package:flutter/foundation.dart';

enum RunMode {
  /// Daily profits: pick the stretch of days with the biggest total.
  bars,

  /// Daily prices: buy one day, sell on a later one.
  prices,
}

/// "+12", "−3", "0".
String signed(int v) => v > 0 ? '+$v' : (v < 0 ? '−${-v}' : '0');

/// "+$12", "−$3".
String signedMoney(int v) => v >= 0 ? '+\$$v' : '−\$${-v}';

/// "day 7" or "days 3–8" (1-based, from 0-based indexes).
String daysText(int s, int e) =>
    s == e ? 'day ${s + 1}' : 'days ${s + 1}–${e + 1}';

String daysTitle(int s, int e) =>
    s == e ? 'Day ${s + 1}' : 'Days ${s + 1}–${e + 1}';

class RunDifficulty {
  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => '6 days, one clear dip',
    2 => 'a few more days',
    3 => 'a big day next to a big loss',
    4 => 'ten days',
    5 => 'worth crossing a small loss',
    6 => 'not worth crossing a big one',
    7 => 'two good stretches',
    8 => 'two weeks',
    9 => 'buy once, sell once',
    _ => 'buy and sell over two weeks',
  };
}

@immutable
class RunPuzzle {
  const RunPuzzle({
    required this.level,
    required this.seed,
    required this.mode,
    required this.values,
  });

  final int level;
  final int seed;
  final RunMode mode;

  /// Daily profit (bars) or price (prices).
  final List<int> values;

  int get days => values.length;
  bool get prices => mode == RunMode.prices;

  /// What picking days [s] to [e] makes: their total, or sell − buy.
  int valueOf(int s, int e) {
    if (prices) return values[e] - values[s];
    var t = 0;
    for (var i = s; i <= e; i++) {
      t += values[i];
    }
    return t;
  }

  /// Every choice that can be locked in.
  Iterable<(int, int)> get choices sync* {
    for (var s = 0; s < days; s++) {
      for (var e = prices ? s + 1 : s; e < days; e++) {
        yield (s, e);
      }
    }
  }

  int get best => choices.map((c) => valueOf(c.$1, c.$2)).reduce(max);

  List<(int, int)> get bestChoices => [
    for (final c in choices)
      if (valueOf(c.$1, c.$2) == best) c,
  ];

  /// The best choice shown in the review (the shortest, then the earliest).
  (int, int) get bestChoice {
    final all = bestChoices
      ..sort((a, b) {
        final la = a.$2 - a.$1, lb = b.$2 - b.$1;
        return la != lb ? la.compareTo(lb) : a.$1.compareTo(b.$1);
      });
    return all.first;
  }

  bool isBest(int s, int e) => valueOf(s, e) == best;

  /// Under each day. Bars: the running total, which starts again after it
  /// falls to zero or below. Prices: that day's price minus the lowest
  /// price up to then.
  List<int> get running {
    final out = <int>[];
    if (prices) {
      var low = values.first;
      for (final p in values) {
        low = min(low, p);
        out.add(p - low);
      }
      return out;
    }
    var r = 0;
    for (final v in values) {
      r = (r > 0 ? r : 0) + v;
      out.add(r);
    }
    return out;
  }

  /// Days where the running total starts again.
  Set<int> get restarts {
    final r = running;
    return {
      for (var i = 1; i < days; i++)
        if (!prices && r[i - 1] <= 0) i,
    };
  }

  String get title => prices ? 'Buy once, sell once' : 'Find the best run';

  String get question => prices
      ? 'A share\'s price over $days days. Buy one day, sell on a later one. '
            'What\'s the most you can make?'
      : 'A stall\'s profit for $days days. Which stretch of days in a row '
            'made the most?';

  String choiceText(int s, int e) => prices
      ? 'Buy day ${s + 1} at \$${values[s]}, sell day ${e + 1} at '
            '\$${values[e]} · ${signedMoney(valueOf(s, e))}'
      : '${daysTitle(s, e)} · ${signed(valueOf(s, e))}';

  List<String> get steps {
    final (s, e) = bestChoice;
    if (prices) {
      return [
        'Under each day: its price minus the lowest price up to then.',
        'The biggest is ${signedMoney(best)} on day ${e + 1}; the low before '
            'it was \$${values[s]} on day ${s + 1}.',
        'So buy day ${s + 1} at \$${values[s]} and sell day ${e + 1} at '
            '\$${values[e]}.',
      ];
    }
    return [
      'Under the bars: a running total that starts over when it drops below '
          'zero.',
      s == 0
          ? 'It never needs to start again before day ${e + 1}, where it '
                'peaks at ${signed(best)}.'
          : 'It starts again on day ${s + 1} and peaks at ${signed(best)} on '
                'day ${e + 1}.',
      'So the best run is ${daysText(s, e)}: ${signed(best)}.',
    ];
  }

  String feedbackFor(int s, int e) {
    final (bs, be) = bestChoice;
    if (prices) return _priceFeedback(s, e, bs, be);
    if (isBest(s, e)) {
      return '${daysTitle(s, e)} make ${signed(best)}, the most of any run. '
          'A running total that starts again below zero finds it.';
    }
    final top = values.reduce(max);
    if (s == e && values[s] == top) {
      return 'The biggest day isn\'t the best run: ${daysText(bs, be)} make '
          '${signed(best)}.';
    }
    final mine = valueOf(s, e);
    final bestText = 'Best: ${daysText(bs, be)}, ${signed(best)}.';
    if (s >= bs && e <= be) {
      final left = s > bs ? valueOf(bs, s - 1) : 0;
      final right = e < be ? valueOf(e + 1, be) : 0;
      if (s == bs) {
        final rest = [for (var i = e + 1; i <= be; i++) values[i]];
        final dip = rest.where((x) => x < 0).map(signed).toList();
        final gain = rest.where((x) => x > 0).map(signed).toList();
        final payback = dip.isEmpty
            ? ''
            : ' The ${dip.join(' and ')} ${dip.length == 1 ? 'is' : 'are'} '
                  'paid back by the ${gain.join(' and ')}.';
        return 'Stopped too soon: ${daysText(e + 1, be)} '
            '${e + 1 == be ? 'adds' : 'add'} ${signed(right)} more.$payback';
      }
      if (e == be) {
        return 'Started too late: ${daysText(bs, s - 1)} '
            '${bs == s - 1 ? 'adds' : 'add'} ${signed(left)} more. $bestText';
      }
      return 'Too short at both ends. $bestText';
    }
    if (s <= bs && e >= be) {
      final cost = mine - best;
      final parts = [if (s < bs) (s, bs - 1), if (e > be) (be + 1, e)];
      final extra = parts.map((x) => daysText(x.$1, x.$2)).join(' and ');
      final one = parts.length == 1 && parts.single.$1 == parts.single.$2;
      return 'Trim it: $extra ${one ? 'costs' : 'cost'} ${signed(cost)}. '
          '$bestText';
    }
    return 'The best run is ${daysText(bs, be)}: ${signed(best)}. Yours made '
        '${signed(mine)}.';
  }

  String _priceFeedback(int b, int s, int bb, int bs) {
    final p = values;
    if (isBest(b, s)) {
      return 'Buy day ${b + 1}, sell day ${s + 1}: ${signedMoney(best)}, the '
          'most possible. Track the lowest price so far.';
    }
    final bestText =
        'Best: buy day ${bb + 1} at \$${p[bb]}, sell day ${bs + 1} at '
        '\$${p[bs]}: ${signedMoney(best)}.';
    final low = p.reduce(min);
    if (p[b] == low && b > bs) {
      return 'The lowest price, day ${b + 1}, comes too late: there\'s little '
          'to sell into after it. $bestText';
    }
    if (b == bb) {
      return 'Right day to buy, but day ${bs + 1} sold higher. $bestText';
    }
    if (s == bs) {
      return 'Right day to sell, but day ${bb + 1} was cheaper before it. '
          '$bestText';
    }
    return '$bestText Yours made ${signedMoney(valueOf(b, s))}.';
  }
}

class RunGenerator {
  const RunGenerator();

  RunPuzzle generate({required int level, required int seed}) {
    final rng = Random(seed);
    final lvl = level.clamp(1, 10);
    int pick(int lo, int hi) => lo + rng.nextInt(hi - lo + 1);
    final n = switch (lvl) {
      1 => 6,
      2 => pick(7, 8),
      3 => 8,
      4 => pick(9, 10),
      5 => 10,
      6 => pick(11, 12),
      7 => pick(12, 13),
      8 => 14,
      9 => pick(9, 11),
      _ => pick(12, 14),
    };
    final mode = lvl >= 9 ? RunMode.prices : RunMode.bars;
    RunPuzzle? fallback;
    for (var tries = 0; tries < 20000; tries++) {
      final values = mode == RunMode.prices
          ? _walk(rng, n)
          : [
              for (var i = 0; i < n; i++)
                (rng.nextBool() ? 1 : -1) * pick(1, 9),
            ];
      final p = RunPuzzle(level: level, seed: seed, mode: mode, values: values);
      if (!_basic(p)) continue;
      fallback ??= p;
      if (fits(p, lvl)) return p;
    }
    return fallback!;
  }

  /// A price path that wanders between $5 and $40.
  List<int> _walk(Random rng, int n) {
    final out = [12 + rng.nextInt(16)];
    while (out.length < n) {
      final step = (rng.nextBool() ? 1 : -1) * (1 + rng.nextInt(7));
      out.add((out.last + step).clamp(5, 40));
    }
    return out;
  }

  /// One clear answer that's more than one day and less than everything.
  bool _basic(RunPuzzle p) {
    if (p.best <= 0 || p.bestChoices.length != 1) return false;
    final (s, e) = p.bestChoice;
    if (p.prices) return true;
    return e > s && !(s == 0 && e == p.days - 1);
  }

  /// Each level's twist.
  @visibleForTesting
  static bool fits(RunPuzzle p, int level) {
    final v = p.values;
    final (s, e) = p.bestChoice;
    bool inside(int i) => i >= s && i <= e;
    final negInside = [for (var i = s; i <= e; i++) v[i]].any((x) => x < 0);
    final top = v.indexOf(v.reduce(max));
    final low = v.indexOf(v.reduce(min));
    final negatives = v.where((x) => x < 0).length;
    switch (level.clamp(1, 10)) {
      case 1:
        return negatives >= 1 && negatives <= 2;
      case 2:
        return negatives >= 2 && negatives <= 3;
      case 3:
        // The biggest day sits outside the best run.
        return !inside(top);
      case 4:
        return negInside;
      case 5:
        // Crossing a small loss pays.
        return negInside &&
            [for (var i = s; i <= e; i++) v[i]]
                .where((x) => x < 0)
                .every((x) => x >= -4);
      case 6:
        // The worst day sits right next to the best run: crossing it doesn't
        // pay.
        return low == s - 1 || low == e + 1;
      case 7:
        // A second, separate stretch nearly as good.
        return p.choices.any(
          (c) =>
              (c.$2 < s - 1 || c.$1 > e + 1) &&
              p.valueOf(c.$1, c.$2) >= p.best - 3,
        );
      case 8:
        return negInside && !inside(top);
      case 9:
        // The lowest price comes after the highest.
        return low > top && s != low;
      default:
        return low > top && s != low && e != top;
    }
  }
}
