import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum CalcKind {
  power,
  chainProduct,
  transcend,
  polyIntegral,
  expLogIntegral,
  limit,
  estimate,
  taylor,
  extremum,
}

/// What the answer is, so it can be checked another way.
enum CalcCheck {
  /// f′ at `params['at']`.
  slope,

  /// The formula for f′(x).
  derivative,

  /// The integral of [CalcQuestion.expr] from `lo` to `hi`.
  integral,

  /// The limit as the variable tends to `to` (or ∞ when `inf` is 1).
  limit,

  /// A Taylor estimate of f(a + h) of order `order`.
  estimate,

  /// The coefficient of x^k in the series about 0.
  coefficient,

  /// Where f peaks or dips (`ask` 0) or its best value (`ask` 1), with
  /// `want` 1 for a maximum and −1 for a minimum, on (lo, hi).
  extremum,
}

/// A small graph of the function on the card: the curve, and in spark
/// orange the point with its tangent, a second point, or the shaded area.
@immutable
class CalcGraph {
  const CalcGraph({
    required this.f,
    required this.lo,
    required this.hi,
    this.at,
    this.slope,
    this.target,
    this.from,
    this.to,
    this.labels = const {},
  });

  final double Function(double x) f;

  /// The x range drawn.
  final double lo, hi;

  /// A marked point on the curve, and the tangent through it.
  final double? at, slope;

  /// A second marked point (where an estimate lands).
  final double? target;

  /// The shaded area under the curve.
  final double? from, to;

  /// Labels under the x axis.
  final Map<double, String> labels;

  bool get shaded => from != null && to != null;
}

/// One line of working: plain words, then (optionally) a line of maths.
@immutable
class CalcStep {
  const CalcStep(this.text, [this.math]);

  final String text;

  /// [MathText] source.
  final String? math;
}

/// A wrong answer and the slip behind it.
@immutable
class CalcTrap {
  const CalcTrap(this.label, this.why, [this.value]);

  /// [MathText] source.
  final String label;
  final String why;

  /// For number answers.
  final Frac? value;
}

@immutable
class CalcQuestion {
  const CalcQuestion({
    required this.level,
    required this.seed,
    required this.kind,
    required this.check,
    required this.card,
    required this.caption,
    required this.graph,
    required this.reviewGraph,
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
    required this.expr,
    required this.variable,
    required this.params,
    required this.positive,
  });

  final int level;
  final int seed;
  final CalcKind kind;
  final CalcCheck check;

  /// The function, integral or limit, as [MathText] source.
  final String card;

  /// A short label under the card.
  final String caption;

  /// The picture on the question card, if any.
  final CalcGraph? graph;

  /// The picture after answering (the same one, or one that shows the
  /// answer, such as the turning point).
  final CalcGraph? reviewGraph;

  final String question;
  final String hint;

  /// [MathText] source of the right option.
  final String answer;

  /// For number answers: its value (for e-limits, the power of e).
  final Frac? answerValue;
  final List<CalcTrap> traps;
  final List<String> options;

  /// Sort keys of number options, ascending; null for formulas.
  final List<Frac>? optionValues;

  /// "about 5.33" under fractions that aren't tidy decimals.
  final List<String?> notes;
  final List<CalcStep> steps;
  final String insight;

  /// The function behind the question, as [MathText] source in
  /// [variable], for checking.
  final String expr;
  final String variable;

  /// The numbers behind the question, for recomputing in tests.
  final Map<String, num> params;

  /// Every option is above zero (lengths, areas, prices, ratios).
  final bool positive;

  /// Numbers, sorted; otherwise formulas in random order.
  bool get numeric => optionValues != null;

  int get answerIndex => options.indexOf(answer);

  String feedbackFor(String picked) => picked == answer
      ? insight
      : traps.firstWhere((t) => t.label == picked).why;
}

class CalcDifficulty {
  static List<CalcKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [CalcKind.power],
    2 => const [CalcKind.chainProduct],
    3 => const [CalcKind.transcend],
    4 => const [CalcKind.polyIntegral],
    5 => const [CalcKind.expLogIntegral],
    6 => const [CalcKind.limit],
    7 => const [CalcKind.estimate],
    8 => const [CalcKind.taylor],
    9 => const [CalcKind.extremum],
    _ => const [
      CalcKind.polyIntegral,
      CalcKind.expLogIntegral,
      CalcKind.limit,
      CalcKind.estimate,
      CalcKind.taylor,
      CalcKind.extremum,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'derivatives of powers',
    2 => 'the product and chain rules',
    3 => 'eˣ, ln x, sin and cos',
    4 => 'integrals of polynomials',
    5 => 'integrals of eˣ and 1/x',
    6 => 'limits',
    7 => 'quick estimates',
    8 => 'Taylor series',
    9 => 'maxima and minima',
    _ => 'any of them',
  };
}

// ---- formatting --------------------------------------------------------------

/// A number as [MathText] source: whole, a tidy decimal, or a fraction.
String mnum(Frac v) {
  if (v.d == 1) return '${v.n}';
  if (100 % v.d == 0) return _decimal(v);
  return '${v.n < 0 ? '-' : ''}\\frac{${v.n.abs()}}{${v.d}}';
}

/// A number as plain text, with a real minus sign.
String tnum(Frac v) {
  final s = v.d == 1
      ? '${v.n.abs()}'
      : 100 % v.d == 0 || 10000 % v.d == 0
      ? _decimal(Frac(v.n.abs(), v.d))
      : '${v.n.abs()}/${v.d}';
  return v.n < 0 ? '−$s' : s;
}

/// "about 5.33" under a fraction that isn't a tidy decimal.
String? note(Frac v) => v.d == 1 || 100 % v.d == 0
    ? null
    : 'about ${v.value.toStringAsFixed(2).replaceFirst('-', '−')}';

/// An exact decimal with up to four places, as [MathText] source.
String mdec(Frac v) => _decimal(v);

String _decimal(Frac v) {
  assert(10000 % v.d == 0, '$v has more than 4 decimal places');
  final scaled = (v.n * (10000 ~/ v.d)).abs();
  var frac = '${scaled % 10000}'.padLeft(4, '0');
  while (frac.endsWith('0')) {
    frac = frac.substring(0, frac.length - 1);
  }
  final whole = '${scaled ~/ 10000}';
  return '${v.n < 0 ? '-' : ''}$whole${frac.isEmpty ? '' : '.$frac'}';
}

/// Plain-text superscript digits: 3 → "³".
String sup(int k) {
  const digits = '⁰¹²³⁴⁵⁶⁷⁸⁹';
  final s = k.abs().toString().split('').map((c) => digits[int.parse(c)]);
  return '${k < 0 ? '⁻' : ''}${s.join()}';
}

/// One term of a polynomial: coefficient and power.
typedef Term = (Frac, int);

/// A polynomial as [MathText] source, highest power first as given.
String poly(List<Term> terms, [String v = 'x']) {
  final out = StringBuffer();
  var first = true;
  for (final (c, p) in terms) {
    if (c == Frac.zero) continue;
    final neg = c < Frac.zero;
    final mag = neg ? Frac.zero - c : c;
    if (first) {
      if (neg) out.write('-');
    } else {
      out.write(neg ? ' - ' : ' + ');
    }
    first = false;
    final power = p == 0
        ? ''
        : p == 1
        ? v
        : '$v^{$p}';
    if (p == 0) {
      out.write(_coef(mag));
    } else if (mag != Frac.one) {
      out.write('${_coef(mag)}$power');
    } else {
      out.write(power);
    }
  }
  return first ? '0' : out.toString();
}

/// A coefficient: whole, or a fraction (never a decimal, so ⅓x³ and ¼x⁴
/// read like the working in a book).
String _coef(Frac v) => v.d == 1 ? '${v.n}' : '\\frac{${v.n}}{${v.d}}';

/// x to a power as plain text: "x", "x²", "1".
String _xp(String v, int n) => n == 0
    ? '1'
    : n == 1
    ? v
    : '$v${sup(n)}';

/// A thin space after sin, cos, ln and log₁₀ when the argument has no
/// brackets, so "sin x" doesn't run together (a typed space is a hair
/// space).
String spaced(String m) => m.replaceAllMapped(
  RegExp(r'\\(sin|cos|ln|log_\{10\}) '),
  (x) => '\\${x[1]}\u2009',
);

/// Adds together terms with the same power.
List<Term> merge(List<Term> terms) {
  final by = <int, Frac>{};
  for (final (c, p) in terms) {
    by[p] = (by[p] ?? Frac.zero) + c;
  }
  final powers = by.keys.toList()..sort((a, b) => b.compareTo(a));
  return [for (final p in powers) (by[p]!, p)];
}

Frac evalPoly(List<Term> terms, Frac x) {
  var s = Frac.zero;
  for (final (c, p) in terms) {
    s = s + c * x.pow(p);
  }
  return s;
}

double Function(double) polyFn(List<Term> terms) => (x) {
  var s = 0.0;
  for (final (c, p) in terms) {
    s += c.value * pow(x, p);
  }
  return s;
};

/// "2", "(−3)": a number to substitute, bracketed when negative.
String _arg(int k) => k < 0 ? '($k)' : '$k';
String _argF(Frac k) => k < Frac.zero ? '(${mnum(k)})' : mnum(k);

/// "x − 2", "x + 1", "x".
String _xMinus(int r, [String v = 'x']) => r == 0
    ? v
    : r > 0
    ? '$v - $r'
    : '$v + ${-r}';

/// The coefficient in front of a letter: "" for 1, "-" for −1.
String _co(int a) => a == 1
    ? ''
    : a == -1
    ? '-'
    : '$a';

/// e to a whole power, as [MathText] source: 1, e, e^{4}, e^{-2}.
String ePow(int k) => k == 0
    ? '1'
    : k == 1
    ? 'e'
    : 'e^{$k}';

int _ipow(int b, int e) {
  var r = 1;
  for (var i = 0; i < e; i++) {
    r *= b;
  }
  return r;
}

int _fact(int n) => n <= 1 ? 1 : n * _fact(n - 1);

class CalcGenerator {
  const CalcGenerator();

  static const _again = 'Check the numbers again: see the working.';

  CalcQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = CalcDifficulty.kindsFor(level);
    for (var attempt = 0; ; attempt++) {
      final kind = kinds[rng.nextInt(kinds.length)];
      final d = switch (kind) {
        CalcKind.power => _power(rng),
        CalcKind.chainProduct => _chainProduct(rng),
        CalcKind.transcend => _transcend(rng),
        CalcKind.polyIntegral => _polyIntegral(rng),
        CalcKind.expLogIntegral => _expLogIntegral(rng),
        CalcKind.limit => _limit(rng),
        CalcKind.estimate => _estimate(rng),
        CalcKind.taylor => _taylor(rng),
        CalcKind.extremum => _extremum(rng),
      };
      final q = d.value != null
          ? _numberQuestion(d, level, seed, kind, rng)
          : _formulaQuestion(d, level, seed, kind, rng);
      // A fraction among whole numbers (or the reverse) would give the
      // answer away: try another setup.
      if (q != null || attempt > 40) {
        return q ?? _numberQuestion(d, level, seed, kind, rng, strict: false)!;
      }
    }
  }

  CalcQuestion? _numberQuestion(
    _Draft d,
    int level,
    int seed,
    CalcKind kind,
    Random rng, {
    bool strict = true,
  }) {
    final a = d.value!;
    final format = d.format ?? (d.decimal ? mdec : mnum);
    CalcTrap t(Frac v, String why) => CalcTrap(format(v), why, v);
    // Where the answer is never 0, a 0 would always be wrong.
    bool fits(Frac v) =>
        v != a &&
        (!d.positive || v > Frac.zero) &&
        (d.zeroOk || v != Frac.zero);
    final fillers = [
      for (final k in [1, 2, 3])
        for (final sign in [1, -1])
          if (fits(a + d.unit * Frac(sign * k)))
            t(a + d.unit * Frac(sign * k), _again),
    ]..shuffle(rng);
    final named = [
      for (final (v, why) in d.traps)
        if (fits(v)) t(v, why),
    ];
    final chosen = balancedOptions(
      t(a, ''),
      named,
      fillers,
      rng,
      compare: (x, y) => x.value!.compareTo(y.value!),
    );
    final notes = [
      for (final c in chosen)
        if (d.format != null || d.decimal) null else note(c.value!),
    ];
    if (strict && d.format == null && !d.decimal) {
      final mine = note(a) != null;
      final same = chosen.where((c) => (note(c.value!) != null) == mine);
      if (same.length < 2) return null;
    }
    return _question(
      d,
      level,
      seed,
      kind,
      answer: format(a),
      traps: [
        for (final c in chosen)
          if (c.value != a) c,
      ],
      options: [for (final c in chosen) c.label],
      values: [for (final c in chosen) c.value!],
      notes: notes,
    );
  }

  CalcQuestion _formulaQuestion(
    _Draft d,
    int level,
    int seed,
    CalcKind kind,
    Random rng,
  ) {
    final seen = {d.formula!};
    final traps = <CalcTrap>[];
    for (final (label, why) in d.formulaTraps) {
      if (traps.length == 3) break;
      if (seen.add(label)) traps.add(CalcTrap(label, why));
    }
    assert(traps.length == 3, 'only ${traps.length} traps for ${d.card}');
    final order = [...traps]..shuffle(rng);
    final options = [for (final t in order) t.label]
      ..insert(rng.nextInt(4), d.formula!);
    return _question(
      d,
      level,
      seed,
      kind,
      answer: d.formula!,
      traps: traps,
      options: options,
      values: null,
      notes: List.filled(4, null),
    );
  }

  CalcQuestion _question(
    _Draft d,
    int level,
    int seed,
    CalcKind kind, {
    required String answer,
    required List<CalcTrap> traps,
    required List<String> options,
    required List<Frac>? values,
    required List<String?> notes,
  }) => CalcQuestion(
    level: level,
    seed: seed,
    kind: kind,
    check: d.check,
    card: spaced(d.card),
    caption: d.caption,
    graph: d.graph,
    reviewGraph: d.reviewGraph ?? d.graph,
    question: d.question,
    hint: d.hint,
    answer: spaced(answer),
    answerValue: d.value,
    traps: [for (final t in traps) CalcTrap(spaced(t.label), t.why, t.value)],
    options: [for (final o in options) spaced(o)],
    optionValues: values,
    notes: notes,
    steps: [
      for (final s in d.steps)
        CalcStep(s.text, s.math == null ? null : spaced(s.math!)),
    ],
    insight: d.insight,
    expr: spaced(d.expr),
    variable: d.variable,
    params: d.params,
    positive: d.positive,
  );

  // ---- helpers ------------------------------------------------------------

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  static CalcGraph _tangent(
    double Function(double) f,
    double at,
    double slope, {
    required double lo,
    required double hi,
    double? target,
    String? label,
  }) => CalcGraph(
    f: f,
    lo: lo,
    hi: hi,
    at: at,
    slope: slope,
    target: target,
    labels: {at: label ?? 'x = ${_short(at).replaceFirst('-', '−')}'},
  );

  static String _short(double x) =>
      x == x.roundToDouble() ? '${x.round()}' : '$x';

  // ---- level 1: powers -----------------------------------------------------

  _Draft _power(Random rng) {
    final n = 2 + rng.nextInt(3);
    final m = 1 + rng.nextInt(n - 1);
    final a = 1 + rng.nextInt(4);
    final b = _pick(rng, const [-5, -4, -3, -2, -1, 1, 2, 3, 4, 5]);
    final c = _pick(rng, const [-4, -3, -2, -1, 1, 2, 3, 5, 7]);
    final f = <Term>[(Frac(a), n), (Frac(b), m), (Frac(c), 0)];
    final df = <Term>[(Frac(a * n), n - 1), (Frac(b * m), m - 1)];
    final card = 'f(x) = ${poly(f)}';
    if (rng.nextBool()) {
      final k = _pick(rng, n <= 3 ? const [-3, -2, 2, 3] : const [-2, 2]);
      final kk = Frac(k);
      final ans = evalPoly(df, kk);
      final dfAt = [
        for (final (cc, p) in df)
          p == 0
              ? mnum(cc)
              : p == 1
              ? '${mnum(cc)} \\cdot ${_arg(k)}'
              : '${mnum(cc)} \\cdot ${_arg(k)}^{$p}',
      ];
      return _Draft(
        check: CalcCheck.slope,
        zeroOk: true,
        card: card,
        caption: 'The tangent at x = ${tnum(Frac(k))}',
        graph: _tangent(
          polyFn(f),
          k.toDouble(),
          ans.value,
          lo: k - 1.2,
          hi: k + 1.2,
        ),
        question: 'What is f′(${tnum(Frac(k))}), the slope of the tangent?',
        hint: 'Power rule: xⁿ becomes n·xⁿ⁻¹.',
        value: ans,
        unit: Frac(max(1, ans.n.abs() ~/ 12)),
        traps: [
          (
            evalPoly([(Frac(a * n), n), (Frac(b * m), m)], kk),
            'The power drops by one: x${sup(n)} becomes $n${_xp('x', n - 1)}, '
                'not ${n}x${sup(n)}.',
          ),
          (
            evalPoly([(Frac(a), n - 1), (Frac(b), m - 1)], kk),
            'The power comes down as a factor too: x${sup(n)} becomes '
                '$n${_xp('x', n - 1)}.',
          ),
          (
            evalPoly(f, kk),
            'That\'s f(${tnum(Frac(k))}), the height; the slope is '
                'f′(${tnum(Frac(k))}).',
          ),
          (
            ans + Frac(c),
            'A constant has slope 0: the ${tnum(Frac(c))} drops out.',
          ),
        ],
        steps: [
          CalcStep(
            'Differentiate term by term: power down, then one less.',
            'f′(x) = ${poly(df)}',
          ),
          CalcStep(
            'Put x = ${tnum(Frac(k))} in.',
            'f′($k) = ${dfAt.join(' + ').replaceAll('+ -', '- ')}',
          ),
          CalcStep('So the slope there is:', 'f′($k) = ${mnum(ans)}'),
        ],
        insight: 'Right: power down, one less, then put the number in.',
        expr: poly(f),
        params: {'at': k},
      );
    }
    final kept = poly([(Frac(a * n), n), (Frac(b * m), m)]);
    final noDown = poly([(Frac(a), n - 1), (Frac(b), m - 1)]);
    final withC = poly(merge([...df, (Frac(c), 0)]));
    final integrated = poly([
      (Frac(a, n + 1), n + 1),
      (Frac(b, m + 1), m + 1),
      (Frac(c), 1),
    ]);
    return _Draft(
      check: CalcCheck.derivative,
      card: card,
      caption: 'Differentiate',
      question: 'What is f′(x), the derivative?',
      hint: 'Power rule: xⁿ becomes n·xⁿ⁻¹; constants drop out.',
      formula: poly(df),
      formulaTraps: [
        (
          kept,
          'The power drops by one: x${sup(n)} becomes $n${_xp('x', n - 1)}, '
              'not ${n}x${sup(n)}.',
        ),
        (
          noDown,
          'The power comes down as a factor too: x${sup(n)} becomes '
              '$n${_xp('x', n - 1)}.',
        ),
        (withC, 'A constant has slope 0: the ${tnum(Frac(c))} drops out.'),
        (integrated, 'That integrates; differentiating lowers each power.'),
      ],
      steps: [
        CalcStep(
          'Bring each power down, then make it one less.',
          '\\frac{d}{dx} ${poly([(Frac(a), n)])} = ${poly([(Frac(a * n), n - 1)])}',
        ),
        CalcStep(
          'A constant has slope 0, so it drops out.',
          '\\frac{d}{dx} ($c) = 0',
        ),
        CalcStep('Together:', 'f′(x) = ${poly(df)}'),
      ],
      insight: 'Right: power down, one less, and constants vanish.',
      expr: poly(f),
    );
  }

  // ---- level 2: product and chain ------------------------------------------

  _Draft _chainProduct(Random rng) => switch (rng.nextInt(3)) {
    0 => _chainValue(rng),
    1 => _chainFormula(rng),
    _ => _productValue(rng),
  };

  _Draft _chainValue(Random rng) {
    int a, b, n, k, u;
    do {
      a = 2 + rng.nextInt(2);
      n = 2 + rng.nextInt(3);
      k = _pick(rng, const [-1, 0, 1, 2]);
      u = _pick(rng, n == 4 ? const [-2, 2] : const [-3, -2, 2, 3]);
      b = u - a * k;
    } while (b == 0 || b.abs() > 6);
    final lin = poly([(Frac(a), 1), (Frac(b), 0)]);
    final ans = Frac(n * a * _ipow(u, n - 1));
    final f = 'f(x) = ($lin)^{$n}';
    String up(int e) => e == 1 ? _arg(u) : '${_arg(u)}^{$e}';
    return _Draft(
      check: CalcCheck.slope,
      card: f,
      caption: 'The tangent at x = ${tnum(Frac(k))}',
      graph: _tangent(
        (x) => pow(a * x + b, n).toDouble(),
        k.toDouble(),
        ans.value,
        lo: k - 1.0,
        hi: k + 1.0,
      ),
      question: 'What is f′(${tnum(Frac(k))}), the slope of the tangent?',
      hint: 'Chain rule: the outside\'s slope times the inside\'s.',
      value: ans,
      unit: Frac(max(1, ans.n.abs() ~/ 10)),
      traps: [
        (
          Frac(n * _ipow(u, n - 1)),
          'The chain rule also multiplies by the inside\'s slope, $a.',
        ),
        (
          Frac(n * a * _ipow(u, n)),
          'The outer power drops by one: u${sup(n)} becomes $n${_xp('u', n - 1)}.',
        ),
        (
          Frac(_ipow(u, n)),
          'That\'s f(${tnum(Frac(k))}), the height; the slope is '
              'f′(${tnum(Frac(k))}).',
        ),
        (Frac(a * _ipow(u, n - 1)), 'The power $n comes down as a factor too.'),
      ],
      steps: [
        CalcStep(
          'Chain rule: the outside\'s slope times the inside\'s slope.',
          'f′(x) = $n($lin)^{${n - 1}} \\cdot $a',
        ),
        CalcStep(
          'At x = ${tnum(Frac(k))} the inside is ${tnum(Frac(u))}.',
          'f′($k) = $n \\cdot ${up(n - 1)} \\cdot $a',
        ),
        CalcStep('So the slope there is:', 'f′($k) = ${mnum(ans)}'),
      ],
      insight:
          'Right: differentiate the outside, then times the inside\'s slope.',
      expr: '($lin)^{$n}',
      params: {'at': k},
    );
  }

  _Draft _chainFormula(Random rng) {
    final c = 1 + rng.nextInt(5);
    final n = 2 + rng.nextInt(4);
    final inner = 'x^{2} + $c';
    String pw(int e) => e == 1 ? '($inner)' : '($inner)^{$e}';
    return _Draft(
      check: CalcCheck.derivative,
      card: 'f(x) = ${pw(n)}',
      caption: 'Differentiate',
      question: 'What is f′(x), the derivative?',
      hint: 'Chain rule: the outside\'s slope times the inside\'s.',
      formula: '${2 * n}x${pw(n - 1)}',
      formulaTraps: [
        (
          '$n${pw(n - 1)}',
          'The chain rule also multiplies by the inside\'s slope, 2x.',
        ),
        (
          '${2 * n}x${pw(n)}',
          'The outer power drops by one: u${sup(n)} becomes $n${_xp('u', n - 1)}.',
        ),
        ('2x${pw(n - 1)}', 'The power $n comes down as a factor too.'),
      ],
      steps: [
        CalcStep(
          'Outside: the power rule, keeping u = x² + $c whole.',
          '$n${pw(n - 1)}',
        ),
        CalcStep(
          'Inside: the slope of x² + $c is 2x.',
          '\\frac{d}{dx}($inner) = 2x',
        ),
        CalcStep('Multiply them:', 'f′(x) = ${2 * n}x${pw(n - 1)}'),
      ],
      insight: 'Right: the outside\'s slope times the inside\'s slope.',
      expr: pw(n),
    );
  }

  _Draft _productValue(Random rng) {
    final a = 1 + rng.nextInt(3);
    final b = _pick(rng, const [-3, -2, -1, 1, 2, 3]);
    final c = 1 + rng.nextInt(2);
    final d = _pick(rng, const [-4, -3, -2, -1, 1, 2, 3, 5]);
    var k = _pick(rng, const [-2, -1, 1, 2]);
    // u = 0 at the point would make every slip land on the same number.
    while (a * k + b == 0) {
      k = _pick(rng, const [-2, -1, 1, 2]);
    }
    final lin = poly([(Frac(a), 1), (Frac(b), 0)]);
    final quad = poly([(Frac(c), 2), (Frac(d), 0)]);
    final u = a * k + b, v = c * k * k + d, dv = 2 * c * k;
    final ans = Frac(a * v + u * dv);
    return _Draft(
      check: CalcCheck.slope,
      zeroOk: true,
      card: 'f(x) = ($lin)($quad)',
      caption: 'The tangent at x = ${tnum(Frac(k))}',
      graph: _tangent(
        (x) => (a * x + b) * (c * x * x + d),
        k.toDouble(),
        ans.value,
        lo: k - 1.2,
        hi: k + 1.2,
      ),
      question: 'What is f′(${tnum(Frac(k))}), the slope of the tangent?',
      hint: 'Product rule: (uv)′ = u′v + uv′.',
      value: ans,
      unit: Frac(max(1, ans.n.abs() ~/ 10)),
      traps: [
        (Frac(a * dv), '(uv)′ is u′v + uv′, not u′ times v′.'),
        (Frac(a * v), 'That\'s only u′v; add uv′ too.'),
        (Frac(u * dv), 'That\'s only uv′; add u′v too.'),
        (
          Frac(u * v),
          'That\'s f(${tnum(Frac(k))}), the height; the slope is '
              'f′(${tnum(Frac(k))}).',
        ),
      ],
      steps: [
        CalcStep(
          'Product rule, with u = ${_plain(lin)} and v = ${_plain(quad)}.',
          'f′(x) = $a($quad) + ($lin) \\cdot ${2 * c}x',
        ),
        CalcStep(
          'At x = ${tnum(Frac(k))}: u = ${tnum(Frac(u))}, v = ${tnum(Frac(v))}, '
          'u′ = $a, v′ = ${tnum(Frac(dv))}.',
        ),
        CalcStep(
          'So the slope there is:',
          'f′($k) = $a \\cdot ${_arg(v)} + ${_arg(u)} \\cdot ${_arg(dv)} = ${mnum(ans)}',
        ),
      ],
      insight: 'Right: u′v + uv′, then put the number in.',
      expr: '($lin)($quad)',
      params: {'at': k},
    );
  }

  /// [MathText] source as plain text, for maths inside a sentence.
  static String _plain(String m) => m
      .replaceAllMapped(RegExp(r'\^\{(-?\d+)\}'), (x) => sup(int.parse(x[1]!)))
      .replaceAll(' - ', ' − ')
      .replaceAll(RegExp(r'^-'), '−');

  // ---- level 3: e^x, ln x, sin, cos ----------------------------------------

  _Draft _transcend(Random rng) => switch (rng.nextInt(5)) {
    0 => _trigSum(rng),
    1 => _expProduct(rng),
    2 => _lnChain(rng),
    3 => _expTrig(rng),
    _ => _powerLn(rng),
  };

  static String _trig(String fn, int a) => a == 1 ? '\\$fn x' : '\\$fn(${a}x)';
  static String _trigPlain(String fn, int a) => a == 1 ? '$fn x' : '$fn(${a}x)';

  _Draft _trigSum(Random rng) {
    final a = 1 + rng.nextInt(4);
    int b;
    do {
      b = 2 + rng.nextInt(4);
    } while (b == a);
    final sinA = _trig('sin', a), cosA = _trig('cos', a);
    final sinB = _trig('sin', b), cosB = _trig('cos', b);
    final answer = '${_co(a)}$cosA - ${_co(b)}$sinB';
    return _Draft(
      check: CalcCheck.derivative,
      card: 'f(x) = $sinA + $cosB',
      caption: 'Differentiate',
      question: 'What is f′(x), the derivative?',
      hint: 'sin goes to cos, cos goes to −sin, times the inside\'s slope.',
      formula: answer,
      formulaTraps: [
        (
          '${_co(a)}$cosA + ${_co(b)}$sinB',
          'The slope of cos is −sin: watch the sign.',
        ),
        (
          '$cosA - $sinB',
          a == 1
              ? 'Chain rule: ${_trigPlain('cos', b)} brings out its inside\'s '
                    'slope, $b.'
              : 'Chain rule: ${_trigPlain('sin', a)} brings out $a, and '
                    '${_trigPlain('cos', b)} brings out $b.',
        ),
        (
          '-${_co(a)}$cosA - ${_co(b)}$sinB',
          'The slope of sin is +cos: only cos picks up a minus.',
        ),
      ],
      steps: [
        CalcStep(
          'sin goes to cos, times the inside\'s slope.',
          '\\frac{d}{dx}$sinA = ${_co(a)}$cosA',
        ),
        CalcStep(
          'cos goes to minus sin, times the inside\'s slope.',
          '\\frac{d}{dx}$cosB = -${_co(b)}$sinB',
        ),
        CalcStep('Add them:', 'f′(x) = $answer'),
      ],
      insight: 'Right: sin → cos, cos → −sin, and the chain rule\'s factor.',
      expr: '$sinA + $cosB',
    );
  }

  _Draft _expProduct(Random rng) {
    final n = 2 + rng.nextInt(2);
    final a = 2 + rng.nextInt(2);
    final xn = 'x^{$n}';
    final xn1 = n == 2 ? 'x' : 'x^{${n - 1}}';
    final ea = 'e^{${a}x}';
    final answer = '$n$xn1$ea + $a$xn$ea';
    return _Draft(
      check: CalcCheck.derivative,
      card: 'f(x) = $xn$ea',
      caption: 'Differentiate',
      question: 'What is f′(x), the derivative?',
      hint: 'Product rule: (uv)′ = u′v + uv′.',
      formula: answer,
      formulaTraps: [
        ('${n * a}$xn1$ea', '(uv)′ is u′v + uv′, not u′ times v′.'),
        (
          '$n$xn1$ea + $xn$ea',
          'e^(${a}x) has slope ${a}e^(${a}x): the chain rule brings out $a.',
        ),
        ('$n$xn1$ea', 'That\'s only u′v; add uv′ too.'),
      ],
      steps: [
        CalcStep(
          'Product rule with u = x${sup(n)} and v = e^(${a}x).',
          'u′ = $n$xn1, v′ = $a$ea',
        ),
        CalcStep('u′v + uv′:', '$n$xn1 \\cdot $ea + $xn \\cdot $a$ea'),
        CalcStep('Tidy up:', 'f′(x) = $answer'),
      ],
      insight: 'Right: u′v + uv′, with the chain rule on e^(${a}x).',
      expr: '$xn$ea',
    );
  }

  _Draft _lnChain(Random rng) {
    final a = 1 + rng.nextInt(3);
    final b = 1 + rng.nextInt(5);
    final inner = poly([(Frac(a), 2), (Frac(b), 0)]);
    final answer = '\\frac{${2 * a}x}{$inner}';
    return _Draft(
      check: CalcCheck.derivative,
      card: 'f(x) = \\ln($inner)',
      caption: 'Differentiate',
      question: 'What is f′(x), the derivative?',
      hint: 'The slope of ln u is 1/u, times the inside\'s slope.',
      formula: answer,
      formulaTraps: [
        (
          '\\frac{1}{$inner}',
          'Chain rule: ln u has slope u′/u; you left out u′ = ${2 * a}x.',
        ),
        (
          '\\frac{${2 * a}x}{($inner) \\ln 10}',
          'The extra ln 10 is for log₁₀; ln has none.',
        ),
        (
          '${2 * a}x \\ln($inner)',
          'The slope of ln u is 1/u: the ln itself goes.',
        ),
      ],
      steps: [
        CalcStep(
          'The slope of ln u is 1/u.',
          '\\frac{d}{du}\\ln u = \\frac{1}{u}',
        ),
        CalcStep(
          'Inside: u = ${_plain(inner)}, with slope ${2 * a}x.',
          'u′ = ${2 * a}x',
        ),
        CalcStep('Multiply:', 'f′(x) = $answer'),
      ],
      insight: 'Right: u′/u.',
      expr: '\\ln($inner)',
    );
  }

  _Draft _expTrig(Random rng) {
    final sin = rng.nextBool();
    final (inner, slope) = sin
        ? ('\\sin x', '\\cos x')
        : ('\\cos x', '-\\sin x');
    final answer = '$slope \\cdot e^{$inner}';
    return _Draft(
      check: CalcCheck.derivative,
      card: 'f(x) = e^{$inner}',
      caption: 'Differentiate',
      question: 'What is f′(x), the derivative?',
      hint: 'eᵘ keeps its form; multiply by u′.',
      formula: answer,
      formulaTraps: [
        (
          'e^{$inner}',
          'Chain rule: multiply by the inside\'s slope, ${sin ? 'cos x' : '−sin x'}.',
        ),
        (
          sin ? 'e^{\\cos x}' : 'e^{-\\sin x}',
          'Only the outside changes: eᵘ stays eᵘ, then times u′.',
        ),
        (
          sin ? '-\\cos x \\cdot e^{\\sin x}' : '\\sin x \\cdot e^{\\cos x}',
          sin
              ? 'The slope of sin x is +cos x.'
              : 'The slope of cos x is −sin x: keep the minus.',
        ),
      ],
      steps: [
        CalcStep(
          'eᵘ has slope eᵘ times u′.',
          '\\frac{d}{dx}e^{u} = e^{u} \\cdot u′',
        ),
        CalcStep(
          'Here u = ${sin ? 'sin x' : 'cos x'}, with slope '
              '${sin ? 'cos x' : '−sin x'}.',
          'u′ = $slope',
        ),
        CalcStep('So:', 'f′(x) = $answer'),
      ],
      insight: 'Right: eᵘ times u′.',
      expr: 'e^{$inner}',
    );
  }

  _Draft _powerLn(Random rng) {
    final n = 2 + rng.nextInt(3);
    String xp(int e) => e == 0
        ? ''
        : e == 1
        ? 'x'
        : 'x^{$e}';
    final answer = '$n${xp(n - 1)} \\ln x + ${xp(n - 1)}';
    return _Draft(
      check: CalcCheck.derivative,
      card: 'f(x) = ${xp(n)} \\ln x',
      caption: 'Differentiate',
      question: 'What is f′(x), the derivative?',
      hint: 'Product rule: (uv)′ = u′v + uv′.',
      formula: answer,
      formulaTraps: [
        ('$n${xp(n - 2)}', '(uv)′ is u′v + uv′, not u′ times v′.'),
        (
          '$n${xp(n - 1)} \\ln x',
          'That\'s only u′v; add uv′ = x${sup(n)} · (1/x) too.',
        ),
        (
          '$n${xp(n)} \\ln x + ${xp(n - 1)}',
          'The power drops by one: x${sup(n)} becomes $n${_xp('x', n - 1)}.',
        ),
      ],
      steps: [
        CalcStep(
          'Product rule with u = x${sup(n)} and v = ln x.',
          'u′ = $n${xp(n - 1)}, v′ = \\frac{1}{x}',
        ),
        CalcStep(
          'u′v + uv′:',
          '$n${xp(n - 1)} \\ln x + ${xp(n)} \\cdot \\frac{1}{x}',
        ),
        CalcStep('Tidy up:', 'f′(x) = $answer'),
      ],
      insight: 'Right: u′v + uv′, and ln x has slope 1/x.',
      expr: '${xp(n)} \\ln x',
    );
  }

  // ---- level 4: integrals of polynomials -----------------------------------

  _Draft _polyIntegral(Random rng) {
    late int n, a, m, b, lo, hi;
    late Frac ans;
    late List<Term> f, big;
    Frac at(List<Term> t, int x) => evalPoly(t, Frac(x));
    do {
      n = 1 + rng.nextInt(3);
      a = 1 + rng.nextInt(4);
      m = rng.nextInt(n);
      b = _pick(rng, const [-3, -2, -1, 1, 2, 3, 4]);
      lo = _pick(rng, const [-1, 0, 0, 1]);
      hi = lo + 1 + rng.nextInt(n == 3 ? 2 : 3);
      f = [(Frac(a), n), (Frac(b), m)];
      big = [for (final (c, p) in f) (c / Frac(p + 1), p + 1)];
      ans = at(big, hi) - at(big, lo);
    } while (ans == Frac.zero || hi > 3);
    final noDivide = [for (final (c, p) in f) (c, p + 1)];
    final byOld = [for (final (c, p) in f) (p == 0 ? c : c / Frac(p), p + 1)];
    final fHi = at(big, hi), fLo = at(big, lo);
    return _Draft(
      check: CalcCheck.integral,
      card: '\\int_{$lo}^{$hi} (${poly(f)}) dx',
      caption: 'The area from $lo to $hi',
      graph: CalcGraph(
        f: polyFn(f),
        lo: lo - 0.5,
        hi: hi + 0.5,
        from: lo.toDouble(),
        to: hi.toDouble(),
        labels: {lo.toDouble(): '$lo', hi.toDouble(): '$hi'},
      ),
      question: 'What does the integral come to?',
      hint: 'Raise each power by one, divide by the new power.',
      value: ans,
      unit: ans.d == 1 ? Frac.one : Frac(1, ans.d),
      traps: [
        (
          at(noDivide, hi) - at(noDivide, lo),
          'Integrating xⁿ gives xⁿ⁺¹/(n + 1): you left out the divide.',
        ),
        (
          Frac.zero - ans,
          'Upper minus lower: F($hi) − F(${tnum(Frac(lo))}), not the other way.',
        ),
        if (fLo != Frac.zero)
          (
            fHi,
            'Take away F(${tnum(Frac(lo))}) too: the area starts at x = ${tnum(Frac(lo))}.',
          ),
        (
          at(byOld, hi) - at(byOld, lo),
          'Divide by the new power, n + 1, not the old one.',
        ),
        (
          at(f, hi) - at(f, lo),
          'That\'s f($hi) − f(${tnum(Frac(lo))}): integrate first, then subtract.',
        ),
      ],
      steps: [
        CalcStep(
          'Raise each power by one, divide by the new power.',
          'F(x) = ${poly(big)}',
        ),
        CalcStep(
          'Upper limit minus lower limit.',
          'F($hi) - F($lo) = ${mnum(fHi)} - ${_argF(fLo)}',
        ),
        CalcStep('So the integral is:', '= ${mnum(ans)}'),
      ],
      insight: 'Right: integrate, then upper minus lower.',
      expr: poly(f),
      params: {'lo': lo, 'hi': hi},
    );
  }

  // ---- level 5: e^x, 1/x and a substitution --------------------------------

  _Draft _expLogIntegral(Random rng) => switch (rng.nextInt(4)) {
    0 => _expIntegral(rng),
    1 => _lnIntegral(rng),
    2 => _subExp(rng),
    _ => _subLog(rng),
  };

  _Draft _expIntegral(Random rng) {
    final a = 1 + rng.nextInt(3);
    final k = a == 3 ? 1 : 1 + rng.nextInt(2);
    final ax = a == 1 ? 'x' : '${a}x';
    final e = ePow(a * k);
    final graph = CalcGraph(
      f: (x) => exp(a * x),
      lo: -0.4,
      hi: k + 0.3,
      from: 0,
      to: k.toDouble(),
      labels: {0: '0', k.toDouble(): '$k'},
    );
    if (a == 1) {
      return _Draft(
        check: CalcCheck.integral,
        card: '\\int_{0}^{$k} e^{x} dx',
        caption: 'The area from 0 to $k',
        graph: graph,
        question: 'What does the integral come to?',
        hint: 'eˣ is its own integral.',
        formula: '$e - 1',
        formulaTraps: [
          (e, 'Take away F(0) = e⁰ = 1.'),
          ('1 - $e', 'Upper minus lower: F($k) − F(0), not the other way.'),
          (
            '\\frac{e^{${k + 1}}}{${k + 1}}',
            'eˣ isn\'t a power of x: it is its own integral.',
          ),
        ],
        steps: [
          const CalcStep('eˣ is its own integral.', 'F(x) = e^{x}'),
          CalcStep('Upper minus lower; e⁰ = 1.', 'F($k) - F(0) = $e - e^{0}'),
          CalcStep('So the integral is:', '= $e - 1'),
        ],
        insight: 'Right: eˣ integrates to itself; e⁰ = 1.',
        expr: 'e^{x}',
        params: {'lo': 0, 'hi': k},
      );
    }
    return _Draft(
      check: CalcCheck.integral,
      card: '\\int_{0}^{$k} e^{$ax} dx',
      caption: 'The area from 0 to $k',
      graph: graph,
      question: 'What does the integral come to?',
      hint: 'e^(ax) integrates to e^(ax)/a.',
      formula: '\\frac{1}{$a}($e - 1)',
      formulaTraps: [
        (
          '$a($e - 1)',
          'Undo the chain rule by dividing by $a, not multiplying.',
        ),
        ('$e - 1', 'e^(${a}x) integrates to e^(${a}x)/$a: keep the 1/$a.'),
        ('\\frac{1}{$a}$e', 'Take away the lower limit too: F(0) = 1/$a.'),
        (
          '\\frac{1}{$a}(1 - $e)',
          'Upper minus lower: F($k) − F(0), not the other way.',
        ),
      ],
      steps: [
        CalcStep(
          'e^(${a}x) integrates to e^(${a}x)/$a.',
          'F(x) = \\frac{1}{$a}e^{$ax}',
        ),
        CalcStep(
          'Upper minus lower; e⁰ = 1.',
          'F($k) - F(0) = \\frac{1}{$a}$e - \\frac{1}{$a}',
        ),
        CalcStep('So the integral is:', '= \\frac{1}{$a}($e - 1)'),
      ],
      insight: 'Right: divide by the $a the chain rule would bring out.',
      expr: 'e^{$ax}',
      params: {'lo': 0, 'hi': k},
    );
  }

  _Draft _lnIntegral(Random rng) {
    final c = 1 + rng.nextInt(3);
    final b = _pick(rng, const [3, 5, 6, 7]);
    final co = _co(c);
    return _Draft(
      check: CalcCheck.integral,
      card: '\\int_{1}^{$b} \\frac{$c}{x} dx',
      caption: 'The area from 1 to $b',
      graph: CalcGraph(
        f: (x) => c / x,
        lo: 0.6,
        hi: b + 0.5,
        from: 1,
        to: b.toDouble(),
        labels: {1: '1', b.toDouble(): '$b'},
      ),
      question: 'What does the integral come to?',
      hint: '1/x integrates to ln x.',
      formula: '$co\\ln $b',
      formulaTraps: [
        ('$co\\log_{10} $b', '1/x integrates to ln x, not log₁₀ x.'),
        ('-$co\\ln $b', 'Upper minus lower: ln $b − ln 1, not the other way.'),
        ('$co\\ln ${b - 1}', 'ln $b − ln 1 is just ln $b: ln 1 is 0.'),
      ],
      steps: [
        CalcStep('1/x integrates to ln x.', 'F(x) = $co\\ln x'),
        CalcStep(
          'Upper minus lower; ln 1 = 0.',
          'F($b) - F(1) = $co\\ln $b - 0',
        ),
        CalcStep('So the integral is:', '= $co\\ln $b'),
      ],
      insight: 'Right: ln, and ln 1 = 0.',
      expr: '\\frac{$c}{x}',
      params: {'lo': 1, 'hi': b},
    );
  }

  _Draft _subExp(Random rng) {
    final k = 1 + rng.nextInt(2);
    final e = ePow(k * k);
    return _Draft(
      check: CalcCheck.integral,
      card: '\\int_{0}^{$k} xe^{x^{2}} dx',
      caption: 'The area from 0 to $k',
      graph: CalcGraph(
        f: (x) => x * exp(x * x),
        lo: -0.2,
        hi: k + 0.15,
        from: 0,
        to: k.toDouble(),
        labels: {0: '0', k.toDouble(): '$k'},
      ),
      question: 'What does the integral come to?',
      hint: 'Try u = x²: then du = 2x dx.',
      formula: '\\frac{1}{2}($e - 1)',
      formulaTraps: [
        ('$e - 1', 'With u = x², du = 2x dx, so x dx is du/2: keep the ½.'),
        ('2($e - 1)', 'Divide by the 2 in du = 2x dx, don\'t multiply.'),
        (
          '\\frac{1}{2}$e',
          'Take away the lower limit too: at x = 0, eᵘ = e⁰ = 1.',
        ),
      ],
      steps: [
        const CalcStep('Put u = x², so du = 2x dx.', 'x dx = \\frac{1}{2}du'),
        CalcStep(
          'x = 0 gives u = 0; x = $k gives u = ${k * k}.',
          '\\frac{1}{2}\\int_{0}^{${k * k}} e^{u} du',
        ),
        CalcStep('So the integral is:', '= \\frac{1}{2}($e - 1)'),
      ],
      insight: 'Right: u = x² turns it into ½∫eᵘ du.',
      expr: 'xe^{x^{2}}',
      params: {'lo': 0, 'hi': k},
    );
  }

  _Draft _subLog(Random rng) {
    final k = 2 + rng.nextInt(2);
    final top = k * k + 1;
    final traps = [
      (
        '\\frac{1}{2}\\ln $top',
        '2x dx is exactly du here: there\'s nothing to halve.',
      ),
      ('2\\ln $top', '2x dx is exactly du here: don\'t multiply by 2.'),
      ('\\ln ${k * k}', 'At x = $k, u = x² + 1 = $top: keep the + 1.'),
      ('\\log_{10} $top', 'du/u integrates to ln u, not log₁₀ u.'),
    ]..shuffle(rng);
    return _Draft(
      check: CalcCheck.integral,
      card: '\\int_{0}^{$k} \\frac{2x}{x^{2} + 1} dx',
      caption: 'The area from 0 to $k',
      graph: CalcGraph(
        f: (x) => 2 * x / (x * x + 1),
        lo: -0.3,
        hi: k + 0.3,
        from: 0,
        to: k.toDouble(),
        labels: {0: '0', k.toDouble(): '$k'},
      ),
      question: 'What does the integral come to?',
      hint: 'Try u = x² + 1: then du = 2x dx.',
      formula: '\\ln $top',
      formulaTraps: traps,
      steps: [
        const CalcStep(
          'Put u = x² + 1, so du = 2x dx.',
          '\\int \\frac{du}{u} = \\ln u',
        ),
        CalcStep('u runs from 1 to $top.', '\\ln $top - \\ln 1'),
        CalcStep('ln 1 = 0, so the integral is:', '= \\ln $top'),
      ],
      insight: 'Right: the top is the bottom\'s slope, so it\'s a log.',
      expr: '\\frac{2x}{x^{2} + 1}',
      params: {'lo': 0, 'hi': k},
    );
  }

  // ---- level 6: limits -----------------------------------------------------

  _Draft _limit(Random rng) => switch (rng.nextInt(3)) {
    0 => _sinRatio(rng),
    1 => _eLimit(rng),
    _ => switch (rng.nextInt(3)) {
      0 => _powerQuotient(rng),
      1 => _expQuotient(rng),
      _ => _cosQuotient(rng),
    },
  };

  _Draft _sinRatio(Random rng) {
    final a = 2 + rng.nextInt(5);
    int b;
    do {
      b = 1 + rng.nextInt(5);
    } while (b == a);
    final bySin = rng.nextBool();
    final den = bySin ? _trig('sin', b) : '${_co(b)}x';
    final ans = Frac(a, b);
    return _Draft(
      check: CalcCheck.limit,
      card: '\\lim_{x \\to 0} \\frac{\\sin(${a}x)}{$den}',
      caption: 'Near x = 0',
      question: 'What does it tend to as x goes to 0?',
      hint: 'Near 0, sin u is almost exactly u.',
      value: ans,
      positive: true,
      unit: a >= 4 ? Frac(1, b) : Frac(1, 2 * b),
      traps: [
        (Frac(b, a), 'Flipped: sin(${a}x) is about ${a}x, so it\'s $a/$b.'),
        (Frac.one, 'sin u / u → 1 only when the bottom matches the inside, u.'),
        if (b != 1) (Frac(a), 'You dropped the $b at the bottom.'),
        (Frac(1, b), 'You dropped the $a: sin(${a}x) is about ${a}x, not x.'),
      ],
      steps: [
        CalcStep('Near 0, sin u ≈ u.', '\\sin(${a}x) \\approx ${a}x'),
        CalcStep('So the quotient is about:', '\\frac{${a}x}{${_co(b)}x}'),
        CalcStep('The x cancels:', '= ${mnum(ans)}'),
      ],
      insight: 'Right: near 0, sin u ≈ u, so the x cancels.',
      expr: '\\frac{\\sin(${a}x)}{$den}',
      params: {'to': 0},
    );
  }

  _Draft _eLimit(Random rng) {
    final a = 1 + rng.nextInt(3);
    final b = 1 + rng.nextInt(3);
    final s = rng.nextBool() ? 1 : -1;
    final k = s * a * b;
    final inner = '1 ${s > 0 ? '+' : '-'} \\frac{$a}{n}';
    final power = b == 1 ? 'n' : '${b}n';
    final expr = '($inner)^{$power}';
    return _Draft(
      check: CalcCheck.limit,
      zeroOk: true,
      card: '\\lim_{n \\to \\infty} $expr',
      caption: 'As n grows',
      question: 'What does it tend to as n grows without end?',
      hint: '(1 + a/n)ⁿ tends to eᵃ.',
      value: Frac(k),
      format: (v) => ePow(v.n),
      unit: Frac.one,
      traps: [
        (
          Frac.zero,
          '1 ${s > 0 ? '+' : '−'} $a/n tends to 1, but the power grows just as '
              'fast: the limit is a power of e.',
        ),
        (
          Frac(-k),
          'Watch the sign: 1 ${s > 0 ? '+' : '−'} $a/n gives e to a '
              '${s > 0 ? 'plus' : 'minus'}.',
        ),
        if (b > 1)
          (Frac(s * (a + b)), 'The powers multiply, $a × $b; they don\'t add.'),
        if (b > 1) (Frac(s * a), 'You dropped the $b in the power ${b}n.'),
        if (a > 1) (Frac(s * b), '(1 + 1/n)ⁿ → e; with $a/n it is e^$a.'),
      ],
      steps: [
        const CalcStep(
          'The standard limit: (1 + a/n)ⁿ → eᵃ.',
          '(1 + \\frac{a}{n})^{n} \\to e^{a}',
        ),
        CalcStep(
          b == 1
              ? 'Here a = ${tnum(Frac(s * a))}.'
              : 'The power ${b}n is $b lots of n; here a = ${tnum(Frac(s * a))}.',
          b == 1 ? '($inner)^{n} \\to ${ePow(s * a)}' : '(${ePow(s * a)})^{$b}',
        ),
        CalcStep('So the limit is:', '= ${ePow(k)}'),
      ],
      insight: 'Right: (1 + a/n)^(bn) → e^(ab).',
      expr: expr,
      variable: 'n',
      params: {'inf': 1},
    );
  }

  _Draft _powerQuotient(Random rng) {
    final n = 2 + rng.nextInt(3);
    final c = n == 4 ? 2 : 2 + rng.nextInt(2);
    final ans = Frac(n * _ipow(c, n - 1));
    final cn = _ipow(c, n);
    return _Draft(
      check: CalcCheck.limit,
      card: '\\lim_{x \\to $c} \\frac{x^{$n} - $cn}{x - $c}',
      caption: 'Near x = $c',
      question: 'What does it tend to as x goes to $c?',
      hint: 'It\'s 0/0 at x = $c: try L\'Hôpital.',
      value: ans,
      positive: true,
      unit: Frac(max(1, ans.n ~/ 8)),
      traps: [
        (
          Frac(n * cn),
          'The power drops by one: the top\'s slope is $n${_xp('x', n - 1)}.',
        ),
        (
          Frac(_ipow(c, n - 1)),
          'Bring the power down: the top\'s slope is $n${_xp('x', n - 1)}.',
        ),
        (
          Frac(n * (n - 1) * _ipow(c, n - 2)),
          'Differentiate once: the bottom\'s slope is 1, so you\'re done.',
        ),
      ],
      steps: [
        CalcStep(
          'At x = $c it is 0/0. L\'Hôpital: slope of top over slope of bottom.',
          '\\frac{${n}x^{${n - 1}}}{1}',
        ),
        CalcStep('Put x = $c in.', '$n \\cdot $c^{${n - 1}}'),
        CalcStep('So the limit is:', '= ${mnum(ans)}'),
      ],
      insight: 'Right: the top\'s slope over the bottom\'s, at x = $c.',
      expr: '\\frac{x^{$n} - $cn}{x - $c}',
      params: {'to': c},
    );
  }

  _Draft _expQuotient(Random rng) {
    final a = 2 + rng.nextInt(4);
    int b;
    do {
      b = 1 + rng.nextInt(4);
    } while (b == a);
    final ans = Frac(a, b);
    return _Draft(
      check: CalcCheck.limit,
      card: '\\lim_{x \\to 0} \\frac{e^{${a}x} - 1}{${_co(b)}x}',
      caption: 'Near x = 0',
      question: 'What does it tend to as x goes to 0?',
      hint: 'It\'s 0/0 at x = 0: try L\'Hôpital.',
      value: ans,
      positive: true,
      unit: a >= 4 ? Frac(1, b) : Frac(1, 2 * b),
      traps: [
        (
          Frac(1, b),
          'The top\'s slope is ${a}e^(${a}x): the chain rule brings out $a.',
        ),
        if (b != 1) (Frac(a), 'The bottom\'s slope is $b, not 1.'),
        (Frac(b, a), 'Top over bottom, not bottom over top.'),
      ],
      steps: [
        CalcStep(
          'At 0 it is 0/0: take the slopes of top and bottom.',
          '\\frac{${a}e^{${a}x}}{$b}',
        ),
        CalcStep('Put x = 0 in; e⁰ = 1.', '\\frac{$a \\cdot 1}{$b}'),
        CalcStep('So the limit is:', '= ${mnum(ans)}'),
      ],
      insight: 'Right: the top\'s slope over the bottom\'s, at 0.',
      expr: '\\frac{e^{${a}x} - 1}{${_co(b)}x}',
      params: {'to': 0},
    );
  }

  _Draft _cosQuotient(Random rng) {
    final a = 2 + rng.nextInt(3);
    final s = rng.nextBool() ? 1 : -1;
    final ans = Frac(s * a * a, 2);
    final top = s > 0 ? '1 - \\cos(${a}x)' : '\\cos(${a}x) - 1';
    final sg = s > 0 ? '' : '-';
    return _Draft(
      check: CalcCheck.limit,
      card: '\\lim_{x \\to 0} \\frac{$top}{x^{2}}',
      caption: 'Near x = 0',
      question: 'What does it tend to as x goes to 0?',
      hint: 'It\'s 0/0 at x = 0: try L\'Hôpital, maybe twice.',
      value: ans,
      unit: Frac(1, 2),
      traps: [
        (Frac(s * a * a), 'Twice L\'Hôpital makes the bottom 2: halve it.'),
        (Frac.zero - ans, 'The slope of cos is −sin: watch the sign.'),
        (Frac(s * a, 2), 'Each slope brings out an $a: twice, so $a², not $a.'),
      ],
      steps: [
        CalcStep(
          '0/0 at x = 0: take slopes once.',
          '\\frac{$sg$a\\sin(${a}x)}{2x}',
        ),
        CalcStep(
          'Still 0/0: take slopes again.',
          '\\frac{$sg${a * a}\\cos(${a}x)}{2}',
        ),
        CalcStep('Put x = 0 in; cos 0 = 1.', '= ${mnum(ans)}'),
      ],
      insight: 'Right: L\'Hôpital twice, and cos 0 = 1.',
      expr: '\\frac{$top}{x^{2}}',
      params: {'to': 0},
    );
  }

  // ---- level 7: one tangent step -------------------------------------------

  _Draft _estimate(Random rng) => switch (rng.nextInt(4)) {
    0 => _sqrtStep(rng),
    1 => _expStep(rng),
    2 => _lnStep(rng),
    _ => _powerStep(rng),
  };

  static String _true(double v) => v.toStringAsFixed(4).replaceFirst('-', '−');

  static String _signed(Frac h) =>
      h < Frac.zero ? '- ${mdec(Frac.zero - h)}' : '+ ${mdec(h)}';

  _Draft _sqrtStep(Random rng) {
    final root = _pick(rng, const [4, 5, 10, 20]);
    final k = 1 + rng.nextInt(3);
    final s = rng.nextBool() ? 1 : -1;
    final sq = root * root;
    final t = sq + s * k;
    final ans = Frac(root) + Frac(s * k, 2 * root);
    return _Draft(
      check: CalcCheck.estimate,
      card: '\\sqrt{$t}',
      caption: 'The tangent at $sq',
      graph: _tangent(
        sqrt,
        sq.toDouble(),
        1 / (2 * root),
        lo: sq * 0.4,
        hi: sq * 1.6,
        target: t.toDouble(),
        label: '$sq',
      ),
      question: 'Estimate √$t with one tangent step from $sq.',
      hint: 'The slope of √x is 1/(2√x).',
      value: ans,
      decimal: true,
      positive: true,
      unit: Frac(k, 4 * root),
      traps: [
        (
          Frac(root) + Frac(s * k, root),
          'That uses 1/√x as the slope. The slope of √x is 1/(2√x), half of that.',
        ),
        (
          Frac(root) - Frac(s * k, 2 * root),
          '$t is ${s > 0 ? 'above' : 'below'} $sq, so its root is '
              '${s > 0 ? 'above' : 'below'} $root.',
        ),
        (
          Frac(root) + Frac(s * k, 2),
          'The slope is 1/(2√$sq) = 1/${2 * root}, not ½.',
        ),
      ],
      steps: [
        CalcStep('Start where the root is easy.', '\\sqrt{$sq} = $root'),
        CalcStep(
          'The slope of √x is 1/(2√x).',
          '\\frac{1}{2\\sqrt{$sq}} = \\frac{1}{${2 * root}}',
        ),
        CalcStep(
          'Add slope × step. True value: ${_true(sqrt(t))}.',
          '$root ${s > 0 ? '+' : '-'} $k \\cdot \\frac{1}{${2 * root}} = ${mdec(ans)}',
        ),
      ],
      insight: 'Right: f(a) + slope × step.',
      expr: '\\sqrt{x}',
      params: {'a': sq, 'h': s * k, 'order': 1},
    );
  }

  _Draft _expStep(Random rng) {
    final h = Frac((rng.nextBool() ? 1 : -1) * (1 + rng.nextInt(5)), 100);
    final ans = Frac.one + h;
    return _Draft(
      check: CalcCheck.estimate,
      card: 'e^{${mdec(h)}}',
      caption: 'The tangent at 0',
      graph: _tangent(exp, 0, 1, lo: -1, hi: 1, target: h.value, label: '0'),
      question: 'Estimate it with one tangent step from 0.',
      hint: 'The slope of eˣ is eˣ, which is 1 at 0.',
      value: ans,
      decimal: true,
      positive: true,
      unit: Frac(1, 200),
      traps: [
        (h, 'e⁰ is 1, not 0: start from 1.'),
        (
          Frac.one - h,
          'The slope of eˣ at 0 is +1, so the step keeps its sign.',
        ),
        (
          Frac(((1 + e * h.value) * 10000).round(), 10000),
          'The slope of eˣ at 0 is e⁰ = 1, not e.',
        ),
      ],
      steps: [
        const CalcStep('Start at 0, where e⁰ = 1.', 'e^{0} = 1'),
        const CalcStep(
          'The slope of eˣ is eˣ: 1 at 0.',
          '\\frac{d}{dx}e^{x} = e^{x}',
        ),
        CalcStep(
          'Add slope × step. True value: ${_true(exp(h.value))}.',
          '1 ${_signed(h)} = ${mdec(ans)}',
        ),
      ],
      insight: 'Right: near 0, eʰ ≈ 1 + h.',
      expr: 'e^{x}',
      params: {'a': 0, 'h': h.value, 'order': 1},
    );
  }

  _Draft _lnStep(Random rng) {
    final s = rng.nextBool() ? 1 : -1;
    final h = Frac(s * (1 + rng.nextInt(5)), 100);
    final x = Frac.one + h;
    final log10 = Frac((h.value / ln10 * 10000).round(), 10000);
    return _Draft(
      check: CalcCheck.estimate,
      card: '\\ln ${mdec(x)}',
      caption: 'The tangent at 1',
      graph: _tangent(log, 1, 1, lo: 0.4, hi: 1.8, target: x.value, label: '1'),
      question: 'Estimate ln ${tnum(x)} with one tangent step from 1.',
      hint: 'The slope of ln x is 1/x, which is 1 at x = 1.',
      value: h,
      decimal: true,
      unit: Frac(1, 200),
      traps: [
        (Frac.one + h, 'ln 1 is 0, so start from 0, not 1.'),
        (log10, 'That\'s log₁₀; the slope of ln x at 1 is 1.'),
        (
          Frac.zero - h,
          '${tnum(x)} is ${s > 0 ? 'above' : 'below'} 1, so its ln is '
              '${s > 0 ? 'above' : 'below'} 0.',
        ),
      ],
      steps: [
        const CalcStep('Start at 1, where ln 1 = 0.', '\\ln 1 = 0'),
        const CalcStep(
          'The slope of ln x is 1/x: 1 at x = 1.',
          '\\frac{d}{dx} \\ln x = \\frac{1}{x}',
        ),
        CalcStep(
          'Add slope × step. True value: ${_true(log(x.value))}.',
          '0 ${_signed(h)} = ${mdec(h)}',
        ),
      ],
      insight: 'Right: near 1, ln(1 + h) ≈ h.',
      expr: '\\ln x',
      params: {'a': 1, 'h': h.value, 'order': 1},
    );
  }

  _Draft _powerStep(Random rng) {
    final (h, n) = _pick(rng, [
      (Frac(1, 100), 10),
      (Frac(1, 100), 5),
      (Frac(2, 100), 5),
      (Frac(2, 100), 8),
      (Frac(3, 100), 4),
      (Frac(-1, 100), 10),
      (Frac(-2, 100), 6),
      (Frac(5, 100), 3),
    ]);
    final x = Frac.one + h;
    final ans = Frac.one + Frac(n) * h;
    return _Draft(
      check: CalcCheck.estimate,
      card: '(${mdec(x)})^{$n}',
      caption: 'The tangent at 1',
      graph: _tangent(
        (v) => pow(v, n).toDouble(),
        1,
        n.toDouble(),
        lo: 0.82,
        hi: 1.18,
        target: x.value,
        label: '1',
      ),
      question: 'Estimate it with one tangent step from 1.',
      hint: 'The slope of xⁿ at 1 is n.',
      value: ans,
      decimal: true,
      positive: true,
      unit: Frac(1, 200),
      traps: [
        (
          Frac.one + Frac(n - 1) * h,
          'The power comes down whole: $n × ${tnum(h)}, not ${n - 1} × ${tnum(h)}.',
        ),
        (
          Frac.one + h,
          'Raise it to the power: the slope of x${sup(n)} at 1 is $n.',
        ),
        (Frac(n) * x, 'Raising to a power isn\'t multiplying by it.'),
      ],
      steps: [
        CalcStep('Start at x = 1, where 1${sup(n)} = 1.', '1^{$n} = 1'),
        CalcStep(
          'The slope of x${sup(n)} is $n${_xp('x', n - 1)}: $n at x = 1.',
          '\\frac{d}{dx}x^{$n} = ${n}x^{${n - 1}}',
        ),
        CalcStep(
          'Add slope × step. True value: ${_true(pow(x.value, n).toDouble())}.',
          '1 + $n \\cdot ${_argF(h)} = ${mdec(ans)}',
        ),
      ],
      insight: 'Right: (1 + h)ⁿ ≈ 1 + nh for small h.',
      expr: 'x^{$n}',
      params: {'a': 1, 'h': h.value, 'order': 1},
    );
  }

  // ---- level 8: Taylor series ----------------------------------------------

  _Draft _taylor(Random rng) => switch (rng.nextInt(4)) {
    0 => _coefExp(rng),
    1 => _coefTrig(rng),
    2 => _coefLn(rng),
    _ => _secondOrder(rng),
  };

  _Draft _coefExp(Random rng) {
    final a = _pick(rng, const [-2, 2, 3]);
    final k = a == 3 ? 2 + rng.nextInt(2) : 2 + rng.nextInt(3);
    final ak = _ipow(a, k), kf = _fact(k);
    final ans = Frac(ak, kf);
    return _Draft(
      check: CalcCheck.coefficient,
      card: 'e^{${a}x}',
      caption: 'Its series about x = 0',
      question:
          'What is the coefficient of x${sup(k)} in its Taylor series '
          'about 0?',
      hint: 'eᵘ = 1 + u + u²/2! + u³/3! + …',
      value: ans,
      unit: Frac(1, ans.d == 1 ? 2 : ans.d),
      traps: [
        (Frac(ak), 'Each term is divided by k!: here $k! = $kf.'),
        (Frac(a, kf), 'The $a is raised to the power too: (${a}x)${sup(k)}.'),
        (Frac(ak, _fact(k - 1)), 'The x${sup(k)} term has $k!, not ${k - 1}!.'),
        if (k >= 3) (Frac(ak, k), 'Divide by $k! = $kf, not by $k.'),
      ],
      steps: [
        const CalcStep(
          'The series of eᵘ: each term is uᵏ/k!.',
          'e^{u} = 1 + u + \\frac{u^{2}}{2!} + \\frac{u^{3}}{3!} + …',
        ),
        CalcStep(
          'Put u = ${a}x; the x${sup(k)} term is:',
          '\\frac{(${a}x)^{$k}}{$k!} = \\frac{$ak}{$kf}x^{$k}',
        ),
        CalcStep('So the coefficient is:', mnum(ans)),
      ],
      insight: 'Right: (ax)ᵏ/k!.',
      expr: 'e^{${a}x}',
      params: {'k': k},
    );
  }

  _Draft _coefTrig(Random rng) {
    final a = 2 + rng.nextInt(2);
    final (fn, k) = _pick(rng, const [('sin', 3), ('cos', 2), ('cos', 4)]);
    final sign = (fn == 'sin' ? (k - 1) ~/ 2 : k ~/ 2).isEven ? 1 : -1;
    final ak = _ipow(a, k), kf = _fact(k);
    final ans = Frac(sign * ak, kf);
    final series = fn == 'sin'
        ? '\\sin u = u - \\frac{u^{3}}{3!} + …'
        : '\\cos u = 1 - \\frac{u^{2}}{2!} + \\frac{u^{4}}{4!} - …';
    return _Draft(
      check: CalcCheck.coefficient,
      card: _trig(fn, a),
      caption: 'Its series about x = 0',
      question:
          'What is the coefficient of x${sup(k)} in its Taylor series '
          'about 0?',
      hint: fn == 'sin'
          ? 'sin u = u − u³/3! + u⁵/5! − …'
          : 'cos u = 1 − u²/2! + u⁴/4! − …',
      value: ans,
      unit: Frac(1, ans.d == 1 ? 2 : ans.d),
      traps: [
        (
          Frac.zero - ans,
          'The signs alternate: the x${sup(k)} term of $fn has a '
              '${sign < 0 ? 'minus' : 'plus'}.',
        ),
        (Frac(sign * ak), 'Divide by k!: here $k! = $kf.'),
        (
          Frac(sign * a, kf),
          'The $a is raised to the power too: (${a}x)${sup(k)}.',
        ),
      ],
      steps: [
        CalcStep('The series of $fn u about 0.', series),
        CalcStep(
          'Put u = ${a}x; the x${sup(k)} term is:',
          '${sign < 0 ? '-' : ''}\\frac{(${a}x)^{$k}}{$k!} = '
              '${sign < 0 ? '-' : ''}\\frac{$ak}{$kf}x^{$k}',
        ),
        CalcStep('So the coefficient is:', mnum(ans)),
      ],
      insight: 'Right: put u = ${a}x into the series, signs and all.',
      expr: _trig(fn, a),
      params: {'k': k},
    );
  }

  _Draft _coefLn(Random rng) {
    final a = 2 + rng.nextInt(2);
    final k = 2 + rng.nextInt(2);
    final sign = k.isOdd ? 1 : -1;
    final ak = _ipow(a, k);
    final ans = Frac(sign * ak, k);
    return _Draft(
      check: CalcCheck.coefficient,
      card: '\\ln(1 + ${a}x)',
      caption: 'Its series about x = 0',
      question:
          'What is the coefficient of x${sup(k)} in its Taylor series '
          'about 0?',
      hint: 'ln(1 + u) = u − u²/2 + u³/3 − …',
      value: ans,
      unit: Frac(1, ans.d == 1 ? 2 : ans.d),
      traps: [
        (
          Frac.zero - ans,
          'The signs alternate: + − + …, so the x${sup(k)} term has a '
              '${sign < 0 ? 'minus' : 'plus'}.',
        ),
        if (k >= 3)
          (Frac(sign * ak, _fact(k)), 'ln\'s series divides by k, not k!.'),
        (
          Frac(sign * a, k),
          'The $a is raised to the power too: (${a}x)${sup(k)}.',
        ),
        (Frac(sign * ak), 'Each term is divided by its power: here $k.'),
      ],
      steps: [
        const CalcStep(
          'The series of ln(1 + u) about 0.',
          '\\ln(1 + u) = u - \\frac{u^{2}}{2} + \\frac{u^{3}}{3} - …',
        ),
        CalcStep(
          'Put u = ${a}x; the x${sup(k)} term is:',
          '${sign < 0 ? '-' : ''}\\frac{(${a}x)^{$k}}{$k} = '
              '${sign < 0 ? '-' : ''}\\frac{$ak}{$k}x^{$k}',
        ),
        CalcStep('So the coefficient is:', mnum(ans)),
      ],
      insight: 'Right: uᵏ/k with alternating signs, u = ${a}x.',
      expr: '\\ln(1 + ${a}x)',
      params: {'k': k},
    );
  }

  _Draft _secondOrder(Random rng) {
    final which = rng.nextInt(4);
    late Frac h, ans, first, noHalf, wrongSign;
    late String card, expr, how, tangentAt;
    late double a, slope, truth;
    late double Function(double) f;
    late String q, term;
    late List<String> whys;
    switch (which) {
      case 0:
        h = _pick(rng, [Frac(1, 10), Frac(2, 10), Frac(-1, 10), Frac(-2, 10)]);
        final h2 = h * h / Frac(2);
        first = Frac.one + h;
        ans = first + h2;
        noHalf = first + h * h;
        wrongSign = first - h2;
        card = 'e^{${mdec(h)}}';
        q = 'it';
        expr = 'e^{x}';
        a = 0;
        slope = 1;
        f = exp;
        truth = exp(h.value);
        tangentAt = '0';
        term = '1 ${_signed(h)} + \\frac{${_argF(h)}^{2}}{2}';
        how = 'Here f, f′ and f″ are all 1 at 0.';
        whys = [
          'That stops at first order; add the h²/2 term.',
          'The second-order term is h²/2: keep the ½.',
          'eˣ curves up, so the h²/2 term is added.',
        ];
      case 1:
        h = _pick(rng, [Frac(1, 10), Frac(2, 10), Frac(3, 10)]);
        final h2 = h * h / Frac(2);
        first = Frac.one;
        ans = first - h2;
        noHalf = first - h * h;
        wrongSign = first + h2;
        card = '\\cos ${mdec(h)}';
        q = 'it (in radians)';
        expr = '\\cos x';
        a = 0;
        slope = 0;
        f = cos;
        truth = cos(h.value);
        tangentAt = '0';
        term = '1 - \\frac{${mdec(h)}^{2}}{2}';
        how = 'At 0: cos = 1, its slope is 0, and f″ = −1.';
        whys = [
          'That stops at first order; cos needs its −h²/2 term.',
          'The term is −h²/2: keep the ½.',
          'cos curves down from 1, so the h²/2 is taken away.',
        ];
      case 2:
        h = _pick(rng, [Frac(2, 10), Frac(4, 10), Frac(-2, 10)]);
        final h2 = h * h / Frac(8);
        first = Frac.one + h / Frac(2);
        ans = first - h2;
        noHalf = first - h * h / Frac(4);
        wrongSign = first + h2;
        card = '\\sqrt{${mdec(Frac.one + h)}}';
        q = '√${tnum(Frac.one + h)}';
        expr = '\\sqrt{x}';
        a = 1;
        slope = 0.5;
        f = sqrt;
        truth = sqrt(1 + h.value);
        tangentAt = '1';
        term = '1 ${_signed(h / Frac(2))} - \\frac{${_argF(h)}^{2}}{8}';
        how = 'At 1: √x = 1, its slope is ½, and f″ = −¼.';
        whys = [
          'That stops at first order; add the −h²/8 term.',
          'f″(1)/2 is −¼ ÷ 2 = −⅛, not −¼.',
          '√x curves down, so the h²/8 is taken away.',
        ];
      default:
        h = _pick(rng, [Frac(1, 10), Frac(2, 10), Frac(-1, 10)]);
        final h2 = h * h / Frac(2);
        first = h;
        ans = first - h2;
        noHalf = first - h * h;
        wrongSign = first + h2;
        card = '\\ln ${mdec(Frac.one + h)}';
        q = 'ln ${tnum(Frac.one + h)}';
        expr = '\\ln x';
        a = 1;
        slope = 1;
        f = log;
        truth = log(1 + h.value);
        tangentAt = '1';
        term = '${mdec(h)} - \\frac{${_argF(h)}^{2}}{2}';
        how = 'At 1: ln = 0, its slope is 1, and f″ = −1.';
        whys = [
          'That stops at first order; take away h²/2.',
          'The term is −h²/2: keep the ½.',
          'ln curves down, so the h²/2 is taken away.',
        ];
    }
    return _Draft(
      check: CalcCheck.estimate,
      card: card,
      caption: 'Tangent and curve at $tangentAt',
      graph: _tangent(
        f,
        a,
        slope,
        lo: a == 0 ? -1.2 : 0.3,
        hi: a == 0 ? 1.2 : 2.0,
        target: a + h.value,
        label: tangentAt,
      ),
      question: 'Estimate $q to second order.',
      hint: 'f(a + h) ≈ f(a) + f′(a)h + f″(a)h²/2.',
      value: ans,
      decimal: true,
      unit: Frac(1, 200),
      traps: [(first, whys[0]), (noHalf, whys[1]), (wrongSign, whys[2])],
      steps: [
        CalcStep(
          how,
          'f(a + h) \\approx f(a) + f′(a)h + \\frac{f″(a)}{2}h^{2}',
        ),
        CalcStep('Put h = ${tnum(h)} in.', term),
        CalcStep('True value: ${_true(truth)}.', '= ${mdec(ans)}'),
      ],
      insight: 'Right: the h²/2 term is what first order misses.',
      expr: expr,
      params: {'a': a, 'h': h.value, 'order': 2},
    );
  }

  // ---- level 9: maxima and minima ------------------------------------------

  _Draft _extremum(Random rng) => switch (rng.nextInt(6)) {
    0 || 1 => _cubic(rng),
    2 => _fence(rng),
    3 => _box(rng),
    4 => _price(rng),
    _ => _split(rng),
  };

  _Draft _cubic(Random rng) {
    int r1, r2;
    do {
      r1 = -4 + rng.nextInt(9);
      r2 = -4 + rng.nextInt(9);
    } while (r2 - r1 < 2 || (r1 + r2).isOdd);
    final s = rng.nextBool() ? 1 : -1;
    final wantMax = rng.nextBool();
    final f = <Term>[
      (Frac(s), 3),
      (Frac(-3 * s * (r1 + r2) ~/ 2), 2),
      (Frac(3 * s * r1 * r2), 1),
    ];
    final df = <Term>[
      (Frac(3 * s), 2),
      (Frac(-3 * s * (r1 + r2)), 1),
      (Frac(3 * s * r1 * r2), 0),
    ];
    // f = s(x³ …): with s = 1 the left turning point is the peak.
    final maxAt = s > 0 ? r1 : r2;
    final minAt = s > 0 ? r2 : r1;
    final ans = wantMax ? maxAt : minAt;
    final other = wantMax ? minAt : maxAt;
    final mid = (r1 + r2) ~/ 2;
    final f2 = 6 * s * ans - 3 * s * (r1 + r2);
    final what = wantMax ? 'maximum' : 'minimum';
    final factors = '${s < 0 ? '-' : ''}3(${_xMinus(r1)})(${_xMinus(r2)})';
    return _Draft(
      check: CalcCheck.extremum,
      zeroOk: true,
      card: 'f(x) = ${poly(f)}',
      caption: 'Find the turning points',
      reviewGraph: CalcGraph(
        f: polyFn(f),
        lo: r1 - 1.5,
        hi: r2 + 1.5,
        at: ans.toDouble(),
        slope: 0,
        labels: {r1.toDouble(): '$r1', r2.toDouble(): '$r2'},
      ),
      question: 'Where does f have its local $what?',
      hint: 'Solve f′(x) = 0, then check the sign of f″ there.',
      value: Frac(ans),
      unit: Frac.one,
      traps: [
        (
          Frac(other),
          'f′ = 0 there too, but that\'s the local ${wantMax ? 'minimum' : 'maximum'}.',
        ),
        if (mid != ans)
          (Frac(mid), 'f″ = 0 there: the curve bends, it doesn\'t turn.'),
        for (final r in [-r1, -r2])
          (
            Frac(r),
            'A sign slipped: f′(x) = 0 at x = ${tnum(Frac(r1))} and '
                'x = ${tnum(Frac(r2))}.',
          ),
        (Frac.zero, 'f(0) = 0: that\'s where f crosses zero. Set f′ = 0.'),
      ],
      steps: [
        CalcStep('Set the slope to zero.', 'f′(x) = ${poly(df)} = 0'),
        CalcStep(
          'Factor it: x = ${tnum(Frac(r1))} or x = ${tnum(Frac(r2))}.',
          '$factors = 0',
        ),
        CalcStep(
          '${wantMax ? 'Negative' : 'Positive'} f″ means a $what.',
          'f″($ans) = $f2 ${f2 < 0 ? '<' : '>'} 0',
        ),
      ],
      insight: 'Right: f′ = 0, and f″ says which way it turns.',
      expr: poly(f),
      params: {'lo': r1 - 3, 'hi': r2 + 3, 'want': wantMax ? 1 : -1, 'ask': 0},
    );
  }

  _Draft _fence(Random rng) {
    final l = _pick(rng, const [24, 36, 48, 60, 72]);
    final ans = Frac(l * l, 8);
    return _Draft(
      check: CalcCheck.extremum,
      card: 'A(x) = x($l - 2x)',
      caption: 'Width x, wall on one side',
      reviewGraph: CalcGraph(
        f: (x) => x * (l - 2 * x),
        lo: 0,
        hi: l / 2,
        at: l / 4,
        slope: 0,
        labels: {l / 4: '${l ~/ 4}'},
      ),
      question:
          '$l m of fence makes three sides of a rectangle; a wall is '
          'the fourth. What is the largest area, in m²?',
      hint: 'Set A′(x) = 0.',
      value: ans,
      positive: true,
      unit: Frac(l * l, 96),
      traps: [
        (
          Frac(l * l, 9),
          'Equal sides aren\'t best: the wall side is free, so make it longer.',
        ),
        (
          Frac(l * l, 16),
          'A square is best with four fenced sides; the wall gives one free.',
        ),
        (Frac(l, 4), 'That\'s the best width x, not the area.'),
        (
          Frac(l * l, 4),
          'Two sides are x, so the wall side is $l − 2x, not $l − x.',
        ),
      ],
      steps: [
        CalcStep(
          'The area is x times the side along the wall.',
          'A(x) = ${l}x - 2x^{2}',
        ),
        CalcStep(
          'Set the slope to zero.',
          'A′(x) = $l - 4x = 0, x = ${l ~/ 4}',
        ),
        CalcStep(
          'So the largest area is:',
          '${l ~/ 4} \\cdot ${l ~/ 2} = ${l * l ~/ 8}',
        ),
      ],
      insight: 'Right: the side along the wall is twice the width.',
      expr: 'x($l - 2x)',
      params: {'lo': 0, 'hi': l / 2, 'want': 1, 'ask': 1},
    );
  }

  _Draft _box(Random rng) {
    final s = _pick(rng, const [12, 18, 24, 30, 36]);
    final ans = Frac(s, 6);
    return _Draft(
      check: CalcCheck.extremum,
      card: 'V(x) = x($s - 2x)^{2}',
      caption: 'Cut x from each corner',
      reviewGraph: CalcGraph(
        f: (x) => x * (s - 2 * x) * (s - 2 * x),
        lo: 0,
        hi: s / 2,
        at: s / 6,
        slope: 0,
        labels: {s / 6: '${s ~/ 6}', s / 2: '${s ~/ 2}'},
      ),
      question:
          'Cut an x by x square from each corner of a $s cm sheet and '
          'fold up the sides. Which x makes the biggest box?',
      hint: 'Set V′(x) = 0; one root gives a flat box.',
      value: ans,
      positive: true,
      unit: Frac(1, 2),
      traps: [
        (Frac(s, 2), 'V′ = 0 there too, but V = 0: that\'s the smallest box.'),
        (Frac(s, 4), 'Halfway to ${s ~/ 2} isn\'t the top: solve V′(x) = 0.'),
        (
          Frac(s, 3),
          'Cutting the sheet in thirds isn\'t best: solve V′(x) = 0.',
        ),
      ],
      steps: [
        CalcStep(
          'Differentiate (product rule) and factor.',
          'V′(x) = ($s - 2x)($s - 6x)',
        ),
        CalcStep('V′ = 0 at x = ${s ~/ 6} or x = ${s ~/ 2}.'),
        CalcStep(
          'At x = ${s ~/ 2} the box is flat, so the biggest is at:',
          'x = ${s ~/ 6}',
        ),
      ],
      insight: 'Right: a sixth of the sheet.',
      expr: 'x($s - 2x)^{2}',
      params: {'lo': 0, 'hi': s / 2, 'want': 1, 'ask': 0},
    );
  }

  _Draft _price(Random rng) {
    final a = _pick(rng, const [120, 200, 240]);
    final b = _pick(rng, const [2, 4, 5]);
    final ans = Frac(a, 2 * b);
    return _Draft(
      check: CalcCheck.extremum,
      card: 'R(p) = p($a - ${b}p)',
      caption: 'Revenue at price p',
      reviewGraph: CalcGraph(
        f: (p) => p * (a - b * p),
        lo: 0,
        hi: a / b,
        at: a / (2 * b),
        slope: 0,
        labels: {a / (2 * b): ans.toString()},
      ),
      question:
          'At a price of p dollars you sell $a − ${b}p a day. Which '
          'price brings in the most?',
      hint: 'Set R′(p) = 0.',
      value: ans,
      positive: true,
      unit: Frac(a, 20 * b),
      traps: [
        (
          Frac(a, b),
          'Sales are zero at that price: revenue is 0, the minimum.',
        ),
        (
          Frac(a, 4 * b),
          'Too low: R′(p) = $a − ${2 * b}p is still positive there.',
        ),
        (Frac(a * a, 4 * b), 'That\'s the most revenue, not the price.'),
      ],
      steps: [
        CalcStep('Revenue is price times sales.', 'R(p) = ${a}p - ${b}p^{2}'),
        CalcStep('Set the slope to zero.', 'R′(p) = $a - ${2 * b}p = 0'),
        CalcStep('So the best price is:', 'p = ${mnum(ans)}'),
      ],
      insight: 'Right: halfway to the price where sales hit zero.',
      expr: 'p($a - ${b}p)',
      variable: 'p',
      params: {'lo': 0, 'hi': a / b, 'want': 1, 'ask': 0},
    );
  }

  _Draft _split(Random rng) {
    final s = _pick(rng, const [9, 12, 15, 18, 21]);
    final ans = Frac(2 * s, 3);
    return _Draft(
      check: CalcCheck.extremum,
      card: 'P(y) = ($s - y)y^{2}',
      caption: 'x = $s − y',
      reviewGraph: CalcGraph(
        f: (y) => (s - y) * y * y,
        lo: 0,
        hi: s.toDouble(),
        at: 2 * s / 3,
        slope: 0,
        labels: {2 * s / 3: '${2 * s ~/ 3}'},
      ),
      question:
          'Two positive numbers x and y add up to $s. Which y makes '
          'x·y² as big as it can be?',
      hint: 'Write it in y alone, then set the slope to zero.',
      value: ans,
      positive: true,
      unit: Frac.one,
      traps: [
        (Frac(s, 2), 'An equal split is best for x·y, not for x·y².'),
        (Frac(s, 3), 'That\'s x, the other number.'),
        (Frac(s), 'y = $s leaves x = 0, so x·y² = 0.'),
        (Frac(3 * s, 2), 'Upside down: ${2 * s}y = 3y² gives y = ${2 * s}/3.'),
      ],
      steps: [
        CalcStep('Write it in y alone.', 'P(y) = ${s}y^{2} - y^{3}'),
        CalcStep('Set the slope to zero.', 'P′(y) = ${2 * s}y - 3y^{2} = 0'),
        CalcStep('y = 0 gives 0, so the biggest is at:', 'y = ${2 * s ~/ 3}'),
      ],
      insight: 'Right: y takes two thirds, x one third.',
      expr: '($s - y)y^{2}',
      variable: 'y',
      params: {'lo': 0, 'hi': s, 'want': 1, 'ask': 0},
    );
  }
}

class _Draft {
  _Draft({
    required this.check,
    required this.card,
    required this.caption,
    this.graph,
    this.reviewGraph,
    required this.question,
    required this.hint,
    this.value,
    this.traps = const [],
    this.unit = Frac.one,
    this.decimal = false,
    this.positive = false,
    this.zeroOk = false,
    this.format,
    this.formula,
    this.formulaTraps = const [],
    required this.steps,
    required this.insight,
    required this.expr,
    this.variable = 'x',
    this.params = const {},
  });

  final CalcCheck check;
  final String card;
  final String caption;
  final CalcGraph? graph, reviewGraph;
  final String question;
  final String hint;

  /// A number answer, its named slips and the step for near misses.
  final Frac? value;
  final List<(Frac, String)> traps;
  final Frac unit;

  /// Options are exact decimals (up to four places).
  final bool decimal;
  final bool positive;

  /// The answer itself can be 0 (a slope, a turning point), so 0 may be
  /// offered.
  final bool zeroOk;

  /// How a number option is written, if not as a plain number.
  final String Function(Frac)? format;

  /// A formula answer and its named slips.
  final String? formula;
  final List<(String, String)> formulaTraps;

  final List<CalcStep> steps;
  final String insight;
  final String expr;
  final String variable;
  final Map<String, num> params;
}
