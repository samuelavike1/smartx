import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum VolKind {
  direction,
  atm,
  scaling,
  digitalPrice,
  digitalChance,
  spreadDigital,
  spreadCount,
  inOut,
  farBarrier,
  cap,
  dOne,
  dTwo,
  delta,
  hedge,
  impliedVol,
  richer,
}

/// What the picture draws.
enum VolVisual {
  /// What an option pays against the stock at expiry.
  payoff,

  /// Stock paths over time, with a barrier.
  path,

  /// Price against time or volatility.
  curve,

  /// The standard bell curve with the area left of a cut shaded.
  bell,
}

/// A labelled dot on a picture; spark orange when it marks the unknown.
@immutable
class VolMark {
  const VolMark(this.x, this.y, this.label, {this.unknown = false});

  final double x, y;
  final String label;
  final bool unknown;
}

/// A small chart, in the question's own units.
@immutable
class VolPicture {
  const VolPicture({
    required this.visual,
    required this.title,
    this.line = const [],
    this.ghost = const [],
    this.sparkLine = false,
    this.barrierX,
    this.barrierY,
    this.barrierLabel,
    this.marks = const [],
    this.ticks = const [],
    this.axis = '',
    this.cut = 0,
    this.cutLabel = '',
    this.areaLabel = '',
  });

  final VolVisual visual;

  /// Shown above the picture on the review.
  final String title;

  /// The main line, and a dashed second one (a digital, or another path).
  final List<(double, double)> line;
  final List<(double, double)> ghost;

  /// The main line is the unknown (spark) rather than ink.
  final bool sparkLine;

  /// A dashed barrier: upright at a stock price (payoffs) or flat at one
  /// (paths).
  final double? barrierX, barrierY;
  final String? barrierLabel;
  final List<VolMark> marks;

  /// Labels under the x axis.
  final List<(double, String)> ticks;

  /// What runs along the x axis.
  final String axis;

  /// Bell curve: where the shading stops, and its labels.
  final double cut;
  final String cutLabel, areaLabel;
}

/// The card above the question.
@immutable
class VolScene {
  const VolScene({
    required this.chips,
    required this.caption,
    this.lines = const [],
    this.picture,
    this.pictureOnCard = true,
  });

  final List<String> chips;

  /// Maths shown on the card, in `MathText` shorthand.
  final List<String> lines;
  final String caption;
  final VolPicture? picture;

  /// The picture is part of the question; otherwise it waits for the
  /// review, where it would give the answer away.
  final bool pictureOnCard;
}

/// One line of working: words, and maths under them when it helps.
@immutable
class VolStep {
  const VolStep(this.text, [this.math]);

  final String text;

  /// `MathText` shorthand.
  final String? math;
}

/// A wrong answer and the slip behind it.
@immutable
class VolTrap {
  const VolTrap(this.label, this.why, [this.value]);

  final String label;
  final String why;

  /// Its number, for numeric questions.
  final Frac? value;
}

@immutable
class VolQuestion {
  const VolQuestion({
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
  final VolKind kind;
  final VolScene scene;
  final String question;
  final String hint;
  final String answer;

  /// Null when the options are words.
  final Frac? answerValue;
  final List<VolTrap> traps;
  final List<String> options;

  /// The number behind each option (numeric questions only).
  final List<Frac>? optionValues;
  final List<VolStep> steps;
  final String insight;

  /// The numbers behind the question, for recomputing in tests.
  final Map<String, Object> params;

  bool get numeric => optionValues != null;

  int get answerIndex => options.indexOf(answer);

  String feedbackFor(String picked) => picked == answer
      ? insight
      : traps.firstWhere((t) => t.label == picked).why;
}

class VolDifficulty {
  static List<VolKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [VolKind.direction],
    2 => const [VolKind.atm],
    3 => const [VolKind.scaling],
    4 => const [VolKind.digitalPrice, VolKind.digitalChance],
    5 => const [VolKind.spreadDigital, VolKind.spreadCount],
    6 => const [VolKind.inOut, VolKind.farBarrier, VolKind.cap],
    7 => const [VolKind.dOne, VolKind.dTwo],
    8 => const [VolKind.delta, VolKind.hedge],
    9 => const [VolKind.impliedVol, VolKind.richer],
    _ => const [
      VolKind.digitalPrice,
      VolKind.digitalChance,
      VolKind.spreadDigital,
      VolKind.spreadCount,
      VolKind.inOut,
      VolKind.farBarrier,
      VolKind.cap,
      VolKind.dOne,
      VolKind.dTwo,
      VolKind.delta,
      VolKind.hedge,
      VolKind.impliedVol,
      VolKind.richer,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'which way prices move',
    2 => 'the at-the-money shortcut',
    3 => 'scaling with time and volatility',
    4 => 'digital options and N(d₂)',
    5 => 'call spreads as digitals',
    6 => 'barrier options',
    7 => 'd₁ and d₂',
    8 => 'delta and hedging',
    9 => 'implied volatility',
    _ => 'the whole lab',
  };
}

// ---- writing numbers ----------------------------------------------------------

/// How a question's options are written. Every option in a question uses
/// the same one, so the format never gives the answer away.
enum VolFormat {
  /// Dollars and cents: "$38.00", "−$1.50".
  usd,

  /// Two decimals: "0.40", "−0.38".
  dec,

  /// A whole percentage of a fraction: 0.2 is "20%".
  pct,

  /// A whole count: "110".
  count,
}

bool _exact(Frac v, VolFormat f) => switch (f) {
  VolFormat.count => v.d == 1,
  _ => (v * Frac(100)).d == 1,
};

String _two(int hundredths) {
  final a = hundredths.abs();
  return '${a ~/ 100}.${(a % 100).toString().padLeft(2, '0')}';
}

/// "$38.00", "−$1.50".
String usd(Frac f) {
  final c = (f * Frac(100)).n;
  return '${c < 0 ? '−' : ''}\$${_two(c)}';
}

/// "0.40", "−0.38".
String dec2(Frac f) {
  final c = (f * Frac(100)).n;
  return '${c < 0 ? '−' : ''}${_two(c)}';
}

/// "20%" for 0.2.
String pct(Frac f) {
  final p = (f * Frac(100)).n;
  return '${p < 0 ? '−' : ''}${p.abs()}%';
}

String formatAs(Frac v, VolFormat f) => switch (f) {
  VolFormat.usd => usd(v),
  VolFormat.dec => dec2(v),
  VolFormat.pct => pct(v),
  VolFormat.count => '${v.n}',
};

/// Short dollars for chips and steps: "$100", "$102.50", "$0.45".
String dollars(Frac f) {
  if (f.d == 1) return '${f.n < 0 ? '−' : ''}\$${f.n.abs()}';
  return usd(f);
}

/// A tidy number for steps: "0.2", "0.25", "−0.1", "2".
String tidy(Frac f) {
  if (f.d == 1) return '${f.n < 0 ? '−' : ''}${f.n.abs()}';
  var s = f.value.abs().toStringAsFixed(4);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return '${f < Frac.zero ? '−' : ''}$s';
}

/// Two decimals in `MathText` shorthand: "0.10", "-0.05".
String mathDec(Frac f) => dec2(f).replaceAll('−', '-');

/// The standard normal chance of falling below [x] (Abramowitz–Stegun).
double normCdf(double x) {
  final z = x.abs() / sqrt2;
  final t = 1 / (1 + 0.3275911 * z);
  final poly =
      ((((1.061405429 * t - 1.453152027) * t + 1.421413741) * t - 0.284496736) *
              t +
          0.254829592) *
      t;
  final erf = 1 - poly * exp(-z * z);
  return x >= 0 ? (1 + erf) / 2 : (1 - erf) / 2;
}

/// The x with [normCdf] x = [p], by halving.
double normInv(double p) {
  var lo = -6.0, hi = 6.0;
  for (var i = 0; i < 60; i++) {
    final mid = (lo + hi) / 2;
    normCdf(mid) < p ? lo = mid : hi = mid;
  }
  return (lo + hi) / 2;
}

/// Months as words: "3 months", "1 year".
String months(int m) => switch (m) {
  1 => '1 month',
  12 => '1 year',
  _ when m % 12 == 0 => '${m ~/ 12} years',
  _ => '$m months',
};

/// Months for a chart tick: "3 mo", "1 yr".
String _monthsShort(int m) => m % 12 == 0 ? '${m ~/ 12} yr' : '$m mo';

/// A time in years as words: 1/4 is "3 months".
String years(Frac t) => months((t * Frac(12)).n);

// ---- the generator ------------------------------------------------------------

class _Draft {
  const _Draft({
    required this.scene,
    required this.question,
    required this.hint,
    required this.steps,
    required this.insight,
    required this.params,
    this.value,
    this.format = VolFormat.usd,
    this.unit,
    this.traps = const [],
    this.fits,
    this.negative = false,
    this.answerWord,
    this.wrong = const [],
  });

  final VolScene scene;
  final String question;
  final String hint;
  final List<VolStep> steps;
  final String insight;
  final Map<String, Object> params;

  /// Numeric questions: the answer, how it's written, the near-miss step,
  /// the named slips and any bounds on the options.
  final Frac? value;
  final VolFormat format;
  final Frac? unit;
  final List<(Frac, String)> traps;
  final bool Function(Frac v)? fits;

  /// Negative options make sense (d₁, d₂, a put's delta).
  final bool negative;

  /// Word questions: the answer and the wrong ones with their slips.
  final String? answerWord;
  final List<(String, String)> wrong;
}

/// Base numbers for the "which way" questions: S = K = 100, 20% vol,
/// 1 year, rates 3%.
const _moves = [
  ('Stock up', 1, -1),
  ('Stock down', -1, 1),
  ('Higher strike', -1, 1),
  ('Lower strike', 1, -1),
  ('Volatility up', 1, 1),
  ('Volatility down', -1, -1),
  ('More time', 1, 0),
  ('Less time', -1, 0),
  ('Rates up', 1, -1),
  ('Rates down', -1, 1),
];

const _callWhy = {
  'Stock up':
      'A call pays the stock above the strike, so a higher stock '
      'raises it.',
  'Stock down':
      'A call pays the stock above the strike, so a lower stock '
      'lowers it.',
  'Higher strike':
      'A higher strike leaves less above it to pay: the call '
      'is worth less.',
  'Lower strike':
      'A lower strike leaves more above it to pay: the call is '
      'worth more.',
  'Volatility up':
      'Bigger swings help a long call: its gains grow but its '
      'loss stays capped.',
  'Volatility down':
      'Volatility helps a long option. Smaller swings mean '
      'smaller gains: the call is worth less.',
  'More time':
      'More time gives the stock longer to climb above the '
      'strike: the call is worth more.',
  'Less time':
      'Less time means less chance of a big move: the call is '
      'worth less.',
  'Rates up':
      'Higher rates shrink today\'s cost of the strike you pay '
      'later: the call gains.',
  'Rates down':
      'Lower rates raise today\'s cost of the strike you pay '
      'later: the call loses.',
};

const _putWhy = {
  'Stock up':
      'A put pays the amount below the strike, so a higher stock '
      'lowers it.',
  'Stock down':
      'A put pays the amount below the strike, so a lower stock '
      'raises it.',
  'Higher strike':
      'A higher strike leaves more room below it: the put is '
      'worth more.',
  'Lower strike':
      'A lower strike leaves less room below it: the put is '
      'worth less.',
  'Volatility up':
      'Bigger swings help a long put: its gains grow but its '
      'loss stays capped.',
  'Volatility down':
      'Volatility helps a long option. Smaller swings mean '
      'smaller gains: the put is worth less.',
  'Rates up':
      'Higher rates shrink today\'s value of the strike you get '
      'later: the put loses.',
  'Rates down':
      'Lower rates raise today\'s value of the strike you get '
      'later: the put gains.',
};

/// Stock paths for the barrier pictures, as fractions of the way from
/// today's price to the barrier: one touches it, one stays away.
const _hitShape = [
  0.0,
  0.3,
  0.12,
  0.45,
  0.32,
  0.68,
  0.52,
  1.0,
  0.74,
  0.5,
  0.62,
  0.36,
];
const _missShape = [
  0.0,
  -0.18,
  0.1,
  -0.06,
  -0.3,
  -0.12,
  0.22,
  0.04,
  -0.26,
  -0.1,
  -0.36,
  -0.2,
];

class VolGenerator {
  const VolGenerator();

  static const _again = 'Check the numbers again: see the working.';

  VolQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = VolDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final draft = switch (kind) {
      VolKind.direction => _direction(rng),
      VolKind.atm => _atm(rng),
      VolKind.scaling => _scaling(rng),
      VolKind.digitalPrice => _digitalPrice(rng),
      VolKind.digitalChance => _digitalChance(rng),
      VolKind.spreadDigital => _spreadDigital(rng),
      VolKind.spreadCount => _spreadCount(rng),
      VolKind.inOut => _inOut(rng),
      VolKind.farBarrier => _farBarrier(rng),
      VolKind.cap => _cap(rng),
      VolKind.dOne => _dOne(rng),
      VolKind.dTwo => _dTwo(rng),
      VolKind.delta => _delta(rng),
      VolKind.hedge => _hedge(rng),
      VolKind.impliedVol => _implied(rng),
      VolKind.richer => _richer(rng),
    };

    final List<VolTrap> chosen;
    final String answer;
    if (draft.value case final a?) {
      chosen = _numeric(draft, a, rng);
      answer = formatAs(a, draft.format);
    } else {
      answer = draft.answerWord!;
      chosen = _shuffled(answer, draft.wrong, rng);
    }

    return VolQuestion(
      level: level,
      seed: seed,
      kind: kind,
      scene: draft.scene,
      question: draft.question,
      hint: draft.hint,
      answer: answer,
      answerValue: draft.value,
      traps: [
        for (final x in chosen)
          if (x.label != answer) x,
      ],
      options: [for (final x in chosen) x.label],
      optionValues: draft.value == null
          ? null
          : [for (final x in chosen) x.value!],
      steps: draft.steps,
      insight: draft.insight,
      params: draft.params,
    );
  }

  // ---- options ------------------------------------------------------------

  /// A near-miss step about a sixth of [a], so three steps down stay above 0.
  static Frac _unitFor(Frac a, VolFormat f) {
    final steps = switch (f) {
      VolFormat.usd => const [1, 2, 5, 10, 20, 25, 50, 100, 200, 500, 1000],
      VolFormat.count => const [100, 200, 500, 1000, 2000, 2500, 5000],
      _ => const [1, 2, 5],
    };
    final size = a < Frac.zero ? Frac.zero - a : a;
    var best = steps.first;
    for (final s in steps) {
      if (Frac(s * 6, 100) <= size) best = s;
    }
    return Frac(best, 100);
  }

  /// Four numbers, smallest first, the answer's rank uniform.
  List<VolTrap> _numeric(_Draft draft, Frac a, Random rng) {
    VolTrap t(Frac v, String why) => VolTrap(formatAs(v, draft.format), why, v);
    bool fits(Frac v) {
      if (!draft.negative && v <= Frac.zero) return false;
      if (!_exact(v, draft.format)) return false;
      return draft.fits?.call(v) ?? true;
    }

    final unit = draft.unit ?? _unitFor(a, draft.format);
    final fillers = [
      for (final k in [1, 2, 3])
        for (final sign in [1, -1])
          if (fits(a + unit * Frac(sign * k)))
            t(a + unit * Frac(sign * k), _again),
    ]..shuffle(rng);
    final named = [
      for (final (v, why) in draft.traps)
        if (v != a && fits(v)) t(v, why),
    ];
    return balancedOptions(
      t(a, ''),
      named,
      fillers,
      rng,
      compare: (x, y) => x.value!.compareTo(y.value!),
    );
  }

  /// Words: shuffled, the answer anywhere.
  static List<VolTrap> _shuffled(
    String answer,
    List<(String, String)> wrong,
    Random rng,
  ) {
    final pool = [...wrong]..shuffle(rng);
    final chosen = <VolTrap>[];
    for (final (s, why) in pool) {
      if (s == answer || chosen.any((c) => c.label == s)) continue;
      chosen.add(VolTrap(s, why));
      if (chosen.length == 3) break;
    }
    return chosen..insert(rng.nextInt(chosen.length + 1), VolTrap(answer, ''));
  }

  // ---- helpers ------------------------------------------------------------

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  /// A whole number from [lo] to [hi].
  static int _r(Random rng, int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

  /// Hundredths: 40 is 0.40.
  static Frac _c(int hundredths) => Frac(hundredths, 100);

  /// √T for the tidy times used here.
  static Frac _root(Frac t) {
    for (final (sq, r) in [
      (Frac(1, 4), Frac(1, 2)),
      (Frac.one, Frac.one),
      (Frac(4), Frac(2)),
      (Frac(9), Frac(3)),
      (Frac(1, 9), Frac(1, 3)),
    ]) {
      if (t == sq) return r;
    }
    throw ArgumentError('no tidy root for $t');
  }

  static const _atmRule = r'C \approx 0.4 \cdot S \cdot \sigma \sqrt{T}';

  /// A payoff line for one option, from 60% to 140% of the strike.
  static List<(double, double)> _hockey(bool call, double k) => call
      ? [(k * 0.6, 0), (k, 0), (k * 1.4, k * 0.4)]
      : [(k * 0.6, k * 0.4), (k, 0), (k * 1.4, 0)];

  static List<(double, double)> _path(List<double> shape, double s, double b) =>
      [for (final (i, f) in shape.indexed) (i.toDouble(), s + f * (b - s))];

  // ---- level 1: which way -------------------------------------------------

  _Draft _direction(Random rng) {
    final call = rng.nextBool();
    final raise = rng.nextBool();
    final want = raise ? 1 : -1;
    int effect((String, int, int) m) => call ? m.$2 : m.$3;
    final good = [
      for (final m in _moves)
        if (effect(m) == want) m.$1,
    ];
    final bad = [
      for (final m in _moves)
        if (effect(m) == -want) m.$1,
    ];
    final ans = _pick(rng, good);
    final why = call ? _callWhy : _putWhy;
    final name = call ? 'call' : 'put';
    return _Draft(
      scene: VolScene(
        chips: [call ? 'European call' : 'European put', 'No dividends'],
        caption: call
            ? 'A call pays S − K above the strike'
            : 'A put pays K − S below the strike',
        picture: VolPicture(
          visual: VolVisual.payoff,
          title: 'What the $name pays at expiry',
          line: _hockey(call, 100),
          ticks: const [(100, 'K')],
          axis: 'stock at expiry',
        ),
      ),
      question:
          'Only one thing changes. Which one ${raise ? 'raises' : 'lowers'} '
          'the $name\'s price?',
      hint: 'Ask what makes a big payoff more likely, or cheaper to lock in.',
      answerWord: ans,
      wrong: [for (final b in bad) (b, why[b]!)],
      steps: [
        VolStep(
          call
              ? 'A call pays the stock minus the strike at expiry, or nothing.'
              : 'A put pays the strike minus the stock at expiry, or nothing.',
        ),
        VolStep('$ans. ${why[ans]!}'),
        VolStep(
          'Each of the other three moves the price the other way: it '
          '${raise ? 'falls' : 'rises'}.',
        ),
      ],
      insight: 'Right. ${why[ans]!}',
      params: {'call': call, 'raise': raise, 'answer': ans},
    );
  }

  // ---- level 2: the 0.4 rule ----------------------------------------------

  _Draft _atm(Random rng) {
    late int s, vol;
    late Frac t, sig, rt, a;
    do {
      s = _pick(rng, const [50, 80, 100, 120, 150, 200, 250]);
      vol = _pick(rng, const [10, 15, 20, 25, 30, 40, 50]);
      t = _pick(rng, [Frac(1, 4), Frac.one, Frac(4)]);
      sig = Frac(vol, 100);
      rt = _root(t);
      a = Frac(2, 5) * Frac(s) * sig * rt;
    } while ((sig * rt).value > 1 || !_exact(a, VolFormat.usd));
    final big = Frac(s) * sig * rt;
    final oneYear = t != Frac.one;
    return _Draft(
      scene: VolScene(
        chips: [
          'S = K = ${dollars(Frac(s))}',
          'σ $vol%',
          'T ${years(t)}',
          'Rates 0',
        ],
        lines: const [_atmRule],
        caption: 'An at-the-money call',
        picture: VolPicture(
          visual: VolVisual.curve,
          title: 'At the money, price against volatility',
          line: [(0, 0), (vol * 1.6, a.value * 1.6)],
          marks: [VolMark(vol.toDouble(), a.value, '?', unknown: true)],
          ticks: [(0, '0'), (vol.toDouble(), '$vol%')],
          axis: 'volatility',
        ),
      ),
      question: 'Using the rule, roughly what\'s the call worth?',
      hint: 'σ as a decimal, T in years, then multiply.',
      value: a,
      traps: [
        (big, 'That leaves out the 0.4. It comes from 1/√(2π), about 0.4.'),
        if (oneYear)
          (
            Frac(2, 5) * Frac(s) * sig * t,
            'That scales with T. Prices grow with √T, the square root of '
                'time.',
          ),
        if (oneYear)
          (
            Frac(2, 5) * Frac(s) * sig,
            'That treats it as 1 year. Multiply by √T = ${tidy(rt)} too.',
          ),
        (
          Frac(4, 5) * big,
          '0.8 × S × σ√T prices a straddle, a call plus a put. One call '
              'is 0.4.',
        ),
        (
          Frac(1, 5) * big,
          'That halves the rule. 0.4 × S × σ√T is already one call; the '
              'straddle is 0.8.',
        ),
        (
          Frac(2, 5) * Frac(s) * sig * sig * t,
          'That uses σ²T, the variance. The price goes with σ√T.',
        ),
      ],
      steps: [
        VolStep(
          'T = ${tidy(t)} year${t == Frac.one ? '' : 's'}, so '
          '√T = ${tidy(rt)}; σ = ${tidy(sig)}.',
        ),
        VolStep('σ√T = ${tidy(sig)} × ${tidy(rt)} = ${tidy(sig * rt)}.'),
        VolStep(
          '0.4 × ${dollars(Frac(s))} × ${tidy(sig * rt)} = ${usd(a)}.',
          '0.4 * $s * ${tidy(sig * rt)} = ${usd(a).substring(1)}',
        ),
      ],
      insight:
          'Right: at the money, C ≈ 0.4 × S × σ√T, because 1/√(2π) is '
          'about 0.4.',
      params: {'s': s, 'sigma': sig, 't': t},
    );
  }

  // ---- level 3: scaling ---------------------------------------------------

  _Draft _scaling(Random rng) {
    const prices = [180, 216, 288, 324, 360, 432, 540, 720];
    final p = _c(_pick(rng, prices));
    final type = rng.nextInt(20); // 0–8 time, 9–15 vol, 16–19 both
    var t0 = 6, t1 = 6, s0 = 20, s1 = 20;
    if (type < 9 || type >= 16) {
      (t0, t1) = type >= 16
          ? _pick(rng, const [(3, 12), (12, 3), (6, 24), (24, 6)])
          : _pick(rng, const [
              (3, 12),
              (1, 4),
              (6, 24),
              (1, 9),
              (4, 36),
              (12, 3),
              (24, 6),
              (36, 4),
            ]);
    } else {
      t0 = t1 = _pick(rng, const [3, 6, 12]);
    }
    if (type >= 9) {
      (s0, s1) = type >= 16
          ? _pick(rng, const [(20, 40), (40, 20), (15, 30), (30, 15)])
          : _pick(rng, const [
              (20, 40),
              (30, 60),
              (20, 30),
              (40, 60),
              (24, 36),
              (40, 20),
              (30, 15),
              (24, 12),
            ]);
    } else {
      s0 = s1 = _pick(rng, const [20, 25, 30]);
    }
    final tf = Frac(t1, t0), vf = Frac(s1, s0);
    final sf = _root(tf);
    final a = p * vf * sf;
    final timeMoves = t0 != t1, volMoves = s0 != s1;
    final both = timeMoves && volMoves;
    final up = a > p;
    final traps = <(Frac, String)>[
      if (timeMoves)
        (
          p * vf * tf,
          'That scales with T. The price grows with √T: T ${_times(tf)} '
              'means price ${_times(sf)}.',
        ),
      if (volMoves)
        (
          p * vf * vf * sf,
          'That squares the change in σ. At the money the price is '
              'straight-line in σ.',
        ),
      (
        p,
        'Time and volatility both move an option\'s price; it doesn\'t stay '
            'put.',
      ),
      if (a != p)
        (
          p / (vf * sf),
          'That goes the wrong way. More time or volatility makes a long '
              'option worth more; less makes it worth less.',
        ),
      if (both) ...[
        (p * vf, 'That forgets the time change: √T moves the price too.'),
        (p * sf, 'That forgets the volatility change: σ moves the price too.'),
      ],
    ];
    final String change;
    if (both) {
      change = '$s1% volatility and ${months(t1)} to expiry';
    } else if (timeMoves) {
      change = '${months(t1)} to expiry instead';
    } else {
      change = 'volatility at $s1% instead';
    }
    final VolPicture? picture;
    if (both) {
      picture = null;
    } else if (timeMoves) {
      final hi = max(t0, t1) * 1.2;
      picture = VolPicture(
        visual: VolVisual.curve,
        title: 'At the money, price against time',
        line: [
          for (var i = 0; i <= 40; i++)
            (hi * i * i / 1600, p.value * sqrt(hi * i * i / 1600 / t0)),
        ],
        marks: [
          VolMark(t0.toDouble(), p.value, usd(p)),
          VolMark(t1.toDouble(), a.value, '?', unknown: true),
        ],
        ticks: [
          (t0.toDouble(), _monthsShort(t0)),
          (t1.toDouble(), _monthsShort(t1)),
        ],
        axis: 'time to expiry',
      );
    } else {
      final hi = max(s0, s1) * 1.25;
      picture = VolPicture(
        visual: VolVisual.curve,
        title: 'At the money, price against volatility',
        line: [(0, 0), (hi, p.value * hi / s0)],
        marks: [
          VolMark(s0.toDouble(), p.value, usd(p)),
          VolMark(s1.toDouble(), a.value, '?', unknown: true),
        ],
        ticks: [(s0.toDouble(), '$s0%'), (s1.toDouble(), '$s1%')],
        axis: 'volatility',
      );
    }
    final timeStep = VolStep(
      'Time: ${months(t0)} → ${months(t1)}, so T ${_times(tf)} and √T '
      '${_times(sf)}.',
    );
    final volStep = VolStep('Volatility: $s0% → $s1%, so σ ${_times(vf)}.');
    return _Draft(
      scene: VolScene(
        chips: ['ATM call ${usd(p)}', 'σ $s0%', 'T ${months(t0)}', 'Rates 0'],
        lines: const [r'C \approx 0.4 \cdot S \cdot \sigma \sqrt{T}'],
        caption: 'At the money: strike = stock price',
        picture: picture,
      ),
      question:
          'Same stock and strike. Roughly what\'s the call worth with '
          '$change?',
      hint: 'At the money the price goes with σ × √T.',
      value: a,
      traps: traps,
      steps: [
        if (both) ...[
          timeStep,
          volStep,
        ] else if (timeMoves) ...[
          timeStep,
          const VolStep('The price goes with √T, so it scales the same way.'),
        ] else ...[
          volStep,
          const VolStep('The price is straight-line in σ: same factor.'),
        ],
        VolStep('${usd(p)} ${_times(vf * sf)} = ${usd(a)}.'),
      ],
      insight: up
          ? 'Right: the at-the-money price scales with σ√T, so it rises.'
          : 'Right: the at-the-money price scales with σ√T.',
      params: {'p': p, 't0': t0, 't1': t1, 's0': s0, 's1': s1},
    );
  }

  // ---- level 4: digitals ----------------------------------------------------

  _Draft _digitalPrice(Random rng) {
    late int q, k;
    late Frac df, n1, n2, a;
    do {
      q = _pick(rng, const [100, 100, 100, 50, 10]);
      k = _pick(rng, const [95, 100, 105, 110]);
      df = _c(_pick(rng, const [100, 98, 95, 95, 90]));
      n2 = _c(2 * _r(rng, 20, 36));
      n1 = n2 + _c(2 * _r(rng, 2, 7));
      a = Frac(q) * df * n2;
    } while (!_exact(a, VolFormat.usd));
    final noRates = df == Frac.one;
    final qd = Frac(q) * df;
    return _Draft(
      scene: VolScene(
        chips: ['Pays ${dollars(Frac(q))} above ${dollars(Frac(k))}'],
        lines: [
          'N(d_1) = ${mathDec(n1)}',
          'N(d_2) = ${mathDec(n2)}',
          noRates ? 'r = 0' : 'e^{-rT} = ${mathDec(df)}',
        ],
        caption: 'A digital (cash-or-nothing) call',
        picture: VolPicture(
          visual: VolVisual.payoff,
          title: 'What the digital pays at expiry',
          line: [
            (k * 0.7, 0),
            (k.toDouble(), 0),
            (k.toDouble(), q.toDouble()),
            (k * 1.3, q.toDouble()),
          ],
          sparkLine: true,
          marks: [VolMark(k * 1.3, q.toDouble(), dollars(Frac(q)))],
          ticks: [(k.toDouble(), dollars(Frac(k)))],
          axis: 'stock at expiry',
        ),
      ),
      question:
          'It pays ${dollars(Frac(q))} if the stock ends above '
          '${dollars(Frac(k))}, nothing otherwise. What\'s it worth today?',
      hint: 'Payout × the chance of ending in the money × the discount.',
      value: a,
      fits: (v) => v < Frac(q),
      traps: [
        (
          qd * n1,
          'That uses N(d₁). The risk-neutral chance of ending in the money '
              'is N(d₂).',
        ),
        if (!noRates)
          (
            Frac(q) * n2,
            'That forgets to discount: the cash comes at expiry, so '
                'multiply by e^(−rT).',
          ),
        (
          qd * (Frac.one - n2),
          '1 − N(d₂) is the chance of ending below the strike: that prices '
              'the digital put.',
        ),
        if (!noRates)
          (
            Frac(q) * n1,
            'Two slips: N(d₁) instead of N(d₂), and no discounting.',
          ),
        (
          qd * (Frac.one - n1),
          'That\'s 1 − N(d₁): the wrong N and the wrong side of the strike.',
        ),
        if (!noRates)
          (qd * df * n2, 'That discounts twice. Once is enough: × e^(−rT).'),
      ],
      steps: [
        VolStep(
          'The risk-neutral chance of ending above ${dollars(Frac(k))} is '
          'N(d₂) = ${dec2(n2)}.',
        ),
        VolStep(
          'Expected payout: ${dollars(Frac(q))} × ${dec2(n2)} = '
          '${usd(Frac(q) * n2)}.',
        ),
        VolStep(
          noRates
              ? 'Rates are 0, so there\'s nothing to discount: ${usd(a)}.'
              : 'Discount it: ${usd(Frac(q) * n2)} × ${tidy(df)} = '
                    '${usd(a)}.',
          noRates ? null : 'e^{-rT} \\cdot $q \\cdot N(d_2)',
        ),
      ],
      insight:
          'Right: a cash-or-nothing call is worth e^(−rT) × N(d₂) per \$1 of '
          'payout.',
      params: {'q': q, 'k': k, 'df': df, 'n1': n1, 'n2': n2},
    );
  }

  _Draft _digitalChance(Random rng) {
    final k = _pick(rng, const [95, 100, 105, 110]);
    final df = _c(_pick(rng, const [98, 96, 95, 90]));
    final p = _c(_r(rng, 25, 75));
    final n1 = p + _c(_r(rng, 4, 12));
    final price = Frac(100) * df * p;
    final perDollar = df * p;
    return _Draft(
      scene: VolScene(
        chips: ['Pays \$100 above ${dollars(Frac(k))}', 'Costs ${usd(price)}'],
        lines: ['N(d_1) = ${mathDec(n1)}', 'e^{-rT} = ${mathDec(df)}'],
        caption: 'A digital call\'s price',
        picture: VolPicture(
          visual: VolVisual.bell,
          title: 'N(d₂): the area left of d₂',
          cut: normInv(p.value),
          cutLabel: 'd₂',
          areaLabel: '?',
        ),
      ),
      question:
          'What\'s the risk-neutral chance that the stock ends above '
          '${dollars(Frac(k))}?',
      hint: 'Price = payout × chance × discount. Undo each one.',
      value: p,
      format: VolFormat.dec,
      fits: (v) => v < Frac.one,
      traps: [
        (
          perDollar,
          'That\'s the price per \$1, still discounted. Divide by e^(−rT) '
              'to undo it.',
        ),
        (
          Frac.one - p,
          'That\'s the chance of ending below the strike, the other side.',
        ),
        (
          Frac.one - perDollar,
          'That\'s 1 minus the price per \$1. The price is the discounted '
              'chance of ending above.',
        ),
        (perDollar * df, 'That discounts again. Divide by e^(−rT) instead.'),
        (
          n1,
          'That\'s N(d₁), which belongs to delta. The chance of ending in '
              'the money is N(d₂).',
        ),
        (
          Frac.one - n1,
          'That\'s 1 − N(d₁): the wrong N and the wrong side of the strike.',
        ),
      ],
      steps: [
        const VolStep(
          'Price = payout × e^(−rT) × N(d₂).',
          r'100 \cdot e^{-rT} \cdot N(d_2)',
        ),
        VolStep('Per \$1: ${usd(price)} ÷ \$100 = ${tidy(perDollar)}.'),
        VolStep(
          'Undo the discount: ${tidy(perDollar)} ÷ ${tidy(df)} = '
          '${dec2(p)}.',
        ),
      ],
      insight:
          'Right: N(d₂) is the risk-neutral chance of ending in the money.',
      params: {'k': k, 'df': df, 'price': price, 'n1': n1},
    );
  }

  // ---- level 5: call spreads -------------------------------------------------

  _Draft _spreadDigital(Random rng) {
    late Frac h, p, c1, c2, a;
    late int q, k;
    do {
      final wide = rng.nextBool();
      h = wide ? Frac(2) : Frac(1, 2);
      p = wide ? _c(_r(rng, 25, 48)) : _c(2 * _r(rng, 13, 35));
      q = _pick(rng, const [10, 100]);
      k = _pick(rng, const [50, 100, 120]);
      c1 = _c(_r(rng, k == 50 ? 200 : 350, k == 50 ? 500 : 900));
      c2 = c1 - p * h;
      a = Frac(q) * p;
    } while (c2 < _c(50));
    final kh = Frac(k) + h;
    final pts = [
      (k - 2 * h.value, 0.0),
      (k.toDouble(), 0.0),
      (kh.value, h.value),
      (k + 3 * h.value, h.value),
    ];
    return _Draft(
      scene: VolScene(
        chips: [
          'Call at ${dollars(Frac(k))}: ${usd(c1)}',
          'Call at ${dollars(kh)}: ${usd(c2)}',
          'Rates 0',
        ],
        caption: 'Same stock, same expiry',
        picture: VolPicture(
          visual: VolVisual.payoff,
          title: 'The call spread and a digital',
          line: pts,
          ghost: [
            (k - 2 * h.value, 0),
            (k.toDouble(), 0),
            (k.toDouble(), h.value),
            (k + 3 * h.value, h.value),
          ],
          marks: [VolMark(k + 3 * h.value, h.value, dollars(h))],
          ticks: [(k.toDouble(), dollars(Frac(k))), (kh.value, dollars(kh))],
          axis: 'stock at expiry',
        ),
      ),
      question:
          'Roughly what\'s a digital call worth that pays ${dollars(Frac(q))} '
          'if the stock ends above ${dollars(Frac(k))}?',
      hint: 'Buy one call, sell the other: a ramp that pays up to the gap.',
      value: a,
      fits: (v) => v < Frac(q),
      traps: [
        (
          Frac(q) * p * h,
          'That forgets to divide by the ${dollars(h)} gap between the '
              'strikes.',
        ),
        (
          Frac(q) * p * h * h,
          'That multiplies by the gap. Divide by it: '
              '(C(K) − C(K + h)) ÷ h.',
        ),
        (Frac(q) * p / h, 'That divides by the gap twice. Once is enough.'),
        (
          p,
          'That\'s the price of a \$1 digital. This one pays '
              '${dollars(Frac(q))}.',
        ),
        (
          Frac(q) * (Frac.one - p),
          'That\'s the digital put: it pays when the stock ends below the '
              'strike.',
        ),
      ],
      steps: [
        VolStep(
          'The spread costs ${usd(c1)} − ${usd(c2)} = ${usd(p * h)} and pays '
          'up to ${dollars(h)}.',
        ),
        VolStep(
          'Per \$1 of payout: ${usd(p * h)} ÷ ${tidy(h)} = ${usd(p)}.',
          r'\frac{C(K) - C(K + h)}{h}',
        ),
        VolStep('For ${dollars(Frac(q))}: $q × ${usd(p)} = ${usd(a)}.'),
      ],
      insight:
          'Right: (C(K) − C(K + h)) ÷ h becomes a \$1 digital as the gap '
          'shrinks.',
      params: {'q': q, 'k': k, 'h': h, 'c1': c1, 'c2': c2},
    );
  }

  _Draft _spreadCount(Random rng) {
    late int q;
    late Frac h, n;
    do {
      q = _pick(rng, const [10, 20, 50, 100]);
      h = _pick(rng, [Frac(1, 2), Frac(2), Frac(5, 2), Frac(5)]);
      n = Frac(q) / h;
    } while (n.d != 1 || n < Frac(4));
    const k = 100;
    final kh = Frac(k) + h;
    final qd = q.toDouble();
    return _Draft(
      scene: VolScene(
        chips: [
          'Buy the ${dollars(Frac(k))} call',
          'Sell the ${dollars(kh)} call',
        ],
        caption: 'One call spread pays up to ${dollars(h)}',
        picture: VolPicture(
          visual: VolVisual.payoff,
          title: 'The spreads together and the digital',
          line: [
            (k - 2 * h.value, 0),
            (k.toDouble(), 0),
            (kh.value, qd),
            (k + 3 * h.value, qd),
          ],
          ghost: [
            (k - 2 * h.value, 0),
            (k.toDouble(), 0),
            (k.toDouble(), qd),
            (k + 3 * h.value, qd),
          ],
          marks: [VolMark(k + 3 * h.value, qd, dollars(Frac(q)))],
          ticks: [(k.toDouble(), dollars(Frac(k))), (kh.value, dollars(kh))],
          axis: 'stock at expiry',
        ),
      ),
      question:
          'How many of these spreads pay like a digital call that pays '
          '${dollars(Frac(q))} above ${dollars(Frac(k))}?',
      hint: 'Each spread pays nothing below the low strike, the gap above.',
      value: n,
      format: VolFormat.count,
      traps: [
        (
          Frac(q) * h,
          'That multiplies by the gap. Each spread pays up to '
              '${dollars(h)}, so divide.',
        ),
        (
          Frac(q),
          'That\'s one per dollar, but each spread pays ${dollars(h)} at '
              'the top, not \$1.',
        ),
        (
          n * Frac(2),
          'That counts calls: each spread is two, one bought and one sold.',
        ),
        (
          n / Frac(2),
          'Half enough: n spreads pay n × ${dollars(h)}, so you need '
              '${dollars(Frac(q))} ÷ ${dollars(h)}.',
        ),
      ],
      steps: [
        VolStep(
          'One spread pays nothing below ${dollars(Frac(k))} and '
          '${dollars(h)} above ${dollars(kh)}.',
        ),
        VolStep(
          'To pay ${dollars(Frac(q))} you need ${dollars(Frac(q))} ÷ '
          '${dollars(h)} of them.',
        ),
        VolStep('$q ÷ ${tidy(h)} = ${n.n} spreads.'),
      ],
      insight:
          'Right: ${n.n} tight spreads, each paying up to ${dollars(h)}, '
          'copy the digital.',
      params: {'q': q, 'h': h},
    );
  }

  // ---- level 6: barriers ----------------------------------------------------

  _Draft _inOut(Random rng) {
    final down = rng.nextBool();
    final b = down
        ? _pick(rng, const [80, 85, 90])
        : _pick(rng, const [115, 120, 125, 130]);
    final v = _c(25 * _r(rng, 24, 48));
    late Frac i;
    do {
      i = _c(5 * _r(rng, 6, (v.value * 20).round() - 6));
    } while (i <= Frac.zero || i >= v);
    final o = v - i;
    final askIn = rng.nextBool();
    final side = down ? 'down' : 'up';
    final given = askIn ? o : i;
    final a = askIn ? i : o;
    final givenName = askIn
        ? '${_cap1(side)}-and-out'
        : '${_cap1(side)}-and-in';
    final askName = askIn ? '$side-and-in' : '$side-and-out';
    final meaning = askIn
        ? 'only comes alive if the stock touches ${dollars(Frac(b))}'
        : 'dies if the stock ever touches ${dollars(Frac(b))}';
    return _Draft(
      scene: VolScene(
        chips: [
          'Vanilla call ${usd(v)}',
          '$givenName ${usd(given)}',
          'Barrier ${dollars(Frac(b))}',
        ],
        caption: 'Same strike \$100 and expiry',
        picture: VolPicture(
          visual: VolVisual.path,
          title: 'Two paths: one touches ${dollars(Frac(b))}',
          line: _path(_hitShape, 100, b.toDouble()),
          ghost: _path(_missShape, 100, b.toDouble()),
          sparkLine: true,
          barrierY: b.toDouble(),
          barrierLabel: 'barrier ${dollars(Frac(b))}',
          marks: const [VolMark(0, 100, '\$100')],
          axis: 'time',
        ),
      ),
      question:
          '${down ? 'A' : 'An'} $askName call $meaning. Otherwise it\'s the '
          'same. What\'s it '
          'worth?',
      hint: 'Every path either touches the barrier or it doesn\'t.',
      value: a,
      traps: [
        (
          v + given,
          'That\'s in-out parity backwards. Knock-in + knock-out = vanilla, '
              'so subtract.',
        ),
        (
          given,
          'That\'s the other barrier option\'s price. Together the two make '
              'the vanilla.',
        ),
        (
          v,
          'It only pays on some paths, so it\'s worth less than the '
              'vanilla.',
        ),
      ],
      steps: [
        VolStep(
          'On each path one of the two is alive: the knock-in if it touched '
          '${dollars(Frac(b))}, the knock-out if not.',
        ),
        const VolStep('So knock-in + knock-out = vanilla.'),
        VolStep('${usd(v)} − ${usd(given)} = ${usd(a)}.'),
      ],
      insight: 'Right: in + out = vanilla, whatever the barrier.',
      params: {'v': v, 'given': given},
    );
  }

  /// "× 4", "÷ 2", "× 1.5".
  static String _times(Frac f) {
    if (f.d == 1) return '× ${f.n}';
    if (f.n == 1) return '÷ ${f.d}';
    return '× ${tidy(f)}';
  }

  static String _cap1(String s) => s[0].toUpperCase() + s.substring(1);

  _Draft _farBarrier(Random rng) {
    final variant = rng.nextInt(4);
    final vol = _pick(rng, const [20, 30]);
    final vanilla = vol == 20 ? _c(797) : _c(1192);
    final far = variant < 2;
    final b = far ? _pick(rng, const [40, 50]) : _pick(rng, const [101, 102]);
    final knockIn = variant.isOdd;
    final name = switch (variant) {
      0 => 'down-and-out',
      1 => 'down-and-in',
      2 => 'up-and-out',
      _ => 'up-and-in',
    };
    // Far barriers are almost never touched; near ones almost always.
    final alive = far != knockIn;
    final ans = alive ? 'Nearly the vanilla' : 'Nearly zero';
    final bd = dollars(Frac(b));
    final distance = far
        ? 'a ${100 - b}% fall within the year'
        : 'a rise of just ${b - 100}%';
    final likely = far
        ? 'At $vol% volatility that almost never happens.'
        : 'Over a year at $vol% volatility it almost surely happens.';
    final touch = far ? 'almost never' : 'almost always';
    final meaning = knockIn
        ? 'only comes alive if the stock touches $bd'
        : 'dies if the stock ever touches $bd';
    return _Draft(
      scene: VolScene(
        chips: ['Stock \$100', 'Strike \$100', 'σ $vol%', 'T 1 year'],
        caption: 'Vanilla call ${usd(vanilla)}',
        picture: VolPicture(
          visual: VolVisual.path,
          title: 'A typical path and the barrier',
          line: _path(
            far ? _missShape : _hitShape,
            100,
            far ? 100 - 30 : b * 1.0,
          ),
          barrierY: b.toDouble(),
          barrierLabel: 'barrier $bd',
          marks: const [VolMark(0, 100, '\$100')],
          axis: 'time',
        ),
      ),
      question:
          '${variant < 2 ? 'A' : 'An'} $name call $meaning before expiry. '
          'Roughly what\'s it worth?',
      hint: 'How likely is the stock to touch the barrier in a year?',
      answerWord: ans,
      wrong: [
        if (alive)
          (
            'Nearly zero',
            far
                ? 'It only dies after $distance. $likely'
                : 'Touching $bd is almost certain, so it nearly always comes '
                      'alive.',
          )
        else
          (
            'Nearly the vanilla',
            far
                ? 'It only comes alive after $distance. $likely'
                : 'The stock is \$${b - 100} from $bd: it almost surely '
                      'touches it and the call dies.',
          ),
        (
          'About half the vanilla',
          'Half would need even odds of touching $bd. Here the stock '
              '$touch touches it.',
        ),
        (
          'More than the vanilla',
          'A barrier only takes payoffs away, so it\'s never worth more '
              'than the vanilla.',
        ),
      ],
      steps: [
        VolStep('From \$100, touching $bd needs $distance.'),
        VolStep(likely),
        VolStep(
          'So the call is ${alive ? 'nearly always alive' : 'nearly always dead'}'
          ': ${alive ? 'nearly the vanilla' : 'nearly zero'}.',
        ),
      ],
      insight:
          'Right: a barrier the stock ${far ? 'won\'t' : 'will'} reach '
          '${alive ? 'barely changes the vanilla' : 'leaves almost nothing'}.',
      params: {'variant': variant, 'b': b, 'vol': vol, 'vanilla': vanilla},
    );
  }

  _Draft _cap(Random rng) {
    final k = _pick(rng, const [90, 95, 100, 105, 110]);
    final g = _pick(rng, const [15, 20, 25, 30, 40]);
    final b = k + g;
    final s = k + _pick<int>(rng, const [-5, 0, 5, 10]);
    return _Draft(
      scene: VolScene(
        chips: [
          'Strike ${dollars(Frac(k))}',
          'Barrier ${dollars(Frac(b))}',
          'Stock now ${dollars(Frac(s))}',
        ],
        caption: 'An up-and-out call',
        picture: VolPicture(
          visual: VolVisual.payoff,
          title: 'What it pays if the barrier was never touched',
          line: [
            (k - g * 0.8, 0),
            (k.toDouble(), 0),
            (b - 0.001, g.toDouble()),
            (b.toDouble(), 0),
            (b + g * 0.5, 0),
          ],
          barrierX: b.toDouble(),
          barrierLabel: 'barrier',
          marks: [VolMark(b.toDouble(), g.toDouble(), '?', unknown: true)],
          ticks: [
            (k.toDouble(), dollars(Frac(k))),
            (b.toDouble(), dollars(Frac(b))),
          ],
          axis: 'stock at expiry',
        ),
      ),
      question:
          'It pays the stock minus ${dollars(Frac(k))} at expiry, but dies if '
          'the stock ever touches ${dollars(Frac(b))}. What\'s the most it '
          'could pay?',
      hint: 'To pay at all it must end above the strike, below the barrier.',
      value: Frac(g),
      traps: [
        (
          Frac(b),
          'That\'s the barrier. The call pays the stock minus the strike, so '
              'less than B − K.',
        ),
        if (s != k)
          (
            Frac(b - s),
            'That counts from today\'s price. The payoff counts from the '
                'strike.',
          ),
        (
          Frac(k),
          'That\'s the strike. The payoff is how far the stock ends above '
              'it.',
        ),
        if (s > k)
          (
            Frac(s - k),
            'That\'s what it pays if the stock stays put. It can pay more, '
                'up to just under the barrier.',
          ),
      ],
      unit: Frac(5),
      steps: [
        VolStep(
          'To pay anything, the stock must end above ${dollars(Frac(k))}.',
        ),
        VolStep(
          'It must also stay below ${dollars(Frac(b))} the whole time, or the '
          'call dies.',
        ),
        VolStep(
          'So it pays less than ${dollars(Frac(b))} − ${dollars(Frac(k))} = '
          '${usd(Frac(g))}.',
        ),
      ],
      insight:
          'Right: the barrier caps the payoff at B − K, so the price is below '
          'that too.',
      params: {'k': k, 'b': b, 's': s},
    );
  }

  // ---- level 7: d₁ and d₂ ---------------------------------------------------

  static const _d1Rule =
      r'd_1 = \frac{\ln(S/K) + \frac{1}{2}\sigma^2 T}{\sigma \sqrt{T}}';
  static const _d2Rule = r'd_2 = d_1 - \sigma \sqrt{T}';

  /// ln(S/K), σ and T with d₁ to two places.
  ({Frac l, Frac sig, Frac t, Frac v, Frac d1}) _dParams(
    Random rng, {
    bool longOrShort = false,
  }) {
    while (true) {
      final l = _c(_pick(rng, const [0, 0, 5, 10, -10, 20, -5, 15, -20]));
      final sig = _c(_pick(rng, const [10, 20, 25, 30, 40, 50]));
      final t = longOrShort
          ? _pick(rng, [Frac(1, 4), Frac(4)])
          : _pick(rng, [Frac(1, 4), Frac.one, Frac(4)]);
      final v = sig * _root(t);
      if (v.value > 1) continue;
      final d1 = l / v + v / Frac(2);
      if (!_exact(d1, VolFormat.dec)) continue;
      return (l: l, sig: sig, t: t, v: v, d1: d1);
    }
  }

  static List<String> _dChips(Frac sig, Frac t) => [
    'σ ${pct(sig)}',
    'T ${years(t)}',
    'Rates 0',
  ];

  static VolPicture _dBell(String name, Frac d) => VolPicture(
    visual: VolVisual.bell,
    title: '$name on the bell curve',
    cut: d.value,
    cutLabel: '$name = ${dec2(d)}',
    areaLabel: 'N($name)',
  );

  _Draft _dOne(Random rng) {
    final (:l, :sig, :t, :v, :d1) = _dParams(rng);
    final top = l + v * v / Frac(2);
    return _Draft(
      scene: VolScene(
        chips: _dChips(sig, t),
        lines: [_d1Rule, '\\ln(S/K) = ${mathDec(l)}'],
        caption: 'Black–Scholes, piece by piece',
        picture: _dBell('d₁', d1),
        pictureOnCard: false,
      ),
      question: 'What\'s d₁?',
      hint: 'Work out σ√T first; it\'s on the bottom.',
      value: d1,
      format: VolFormat.dec,
      negative: true,
      unit: _c(5),
      traps: [
        (l / v - v / Frac(2), 'That subtracts ½σ²T: that\'s d₂. d₁ adds it.'),
        (l / v + v, 'That forgets the ½ in ½σ²T.'),
        if (t != Frac.one)
          (top / sig, 'That divides by σ alone. Divide by σ√T.'),
        if (l != Frac.zero) ...[
          (l + v / Frac(2), 'Divide all of the top by σ√T, ln(S/K) too.'),
          (v / Frac(2), 'That drops ln(S/K). It\'s 0 only at the money.'),
        ] else
          (top, 'That\'s the top alone. Divide it by σ√T.'),
      ],
      steps: [
        VolStep('σ√T = ${tidy(sig)} × ${tidy(_root(t))} = ${tidy(v)}.'),
        VolStep(
          'Top: ${tidy(l)} + ½ × ${tidy(v)}² = ${tidy(top)}.',
          '\\ln(S/K) + \\frac{1}{2}\\sigma^2 T = ${tidy(top).replaceAll('−', '-')}',
        ),
        VolStep('d₁ = ${tidy(top)} ÷ ${tidy(v)} = ${dec2(d1)}.'),
      ],
      insight: 'Right: d₁ = (ln(S/K) + ½σ²T) ÷ σ√T.',
      params: {'l': l, 'sigma': sig, 't': t},
    );
  }

  _Draft _dTwo(Random rng) {
    final fromD1 = rng.nextBool();
    final (:l, :sig, :t, :v, :d1) = _dParams(rng, longOrShort: fromD1);
    final d2 = d1 - v;
    final rt = _root(t);
    final top = l + v * v / Frac(2);
    return _Draft(
      scene: VolScene(
        chips: _dChips(sig, t),
        lines: fromD1
            ? [_d2Rule, 'd_1 = ${mathDec(d1)}']
            : [_d1Rule, _d2Rule, '\\ln(S/K) = ${mathDec(l)}'],
        caption: 'Black–Scholes, piece by piece',
        picture: _dBell('d₂', d2),
        pictureOnCard: false,
      ),
      question: 'What\'s d₂?',
      hint: fromD1
          ? 'σ√T: volatility times the square root of time.'
          : 'Find d₁ first, then step down by σ√T.',
      value: d2,
      format: VolFormat.dec,
      negative: true,
      unit: _c(5),
      traps: fromD1
          ? [
              (d1 + v, 'd₂ is d₁ minus σ√T, not plus.'),
              (d1 - sig, 'That subtracts σ. Subtract σ√T.'),
              (d1 - sig * t, 'That uses T, not √T: subtract σ√T.'),
              (d1 - v * v, 'That subtracts σ²T. Subtract σ√T.'),
              (d1 - v / Frac(2), 'That subtracts half of σ√T. Take all of it.'),
            ]
          : [
              (d1, 'That\'s d₁. d₂ = d₁ − σ√T.'),
              (l / v - v, 'That forgets the ½ in ½σ²T.'),
              (d1 + v, 'd₂ is d₁ minus σ√T, not plus.'),
              if (t != Frac.one)
                (
                  (l - sig * sig * t / Frac(2)) / sig,
                  'That divides by σ alone. Divide by σ√T.',
                ),
              if (l != Frac.zero)
                (
                  Frac.zero - v / Frac(2),
                  'That drops ln(S/K). It\'s 0 only at the money.',
                ),
            ],
      steps: fromD1
          ? [
              VolStep('√T = ${tidy(rt)}.'),
              VolStep('σ√T = ${tidy(sig)} × ${tidy(rt)} = ${tidy(v)}.'),
              VolStep('d₂ = ${dec2(d1)} − ${tidy(v)} = ${dec2(d2)}.'),
            ]
          : [
              VolStep('σ√T = ${tidy(sig)} × ${tidy(rt)} = ${tidy(v)}.'),
              VolStep(
                'd₁ = (${tidy(l)} + ½ × ${tidy(v)}²) ÷ ${tidy(v)} = '
                '${tidy(top)} ÷ ${tidy(v)} = ${dec2(d1)}.',
              ),
              VolStep('d₂ = ${dec2(d1)} − ${tidy(v)} = ${dec2(d2)}.'),
            ],
      insight: 'Right: d₂ = d₁ − σ√T, one σ√T further left.',
      params: {
        'l': l,
        'sigma': sig,
        't': t,
        'fromD1': fromD1,
        if (fromD1) 'd1': d1,
      },
    );
  }

  // ---- level 8: delta -------------------------------------------------------

  _Draft _delta(Random rng) {
    final call = rng.nextBool();
    final n1 = _c(_r(rng, 25, 80));
    final n2 = n1 - _c(_r(rng, 4, 10));
    final a = call ? n1 : n1 - Frac.one;
    final one = Frac.one;
    return _Draft(
      scene: VolScene(
        chips: [call ? 'European call' : 'European put', 'Rates 0'],
        lines: ['N(d_1) = ${mathDec(n1)}', 'N(d_2) = ${mathDec(n2)}'],
        caption: 'Delta: how much it moves per \$1 of stock',
      ),
      question: 'What\'s the ${call ? 'call' : 'put'}\'s delta?',
      hint: call
          ? 'One of the two N terms is the delta.'
          : 'Start from the call\'s delta; put–call parity does the rest.',
      value: a,
      format: VolFormat.dec,
      negative: true,
      unit: _c(5),
      fits: (v) => v != Frac.zero && v >= Frac(-1) && v <= one,
      traps: call
          ? [
              (
                n2,
                'N(d₂) is the chance of ending in the money, not the delta.',
              ),
              (n1 - one, 'That\'s the put\'s delta, N(d₁) − 1.'),
              (
                one - n1,
                'That\'s the size of the put\'s delta, not the call\'s.',
              ),
              (n2 - one, 'That uses N(d₂) and the put\'s − 1: two slips.'),
              (one - n2, 'That\'s 1 − N(d₂), the chance of ending below.'),
            ]
          : [
              (
                one - n1,
                'A put falls when the stock rises, so its delta is negative: '
                    'N(d₁) − 1.',
              ),
              (n1, 'That\'s the call\'s delta. The put\'s is N(d₁) − 1.'),
              (n2 - one, 'That uses N(d₂). Delta comes from N(d₁): N(d₁) − 1.'),
              (
                Frac.zero - n1,
                'That\'s −N(d₁). Put–call parity gives the put N(d₁) − 1.',
              ),
              (one - n2, 'That uses N(d₂), and a put\'s delta is negative.'),
            ],
      steps: call
          ? [
              const VolStep('A call\'s delta is N(d₁), the first N term.'),
              const VolStep(
                'N(d₂) is the chance of ending in the money: a different '
                'thing.',
              ),
              VolStep('Delta = ${dec2(n1)}.'),
            ]
          : [
              VolStep('A call\'s delta is N(d₁) = ${dec2(n1)}.'),
              const VolStep(
                'Put = call − stock + cash, so the put\'s delta is one less.',
                r'N(d_1) - 1',
              ),
              VolStep('${dec2(n1)} − 1 = ${dec2(a)}.'),
            ],
      insight: call
          ? 'Right: a call\'s delta is N(d₁).'
          : 'Right: a put\'s delta is N(d₁) − 1, always negative.',
      params: {'call': call, 'n1': n1},
    );
  }

  _Draft _hedge(Random rng) {
    final n = 100 * _r(rng, 1, 5);
    final n1 = _c(_r(rng, 25, 80));
    final n2 = n1 - _c(_r(rng, 4, 10));
    final kind = rng.nextInt(4);
    final call = kind < 2;
    final long = kind.isOdd;
    final one = Frac.one;
    final per = call ? n1 : one - n1;
    final a = Frac(n) * per;
    // Long calls and short puts gain with the stock: sell shares to hedge.
    final sell = call == long;
    final name = call ? 'calls' : 'puts';
    final delta = call ? n1 : n1 - one;
    final total = Frac(long ? n : -n) * delta;
    return _Draft(
      scene: VolScene(
        chips: ['${long ? 'Long' : 'Short'} $n $name', 'Each on one share'],
        lines: ['N(d_1) = ${mathDec(n1)}', 'N(d_2) = ${mathDec(n2)}'],
        caption: 'Delta-neutral: small stock moves don\'t change your value',
      ),
      question:
          'You ${long ? 'bought' : 'sold'} $n $name. How many shares do you '
          '${sell ? 'sell' : 'buy'} to be delta-neutral?',
      hint: 'Shares = options × delta. Get the delta\'s sign right.',
      value: a,
      format: VolFormat.count,
      traps: [
        (
          Frac(n) * (call ? n2 : one - n2),
          'That uses N(d₂). The hedge comes from delta, N(d₁).',
        ),
        call
            ? (
                Frac(n) * (one - n1),
                'That\'s the put\'s delta. A call\'s delta is N(d₁) = '
                    '${dec2(n1)}.',
              )
            : (
                Frac(n) * n1,
                'That\'s the call\'s delta. A put\'s is N(d₁) − 1 = '
                    '${dec2(n1 - one)}.',
              ),
        (
          Frac(n),
          'One share per option over-hedges: each moves only delta per \$1.',
        ),
        (
          Frac(n) * per / Frac(2),
          'Half a hedge. Each option needs its full delta in shares.',
        ),
      ],
      steps: [
        VolStep(
          call
              ? 'Each call\'s delta is N(d₁) = ${dec2(n1)}.'
              : 'Each put\'s delta is N(d₁) − 1 = ${dec2(n1 - one)}.',
        ),
        VolStep(
          '${long ? 'Long' : 'Short'} $n: $n × ${dec2(long ? delta : Frac.zero - delta)} '
          '= ${tidy(total)} share-equivalents.',
        ),
        VolStep('${sell ? 'Sell' : 'Buy'} ${a.n} shares to bring it to 0.'),
      ],
      insight: 'Right: hedge with options × delta shares, the opposite way.',
      params: {'n': n, 'n1': n1, 'call': call, 'long': long},
    );
  }

  // ---- level 9: implied volatility -----------------------------------------

  _Draft _implied(Random rng) {
    final straddle = rng.nextInt(20) < 7;
    late int s, vol;
    late Frac t, sig, rt, price;
    final factor = straddle ? Frac(4, 5) : Frac(2, 5);
    do {
      s = _pick(rng, const [50, 100, 200]);
      vol = 5 * _r(rng, 3, 12);
      t = _pick(rng, [Frac(1, 4), Frac.one, Frac(4)]);
      sig = Frac(vol, 100);
      rt = _root(t);
      price = factor * Frac(s) * sig * rt;
    } while ((sig * rt).value > 1 || !_exact(price, VolFormat.usd));
    final oneYear = t != Frac.one;
    final per = factor * Frac(s) * rt;
    final what = straddle ? 'straddle (a call plus a put)' : 'call';
    return _Draft(
      scene: VolScene(
        chips: [
          'ATM ${straddle ? 'straddle' : 'call'} ${usd(price)}',
          'S = K = ${dollars(Frac(s))}',
          'T ${years(t)}',
          'Rates 0',
        ],
        lines: [
          straddle
              ? r'C + P \approx 0.8 \cdot S \cdot \sigma \sqrt{T}'
              : _atmRule,
        ],
        caption: 'Implied volatility: what the price says',
        picture: VolPicture(
          visual: VolVisual.curve,
          title: 'Reading the price line backwards',
          line: [(0, 0), (vol * 1.6, price.value * 1.6)],
          marks: [VolMark(vol.toDouble(), price.value, usd(price))],
          ticks: [(0, '0'), (vol.toDouble(), '?')],
          axis: 'volatility',
        ),
      ),
      question:
          'The $what is at the money. What volatility does its price '
          'imply?',
      hint: 'Run the rule backwards: divide the price by everything else.',
      value: sig,
      format: VolFormat.pct,
      unit: vol >= 25 ? _c(5) : _c(2),
      fits: (v) => v <= Frac(3),
      traps: [
        if (oneYear) ...[
          (
            sig / rt,
            'That divides by T. Divide by √T: prices grow with the square '
                'root of time.',
          ),
          (sig * rt, 'That leaves out time. Divide by √T as well.'),
        ],
        if (straddle) ...[
          (
            sig * Frac(2),
            'That treats the straddle as one call. Call plus put is about '
                '0.8 × S × σ√T.',
          ),
          (sig * Frac(4, 5), 'That leaves out the 0.8 in 0.8 × S × σ√T.'),
        ] else ...[
          (sig * Frac(2, 5), 'That leaves out the 0.4 in 0.4 × S × σ√T.'),
          (
            sig / Frac(2),
            'That uses 0.8, the straddle\'s number. One call is 0.4.',
          ),
          (
            sig * Frac(2),
            'That uses 0.2. One call is 0.4 × S × σ√T; 0.2 is half of that.',
          ),
        ],
      ],
      steps: [
        VolStep(
          '${tidy(factor)} × ${dollars(Frac(s))} × √T = ${tidy(factor)} × '
          '${dollars(Frac(s))} × ${tidy(rt)} = ${dollars(per)} per unit of σ.',
        ),
        VolStep('σ ≈ ${usd(price)} ÷ ${dollars(per)} = ${tidy(sig)}.'),
        VolStep('That\'s ${pct(sig)}.'),
      ],
      insight:
          'Right: implied volatility is the σ that makes the formula match '
          'the price.',
      params: {'s': s, 't': t, 'price': price, 'straddle': straddle},
    );
  }

  _Draft _richer(Random rng) {
    final pick = rng.nextInt(3); // 0 A, 1 B, 2 same
    final (short, long) = _pick(rng, [
      (Frac(1, 4), Frac.one),
      (Frac(1, 4), Frac(4)),
      (Frac.one, Frac(4)),
    ]);
    // The richer one is the cheaper, so it has the shorter time.
    final aShort = pick == 0 || (pick == 2 && rng.nextBool());
    final ta = aShort ? short : long, tb = aShort ? long : short;
    final ra = _root(ta), rb = _root(tb);
    late int va, vb;
    late Frac ca, cb;
    while (true) {
      va = 5 * _r(rng, 3, 10);
      vb = pick == 2 ? va : 5 * _r(rng, 3, 10);
      if ((Frac(va, 100) * ra).value > 1 || (Frac(vb, 100) * rb).value > 1) {
        continue;
      }
      ca = Frac(40) * Frac(va, 100) * ra;
      cb = Frac(40) * Frac(vb, 100) * rb;
      if (pick == 0 && !(va > vb && ca < cb)) continue;
      if (pick == 1 && !(vb > va && cb < ca)) continue;
      break;
    }
    final ans = switch (pick) {
      0 => 'A is richer',
      1 => 'B is richer',
      _ => 'Same volatility',
    };
    final works = 'With C ≈ 0.4 × S × σ√T, A works out to $va% and B to $vb%.';
    final dearer = ca > cb ? 'A' : 'B';
    return _Draft(
      scene: VolScene(
        chips: [
          'A: ${years(ta)}, ${usd(ca)}',
          'B: ${years(tb)}, ${usd(cb)}',
          'S = K = \$100',
          'Rates 0',
        ],
        lines: const [_atmRule],
        caption: 'Two at-the-money calls on one stock',
      ),
      question: 'Which is richer: priced at the higher implied volatility?',
      hint: 'Turn each price into a σ with the rule, then compare.',
      answerWord: ans,
      wrong: [
        if (pick != 0)
          (
            'A is richer',
            pick == 2
                ? 'Both work out to $va%; $dearer just has more time.'
                : works,
          ),
        if (pick != 1)
          (
            'B is richer',
            pick == 2
                ? 'Both work out to $va%; $dearer just has more time.'
                : works,
          ),
        if (pick != 2) ('Same volatility', works),
        (
          'Can\'t tell',
          'The rule turns each at-the-money price into a σ: that\'s all you '
              'need.',
        ),
      ],
      steps: [
        VolStep(
          'A: ${usd(ca)} ÷ (0.4 × \$100 × ${tidy(ra)}) = $va%.',
          '\\sigma_A = \\frac{${usd(ca).substring(1)}}{40 \\cdot ${tidy(ra)}}',
        ),
        VolStep(
          'B: ${usd(cb)} ÷ (0.4 × \$100 × ${tidy(rb)}) = $vb%.',
          '\\sigma_B = \\frac{${usd(cb).substring(1)}}{40 \\cdot ${tidy(rb)}}',
        ),
        VolStep(
          pick == 2
              ? 'Both are $va%: the same volatility.'
              : '${pick == 0 ? 'A' : 'B'} has the higher volatility, though it '
                    'costs less.',
        ),
      ],
      insight: pick == 2
          ? 'Right: the dearer call just has more time; σ is the same.'
          : 'Right: compare σ, not price. More time makes an option dearer '
                'at the same σ.',
      params: {'ta': ta, 'tb': tb, 'ca': ca, 'cb': cb, 'pick': pick},
    );
  }
}
