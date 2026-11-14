import 'dart:math';

import 'package:material_ui/material_ui.dart';

import 'odds_math.dart';

// Odds On: a probability question with an exact answer, four options and a
// worked solution. Questions are generated from a seed; wrong options come
// from the classic slips, each with a sentence that names the slip.

enum BallColour {
  red('red', Color(0xFFE11D48), Color(0xFFFF3D63)),
  blue('blue', Color(0xFF2563EB), Color(0xFF6C9BFF)),
  green('green', Color(0xFF2E8B3E), Color(0xFF4CC26B));

  const BallColour(this.word, this.color, this.nightColor);
  final String word;
  final Color color;
  final Color nightColor;

  Color shade({required bool night}) => night ? nightColor : color;
}

/// What the picture above the question shows.
@immutable
class OddsScene {
  const OddsScene({
    required this.label,
    this.dice = 0,
    this.coins = 0,
    this.deck = false,
    this.balls = const [],
    this.test = false,
  });

  /// Caption: "Two fair dice".
  final String label;
  final int dice;
  final int coins;
  final bool deck;
  final List<(BallColour, int)> balls;

  /// A medical-style test (Bayes questions).
  final bool test;
}

/// The question families, kept for tests and the near-miss text.
enum OddsKind {
  dieEvent,
  twoCoins,
  cardDraw,
  diceTotal,
  doubles,
  threeCoins,
  bagDraw,
  atLeastOneSix,
  bothSameColour,
  oneOfEach,
  atLeastOneHead,
  twoHearts,
  givenTotal,
  givenASix,
  threeDiceDifferent,
  bayesTest,
  whichCoin,
  takingTurns,
}

@immutable
class OddsQuestion {
  const OddsQuestion({
    required this.level,
    required this.seed,
    required this.kind,
    required this.scene,
    required this.question,
    required this.short,
    required this.answer,
    required this.options,
    required this.steps,
    required this.insight,
    required this.slips,
    required this.params,
  });

  final int level;
  final int seed;
  final OddsKind kind;
  final OddsScene scene;

  /// The full question: "Roll both. What is the chance the total is 8?"
  final String question;

  /// One line for the review: "Two fair dice: chance the total is 8?"
  final String short;
  final Frac answer;

  /// Four distinct options, smallest first.
  final List<Frac> options;

  /// "Working it out", in order. The last step states the answer.
  final List<String> steps;

  /// The idea to take away, shown after a right answer.
  final String insight;

  /// Why each wrong option is tempting, by value.
  final Map<Frac, String> slips;

  /// The numbers the question was built from (for tests).
  final Map<String, int> params;

  int get answerIndex => options.indexOf(answer);

  /// Feedback after picking [option].
  String feedbackFor(Frac option) => option == answer
      ? insight
      : (slips[option] ??
            'That doesn\'t match the count. The right answer is $answer, '
                '${answer.percent}.');
}

@immutable
class OddsDifficulty {
  const OddsDifficulty(this.band, this.kinds, this.hint);

  factory OddsDifficulty.forLevel(int level) =>
      _bands[((level.clamp(1, 10) - 1) ~/ 2)];

  final int band;
  final List<OddsKind> kinds;

  /// For the results screen: what this level asks.
  final String hint;

  static const _bands = [
    OddsDifficulty(1, [
      OddsKind.dieEvent,
      OddsKind.twoCoins,
      OddsKind.cardDraw,
    ], 'one die, two coins or one card'),
    OddsDifficulty(2, [
      OddsKind.diceTotal,
      OddsKind.doubles,
      OddsKind.threeCoins,
      OddsKind.bagDraw,
    ], 'two dice, three coins, a bag of balls'),
    OddsDifficulty(3, [
      OddsKind.atLeastOneSix,
      OddsKind.bothSameColour,
      OddsKind.oneOfEach,
      OddsKind.atLeastOneHead,
      OddsKind.twoHearts,
    ], '"at least one" and drawing without replacement'),
    OddsDifficulty(4, [
      OddsKind.givenTotal,
      OddsKind.givenASix,
      OddsKind.threeDiceDifferent,
      OddsKind.bothSameColour,
    ], '"given that…" and three dice'),
    OddsDifficulty(5, [
      OddsKind.bayesTest,
      OddsKind.whichCoin,
      OddsKind.takingTurns,
      OddsKind.givenASix,
    ], 'Bayes and taking turns'),
  ];
}

/// What a template produces before the options are filled in.
class _Draft {
  _Draft({
    required this.kind,
    required this.scene,
    required this.question,
    required this.short,
    required this.answer,
    required this.steps,
    required this.insight,
    required this.slips,
    this.params = const {},
  });

  final OddsKind kind;
  final OddsScene scene;
  final String question;
  final String short;
  final Frac answer;
  final List<String> steps;
  final String insight;
  final List<(Frac, String)> slips;
  final Map<String, int> params;
}

const _numberWords = [
  'zero',
  'one',
  'two',
  'three',
  'four',
  'five',
  'six',
  'seven',
  'eight',
  'nine',
  'ten',
];

String _cap(String s) => s[0].toUpperCase() + s.substring(1);
String _num(int n) => n < _numberWords.length ? _numberWords[n] : '$n';

class OddsGenerator {
  const OddsGenerator();

  OddsQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final d = OddsDifficulty.forLevel(level);
    final kind = d.kinds[rng.nextInt(d.kinds.length)];
    final draft = _draft(kind, rng);
    return _finish(draft, level: level, seed: seed, rng: rng);
  }

  /// Builds one question of [kind] (also used by tests).
  @visibleForTesting
  OddsQuestion generateKind(OddsKind kind, {required int seed, int level = 1}) {
    final rng = Random(seed);
    return _finish(_draft(kind, rng), level: level, seed: seed, rng: rng);
  }

  OddsQuestion _finish(
    _Draft draft, {
    required int level,
    required int seed,
    required Random rng,
  }) {
    final answer = draft.answer;
    final slips = <Frac, String>{};
    for (final (value, why) in draft.slips) {
      if (value != answer && value.isProbability && !slips.containsKey(value)) {
        slips[value] = why;
      }
      if (slips.length == 3) break;
    }
    // Fill up with near misses of the right size.
    final near = <Frac>[
      Frac(answer.n + 1, answer.d),
      Frac(max(1, answer.n - 1), answer.d),
      answer * Frac(2),
      answer * Frac(1, 2),
      Frac.one - answer,
      Frac(answer.n, answer.d + 1),
      Frac(answer.n + 1, answer.d + 1),
      Frac(answer.n + 2, answer.d + 2),
    ]..shuffle(rng);
    final options = <Frac>{answer, ...slips.keys};
    for (final f in near) {
      if (options.length == 4) break;
      if (f.isProbability && f != Frac.one) options.add(f);
    }
    return OddsQuestion(
      level: level,
      seed: seed,
      kind: draft.kind,
      scene: draft.scene,
      question: draft.question,
      short: draft.short,
      answer: answer,
      options: options.toList()..sort(),
      steps: draft.steps,
      insight: draft.insight,
      slips: {
        for (final o in options)
          if (slips.containsKey(o)) o: slips[o]!,
      },
      params: draft.params,
    );
  }

  _Draft _draft(OddsKind kind, Random rng) => switch (kind) {
    OddsKind.dieEvent => _dieEvent(rng),
    OddsKind.twoCoins => _twoCoins(rng),
    OddsKind.cardDraw => _cardDraw(rng),
    OddsKind.diceTotal => _diceTotal(rng),
    OddsKind.doubles => _doubles(),
    OddsKind.threeCoins => _threeCoins(rng),
    OddsKind.bagDraw => _bagDraw(rng),
    OddsKind.atLeastOneSix => _atLeastOneSix(rng),
    OddsKind.bothSameColour => _bothSameColour(rng),
    OddsKind.oneOfEach => _oneOfEach(rng),
    OddsKind.atLeastOneHead => _atLeastOneHead(rng),
    OddsKind.twoHearts => _twoHearts(),
    OddsKind.givenTotal => _givenTotal(rng),
    OddsKind.givenASix => _givenASix(),
    OddsKind.threeDiceDifferent => _threeDiceDifferent(),
    OddsKind.bayesTest => _bayesTest(rng),
    OddsKind.whichCoin => _whichCoin(rng),
    OddsKind.takingTurns => _takingTurns(rng),
  };

  // ── Band 1 ──────────────────────────────────────────────────────────

  _Draft _dieEvent(Random rng) {
    final events = <(String, List<int>)>[
      ('an even number', [2, 4, 6]),
      ('a number above 4', [5, 6]),
      ('a number above 2', [3, 4, 5, 6]),
      ('a prime number', [2, 3, 5]),
      ('a multiple of 3', [3, 6]),
      ('a 6', [6]),
    ];
    final (what, faces) = events[rng.nextInt(events.length)];
    final c = faces.length;
    final ans = Frac(c, 6);
    return _Draft(
      kind: OddsKind.dieEvent,
      scene: const OddsScene(label: 'One fair die', dice: 1),
      question: 'Roll it once. What is the chance of $what?',
      short: 'One die: chance of $what?',
      answer: ans,
      steps: [
        'A die has 6 faces, all equally likely.',
        '${_cap(what)}: ${faces.join(', ')}. That is $c '
            '${c == 1 ? 'face' : 'faces'}.',
        'So the chance is $c/6 = $ans, ${ans.percent}.',
      ],
      insight: 'Count the faces you want, out of 6 equally likely faces.',
      slips: [
        (Frac(6 - c, 6), '${Frac(6 - c, 6)} is the chance of NOT getting it.'),
        if (c < 5) (Frac(c, 5), 'A die has 6 faces, not 5.'),
        if (c > 1) (Frac(1, 6), 'That is one face. $c faces work here.'),
      ],
      params: {'count': c},
    );
  }

  _Draft _twoCoins(Random rng) {
    final which = rng.nextInt(3);
    final (what, ans, list, slips) = switch (which) {
      0 => (
        'exactly one head',
        Frac(2, 4),
        'HT and TH',
        [
          (
            Frac(1, 3),
            'HT and TH are different outcomes, so there are 4 outcomes, not 3.',
          ),
          (Frac(1, 4), 'Exactly one head happens two ways: HT and TH.'),
        ],
      ),
      1 => (
        'two heads',
        Frac(1, 4),
        'HH',
        [
          (Frac(1, 2), 'That is one coin. Both must land heads: 1/2 × 1/2.'),
          (Frac(1, 3), 'There are 4 equally likely outcomes, not 3.'),
        ],
      ),
      _ => (
        'at least one head',
        Frac(3, 4),
        'HH, HT and TH',
        [
          (Frac(1, 2), 'That is one coin. Two coins give more chances.'),
          (Frac(2, 3), 'There are 4 equally likely outcomes, not 3.'),
        ],
      ),
    };
    return _Draft(
      kind: OddsKind.twoCoins,
      scene: const OddsScene(label: 'Two fair coins', coins: 2),
      question: 'Flip both. What is the chance of $what?',
      short: 'Two coins: chance of $what?',
      answer: ans,
      steps: [
        'Two coins give 4 equally likely outcomes: HH, HT, TH, TT.',
        '${_cap(what)}: $list.',
        'So the chance is $ans, ${ans.percent}.',
      ],
      insight: 'List every outcome. HT and TH count as two.',
      slips: slips,
      params: {'which': which},
    );
  }

  _Draft _cardDraw(Random rng) {
    final events = <(String, int, String, List<(Frac, String)>)>[
      (
        'a heart',
        13,
        'There are 13 hearts.',
        [(Frac(1, 13), 'That is the chance of one rank, like an ace.')],
      ),
      (
        'an ace',
        4,
        'There are 4 aces.',
        [(Frac(1, 4), 'That is the chance of one suit, like hearts.')],
      ),
      (
        'a face card (jack, queen or king)',
        12,
        'There are 3 face cards in each of 4 suits: 12.',
        [(Frac(16, 52), 'Aces aren\'t face cards: only jacks, queens, kings.')],
      ),
      (
        'a red king',
        2,
        'There are 2 red kings: hearts and diamonds.',
        [(Frac(1, 13), 'That is any king. Only 2 of the 4 are red.')],
      ),
      (
        'a heart or a king',
        16,
        '13 hearts plus 3 more kings (the king of hearts is already counted): 16.',
        [
          (
            Frac(17, 52),
            'The king of hearts was counted twice: once as a heart, once as a king.',
          ),
        ],
      ),
    ];
    final (what, c, why, slips) = events[rng.nextInt(events.length)];
    final ans = Frac(c, 52);
    return _Draft(
      kind: OddsKind.cardDraw,
      scene: const OddsScene(label: 'A shuffled deck of 52', deck: true),
      question: 'Draw one card. What is the chance it is $what?',
      short: 'One card: chance of $what?',
      answer: ans,
      steps: [
        'A deck has 52 cards, each equally likely.',
        why,
        'So the chance is $c/52 = $ans, ${ans.percent}.',
      ],
      insight: 'Count the cards that work, out of 52. Don\'t count any twice.',
      slips: [
        ...slips,
        (Frac(c, 54), 'A standard deck has 52 cards, no jokers.'),
      ],
      params: {'count': c},
    );
  }

  // ── Band 2 ──────────────────────────────────────────────────────────

  _Draft _diceTotal(Random rng) {
    final total = 3 + rng.nextInt(9); // 3..11
    final pairs = [
      for (var a = 1; a <= 6; a++)
        for (var b = 1; b <= 6; b++)
          if (a + b == total) '$a+$b',
    ];
    final ways = pairs.length;
    final unordered =
        (ways + (total.isEven && total >= 2 && total <= 12 ? 1 : 0)) ~/ 2;
    final ans = Frac(ways, 36);
    return _Draft(
      kind: OddsKind.diceTotal,
      scene: const OddsScene(label: 'Two fair dice', dice: 2),
      question: 'Roll both. What is the chance the total is $total?',
      short: 'Two dice: chance the total is $total?',
      answer: ans,
      steps: [
        'Two dice give 6 × 6 = 36 equally likely outcomes.',
        'A total of $total comes from ${pairs.join(', ')}: $ways '
            '${ways == 1 ? 'way' : 'ways'}.',
        'So the chance is $ways/36 = $ans, ${ans.percent}.',
      ],
      insight: 'Count ordered pairs: 3+5 and 5+3 are different rolls.',
      slips: [
        if (total != 7)
          (
            Frac(1, 6),
            '1/6 is the chance of a total of 7, the most likely total.',
          ),
        (
          Frac(1, 11),
          'There are 11 possible totals, but they are not equally likely.',
        ),
        if (unordered != ways)
          (
            Frac(unordered, 36),
            'Order matters: 3+5 and 5+3 are different outcomes.',
          ),
      ],
      params: {'total': total},
    );
  }

  _Draft _doubles() {
    final ans = Frac(1, 6);
    return _Draft(
      kind: OddsKind.doubles,
      scene: const OddsScene(label: 'Two fair dice', dice: 2),
      question: 'Roll both. What is the chance they show the same number?',
      short: 'Two dice: chance of a double?',
      answer: ans,
      steps: [
        'Two dice give 36 equally likely outcomes.',
        'Doubles: 1+1, 2+2, 3+3, 4+4, 5+5, 6+6. That is 6 ways.',
        'So the chance is 6/36 = 1/6, ${ans.percent}. (Or: whatever the '
            'first die shows, the second matches it 1 time in 6.)',
      ],
      insight: 'Whatever the first die shows, the second matches it 1 in 6.',
      slips: [
        (Frac(1, 36), 'That is one particular double, like two sixes.'),
        (Frac(1, 12), 'There are 6 doubles out of 36, not 3.'),
        (Frac(1, 3), 'Matching is harder than that: 6 of 36 rolls.'),
      ],
    );
  }

  _Draft _threeCoins(Random rng) {
    final k = rng.nextInt(4); // 0..3 heads
    final ways = choose(3, k);
    final ans = Frac(ways, 8);
    final list = [
      for (final o in ['HHH', 'HHT', 'HTH', 'THH', 'HTT', 'THT', 'TTH', 'TTT'])
        if ('H'.allMatches(o).length == k) o,
    ];
    final what = switch (k) {
      0 => 'no heads at all',
      1 => 'exactly one head',
      2 => 'exactly two heads',
      _ => 'three heads',
    };
    return _Draft(
      kind: OddsKind.threeCoins,
      scene: const OddsScene(label: 'Three fair coins', coins: 3),
      question: 'Flip all three. What is the chance of $what?',
      short: 'Three coins: chance of $what?',
      answer: ans,
      steps: [
        'Three coins give 2 × 2 × 2 = 8 equally likely outcomes.',
        '${_cap(what)}: ${list.join(', ')}. That is $ways '
            '${ways == 1 ? 'outcome' : 'outcomes'}.',
        'So the chance is $ans, ${ans.percent}.',
      ],
      insight: 'Three coins give 8 outcomes; count the arrangements.',
      slips: [
        (
          Frac(1, 4),
          'There are 4 possible head counts (0 to 3), but they are not equally '
              'likely.',
        ),
        if (ways > 1)
          (Frac(1, 8), 'There are $ways arrangements, not just one.'),
        (Frac(ways, 6), 'Three coins give 8 outcomes, not 6.'),
      ],
      params: {'heads': k},
    );
  }

  _Draft _bagDraw(Random rng) {
    final r = 2 + rng.nextInt(4), b = 1 + rng.nextInt(4), g = rng.nextInt(3);
    final t = r + b + g;
    final ans = Frac(r, t);
    final colours = [
      (BallColour.red, r),
      (BallColour.blue, b),
      if (g > 0) (BallColour.green, g),
    ];
    final desc = colours.map((c) => '${c.$2} ${c.$1.word}').join(', ');
    return _Draft(
      kind: OddsKind.bagDraw,
      scene: OddsScene(label: 'A bag: $desc', balls: colours),
      question:
          'Pull out one ball without looking. What is the chance it is '
          'red?',
      short: 'Bag of $desc: chance of red?',
      answer: ans,
      steps: [
        'There are $r + $b${g > 0 ? ' + $g' : ''} = $t balls, each equally '
            'likely.',
        '$r of them are red.',
        'So the chance is $r/$t${ans.d != t ? ' = $ans' : ''}, ${ans.percent}.',
      ],
      insight: 'Red balls out of all balls, not red against the rest.',
      slips: [
        (
          Frac(r, t - r),
          'That compares red with not-red (odds). A chance is red out of all.',
        ),
        (
          Frac(1, colours.length),
          'There are ${colours.length} colours, but not equally many balls.',
        ),
        (Frac(r, t + 1), 'Count the balls again: there are $t.'),
      ],
      params: {'red': r, 'blue': b, 'green': g},
    );
  }

  // ── Band 3 ──────────────────────────────────────────────────────────

  _Draft _atLeastOneSix(Random rng) {
    final n = 2 + rng.nextInt(2);
    final none = Frac(5, 6).pow(n);
    final ans = Frac.one - none;
    final word = _num(n);
    return _Draft(
      kind: OddsKind.atLeastOneSix,
      scene: OddsScene(label: '${_cap(word)} fair dice', dice: n),
      question: 'Roll all $word. What is the chance of at least one six?',
      short: '${_cap(word)} dice: chance of at least one six?',
      answer: ans,
      steps: [
        'Easier the other way round: find the chance of no six at all.',
        'Each die misses six with chance 5/6, so no six: (5/6)^$n = $none.',
        'So at least one six: 1 − $none = $ans, ${ans.percent}.',
      ],
      insight: '"At least one": work out "none", then take it from 1.',
      slips: [
        (
          Frac(n, 6),
          'Adding 1/6 per die counts rolls with two sixes more than once.',
        ),
        (Frac(1, 6).pow(n), 'That is every die showing a six.'),
        (none, 'That is the chance of NO six.'),
      ],
      params: {'dice': n},
    );
  }

  _Draft _bothSameColour(Random rng) {
    final r = 3 + rng.nextInt(4), b = 2 + rng.nextInt(4);
    final t = r + b;
    final ans = Frac(r, t) * Frac(r - 1, t - 1);
    return _Draft(
      kind: OddsKind.bothSameColour,
      scene: OddsScene(
        label: 'A bag: $r red, $b blue',
        balls: [(BallColour.red, r), (BallColour.blue, b)],
      ),
      question:
          'Take out two balls, one after the other, without putting the '
          'first back. What is the chance both are red?',
      short: '$r red, $b blue, draw two: chance both red?',
      answer: ans,
      steps: [
        'First ball red: $r out of $t.',
        'Then one red is gone: ${r - 1} red out of ${t - 1} left.',
        'Both: $r/$t × ${r - 1}/${t - 1} = $ans, ${ans.percent}.',
      ],
      insight: 'Without replacement, the second draw has one ball fewer.',
      slips: [
        (
          Frac(r, t).pow(2),
          'That puts the first ball back. Without replacement there is one '
              'red fewer the second time.',
        ),
        (Frac(r, t), 'That is only the first ball.'),
        (Frac(r - 1, t - 1), 'That is only the second ball.'),
      ],
      params: {'red': r, 'blue': b},
    );
  }

  _Draft _oneOfEach(Random rng) {
    final r = 2 + rng.nextInt(4), b = 2 + rng.nextInt(4);
    final t = r + b;
    final ans = Frac(2 * r * b, t * (t - 1));
    final oneOrder = Frac(r * b, t * (t - 1));
    return _Draft(
      kind: OddsKind.oneOfEach,
      scene: OddsScene(
        label: 'A bag: $r red, $b blue',
        balls: [(BallColour.red, r), (BallColour.blue, b)],
      ),
      question:
          'Take out two balls without putting the first back. What is '
          'the chance you get one of each colour?',
      short: '$r red, $b blue, draw two: chance of one each?',
      answer: ans,
      steps: [
        'Red then blue: $r/$t × $b/${t - 1} = $oneOrder.',
        'Blue then red: $b/$t × $r/${t - 1} = $oneOrder.',
        'Either order works: $oneOrder + $oneOrder = $ans, ${ans.percent}.',
      ],
      insight: 'One of each can happen in two orders; add them.',
      slips: [
        (oneOrder, 'That is only red then blue. Blue then red works too.'),
        (
          Frac(2 * r * b, t * t),
          'That puts the first ball back. Without replacement there are '
              '${t - 1} balls left.',
        ),
        (
          Frac(1, 2),
          'Two colours, but the counts and order change the chance.',
        ),
      ],
      params: {'red': r, 'blue': b},
    );
  }

  _Draft _atLeastOneHead(Random rng) {
    final n = 3 + rng.nextInt(3);
    final none = Frac(1, 2).pow(n);
    final ans = Frac.one - none;
    final word = _num(n);
    return _Draft(
      kind: OddsKind.atLeastOneHead,
      scene: OddsScene(label: '${_cap(word)} fair coins', coins: n),
      question: 'Flip all $word. What is the chance of at least one head?',
      short: '${_cap(word)} coins: chance of at least one head?',
      answer: ans,
      steps: [
        'The only way to get no head is all tails.',
        'All tails: (1/2)^$n = $none.',
        'So at least one head: 1 − $none = $ans, ${ans.percent}.',
      ],
      insight: '"At least one": 1 minus the chance of none.',
      slips: [
        (Frac(n, 1 << n), 'That is exactly one head.'),
        (Frac(1, 2), 'That is one coin. More coins give more chances.'),
        (none, 'That is the chance of no heads at all.'),
      ],
      params: {'coins': n},
    );
  }

  _Draft _twoHearts() {
    final ans = Frac(13, 52) * Frac(12, 51);
    return _Draft(
      kind: OddsKind.twoHearts,
      scene: const OddsScene(label: 'A shuffled deck of 52', deck: true),
      question: 'Deal two cards. What is the chance both are hearts?',
      short: 'Two cards: chance both are hearts?',
      answer: ans,
      steps: [
        'First card a heart: 13 out of 52.',
        'Then 12 hearts are left among 51 cards.',
        'Both: 13/52 × 12/51 = $ans, ${ans.percent}.',
      ],
      insight: 'Dealt cards don\'t go back: the second draw has 51 cards.',
      slips: [
        (
          Frac(1, 16),
          'That is with replacement. After one heart, 12 of 51 are left.',
        ),
        (Frac(1, 4), 'That is one card.'),
        (Frac(1, 8), 'Hearts aren\'t added: multiply the two draws.'),
      ],
    );
  }

  // ── Band 4 ──────────────────────────────────────────────────────────

  _Draft _givenTotal(Random rng) {
    final total = [4, 6, 8, 10][rng.nextInt(4)];
    final pairs = [
      for (var a = 1; a <= 6; a++)
        for (var b = 1; b <= 6; b++)
          if (a + b == total) '$a+$b',
    ];
    final ways = pairs.length;
    final ans = Frac(1, ways);
    final half = total ~/ 2;
    return _Draft(
      kind: OddsKind.givenTotal,
      scene: const OddsScene(label: 'Two fair dice', dice: 2),
      question:
          'You\'re told the total is $total. What is the chance it was '
          'a double?',
      short: 'Two dice, total $total: chance it was a double?',
      answer: ans,
      steps: [
        'Only rolls with a total of $total count now: ${pairs.join(', ')}. '
            'That is $ways.',
        'Just one of them is a double: $half+$half.',
        'So the chance is 1/$ways, ${ans.percent}.',
      ],
      insight: 'A condition shrinks the outcomes to the ones that fit it.',
      slips: [
        (Frac(1, 6), 'That ignores what you were told about the total.'),
        (
          Frac(1, 36),
          'That is the chance of $half+$half before knowing '
              'anything.',
        ),
        (
          Frac(1, (ways + 1) ~/ 2),
          'Order matters: ${pairs.first} and ${pairs.last} are different rolls.',
        ),
      ],
      params: {'total': total},
    );
  }

  _Draft _givenASix() {
    final ans = Frac(1, 11);
    return _Draft(
      kind: OddsKind.givenASix,
      scene: const OddsScene(label: 'Two fair dice', dice: 2),
      question:
          'A friend rolls both and says "at least one is a six". What is '
          'the chance both are sixes?',
      short: 'Two dice, at least one six: chance both are sixes?',
      answer: ans,
      steps: [
        'Rolls with at least one six: 6+1 … 6+6 and 1+6 … 5+6. That is '
            '6 + 5 = 11.',
        'Only 6+6 has two sixes.',
        'So the chance is 1/11, ${ans.percent}.',
      ],
      insight: '"At least one six" doesn\'t say which die; count all 11 rolls.',
      slips: [
        (
          Frac(1, 6),
          'That assumes you know which die is the six. You only know one of '
              'them is.',
        ),
        (Frac(1, 36), 'That ignores what your friend told you.'),
        (Frac(1, 12), 'The roll 6+6 is one outcome; 11 rolls fit, not 12.'),
      ],
    );
  }

  _Draft _threeDiceDifferent() {
    final ans = Frac(6 * 5 * 4, 216);
    return _Draft(
      kind: OddsKind.threeDiceDifferent,
      scene: const OddsScene(label: 'Three fair dice', dice: 3),
      question:
          'Roll all three. What is the chance they all show different '
          'numbers?',
      short: 'Three dice: chance all different?',
      answer: ans,
      steps: [
        'First die: anything. Second: one of the 5 other numbers (5/6).',
        'Third: one of the 4 numbers not used yet (4/6).',
        'So 5/6 × 4/6 = $ans, ${ans.percent}.',
      ],
      insight: 'Go die by die: each must avoid the numbers already shown.',
      slips: [
        (Frac(5, 6), 'That only checks the second die against the first.'),
        (Frac(1, 36), 'That is the chance all three are the same.'),
        (Frac(1, 2), 'Each die must avoid what came before: 5/6, then 4/6.'),
      ],
    );
  }

  // ── Band 5 ──────────────────────────────────────────────────────────

  _Draft _bayesTest(Random rng) {
    final n = [10, 20, 50, 100][rng.nextInt(4)];
    final sens = [80, 90, 100][rng.nextInt(3)];
    final fp = [10, 20][rng.nextInt(2)];
    const people = 1000;
    final sick = people ~/ n;
    final healthy = people - sick;
    final caught = sick * sens ~/ 100;
    final flagged = healthy * fp ~/ 100;
    final ans = Frac(caught, caught + flagged);
    return _Draft(
      kind: OddsKind.bayesTest,
      scene: OddsScene(label: '1 in $n people have it', test: true),
      question:
          'A test catches $sens% of people who have it, and wrongly '
          'flags $fp% of people who don\'t. Someone tests positive. What is '
          'the chance they have it?',
      short: '1 in $n have it, test $sens% / $fp%: chance a positive has it?',
      answer: ans,
      steps: [
        'Picture 1,000 people: $sick have it, $healthy don\'t.',
        'The test catches $caught of the $sick, and wrongly flags $flagged of '
            'the $healthy.',
        '${caught + flagged} test positive and $caught of them have it: '
            '$caught/${caught + flagged} = $ans, ${ans.percent}.',
      ],
      insight:
          'With a rare condition, most positives come from the many '
          'healthy people.',
      slips: [
        (
          Frac(sens, 100),
          'That is the chance of a positive if you have it, not the chance '
              'you have it if positive.',
        ),
        (Frac(1, n), 'That ignores the test result.'),
        (
          Frac(100 - fp, 100),
          'That is the chance a healthy person tests negative.',
        ),
      ],
      params: {'n': n, 'sens': sens, 'fp': fp},
    );
  }

  _Draft _whichCoin(Random rng) {
    final k = 2 + rng.nextInt(3); // coins in the bag
    final m = 1 + rng.nextInt(3); // heads in a row
    final pow2 = 1 << m;
    final ans = Frac(pow2, pow2 + k - 1);
    final flips = m == 1
        ? 'flip it once: heads'
        : 'flip it $m times: heads every time';
    return _Draft(
      kind: OddsKind.whichCoin,
      scene: OddsScene(label: '$k coins, one with two heads', coins: k),
      question:
          'A bag holds $k coins: ${k - 1} fair, one with heads on both '
          'sides. Pick one at random and $flips. What is the chance it is the '
          'two-headed coin?',
      short:
          '$k coins (one two-headed), $m ${m == 1 ? 'head' : 'heads'} in a '
          'row: chance it is two-headed?',
      answer: ans,
      steps: [
        'Imagine ${k * pow2} picks: the two-headed coin is picked $pow2 times '
            'and always shows heads.',
        'Fair coins are picked ${(k - 1) * pow2} times; '
            '${m == 1 ? 'half' : '1 in $pow2'} of those '
            'show ${m == 1 ? 'heads' : '$m heads'}: ${k - 1}.',
        'So $pow2 of the ${pow2 + k - 1} all-heads results are the two-headed '
            'coin: $ans, ${ans.percent}.',
      ],
      insight: 'Each head makes the two-headed coin twice as likely as before.',
      slips: [
        (Frac(1, k), 'That ignores the flips you just saw.'),
        (Frac(1, 2), 'The heads you saw are evidence; weigh each coin by it.'),
        (
          Frac(m, m + k - 1),
          'Each extra head doubles the weight, it doesn\'t '
              'add one.',
        ),
      ],
      params: {'coins': k, 'heads': m},
    );
  }

  _Draft _takingTurns(Random rng) {
    final targets = <(String, int)>[
      ('a six', 1),
      ('a 5 or a 6', 2),
      ('an even number', 3),
    ];
    final (what, a) = targets[rng.nextInt(targets.length)];
    final p = Frac(a, 6);
    final miss = Frac.one - p;
    final ans = Frac.one / (Frac(2) - p);
    return _Draft(
      kind: OddsKind.takingTurns,
      scene: const OddsScene(label: 'One die, two players', dice: 1),
      question:
          'You and a friend take turns rolling, you first. The first to '
          'roll $what wins. What is your chance of winning?',
      short: 'Take turns, you first, first to roll $what wins: your chance?',
      answer: ans,
      steps: [
        'You win on your first roll with chance $p.',
        'If you both miss (chance $miss × $miss), it starts again, so your '
            'chance P = $p + ${miss * miss} × P.',
        'Solving: P = $p ÷ (1 − ${miss * miss}) = $ans, ${ans.percent}.',
      ],
      insight: 'When a game restarts, write the chance in terms of itself.',
      slips: [
        (Frac(1, 2), 'Going first is an advantage: you get the first chance.'),
        (p, 'That is only your first roll.'),
        (Frac.one - ans, 'That is your friend\'s chance.'),
      ],
      params: {'faces': a},
    );
  }
}
