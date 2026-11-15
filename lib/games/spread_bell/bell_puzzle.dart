import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../expect_it/expect_puzzle.dart' show about, ev;
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum BellKind {
  spread,
  add,
  scale,
  rule,
  zscore,
  average,
  binomial,
  poisson,
  covar,
}

/// What the scene card draws above the question.
enum BellVisual { dots, dice, bars, bell, twoBells, scatter }

/// The card above the question.
@immutable
class BellScene {
  const BellScene({
    required this.visual,
    required this.chips,
    required this.caption,
    this.values = const [],
    this.faces = const [],
    this.dice = 0,
    this.coins = 0,
    this.bars = const [],
    this.barStart = 0,
    this.barStep = 1,
    this.mean = 0,
    this.shade = const [],
    this.ticks = const [],
    this.markZ,
    this.markLabel = '',
    this.ratio = 1,
    this.labels = const ('', ''),
    this.rho = 0,
    this.note = '',
  });

  final BellVisual visual;
  final List<String> chips;
  final String caption;

  /// [BellVisual.dots]: the values on a 0–10 line, and their [mean].
  final List<int> values;

  /// [BellVisual.dice]: a die's faces in order, or [dice] unknown dice and
  /// [coins] unknown coins.
  final List<int> faces;
  final int dice;
  final int coins;

  /// [BellVisual.bars]: chances of [barStart], [barStart] + [barStep], …;
  /// the [mean] is marked.
  final List<double> bars;
  final int barStart;
  final int barStep;
  final double mean;

  /// [BellVisual.bell]: shaded stretches in SDs from the mean (±4 stands for
  /// "and beyond"), labels under the ticks at −3 … +3 SDs, and an optional
  /// marked point.
  final List<(double, double)> shade;
  final List<String> ticks;
  final double? markZ;
  final String markLabel;

  /// [BellVisual.twoBells]: the second curve's SD as a multiple of the
  /// first's, and the two curves' names.
  final double ratio;
  final (String, String) labels;

  /// [BellVisual.scatter]: the correlation of the drawn points.
  final double rho;

  /// What the shading shows, for the review ("shaded: above 130").
  final String note;
}

/// A wrong answer and the slip behind it.
@immutable
class BellTrap {
  const BellTrap(this.label, this.why, this.value);

  final String label;
  final String why;
  final Frac value;
}

@immutable
class BellQuestion {
  const BellQuestion({
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
    required this.notes,
    required this.steps,
    required this.insight,
    required this.params,
    required this.isShare,
  });

  final int level;
  final int seed;
  final BellKind kind;
  final BellScene scene;
  final String question;
  final String hint;
  final String answer;
  final Frac answerValue;
  final List<BellTrap> traps;
  final List<String> options;

  /// The number behind each option, in the same order.
  final List<Frac> optionValues;

  /// "about 2.92" under an option that is an untidy fraction, else null.
  final List<String?> notes;
  final List<String> steps;
  final String insight;

  /// The numbers behind the question, for recomputing in tests.
  final Map<String, Frac> params;

  /// The answer is a share (a chance): written as a percentage, and every
  /// option stays below 100%.
  final bool isShare;

  int get answerIndex => options.indexOf(answer);

  String? get answerNote => notes[answerIndex];

  String feedbackFor(String picked) => picked == answer
      ? insight
      : traps.firstWhere((t) => t.label == picked).why;
}

/// A share as a percentage: "2.5%", "0.15%", "68%".
String pct(Frac f) => '${ev(f * Frac(100))}%';

/// A signed number with a real minus sign: "−0.25", "3".
String signed(Frac f) => f < Frac.zero ? '−${ev(Frac.zero - f)}' : ev(f);

/// The exact square root, or null when it isn't a fraction.
Frac? root(Frac f) {
  if (f.n < 0) return null;
  int? isqrt(int x) {
    final r = sqrt(x).round();
    for (final c in [r - 1, r, r + 1]) {
      if (c >= 0 && c * c == x) return c;
    }
    return null;
  }

  final n = isqrt(f.n), d = isqrt(f.d);
  return n == null || d == null ? null : Frac(n, d);
}

class BellDifficulty {
  static List<BellKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [BellKind.spread],
    2 => const [BellKind.add],
    3 => const [BellKind.scale],
    4 => const [BellKind.rule],
    5 => const [BellKind.zscore],
    6 => const [BellKind.average],
    7 => const [BellKind.binomial],
    8 => const [BellKind.poisson],
    9 => const [BellKind.covar],
    _ => const [
      BellKind.rule,
      BellKind.zscore,
      BellKind.average,
      BellKind.binomial,
      BellKind.poisson,
      BellKind.covar,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'variance: the average squared distance',
    2 => 'independent variances add',
    3 => 'stretching and shifting',
    4 => 'the 68–95–99.7 rule',
    5 => 'z-scores and a small table',
    6 => 'averages are less spread out',
    7 => 'counting successes',
    8 => 'Poisson counts',
    9 => 'two things that move together',
    _ => 'any of the tricks',
  };
}

class BellGenerator {
  const BellGenerator();

  static const _again = 'Check the numbers again: see the working.';

  BellQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = BellDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final draft = switch (kind) {
      BellKind.spread => _spread(rng),
      BellKind.add => _add(rng),
      BellKind.scale => _scale(rng),
      BellKind.rule => _rule(rng),
      BellKind.zscore => _zscore(rng),
      BellKind.average => _average(rng),
      BellKind.binomial => _binomial(rng),
      BellKind.poisson => _poisson(rng),
      BellKind.covar => _covar(rng),
    };

    final a = draft.value;
    final share = draft.share;
    String format(Frac v) => share ? pct(v) : ev(v);
    // Above zero; a share stays below 100% and reads as a tidy percentage.
    bool fits(Frac v) =>
        v > Frac.zero && (!share || (v < Frac.one && (v * Frac(10000)).d == 1));
    BellTrap t(Frac v, String why) => BellTrap(format(v), why, v);

    final fillers = [
      for (final k in [1, 2, 3])
        for (final sign in [1, -1])
          if (fits(a + draft.unit * Frac(sign * k)))
            t(a + draft.unit * Frac(sign * k), _again),
    ]..shuffle(rng);
    final named = [
      for (final (v, why) in draft.traps)
        if (fits(v) && v != a) t(v, why),
    ];
    var chosen = balancedOptions(
      t(a, ''),
      named,
      fillers,
      rng,
      compare: (x, y) => x.value.compareTo(y.value),
    );
    if (!share) {
      // A fraction among tidy numbers (or the other way round) mustn't be
      // the answer just because it looks different.
      final spare = [
        for (final u in [
          draft.unit * Frac(1, 2),
          draft.unit * Frac(1, 3),
          Frac(1, 12),
          Frac(1, 6),
          Frac(1, 3),
          Frac(1, 4),
          Frac.one,
        ])
          for (final k in [1, 2, 3])
            for (final sign in [1, -1])
              if (fits(a + u * Frac(sign * k)))
                t(a + u * Frac(sign * k), _again),
      ];
      chosen = _mixFormats(chosen, a, [...named, ...fillers, ...spare]);
    }

    return BellQuestion(
      level: level,
      seed: seed,
      kind: kind,
      scene: draft.scene,
      question: draft.question,
      hint: draft.hint,
      answer: format(a),
      answerValue: a,
      traps: [
        for (final x in chosen)
          if (x.value != a) x,
      ],
      options: [for (final x in chosen) x.label],
      optionValues: [for (final x in chosen) x.value],
      notes: [for (final x in chosen) share ? null : about(x.value)],
      steps: draft.steps,
      insight: draft.insight,
      params: draft.params,
      isShare: share,
    );
  }

  /// Swaps a wrong option for one on the same side of the answer (so its
  /// rank stays put) when the answer is the only fraction, or the only tidy
  /// number, among the four.
  static List<BellTrap> _mixFormats(
    List<BellTrap> chosen,
    Frac a,
    List<BellTrap> pool,
  ) {
    bool untidy(Frac v) => about(v) != null;
    final mine = untidy(a);
    if (chosen.where((o) => untidy(o.value) == mine).length >= 2) {
      return chosen;
    }
    for (final c in pool) {
      if (untidy(c.value) != mine || c.value == a) continue;
      if (chosen.any((o) => o.value == c.value)) continue;
      final below = c.value < a;
      final out = [
        for (final o in chosen)
          if (o.value != a && (o.value < a) == below) o,
      ];
      if (out.isEmpty) continue;
      // Give up a plain near miss before a named mistake.
      out.sort(
        (x, y) => (x.why == _again ? 0 : 1).compareTo(y.why == _again ? 0 : 1),
      );
      return [
        for (final o in chosen)
          if (o != out.first) o,
        c,
      ]..sort((x, y) => x.value.compareTo(y.value));
    }
    return chosen;
  }

  // ---- helpers ------------------------------------------------------------

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  static int _sum(Iterable<int> xs) => xs.fold(0, (s, x) => s + x);

  static Frac _abs(Frac f) => f < Frac.zero ? Frac.zero - f : f;

  static final _dieVar = Frac(35, 12);

  /// "3X − 4", "−2X + 5".
  static String _lin(int a, int b, [String x = 'X']) {
    final head = a == -1
        ? '−$x'
        : a < 0
        ? '−${-a}$x'
        : '$a$x';
    return '$head ${b < 0 ? '−' : '+'} ${b.abs()}';
  }

  /// "½", "¼", "1/6" and so on, for chances in the text.
  static String _chance(Frac f) => switch ((f.n, f.d)) {
    (1, 2) => '½',
    (1, 3) => '⅓',
    (2, 3) => '⅔',
    (1, 4) => '¼',
    (3, 4) => '¾',
    _ => '${f.n}/${f.d}',
  };

  /// A binomial count's chances, k = 0 … n, relative to the likeliest one
  /// (worked out from the peak, so long runs don't underflow).
  static List<double> _binomialPmf(int n, double p) {
    final out = List.filled(n + 1, 0.0);
    final top = (n * p).floor().clamp(0, n);
    out[top] = 1;
    for (var k = top; k < n; k++) {
      out[k + 1] = out[k] * (n - k) / (k + 1) * p / (1 - p);
    }
    for (var k = top; k > 0; k--) {
      out[k - 1] = out[k] * k / (n - k + 1) * (1 - p) / p;
    }
    return out;
  }

  /// A Poisson count's chances, k = 0 … [upTo], relative to the likeliest.
  static List<double> _poissonPmf(double lambda, int upTo) {
    final out = List.filled(upTo + 1, 0.0);
    final top = lambda.floor().clamp(0, upTo);
    out[top] = 1;
    for (var k = top; k < upTo; k++) {
      out[k + 1] = out[k] * lambda / (k + 1);
    }
    for (var k = top; k > 0; k--) {
      out[k - 1] = out[k] * k / lambda;
    }
    return out;
  }

  /// Bars for a count with chances [pmf]: the middle of it, at most about
  /// 40 bars (every [barStep]th value when it's wider).
  static BellScene _barScene(
    List<double> pmf,
    double mean,
    double sd, {
    required List<String> chips,
    required String caption,
  }) {
    final lo = max(0, (mean - 3.5 * sd).floor());
    final hi = min(pmf.length - 1, (mean + 3.5 * sd).ceil() + 1);
    final step = max(1, ((hi - lo + 1) / 40).ceil());
    return BellScene(
      visual: BellVisual.bars,
      chips: chips,
      caption: caption,
      bars: [for (var k = lo; k <= hi; k += step) pmf[k]],
      barStart: lo,
      barStep: step,
      mean: mean,
    );
  }

  static BellScene _bellScene({
    required List<String> chips,
    required String caption,
    required int mu,
    required int sigma,
    required List<(double, double)> shade,
    double? markZ,
    String markLabel = '',
    String note = '',
  }) => BellScene(
    visual: BellVisual.bell,
    chips: chips,
    caption: caption,
    shade: shade,
    ticks: [for (var k = -3; k <= 3; k++) '${mu + k * sigma}'],
    markZ: markZ,
    markLabel: markLabel,
    note: note,
  );

  // ---- level 1: variance of a short list or a die ---------------------------

  _Draft _spread(Random rng) {
    if (rng.nextBool()) {
      final n = 4 + rng.nextInt(2);
      List<int> xs;
      do {
        xs = [for (var i = 0; i < n; i++) rng.nextInt(11)]..sort();
      } while (xs.toSet().length < 3 || _sum(xs) % n != 0);
      final total = _sum(xs);
      final m = total ~/ n;
      final devs = [for (final x in xs) x - m];
      final ss = _sum([for (final d in devs) d * d]);
      final ans = Frac(ss, n);
      return _Draft(
        scene: BellScene(
          visual: BellVisual.dots,
          chips: ['$n numbers', 'Mean $m'],
          caption: 'Each one equally likely',
          values: xs,
          mean: m.toDouble(),
        ),
        question: 'Pick one of these numbers at random. What\'s its variance?',
        hint: 'Variance: the average squared distance from the mean.',
        value: ans,
        unit: n == 4 ? Frac(1, 2) : Frac(2, 5),
        traps: [
          (
            Frac(ss, n - 1),
            'That divides by ${n - 1}, the fix for guessing from a sample. '
                'Here you know every value: divide by $n.',
          ),
          (
            Frac(_sum([for (final d in devs) d.abs()]), n),
            'That\'s the average distance from the mean. Variance averages '
                'the squared distances.',
          ),
          (
            Frac(ss),
            'That\'s the total of the squared distances. Divide by $n to '
                'average them.',
          ),
          (
            Frac(_sum([for (final x in xs) x * x]), n),
            'That\'s the average of the squares. Subtract the mean squared, '
                '$m² = ${m * m}.',
          ),
        ],
        steps: [
          'Mean: (${xs.join(' + ')}) ÷ $n = $m.',
          'Squared distances from $m: '
              '${[for (final d in devs) d * d].join(' + ')} = $ss.',
          'Average them: $ss ÷ $n = ${ev(ans)}.',
        ],
        insight:
            'Right: variance is the average squared distance from the '
            'mean.',
        params: {
          'variant': Frac.zero,
          for (final (i, x) in xs.indexed) 'x$i': Frac(x),
          'n': Frac(n),
        },
      );
    }
    final fair = rng.nextInt(3) == 0;
    List<int> faces;
    if (fair) {
      faces = const [1, 2, 3, 4, 5, 6];
    } else {
      do {
        faces = [for (var i = 0; i < 6; i++) rng.nextInt(10)]..sort();
      } while (faces.toSet().length < 3 || _sum(faces) % 3 != 0);
    }
    final total = _sum(faces);
    final squares = _sum([for (final f in faces) f * f]);
    final m = Frac(total, 6);
    final sq = Frac(squares, 6);
    final ans = sq - m * m;
    var mad = Frac.zero;
    for (final f in faces) {
      mad = mad + _abs(Frac(f) - m);
    }
    mad = mad / Frac(6);
    return _Draft(
      scene: BellScene(
        visual: BellVisual.dice,
        chips: fair ? const ['1 fair die'] : const ['1 die', '6 faces'],
        caption: 'Each face equally likely',
        faces: faces,
      ),
      question:
          'Roll this die once. What\'s the variance of the number it shows?',
      hint: 'Variance: the average square minus the mean squared.',
      value: ans,
      unit: Frac(1, 4),
      traps: [
        (
          ans * Frac(6, 5),
          'That divides by 5, the fix for guessing from a sample. The die\'s '
              'six faces are all known: divide by 6.',
        ),
        (
          mad,
          'That\'s the average distance from the mean. Variance averages '
              'the squared distances.',
        ),
        (
          sq,
          'That\'s the average square. Take away the mean squared, '
              '${ev(m * m)}.',
        ),
        (
          ans * Frac(6),
          'That\'s the total of the squared distances. Divide by 6 to '
              'average them.',
        ),
      ],
      steps: [
        'Mean: $total ÷ 6 = ${ev(m)}.',
        'Average square: $squares ÷ 6 = ${ev(sq)}.',
        'Variance: ${ev(sq)} − ${ev(m * m)} = ${ev(ans)}.',
      ],
      insight: 'Right: the average square minus the square of the average.',
      params: {
        'variant': Frac.one,
        for (final (i, f) in faces.indexed) 'f$i': Frac(f),
      },
    );
  }

  // ---- level 2: independent variances add ----------------------------------

  _Draft _add(Random rng) {
    final variant = rng.nextInt(3);
    if (variant == 0) {
      final n = 2 + rng.nextInt(4);
      final ans = _dieVar * Frac(n);
      return _Draft(
        scene: BellScene(
          visual: BellVisual.dice,
          chips: ['$n fair dice', 'Add them up'],
          caption: 'The dice roll independently',
          dice: n,
        ),
        question:
            'Roll $n dice and add them. What\'s the variance of the '
            'total?',
        hint: 'One die\'s variance is 35/12.',
        value: ans,
        unit: Frac(1, 4),
        traps: [
          (
            _dieVar * Frac(n * n),
            'That adds standard deviations, as if the dice always rolled '
                'alike. Independent dice: add the variances.',
          ),
          (_dieVar, 'That\'s one die. Each of the $n adds its own 35/12.'),
          (
            _dieVar / Frac(n),
            'That\'s the variance of the dice\'s average. The total spreads '
                'more, not less.',
          ),
          (
            Frac(91 * n, 6),
            'That adds the average squares, 91/6 a die. A die\'s variance is '
                '91/6 − 3.5² = 35/12.',
          ),
        ],
        steps: [
          'One die: variance 35/12, about 2.92.',
          'The dice are independent, so their variances add.',
          '$n × 35/12 = ${ev(ans)}.',
        ],
        insight: 'Right: for independent rolls, variances add.',
        params: {'variant': Frac.zero, 'n': Frac(n)},
      );
    }
    if (variant == 1) {
      final n = 1 + rng.nextInt(3);
      final m = 2 + rng.nextInt(7);
      final dice = _dieVar * Frac(n);
      final coins = Frac(m, 4);
      final ans = dice + coins;
      return _Draft(
        scene: BellScene(
          visual: BellVisual.dice,
          chips: [n == 1 ? '1 die' : '$n dice', '$m coins'],
          caption: 'Score: the dice, plus 1 per head',
          dice: n,
          coins: m,
        ),
        question:
            'Roll ${n == 1 ? 'a die' : '$n dice'} and flip $m coins. You '
            'score the dice plus 1 per head. Variance of the score?',
        hint: 'A die\'s variance is 35/12. A coin scores 0 or 1.',
        value: ans,
        unit: Frac(1, 4),
        traps: [
          (dice, 'That leaves out the coins. Each one adds ¼.'),
          (dice + Frac(m, 2), 'A coin\'s variance is ½ × ½ = ¼, not ½.'),
          (
            _dieVar * Frac(n * n) + Frac(m * m, 4),
            'That adds standard deviations within each group. Independent '
                'dice and coins: add one variance each.',
          ),
          (dice + Frac(m), 'A coin scores 0 or 1: its variance is ¼, not 1.'),
        ],
        steps: [
          'Dice: $n × 35/12 = ${ev(dice)}.',
          'A coin scores 0 or 1, each half the time: variance ¼. '
              '$m × ¼ = ${ev(coins)}.',
          'All independent, so add: ${ev(dice)} + ${ev(coins)} = ${ev(ans)}.',
        ],
        insight: 'Right: add one variance for every independent piece.',
        params: {'variant': Frac.one, 'n': Frac(n), 'm': Frac(m)},
      );
    }
    final r = _pick(rng, const [2, 3, 4, 5, 6, 7, 8, 10]);
    final n = r * r;
    return _Draft(
      scene: BellScene(
        visual: BellVisual.dice,
        chips: ['$n flips', 'Heads +\$1 · tails −\$1'],
        caption: 'A fair coin',
        coins: n,
      ),
      question:
          'Flip a fair coin $n times, winning or losing \$1 each time. '
          'What\'s the standard deviation (SD) of your total?',
      hint: 'SD: the square root of the variance.',
      value: Frac(r),
      unit: Frac.one,
      traps: [
        (
          Frac(n),
          'That adds the flips\' SDs, \$1 each. Variances add: $n, so the '
              'SD is √$n.',
        ),
        (
          Frac(r, 2),
          'That\'s the SD of the number of heads. Each extra head moves you '
              '\$2, so double it.',
        ),
        (Frac(n, 2), 'That\'s the average number of heads, not a spread.'),
        (
          Frac(2 * r),
          'One flip is always \$1 from its average of 0: variance 1, not 4.',
        ),
      ],
      steps: [
        'One flip is \$1 from its average, 0, either way: variance 1.',
        'The flips are independent: variances add up to $n.',
        'SD = √$n = $r.',
      ],
      insight: 'Right: variances add, so the SD grows like √n.',
      params: {'variant': Frac(2), 'n': Frac(n)},
    );
  }

  // ---- level 3: scaling and shifting ----------------------------------------

  _Draft _scale(Random rng) {
    final variant = rng.nextInt(3);
    if (variant == 2) {
      final s = _pick(rng, const [2, 3, 4, 5, 6, 8, 10]);
      final k = Frac(9, 5);
      final ans = k * Frac(s);
      return _Draft(
        scene: BellScene(
          visual: BellVisual.twoBells,
          chips: ['SD $s °C', 'F = 1.8C + 32'],
          caption: 'The same days, in two scales',
          ratio: 1.8,
          labels: const ('°C', '°F'),
        ),
        question:
            'Daily highs vary with an SD of $s °C. What\'s their SD in '
            '°F?',
        hint: 'Adding slides the values. Multiplying stretches them.',
        value: ans,
        unit: Frac(9, 10),
        traps: [
          (
            k * k * Frac(s),
            'That multiplies by 1.8² = 3.24. Only the variance takes the '
                'square; the SD stretches by 1.8.',
          ),
          (
            ans + Frac(32),
            'The +32 moves every day the same way. It changes the average, '
                'not the spread.',
          ),
          (
            Frac(s),
            'That ignores the 1.8. Each °C step is 1.8 °F steps, so the '
                'spread stretches.',
          ),
        ],
        steps: [
          'The +32 shifts every value alike: no change to the spread.',
          'Each °C is 1.8 °F, so every distance stretches by 1.8.',
          'SD: 1.8 × $s = ${ev(ans)} °F.',
        ],
        insight: 'Right: the SD stretches by the scale and ignores the shift.',
        params: {
          'variant': Frac(2),
          'a': k,
          'b': Frac(32),
          's': Frac(s),
          'sd': Frac.one,
        },
      );
    }
    final a = _pick(rng, const [2, 3, 4, 5, -2, -3, -4]);
    var b = 2 + rng.nextInt(9);
    if (rng.nextBool()) b = -b;
    final y = _lin(a, b);
    final aa = a.abs();
    if (variant == 0) {
      final v = 2 + rng.nextInt(8);
      final ans = Frac(a * a * v);
      return _Draft(
        scene: BellScene(
          visual: BellVisual.twoBells,
          chips: ['Var(X) = $v', 'Y = $y'],
          caption: 'X, and Y made from it',
          ratio: aa.toDouble(),
          labels: const ('X', 'Y'),
        ),
        question: 'What\'s the variance of Y?',
        hint: 'Adding b slides the values. Multiplying by a stretches them.',
        value: ans,
        unit: Frac.one,
        traps: [
          (
            Frac(aa * v),
            'That scales by $aa, not $aa². Variance is in squared units: '
                'multiply by ${a * a}.',
          ),
          (
            ans + Frac(b),
            'The ${b < 0 ? '− ${-b}' : '+ $b'} moves every value the same '
                'way. It doesn\'t change the spread.',
          ),
          (
            ans + Frac(b * b),
            'Squaring the shift too? A shift moves every value equally, so '
                'the spread stays.',
          ),
          (
            Frac(v),
            'That leaves out the $a. Multiplying stretches every distance '
                'by $aa.',
          ),
        ],
        steps: [
          'The ${b < 0 ? '− ${-b}' : '+ $b'} shifts every value alike: the '
              'spread doesn\'t change.',
          'Times $a stretches distances by $aa, squared distances by '
              '${a * a}.',
          'Var(Y) = ${a * a} × $v = ${ev(ans)}.',
        ],
        insight: 'Right: Var(aX + b) = a² × Var(X); the shift drops out.',
        params: {
          'variant': Frac.zero,
          'a': Frac(a),
          'b': Frac(b),
          's': Frac(v),
          'sd': Frac.zero,
        },
      );
    }
    final s = 2 + rng.nextInt(9);
    final ans = Frac(aa * s);
    return _Draft(
      scene: BellScene(
        visual: BellVisual.twoBells,
        chips: ['SD of X: $s', 'Y = $y'],
        caption: 'X, and Y made from it',
        ratio: aa.toDouble(),
        labels: const ('X', 'Y'),
      ),
      question: 'What\'s the standard deviation (SD) of Y?',
      hint: 'Adding b slides the values. Multiplying by a stretches them.',
      value: ans,
      unit: Frac.one,
      traps: [
        (
          Frac(a * a * s),
          'Only the variance takes $aa² = ${a * a}. The SD stretches by '
              '$aa.',
        ),
        (
          ans + Frac(b),
          'The ${b < 0 ? '− ${-b}' : '+ $b'} moves every value the same way. '
              'It doesn\'t change the spread.',
        ),
        (
          Frac(s),
          'That leaves out the $a. Multiplying stretches every distance by '
              '$aa.',
        ),
        (
          Frac(a * a * s * s),
          'That\'s the variance of Y. Its SD is the square root.',
        ),
      ],
      steps: [
        'The ${b < 0 ? '− ${-b}' : '+ $b'} shifts every value alike: the '
            'spread doesn\'t change.',
        a < 0
            ? 'Times $a flips and stretches; distances grow by $aa.'
            : 'Times $a stretches every distance by $aa.',
        'SD(Y) = $aa × $s = ${ev(ans)}.',
      ],
      insight: 'Right: the SD scales by |a|; the shift drops out.',
      params: {
        'variant': Frac.one,
        'a': Frac(a),
        'b': Frac(b),
        's': Frac(s),
        'sd': Frac.one,
      },
    );
  }

  // ---- level 4: the 68–95–99.7 rule -----------------------------------------

  /// The share below the mean plus k SDs, by the 68–95–99.7 rule (k from
  /// −4 to 4; ±4 is as good as forever).
  static Frac _phi(int k) => switch (k) {
    <= -4 => Frac.zero,
    -3 => Frac(15, 10000),
    -2 => Frac(25, 1000),
    -1 => Frac(16, 100),
    0 => Frac(1, 2),
    1 => Frac(84, 100),
    2 => Frac(975, 1000),
    3 => Frac(9985, 10000),
    _ => Frac.one,
  };

  static Frac _between(int lo, int hi) => _phi(hi) - _phi(lo);

  static const _within = {1: '68%', 2: '95%', 3: '99.7%'};

  static const _scenarios = [
    ('test scores', '', 100, 15),
    ('test scores', '', 500, 100),
    ('exam marks', '', 60, 12),
    ('heights', ' cm', 170, 6),
    ('loaves', ' g', 800, 10),
    ('commutes', ' min', 40, 5),
  ];

  /// "shaded: above 130", from "What share of … are above 130?".
  static String _shadeNote(String question) =>
      'shaded: ${question.split(' are ').last.replaceAll('?', '')}';

  static String _sds(int k) => k == 1 ? '1 SD' : '$k SDs';

  _Draft _rule(Random rng) {
    final (things, unit, mu, sigma) = _pick(rng, _scenarios);
    final type = rng.nextInt(6);
    final k = 1 + rng.nextInt(3);
    String at(int z) => '${mu + z * sigma}';
    final chips = ['Mean $mu$unit', 'SD $sigma$unit'];
    final caption =
        '${things[0].toUpperCase()}${things.substring(1)} follow a bell curve';
    const hint = '68% within 1 SD, 95% within 2, 99.7% within 3.';
    final others = [
      for (final j in [k - 1, k + 1])
        if (j >= 1 && j <= 3) j,
    ];
    final question = StringBuffer('What share of $things ');
    late final Frac ans;
    late final List<(Frac, String)> traps;
    late final List<String> steps;
    late final List<(double, double)> shade;
    late final int lo, hi;
    var both = false;

    switch (type) {
      case 0 || 1:
        final up = type == 0;
        final x = up ? at(k) : at(-k);
        question.write(up ? 'are above $x$unit?' : 'are below $x$unit?');
        lo = up ? k : -4;
        hi = up ? 4 : -k;
        ans = _between(lo, hi);
        final side = up ? 'above' : 'below';
        traps = [
          (
            ans * Frac(2),
            'That counts both tails. Only the side $side $x is asked: half '
                'of that.',
          ),
          for (final j in others)
            (
              _between(j, 4),
              'That\'s the tail past ${_sds(j)}. $x is ${_sds(k)} from the '
                  'mean.',
            ),
          (Frac.one - ans, 'That\'s the share on the other side of $x.'),
          (
            _between(0, k),
            'That\'s from the mean to $x. The tail is 50% minus that.',
          ),
          (
            _between(-k, k),
            'That\'s the share within ${_sds(k)}. The tail is what\'s '
                'left outside, halved.',
          ),
        ];
        steps = [
          '$x is ${_sds(k)} $side the mean: $sigma × $k = ${k * sigma}.',
          '${_within[k]} lie within ${_sds(k)}, so '
              '${pct(Frac.one - _between(-k, k))} lie outside, in two tails.',
          'One tail, $side $x: ${pct(ans)}.',
        ];
      case 2 || 3:
        final inside = type == 2;
        question.write(
          inside
              ? 'are between ${at(-k)} and ${at(k)}$unit?'
              : 'are below ${at(-k)} or above ${at(k)}$unit?',
        );
        lo = -k;
        hi = k;
        both = !inside;
        final within = _between(-k, k);
        ans = inside ? within : Frac.one - within;
        traps = [
          (
            Frac.one - ans,
            inside
                ? 'That\'s the share outside; the question asks inside.'
                : 'That\'s the share inside; the question asks outside.',
          ),
          if (inside) ...[
            (
              _between(0, k),
              'That\'s one side of the mean only. Count both sides.',
            ),
            (
              _between(-4, k),
              'That\'s everything below ${at(k)}, the low tail too.',
            ),
          ] else ...[
            (
              ans * Frac(1, 2),
              'That\'s one tail. The question counts both sides.',
            ),
            (
              _between(0, k),
              'That\'s from the mean to ${at(k)}. The question asks for '
                  'the tails.',
            ),
          ],
          for (final j in others)
            (
              inside ? _between(-j, j) : Frac.one - _between(-j, j),
              'That\'s for ${_sds(j)}. ${at(-k)} and ${at(k)} are '
                  '${_sds(k)} from the mean.',
            ),
        ];
        steps = [
          '${at(-k)} and ${at(k)} are ${_sds(k)} either side of $mu.',
          '${_within[k]} lie within ${_sds(k)} of the mean.',
          inside
              ? 'Between them: ${pct(ans)}.'
              : 'Outside: 100% − ${_within[k]} = ${pct(ans)}.',
        ];
      case 4:
        final up = rng.nextBool();
        final x = up ? at(k) : at(-k);
        question.write(
          up ? 'are between $mu and $x$unit?' : 'are between $x and $mu$unit?',
        );
        lo = up ? 0 : -k;
        hi = up ? k : 0;
        ans = _between(0, k);
        traps = [
          (
            _between(-k, k),
            'That\'s both sides of the mean. From $mu to $x is half of it.',
          ),
          (
            _between(-4, k),
            'That counts everything ${up ? 'below' : 'above'} $x, not '
                'just from the mean.',
          ),
          (_between(k, 4), 'That\'s the tail beyond $x.'),
          for (final j in others)
            (
              _between(0, j),
              'That\'s for ${_sds(j)}. $x is ${_sds(k)} from the mean.',
            ),
        ];
        steps = [
          '$x is ${_sds(k)} ${up ? 'above' : 'below'} the mean, $mu.',
          '${_within[k]} lie within ${_sds(k)}, half on each side.',
          'From $mu to $x: ${_within[k]} ÷ 2 = ${pct(ans)}.',
        ];
      default:
        var j = 1 + rng.nextInt(3);
        if (j == k) j = k == 3 ? 1 : k + 1;
        question.write('are between ${at(-j)} and ${at(k)}$unit?');
        lo = -j;
        hi = k;
        ans = _between(-j, k);
        traps = [
          (
            _between(-k, k),
            'That treats both ends as ${_sds(k)} out. ${at(-j)} is '
                '${_sds(j)} below.',
          ),
          (
            _between(-j, j),
            'That treats both ends as ${_sds(j)} out. ${at(k)} is '
                '${_sds(k)} above.',
          ),
          (
            _between(-4, k),
            'That counts everything below ${at(k)}, the tail under '
                '${at(-j)} too.',
          ),
          (
            _between(-j, 4),
            'That counts everything above ${at(-j)}, the tail past ${at(k)} '
                'too.',
          ),
        ];
        steps = [
          '${at(-j)} is ${_sds(j)} below; ${at(k)} is ${_sds(k)} above.',
          'Below the mean to ${at(-j)}: ${pct(_between(-j, 0))}. Above, to '
              '${at(k)}: ${pct(_between(0, k))}.',
          'Add them: ${pct(ans)}.',
        ];
    }
    double c(int z) => z.toDouble().clamp(-4, 4);
    shade = both ? [(-4.0, c(lo)), (c(hi), 4.0)] : [(c(lo), c(hi))];
    final small = ans < Frac(1, 100) || ans > Frac(99, 100);
    return _Draft(
      scene: _bellScene(
        chips: chips,
        caption: caption,
        mu: mu,
        sigma: sigma,
        shade: shade,
        note: _shadeNote(question.toString()),
      ),
      question: question.toString(),
      hint: hint,
      value: ans,
      unit: small ? Frac(3, 10000) : Frac(1, 200),
      share: true,
      traps: traps,
      steps: steps,
      insight: 'Right: count SDs from the mean, then use 68–95–99.7.',
      params: {
        'lo': Frac(lo),
        'hi': Frac(hi),
        'both': Frac(both ? 1 : 0),
        'mu': Frac(mu),
        'sigma': Frac(sigma),
      },
    );
  }

  // ---- level 5: z-scores and a table ----------------------------------------

  /// The table on the card: the share below z, for z = 0.5, 1, … 2.5
  /// (keyed by 2z).
  static final _table = {
    1: Frac(69, 100),
    2: Frac(84, 100),
    3: Frac(93, 100),
    4: Frac(975, 1000),
    5: Frac(994, 1000),
  };

  static String _z(int twiceZ) => ev(Frac(twiceZ, 2));

  /// "1 SD", "1.5 SDs".
  static String _zs(int twiceZ) => twiceZ == 2 ? '1 SD' : '${_z(twiceZ)} SDs';

  static String _row(int twiceZ) => 'z ${_z(twiceZ)} → ${pct(_table[twiceZ]!)}';

  static const _zScenarios = [
    (500, 100),
    (100, 20),
    (60, 10),
    (200, 40),
    (70, 8),
    (150, 12),
  ];

  _Draft _zscore(Random rng) {
    final (mu, sigma) = _pick(rng, _zScenarios);
    final variant = rng.nextInt(5);
    final z2 = 1 + rng.nextInt(5);
    final phi = _table[z2]!;
    final zText = _z(z2);
    final off = z2 * sigma ~/ 2;
    final chips = ['Mean $mu', 'SD $sigma'];
    const caption = 'Table: the share below each z';
    const hint = 'z = (score − mean) ÷ SD. The table gives the share below.';
    final params = <String, Frac>{
      'variant': Frac(variant),
      'mu': Frac(mu),
      'sigma': Frac(sigma),
    };
    BellScene scene(
      List<(double, double)> shade,
      double z,
      String label,
      String note,
    ) => _bellScene(
      chips: [...chips, _row(z2)],
      caption: caption,
      mu: mu,
      sigma: sigma,
      shade: shade,
      markZ: z,
      markLabel: label,
      note: note,
    );
    final z = z2 / 2;
    // Reading the wrong row of the table.
    List<(Frac, String)> rows({required bool tail}) => [
      for (final w in [z2 - 1, z2 + 1])
        if (_table[w] case final below?)
          (
            tail ? Frac.one - below : below,
            'That\'s the table row for z = ${_z(w)}. Here z is $zText.',
          ),
    ];

    switch (variant) {
      case 0:
        final x = mu + off;
        params['x'] = Frac(x);
        return _Draft(
          scene: scene([(-4.0, z)], z, '$x', 'shaded: below $x'),
          question: 'What share of scores are below $x?',
          hint: hint,
          value: phi,
          unit: Frac(1, 100),
          share: true,
          traps: [
            (Frac.one - phi, 'That\'s the share above $x, not below.'),
            (
              phi - Frac(1, 2),
              'That\'s from the mean up to $x. Add the 50% below the mean.',
            ),
            (
              phi * Frac(2) - Frac.one,
              'That\'s the share within ${_zs(z2)} on both sides.',
            ),
            ...rows(tail: false),
          ],
          steps: [
            'z = ($x − $mu) ÷ $sigma = $zText.',
            'The table: ${pct(phi)} lie below z = $zText.',
            'So ${pct(phi)} score below $x.',
          ],
          insight: 'Right: turn the score into a z, then read the table.',
          params: params,
        );
      case 1:
        final x = mu + off;
        final ans = Frac.one - phi;
        params['x'] = Frac(x);
        return _Draft(
          scene: scene([(z, 4.0)], z, '$x', 'shaded: above $x'),
          question: 'What share of scores are above $x?',
          hint: hint,
          value: ans,
          unit: ans < Frac(5, 100) ? Frac(1, 1000) : Frac(1, 100),
          share: true,
          traps: [
            (phi, 'That\'s the share below $x. Above is 100% minus it.'),
            (
              ans * Frac(2),
              'That counts both tails. Only scores above $x are asked.',
            ),
            (
              phi - Frac(1, 2),
              'That\'s from the mean up to $x, not beyond it.',
            ),
            ...rows(tail: true),
          ],
          steps: [
            'z = ($x − $mu) ÷ $sigma = $zText.',
            'The table: ${pct(phi)} lie below z = $zText.',
            'Above $x: 100% − ${pct(phi)} = ${pct(ans)}.',
          ],
          insight: 'Right: the table gives below; above is the rest.',
          params: params,
        );
      case 2:
        final x = mu - off;
        final ans = Frac.one - phi;
        params['x'] = Frac(x);
        return _Draft(
          scene: scene([(-4.0, -z)], -z, '$x', 'shaded: below $x'),
          question: 'What share of scores are below $x?',
          hint: hint,
          value: ans,
          unit: ans < Frac(5, 100) ? Frac(1, 1000) : Frac(1, 100),
          share: true,
          traps: [
            (
              phi,
              'That\'s the share below a score as far above the mean. $x is '
                  'below it.',
            ),
            (
              ans * Frac(2),
              'That counts both tails. Only scores below $x are asked.',
            ),
            (phi - Frac(1, 2), 'That\'s from $x up to the mean, not below $x.'),
            ...rows(tail: true),
          ],
          steps: [
            'z = ($x − $mu) ÷ $sigma = −$zText.',
            'The curve is symmetric: below −$zText matches above +$zText.',
            '100% − ${pct(phi)} = ${pct(ans)}.',
          ],
          insight: 'Right: below the mean, flip the curve over.',
          params: params,
        );
      case 3:
        var w2 = 1 + rng.nextInt(5);
        if (w2 == z2) w2 = z2 == 5 ? 1 : z2 + 1;
        final x1 = mu - w2 * sigma ~/ 2;
        final x2 = mu + off;
        final low = Frac.one - _table[w2]!;
        final ans = phi - low;
        params['x'] = Frac(x2);
        params['x1'] = Frac(x1);
        final wText = _z(w2);
        return _Draft(
          scene: _bellScene(
            chips: [...chips, _row(min(w2, z2)), _row(max(w2, z2))],
            caption: caption,
            mu: mu,
            sigma: sigma,
            shade: [(-w2 / 2, z)],
            note: 'shaded: between $x1 and $x2',
          ),
          question: 'What share of scores are between $x1 and $x2?',
          hint: hint,
          value: ans,
          unit: Frac(1, 100),
          share: true,
          traps: [
            (
              phi - _table[w2]!,
              'That takes off the share below +$wText. $x1 is at −$wText: '
                  'below it is ${pct(low)}.',
            ),
            (phi, 'That\'s everything below $x2, the tail under $x1 too.'),
            (
              _table[z2]! * Frac(2) - Frac.one,
              'That treats both ends as ${_zs(z2)} out. $x1 is ${_zs(w2)} '
                  'below.',
            ),
            (
              _table[w2]! * Frac(2) - Frac.one,
              'That treats both ends as ${_zs(w2)} out. $x2 is ${_zs(z2)} '
                  'above.',
            ),
          ],
          steps: [
            'z-scores: $x1 is −$wText, $x2 is +$zText.',
            'Below $x2: ${pct(phi)}. Below $x1: 100% − '
                '${pct(_table[w2]!)} = ${pct(low)}.',
            'Between: ${pct(phi)} − ${pct(low)} = ${pct(ans)}.',
          ],
          insight:
              'Right: share below the top end, minus share below the '
              'bottom.',
          params: params,
        );
      default:
        final top = Frac.one - phi;
        final ans = Frac(mu + off);
        params['top'] = top;
        final traps = <(Frac, String)>[
          (
            Frac(mu - off),
            'That\'s the score for the bottom ${pct(top)}. The top is above '
                'the mean.',
          ),
          (
            Frac(mu) + Frac(z2, 2),
            'That adds z itself. z counts SDs: multiply by $sigma first.',
          ),
          for (final w in [z2 - 1, z2 + 1])
            if (_table.containsKey(w))
              (
                Frac(mu + w * sigma ~/ 2),
                'That\'s the cut for the top ${pct(Frac.one - _table[w]!)}.',
              ),
        ];
        return _Draft(
          scene: scene([(z, 4.0)], z, '?', 'shaded: the top ${pct(top)}'),
          question: 'What score marks the top ${pct(top)}?',
          hint: hint,
          value: ans,
          unit: Frac(sigma, 4),
          traps: traps,
          steps: [
            'Top ${pct(top)} means ${pct(phi)} lie below the score.',
            'The table: ${pct(phi)} below means z = $zText.',
            'Score: $mu + $zText × $sigma = ${ev(ans)}.',
          ],
          insight: 'Right: find z in the table, then mean + z × SD.',
          params: params,
        );
    }
  }

  // ---- level 6: averages narrow ---------------------------------------------

  _Draft _average(Random rng) {
    final variant = rng.nextInt(4);
    final r = _pick(rng, const [2, 3, 4, 5, 6, 10]);
    final n = r * r;
    int sigma;
    do {
      sigma = 2 + rng.nextInt(29);
    } while (100 % Frac(sigma, r).d != 0);
    final sd = Frac(sigma, r);
    final scene = BellScene(
      visual: BellVisual.twoBells,
      chips: ['SD $sigma', '$n draws'],
      caption: 'One draw, and the average of $n',
      ratio: 1 / r,
      labels: ('1 draw', 'average'),
    );
    final params = {
      'variant': Frac(variant),
      'sigma': Frac(sigma),
      'n': Frac(n),
    };
    const hint = 'Averaging n draws divides the variance by n.';
    switch (variant) {
      case 0:
        return _Draft(
          scene: scene,
          question:
              'Each draw has an SD of $sigma. What\'s the SD of the '
              'average of $n draws?',
          hint: hint,
          value: sd,
          unit: sd < Frac(4) ? Frac(1, 4) : Frac(1, 2),
          traps: [
            (
              Frac(sigma, n),
              'That divides by $n. The variance shrinks by $n, so the SD '
                  'shrinks by √$n = $r.',
            ),
            (Frac(sigma), 'That\'s one draw. Averaging narrows the spread.'),
            (
              Frac(sigma * r),
              'That\'s the SD of the total of $n draws. The average divides '
                  'it by $n.',
            ),
            (
              Frac(sigma * sigma, n),
              'That\'s the variance of the average. Its SD is the square '
                  'root.',
            ),
          ],
          steps: [
            'One draw: variance $sigma² = ${sigma * sigma}.',
            'The average of $n: variance ${sigma * sigma} ÷ $n.',
            'SD: √(${sigma * sigma} ÷ $n) = $sigma ÷ $r = ${ev(sd)}.',
          ],
          insight: 'Right: the SD of an average is σ ÷ √n.',
          params: params,
        );
      case 1:
        final ans = Frac(sigma * sigma, n);
        return _Draft(
          scene: scene,
          question:
              'Each draw has an SD of $sigma. What\'s the variance of '
              'the average of $n draws?',
          hint: hint,
          value: ans,
          unit: ans < Frac(4) ? Frac(1, 4) : Frac(1),
          traps: [
            (
              Frac(sigma * sigma, n * n),
              'That divides the SD by $n, then squares. The variance '
                  'divides by $n.',
            ),
            (
              Frac(sigma * sigma),
              'That\'s one draw\'s variance. Averaging narrows it.',
            ),
            (
              Frac(sigma * sigma, r),
              'That divides by √$n. The variance itself divides by $n.',
            ),
            (sd, 'That\'s the SD of the average. Square it for the variance.'),
          ],
          steps: [
            'One draw: variance $sigma² = ${sigma * sigma}.',
            'Averaging $n independent draws divides the variance by $n.',
            '${sigma * sigma} ÷ $n = ${ev(ans)}.',
          ],
          insight: 'Right: the variance of an average is σ² ÷ n.',
          params: params,
        );
      case 2:
        final n0 = _pick(rng, const [4, 9, 16, 25]);
        final k = _pick(rng, const [2, 3]);
        final s0 = k * (2 + rng.nextInt(5));
        final ans = Frac(n0 * k * k);
        params['n0'] = Frac(n0);
        params['k'] = Frac(k);
        return _Draft(
          scene: BellScene(
            visual: BellVisual.twoBells,
            chips: ['$n0 draws', 'SD of the average: $s0'],
            caption: 'Now, and with more draws',
            ratio: 1 / k,
            labels: ('$n0 draws', 'more'),
          ),
          question:
              'How many draws bring the SD of the average down to '
              '${s0 ~/ k}?',
          hint: hint,
          value: ans,
          unit: Frac(n0),
          traps: [
            (
              Frac(n0 * k),
              'The SD shrinks with √n. Cutting it by $k takes $k² = '
                  '${k * k} times the draws.',
            ),
            (
              Frac(k * k),
              'That\'s the factor. Multiply the $n0 draws you have by it.',
            ),
            (
              Frac(n0 * k * k * k * k),
              'That squares twice. The variance shrinks by ${k * k}, so the '
                  'draws grow by ${k * k}.',
            ),
          ],
          steps: [
            'The SD of the average is σ ÷ √n.',
            'To divide it by $k, √n must grow $k times: n grows ${k * k} '
                'times.',
            '$n0 × ${k * k} = ${ev(ans)} draws.',
          ],
          insight: 'Right: k times narrower costs k² times the draws.',
          params: params,
        );
      default:
        final ans = sd * Frac(2);
        return _Draft(
          scene: scene,
          question:
              'Each draw has an SD of $sigma. 95% of averages of $n '
              'draws land within what distance of the mean?',
          hint: hint,
          value: ans,
          unit: ans < Frac(4) ? Frac(1, 4) : Frac(1, 2),
          traps: [
            (
              Frac(2 * sigma),
              'That\'s for one draw. The average\'s SD is $sigma ÷ $r.',
            ),
            (
              Frac(2 * sigma, n),
              'That divides by $n. The SD of an average divides by √$n.',
            ),
            (sd, 'That\'s one SD. 95% lie within 2 SDs.'),
            (
              Frac(2 * sigma * sigma, n),
              'That doubles the variance. Use the SD: $sigma ÷ $r.',
            ),
          ],
          steps: [
            'The average\'s SD: $sigma ÷ √$n = ${ev(sd)}.',
            '95% lie within 2 SDs of the mean.',
            '2 × ${ev(sd)} = ${ev(ans)}.',
          ],
          insight: 'Right: 2 × σ ÷ √n covers 95% of averages.',
          params: params,
        );
    }
  }

  // ---- level 7: binomial counts ---------------------------------------------

  static final _chances = [
    Frac(1, 2),
    Frac(1, 4),
    Frac(3, 4),
    Frac(1, 5),
    Frac(2, 5),
    Frac(3, 5),
    Frac(4, 5),
    Frac(1, 10),
    Frac(3, 10),
    Frac(1, 3),
    Frac(2, 3),
    Frac(1, 6),
  ];

  /// What's counted: "Flip a fair coin 20 times", and chips.
  static (String, List<String>) _trials(int n, Frac p) {
    if (p == Frac(1, 2)) {
      return ('Flip a fair coin $n times and count heads.', ['$n flips']);
    }
    if (p == Frac(1, 6)) {
      return ('Roll a die $n times and count sixes.', ['$n rolls']);
    }
    return (
      'A player makes each shot with chance ${_chance(p)}. Count makes in $n '
          'shots.',
      ['$n shots', 'Chance ${_chance(p)}'],
    );
  }

  _Draft _binomial(Random rng) {
    final variant = rng.nextInt(3);
    if (variant == 2) {
      // The SD of a share: √(p(1 − p) ÷ n), a tidy percentage.
      final options = <(Frac, int)>[
        for (final p in [Frac(1, 2), Frac(1, 5), Frac(1, 10)])
          for (final n in [16, 25, 36, 64, 100, 225, 400, 625, 900, 2500])
            if (root(p * (Frac.one - p) / Frac(n)) case final s?)
              if ((s * Frac(10000)).d == 1 &&
                  ((p * (Frac.one - p) / Frac(n)) * Frac(10000)).d == 1)
                (p, n),
      ];
      final (p, n) = _pick(rng, options);
      final q = Frac.one - p;
      final one = root(p * q)!;
      final ans = root(p * q / Frac(n))!;
      final pmf = _binomialPmf(n, p.value);
      return _Draft(
        scene: _barScene(
          pmf,
          n * p.value,
          sqrt(n * p.value * q.value),
          chips: ['$n people', 'Yes: chance ${_chance(p)}'],
          caption: 'How many say yes',
        ),
        question:
            'In a poll of $n people, each says yes with chance '
            '${_chance(p)}. What\'s the SD of the share who say yes?',
        hint: 'One person: variance p(1 − p). A share is an average.',
        value: ans,
        unit: ans < Frac(2, 100) ? Frac(1, 1000) : Frac(1, 200),
        share: true,
        traps: [
          (
            p * q / Frac(n),
            'That\'s the variance of the share. The SD is its square root.',
          ),
          (
            one / Frac(n),
            'That divides by $n. An average\'s SD divides by √$n.',
          ),
          (one, 'That\'s one person\'s SD. Averaging $n divides it by √$n.'),
          (
            p * q,
            'That\'s one person\'s variance, p(1 − p). Divide by $n, then '
                'take the root.',
          ),
        ],
        steps: [
          'One person: variance ${_chance(p)} × ${_chance(q)} = ${ev(p * q)}.',
          'The share averages $n people: variance ${ev(p * q)} ÷ $n.',
          'SD: √(${ev(p * q)} ÷ $n) = ${pct(ans)}.',
        ],
        insight: 'Right: the SD of a share is √(p(1 − p) ÷ n).',
        params: {'variant': Frac(2), 'n': Frac(n), 'p': p},
      );
    }
    if (variant == 1) {
      final options = <(Frac, int)>[
        for (final p in _chances)
          for (var n = p.d; n <= 400; n += p.d)
            if (root(Frac(n) * p * (Frac.one - p)) case final s?)
              if (100 % s.d == 0 && s > Frac.one) (p, n),
      ];
      final (p, n) = _pick(rng, options);
      final q = Frac.one - p;
      final v = Frac(n) * p * q;
      final ans = root(v)!;
      final (text, chips) = _trials(n, p);
      return _Draft(
        scene: _barScene(
          _binomialPmf(n, p.value),
          n * p.value,
          sqrt(v.value),
          chips: chips,
          caption: 'Chance of each count',
        ),
        question: '$text What\'s the SD of the count?',
        hint: 'One trial: variance p(1 − p). Independent trials add up.',
        value: ans,
        unit: ans < Frac(4) ? Frac(1, 2) : Frac.one,
        traps: [
          (v, 'That\'s the variance, np(1 − p). The SD is its root.'),
          (
            Frac(n) * p,
            'That\'s the average count, np. The spread is √(np(1 − p)).',
          ),
          if (root(Frac(n) * p) case final s?)
            (s, 'That\'s √(np): it uses p where np(1 − p) belongs.'),
          if (root(p * q) case final s?) ...[
            (
              Frac(n) * s,
              'That adds the trials\' SDs. Variances add, so the SD grows '
                  'by √$n, not $n.',
            ),
            (
              s,
              'That\'s one trial\'s SD. Over $n trials the variance grows '
                  '$n times.',
            ),
          ],
          (
            p * q,
            'That\'s one trial\'s variance. Multiply by $n, then take the '
                'root.',
          ),
          (
            ans / Frac(n),
            'That\'s the SD of the share of successes. The count is $n '
                'times it.',
          ),
        ],
        steps: [
          'One trial: variance p(1 − p) = ${ev(p * q)}.',
          '$n independent trials: $n × ${ev(p * q)} = ${ev(v)}.',
          'SD: √${ev(v)} = ${ev(ans)}.',
        ],
        insight: 'Right: the SD of a count is √(np(1 − p)).',
        params: {'variant': Frac.one, 'n': Frac(n), 'p': p},
      );
    }
    final p = _pick(rng, _chances);
    final n = p.d * (2 + rng.nextInt(max(2, 60 ~/ p.d)));
    final q = Frac.one - p;
    final ans = Frac(n) * p * q;
    final (text, chips) = _trials(n, p);
    return _Draft(
      scene: _barScene(
        _binomialPmf(n, p.value),
        n * p.value,
        sqrt(ans.value),
        chips: chips,
        caption: 'Chance of each count',
      ),
      question: '$text What\'s the variance of the count?',
      hint: 'One trial: variance p(1 − p). Independent trials add up.',
      value: ans,
      unit: ans < Frac(4) ? Frac(1, 4) : Frac.one,
      traps: [
        (
          Frac(n) * p,
          'That\'s the average count, np. The variance is np(1 − p).',
        ),
        (
          p * q,
          'That\'s one trial\'s variance. $n independent trials add $n of '
              'them.',
        ),
        (
          Frac(n * n) * p * q,
          'That adds the trials\' SDs. Independent trials: add variances, '
              '$n × p(1 − p).',
        ),
        (
          Frac(n) * q,
          'That\'s the average number of misses. The variance is '
              'np(1 − p).',
        ),
      ],
      steps: [
        'One trial is 1 or 0: variance p(1 − p) = ${_chance(p)} × '
            '${_chance(q)} = ${ev(p * q)}.',
        'The $n trials are independent, so their variances add.',
        '$n × ${ev(p * q)} = ${ev(ans)}.',
      ],
      insight: 'Right: a count of n trials has variance np(1 − p).',
      params: {'variant': Frac.zero, 'n': Frac(n), 'p': p},
    );
  }

  // ---- level 8: Poisson counts ----------------------------------------------

  static const _streams = [
    ('calls', 'a minute', 'minute', 'minutes'),
    ('emails', 'an hour', 'hour', 'hours'),
    ('typos', 'a page', 'page', 'pages'),
    ('goals', 'a match', 'match', 'matches'),
  ];

  _Draft _poisson(Random rng) {
    final variant = rng.nextInt(4);
    final (what, per, one, many) = _pick(rng, _streams);
    const hint = 'For a Poisson count, the variance equals the mean.';
    BellScene bars(int lambda, List<String> chips, String caption) => _barScene(
      _poissonPmf(lambda.toDouble(), lambda * 3 + 12),
      lambda.toDouble(),
      sqrt(lambda),
      chips: chips,
      caption: caption,
    );
    switch (variant) {
      case 0:
        final lambda = 2 + rng.nextInt(5);
        final t = 2 + rng.nextInt(9);
        final ans = Frac(lambda * t);
        return _Draft(
          scene: bars(lambda, [
            '$lambda $what $per',
            'Poisson',
          ], '${what[0].toUpperCase()}${what.substring(1)} in one $one'),
          question: 'What\'s the variance of the $what in $t $many?',
          hint: hint,
          value: ans,
          unit: Frac.one,
          traps: [
            (
              Frac(lambda),
              'That\'s one $one. Over $t independent $many, variances add.',
            ),
            (
              Frac(lambda * t * t),
              'That scales one $one by $t, giving $t² times. Separate $many '
                  'are independent: add $t variances.',
            ),
            (
              Frac(lambda * lambda * t),
              'That squares the rate. A Poisson count\'s variance equals its '
                  'mean.',
            ),
            if (root(ans) case final s?)
              (s, 'That\'s the SD. The variance equals the mean itself.'),
          ],
          steps: [
            'In $t $many, the $what average $lambda × $t = ${lambda * t}.',
            'The total is Poisson too: its variance equals its mean.',
            'Variance: ${ev(ans)}.',
          ],
          insight: 'Right: Poisson counts have variance equal to the mean.',
          params: {'variant': Frac.zero, 'lambda': Frac(lambda), 't': Frac(t)},
        );
      case 1:
        final pairs = [
          for (var l = 1; l <= 9; l++)
            for (var t = 2; t <= 16; t++)
              if (root(Frac(l * t)) != null) (l, t),
        ];
        final (lambda, t) = _pick(rng, pairs);
        final ans = root(Frac(lambda * t))!;
        return _Draft(
          scene: bars(lambda, [
            '$lambda $what $per',
            'Poisson',
          ], '${what[0].toUpperCase()}${what.substring(1)} in one $one'),
          question:
              'What\'s the standard deviation of the $what in $t '
              '$many?',
          hint: hint,
          value: ans,
          unit: Frac.one,
          traps: [
            (
              Frac(lambda * t),
              'That\'s the variance. The SD is its square root.',
            ),
            if (root(Frac(lambda)) case final s?)
              (
                s * Frac(t),
                'That scales one $one\'s SD by $t. Independent $many: '
                    'variances add, so the SD grows by √$t.',
              ),
            if (root(Frac(t)) case final s?)
              (
                Frac(lambda) * s,
                'That takes the root of the $many only. Take the root of '
                    'the mean, $lambda × $t.',
              ),
            (
              Frac(lambda),
              'That\'s one $one\'s variance. Over $t $many the count grows.',
            ),
            if (root(Frac(lambda)) case final s?)
              (
                s,
                'That\'s one $one\'s SD. Over $t $many the variance grows $t '
                    'times.',
              ),
            if (root(Frac(lambda, t)) case final s?)
              (
                s,
                'That\'s the SD of the rate per $one, averaged over $t '
                    '$many. The question asks for the whole count.',
              ),
          ],
          steps: [
            'In $t $many: mean $lambda × $t = ${lambda * t}.',
            'Poisson: the variance equals the mean, ${lambda * t}.',
            'SD: √${lambda * t} = ${ev(ans)}.',
          ],
          insight: 'Right: variance = mean, and the SD is its root.',
          params: {'variant': Frac.one, 'lambda': Frac(lambda), 't': Frac(t)},
        );
      case 2:
        final (a, b) = _pick(rng, const [
          (9, 16),
          (16, 9),
          (36, 64),
          (64, 36),
          (25, 144),
          (144, 25),
          (81, 144),
          (144, 81),
        ]);
        final ans = root(Frac(a + b))!;
        return _Draft(
          scene: bars(a, ['A: mean $a', 'B: mean $b'], 'A on its own'),
          question:
              'A and B are independent Poisson counts. What\'s the SD '
              'of A + B?',
          hint: hint,
          value: ans,
          unit: Frac.one,
          traps: [
            (
              root(Frac(a))! + root(Frac(b))!,
              'That adds the SDs. Independent counts: add the variances, '
                  'then take the root.',
            ),
            (Frac(a + b), 'That\'s the variance. The SD is its root.'),
            (
              root(Frac(a))! * root(Frac(b))!,
              'That multiplies the SDs. Add the variances, then take the '
                  'root.',
            ),
            (root(Frac(a))!, 'That\'s A\'s SD alone. B\'s spread adds to it.'),
            (root(Frac(b))!, 'That\'s B\'s SD alone. A\'s spread adds to it.'),
            (
              _abs(root(Frac(a))! - root(Frac(b))!),
              'That subtracts the SDs. Independent spreads combine through '
                  'their variances.',
            ),
          ],
          steps: [
            'Each count\'s variance equals its mean: $a and $b.',
            'Independent: the variances add, $a + $b = ${a + b}.',
            'SD: √${a + b} = ${ev(ans)}.',
          ],
          insight: 'Right: add variances, then take one square root.',
          params: {'variant': Frac(2), 'a': Frac(a), 'b': Frac(b)},
        );
      default:
        final a = 4 + rng.nextInt(9);
        final b = 1 + rng.nextInt(a - 2);
        final ans = Frac(a + b);
        return _Draft(
          scene: bars(a, ['Home: mean $a', 'Away: mean $b'], 'Home goals'),
          question:
              'Home and away goals are independent Poisson counts. '
              'What\'s the variance of home minus away?',
          hint: hint,
          value: ans,
          unit: Frac.one,
          traps: [
            (
              Frac(a - b),
              'Variances add even for a difference: Var(−B) = Var(B).',
            ),
            (
              Frac((a - b) * (a - b)),
              'That squares the average gap. The spread comes from both '
                  'counts.',
            ),
            (Frac(a), 'That leaves out the away goals\' spread.'),
            (
              Frac(a + b, 2),
              'That averages the two. Independent variances add.',
            ),
          ],
          steps: [
            'Each count\'s variance equals its mean: $a and $b.',
            'Flipping a sign doesn\'t change a spread: Var(−B) = $b.',
            'Independent, so add: $a + $b = ${a + b}.',
          ],
          insight: 'Right: for a difference too, independent variances add.',
          params: {'variant': Frac(3), 'a': Frac(a), 'b': Frac(b)},
        );
    }
  }

  // ---- level 9: covariance ---------------------------------------------------

  static final _rhos = [
    Frac(1, 2),
    Frac(1, 4),
    Frac(3, 4),
    Frac(1, 5),
    Frac(2, 5),
    Frac(3, 5),
    Frac(1, 10),
    Frac(3, 10),
  ];

  _Draft _covar(Random rng) {
    final variant = rng.nextInt(3);
    final plus = rng.nextBool();
    final s = Frac(plus ? 1 : -1);
    final op = plus ? 'X + Y' : 'X − Y';
    final question = plus
        ? 'You hold both. What\'s the variance of $op?'
        : 'Long X, short Y: you make $op. What\'s its variance?';
    String sign(Frac v) => v < Frac.zero ? '−' : '+';
    if (variant == 0) {
      // Square variances, so adding the SDs gives a whole-number slip.
      final sx = 2 + rng.nextInt(6), sy = 2 + rng.nextInt(6);
      final a = sx * sx, b = sy * sy;
      int c;
      do {
        c = rng.nextInt(2 * sx * sy) - sx * sy;
      } while (c == 0 || c * c >= a * b);
      final ans = Frac(a + b) + s * Frac(2 * c);
      final twoC = s * Frac(2 * c);
      return _Draft(
        scene: BellScene(
          visual: BellVisual.scatter,
          chips: ['Var X = $a', 'Var Y = $b', 'Cov = ${signed(Frac(c))}'],
          caption: 'X and Y, day by day',
          rho: c / sqrt(a * b),
        ),
        question: question,
        hint: 'Covariance: how much X and Y move together.',
        value: ans,
        unit: Frac.one,
        traps: [
          (
            Frac(a + b),
            'That leaves out the covariance. X and Y move together, so it '
                'counts.',
          ),
          (Frac(a + b) + s * Frac(c), 'The covariance counts twice: 2 × Cov.'),
          (
            Frac(a + b) - s * Frac(2 * c),
            plus
                ? 'For X + Y the covariance comes in as + 2 Cov.'
                : 'In X − Y the covariance term flips sign: − 2 Cov.',
          ),
          if (!plus)
            (
              Frac(a - b) - Frac(2 * c),
              'Variances never subtract: Var(−Y) = Var(Y).',
            ),
          (
            plus ? Frac((sx + sy) * (sx + sy)) : Frac((sx - sy) * (sx - sy)),
            plus
                ? 'That adds the SDs, $sx + $sy, then squares. That\'s right '
                      'only when X and Y move in lockstep.'
                : 'That subtracts the SDs, then squares. That\'s right only '
                      'when X and Y move in lockstep.',
          ),
          (
            ans / Frac(4),
            'That\'s the variance of half of each, ($op) ÷ 2. The question '
                'asks for the whole.',
          ),
        ],
        steps: [
          'Var($op) = Var X + Var Y ${plus ? '+' : '−'} 2 Cov.',
          '${plus ? '' : '− '}2 Cov = ${signed(twoC)}.',
          '$a + $b ${sign(twoC)} ${ev(_abs(twoC))} = ${ev(ans)}.',
        ],
        insight: 'Right: Var(X ± Y) = Var X + Var Y ± 2 Cov.',
        params: {
          'variant': Frac.zero,
          'a': Frac(a),
          'b': Frac(b),
          'c': Frac(c),
          's': s,
        },
      );
    }
    if (variant == 1) {
      final sx = 2 + rng.nextInt(9);
      final sy = 2 + rng.nextInt(9);
      var rho = _pick(rng, _rhos);
      if (rng.nextInt(3) == 0) rho = Frac.zero - rho;
      final cov = rho * Frac(sx * sy);
      final twoC = s * cov * Frac(2);
      final ans = Frac(sx * sx + sy * sy) + twoC;
      return _Draft(
        scene: BellScene(
          visual: BellVisual.scatter,
          chips: ['SD X = $sx', 'SD Y = $sy', 'Correlation ${signed(rho)}'],
          caption: 'X and Y, day by day',
          rho: rho.value,
        ),
        question: question,
        hint: 'Covariance = correlation × SD of X × SD of Y.',
        value: ans,
        unit: Frac.one,
        traps: [
          (
            Frac(sx * sx + sy * sy) + s * rho * Frac(2),
            'That adds the correlation itself. The covariance is '
                '${signed(rho)} × $sx × $sy = ${signed(cov)}.',
          ),
          (
            Frac(sx * sx + sy * sy),
            'That leaves out the covariance. Correlated moves count.',
          ),
          (
            Frac(sx * sx + sy * sy) - twoC,
            plus
                ? 'For X + Y the covariance comes in as + 2 Cov.'
                : 'In X − Y the covariance term flips sign: − 2 Cov.',
          ),
          (
            plus ? Frac((sx + sy) * (sx + sy)) : Frac((sx - sy) * (sx - sy)),
            plus
                ? 'Adding SDs is right only when the correlation is 1.'
                : 'Subtracting SDs is right only when the correlation is 1.',
          ),
        ],
        steps: [
          'Cov = ${signed(rho)} × $sx × $sy = ${signed(cov)}.',
          'Var($op) = Var X + Var Y ${plus ? '+' : '−'} 2 Cov.',
          '${sx * sx} + ${sy * sy} ${sign(twoC)} ${ev(_abs(twoC))} = '
              '${ev(ans)}.',
        ],
        insight: 'Right: turn the correlation into a covariance first.',
        params: {
          'variant': Frac.one,
          'sx': Frac(sx),
          'sy': Frac(sy),
          'rho': rho,
          's': s,
        },
      );
    }
    // A standard deviation that comes out whole.
    final found = <(int, int, Frac, Frac)>[
      for (var sx = 2; sx <= 12; sx++)
        for (var sy = 2; sy <= 12; sy++)
          for (final r in _rhos)
            for (final rho in [r, Frac.zero - r])
              if (root(Frac(sx * sx + sy * sy) + s * rho * Frac(2 * sx * sy))
                  case final v?)
                if (v.d == 1) (sx, sy, rho, v),
    ];
    final (sx, sy, rho, ans) = _pick(rng, found);
    final cov = rho * Frac(sx * sy);
    final twoC = s * cov * Frac(2);
    final v = Frac(sx * sx + sy * sy) + twoC;
    return _Draft(
      scene: BellScene(
        visual: BellVisual.scatter,
        chips: ['SD X = $sx', 'SD Y = $sy', 'Correlation ${signed(rho)}'],
        caption: 'X and Y, day by day',
        rho: rho.value,
      ),
      question: plus
          ? 'You hold both. What\'s the standard deviation of $op?'
          : 'Long X, short Y: you make $op. What\'s its standard deviation?',
      hint: 'Covariance = correlation × SD of X × SD of Y.',
      value: ans,
      unit: Frac.one,
      traps: [
        (
          Frac(sx + sy),
          'That adds the SDs, right only when the moves line up exactly. '
              'Add variances and the covariance term.',
        ),
        (v, 'That\'s the variance. The SD is its square root.'),
        if (root(Frac(sx * sx + sy * sy)) case final r?)
          (r, 'That leaves out the covariance. Correlated moves count.'),
        if (root(Frac(sx * sx + sy * sy) - twoC) case final r?)
          (
            r,
            plus
                ? 'For X + Y the covariance comes in as + 2 Cov.'
                : 'In X − Y the covariance term flips sign: − 2 Cov.',
          ),
        if (!plus)
          (
            Frac((sx - sy).abs()),
            'That subtracts the SDs, right only when the moves line up '
                'exactly. Spreads combine through variances.',
          ),
        (
          ans / Frac(2),
          'That\'s the SD of half of each, ($op) ÷ 2. The question asks for '
              'the whole.',
        ),
        (Frac(sx), 'That\'s X\'s SD alone. Y\'s moves count too.'),
        (Frac(sy), 'That\'s Y\'s SD alone. X\'s moves count too.'),
      ],
      steps: [
        'Cov = ${signed(rho)} × $sx × $sy = ${signed(cov)}.',
        'Var = ${sx * sx} + ${sy * sy} ${sign(twoC)} ${ev(_abs(twoC))} = '
            '${ev(v)}.',
        'SD = √${ev(v)} = ${ev(ans)}.',
      ],
      insight: 'Right: variances and covariance first, the root last.',
      params: {
        'variant': Frac(2),
        'sx': Frac(sx),
        'sy': Frac(sy),
        'rho': rho,
        's': s,
      },
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
    this.share = false,
  });

  final BellScene scene;
  final String question;
  final String hint;
  final Frac value;
  final List<(Frac, String)> traps;
  final List<String> steps;
  final String insight;
  final Map<String, Frac> params;

  /// The step for plain near misses.
  final Frac unit;

  /// The answer is a share, written as a percentage below 100%.
  final bool share;
}
