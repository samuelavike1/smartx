import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../../core/game/speed_game.dart';

// Mental Math: a quick sum, four options, a time limit. Built on the
// timed-trials engine. A problem is "hard" (the engine's conflict side)
// when it needs a carry or borrow, or a hard fact; the review compares the
// two, so players see what carrying costs them.

enum MathKind {
  add,
  sub,
  table,
  mulOne,
  div,
  add3,
  sub3,
  percent,
  fractionOf,
  square,
  mulTwo,
}

@immutable
class MathTrial implements SpeedTrial<int> {
  const MathTrial({
    required this.kind,
    required this.text,
    required this.spoken,
    required this.answer,
    required this.options,
    required this.hard,
    required this.how,
  });

  final MathKind kind;

  /// As shown: "47 + 38", "25% of 64", "23²".
  final String text;

  /// For screen readers: "47 plus 38".
  final String spoken;

  @override
  final int answer;

  /// Four distinct options, smallest first.
  final List<int> options;

  /// Needs a carry, a borrow or a hard fact.
  final bool hard;

  /// The working: "Split it: 30 × 6 + 4 × 6 = 180 + 24."
  final String how;

  @override
  bool get conflict => hard;
}

@immutable
class MathDifficulty {
  const MathDifficulty(this.kinds, this.limitMs, this.hint);

  factory MathDifficulty.forLevel(int level) =>
      _bands[(level.clamp(1, 10) - 1) ~/ 2];

  final List<MathKind> kinds;

  /// Time limit per problem, in milliseconds.
  final int limitMs;

  /// For the results screen.
  final String hint;

  static const problems = 12;
  static const passMark = 10;

  static const _bands = [
    MathDifficulty(
      [MathKind.add, MathKind.sub],
      6000,
      'add and take away within 100',
    ),
    MathDifficulty(
      [MathKind.add, MathKind.sub, MathKind.table],
      5000,
      'sums within 100 and times tables',
    ),
    MathDifficulty(
      [MathKind.mulOne, MathKind.div, MathKind.add3, MathKind.sub3],
      7000,
      'two digits × one, division, three-digit sums',
    ),
    MathDifficulty(
      [MathKind.percent, MathKind.fractionOf, MathKind.square, MathKind.table],
      8000,
      'percentages, fractions of a number, squares',
    ),
    MathDifficulty(
      [MathKind.mulTwo, MathKind.percent, MathKind.square, MathKind.mulOne],
      9000,
      'two digits × two digits with a shortcut',
    ),
  ];
}

typedef MathAnswer = SpeedAnswer<int>;

@immutable
class MathBlock extends SpeedBlock<MathTrial, int> {
  const MathBlock({
    required this.level,
    required this.seed,
    required this.trials,
    required this.limit,
  });

  @override
  final int level;
  @override
  final int seed;
  @override
  final List<MathTrial> trials;

  /// Time allowed per problem.
  @override
  final Duration limit;

  @override
  int get passMark => MathDifficulty.passMark;

  @override
  MathBlock withTrials(List<MathTrial> trials) =>
      MathBlock(level: level, seed: seed, trials: trials, limit: limit);

  @override
  String get conflictName => 'Problems with a carry or a hard fact';

  @override
  String get noCostSentence => 'Carries and hard facts didn\'t slow you down.';

  @override
  String mistake(SpeedResult r, List<MathAnswer> answers) {
    final first = r.correct.indexOf(false);
    if (first < 0) return 'All $length right.';
    final t = trials[first];
    final a = first < answers.length ? answers[first] : null;
    final sum = '${t.text} = ${t.answer}.';
    return a?.tapped == null
        ? 'Problem ${first + 1} ran out of time: $sum ${t.how}'
        : 'Problem ${first + 1}: $sum ${t.how}';
  }
}

/// A problem before its options are filled in.
typedef _Draft = ({
  MathKind kind,
  String text,
  String spoken,
  int answer,
  bool hard,
  String how,
  List<int> slips,
});

class MathGenerator {
  const MathGenerator();

  MathBlock generate({required int level, required int seed}) {
    final rng = Random(seed);
    final d = MathDifficulty.forLevel(level);
    while (true) {
      final trials = [
        for (var i = 0; i < MathDifficulty.problems; i++)
          _trial(d.kinds[rng.nextInt(d.kinds.length)], rng),
      ];
      final hard = trials.where((t) => t.hard).length;
      if (hard >= 3 && trials.length - hard >= 3) {
        return MathBlock(
          level: level,
          seed: seed,
          trials: trials,
          limit: Duration(milliseconds: d.limitMs),
        );
      }
    }
  }

  /// One problem of [kind] (also used by tests).
  @visibleForTesting
  MathTrial trial(MathKind kind, Random rng) => _trial(kind, rng);

  MathTrial _trial(MathKind kind, Random rng) {
    final d = _draft(kind, rng);
    // Near misses on both sides, so the answer can sit anywhere.
    final near = [
      for (final k in const [1, 2, 3, 4, 9, 10, 11, 20]) ...[
        d.answer + k,
        d.answer - k,
      ],
    ]..shuffle(rng);
    final options = balancedOptions(
      d.answer,
      d.slips.where((s) => s > 0),
      near.where((s) => s > 0),
      rng,
      compare: (a, b) => a.compareTo(b),
    );
    return MathTrial(
      kind: d.kind,
      text: d.text,
      spoken: d.spoken,
      answer: d.answer,
      options: options,
      hard: d.hard,
      how: d.how,
    );
  }

  int _in(Random rng, int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

  _Draft _draft(MathKind kind, Random rng) => switch (kind) {
    MathKind.add => _add(rng),
    MathKind.sub => _sub(rng),
    MathKind.table => _table(rng),
    MathKind.mulOne => _mulOne(rng),
    MathKind.div => _div(rng),
    MathKind.add3 => _add3(rng),
    MathKind.sub3 => _sub3(rng),
    MathKind.percent => _percent(rng),
    MathKind.fractionOf => _fractionOf(rng),
    MathKind.square => _square(rng),
    MathKind.mulTwo => _mulTwo(rng),
  };

  _Draft _add(Random rng) {
    final a = _in(rng, 11, 79), b = _in(rng, 11, 99 - a);
    final ans = a + b;
    final ua = a % 10, ub = b % 10;
    final carry = ua + ub >= 10;
    return (
      kind: MathKind.add,
      text: '$a + $b',
      spoken: '$a plus $b',
      answer: ans,
      hard: carry,
      how: carry
          ? '$ua + $ub = ${ua + ub}: write ${(ua + ub) % 10} and carry 1 '
                'into the tens.'
          : 'Tens then units: ${a - ua} + ${b - ub} = ${a - ua + b - ub}, '
                'and $ua + $ub = ${ua + ub}.',
      slips: [if (carry) ans - 10, ans + 10, ans + 1, ans - 1],
    );
  }

  _Draft _sub(Random rng) {
    final a = _in(rng, 31, 99), b = _in(rng, 11, a - 10);
    final ans = a - b;
    final ua = a % 10, ub = b % 10;
    final borrow = ua < ub;
    // The classic slip: take the smaller digit from the bigger one.
    final noBorrow = (a ~/ 10 - b ~/ 10) * 10 + (ua - ub).abs();
    return (
      kind: MathKind.sub,
      text: '$a − $b',
      spoken: '$a minus $b',
      answer: ans,
      hard: borrow,
      how: borrow
          ? '$ua is less than $ub, so borrow a ten: ${ua + 10} − $ub = '
                '${ua + 10 - ub}. Tens: ${a ~/ 10 - 1} − ${b ~/ 10} = '
                '${a ~/ 10 - 1 - b ~/ 10}.'
          : 'Tens: ${a ~/ 10} − ${b ~/ 10} = ${a ~/ 10 - b ~/ 10}. Units: '
                '$ua − $ub = ${ua - ub}.',
      slips: [if (borrow) noBorrow, ans + 10, ans - 1, ans + 1],
    );
  }

  bool _hardFact(int a, int b) =>
      a >= 6 && b >= 6 && a != 10 && b != 10 && a != 11 && b != 11;

  _Draft _table(Random rng) {
    final a = _in(rng, 2, 12), b = _in(rng, 2, 12);
    final ans = a * b;
    final hard = _hardFact(a, b);
    return (
      kind: MathKind.table,
      text: '$a × $b',
      spoken: '$a times $b',
      answer: ans,
      hard: hard,
      how: a == 9 || b == 9
          ? 'Nines: ten times the other number, minus it once: '
                '${10 * (a == 9 ? b : a)} − ${a == 9 ? b : a} = $ans.'
          : 'If it won\'t come: $a × ${b - 1} = ${a * (b - 1)}, plus one '
                'more $a.',
      slips: [a * (b - 1), a * (b + 1), (a - 1) * b, ans + 10],
    );
  }

  _Draft _mulOne(Random rng) {
    final a = _in(rng, 12, 99), b = _in(rng, 3, 9);
    final ans = a * b;
    final ta = a - a % 10, ua = a % 10;
    final carry = ua * b >= 10;
    // Dropped carry: the tens of ua × b go missing.
    final dropped = ta * b + (ua * b) % 10;
    return (
      kind: MathKind.mulOne,
      text: '$a × $b',
      spoken: '$a times $b',
      answer: ans,
      hard: carry,
      how: 'Split it: $ta × $b + $ua × $b = ${ta * b} + ${ua * b}.',
      slips: [if (carry) dropped, ans - a, ans + a, ans + 10],
    );
  }

  _Draft _div(Random rng) {
    // Quotients from 4, so three smaller wrong answers always exist.
    final q = _in(rng, 4, 12), b = _in(rng, 2, 12);
    final a = q * b;
    return (
      kind: MathKind.div,
      text: '$a ÷ $b',
      spoken: '$a divided by $b',
      answer: q,
      hard: _hardFact(q, b),
      how: 'Think times tables: $q × $b = $a.',
      slips: [q + 1, q - 1, q + 2, q - 2],
    );
  }

  _Draft _add3(Random rng) {
    final a = _in(rng, 120, 690), b = _in(rng, 110, 990 - a);
    final ans = a + b;
    final carry = a % 10 + b % 10 >= 10 || a % 100 + b % 100 >= 100;
    final hundreds = b - b % 100;
    return (
      kind: MathKind.add3,
      text: '$a + $b',
      spoken: '$a plus $b',
      answer: ans,
      hard: carry,
      how:
          'Add in parts: $a + $hundreds = ${a + hundreds}, then + '
          '${b % 100} = $ans.',
      slips: [if (carry) ans - 10, if (carry) ans - 100, ans + 10, ans + 1],
    );
  }

  _Draft _sub3(Random rng) {
    final a = _in(rng, 320, 990), b = _in(rng, 110, a - 100);
    final ans = a - b;
    final borrow = a % 10 < b % 10 || a % 100 < b % 100;
    final hundreds = b - b % 100;
    return (
      kind: MathKind.sub3,
      text: '$a − $b',
      spoken: '$a minus $b',
      answer: ans,
      hard: borrow,
      how:
          'Take away in parts: $a − $hundreds = ${a - hundreds}, then − '
          '${b % 100} = $ans.',
      slips: [if (borrow) ans + 10, if (borrow) ans + 100, ans - 10, ans - 1],
    );
  }

  _Draft _percent(Random rng) {
    const ps = [10, 50, 25, 20, 5, 75, 15];
    final p = ps[rng.nextInt(ps.length)];
    // n keeps the answer whole: multiples of 20 (or of 4 for quarters).
    final n = p == 25 || p == 75 ? 4 * _in(rng, 6, 60) : 20 * _in(rng, 2, 25);
    final ans = n * p ~/ 100;
    final tenth = n ~/ 10;
    final how = switch (p) {
      10 => '10% is a tenth: $n ÷ 10 = $ans.',
      50 => '50% is a half: $n ÷ 2 = $ans.',
      25 => '25% is a quarter: $n ÷ 4 = $ans.',
      75 => '75% is three quarters: $n ÷ 4 = ${n ~/ 4}, × 3 = $ans.',
      20 => '20% is 10% twice: $tenth × 2 = $ans.',
      5 => '5% is half of 10%: $tenth ÷ 2 = $ans.',
      _ => '15% is 10% + 5%: $tenth + ${n ~/ 20} = $ans.',
    };
    return (
      kind: MathKind.percent,
      text: '$p% of $n',
      spoken: '$p percent of $n',
      answer: ans,
      hard: p != 10 && p != 50,
      how: how,
      // Off by 10% of n either way, or "the rest" instead of the part.
      slips: [ans + tenth, ans - tenth, n - ans],
    );
  }

  _Draft _fractionOf(Random rng) {
    const pairs = [
      (1, 3),
      (2, 3),
      (1, 4),
      (3, 4),
      (2, 5),
      (3, 5),
      (3, 8),
      (5, 8),
    ];
    final (k, d) = pairs[rng.nextInt(pairs.length)];
    final n = d * _in(rng, 3, 15);
    final part = n ~/ d;
    final ans = part * k;
    return (
      kind: MathKind.fractionOf,
      text: '$k/$d of $n',
      spoken: '${_fractionWords(k, d)} of $n',
      answer: ans,
      hard: k > 1,
      how: k == 1
          ? 'Divide by $d: $n ÷ $d = $ans.'
          : 'Divide, then multiply: $n ÷ $d = $part, × $k = $ans.',
      slips: [if (k > 1) part, n - ans, part * (k + 1), ans + 1],
    );
  }

  /// "one third", "3 quarters".
  String _fractionWords(int k, int d) {
    final (one, many) = switch (d) {
      3 => ('third', 'thirds'),
      4 => ('quarter', 'quarters'),
      5 => ('fifth', 'fifths'),
      _ => ('eighth', 'eighths'),
    };
    return k == 1 ? 'one $one' : '$k $many';
  }

  _Draft _square(Random rng) {
    final n = _in(rng, 11, 25);
    final ans = n * n;
    final t = n - n % 10, u = n % 10;
    final easy = n % 5 == 0 || n <= 12;
    final how = u == 5
        ? 'Ends in 5: ${n ~/ 10} × ${n ~/ 10 + 1} = ${(n ~/ 10) * (n ~/ 10 + 1)}, '
              'then write 25.'
        : u == 0
        ? '${n ~/ 10}² = ${(n ~/ 10) * (n ~/ 10)}, then add two zeros.'
        : 'Split it: $t² + 2 × $t × $u + $u² = ${t * t} + ${2 * t * u} + '
              '${u * u}.';
    return (
      kind: MathKind.square,
      text: '$n²',
      spoken: '$n squared',
      answer: ans,
      hard: !easy,
      how: how,
      slips: [n * (n - 1), n * (n + 1), t * t + u * u, ans + 10],
    );
  }

  _Draft _mulTwo(Random rng) {
    switch (rng.nextInt(3)) {
      case 0:
        // Either side of a round number: (m − d)(m + d) = m² − d².
        final m = 10 * _in(rng, 2, 9), d = _in(rng, 1, 4);
        final a = m - d, b = m + d, ans = a * b;
        return (
          kind: MathKind.mulTwo,
          text: '$a × $b',
          spoken: '$a times $b',
          answer: ans,
          hard: true,
          how: 'Both are $d from $m: $m² − $d² = ${m * m} − ${d * d}.',
          slips: [m * m + d * d, m * m, ans - a, ans + 10],
        );
      case 1:
        // 25 is a quarter of 100.
        final k = 4 * _in(rng, 3, 24);
        final ans = 25 * k;
        return (
          kind: MathKind.mulTwo,
          text: '25 × $k',
          spoken: '25 times $k',
          answer: ans,
          hard: true,
          how: '25 is a quarter of 100: $k ÷ 4 = ${k ~/ 4}, × 100 = $ans.',
          slips: [ans - 25, ans + 25, ans + 100, ans - 100],
        );
      default:
        // Times a teen: split off the ten.
        final a = _in(rng, 12, 39), b = _in(rng, 11, 19);
        final ans = a * b;
        return (
          kind: MathKind.mulTwo,
          text: '$a × $b',
          spoken: '$a times $b',
          answer: ans,
          hard: true,
          how:
              'Split it: $a × 10 + $a × ${b - 10} = ${a * 10} + '
              '${a * (b - 10)}.',
          slips: [ans - a, ans + a, a * 10 + (b - 10), ans + 10],
        );
    }
  }
}
