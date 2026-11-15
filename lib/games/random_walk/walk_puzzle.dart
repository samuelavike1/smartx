import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../better_bet/bet_puzzle.dart' show money;
import '../expect_it/expect_puzzle.dart' show ev;
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum WalkKind { reach, steps, fairGame, afterN, biased, drift, cliff, lazy }

/// The track on the scene card, and the rules a sample walk follows.
@immutable
class WalkScene {
  const WalkScene({
    required this.chips,
    required this.caption,
    required this.lo,
    required this.hi,
    required this.start,
    required this.up,
    required this.down,
    this.stay = Frac.zero,
    this.broke = false,
    this.cliff = false,
    this.flag = false,
    this.openLeft = false,
    this.openRight = false,
    this.money = false,
    this.fixedSteps,
  });

  final List<String> chips;
  final String caption;

  /// Positions drawn, lowest and highest.
  final int lo, hi;
  final int start;

  /// Chance of a step right, left, or staying put.
  final Frac up, down, stay;

  /// What stops the walk: a "broke" square or a cliff at [lo], a flag at
  /// [hi].
  final bool broke, cliff, flag;

  /// The track goes on past the drawn ends.
  final bool openLeft, openRight;

  /// Positions are dollars.
  final bool money;

  /// The walk runs exactly this many steps (no barriers that matter).
  final int? fixedSteps;

  bool get stopsAtLo => broke || cliff;

  /// One possible walk with these rules: positions from the start, until
  /// it stops, runs [fixedSteps], or reaches [cap] steps.
  List<int> sample(Random rng, {int cap = 80}) {
    final path = [start];
    var at = start;
    final n = fixedSteps ?? cap;
    for (var t = 0; t < n; t++) {
      if (fixedSteps == null) {
        if (stopsAtLo && at <= lo) break;
        if (flag && at >= hi) break;
      }
      final u = rng.nextDouble();
      if (u < up.value) {
        at++;
      } else if (u < up.value + down.value) {
        at--;
      }
      path.add(at);
    }
    return path;
  }
}

/// A wrong answer and the slip behind it.
@immutable
class WalkTrap {
  const WalkTrap(this.label, this.why, this.value);

  final String label;
  final String why;
  final Frac value;
}

@immutable
class WalkQuestion {
  const WalkQuestion({
    required this.level,
    required this.seed,
    required this.kind,
    required this.scene,
    required this.question,
    required this.hint,
    required this.answer,
    required this.answerValue,
    required this.traps,
    required this.options,
    required this.optionValues,
    required this.steps,
    required this.insight,
    required this.params,
  });

  final int level;
  final int seed;
  final WalkKind kind;
  final WalkScene scene;
  final String question;
  final String hint;
  final String answer;
  final Frac answerValue;
  final List<WalkTrap> traps;
  final List<String> options;
  final List<Frac> optionValues;
  final List<String> steps;
  final String insight;

  /// The numbers behind the question, for recomputing in tests.
  final Map<String, Frac> params;

  int get answerIndex => options.indexOf(answer);

  String feedbackFor(String picked) => picked == answer
      ? insight
      : traps.firstWhere((t) => t.label == picked).why;
}

class WalkDifficulty {
  static List<WalkKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [WalkKind.reach],
    2 => const [WalkKind.steps],
    3 => const [WalkKind.fairGame],
    4 => const [WalkKind.afterN],
    5 => const [WalkKind.biased],
    6 => const [WalkKind.drift],
    7 => const [WalkKind.cliff],
    8 => const [WalkKind.lazy],
    9 => const [WalkKind.reach, WalkKind.steps, WalkKind.biased],
    _ => const [
      WalkKind.fairGame,
      WalkKind.afterN,
      WalkKind.biased,
      WalkKind.drift,
      WalkKind.cliff,
      WalkKind.lazy,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'the chance of reaching the goal',
    2 => 'how long a fair walk lasts',
    3 => 'fair games keep their average',
    4 => 'where the walk is after a few steps',
    5 => 'a coin that leans one way',
    6 => 'drifting walks',
    7 => 'the walker near a cliff',
    8 => 'a walker who sometimes stays put',
    9 => 'bigger tracks',
    _ => 'any of the walks',
  };
}

class WalkGenerator {
  const WalkGenerator();

  static const _again = 'Check the numbers again: see the working.';

  WalkQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = WalkDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final big = level == 9;
    final draft = switch (kind) {
      WalkKind.reach => _reach(rng, big),
      WalkKind.steps => _steps(rng, big),
      WalkKind.fairGame => _fairGame(rng),
      WalkKind.afterN => _afterN(rng, level >= 9),
      WalkKind.biased => _biased(rng, big),
      WalkKind.drift => _drift(rng),
      WalkKind.cliff => _cliff(rng),
      WalkKind.lazy => _lazy(rng),
    };

    final a = draft.value;
    WalkTrap t(Frac v, String why) => WalkTrap(draft.format(v), why, v);
    // Above zero, and no chance above 1: an impossible option gives the
    // game away.
    bool fits(Frac v) => v > Frac.zero && (!draft.isChance || v <= Frac.one);
    final fillers = [
      for (final k in [1, 2, 3])
        for (final sign in [1, -1])
          if (fits(a + draft.unit * Frac(sign * k)))
            t(a + draft.unit * Frac(sign * k), _again),
    ]..shuffle(rng);
    final named = [
      for (final (v, why) in draft.traps)
        if (fits(v)) t(v, why),
    ];
    final chosen = balancedOptions(
      t(a, ''),
      named,
      fillers,
      rng,
      compare: (x, y) => x.value.compareTo(y.value),
    );

    return WalkQuestion(
      level: level,
      seed: seed,
      kind: kind,
      scene: draft.scene,
      question: draft.question,
      hint: draft.hint,
      answer: draft.format(a),
      answerValue: a,
      traps: [
        for (final x in chosen)
          if (x.value != a) x,
      ],
      options: [for (final x in chosen) x.label],
      optionValues: [for (final x in chosen) x.value],
      steps: draft.steps,
      insight: draft.insight,
      params: draft.params,
    );
  }

  // ---- helpers ------------------------------------------------------------

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  static final _half = Frac(1, 2);

  /// "1 path", "6 paths".
  static String _count(int n, String word) =>
      n == 1 ? '1 $word' : '$n ${word}s';

  /// "½", "⅓", "2/3" for the arrows and chips.
  static String chance(Frac f) => switch ((f.n, f.d)) {
    (1, 2) => '½',
    (1, 3) => '⅓',
    (2, 3) => '⅔',
    (1, 4) => '¼',
    (3, 4) => '¾',
    (1, 1) => '1',
    _ => '${f.n}/${f.d}',
  };

  /// A fair track from 0 to [n], starting at [a]: as money or as a walker.
  static WalkScene _track(
    int a,
    int n, {
    required bool cash,
    Frac? up,
    Frac? down,
    Frac stay = Frac.zero,
    List<String>? chips,
  }) => WalkScene(
    chips:
        chips ??
        (cash
            ? ['You have \$$a', 'Fair coin, \$1 a flip', 'Stop at \$0 or \$$n']
            : ['Start at $a', 'Ends at 0 and $n']),
    caption: up == null || up == down
        ? 'Each step: left or right, half and half'
        : 'Right ${chance(up)} · left ${chance(down!)}',
    lo: 0,
    hi: n,
    start: a,
    up: up ?? _half,
    down: down ?? _half,
    stay: stay,
    broke: true,
    flag: true,
    money: cash,
  );

  // ---- kinds --------------------------------------------------------------

  /// Fair walk: the chance of the far end first is start ÷ distance.
  _Draft _reach(Random rng, bool big) {
    final n = big ? 10 + rng.nextInt(11) : 4 + rng.nextInt(5);
    // Not right next to an end: a chance can't go below 0 or above 1, and
    // an answer squeezed against either would sit at the end of the row.
    final a = 2 + rng.nextInt(n - 3);
    final cash = rng.nextBool();
    final ans = Frac(a, n);
    final goal = cash ? '\$$n' : '$n';
    return _Draft(
      scene: _track(a, n, cash: cash),
      question: cash
          ? 'What\'s the chance you reach \$$n before going broke?'
          : 'A walker steps left or right at random. What\'s the chance '
                'they reach $n before 0?',
      hint: 'A fair game: the average stays where it started.',
      value: ans,
      // Fine steps leave room for near misses above an answer close to 1.
      unit: Frac(1, 2 * n),
      isChance: true,
      traps: [
        (_half, 'Half and half is right only from the middle.'),
        (Frac(n - a, n), 'That\'s the chance of the other end.'),
        (Frac(a, n - a), 'That\'s the odds, $a to ${n - a}, not the chance.'),
        (Frac(1, n), 'That\'s the chance from 1, not from $a.'),
      ],
      steps: [
        cash
            ? 'A fair game: your money averages \$$a at the end.'
            : 'A fair walk: its end averages where it started, $a.',
        'It ends at $goal (chance P) or at 0: P × $n = $a.',
        ev(ans) == '$a/$n' ? 'P = $a/$n.' : 'P = $a/$n = ${ev(ans)}.',
      ],
      insight: 'Right: in a fair walk, the chance is start ÷ distance.',
      params: {'a': Frac(a), 'n': Frac(n)},
    );
  }

  /// Fair walk: average steps to finish from a is a × (n − a).
  _Draft _steps(Random rng, bool big) {
    final n = big ? 10 + rng.nextInt(11) : 4 + rng.nextInt(5);
    final a = 1 + rng.nextInt(n - 1);
    final cash = rng.nextBool();
    final ans = Frac(a * (n - a));
    final what = cash ? 'flips' : 'steps';
    return _Draft(
      scene: _track(a, n, cash: cash),
      question: cash
          ? 'How many flips until you stop, on average?'
          : 'A walker steps left or right at random until they reach 0 or '
                '$n. How many steps, on average?',
      hint: 'From the middle it takes longest.',
      value: ans,
      unit: Frac(max(1, a * (n - a) ~/ 8)),
      traps: [
        (
          Frac(n - a),
          '${n - a} is the straight route to $n. The walk wanders, so it '
              'takes longer.',
        ),
        (Frac(min(a, n - a)), 'That\'s the straight route to the nearer end.'),
        (
          Frac(a * n),
          'That multiplies by $n; use the distances to each end: '
              '$a and ${n - a}.',
        ),
        if (n.isEven)
          (
            Frac(n * n, 4),
            '${n * n ~/ 4} would be from the middle, ${n ~/ 2}, '
                'not from $a.',
          ),
      ],
      steps: [
        '${cash ? 'Flips' : 'Steps'} from k: E(k) = 1 + ½E(k − 1) + '
            '½E(k + 1), with E = 0 at both ends.',
        'That is solved by E(k) = k × ($n − k).',
        'From $a: $a × ${n - a} = ${ev(ans)} $what.',
      ],
      insight:
          'Right: the distance to one end times the distance to the '
          'other.',
      params: {'a': Frac(a), 'n': Frac(n)},
    );
  }

  /// A fair game keeps its average, however you stop.
  _Draft _fairGame(Random rng) {
    final stop = rng.nextBool();
    if (stop) {
      final n = 4 + rng.nextInt(7);
      final a = 1 + rng.nextInt(n - 1);
      final ans = Frac(a);
      return _Draft(
        scene: _track(a, n, cash: true),
        question: 'How much money do you end with, on average?',
        hint: 'Every flip is fair, so the average never moves.',
        value: ans,
        unit: _half,
        format: money,
        traps: [
          (Frac(n, 2), 'Halfway between \$0 and \$$n; the start matters.'),
          (Frac(n), '\$$n is the goal; you don\'t always get there.'),
          (
            Frac(a, 2),
            'Half of \$$a would need you to lose more often than you '
                'win; the coin is fair.',
          ),
        ],
        steps: [
          'Each flip: +\$1 or −\$1, half and half: the average change is 0.',
          'Stopping at \$0 or \$$n can\'t change that.',
          'So you end with \$$a on average.',
        ],
        insight: 'Right: no stopping rule can make a fair game pay.',
        params: {'variant': Frac.zero, 'a': Frac(a), 'n': Frac(n)},
      );
    }
    final a = 10 + 5 * rng.nextInt(3);
    final k = _pick(rng, const [6, 8, 10, 12]);
    return _Draft(
      scene: WalkScene(
        chips: ['You have \$$a', 'Fair coin, \$1 a flip', '$k flips'],
        caption: 'Each step: left or right, half and half',
        lo: a - 4,
        hi: a + 4,
        start: a,
        up: _half,
        down: _half,
        openLeft: true,
        openRight: true,
        money: true,
        fixedSteps: k,
      ),
      question:
          'You play $k flips, win or lose \$1 on each. How much '
          'money do you have after, on average?',
      hint: 'Every flip is fair, so the average never moves.',
      value: Frac(a),
      unit: Frac(1),
      format: money,
      traps: [
        (
          Frac(a) + Frac(k, 2),
          'That counts the wins and forgets the '
              'losses.',
        ),
        (
          Frac(a) - Frac(k, 2),
          'That counts the losses and forgets the '
              'wins.',
        ),
        (Frac(a + k), 'That wins every flip.'),
      ],
      steps: [
        'Each flip changes your money by +\$1 or −\$1, half and half.',
        'So each flip averages \$0.',
        '\$$a + $k × \$0 = \$$a.',
      ],
      insight: 'Right: a fair game leaves your average where it started.',
      params: {'variant': Frac.one, 'a': Frac(a), 'k': Frac(k)},
    );
  }

  /// Where a fair walk is after n steps.
  _Draft _afterN(Random rng, bool long) {
    final n = long ? 4 + rng.nextInt(5) : 2 + rng.nextInt(5);
    // Ending spot: same parity as n, and not the far end (one path, the
    // smallest chance there is, would always be the first option).
    final spots = [for (var k = n % 2; k <= n - 2; k += 2) k];
    final k = _pick(rng, spots);
    final rights = (n + k) ~/ 2;
    final paths = choose(n, rights);
    final all = 1 << n;
    final ans = Frac(paths, all);
    final where = k == 0 ? 'back at the start' : '$k to the right';
    return _Draft(
      scene: WalkScene(
        chips: ['Start at 0', '$n steps'],
        caption: 'Each step: left or right, half and half',
        lo: -min(n, 5),
        hi: min(n, 5),
        start: 0,
        up: _half,
        down: _half,
        openLeft: n > 5,
        openRight: n > 5,
        fixedSteps: n,
      ),
      question:
          'After $n steps, what\'s the chance the walker is '
          '$where?',
      hint: 'Count the paths that end there.',
      value: ans,
      unit: Frac(1, 2 * all),
      isChance: true,
      traps: [
        (Frac(1, all), 'That\'s one path. Count every path that ends there.'),
        (
          Frac(1, n + 1),
          'That treats every end spot as equally likely; the middle ones '
              'have more paths.',
        ),
        if (k != 0)
          (
            Frac(paths * 2, all),
            'That\'s ending $k to the right or $k to '
                'the left.',
          )
        else
          (_half, 'Half would mean every other path comes back; fewer do.'),
      ],
      steps: [
        'There are 2^$n = $all equally likely paths.',
        k == 0
            ? 'Back at 0 needs ${_count(n ~/ 2, 'right')} and '
                  '${_count(n ~/ 2, 'left')}: C($n, ${n ~/ 2}) = '
                  '${_count(paths, 'path')}.'
            : 'Ending at $k needs ${_count(rights, 'right')} and '
                  '${_count(n - rights, 'left')}: C($n, $rights) = '
                  '${_count(paths, 'path')}.',
        '$paths/$all = ${ev(ans)}.',
      ],
      insight: 'Right: count the paths, divide by all of them.',
      params: {'n': Frac(n), 'k': Frac(k)},
    );
  }

  /// A leaning coin: the chance of the goal first.
  _Draft _biased(Random rng, bool big) {
    // Leaning either way equally often, so answers near 0 and near 1 (and
    // their squeezed options) balance out.
    // Answers within 1/8 of 0 or 1 are rerolled: there'd be no room for
    // wrong options on that side.
    Frac up, r, ans;
    int n, a;
    do {
      up = _pick(rng, [Frac(2, 3), Frac(1, 3), Frac(3, 4), Frac(1, 4)]);
      // From 3 up: on 0..2 the answer is just the one-step chance.
      n = big ? 4 + rng.nextInt(2) : 3 + rng.nextInt(2);
      a = 1 + rng.nextInt(n - 1);
      r = (Frac.one - up) / up;
      ans = (Frac.one - r.pow(a)) / (Frac.one - r.pow(n));
    } while (ans < Frac(1, 8) || ans > Frac(7, 8));
    final down = Frac.one - up;
    return _Draft(
      scene: _track(
        a,
        n,
        cash: false,
        up: up,
        down: down,
        chips: ['Start at $a', 'Right ${chance(up)} · left ${chance(down)}'],
      ),
      question:
          'The walker steps right with chance ${chance(up)}. What\'s '
          'the chance they reach $n before 0?',
      hint: 'Use the ratio left ÷ right.',
      value: ans,
      unit: Frac(1, 2 * ans.d),
      isChance: true,
      traps: [
        (Frac(a, n), '$a/$n is for a fair coin; this one leans.'),
        (
          up.pow(n - a),
          'That\'s only the straight run of ${_count(n - a, 'right')}; '
              'the walk can wander and still get there.',
        ),
        (Frac.one - ans, 'That\'s the chance of reaching 0 first.'),
        (up, 'That\'s one step right, not the whole walk.'),
      ],
      steps: [
        'Let r = left ÷ right = ${chance(down)} ÷ ${chance(up)} = ${ev(r)}.',
        'Chance of $n first from $a: (1 − r^$a) ÷ (1 − r^$n).',
        '(1 − ${ev(r.pow(a))}) ÷ (1 − ${ev(r.pow(n))}) = ${ev(ans)}.',
      ],
      insight:
          'Right: the ratio r turns the fair answer into the leaning '
          'one.',
      params: {'a': Frac(a), 'n': Frac(n), 'up': up},
    );
  }

  /// A drift moves the average a little every step.
  _Draft _drift(Random rng) {
    final variant = rng.nextInt(3);
    if (variant == 0) {
      final (up, n) = _pick(rng, [
        (Frac(2, 3), 6),
        (Frac(2, 3), 12),
        (Frac(3, 4), 8),
        (Frac(3, 4), 12),
        (Frac(3, 5), 10),
        (Frac(3, 5), 20),
      ]);
      final down = Frac.one - up;
      final ans = Frac(n) * (up - down);
      return _Draft(
        scene: WalkScene(
          chips: ['Start at 0', '$n steps', 'Right ${chance(up)}'],
          caption: 'Right ${chance(up)} · left ${chance(down)}',
          lo: -2,
          hi: 8,
          start: 0,
          up: up,
          down: down,
          openLeft: true,
          openRight: true,
          fixedSteps: n,
        ),
        question:
            'Each step goes right with chance ${chance(up)}, else '
            'left. Where is the walker after $n steps, on average?',
        hint: 'Find the average of one step first.',
        value: ans,
        unit: Frac(1),
        traps: [
          (Frac(n) * up, 'That counts the rights and forgets the lefts.'),
          (Frac(n), 'That steps right every time.'),
          (
            Frac(n) * (up - down) / Frac(2),
            'Half the drift: each step '
                'averages ${chance(up)} − ${chance(down)}, not half of it.',
          ),
        ],
        steps: [
          'One step averages ${chance(up)} × (+1) + ${chance(down)} × (−1) '
              '= ${ev(up - down)}.',
          'Averages add over steps.',
          '$n × ${ev(up - down)} = ${ev(ans)}.',
        ],
        insight: 'Right: the drift per step, times the steps.',
        params: {'variant': Frac.zero, 'up': up, 'n': Frac(n)},
      );
    }
    if (variant == 1) {
      final a = _pick(rng, const [20, 30, 50]);
      final (win, k) = _pick(rng, [
        (Frac(2, 5), 10),
        (Frac(2, 5), 20),
        (Frac(1, 3), 9),
        (Frac(1, 4), 8),
      ]);
      final lose = Frac.one - win;
      final ans = Frac(a) + Frac(k) * (win - lose);
      return _Draft(
        scene: WalkScene(
          chips: [
            'You have \$$a',
            'Win \$1 with chance ${chance(win)}',
            '$k rounds',
          ],
          caption: 'Win ${chance(win)} · lose ${chance(lose)}',
          lo: a - 6,
          hi: a + 4,
          start: a,
          up: win,
          down: lose,
          openLeft: true,
          openRight: true,
          money: true,
          fixedSteps: k,
        ),
        question:
            'Each round you win \$1 with chance ${chance(win)}, else '
            'lose \$1. After $k rounds, how much do you have on average?',
        hint: 'Find the average of one round first.',
        value: ans,
        unit: Frac(1),
        format: money,
        traps: [
          (Frac(a), 'That treats the game as fair; it leans against you.'),
          (
            Frac(a) - Frac(k) * lose,
            'That counts the losses and forgets the '
                'wins.',
          ),
          (
            Frac(a) + Frac(k) * win,
            'That counts the wins and forgets the '
                'losses.',
          ),
        ],
        steps: [
          'One round averages ${chance(win)} − ${chance(lose)} = '
              '${money(win - lose)}.',
          'Over $k rounds: $k × ${money(win - lose)} = '
              '${money(Frac(k) * (win - lose))}.',
          '\$$a ${(win - lose) < Frac.zero ? '−' : '+'} '
              '${money(Frac(k) * (lose - win))} = ${money(ans)}.',
        ],
        insight: 'Right: a small edge per round adds up.',
        params: {'variant': Frac.one, 'a': Frac(a), 'win': win, 'k': Frac(k)},
      );
    }
    final up = _pick(rng, [Frac(2, 3), Frac(3, 4)]);
    final down = Frac.one - up;
    final n = _pick(rng, const [3, 4, 5, 6]);
    final ans = Frac(n) / (up - down);
    return _Draft(
      scene: WalkScene(
        chips: ['Start at 0', 'Right ${chance(up)}', 'Flag at $n'],
        caption: 'Right ${chance(up)} · left ${chance(down)}',
        lo: -2,
        hi: n,
        start: 0,
        up: up,
        down: down,
        flag: true,
        openLeft: true,
      ),
      question:
          'Each step goes right with chance ${chance(up)}, else left. '
          'How many steps to reach $n, on average?',
      hint: 'Each step gains ${chance(up)} − ${chance(down)} on average.',
      value: ans,
      unit: Frac(1),
      traps: [
        (Frac(n), 'That steps right every time; some steps go left.'),
        (
          Frac(n) / up,
          'That counts the time to make $n rights, but the '
              'lefts undo some of them.',
        ),
        (
          Frac(n) / down,
          'That divides by the chance of a left step; divide by the '
              'gain per step, ${ev(up - down)}.',
        ),
      ],
      steps: [
        'Each step gains ${chance(up)} − ${chance(down)} = ${ev(up - down)} '
            'on average.',
        'To gain $n takes $n ÷ ${ev(up - down)} steps on average.',
        '= ${ev(ans)} steps.',
      ],
      insight: 'Right: distance ÷ drift per step.',
      params: {'variant': Frac(2), 'up': up, 'n': Frac(n)},
    );
  }

  /// Near a cliff: the chance of ever stepping off.
  _Draft _cliff(Random rng) {
    // Always leaning away: a fair walk falls for sure, and an answer of 1
    // would always be the biggest option.
    // Answers under 1/9 are rerolled: no room for options below them.
    Frac toward, away, p1, ans;
    int k;
    do {
      toward = _pick(rng, [Frac(1, 3), Frac(1, 4), Frac(2, 5)]);
      away = Frac.one - toward;
      k = 1 + rng.nextInt(3);
      p1 = toward / away;
      ans = p1.pow(k);
    } while (ans < Frac(1, 9));
    final fair = toward == away;
    return _Draft(
      scene: WalkScene(
        chips: [
          k == 1 ? '1 step from the edge' : '$k steps from the edge',
          'Away ${chance(away)} · toward ${chance(toward)}',
        ],
        caption: 'The path goes on forever to the right',
        lo: 0,
        hi: k + 4,
        start: k,
        up: away,
        down: toward,
        cliff: true,
        openRight: true,
      ),
      question: 'What\'s the chance the walker ever steps off the edge?',
      hint: k == 1
          ? 'Step away, and they must come back twice.'
          : 'To fall from $k, first get back to ${k - 1}.',
      value: ans,
      unit: Frac(1, 2 * max(4, ans.d)),
      isChance: true,
      traps: [
        (
          toward.pow(k),
          'That\'s only the straight fall; the walker can '
              'wander out and come back.',
        ),
        if (k > 1)
          (
            p1,
            'That\'s from 1 step away; from $k, each step back is a '
                'fresh fall.',
          ),
        (toward, 'That\'s one step toward the edge, not ever.'),
        if (!fair)
          (_half, 'Half and half ignores the lean away from the edge.')
        else
          (
            Frac(1, 2).pow(k),
            'With a fair walk the path always comes back: '
                'it\'s certain.',
          ),
      ],
      steps: [
        'From 1 step: fall now (${chance(toward)}), or step away '
            '(${chance(away)}) and come back twice: P = ${chance(toward)} + '
            '${chance(away)} × P².',
        fair
            ? 'With a fair walk the only answer is P = 1: it always comes '
                  'back.'
            : 'The answer below 1 is P = ${chance(toward)} ÷ ${chance(away)} '
                  '= ${ev(p1)}.',
        k == 1
            ? 'From 1 step: ${ev(ans)}.'
            : 'From $k steps: P^$k = ${ev(ans)}.',
      ],
      insight:
          'Right: from k steps, it\'s the one-step chance to the power '
          'k.',
      params: {'toward': toward, 'k': Frac(k)},
    );
  }

  /// A lazy walker: pauses slow it down but don't change who wins.
  _Draft _lazy(Random rng) {
    final stay = _pick(rng, [_half, Frac(1, 3), Frac(2, 3)]);
    final move = (Frac.one - stay) / Frac(2);
    final n = 4 + rng.nextInt(4);
    final a = 2 + rng.nextInt(n - 3);
    final steps = rng.nextBool();
    final scene = _track(
      a,
      n,
      cash: false,
      up: move,
      down: move,
      stay: stay,
      chips: ['Start at $a', 'Stays put ${chance(stay)}', 'Ends at 0 and $n'],
    );
    if (!steps) {
      final ans = Frac(a, n);
      return _Draft(
        scene: scene,
        question:
            'The walker stays put with chance ${chance(stay)}, else '
            'steps left or right. What\'s the chance they reach $n before '
            '0?',
        hint: 'A pause changes nothing about where the walk goes next.',
        value: ans,
        unit: Frac(1, 2 * n),
        isChance: true,
        traps: [
          (
            ans * (Frac.one - stay),
            'Pauses only slow the walk; they don\'t '
                'cost chances.',
          ),
          (_half, 'Half and half is right only from the middle.'),
          (Frac(n - a, n), 'That\'s the chance of the other end.'),
        ],
        steps: [
          'Leave out the pauses: what\'s left is a fair walk.',
          'A fair walk from $a reaches $n first with chance $a/$n.',
          '= ${ev(ans)}.',
        ],
        insight: 'Right: pauses change how long, never where.',
        params: {'stay': stay, 'a': Frac(a), 'n': Frac(n), 'steps': Frac.zero},
      );
    }
    final fairSteps = Frac(a * (n - a));
    final ans = fairSteps / (Frac.one - stay);
    return _Draft(
      scene: scene,
      question:
          'The walker stays put with chance ${chance(stay)}, else steps '
          'left or right. How many turns until they reach 0 or $n, on '
          'average?',
      hint: 'Each real step takes several turns on average.',
      value: ans,
      unit: Frac(1),
      traps: [
        (
          fairSteps,
          '${ev(fairSteps)} counts real steps only; pauses take '
              'turns too.',
        ),
        (
          fairSteps * (Frac.one - stay),
          'That shortens it; pauses make it '
              'longer.',
        ),
        (
          fairSteps / stay,
          'Divide by the chance of moving, '
              '${chance(Frac.one - stay)}, not of staying.',
        ),
      ],
      steps: [
        'Without pauses: $a × ${n - a} = ${ev(fairSteps)} steps.',
        'A real step comes with chance ${chance(Frac.one - stay)} each '
            'turn: ${ev(Frac.one / (Frac.one - stay))} turns per step.',
        '${ev(fairSteps)} × ${ev(Frac.one / (Frac.one - stay))} = '
            '${ev(ans)} turns.',
      ],
      insight: 'Right: same walk, stretched by the pauses.',
      params: {'stay': stay, 'a': Frac(a), 'n': Frac(n), 'steps': Frac.one},
    );
  }
}

class _Draft {
  _Draft({
    required this.scene,
    required this.question,
    required this.hint,
    required this.value,
    required this.traps,
    required this.steps,
    required this.insight,
    required this.params,
    required this.unit,
    String Function(Frac)? format,
    this.isChance = false,
  }) : format = format ?? ev;

  final WalkScene scene;
  final String question;
  final String hint;
  final Frac value;
  final List<(Frac, String)> traps;
  final List<String> steps;
  final String insight;
  final Map<String, Frac> params;

  /// The step for plain near misses.
  final Frac unit;

  /// How options are written: plain numbers, or money.
  final String Function(Frac) format;

  /// The answer is a chance: every option stays between 0 and 1.
  final bool isChance;
}
