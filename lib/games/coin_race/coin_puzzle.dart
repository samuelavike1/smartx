import 'dart:math';

import 'package:flutter/foundation.dart';

import '../odds_on/odds_math.dart';

enum CoinKind {
  /// On average, how many flips until a pattern first turns up?
  wait,

  /// Flip until A or B turns up: what's the chance A wins?
  race,

  /// A friend bets on a pattern: which one should you bet on?
  pick,
}

/// The chance of [pattern] in a row, when heads has chance [heads].
Frac chanceOf(String pattern, Frac heads) => pattern
    .split('')
    .fold(Frac.one, (f, c) => f * (c == 'H' ? heads : Frac.one - heads));

/// Lengths k where the first k flips of [x] match the last k of [y].
List<int> overlaps(String y, String x) => [
  for (var k = 1; k <= min(x.length, y.length); k++)
    if (y.substring(y.length - k) == x.substring(0, k)) k,
];

/// Average flips until [p] first turns up: for each length k where the
/// pattern's start matches its end, add 1 ÷ the chance of those k flips.
Frac waitFor(String p, Frac heads) => overlaps(
  p,
  p,
).fold(Frac.zero, (s, k) => s + Frac.one / chanceOf(p.substring(0, k), heads));

/// Conway's score for [x] then [y] on a fair coin: 2^(k−1) for each length k
/// where x's end is y's start.
int conway(String x, String y) =>
    overlaps(x, y).fold(0, (s, k) => s + (1 << (k - 1)));

/// The chance [a] turns up before [b] on a fair coin (same length).
Frac raceChance(String a, String b) {
  final forA = conway(b, b) - conway(b, a);
  final forB = conway(a, a) - conway(a, b);
  return Frac(forA, forA + forB);
}

/// Penney's reply to a 3-flip pattern: switch its middle flip and put it in
/// front of its first two.
String penney(String f) => '${f[1] == 'H' ? 'T' : 'H'}${f.substring(0, 2)}';

String flipText(Frac f) {
  if (f.d == 1) return '${f.n}';
  if (100 % f.d == 0) {
    final s = (f.n * (100 ~/ f.d) / 100).toStringAsFixed(2);
    return s.endsWith('0') ? s.substring(0, s.length - 1) : s;
  }
  return '$f';
}

/// A wrong answer and the slip behind it.
@immutable
class CoinTrap {
  const CoinTrap(this.label, this.why);

  final String label;
  final String why;
}

@immutable
class CoinQuestion {
  const CoinQuestion({
    required this.level,
    required this.seed,
    required this.kind,
    required this.patterns,
    required this.heads,
    required this.question,
    required this.caption,
    required this.answer,
    required this.traps,
    required this.steps,
    required this.insight,
    required this.options,
    required this.tried,
  });

  final int level;
  final int seed;
  final CoinKind kind;

  /// Wait: [p]. Race: [a, b]. Pick: [friend].
  final List<String> patterns;
  final Frac heads;
  final String question;
  final String caption;
  final String answer;
  final List<CoinTrap> traps;
  final List<String> steps;
  final String insight;
  final List<String> options;

  /// 1,000 simulated tries, as a reality check.
  final String tried;

  int get answerIndex => options.indexOf(answer);
  bool get fair => heads == Frac(1, 2);

  String feedbackFor(String picked) {
    if (picked == answer) return insight;
    return traps.firstWhere((t) => t.label == picked).why;
  }
}

class CoinDifficulty {
  static List<CoinKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 || 3 || 7 || 9 => const [CoinKind.wait],
    2 || 5 => const [CoinKind.race],
    4 => const [CoinKind.wait, CoinKind.race],
    6 => const [CoinKind.pick],
    8 => const [CoinKind.race, CoinKind.pick],
    _ => const [CoinKind.wait, CoinKind.race, CoinKind.pick],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'waits for two flips',
    2 => 'races of two-flip patterns',
    3 => 'waits for three flips',
    4 => 'waits and races',
    5 => 'races of three-flip patterns',
    6 => 'pick a pattern against a friend',
    7 => 'a bent coin',
    8 => 'three-flip races and picks',
    9 => 'waits for four flips',
    _ => 'any of the hard ones',
  };
}

class CoinGenerator {
  const CoinGenerator();

  CoinQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final lvl = level.clamp(1, 10);
    final kinds = CoinDifficulty.kindsFor(lvl);
    final kind = kinds[rng.nextInt(kinds.length)];
    String pattern(int n) =>
        [for (var i = 0; i < n; i++) rng.nextBool() ? 'H' : 'T'].join();
    return switch (kind) {
      CoinKind.wait => _wait(lvl, seed, rng, pattern),
      CoinKind.race => _race(lvl, seed, rng, pattern),
      CoinKind.pick => _pick(lvl, seed, rng, pattern),
    };
  }

  /// Picks three traps that differ from the answer and each other, then
  /// shuffles them in with it.
  (List<CoinTrap>, List<String>) _options(
    String answer,
    List<CoinTrap> candidates,
    Random rng,
  ) {
    final seen = {answer};
    final traps = <CoinTrap>[];
    for (final t in candidates) {
      if (traps.length == 3) break;
      if (seen.add(t.label)) traps.add(t);
    }
    assert(traps.length == 3, 'not enough traps for $answer');
    final options = [answer, ...traps.map((t) => t.label)]..shuffle(rng);
    return (traps, options);
  }

  CoinQuestion _wait(
    int lvl,
    int seed,
    Random rng,
    String Function(int) pattern,
  ) {
    final n = switch (lvl) {
      1 => 2,
      3 => 3,
      7 => 2,
      9 => 4,
      _ => 2 + rng.nextInt(2),
    };
    final heads = lvl == 7
        ? [Frac(2, 3), Frac(1, 3)][rng.nextInt(2)]
        : Frac(1, 2);
    final fair = heads == Frac(1, 2);
    final p = pattern(n);
    final ans = waitFor(p, heads);
    final naive = Frac.one / chanceOf(p, heads);
    final same = 'H' * n == p ? 'T' * n : 'H' * n;
    final sameWait = waitFor(same, heads);
    final ks = overlaps(p, p);
    final selfOverlaps = ks.length > 1;
    final coin = fair
        ? 'a fair coin'
        : 'a coin that lands heads $heads of the time';

    final candidates = [
      if (selfOverlaps)
        CoinTrap(
          flipText(naive),
          '${flipText(naive)} is 1 ÷ the chance of $p. That only works for '
          'patterns that can\'t overlap themselves; $p can.',
        )
      else
        CoinTrap(
          flipText(sameWait),
          '${flipText(sameWait)} is the wait for $same, which overlaps '
          'itself. $p doesn\'t, so a near miss is never wasted.',
        ),
      CoinTrap(
        '$n',
        '$n is just the length of $p; most tries miss before it turns up.',
      ),
      CoinTrap(
        flipText(naive * Frac(2)),
        '${flipText(naive * Frac(2))} doubles 1 ÷ the chance; overlaps only '
        'add where the start matches the end.',
      ),
      CoinTrap(
        flipText(ans + Frac(2)),
        'That adds an overlap $p doesn\'t have.',
      ),
      CoinTrap(flipText(ans + Frac(4)), 'Count the overlaps again.'),
    ];
    final answer = flipText(ans);
    final (traps, options) = _options(answer, candidates, rng);

    final matches = [
      for (final (i, k) in ks.indexed)
        'after $k${i == 0 ? (k == 1 ? ' flip' : ' flips') : ''} (${p.substring(0, k)})',
    ].join(' and ');
    final terms = ks
        .map((k) => flipText(Frac.one / chanceOf(p.substring(0, k), heads)))
        .join(' + ');
    final steps = [
      ks.length == 1
          ? '$p\'s start only matches its end at full length, after $n '
                '${n == 1 ? 'flip' : 'flips'}.'
          : 'Find where $p\'s start matches its end: $matches.',
      fair
          ? 'A match k flips long adds 2 to the power k: $terms.'
          : 'A match adds 1 ÷ the chance of its flips: $terms.',
      'So $p takes $answer flips on average.',
    ];

    // 1,000 tries.
    var total = 0;
    for (var t = 0; t < 1000; t++) {
      var seen = '';
      var flips = 0;
      while (!seen.endsWith(p)) {
        seen += rng.nextDouble() < heads.value ? 'H' : 'T';
        if (seen.length > 8) seen = seen.substring(seen.length - 8);
        flips++;
      }
      total += flips;
    }

    return CoinQuestion(
      level: lvl,
      seed: seed,
      kind: CoinKind.wait,
      patterns: [p],
      heads: heads,
      question:
          'On average, how many flips of $coin until $p first turns '
          'up?',
      caption: fair ? 'A fair coin' : 'Heads $heads of the time',
      answer: answer,
      traps: traps,
      steps: steps,
      insight: selfOverlaps
          ? 'Right: $p overlaps itself, so it takes longer than 1 ÷ its '
                'chance.'
          : 'Right: $p can\'t overlap itself, so it\'s 1 ÷ its chance.',
      options: options,
      tried: 'average ${(total / 1000).toStringAsFixed(1)} flips',
    );
  }

  static const _pairInsight = {
    'HH|TH':
        'Unless the first two flips are HH, a T comes first, and then TH '
        'always arrives before HH.',
    'HT|TT':
        'Once an H shows up, HT must come before TT. TT only wins with TT '
        'on the first two flips.',
    'HH|HT':
        'After the first H, the next flip settles it: H for HH, T for HT. '
        'Even.',
    'HT|TH':
        'Whichever flip comes first, the other one completes its pattern. '
        'Even.',
    'HH|TT': 'Mirror images on a fair coin: even.',
  };

  CoinQuestion _race(
    int lvl,
    int seed,
    Random rng,
    String Function(int) pattern,
  ) {
    final n = lvl <= 4 ? 2 : 3;
    final a = pattern(n);
    var b = pattern(n);
    while (b == a) {
      b = pattern(n);
    }
    final ans = raceChance(a, b);
    final half = Frac(1, 2);
    final wa = waitFor(a, half), wb = waitFor(b, half);
    final byWait = wb / (wa + wb);
    final candidates = [
      if (ans != half)
        CoinTrap(
          '$half',
          '1/2 assumes the same length means the same chance. Overlaps '
              'decide who gets there first.',
        ),
      CoinTrap('${Frac.one - ans}', '${Frac.one - ans} is B\'s chance.'),
      CoinTrap(
        '${chanceOf(a, half)}',
        '${chanceOf(a, half)} is the chance $a turns up in the first $n '
            'flips. The race usually runs longer.',
      ),
      CoinTrap(
        '$byWait',
        '$byWait splits by average waits, but races aren\'t decided by '
            'average waits.',
      ),
      CoinTrap(
        '${Frac(1, 3)}',
        'Score the overlaps both ways, then compare: see the working.',
      ),
      CoinTrap(
        '${Frac(2, 3)}',
        'Score the overlaps both ways, then compare: see the working.',
      ),
      CoinTrap(
        '${Frac(1, 5)}',
        'Score the overlaps both ways, then compare: see the working.',
      ),
    ];
    final answer = '$ans';
    final (traps, options) = _options(answer, candidates, rng);
    final aa = conway(a, a), ab = conway(a, b);
    final bb = conway(b, b), ba = conway(b, a);
    final key = [a, b]..sort();
    final mirror =
        key
            .map((x) => x.split('').map((c) => c == 'H' ? 'T' : 'H').join())
            .toList()
          ..sort();
    final specific =
        _pairInsight[key.join('|')] ?? _pairInsight[mirror.join('|')];

    var aWins = 0;
    for (var t = 0; t < 1000; t++) {
      var seen = '';
      while (true) {
        seen += rng.nextBool() ? 'H' : 'T';
        if (seen.endsWith(a)) {
          aWins++;
          break;
        }
        if (seen.endsWith(b)) break;
      }
    }

    return CoinQuestion(
      level: lvl,
      seed: seed,
      kind: CoinKind.race,
      patterns: [a, b],
      heads: half,
      question: 'Flip until one turns up. What\'s the chance A wins?',
      caption: 'A fair coin · first to turn up wins',
      answer: answer,
      traps: traps,
      steps: [
        'Score X→Y: add 1, 2, 4 for each length 1, 2, 3 where the end of X '
            'is the start of Y.',
        'A→A = $aa, A→B = $ab, B→B = $bb, B→A = $ba.',
        'A\'s odds are (B→B − B→A) to (A→A − A→B): ${bb - ba} to '
            '${aa - ab}, a chance of $answer.',
      ],
      insight: specific ?? 'Right: overlaps, not length, decide a race.',
      options: options,
      tried: 'A won $aWins of 1,000 races',
    );
  }

  CoinQuestion _pick(
    int lvl,
    int seed,
    Random rng,
    String Function(int) pattern,
  ) {
    final f = pattern(3);
    final best = penney(f);
    final all = [
      for (var i = 0; i < 8; i++)
        [for (var j = 2; j >= 0; j--) (i >> j) & 1 == 1 ? 'H' : 'T'].join(),
    ];
    final others = all.where((x) => x != f && x != best).toList()..shuffle(rng);
    final chance = {
      for (final x in all)
        if (x != f) x: raceChance(x, f),
    };
    final picked = <String>[];
    for (final x in others) {
      if (picked.length == 3) break;
      if (chance[x]! < chance[best]!) picked.add(x);
    }
    final candidates = [
      for (final x in picked)
        CoinTrap(
          x,
          '$x wins only ${chance[x]} of races against $f. $best wins '
          '${chance[best]}.',
        ),
    ];
    final (traps, options) = _options(best, candidates, rng);

    var wins = 0;
    for (var t = 0; t < 1000; t++) {
      var seen = '';
      while (true) {
        seen += rng.nextBool() ? 'H' : 'T';
        if (seen.endsWith(best)) {
          wins++;
          break;
        }
        if (seen.endsWith(f)) break;
      }
    }
    final mid = f[1], swapped = mid == 'H' ? 'T' : 'H';

    return CoinQuestion(
      level: lvl,
      seed: seed,
      kind: CoinKind.pick,
      patterns: [f],
      heads: Frac(1, 2),
      question:
          'Your friend bets on $f. Which pattern should you bet on to '
          'win the most races?',
      caption: 'A fair coin · first to turn up wins',
      answer: best,
      traps: traps,
      steps: [
        'Switch the middle of $f ($mid → $swapped) and put it in front of '
            'its first two: $best.',
        '$best ends with ${f.substring(0, 2)}, the start of $f, so it '
            'usually lands just as $f gets going.',
        'Against $f it wins ${chance[best]} of races.',
      ],
      insight: 'Right: $best wins ${chance[best]} of races against $f.',
      options: options,
      tried: '$best won $wins of 1,000 races',
    );
  }
}
