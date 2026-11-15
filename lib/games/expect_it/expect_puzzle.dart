import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum ExpKind {
  average,
  sum,
  waiting,
  indicator,
  maxMin,
  coupon,
  compound,
  stick,
  deck,
}

/// What the scene card draws above the question.
enum ExpVisual { dice, faces, coins, diceCoins, hats, cards, stick }

/// The card above the question.
@immutable
class ExpScene {
  const ExpScene({
    required this.visual,
    required this.chips,
    required this.caption,
    this.count = 0,
    this.coins = 0,
    this.faces = const [],
    this.pips = false,
    this.length = 0,
    this.points = 0,
    this.breakStick = false,
  });

  final ExpVisual visual;
  final List<String> chips;
  final String caption;

  /// Dice, hats or cards drawn (the chips give the true number).
  final int count;

  /// Coins drawn next to the dice ([ExpVisual.diceCoins]).
  final int coins;

  /// [ExpVisual.faces]: the faces of the die, in order.
  final List<int> faces;

  /// Faces 1–6 drawn as pips rather than numbers.
  final bool pips;

  /// [ExpVisual.stick]: its length in cm and the random points on it.
  final int length;
  final int points;

  /// One break (two pieces) rather than marked points.
  final bool breakStick;
}

/// A wrong answer and the slip behind it.
@immutable
class ExpTrap {
  const ExpTrap(this.label, this.why, this.value);

  final String label;
  final String why;
  final Frac value;
}

@immutable
class ExpQuestion {
  const ExpQuestion({
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
  final ExpKind kind;
  final ExpScene scene;
  final String question;
  final String hint;
  final String answer;
  final Frac answerValue;
  final List<ExpTrap> traps;
  final List<String> options;

  /// The number behind each option, in the same order.
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

/// An average as written in the game: whole numbers and tidy decimals as
/// numbers ("6", "3.5", "14.7"), anything else as a fraction ("161/36").
String ev(Frac f) {
  if (f.d == 1) return '${f.n}';
  if (100 % f.d == 0) {
    var s = f.value.toStringAsFixed(2);
    while (s.endsWith('0')) {
      s = s.substring(0, s.length - 1);
    }
    return s;
  }
  return '${f.n}/${f.d}';
}

/// "about 4.47" under a fraction; null when [ev] already reads as a number.
String? about(Frac f) =>
    f.d == 1 || 100 % f.d == 0 ? null : 'about ${f.value.toStringAsFixed(2)}';

class ExpDifficulty {
  static List<ExpKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [ExpKind.average],
    2 => const [ExpKind.sum],
    3 => const [ExpKind.waiting],
    4 => const [ExpKind.indicator],
    5 => const [ExpKind.maxMin],
    6 => const [ExpKind.coupon],
    7 => const [ExpKind.compound],
    8 => const [ExpKind.stick],
    9 => const [ExpKind.deck],
    _ => const [
      ExpKind.indicator,
      ExpKind.maxMin,
      ExpKind.coupon,
      ExpKind.compound,
      ExpKind.stick,
      ExpKind.deck,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'the average of one die',
    2 => 'adding averages',
    3 => 'waiting for something to happen',
    4 => 'counting with yes-or-no tallies',
    5 => 'the higher or lower of two dice',
    6 => 'collecting every face',
    7 => 'one step, then another',
    8 => 'random points on a stick',
    9 => 'positions in a shuffled deck',
    _ => 'any of the tricks',
  };
}

class ExpGenerator {
  const ExpGenerator();

  static const _again = 'Check the numbers again: see the working.';

  ExpQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = ExpDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final draft = switch (kind) {
      ExpKind.average => _average(rng),
      ExpKind.sum => _sum(rng),
      ExpKind.waiting => _waiting(rng),
      ExpKind.indicator => _indicator(rng),
      ExpKind.maxMin => _maxMin(rng),
      ExpKind.coupon => _coupon(rng),
      ExpKind.compound => _compound(rng),
      ExpKind.stick => _stick(rng),
      ExpKind.deck => _deck(rng),
    };

    // Smallest first, the answer at a random rank, named slips first, then
    // plain near misses. Nothing below zero.
    final a = draft.value;
    final fillers = [
      for (final k in [1, 2, 3])
        for (final sign in [1, -1])
          if (a + draft.unit * Frac(sign * k) > Frac.zero)
            _t(a + draft.unit * Frac(sign * k), _again, draft.suffix),
    ]..shuffle(rng);
    final named = [
      for (final t in draft.traps)
        if (t.value > Frac.zero) t,
    ];
    final chosen = balancedOptions(
      _t(a, '', draft.suffix),
      named,
      fillers,
      rng,
      compare: (x, y) => x.value.compareTo(y.value),
    );

    return ExpQuestion(
      level: level,
      seed: seed,
      kind: kind,
      scene: draft.scene,
      question: draft.question,
      hint: draft.hint,
      answer: _label(a, draft.suffix),
      answerValue: a,
      traps: [
        for (final t in chosen)
          if (t.value != a) t,
      ],
      options: [for (final t in chosen) t.label],
      optionValues: [for (final t in chosen) t.value],
      steps: draft.steps,
      insight: draft.insight,
      params: draft.params,
    );
  }

  // ---- helpers ------------------------------------------------------------

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  static String _label(Frac v, String suffix) => '${ev(v)}$suffix';

  static ExpTrap _t(Frac v, String why, [String suffix = '']) =>
      ExpTrap(_label(v, suffix), why, v);

  static Frac _harmonic(int n) {
    var h = Frac.zero;
    for (var k = 1; k <= n; k++) {
      h = h + Frac(1, k);
    }
    return h;
  }

  static String _harmonicText(int n) => switch (n) {
    2 => '1 + ½',
    3 => '1 + ½ + ⅓',
    4 => '1 + ½ + ⅓ + ¼',
    _ => '1 + ½ + … + 1/$n',
  };

  static String _dice(int n) => n == 1 ? '1 die' : '$n dice';

  // ---- kinds --------------------------------------------------------------

  /// A die with its own faces: add them, divide by six.
  _Draft _average(Random rng) {
    List<int> faces;
    do {
      faces = [for (var i = 0; i < 6; i++) rng.nextInt(10)]..sort();
    } while (faces.toSet().length < 3 ||
        faces.reduce((a, b) => a + b) % 3 != 0);
    final total = faces.reduce((a, b) => a + b);
    final ans = Frac(total, 6);
    final counts = <int, int>{};
    for (final f in faces) {
      counts[f] = (counts[f] ?? 0) + 1;
    }
    final mode = counts.entries.reduce((a, b) => b.value > a.value ? b : a);
    final distinct = faces.toSet();
    return _Draft(
      scene: ExpScene(
        visual: ExpVisual.faces,
        chips: const ['1 die', '6 faces'],
        caption: 'Each face equally likely',
        faces: faces,
      ),
      question: 'Roll this die once. What does it show, on average?',
      hint: 'Add up the six faces, then share them out.',
      value: ans,
      unit: Frac(1, 2),
      traps: [
        _t(
          Frac(faces[2] + faces[3], 2),
          'That\'s the middle of the faces. The average weighs every face, '
          'so the far ones pull it their way.',
        ),
        if (mode.value > 1)
          _t(
            Frac(mode.key),
            '${mode.key} is the face that turns up most often, not the '
            'average.',
          ),
        _t(
          Frac(distinct.reduce((a, b) => a + b), distinct.length),
          'That counts each number once. Faces that repeat count each '
          'time.',
        ),
        _t(
          Frac(faces.first + faces.last, 2),
          'Halfway between the lowest and the highest; the faces between '
          'them matter too.',
        ),
      ],
      steps: [
        'Add the faces: ${faces.join(' + ')} = $total.',
        'Each face turns up 1 time in 6.',
        'Average: $total ÷ 6 = ${ev(ans)}.',
      ],
      insight: 'Right: the average is the faces added up and shared out.',
      params: {for (final (i, f) in faces.indexed) 'f$i': Frac(f)},
    );
  }

  /// Averages add up, whatever the dice and coins do together.
  _Draft _sum(Random rng) {
    final variant = rng.nextInt(3);
    final die = Frac(7, 2);
    if (variant == 0) {
      final n = 2 + rng.nextInt(4);
      final ans = die * Frac(n);
      return _Draft(
        scene: ExpScene(
          visual: ExpVisual.dice,
          chips: [_dice(n), 'Add them up'],
          caption: 'Every die fair',
          count: n,
        ),
        question:
            'Roll ${_dice(n)} and add them. What\'s the total, on '
            'average?',
        hint: 'Find one die\'s average first.',
        value: ans,
        unit: Frac(1, 2),
        traps: [
          _t(Frac(3 * n), 'That uses 3 for a die. A die averages 3.5.'),
          _t(die, 'That\'s one die. Each of the $n adds its own 3.5.'),
          _t(
            Frac(6 * n),
            '${6 * n} is the most the total can be, not its average.',
          ),
          _t(
            Frac(7 * n),
            'That adds 1 and 6 for each die but forgets to '
            'halve: (1 + 6) ÷ 2 = 3.5.',
          ),
        ],
        steps: [
          'One die: (1 + 2 + 3 + 4 + 5 + 6) ÷ 6 = 3.5.',
          'Averages add, even for a total.',
          '$n × 3.5 = ${ev(ans)}.',
        ],
        insight: 'Right: the average of a total is the total of averages.',
        params: {'variant': Frac.zero, 'n': Frac(n)},
      );
    }
    if (variant == 1) {
      final n = 1 + rng.nextInt(3);
      final m = 2 + rng.nextInt(5);
      final ans = die * Frac(n) + Frac(m, 2);
      return _Draft(
        scene: ExpScene(
          visual: ExpVisual.diceCoins,
          chips: [_dice(n), '$m coins'],
          caption: 'Score: the dice, plus 1 per head',
          count: n,
          coins: m,
        ),
        question:
            'Roll ${_dice(n)} and flip $m coins. You score the dice '
            'plus 1 for each head. Average score?',
        hint: 'Average the dice and the heads apart, then add.',
        value: ans,
        unit: Frac(1, 2),
        traps: [
          _t(
            die * Frac(n),
            'That leaves out the coins: $m coins give '
            '${ev(Frac(m, 2))} heads on average.',
          ),
          _t(
            die * Frac(n) + Frac(m),
            'That scores every coin as a head. '
            'Each coin gives ½ a head on average.',
          ),
          _t(
            Frac(2 * (n + m)),
            'That averages 3.5 and 0.5 together. '
            'Add what each die and coin brings instead.',
          ),
        ],
        steps: [
          'Dice: $n × 3.5 = ${ev(die * Frac(n))}.',
          'Heads: $m × ½ = ${ev(Frac(m, 2))}.',
          'Add: ${ev(die * Frac(n))} + ${ev(Frac(m, 2))} = ${ev(ans)}.',
        ],
        insight: 'Right: work out each piece\'s average and add them.',
        params: {'variant': Frac.one, 'n': Frac(n), 'm': Frac(m)},
      );
    }
    final k = _pick(rng, const [2, 3, 4]);
    final ans = die * Frac(k) + die;
    return _Draft(
      scene: const ExpScene(
        visual: ExpVisual.dice,
        chips: ['Die A', 'Die B'],
        caption: 'Two fair dice',
        count: 2,
      ),
      question:
          'Roll two dice. Score $k times the first, plus the second. '
          'Average score?',
      hint: 'Scaling a roll scales its average.',
      value: ans,
      unit: Frac(1, 2),
      traps: [
        _t(
          Frac(7),
          'That\'s plain 3.5 + 3.5. The first die counts $k '
          'times.',
        ),
        _t(
          die * Frac(2 * k),
          'That multiplies both dice by $k; only the '
          'first is.',
        ),
        _t(
          Frac(6 * k + 6),
          'That\'s the best possible score, not the '
          'average.',
        ),
      ],
      steps: [
        'First die: $k × 3.5 = ${ev(die * Frac(k))}.',
        'Second die: 3.5.',
        '${ev(die * Frac(k))} + 3.5 = ${ev(ans)}.',
      ],
      insight: 'Right: k times a roll averages k times its average.',
      params: {'variant': Frac(2), 'k': Frac(k)},
    );
  }

  /// Waiting for a chance p takes 1/p tries on average.
  _Draft _waiting(Random rng) {
    // (setup, tries, chance, target, how the chance is counted, picture,
    // count)
    final cases = [
      (
        'Roll a die until it shows a 6.',
        'rolls',
        Frac(1, 6),
        'a 6',
        '1 face in 6',
        ExpVisual.dice,
        1,
      ),
      (
        'Roll a die until it shows a 5 or a 6.',
        'rolls',
        Frac(1, 3),
        'a 5 or 6',
        '2 faces in 6',
        ExpVisual.dice,
        1,
      ),
      (
        'Flip a coin until it lands heads.',
        'flips',
        Frac(1, 2),
        'heads',
        '1 side in 2',
        ExpVisual.coins,
        1,
      ),
      (
        'Roll two dice until they match.',
        'rolls',
        Frac(1, 6),
        'a double',
        '6 pairs in 36',
        ExpVisual.dice,
        2,
      ),
      (
        'Roll two dice until they add to 7.',
        'rolls',
        Frac(1, 6),
        'a 7',
        '6 pairs in 36',
        ExpVisual.dice,
        2,
      ),
      (
        'Roll two dice until they add to 11 or 12.',
        'rolls',
        Frac(1, 12),
        '11 or 12',
        '3 pairs in 36',
        ExpVisual.dice,
        2,
      ),
      (
        'Draw a card, put it back and shuffle, until you draw a heart.',
        'draws',
        Frac(1, 4),
        'a heart',
        '13 cards in 52',
        ExpVisual.cards,
        3,
      ),
      (
        'Draw a card, put it back and shuffle, until you draw an ace.',
        'draws',
        Frac(1, 13),
        'an ace',
        '4 cards in 52',
        ExpVisual.cards,
        3,
      ),
      (
        'Draw a card, put it back and shuffle, until you draw a face card.',
        'draws',
        Frac(3, 13),
        'a face card',
        '12 cards in 52',
        ExpVisual.cards,
        3,
      ),
    ];
    final (setup, tries, p, what, why, visual, count) = _pick(rng, cases);
    final one = tries.substring(0, tries.length - 1);
    final before = rng.nextInt(3) == 0;
    final wait = Frac.one / p;
    final ans = before ? wait - Frac.one : wait;
    return _Draft(
      scene: ExpScene(
        visual: visual,
        chips: ['Waiting for $what', 'Chance ${p.n} in ${p.d}'],
        caption: 'Each try starts fresh',
        count: count,
      ),
      question: before
          ? '$setup How many $tries come before it, on average?'
          : '$setup How many $tries does it take, on average, '
                'counting the last?',
      hint: 'A chance of 1 in N takes N tries on average.',
      value: ans,
      unit: Frac.one,
      traps: [
        if (before)
          _t(
            wait,
            '${ev(wait)} counts the $one that hits too; the '
            'question asks for the ones before it.',
          )
        else
          _t(
            wait - Frac.one,
            'That counts only the misses, not the $one '
            'that hits.',
          ),
        _t(
          wait / Frac(2),
          'Half of ${ev(wait)}. Long waits happen, and '
          'they pull the average up.',
        ),
        _t(
          wait * Frac(2),
          'Double the wait. On average it takes '
          '${ev(wait)}, the chance turned upside down.',
        ),
        if (!before)
          _t(
            wait + Frac.one,
            'One too many: ${ev(wait)} already counts the $one that '
            'hits.',
          ),
      ],
      steps: [
        'Chance of $what each try: $why = ${p.n}/${p.d}.',
        'Waiting for a 1-in-N chance takes N tries on average: '
            '${ev(wait)}.',
        before
            ? 'Before it: ${ev(wait)} − 1 = ${ev(ans)}.'
            : 'Counting the last: ${ev(ans)} $tries.',
      ],
      insight: 'Right: a 1-in-N chance takes N tries on average.',
      params: {'p': p, 'before': Frac(before ? 1 : 0)},
    );
  }

  /// Count with tallies: add up each one's chance.
  _Draft _indicator(Random rng) {
    final variant = rng.nextInt(5);
    switch (variant) {
      case 0:
        final n = _pick(rng, const [6, 12, 18, 30]);
        final ans = Frac(n, 6);
        return _Draft(
          scene: ExpScene(
            visual: ExpVisual.dice,
            chips: ['$n rolls', 'Count the 6s'],
            caption: 'One fair die',
            count: 1,
          ),
          question: 'Roll a die $n times. How many 6s, on average?',
          hint: 'Each roll is a 6 with chance 1 in 6.',
          value: ans,
          unit: Frac.one,
          traps: [
            _t(
              Frac(n, 2),
              'That\'s a 1-in-2 chance each roll; a 6 is 1 '
              'in 6.',
            ),
            _t(
              Frac(n, 36),
              'That\'s the chance of two 6s; each roll '
              'counts on its own.',
            ),
            _t(ans + Frac.one, 'One too many: $n × 1/6 = ${ev(ans)}.'),
          ],
          steps: [
            'Tally 1 for each roll that\'s a 6.',
            'Each tally averages 1/6.',
            'Add the $n tallies: $n × 1/6 = ${ev(ans)}.',
          ],
          insight: 'Right: add up each roll\'s chance.',
          params: {'variant': Frac.zero, 'n': Frac(n)},
        );
      case 1:
        final n = _pick(rng, const [4, 5, 8, 10, 20]);
        return _Draft(
          scene: ExpScene(
            visual: ExpVisual.hats,
            chips: ['$n people', '$n hats, shuffled'],
            caption: 'Each takes a hat at random',
            count: n,
          ),
          question:
              '$n people each take a hat at random. How many get '
              'their own, on average?',
          hint: 'Each person\'s chance of their own hat is 1 in $n.',
          value: Frac.one,
          unit: Frac(1, 2),
          traps: [
            _t(
              Frac(1, n),
              'That\'s one person\'s chance. Add it up for all '
              '$n.',
            ),
            _t(
              Frac(n, 2),
              'Half of them would need each to have a 1-in-2 '
              'chance; it\'s 1 in $n.',
            ),
            _t(Frac(2), 'Two would need a 2-in-$n chance each.'),
          ],
          steps: [
            'Tally 1 for each person who gets their own hat.',
            'Each tally averages 1/$n.',
            'Add the $n tallies: $n × 1/$n = 1, for any number of '
                'people.',
          ],
          insight:
              'Right: one, however many people. Tallies add even '
              'when they depend on each other.',
          params: {'variant': Frac.one, 'n': Frac(n)},
        );
      case 2:
        final k = _pick(rng, const [5, 13, 26]);
        final ans = Frac(4 * k, 52);
        return _Draft(
          scene: ExpScene(
            visual: ExpVisual.cards,
            chips: ['Deal $k cards', '52-card deck'],
            caption: 'A shuffled deck',
            count: 5,
          ),
          question:
              'Deal $k cards from a shuffled deck. How many aces, on '
              'average?',
          hint: 'Each card dealt is an ace with chance 4 in 52.',
          value: ans,
          unit: Frac(1, 13),
          traps: [
            _t(
              Frac(1, 13),
              'That\'s one card\'s chance. There are $k '
              'cards.',
            ),
            _t(Frac(k, 52), 'That counts one ace; there are four.'),
            _t(Frac(4 * k, 13), 'That uses 4 in 13 per card; it\'s 4 in 52.'),
          ],
          steps: [
            'Tally 1 for each card that\'s an ace.',
            'Each card is an ace with chance 4/52 = 1/13.',
            '$k × 1/13 = ${ev(ans)}.',
          ],
          insight:
              'Right: dealing without putting back changes nothing '
              'for the average.',
          params: {'variant': Frac(2), 'k': Frac(k)},
        );
      case 3:
        final n = _pick(rng, const [5, 7, 9, 11, 21]);
        final ans = Frac(n - 1, 2);
        return _Draft(
          scene: ExpScene(
            visual: ExpVisual.coins,
            chips: ['$n flips in a row', 'Count matching neighbours'],
            caption: 'HH or TT side by side',
            count: min(n, 6),
          ),
          question:
              'Flip a coin $n times in a row. How many neighbouring '
              'pairs match, on average?',
          hint: 'Count the neighbouring pairs first.',
          value: ans,
          unit: Frac(1, 2),
          traps: [
            _t(Frac(n, 2), 'There are ${n - 1} neighbouring pairs, not $n.'),
            _t(
              Frac(n - 1, 4),
              'A pair matches half the time (HH or TT), '
              'not a quarter.',
            ),
            _t(
              Frac(n - 1),
              'That\'s every pair; each matches only half '
              'the time.',
            ),
          ],
          steps: [
            '$n flips make ${n - 1} neighbouring pairs.',
            'Each pair matches with chance 1/2.',
            '${n - 1} × 1/2 = ${ev(ans)}.',
          ],
          insight: 'Right: tally each pair; the overlaps don\'t matter.',
          params: {'variant': Frac(3), 'n': Frac(n)},
        );
      default:
        final n = _pick(rng, const [5, 6, 8, 15]);
        final pairs = n * (n - 1) ~/ 2;
        final ans = Frac(pairs, 7);
        return _Draft(
          scene: ExpScene(
            visual: ExpVisual.hats,
            chips: ['$n people', 'Born on a weekday at random'],
            caption: 'Any of 7 days, equally likely',
            count: n,
          ),
          question:
              '$n people. How many pairs of them were born on the '
              'same day of the week, on average?',
          hint: 'Count the pairs of people first.',
          value: ans,
          unit: Frac(1, 7),
          traps: [
            _t(
              Frac(n, 7),
              'That tallies people, not pairs: there are '
              '$pairs pairs.',
            ),
            _t(
              Frac(pairs, 49),
              'Two given people share a day with chance '
              '1/7, not 1/49.',
            ),
            _t(
              Frac(n * n, 14),
              'There are $n × ${n - 1} ÷ 2 = $pairs '
              'pairs.',
            ),
          ],
          steps: [
            'Pairs of people: $n × ${n - 1} ÷ 2 = $pairs.',
            'Each pair shares a day with chance 1/7.',
            '$pairs × 1/7 = ${ev(ans)}.',
          ],
          insight: 'Right: tally the pairs and add their chances.',
          params: {'variant': Frac(4), 'n': Frac(n)},
        );
    }
  }

  /// The higher (or lower) of two dice.
  _Draft _maxMin(Random rng) {
    final n = _pick(rng, const [4, 6, 6, 8]);
    final high = rng.nextBool();
    var sumMax = 0;
    for (var k = 1; k <= n; k++) {
      sumMax += k * (2 * k - 1);
    }
    final eMax = Frac(sumMax, n * n);
    final eMin = Frac(n + 1) - eMax;
    final ans = high ? eMax : eMin;
    final one = Frac(n + 1, 2);
    final kind = n == 6 ? 'dice' : '$n-sided dice';
    final word = high ? 'higher' : 'lower';
    return _Draft(
      scene: ExpScene(
        visual: ExpVisual.dice,
        chips: ['Two $kind', 'Keep the $word'],
        caption: 'Faces 1 to $n, equally likely',
        count: 2,
      ),
      question:
          'Roll two $kind and keep the $word. What is it, on '
          'average?',
      hint: high
          ? 'The higher is at most k when both are.'
          : 'The higher and the lower add up to the two dice.',
      value: ans,
      unit: Frac(1, n),
      traps: [
        _t(
          one,
          '${ev(one)} is one die\'s average. Keeping the $word of '
          'two pulls it ${high ? 'up' : 'down'}.',
        ),
        _t(
          high ? eMin : eMax,
          'That\'s the ${high ? 'lower' : 'higher'} '
          'of the two, not the $word.',
        ),
        _t(
          high ? Frac(2 * n, 3) : Frac(n, 3),
          'That treats the die like a smooth stick. Dice are lumpy: ties '
          'and the 1 change it.',
        ),
        _t(
          high ? Frac(n) : Frac.one,
          'That\'s the ${high ? 'best' : 'worst'}'
          ' it can be, not its average.',
        ),
      ],
      steps: [
        high
            ? 'The higher is at most k when both are: (k/$n)².'
            : 'The higher is exactly k with chance (2k − 1)/${n * n}.',
        high
            ? 'So it is exactly k with chance (2k − 1)/${n * n}.'
            : 'Higher plus lower = the two dice: '
                  '${n + 1} on average, so lower = ${n + 1} − higher.',
        high
            ? 'Add k × (2k − 1) for k = 1 to $n: $sumMax ÷ ${n * n} = '
                  '${ev(ans)}.'
            : 'Higher averages $sumMax ÷ ${n * n}, so lower = '
                  '${n + 1} − ${ev(eMax)} = ${ev(ans)}.',
      ],
      insight: high
          ? 'Right: find the chance of each value from "both at most k".'
          : 'Right: higher and lower add up to the two dice.',
      params: {'n': Frac(n), 'high': Frac(high ? 1 : 0)},
    );
  }

  /// Collect every face; or how many different faces turn up.
  _Draft _coupon(Random rng) {
    final all = rng.nextInt(3) != 0;
    final n = all
        ? _pick(rng, const [2, 3, 4, 6, 6])
        : _pick(rng, const [4, 6]);
    final what = n == 2 ? 'coin' : (n == 6 ? 'die' : '$n-sided die');
    final faceWord = n == 2 ? 'side' : 'face';
    final scene = ExpScene(
      visual: n == 2 ? ExpVisual.coins : ExpVisual.faces,
      chips: [
        n == 2 ? '1 coin' : '1 $what',
        all ? 'Until every $faceWord shows' : '${n == 6 ? 3 : 2} rolls',
      ],
      caption: all ? 'Each $faceWord at least once' : 'Count different faces',
      faces: [for (var i = 1; i <= n; i++) i],
      pips: n == 6,
      count: n == 2 ? 2 : 0,
    );
    if (all) {
      final ans = Frac(n) * _harmonic(n);
      final waits = [for (var k = n; k >= 1; k--) '$n/$k'];
      final verb = n == 2 ? 'Flip' : 'Roll';
      final tries = n == 2 ? 'flips' : 'rolls';
      return _Draft(
        scene: scene,
        question:
            '$verb a $what until every $faceWord has shown. How many '
            '$tries does it take, on average?',
        hint: 'Each new $faceWord is a wait of its own.',
        value: ans,
        unit: Frac(1, 2),
        traps: [
          _t(
            Frac(n),
            'One per $faceWord would need no repeats; repeats '
            'cost extra $tries.',
          ),
          _t(
            Frac(n * n),
            '$n × $n waits the full $n for every $faceWord. '
            'Early ${faceWord}s come quickly.',
          ),
          if (n > 2)
            _t(
              Frac(n * (n + 1), 2),
              'That adds the faces 1 + … + $n. The '
              'waits are ${waits.join(' + ')}.',
            ),
          _t(
            ans - Frac(n),
            'That leaves out the last $faceWord\'s wait, '
            'the longest: $n.',
          ),
        ],
        steps: [
          'Waiting for a new $faceWord when k are left takes $n/k '
              '$tries on average.',
          'Add the waits: ${waits.join(' + ')}.',
          'That\'s $n × (${_harmonicText(n)}) = ${ev(ans)}.',
        ],
        insight: 'Right: split the wait into one wait per new $faceWord.',
        params: {'n': Frac(n), 'all': Frac.one},
      );
    }
    final r = n == 6 ? 3 : 2;
    final miss = Frac(n - 1, n);
    var missAll = Frac.one;
    for (var i = 0; i < r; i++) {
      missAll = missAll * miss;
    }
    final ans = Frac(n) * (Frac.one - missAll);
    return _Draft(
      scene: scene,
      question:
          'Roll a $what $r times. How many different faces turn up, '
          'on average?',
      hint: 'Tally each face that shows up at least once.',
      value: ans,
      unit: Frac(1, n),
      traps: [
        _t(
          Frac(r),
          '$r would need no repeats; sometimes a face comes '
          'twice.',
        ),
        _t(
          Frac(r) - Frac(r * (r - 1), 2 * n),
          'That takes off every '
          'possible repeat once; a triple gets taken off too often.',
        ),
        _t(
          Frac(n) * missAll,
          'That\'s how many faces are missed, not how '
          'many show.',
        ),
      ],
      steps: [
        'Tally each face that shows at least once.',
        'A face is missed by all $r rolls with chance '
            '(${n - 1}/$n)^$r = $missAll.',
        '$n × (1 − $missAll) = ${ev(ans)}.',
      ],
      insight: 'Right: tally each face, using the chance it never shows.',
      params: {'n': Frac(n), 'all': Frac.zero, 'r': Frac(r)},
    );
  }

  /// One random step decides the next.
  _Draft _compound(Random rng) {
    final variant = rng.nextInt(3);
    final die = Frac(7, 2);
    if (variant == 0) {
      final coins = rng.nextBool();
      final each = coins ? Frac(1, 2) : die;
      final ans = die * each;
      final thing = coins ? 'coins' : 'dice';
      return _Draft(
        scene: ExpScene(
          visual: coins ? ExpVisual.diceCoins : ExpVisual.dice,
          chips: [
            'Roll 1 die',
            coins ? 'Flip that many coins' : 'Roll that many dice',
          ],
          caption: coins ? 'Count the heads' : 'Add the second dice',
          count: coins ? 1 : 2,
          coins: coins ? 3 : 0,
        ),
        question: coins
            ? 'Roll a die, then flip that many coins. How many heads, on '
                  'average?'
            : 'Roll a die, then roll that many dice and add them. Average '
                  'total?',
        hint:
            'Average the second step for a given first roll, then '
            'average that.',
        value: ans,
        unit: coins ? Frac(1, 4) : Frac(1, 2),
        traps: [
          _t(die, 'That\'s the first die alone. The $thing come after it.'),
          _t(
            each * Frac(6),
            'That assumes the first roll is a 6; it '
            'averages 3.5.',
          ),
          _t(
            die + each,
            'That adds the two averages. The first roll says '
            'how many $thing, so they multiply.',
          ),
          if (coins) _t(each, 'That\'s one coin; the die says how many.'),
        ],
        steps: [
          'Roll k: the $thing then average k × ${ev(each)}.',
          'Average that over k: 3.5 × ${ev(each)}.',
          '= ${ev(ans)}.',
        ],
        insight:
            'Right: average the second step, then average over the '
            'first.',
        params: {'variant': Frac.zero, 'coins': Frac(coins ? 1 : 0)},
      );
    }
    if (variant == 1) {
      final t = _pick(rng, const [2, 3, 4]);
      var kept = 0;
      for (var k = t + 1; k <= 6; k++) {
        kept += k;
      }
      final ans = Frac(t, 6) * die + Frac(kept, 6);
      return _Draft(
        scene: ExpScene(
          visual: ExpVisual.dice,
          chips: ['1 die', 'Reroll a $t or less once'],
          caption: 'You must keep the second roll',
          count: 2,
        ),
        question:
            'Roll a die. If it shows $t or less, roll again and keep '
            'that. What do you end with, on average?',
        hint: 'Split it: keep the first roll, or take a fresh 3.5.',
        value: ans,
        unit: Frac(1, 6),
        traps: [
          _t(die, 'That\'s a single roll. Rerolling the low ones helps.'),
          _t(
            Frac(t + 1 + 6, 2),
            'That\'s the average of the faces you '
            'keep. Rerolls can still come out low.',
          ),
          _t(
            Frac(kept, 6) + Frac(t, 6),
            'That scores a reroll as 1 point. '
            'A fresh roll averages 3.5.',
          ),
        ],
        steps: [
          'First roll above $t (chance ${6 - t}/6): keep it; those faces '
              'add $kept/6.',
          '$t or less (chance $t/6): a fresh roll, worth 3.5.',
          '$kept/6 + $t/6 × 3.5 = ${ev(ans)}.',
        ],
        insight: 'Right: split on the first roll and weigh each branch.',
        params: {'variant': Frac.one, 't': Frac(t)},
      );
    }
    final cases = [
      ('a 6', Frac(1, 6), 'Roll a die', 'rolls'),
      ('a 5 or 6', Frac(1, 3), 'Roll a die', 'rolls'),
      ('heads', Frac(1, 2), 'Flip a coin', 'flips'),
      ('a heart', Frac(1, 4), 'Draw a card, put it back,', 'draws'),
    ];
    final (what, p, verb, tries) = _pick(rng, cases);
    final ans = Frac.one / p + Frac.one / (p * p);
    final w = Frac.one / p;
    return _Draft(
      scene: ExpScene(
        visual: p == Frac(1, 2)
            ? ExpVisual.coins
            : (p == Frac(1, 4) ? ExpVisual.cards : ExpVisual.dice),
        chips: ['Two in a row', 'Chance ${p.n} in ${p.d} each'],
        caption: 'A miss starts the count again',
        count: 2,
      ),
      question:
          '$verb until you get $what twice in a row. How many $tries '
          'does it take, on average?',
      hint: 'First wait for one; then a miss sends you back to the start.',
      value: ans,
      unit: Frac.one,
      traps: [
        _t(
          w * w,
          'Two in a row has chance 1/${ev(w * w)}, but a miss after '
          'a hit throws the hit away.',
        ),
        _t(
          w * Frac(2),
          'That\'s two separate waits; they have to be in a '
          'row.',
        ),
      ],
      steps: [
        'One $what takes ${ev(w)} $tries on average.',
        'Then one more try: a hit ends it; a miss (chance '
            '${ev(Frac.one - p)}) starts it all again.',
        'So E = (${ev(w)} + 1) ÷ ${ev(p)} = ${ev(w)} + ${ev(w * w)} = '
            '${ev(ans)}.',
      ],
      insight: 'Right: condition on what happens after the first hit.',
      params: {'variant': Frac(2), 'p': p},
    );
  }

  /// Random points on a stick.
  _Draft _stick(Random rng) {
    final l = _pick(rng, const [12, 24, 36, 60]);
    final variant = rng.nextInt(5);
    final big = Frac(l);
    const cm = ' cm';
    _Draft draft({
      required String question,
      required String hint,
      required Frac value,
      required List<ExpTrap> traps,
      required List<String> steps,
      required String insight,
      required int points,
      required bool breakStick,
      required String chip,
    }) => _Draft(
      scene: ExpScene(
        visual: ExpVisual.stick,
        chips: ['Stick $l cm', chip],
        caption: 'Every point equally likely',
        length: l,
        points: points,
        breakStick: breakStick,
      ),
      question: question,
      hint: hint,
      value: value,
      unit: Frac(l, 12),
      suffix: cm,
      traps: traps,
      steps: steps,
      insight: insight,
      params: {'variant': Frac(variant), 'l': big, 'points': Frac(points)},
    );

    ExpTrap t(Frac v, String why) => _t(v, why, cm);

    switch (variant) {
      case 0:
      case 1:
        final longer = variant == 0;
        final ans = longer ? big * Frac(3, 4) : big * Frac(1, 4);
        return draft(
          question:
              'Break it at a random point. How long is the '
              '${longer ? 'longer' : 'shorter'} piece, on average?',
          hint: longer
              ? 'The longer piece is never under half the stick.'
              : 'The shorter piece is never over half the stick.',
          value: ans,
          traps: [
            t(
              big / Frac(2),
              'Half the stick is the ${longer ? 'least' : 'most'}'
              ' the ${longer ? 'longer' : 'shorter'} piece can be.',
            ),
            t(
              longer ? big * Frac(2, 3) : big / Frac(3),
              'That\'s for two '
              'random points; here there is one break.',
            ),
            t(
              longer ? big / Frac(4) : big * Frac(3, 4),
              'That\'s the '
              '${longer ? 'shorter' : 'longer'} piece.',
            ),
          ],
          steps: [
            'The shorter piece is anywhere from 0 to ${l ~/ 2} cm, all '
                'equally likely.',
            'So it averages ${l ~/ 4} cm.',
            longer
                ? 'The longer is the rest: $l − ${l ~/ 4} = ${ev(ans)} cm.'
                : 'Shorter piece: ${ev(ans)} cm.',
          ],
          insight: 'Right: the shorter piece is even between 0 and half.',
          points: 1,
          breakStick: true,
          chip: '1 break, anywhere',
        );
      case 2:
        final ans = big / Frac(3);
        return draft(
          question:
              'Mark two random points. How far apart are they, on '
              'average?',
          hint: 'Two points cut the stick into three pieces.',
          value: ans,
          traps: [
            t(big / Frac(2), 'Half the stick is the middle, not the gap.'),
            t(big / Frac(4), 'That\'s the shorter piece of one break.'),
            t(
              big * Frac(2, 3),
              'That\'s where the further one sits, not '
              'the gap.',
            ),
          ],
          steps: [
            'Two points cut the stick into three pieces.',
            'By symmetry each piece averages the same: $l ÷ 3.',
            'The gap is the middle piece: ${ev(ans)} cm.',
          ],
          insight: 'Right: random points split a stick evenly on average.',
          points: 2,
          breakStick: false,
          chip: '2 random points',
        );
      case 3:
        final ans = big * Frac(2, 3);
        return draft(
          question:
              'Mark two random points. How far from the left end is '
              'the further one, on average?',
          hint: 'Two points cut the stick into three pieces.',
          value: ans,
          traps: [
            t(
              big / Frac(2),
              'That\'s one point alone. The further of two '
              'sits beyond the middle.',
            ),
            t(big * Frac(3, 4), 'That\'s the longer piece of one break.'),
            t(big / Frac(3), 'That\'s the nearer one.'),
          ],
          steps: [
            'Two points cut the stick into three pieces.',
            'Each averages $l ÷ 3 = ${l ~/ 3} cm.',
            'The further point is past two of them: ${ev(ans)} cm.',
          ],
          insight: 'Right: n points make n + 1 even pieces on average.',
          points: 2,
          breakStick: false,
          chip: '2 random points',
        );
      default:
        final n = _pick(rng, const [3, 5]);
        final ans = big / Frac(n + 1);
        return draft(
          question:
              'Mark $n random points. How far from the left end is '
              'the nearest one, on average?',
          hint: '$n points cut the stick into ${n + 1} pieces.',
          value: ans,
          traps: [
            t(
              big / Frac(n),
              'That splits it into $n pieces; $n points make '
              '${n + 1}.',
            ),
            t(big / Frac(2), 'That\'s one point alone.'),
          ],
          steps: [
            '$n points cut the stick into ${n + 1} pieces.',
            'By symmetry each averages $l ÷ ${n + 1}.',
            'The nearest point ends the first piece: ${ev(ans)} cm.',
          ],
          insight: 'Right: n points make n + 1 even pieces on average.',
          points: n,
          breakStick: false,
          chip: '$n random points',
        );
    }
  }

  /// Where the first special card falls in a shuffled deck.
  _Draft _deck(Random rng) {
    final cases = [
      (52, 4, 'an ace', '52 cards', '4 aces'),
      (52, 13, 'a heart', '52 cards', '13 hearts'),
      (52, 26, 'a red card', '52 cards', '26 red'),
      (10, 1, 'the joker', '10 cards', '1 joker'),
      (10, 4, 'a winner', '10 cards', '4 winners'),
      (20, 3, 'a star', '20 cards', '3 stars'),
      (12, 2, 'a red card', '12 cards', '2 red'),
    ];
    final (n, k, one, c1, c2) = _pick(rng, cases);
    final before = rng.nextBool();
    final upTo = Frac(n + 1, k + 1);
    final ans = before ? Frac(n - k, k + 1) : upTo;
    return _Draft(
      scene: ExpScene(
        visual: ExpVisual.cards,
        chips: [c1, c2],
        caption: 'Shuffled, turned over one by one',
        count: 5,
      ),
      question: before
          ? 'Turn cards over until you reach $one. How many cards come '
                'before it, on average?'
          : 'Turn cards over until you reach $one. How many cards do you '
                'turn, on average, counting it?',
      hint: 'The $k special cards cut the rest into ${k + 1} even gaps.',
      value: ans,
      unit: Frac(1, k + 1),
      traps: [
        _t(
          Frac(n, k),
          'That\'s for putting each card back. Without, the '
          'gaps give (n + 1) ÷ (k + 1).',
        ),
        _t(
          Frac(n, 2),
          'Half the deck leaves out how many special cards '
          'there are: more of them, sooner the first.',
        ),
        if (before)
          _t(
            upTo,
            'That counts the special card too; the question asks '
            'for the ones before it.',
          )
        else
          _t(
            Frac(n - k, k + 1),
            'That counts the cards before it, not the '
            'one you stop on.',
          ),
        _t(
          Frac(n, k + 1),
          'Close: the $k special cards split the other '
          '${n - k}, not all $n.',
        ),
      ],
      steps: [
        'The $k special cards split the other ${n - k} into ${k + 1} '
            'gaps.',
        'By symmetry each gap averages ${n - k} ÷ ${k + 1} = '
            '${ev(Frac(n - k, k + 1))}.',
        before
            ? 'Cards before the first: ${ev(ans)}.'
            : 'Counting the special one: ${ev(Frac(n - k, k + 1))} + 1 = '
                  '${ev(ans)}.',
      ],
      insight: 'Right: special cards cut the rest into even gaps.',
      params: {'n': Frac(n), 'k': Frac(k), 'before': Frac(before ? 1 : 0)},
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
    this.suffix = '',
  });

  final ExpScene scene;
  final String question;
  final String hint;
  final Frac value;
  final List<ExpTrap> traps;
  final List<String> steps;
  final String insight;
  final Map<String, Frac> params;

  /// The step for plain near misses.
  final Frac unit;

  /// Written after every option ("cm").
  final String suffix;
}
