import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../expect_it/expect_puzzle.dart' show ev;
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum BrownKind {
  scaling,
  increments,
  table,
  reflection,
  martingale,
  stopping,
  drift,
  ito,
  gbm,
}

/// A dashed level across a path picture.
@immutable
class BrownLevel {
  const BrownLevel(this.y, this.label, {this.spark = false});

  final double y;
  final String label;

  /// Spark orange: the level the question is about.
  final bool spark;
}

/// A marked time under a path picture.
@immutable
class BrownMark {
  const BrownMark(this.t, this.label, {this.spark = false});

  final double t;
  final String label;
  final bool spark;
}

/// One possible path, drawn from the question's seed: values at equal time
/// steps from 0 to [tEnd].
@immutable
class BrownPath {
  const BrownPath({
    required this.ys,
    required this.tEnd,
    this.levels = const [],
    this.marks = const [],
    this.from,
    this.to,
    this.endDot = false,
  });

  final List<double> ys;
  final double tEnd;
  final List<BrownLevel> levels;
  final List<BrownMark> marks;

  /// The stretch of the path drawn in spark orange (a step being asked
  /// about).
  final double? from, to;

  /// A spark dot where the path ends (where it stopped).
  final bool endDot;
}

/// Which part of a bell curve is shaded.
enum BellShade { above, below, outside }

/// A normal curve in z units, with a tail (or two) shaded.
@immutable
class BrownBell {
  const BrownBell({
    required this.cut,
    required this.shade,
    this.labels = const {},
  });

  /// Where the shading starts, in SDs from the middle.
  final double cut;
  final BellShade shade;

  /// Labels under the axis, keyed by z.
  final Map<double, String> labels;
}

/// One line of working: plain words, then (optionally) a line of maths.
@immutable
class BrownStep {
  const BrownStep(this.text, [this.math]);

  final String text;

  /// [MathText] source.
  final String? math;
}

/// A wrong answer and the slip behind it.
@immutable
class BrownTrap {
  const BrownTrap(this.label, this.why, [this.value]);

  /// [MathText] source.
  final String label;
  final String why;

  /// Its sort key, for number options.
  final Frac? value;
}

@immutable
class BrownQuestion {
  const BrownQuestion({
    required this.level,
    required this.seed,
    required this.kind,
    required this.variant,
    required this.card,
    required this.given,
    required this.caption,
    required this.path,
    required this.bell,
    required this.table,
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
    required this.showPictureInReview,
  });

  final int level;
  final int seed;
  final BrownKind kind;

  /// Which question of its kind (see the generator).
  final int variant;

  /// What is asked, as [MathText] source.
  final String card;

  /// The process it's about, as [MathText] source, if any.
  final String? given;

  /// A short label under the card.
  final String caption;

  /// The picture: a path or a bell curve.
  final BrownPath? path;
  final BrownBell? bell;

  /// The normal table on the card: 2z for each column shown.
  final List<int>? table;

  final String question;
  final String hint;

  /// [MathText] source of the right option.
  final String answer;

  /// For number answers, its value (for powers of e, the power).
  final Frac? answerValue;
  final List<BrownTrap> traps;
  final List<String> options;

  /// Sort keys of number options, ascending; null for formulas.
  final List<Frac>? optionValues;

  /// "about 0.67" under fractions that aren't tidy decimals.
  final List<String?> notes;
  final List<BrownStep> steps;
  final String insight;

  /// The numbers behind the question, for recomputing in tests.
  final Map<String, num> params;

  /// The review shows the picture again.
  final bool showPictureInReview;

  /// Numbers, sorted; otherwise formulas in random order.
  bool get numeric => optionValues != null;

  int get answerIndex => options.indexOf(answer);

  String feedbackFor(String picked) => picked == answer
      ? insight
      : traps.firstWhere((t) => t.label == picked).why;
}

class BrownDifficulty {
  static List<BrownKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [BrownKind.scaling],
    2 => const [BrownKind.increments],
    3 => const [BrownKind.table],
    4 => const [BrownKind.reflection],
    5 => const [BrownKind.martingale],
    6 => const [BrownKind.stopping],
    7 => const [BrownKind.drift],
    8 => const [BrownKind.ito],
    9 => const [BrownKind.gbm],
    _ => const [
      BrownKind.reflection,
      BrownKind.martingale,
      BrownKind.stopping,
      BrownKind.drift,
      BrownKind.ito,
      BrownKind.gbm,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'how fast Brownian motion spreads',
    2 => 'steps and overlaps',
    3 => 'reading a normal table',
    4 => 'touching a level',
    5 => 'spotting martingales',
    6 => 'stopping at a level',
    7 => 'Brownian motion with drift',
    8 => 'Itô\'s rule in small steps',
    9 => 'stock prices: geometric Brownian motion',
    _ => 'any of them',
  };
}

// ---- formatting --------------------------------------------------------------

/// A number as [MathText] source: whole, a tidy decimal (up to 4 places),
/// or a fraction.
String bnum(Frac v) {
  if (v.d == 1) return '${v.n}';
  if (10000 % v.d == 0) return _decimal(v);
  return '${v.n < 0 ? '-' : ''}\\frac{${v.n.abs()}}{${v.d}}';
}

/// A number as plain text, with a real minus sign.
String tnum(Frac v) {
  final s = v.d == 1
      ? '${v.n.abs()}'
      : 10000 % v.d == 0
      ? _decimal(Frac(v.n.abs(), v.d))
      : '${v.n.abs()}/${v.d}';
  return v.n < 0 ? '−$s' : s;
}

/// "about 0.67" under a fraction that isn't a tidy decimal.
String? fracNote(Frac v) => v.d == 1 || 10000 % v.d == 0
    ? null
    : 'about ${v.value.toStringAsFixed(2).replaceFirst('-', '−')}';

/// A chance as a percentage: "15.9%".
String pc(Frac f) => '${ev(f * Frac(100))}%';

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

/// The share of a standard normal above z, as the card's table gives it,
/// for z = 0.5, 1, … 2.5 (keyed by 2z), to 0.1%.
final Map<int, Frac> normalTable = {
  1: Frac(309, 1000),
  2: Frac(159, 1000),
  3: Frac(67, 1000),
  4: Frac(23, 1000),
  5: Frac(6, 1000),
};

/// P(Z > z) for z = [twiceZ] / 2, read from the table (negative z by
/// symmetry); null when the table doesn't have it.
Frac? tail(int twiceZ) {
  if (twiceZ == 0) return Frac(1, 2);
  if (twiceZ < 0) {
    final up = normalTable[-twiceZ];
    return up == null ? null : Frac.one - up;
  }
  return normalTable[twiceZ];
}

/// 2z as a whole number, or null when z isn't a multiple of ½.
int? twice(Frac z) {
  final t = z * Frac(2);
  return t.d == 1 ? t.n : null;
}

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

/// W at a whole time, as plain text: "W₂₅".
String _w(int k) =>
    'W${'$k'.split('').map((c) => '₀₁₂₃₄₅₆₇₈₉'[int.parse(c)]).join()}';

/// The coefficient in front of a letter: "" for 1, "0.5" otherwise.
String _co(Frac c) => c == Frac.one ? '' : bnum(c);

class BrownGenerator {
  const BrownGenerator();

  static const _again = 'Check the numbers again: see the working.';

  BrownQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = BrownDifficulty.kindsFor(level);
    for (var attempt = 0; ; attempt++) {
      final kind = kinds[rng.nextInt(kinds.length)];
      final d = switch (kind) {
        BrownKind.scaling => _scaling(rng),
        BrownKind.increments => _increments(rng),
        BrownKind.table => _table(rng),
        BrownKind.reflection => _reflection(rng),
        BrownKind.martingale => _martingale(rng),
        BrownKind.stopping => _stopping(rng),
        BrownKind.drift => _drift(rng),
        BrownKind.ito => _ito(rng),
        BrownKind.gbm => _gbm(rng),
      };
      final q = d.formula != null
          ? _formulaQuestion(d, level, seed, kind, rng)
          : _numberQuestion(d, level, seed, kind, rng);
      // A fraction among tidy numbers (or the reverse) would give the
      // answer away: try another setup.
      if (q != null || attempt > 40) {
        return q ?? _numberQuestion(d, level, seed, kind, rng, strict: false)!;
      }
    }
  }

  BrownQuestion? _numberQuestion(
    _Draft d,
    int level,
    int seed,
    BrownKind kind,
    Random rng, {
    bool strict = true,
  }) {
    final a = d.value!;
    final format = d.format ?? bnum;
    BrownTrap t(Frac v, String why) => BrownTrap(format(v), why, v);
    bool fits(Frac v) =>
        v != a &&
        (d.above == null || v > d.above!) &&
        (d.below == null || v < d.below!);
    final near =
        d.fillers ??
        [
          for (final k in [1, 2, 3])
            for (final sign in [1, -1]) a + d.unit * Frac(sign * k),
        ];
    final fillers = [
      for (final v in near)
        if (fits(v)) t(v, _again),
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
    if (chosen.length < 4) return null;
    final notes = [
      for (final c in chosen)
        d.note != null
            ? d.note!(c.value!)
            : d.format == null
            ? fracNote(c.value!)
            : null,
    ];
    if (strict && d.format == null) {
      final mine = fracNote(a) != null;
      final same = chosen.where((c) => (fracNote(c.value!) != null) == mine);
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

  BrownQuestion _formulaQuestion(
    _Draft d,
    int level,
    int seed,
    BrownKind kind,
    Random rng,
  ) {
    final seen = {d.formula!};
    final traps = <BrownTrap>[];
    for (final (label, why) in d.formulaTraps) {
      if (traps.length == 3) break;
      if (seen.add(label)) traps.add(BrownTrap(label, why));
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

  BrownQuestion _question(
    _Draft d,
    int level,
    int seed,
    BrownKind kind, {
    required String answer,
    required List<BrownTrap> traps,
    required List<String> options,
    required List<Frac>? values,
    required List<String?> notes,
  }) => BrownQuestion(
    level: level,
    seed: seed,
    kind: kind,
    variant: d.variant,
    card: d.card,
    given: d.given,
    caption: d.caption,
    path: d.path,
    bell: d.bell,
    table: d.table,
    question: d.question,
    hint: d.hint,
    answer: answer,
    answerValue: d.value,
    traps: traps,
    options: options,
    optionValues: values,
    notes: notes,
    steps: d.steps,
    insight: d.insight,
    params: d.params,
    showPictureInReview: d.review,
  );

  // ---- helpers ------------------------------------------------------------

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  static final _half = Frac(1, 2);

  static double _gauss(Random r) {
    final u = r.nextDouble() + 1e-12, v = r.nextDouble();
    return sqrt(-2 * log(u)) * cos(2 * pi * v);
  }

  /// A sample path of μt + σW_t over [0, tEnd] in [n] steps.
  static List<double> _sample(
    Random r,
    double tEnd, {
    double mu = 0,
    double sigma = 1,
    int n = 90,
  }) {
    final dt = tEnd / n;
    final ys = [0.0];
    var x = 0.0;
    for (var i = 0; i < n; i++) {
      x += mu * dt + sigma * sqrt(dt) * _gauss(r);
      ys.add(x);
    }
    return ys;
  }

  /// A path to [t], preferring one that does (or doesn't) touch [level].
  static List<double> _toward(
    Random rng,
    double t, {
    required double level,
    required bool touch,
  }) {
    final r = Random(rng.nextInt(1 << 30));
    var ys = _sample(r, t);
    for (var i = 0; i < 30; i++) {
      final top = level > 0 ? ys.reduce(max) : -ys.reduce(min);
      if ((top >= level.abs()) == touch) break;
      ys = _sample(r, t);
    }
    return ys;
  }

  /// A path of μt + σW_t until it reaches [hi] or [lo] (drawn up to the
  /// hit), within about [t].
  static List<double> _untilHit(
    Random rng,
    double t, {
    required double hi,
    required double lo,
    double mu = 0,
    double sigma = 1,
  }) {
    final r = Random(rng.nextInt(1 << 30));
    List<double> once() {
      const n = 90;
      final dt = t / n;
      final ys = [0.0];
      var x = 0.0;
      for (var i = 0; i < 3 * n; i++) {
        x += mu * dt + sigma * sqrt(dt) * _gauss(r);
        if (x >= hi || x <= lo) {
          ys.add(x >= hi ? hi : lo);
          return ys;
        }
        ys.add(x);
      }
      return ys;
    }

    var ys = once();
    for (var i = 0; i < 30; i++) {
      final end = ys.last;
      if ((end == hi || end == lo) && ys.length > 25) break;
      ys = once();
    }
    return ys;
  }

  /// A path stopped at the first of two levels (the highest and lowest of
  /// [levels]), with τ marked where it stopped.
  static BrownPath _stopped(
    Random rng,
    double t, {
    required List<BrownLevel> levels,
    double mu = 0,
    bool sparkTime = false,
  }) {
    final ys = levels.map((l) => l.y);
    final hi = ys.reduce(max), lo = ys.reduce(min);
    final path = _untilHit(rng, t, hi: hi, lo: lo, mu: mu);
    final end = (path.length - 1) * t / 90;
    final hit = path.last == hi || path.last == lo;
    return BrownPath(
      ys: path,
      tEnd: end,
      levels: levels,
      marks: [if (hit) BrownMark(end, 'τ', spark: sparkTime)],
      endDot: hit,
    );
  }

  static BrownPath _plain(Random rng, Frac t, {String? label}) {
    final tt = t.value;
    return BrownPath(
      ys: _sample(Random(rng.nextInt(1 << 30)), tt),
      tEnd: tt,
      marks: [BrownMark(tt, label ?? 't = ${tnum(t)}')],
    );
  }

  /// The columns of the table to show: four in a row, holding the
  /// answer's z and as many of the traps' as fit.
  static List<int> _window(int answer, Iterable<int?> others) {
    var best = const [1, 2, 3, 4];
    var bestScore = -1;
    for (final start in [1, 2]) {
      final cols = [for (var c = start; c < start + 4; c++) c];
      if (!cols.contains(answer.abs()) && answer != 0) continue;
      var score = 0;
      for (final o in others) {
        if (o != null && cols.contains(o.abs())) score += 2;
      }
      // Room on both sides of the answer's column.
      if (answer.abs() != cols.first && answer.abs() != cols.last) score++;
      if (score > bestScore) {
        bestScore = score;
        best = cols;
      }
    }
    return best;
  }

  /// Chances made from the shown columns, for near misses.
  static List<Frac> _tableFillers(List<int> cols) => [
    for (final c in cols) ...[
      normalTable[c]!,
      Frac.one - normalTable[c]!,
      normalTable[c]! * Frac(2),
      Frac.one - normalTable[c]! * Frac(2),
    ],
  ];

  /// The trap for one table entry, if it's on the card.
  static (Frac, String)? _ifShown(
    List<int> cols,
    int? z2,
    Frac Function(Frac) f,
    String why,
  ) {
    if (z2 == null || !cols.contains(z2.abs()) || z2 == 0) return null;
    final q = tail(z2);
    return q == null ? null : (f(q), why);
  }

  // ---- level 1: scaling ----------------------------------------------------

  _Draft _scaling(Random rng) {
    final v = rng.nextInt(4);
    if (v == 0) {
      final k = _pick(rng, [
        _half,
        Frac(2),
        Frac(3),
        Frac(4),
        Frac(5),
        Frac(6),
        Frac(7),
        Frac(8),
        Frac(10),
      ]);
      final t = k * k;
      final tt = tnum(t);
      return _Draft(
        variant: v,
        card: 'SD(W_{${bnum(t)}})',
        caption: 'Mean 0, variance t',
        path: _plain(rng, t),
        question:
            'W is a Brownian motion starting at 0. What is its standard '
            'deviation (SD) at time $tt?',
        hint: 'Its variance grows like time: at time t it is t.',
        value: k,
        above: Frac.zero,
        unit: k < Frac.one ? Frac(1, 10) : Frac.one,
        traps: [
          (t, 'That\'s the variance, $tt. The SD is its square root.'),
          (t / Frac(2), 'Halving isn\'t a square root: the SD is √$tt.'),
          (k * Frac(2), 'That\'s 2 SDs, the edge of the 95% band.'),
          (Frac.one, 'That\'s the SD at time 1. It grows like √t.'),
        ],
        steps: [
          BrownStep(
            'Brownian motion spreads with time: its variance at t is t.',
            'Var(W_{${bnum(t)}}) = ${bnum(t)}',
          ),
          const BrownStep('The SD is the square root of the variance.'),
          BrownStep('So:', 'SD = \\sqrt{${bnum(t)}} = ${bnum(k)}'),
        ],
        insight: 'Right: the SD grows like √t, not like t.',
        params: {'t': t.value},
      );
    }
    if (v == 1) {
      final s = _pick(rng, [Frac(2), Frac(3), Frac(5), _half]);
      final r = _pick(rng, const [2, 3, 4, 5]);
      final t = Frac(r * r);
      final ans = s * Frac(r);
      return _Draft(
        variant: v,
        card: 'SD(${bnum(s)}W_{${bnum(t)}})',
        caption: 'Brownian motion, scaled',
        path: _plain(rng, t),
        question:
            'X = ${tnum(s)}W, a Brownian motion scaled by ${tnum(s)}. What is '
            'its SD at time ${tnum(t)}?',
        hint: 'Scaling by σ scales the SD by σ.',
        value: ans,
        above: Frac.zero,
        unit: ans < Frac(2) ? Frac(1, 4) : Frac.one,
        traps: [
          (
            s * t,
            'That uses t instead of √t: the SD is ${tnum(s)} × √${tnum(t)}.',
          ),
          (s * s * t, 'That\'s the variance, σ²t. Take its square root.'),
          (s + Frac(r), 'The SD multiplies: ${tnum(s)} × $r, not plus.'),
          (Frac(r), 'That leaves out the scale: multiply √t by ${tnum(s)}.'),
          (s, 'That\'s the SD at time 1. At time ${tnum(t)}, multiply by $r.'),
        ],
        steps: [
          BrownStep('W at time ${tnum(t)} has SD √${tnum(t)}.', 'SD(W) = $r'),
          BrownStep('Scaling by ${tnum(s)} scales the SD by ${tnum(s)}.'),
          BrownStep('So:', 'SD = ${bnum(s)} \\times $r = ${bnum(ans)}'),
        ],
        insight: 'Right: the SD of σWₜ is σ√t.',
        params: {'s': s.value, 't': t.value},
      );
    }
    if (v == 2) {
      final k = _pick(rng, [Frac(2), Frac(3), Frac(4), Frac(5), Frac(6)]);
      final t = k * k;
      final kk = k.value;
      final r = Random(rng.nextInt(1 << 30));
      return _Draft(
        variant: v,
        card: 'SD(W_t) = ${bnum(k)}',
        caption: 'The band of one SD either side',
        path: BrownPath(
          ys: _sample(r, t.value * 1.25),
          tEnd: t.value * 1.25,
          levels: [
            BrownLevel(kk, tnum(k)),
            BrownLevel(-kk, tnum(Frac.zero - k)),
          ],
          marks: [BrownMark(t.value, 't = ?', spark: true)],
        ),
        question: 'At what time does the SD of W reach ${tnum(k)}?',
        hint: 'The SD at time t is √t. Undo the square root.',
        value: t,
        above: Frac.zero,
        unit: Frac(2),
        traps: [
          (
            k,
            'That treats time like the SD. The SD is √t, so t = '
                '${tnum(k)}² = ${tnum(t)}.',
          ),
          (
            k * Frac(2),
            'Doubling isn\'t squaring: √t = ${tnum(k)} gives '
                't = ${tnum(t)}.',
          ),
          (
            t * Frac(2),
            'The variance is t itself, no factor 2: t = ${tnum(t)}.',
          ),
        ],
        steps: [
          BrownStep('The SD at time t is √t.', '\\sqrt{t} = ${bnum(k)}'),
          const BrownStep('Square both sides.'),
          BrownStep('So:', 't = ${bnum(k)}^{2} = ${bnum(t)}'),
        ],
        insight: 'Right: twice the spread takes four times as long.',
        params: {'k': k.value},
      );
    }
    final (s, t) = _pick(rng, const [
      (9, 25),
      (16, 25),
      (4, 25),
      (1, 25),
      (16, 100),
      (36, 100),
      (64, 100),
    ]);
    final ratio = Frac(s, t);
    final r = Random(rng.nextInt(1 << 30));
    return _Draft(
      variant: v,
      card: 'P(W_{$t} > W_{$s})',
      caption: 'The step from time $s to time $t',
      path: BrownPath(
        ys: _sample(r, t * 1.1),
        tEnd: t * 1.1,
        marks: [BrownMark(s.toDouble(), '$s'), BrownMark(t.toDouble(), '$t')],
        from: s.toDouble(),
        to: t.toDouble(),
      ),
      question:
          'What\'s the chance W is higher at time $t than at time '
          '$s?',
      hint: 'The step from $s to $t doesn\'t care where W was.',
      value: _half,
      above: Frac.zero,
      below: Frac.one,
      unit: Frac(1, 10),
      traps: [
        (
          ratio,
          'That\'s the ratio of the times. The step after $s is as likely '
              'up as down.',
        ),
        (
          root(ratio)!,
          'That\'s the ratio of the SDs. The step is centred on 0, so it\'s '
              'half.',
        ),
        (
          Frac.one - ratio,
          'That\'s the share of the time after $s. The step is as likely up '
              'as down.',
        ),
      ],
      steps: [
        BrownStep(
          '${_w(t)} − ${_w(s)} is a fresh step, independent of the past.',
          'W_{$t} - W_{$s} \\sim N(0, ${t - s})',
        ),
        const BrownStep('A normal centred on 0 is as likely up as down.'),
        const BrownStep('So:', 'P = \\frac{1}{2}'),
      ],
      insight: 'Right: every step of Brownian motion is a fair coin.',
      params: {'s': s, 't': t},
    );
  }

  // ---- level 2: increments -------------------------------------------------

  _Draft _increments(Random rng) {
    final v = rng.nextInt(4);
    final r = Random(rng.nextInt(1 << 30));
    BrownPath pic(int s, int t, {bool step = false}) => BrownPath(
      ys: _sample(r, t * 1.15),
      tEnd: t * 1.15,
      marks: [
        BrownMark(s.toDouble(), 's = $s', spark: !step),
        BrownMark(t.toDouble(), 't = $t', spark: !step),
      ],
      from: step ? s.toDouble() : null,
      to: step ? t.toDouble() : null,
    );
    const squares = [
      (1, 4),
      (1, 9),
      (4, 9),
      (4, 16),
      (9, 16),
      (1, 16),
      (9, 25),
      (16, 25),
      (4, 25),
    ];
    if (v == 0) {
      final (s, t) = _pick(rng, squares);
      final rs = sqrt(s).round(), rt = sqrt(t).round();
      final ans = Frac(t - s);
      return _Draft(
        variant: v,
        card: 'Var(W_{$t} - W_{$s})',
        caption: 'The step from time $s to time $t',
        path: pic(s, t, step: true),
        question: 'What is the variance of the step ${_w(t)} − ${_w(s)}?',
        hint: 'Only the time between them counts.',
        value: ans,
        above: Frac.zero,
        unit: Frac.one,
        traps: [
          (
            Frac(t + s),
            'Variances add for independent pieces, but ${_w(t)} and ${_w(s)} share '
                'the path up to $s.',
          ),
          (
            Frac((rt - rs) * (rt - rs)),
            'That subtracts the SDs. The step after $s has variance '
                '$t − $s.',
          ),
          (
            Frac(t),
            'That\'s Var(${_w(t)}) alone. Only the step after $s counts.',
          ),
        ],
        steps: [
          BrownStep(
            '${_w(t)} − ${_w(s)} is the fresh step taken after time $s.',
            'W_{$t} = W_{$s} + (W_{$t} - W_{$s})',
          ),
          const BrownStep('A step over a time gap h has variance h.'),
          BrownStep('So:', 'Var(W_{$t} - W_{$s}) = $t - $s = ${t - s}'),
        ],
        insight: 'Right: the step\'s variance is the time it takes.',
        params: {'s': s, 't': t},
      );
    }
    if (v == 1) {
      final (s, t) = _pick(rng, squares);
      final rs = sqrt(s).round(), rt = sqrt(t).round();
      final ans = Frac(t + 3 * s);
      return _Draft(
        variant: v,
        card: 'Var(W_{$s} + W_{$t})',
        caption: 'W at time $s plus W at time $t',
        path: pic(s, t),
        question: 'What is the variance of ${_w(s)} + ${_w(t)}?',
        hint: 'Split ${_w(t)} into ${_w(s)} plus a fresh step.',
        value: ans,
        above: Frac.zero,
        unit: Frac(2),
        traps: [
          (
            Frac(t + s),
            'That treats ${_w(s)} and ${_w(t)} as independent. They share the path '
                'up to $s.',
          ),
          (
            Frac((rt + rs) * (rt + rs)),
            'That adds the SDs, as if they moved in lockstep. They share '
                'only the path up to $s.',
          ),
          (
            Frac(t + 2 * s),
            'The overlap counts twice: Var(X + Y) = Var X + Var Y + 2 Cov.',
          ),
        ],
        steps: [
          BrownStep(
            'Split ${_w(t)} into ${_w(s)} plus the fresh step after $s.',
            'W_{$s} + W_{$t} = 2W_{$s} + (W_{$t} - W_{$s})',
          ),
          BrownStep(
            'The two pieces are independent, so variances add.',
            'Var = 4 \\cdot $s + ($t - $s)',
          ),
          BrownStep('So:', 'Var(W_{$s} + W_{$t}) = ${t + 3 * s}'),
        ],
        insight: 'Right: split into independent pieces, then add variances.',
        params: {'s': s, 't': t},
      );
    }
    if (v == 2) {
      final s = 1 + rng.nextInt(6);
      final t = s + 1 + rng.nextInt(9 - s);
      final swap = rng.nextBool();
      final (x, y) = swap ? (t, s) : (s, t);
      final prod = root(Frac(s * t));
      return _Draft(
        variant: v,
        card: 'Cov(W_{$x}, W_{$y})',
        caption: 'W at two times',
        path: pic(s, t),
        question: 'What is the covariance of ${_w(x)} and ${_w(y)}?',
        hint: 'They share the path up to the earlier time.',
        value: Frac(s),
        above: Frac.zero,
        unit: Frac.one,
        traps: [
          (
            Frac(t),
            'That\'s the later time. They share only the path up to '
                'time $s.',
          ),
          (
            Frac(s * t),
            'Covariance isn\'t a product of times: it\'s the shared '
                'variance.',
          ),
          (
            Frac(t - s),
            'That\'s the variance of the step between them, which they '
                'don\'t share.',
          ),
          if (prod != null)
            (prod, 'That\'s SD × SD, as if they moved in lockstep.'),
        ],
        steps: [
          BrownStep(
            'Write the later one as the earlier one plus a fresh step.',
            'W_{$t} = W_{$s} + (W_{$t} - W_{$s})',
          ),
          BrownStep(
            'The fresh step is independent of ${_w(s)}, so it adds 0.',
            'Cov(W_{$s}, W_{$t}) = Var(W_{$s})',
          ),
          BrownStep('So:', 'Cov = \\min($s, $t) = $s'),
        ],
        insight: 'Right: Cov(Wₛ, Wₜ) is the earlier time, min(s, t).',
        params: {'s': s, 't': t},
      );
    }
    final (s, t) = _pick(rng, const [
      (1, 4),
      (4, 9),
      (9, 16),
      (1, 9),
      (4, 16),
      (16, 25),
      (9, 25),
      (1, 16),
      (4, 25),
    ]);
    final ans = root(Frac(s, t))!;
    return _Draft(
      variant: v,
      card: 'Corr(W_{$s}, W_{$t})',
      caption: 'W at two times',
      path: pic(s, t),
      question: 'What is the correlation of ${_w(s)} and ${_w(t)}?',
      hint: 'Correlation = covariance ÷ (SD × SD).',
      value: ans,
      above: Frac.zero,
      below: Frac.one,
      unit: Frac(1, 20),
      traps: [
        (
          Frac(s, t),
          'That\'s Cov ÷ Var(${_w(t)}). Divide by both SDs: √$s × √$t.',
        ),
        (
          Frac(t - s, t),
          'That\'s the share of Var(${_w(t)}) that is new, not shared.',
        ),
        (
          Frac(s, sqrt(t).round()),
          'That divides by one SD only. Divide by √$s too.',
        ),
      ],
      steps: [
        BrownStep('They share the path up to $s.', 'Cov = \\min($s, $t) = $s'),
        BrownStep(
          'Divide by both SDs.',
          '\\frac{$s}{\\sqrt{$s} \\cdot \\sqrt{$t}} = \\sqrt{\\frac{$s}{$t}}',
        ),
        BrownStep('So:', 'Corr = ${bnum(ans)}'),
      ],
      insight: 'Right: Corr(Wₛ, Wₜ) = √(s/t) for s before t.',
      params: {'s': s, 't': t},
    );
  }

  // ---- level 3: the normal table -------------------------------------------

  /// A time and a level a with a/√t = z on the table.
  static (Frac t, Frac a, int z2) _timeAndLevel(Random rng) {
    final options = <(Frac, Frac, int)>[];
    for (final t in [Frac(4), Frac(9), Frac(16), Frac(25), Frac(1, 4)]) {
      final rt = root(t)!;
      for (var z2 = 1; z2 <= 4; z2++) {
        final a = rt * Frac(z2, 2);
        final alt = twice(a / t);
        // Twice as often when dividing by t lands on the table too.
        final n = alt != null && alt >= 1 && alt <= 5 && alt != z2 ? 2 : 1;
        for (var i = 0; i < n; i++) {
          options.add((t, a, z2));
        }
      }
    }
    return _pick(rng, options);
  }

  _Draft _table(Random rng) {
    final v = rng.nextInt(4);
    final (t, a, z2) = _timeAndLevel(rng);
    final rt = root(t)!;
    final zt = twice(a / t);
    final cols = _window(z2, [zt]);
    final q = tail(z2)!;
    final z = Frac(z2, 2);
    final at = tnum(a), tt = tnum(t);
    const sl = pc;
    final rootWhy =
        'That divides by t. The SD at time $tt is √$tt = '
        '${tnum(rt)}.';
    final (card, value, shade, ask) = switch (v) {
      0 => ('P(W_{${bnum(t)}} > ${bnum(a)})', q, BellShade.above, 'above $at'),
      1 => (
        'P(W_{${bnum(t)}} < -${bnum(a)})',
        q,
        BellShade.below,
        'below −$at',
      ),
      2 => (
        'P(|W_{${bnum(t)}}| > ${bnum(a)})',
        q * Frac(2),
        BellShade.outside,
        'more than $at from 0',
      ),
      _ => (
        'P(W_{${bnum(t)}} < ${bnum(a)})',
        Frac.one - q,
        BellShade.below,
        'below $at',
      ),
    };
    final traps = <(Frac, String)?>[
      switch (v) {
        0 || 1 => _ifShown(cols, zt, (x) => x, rootWhy),
        2 => _ifShown(cols, zt, (x) => x * Frac(2), rootWhy),
        _ => _ifShown(cols, zt, (x) => Frac.one - x, rootWhy),
      },
      ...switch (v) {
        0 => [
          (Frac.one - q, 'That\'s the chance W is below $at.'),
          (q * Frac(2), 'That counts both tails; only above $at is asked.'),
          (
            Frac.one - q * Frac(2),
            'That\'s the chance W ends between −$at and $at.',
          ),
        ],
        1 => [
          (Frac.one - q, 'That\'s the chance W is above −$at.'),
          (q * Frac(2), 'That counts both tails; only below −$at is asked.'),
          (
            Frac.one - q * Frac(2),
            'That\'s the chance W ends between −$at and $at.',
          ),
        ],
        2 => [
          (q, 'That\'s one tail. |W| > $at counts both sides.'),
          (Frac.one - q * Frac(2), 'That\'s inside, between −$at and $at.'),
          (
            Frac.one - q,
            'That\'s the chance W is below $at; |W| > $at means past $at or '
                '−$at.',
          ),
        ],
        _ => [
          (q, 'That\'s the chance W is above $at.'),
          (q * Frac(2), 'That\'s the chance W ends past $at or −$at.'),
          (
            Frac.one - q * Frac(2),
            'That\'s between −$at and $at; below $at includes everything '
                'under −$at too.',
          ),
        ],
      },
    ];
    final last = switch (v) {
      0 => BrownStep('Above $at is that tail.'),
      1 => BrownStep('Below −$at is the same, by symmetry.'),
      2 => BrownStep(
        'Both tails count:',
        '2 \\times ${sl(q)} = ${sl(q * Frac(2))}',
      ),
      _ => BrownStep(
        'Below $at is the rest:',
        '100% - ${sl(q)} = ${sl(value)}',
      ),
    };
    return _Draft(
      variant: v,
      card: card,
      caption: 'W at time $tt: mean 0, variance $tt',
      bell: BrownBell(
        cut: z.value,
        shade: shade,
        labels: {
          0: '0',
          if (v != 0 && v != 3) -z.value: '−$at',
          if (v != 1) z.value: at,
        },
      ),
      table: cols,
      question: 'What\'s the chance W is $ask at time $tt?',
      hint: 'Divide by the SD, √t, to get z.',
      value: value,
      format: pc,
      above: Frac.zero,
      below: Frac.one,
      fillers: _tableFillers(cols),
      traps: [...traps.nonNulls],
      steps: [
        BrownStep(
          'At time $tt, W has SD √$tt = ${tnum(rt)}.',
          'z = \\frac{${bnum(a)}}{${bnum(rt)}} = ${bnum(z)}',
        ),
        BrownStep('The table:', 'P(Z > ${bnum(z)}) = ${sl(q)}'),
        last,
      ],
      insight: 'Right: z = a ÷ √t, then read the table.',
      params: {'t': t.value, 'a': a.value},
    );
  }

  // ---- level 4: reflection -------------------------------------------------

  _Draft _reflection(Random rng) {
    final v = rng.nextInt(3);
    final (t, a, z2) = _timeAndLevel(rng);
    final down = v == 0 && rng.nextBool();
    final rt = root(t)!;
    final zt = twice(a / t);
    final cols = _window(z2, [zt]);
    final q = tail(z2)!;
    final two = q * Frac(2);
    final z = Frac(z2, 2);
    final at = down ? '−${tnum(a)}' : tnum(a);
    final am = down ? '-${bnum(a)}' : bnum(a);
    final tt = tnum(t), tm = bnum(t);
    final rootWhy =
        'That divides by t. The SD at time $tt is √$tt = '
        '${tnum(rt)}.';
    final card = switch (v) {
      0 =>
        down
            ? 'P(\\min_{s \\le $tm} W_{s} \\le $am)'
            : 'P(\\max_{s \\le $tm} W_{s} \\ge $am)',
      1 => 'P(\\max_{s \\le $tm} W_{s} < $am)',
      _ => 'P(\\max_{s \\le $tm} W_{s} \\ge $am, W_{$tm} < $am)',
    };
    final value = switch (v) {
      0 => two,
      1 => Frac.one - two,
      _ => q,
    };
    final traps = <(Frac, String)?>[
      switch (v) {
        0 => _ifShown(cols, zt, (x) => x * Frac(2), rootWhy),
        1 => _ifShown(cols, zt, (x) => Frac.one - x * Frac(2), rootWhy),
        _ => _ifShown(cols, zt, (x) => x, rootWhy),
      },
      ...switch (v) {
        0 => [
          (
            q,
            'That forgets the factor 2: paths that touch $at end beyond it '
                'only half the time.',
          ),
          (Frac.one - two, 'That\'s the chance it never touches $at.'),
          (
            Frac.one - q,
            'That\'s the chance W isn\'t past $at at time $tt. Touching is '
                'about the whole path.',
          ),
        ],
        1 => [
          (
            Frac.one - q,
            'That forgets the factor 2: touching is 2 × ${pc(q)}, not '
                '${pc(q)}.',
          ),
          (two, 'That\'s the chance it does touch $at.'),
          (
            q,
            'That\'s ending above $at at time $tt. Never touching is 1 − 2 × '
                'that.',
          ),
        ],
        _ => [
          (two, 'That\'s touching at all; half of those paths end above $at.'),
          (Frac.one - q, 'That\'s ending below $at, touched or not.'),
          (Frac.one - two, 'That\'s the chance it never touches $at.'),
        ],
      },
    ];
    final last = switch (v) {
      0 => BrownStep(
        'Reflect each path after it first touches $at: touching is twice '
            'ending beyond.',
        '2 \\times ${pc(q)} = ${pc(two)}',
      ),
      1 => BrownStep(
        'Touching is 2 × ${pc(q)}; never touching is the rest.',
        '100% - ${pc(two)} = ${pc(value)}',
      ),
      _ => BrownStep(
        'Reflect after the first touch: ending below matches ending above.',
        'P = ${pc(q)}',
      ),
    };
    final level = down ? -a.value : a.value;
    return _Draft(
      variant: v,
      card: card,
      caption: switch (v) {
        0 => 'Touching a level',
        1 => 'Never touching a level',
        _ => 'Touching, then ending below',
      },
      path: BrownPath(
        ys: _toward(rng, t.value, level: level, touch: v != 1),
        tEnd: t.value,
        levels: [BrownLevel(level, at, spark: true)],
        marks: [BrownMark(t.value, 't = $tt')],
      ),
      table: cols,
      question: switch (v) {
        0 => 'What\'s the chance W touches $at by time $tt?',
        1 => 'What\'s the chance W stays below $at all the way to time $tt?',
        _ =>
          'What\'s the chance W touches $at by time $tt but ends below '
              'it?',
      },
      hint: 'After touching $at, a path ends beyond it half the time.',
      value: value,
      format: pc,
      above: Frac.zero,
      below: Frac.one,
      fillers: _tableFillers(cols),
      traps: [...traps.nonNulls],
      steps: [
        BrownStep(
          'At time $tt, W has SD √$tt = ${tnum(rt)}.',
          'z = \\frac{${bnum(a)}}{${bnum(rt)}} = ${bnum(z)}',
        ),
        BrownStep(
          'The table gives the chance of ending beyond $at:',
          'P(Z > ${bnum(z)}) = ${pc(q)}',
        ),
        last,
      ],
      insight: 'Right: touching a by t is twice the chance of ending past a.',
      params: {'t': t.value, 'a': a.value},
    );
  }

  // ---- level 5: martingales ------------------------------------------------

  /// The exponent σW_t + k·t, as [MathText] source.
  static String _expo(Frac s, Frac k) {
    final w = '${_co(s)}W_{t}';
    if (k == Frac.zero) return w;
    final mag = k < Frac.zero ? Frac.zero - k : k;
    final term = mag.d == 1
        ? '${_co(mag)}t'
        : '\\frac{${mag.n == 1 ? '' : mag.n}t}{${mag.d}}';
    return '$w ${k < Frac.zero ? '-' : '+'} $term';
  }

  _Draft _martingale(Random rng) {
    final v = rng.nextInt(3);
    if (v == 0) {
      final s = _pick(rng, [Frac(1), Frac(2), Frac(3)]);
      final h = s * s / Frac(2);
      final families = <(String, List<(String, String)>)>[
        (
          'W_{t}^{2} - t',
          [
            ('W_{t}^{2}', 'W² drifts up: d(W²) = 2W dW + dt has a dt term.'),
            ('W_{t}^{2} + t', 'Adding t doubles the drift: subtract t.'),
            (
              'W_{t}^{2} - 2t',
              'That overshoots: W² drifts up by exactly 1 per unit time.',
            ),
            ('tW_{t}', 'd(tW) = W dt + t dW: the W dt is a drift.'),
          ],
        ),
        (
          'e^{${_expo(s, Frac.zero - h)}}',
          [
            (
              'e^{${_expo(s, Frac.zero)}}',
              'e^(σW) drifts up: its average, e^(σ²t/2), grows.',
            ),
            (
              'e^{${_expo(s, Frac.zero - s * s)}}',
              'The correction is σ²t/2: σ²t takes away too much.',
            ),
            (
              'e^{${_expo(s, h)}}',
              'Wrong sign: the drift σ²/2 must be taken away.',
            ),
          ],
        ),
        (
          'W_{t}^{3} - 3tW_{t}',
          [
            (
              'W_{t}^{3}',
              'Itô gives d(W³) = 3W² dW + 3W dt: the 3W dt is a drift.',
            ),
            (
              'W_{t}^{3} - 3t',
              'The drift to cancel is 3W dt, so subtract 3tW, not 3t.',
            ),
            (
              'W_{t}^{3} - tW_{t}',
              'That cancels only a third of the 3W dt drift.',
            ),
          ],
        ),
      ];
      final f = rng.nextInt(3);
      final (right, own) = families[f];
      final others = [
        for (var i = 0; i < 3; i++)
          if (i != f) [...families[i].$2]..shuffle(rng),
      ];
      final mine = [...own]..shuffle(rng);
      return _Draft(
        variant: v,
        card: 'E[X_{t} | X_{s}] = X_{s}',
        caption: 'A martingale: no drift up or down',
        path: _plain(rng, Frac(4), label: 't'),
        question: 'Which of these is a martingale?',
        hint: 'Use Itô: the dt terms must cancel.',
        formula: right,
        formulaTraps: [mine.first, others[0].first, others[1].first],
        review: false,
        steps: switch (f) {
          0 => const [
            BrownStep(
              'Itô for W²: one extra dt term.',
              'd(W_{t}^{2}) = 2W_{t} dW_{t} + dt',
            ),
            BrownStep('Subtracting t takes away exactly that dt.', 'd(t) = dt'),
            BrownStep(
              'No dt term left, so it\'s a martingale:',
              'd(W_{t}^{2} - t) = 2W_{t} dW_{t}',
            ),
          ],
          1 => [
            BrownStep(
              'Itô for e^(σW): the dt term is σ²/2 times it.',
              'd(e^{${_expo(s, Frac.zero)}}) = e^{${_expo(s, Frac.zero)}}'
                  '(${_co(s)}dW_{t} + ${bnum(h)}dt)',
            ),
            BrownStep(
              'Multiplying by e^(−σ²t/2) takes that dt away.',
              '\\frac{σ^{2}}{2} = ${bnum(h)}',
            ),
            BrownStep('No dt term left, so it\'s a martingale:', right),
          ],
          _ => const [
            BrownStep(
              'Itô for W³: an extra 3W dt.',
              'd(W_{t}^{3}) = 3W_{t}^{2} dW_{t} + 3W_{t} dt',
            ),
            BrownStep(
              'd(3tW) = 3W dt + 3t dW cancels that dt.',
              'd(3tW_{t}) = 3W_{t} dt + 3t dW_{t}',
            ),
            BrownStep(
              'No dt term left, so it\'s a martingale:',
              'W_{t}^{3} - 3tW_{t}',
            ),
          ],
        },
        insight: 'Right: no dt term in its Itô differential, so no drift.',
        params: {'family': f, 's': s.value},
      );
    }
    if (v == 1) {
      final s = _pick(rng, const [2, 3, 4, 5, 6]);
      final ans = Frac(s * s, 2);
      return _Draft(
        variant: v,
        card: 'e^{${s}W_{t} - ct}',
        caption: 'A martingale: no drift up or down',
        path: _plain(rng, Frac(4), label: 't'),
        question: 'For which c is this a martingale?',
        hint: 'Itô adds ½σ² dt to e^(σW). Cancel it.',
        review: false,
        value: ans,
        above: Frac.zero,
        unit: Frac(1, 2),
        traps: [
          (
            Frac(s * s),
            'That forgets the ½: Itô\'s dt term is ½σ² times '
                'e^(σW).',
          ),
          (Frac(s), 'Square σ: the correction is σ²/2 = ${s * s}/2.'),
          (Frac(s, 2), 'Square σ first: σ²/2, not σ/2.'),
        ],
        steps: [
          BrownStep(
            'Itô for f = e^(σW − ct): df = f (σ dW + (σ²/2 − c) dt).',
            'σ = $s',
          ),
          const BrownStep(
            'No drift means the dt term is 0.',
            'c = \\frac{σ^{2}}{2}',
          ),
          BrownStep('So:', 'c = \\frac{${s * s}}{2} = ${bnum(ans)}'),
        ],
        insight: 'Right: e^(σW − σ²t/2) is the classic exponential martingale.',
        params: {'s': s},
      );
    }
    final s = _pick(rng, const [1, 2, 3]);
    final t = _pick(rng, const [1, 2, 4]);
    final x = Frac(s * s * t, 2);
    String e(Frac k) => 'e^{${bnum(k)}}';
    return _Draft(
      variant: v,
      card: 'E[e^{${s == 1 ? '' : s}W_{$t}}]',
      caption: 'The average of e to a normal',
      path: _plain(rng, Frac(t)),
      question:
          'W is a Brownian motion. What is the average of '
          'e^(${s == 1 ? '' : s}W) at time $t?',
      hint: 'For a normal X: E[e^X] = e^(mean + variance/2).',
      review: false,
      value: x,
      format: e,
      above: Frac.zero,
      unit: Frac(1, 2),
      traps: [
        (
          Frac(s * s * t),
          'That forgets the ½: E[e^X] = e^(mean + variance/2).',
        ),
        if (s != 1) (Frac(s * t, 2), 'The variance of σWₜ is σ²t, not σt.'),
        if (t != 1)
          (Frac(s * s * t * t, 2), 'The variance of Wₜ is t, not t².'),
        if (t != 1 && s != 1)
          (Frac(s * s), 'That uses t = 1; the variance grows with t.'),
      ],
      steps: [
        BrownStep(
          '${s == 1 ? '' : s}W at time $t is normal with mean 0.',
          'Var = ${s * s} \\cdot $t = ${s * s * t}',
        ),
        const BrownStep(
          'For a normal X: E[e^X] = e^(mean + variance/2).',
          'E[e^{X}] = e^{\\frac{Var}{2}}',
        ),
        BrownStep('So:', e(x)),
      ],
      insight: 'Right: that\'s why e^(σW) needs the −σ²t/2 to be fair.',
      params: {'s': s, 't': t},
    );
  }

  // ---- level 6: optional stopping ------------------------------------------

  _Draft _stopping(Random rng) {
    final v = rng.nextInt(3);
    if (v == 0) {
      final a = 1 + rng.nextInt(6);
      var b = 1 + rng.nextInt(5);
      if (b >= a) b++;
      final ans = Frac(b, a + b);
      return _Draft(
        variant: v,
        card: 'P(τ_{$a} < τ_{-$b})',
        given: r'\tau_{x} = \text{the first time W reaches }x',
        caption: 'Which level comes first?',
        path: _stopped(
          rng,
          a * b * 1.0,
          levels: [
            BrownLevel(a.toDouble(), '$a', spark: true),
            BrownLevel(-b.toDouble(), '−$b'),
          ],
        ),
        question: 'W starts at 0. What\'s the chance it reaches $a before −$b?',
        hint: 'W is a fair game: its average when it stops is still 0.',
        value: ans,
        above: Frac.zero,
        below: Frac.one,
        unit: Frac(1, 2 * (a + b)),
        traps: [
          (
            Frac(a, a + b),
            'That mixes up a and b: the nearer level is the likelier one.',
          ),
          (_half, 'Half and half only if $a and −$b are equally far.'),
          if (b < a)
            (Frac(b, a), 'That\'s the odds, $b to $a, not the chance.'),
        ],
        steps: [
          BrownStep(
            'W is a martingale, so its average at the stop is 0.',
            'p \\cdot $a + (1 - p)(-$b) = 0',
          ),
          BrownStep('Solve for p.', 'p = \\frac{$b}{$a + $b}'),
          BrownStep('So:', 'p = ${bnum(ans)}'),
        ],
        insight: 'Right: the chance of a first is b ÷ (a + b).',
        params: {'a': a, 'b': b},
      );
    }
    if (v == 1) {
      final a = _pick(rng, [Frac(2), Frac(3), Frac(4), Frac(5), Frac(3, 2)]);
      final ans = a * a;
      final at = tnum(a);
      return _Draft(
        variant: v,
        card: 'E[τ]',
        given: r'\tau = \text{the first time W reaches either level}',
        caption: 'Stops at the first level reached',
        path: _stopped(
          rng,
          ans.value,
          levels: [BrownLevel(a.value, at), BrownLevel(-a.value, '−$at')],
          sparkTime: true,
        ),
        question: 'How long until W first reaches $at or −$at, on average?',
        hint: 'W² − t is a martingale too.',
        value: ans,
        above: Frac.zero,
        unit: ans < Frac(4) ? _half : Frac.one,
        traps: [
          (
            a,
            'That treats distance like time. The SD after t is √t, so '
                'distance $at takes about ${tnum(ans)}.',
          ),
          (
            ans * Frac(2),
            'At the stop W² = ${tnum(ans)}, whichever level it hits: no '
                'doubling.',
          ),
          (
            a * Frac(2),
            'That\'s the width of the band. Time goes like distance '
                'squared.',
          ),
        ],
        steps: [
          const BrownStep(
            'W² − t is a martingale, so at the stop E[W²] = E[τ].',
            'E[W_{τ}^{2}] = E[τ]',
          ),
          BrownStep(
            'At the stop W is $at or −$at, so W² is ${tnum(ans)}.',
            'W_{τ}^{2} = ${bnum(ans)}',
          ),
          BrownStep('So:', 'E[τ] = ${bnum(a)}^{2} = ${bnum(ans)}'),
        ],
        insight: 'Right: reaching ±a takes a² on average.',
        params: {'a': a.value, 'b': a.value},
      );
    }
    final a = 1 + rng.nextInt(5);
    var b = 1 + rng.nextInt(4);
    if (b >= a) b++;
    final ans = Frac(a * b);
    return _Draft(
      variant: v,
      card: 'E[τ]',
      given: r'\tau = \text{the first time W reaches either level}',
      caption: 'Stops at the first level reached',
      path: _stopped(
        rng,
        a * b * 1.0,
        levels: [
          BrownLevel(a.toDouble(), '$a'),
          BrownLevel(-b.toDouble(), '−$b'),
        ],
        sparkTime: true,
      ),
      question: 'How long until W first reaches $a or −$b, on average?',
      hint: 'W² − t is a martingale too.',
      value: ans,
      above: Frac.zero,
      unit: Frac.one,
      traps: [
        (Frac(a + b), 'That adds the distances; the time multiplies them.'),
        (
          Frac((a + b) * (a + b)),
          'That squares the width; the time is $a × $b.',
        ),
        (Frac(a * a), 'That\'s for ±$a; the lower level is at −$b.'),
        (Frac(b * b), 'That\'s for ±$b; the upper level is at $a.'),
      ],
      steps: [
        const BrownStep(
          'W² − t is a martingale, so E[τ] = E[W² at the stop].',
          'E[τ] = E[W_{τ}^{2}]',
        ),
        BrownStep(
          'It stops at $a with chance $b/${a + b}, else at −$b.',
          '\\frac{$b}{${a + b}} \\cdot ${a * a} + \\frac{$a}{${a + b}} \\cdot '
              '${b * b}',
        ),
        BrownStep(
          'That simplifies to a × b:',
          'E[τ] = $a \\cdot $b = ${a * b}',
        ),
      ],
      insight: 'Right: the time to reach a or −b is a × b.',
      params: {'a': a, 'b': b},
    );
  }

  // ---- level 7: drift ------------------------------------------------------

  /// μt + σW_t as [MathText] source.
  static String _lin(Frac mu, Frac sigma) => '${_co(mu)}t + ${_co(sigma)}W_{t}';

  _Draft _drift(Random rng) {
    final v = rng.nextInt(4);
    if (v <= 1) {
      final below = v == 0;
      final (mu, sigma, t) = _pick(rng, [
        (Frac(1), Frac(2), Frac(4)),
        (_half, Frac(2), Frac(16)),
        (Frac(1, 4), _half, Frac(4)),
        (_half, _half, Frac(1)),
        (_half, Frac(2), Frac(4)),
        (Frac(1, 4), Frac(1), Frac(4)),
        (_half, Frac(1), Frac(4)),
      ]);
      final rt = root(t)!;
      final mean = mu * t, sd = sigma * rt;
      final z = mean / sd;
      final z2 = twice(z)!;
      final zt = twice(mean / (sigma * t));
      final zs = twice(mean / (sigma * sigma * rt));
      // The noise's σ left out: SD √t.
      final zn = sigma == Frac.one ? null : twice(mean / rt);
      final cols = _window(z2, [zt, zs, zn]);
      final q = tail(z2)!;
      final value = below ? q : Frac.one - q;
      Frac f(Frac x) => below ? x : Frac.one - x;
      final traps = <(Frac, String)?>[
        _ifShown(
          cols,
          zn,
          f,
          'That leaves out σ: the SD of σWₜ is σ√t = ${tnum(sd)}.',
        ),
        _ifShown(
          cols,
          zt,
          f,
          'That uses σt for the SD. The SD of σWₜ is σ√t = ${tnum(sd)}.',
        ),
        if (zs != zt)
          _ifShown(
            cols,
            zs,
            f,
            'That divides by σ²√t; the SD is σ√t = ${tnum(sd)}.',
          ),
        (
          Frac.one - value,
          below
              ? 'That\'s the chance X ends above 0.'
              : 'That\'s the chance X ends below 0.',
        ),
        (
          _half,
          'Without drift it would be half, but the drift moves the mean up '
              'to ${tnum(mean)}.',
        ),
      ];
      return _Draft(
        variant: v,
        card: 'P(X_{${bnum(t)}} ${below ? '<' : '>'} 0)',
        given: 'X_{t} = ${_lin(mu, sigma)}',
        caption: 'A drift up, plus noise',
        bell: BrownBell(
          cut: -z.value,
          shade: below ? BellShade.below : BellShade.above,
          labels: {-z.value: '0', 0: tnum(mean)},
        ),
        table: cols,
        question:
            'What\'s the chance X is ${below ? 'below' : 'above'} 0 at time '
            '${tnum(t)}?',
        hint: 'Mean μt, SD σ√t. How many SDs is 0 from the mean?',
        value: value,
        format: pc,
        above: Frac.zero,
        below: Frac.one,
        fillers: _tableFillers(cols),
        traps: [...traps.nonNulls],
        steps: [
          BrownStep(
            'At time ${tnum(t)}: mean μt = ${tnum(mean)}, SD σ√t = '
                '${tnum(sd)}.',
            'z = \\frac{${bnum(mean)}}{${bnum(sd)}} = ${bnum(z)}',
          ),
          BrownStep(
            '0 is ${tnum(z)} SDs below the mean. The table:',
            'P(Z > ${bnum(z)}) = ${pc(q)}',
          ),
          below
              ? BrownStep('Below 0 is that tail:', 'P = ${pc(q)}')
              : BrownStep(
                  'Above 0 is the rest:',
                  '100% - ${pc(q)} = ${pc(value)}',
                ),
        ],
        insight: 'Right: the drift moves the mean by μt; the SD is σ√t.',
        params: {
          'mu': mu.value,
          'sigma': sigma.value,
          't': t.value,
          'below': below ? 1 : 0,
        },
      );
    }
    if (v == 2) {
      final mu = _pick(rng, [_half, Frac(1), Frac(2)]);
      final b = _pick(rng, const [2, 3, 4]);
      final sigma = Frac(2);
      final x = Frac(2) * mu * Frac(b) / (sigma * sigma);
      String e(Frac k) => 'e^{${bnum(k)}}';
      return _Draft(
        variant: v,
        card: 'P(\\min_{t} X_{t} \\le -$b)',
        given: 'X_{t} = ${_lin(mu, sigma)}',
        caption: 'A drift up, plus noise, forever',
        path: BrownPath(
          ys: _sample(Random(rng.nextInt(1 << 30)), 8, mu: mu.value, sigma: 2),
          tEnd: 8,
          levels: [BrownLevel(-b.toDouble(), '−$b', spark: true)],
        ),
        question: 'X drifts up. What\'s the chance it ever falls to −$b?',
        hint: 'e^(−2μX/σ²) is a martingale.',
        value: Frac.zero - x,
        format: e,
        below: Frac.zero,
        unit: _half,
        traps: [
          (Frac.zero - x / Frac(2), 'That forgets the 2 in e^(−2μb/σ²).'),
          (
            Frac.zero - x * sigma,
            'That divides by σ, not σ²: the martingale is e^(−2μX/σ²).',
          ),
          (
            Frac.zero - x * sigma * sigma,
            'That leaves out σ²: the noise helps it fall.',
          ),
        ],
        steps: [
          BrownStep(
            'M = e^(−2μX/σ²) has no drift and starts at 1.',
            'M_{t} = e^{-${bnum(Frac(2) * mu / (sigma * sigma))}X_{t}}',
          ),
          BrownStep(
            'At −$b, M = e^(${tnum(x)}); far up, M ≈ 0. So P × e^(${tnum(x)}) '
            '= 1.',
          ),
          BrownStep('So:', 'P = ${e(Frac.zero - x)}'),
        ],
        insight: 'Right: with drift up, falling to −b has chance e^(−2μb/σ²).',
        params: {'mu': mu.value, 'sigma': 2, 'b': b},
      );
    }
    final (a, b) = _pick(rng, const [
      (1, 1),
      (2, 1),
      (1, 2),
      (2, 2),
      (3, 1),
      (1, 3),
    ]);
    // s(x) = 2^(−x): s(0) = p·s(a) + (1 − p)·s(−b).
    final sa = Frac(1, 1 << a), sb = Frac(1 << b);
    final ans = (sb - Frac.one) / (sb - sa);
    return _Draft(
      variant: v,
      card: 'P(τ_{$a} < τ_{-$b})',
      given: 'X_{t} = μt + W_{t}, e^{-2μ} = \\frac{1}{2}',
      caption: 'Which level comes first?',
      path: _stopped(
        rng,
        (a * b).toDouble(),
        mu: log(2) / 2,
        levels: [
          BrownLevel(a.toDouble(), '$a', spark: true),
          BrownLevel(-b.toDouble(), '−$b'),
        ],
      ),
      question:
          'X drifts up, with e^(−2μ) = ½. What\'s the chance it reaches $a '
          'before −$b?',
      hint: 's(X) = e^(−2μX) = 2^(−X) has no drift.',
      value: ans,
      above: Frac.zero,
      below: Frac.one,
      unit: Frac(1, 20),
      traps: [
        (Frac(b, a + b), 'That ignores the drift, which pushes X up to $a.'),
        (Frac(a, a + b), 'That mixes up a and b, and ignores the drift.'),
        (Frac.one - ans, 'That\'s the chance of −$b first.'),
        (
          (Frac.one - Frac(1, 1 << b)) / (Frac(1 << a) - Frac(1, 1 << b)),
          'That uses 2^X; the martingale is 2^(−X), since e^(−2μ) = ½.',
        ),
      ],
      steps: [
        const BrownStep(
          'With e^(−2μ) = ½, s(X) = 2^(−X) is a martingale.',
          's(0) = 1',
        ),
        BrownStep(
          'It ends at s($a) = ${tnum(sa)} with chance p, else at s(−$b) = '
              '${tnum(sb)}:',
          'p \\cdot ${bnum(sa)} + (1 - p) \\cdot ${bnum(sb)} = 1',
        ),
        BrownStep('Solve for p:', 'p = ${bnum(ans)}'),
      ],
      insight: 'Right: the scale function s(x) = e^(−2μx) makes it fair.',
      params: {'a': a, 'b': b},
    );
  }

  // ---- level 8: Itô --------------------------------------------------------

  _Draft _ito(Random rng) {
    final v = rng.nextInt(5);
    final pic = _plain(rng, Frac(4), label: 't');
    if (v == 0) {
      final t = _pick(rng, const [2, 3, 4, 5]);
      return _Draft(
        variant: v,
        card: 'E[W_{$t}^{4}]',
        caption: 'The fourth moment',
        path: pic,
        review: false,
        question: 'What is the average of W⁴ at time $t?',
        hint: 'Itô: d(W⁴) = 4W³ dW + 6W² dt.',
        value: Frac(3 * t * t),
        above: Frac.zero,
        unit: Frac(t),
        traps: [
          (
            Frac(t * t),
            'A normal\'s 4th moment is 3 × variance²: 3t², not t².',
          ),
          (Frac(3 * t), 'W⁴ scales like t², not t.'),
          (
            Frac(t * t * t * t),
            'W scales like √t, so W⁴ scales like t², not t⁴.',
          ),
        ],
        steps: [
          const BrownStep(
            'Itô for W⁴:',
            'd(W_{t}^{4}) = 4W_{t}^{3} dW_{t} + 6W_{t}^{2} dt',
          ),
          const BrownStep(
            'The dW part averages 0, and E[Wₛ²] = s.',
            'E[W_{t}^{4}] = \\int_{0}^{t} 6s ds = 3t^{2}',
          ),
          BrownStep('So:', '3 \\cdot $t^{2} = ${3 * t * t}'),
        ],
        insight: 'Right: E[Wₜ⁴] = 3t², from Itô in one line.',
        params: {'t': t},
      );
    }
    if (v == 1) {
      final t = _pick(rng, const [2, 3, 4, 5]);
      return _Draft(
        variant: v,
        card: 'Var(W_{$t}^{2})',
        caption: 'The spread of W²',
        path: pic,
        review: false,
        question: 'What is the variance of W² at time $t?',
        hint: 'Var = E[W⁴] − (E[W²])², with E[W⁴] = 3t².',
        value: Frac(2 * t * t),
        above: Frac.zero,
        unit: Frac(t),
        traps: [
          (Frac(3 * t * t), 'That\'s E[W⁴]; subtract (E[W²])² = t².'),
          (Frac(t * t), 'E[W⁴] is 3t², so the variance is 3t² − t².'),
          (Frac(2 * t), 'W² scales like t, so its variance scales like t².'),
        ],
        steps: [
          BrownStep(
            'E[W²] = t and E[W⁴] = 3t².',
            'E[W_{$t}^{4}] = ${3 * t * t}',
          ),
          const BrownStep('Variance = E[X²] − (E[X])² with X = W².'),
          BrownStep('So:', '${3 * t * t} - $t^{2} = ${2 * t * t}'),
        ],
        insight: 'Right: Var(Wₜ²) = 2t².',
        params: {'t': t},
      );
    }
    if (v == 2) {
      final f = rng.nextInt(5);
      final (fn, d1, d2, right, traps) = switch (f) {
        0 => (
          'W_{t}^{2}',
          '2w',
          '2',
          '2W_{t} dW_{t} + dt',
          [
            ('2W_{t} dW_{t}', _dropDt('½ · 2 = 1, so + dt')),
            ('2W_{t} dW_{t} + 2dt', _forgotHalf),
            ('2W_{t} dt + dW_{t}', _swapped),
          ],
        ),
        1 => (
          'W_{t}^{3}',
          '3w^{2}',
          '6w',
          '3W_{t}^{2} dW_{t} + 3W_{t} dt',
          [
            ('3W_{t}^{2} dW_{t}', _dropDt('3W dt')),
            ('3W_{t}^{2} dW_{t} + 6W_{t} dt', _forgotHalf),
            ('3W_{t}^{2} dW_{t} + 3W_{t}^{2} dt', _notFirst),
          ],
        ),
        2 => (
          'W_{t}^{4}',
          '4w^{3}',
          '12w^{2}',
          '4W_{t}^{3} dW_{t} + 6W_{t}^{2} dt',
          [
            ('4W_{t}^{3} dW_{t}', _dropDt('6W² dt')),
            ('4W_{t}^{3} dW_{t} + 12W_{t}^{2} dt', _forgotHalf),
            ('4W_{t}^{3} dW_{t} + 4W_{t}^{3} dt', _notFirst),
          ],
        ),
        3 => (
          'e^{W_{t}}',
          'e^{w}',
          'e^{w}',
          'e^{W_{t}} dW_{t} + \\frac{1}{2}e^{W_{t}} dt',
          [
            ('e^{W_{t}} dW_{t}', _dropDt('½e^W dt')),
            ('e^{W_{t}} dW_{t} + e^{W_{t}} dt', _forgotHalf),
            ('\\frac{1}{2}e^{W_{t}} dW_{t} + e^{W_{t}} dt', _swapped),
          ],
        ),
        _ => (
          'e^{2W_{t}}',
          '2e^{2w}',
          '4e^{2w}',
          '2e^{2W_{t}} dW_{t} + 2e^{2W_{t}} dt',
          [
            ('2e^{2W_{t}} dW_{t}', _dropDt('2e^(2W) dt')),
            ('2e^{2W_{t}} dW_{t} + 4e^{2W_{t}} dt', _forgotHalf),
            (
              '2e^{2W_{t}} dW_{t} + e^{2W_{t}} dt',
              'The chain rule\'s 2 comes in twice: f″ = 4e^(2w), and half '
                  'is 2e^(2w).',
            ),
          ],
        ),
      };
      return _Draft(
        variant: v,
        card: 'd($fn) = ?',
        caption: 'Itô\'s rule',
        path: pic,
        review: false,
        question: 'Which is the right Itô differential?',
        hint: 'df = f′ dW + ½f″ dt: one more term than usual.',
        formula: right,
        formulaTraps: traps,
        steps: [
          const BrownStep(
            'Itô\'s rule for f(W): one more term than usual.',
            'df = f′(W_{t}) dW_{t} + \\frac{1}{2}f″(W_{t}) dt',
          ),
          BrownStep(
            'Its two derivatives:',
            'f′(w) = $d1\\text{,   }f″(w) = $d2',
          ),
          BrownStep('Half of f″ gives the dt term:', 'd($fn) = $right'),
        ],
        insight: 'Right: f′ dW plus half of f″ dt.',
        params: {'f': f},
      );
    }
    if (v == 3) {
      final w = rng.nextBool();
      final t = _pick(rng, w ? const [2, 3, 4, 6] : const [2, 3, 6]);
      final ans = w ? Frac(t * t, 2) : Frac(t * t * t, 3);
      final integrand = w ? 'W_{s}' : 's';
      return _Draft(
        variant: v,
        card: 'Var(\\int_{0}^{$t} $integrand dW_{s})',
        caption: 'An Itô integral',
        path: _plain(rng, Frac(t)),
        review: false,
        question: 'What is the variance of this Itô integral?',
        hint: 'Itô isometry: Var = ∫ E[integrand²] ds.',
        value: ans,
        above: Frac.zero,
        unit: Frac.one,
        traps: w
            ? [
                (Frac(t * t), 'That forgets the ½: ∫₀ᵗ s ds = t²/2.'),
                (Frac(t), 'That integrates 1; here E[Wₛ²] = s.'),
                (Frac(t * t * t, 3), 'That integrates s²; E[Wₛ²] is s.'),
              ]
            : [
                (Frac(t * t, 2), 'Square the integrand: ∫ s² ds, not ∫ s ds.'),
                (Frac(t * t * t), 'That forgets the ⅓: ∫₀ᵗ s² ds = t³/3.'),
                (Frac(t * t), 'Square the integrand, then integrate: t³/3.'),
              ],
        steps: [
          const BrownStep(
            'Itô isometry: the variance is the integral of E[integrand²].',
            'Var = \\int_{0}^{t} E[g_{s}^{2}] ds',
          ),
          BrownStep(
            w ? 'Here E[Wₛ²] = s.' : 'Here gₛ = s, so gₛ² = s².',
            w ? '\\int_{0}^{$t} s ds' : '\\int_{0}^{$t} s^{2} ds',
          ),
          BrownStep(
            'So:',
            w
                ? '\\frac{$t^{2}}{2} = ${bnum(ans)}'
                : '\\frac{$t^{3}}{3} = ${bnum(ans)}',
          ),
        ],
        insight:
            'Right: the Itô isometry turns a variance into a plain '
            'integral.',
        params: {'t': t, 'w': w ? 1 : 0},
      );
    }
    return _Draft(
      variant: v,
      card: '\\int_{0}^{t} W_{s} dW_{s} = ?',
      caption: 'An Itô integral',
      path: pic,
      review: false,
      question: 'Which is the Itô integral of W against itself?',
      hint: 'Start from d(W²) = 2W dW + dt.',
      formula: '\\frac{1}{2}(W_{t}^{2} - t)',
      formulaTraps: [
        (
          '\\frac{1}{2}W_{t}^{2}',
          'That\'s ordinary calculus. Itô\'s dt term takes away t/2.',
        ),
        (
          '\\frac{1}{2}(W_{t}^{2} + t)',
          'Wrong sign: d(W²) = 2W dW + dt, so the t comes off.',
        ),
        ('W_{t}^{2} - t', 'That\'s twice it: d(W²) has 2W dW.'),
      ],
      steps: const [
        BrownStep('Itô for W²:', 'd(W_{t}^{2}) = 2W_{t} dW_{t} + dt'),
        BrownStep(
          'Integrate from 0 to t:',
          'W_{t}^{2} = 2\\int_{0}^{t} W_{s} dW_{s} + t',
        ),
        BrownStep(
          'Solve for the integral:',
          '\\int_{0}^{t} W_{s} dW_{s} = \\frac{1}{2}(W_{t}^{2} - t)',
        ),
      ],
      insight: 'Right: the dt term is why it isn\'t just W²/2.',
      params: const {},
    );
  }

  static String _dropDt(String term) =>
      'That drops the dt term. Itô adds ½f″ dt, which is $term here.';
  static const _forgotHalf =
      'That forgets the ½: the dt term is half of f″, not f″.';
  static const _swapped =
      'dW and dt are swapped: f′ goes with dW, ½f″ with dt.';
  static const _notFirst =
      'The dt term uses ½f″, the second derivative, not f′ again.';

  // ---- level 9: geometric Brownian motion ----------------------------------

  _Draft _gbm(Random rng) {
    final v = rng.nextInt(3);
    if (v <= 1) {
      final mu = _pick(rng, [
        Frac(4, 100),
        Frac(5, 100),
        Frac(6, 100),
        Frac(8, 100),
        Frac(1, 10),
      ]);
      final sigma = _pick(rng, [Frac(2, 10), Frac(4, 10)]);
      final t = _pick(rng, const [1, 2, 5]);
      final tt = Frac(t);
      final h = sigma * sigma / Frac(2);
      final mean = mu * tt, median = (mu - h) * tt;
      String e(Frac k) => '100e^{${bnum(k)}}';
      String note(Frac k) => 'about ${(100 * exp(k.value)).toStringAsFixed(2)}';
      final isMean = v == 0;
      final r = Random(rng.nextInt(1 << 30));
      final logs = _sample(
        r,
        t.toDouble(),
        mu: median.value / t,
        sigma: sigma.value,
      );
      return _Draft(
        variant: v,
        card: isMean ? 'E[S_{$t}]' : 'median(S_{$t})',
        given: 'dS_{t} = ${bnum(mu)}S_{t} dt + ${bnum(sigma)}S_{t} dW_{t}',
        caption: 'A stock from S₀ = 100',
        path: BrownPath(
          ys: [for (final y in logs) 100 * exp(y)],
          tEnd: t.toDouble(),
          levels: const [BrownLevel(100, '100')],
          marks: [BrownMark(t.toDouble(), 't = $t', spark: true)],
        ),
        question: isMean
            ? 'The stock starts at 100. What is its average price at time $t?'
            : 'The stock starts at 100. What is its median price at time $t?',
        hint: isMean
            ? 'μ is the drift of S itself.'
            : 'log S drifts at μ − σ²/2.',
        value: isMean ? mean : median,
        format: e,
        note: note,
        unit: Frac(1, 100),
        traps: isMean
            ? [
                (median, 'That\'s the median. The mean is higher: e^(μt).'),
                (
                  (mu + h) * tt,
                  'That adds σ²/2 to μ; μ is already the drift of S itself.',
                ),
                (
                  (mu - h * Frac(2)) * tt,
                  'That takes off σ²: no, the mean grows at μ.',
                ),
              ]
            : [
                (
                  mean,
                  'That\'s the mean. The median is lower: log S drifts at '
                      'μ − σ²/2.',
                ),
                ((mu - h * Frac(2)) * tt, 'That forgets the ½: take off σ²/2.'),
                ((mu + h) * tt, 'Wrong sign: Itô takes σ²/2 away from log S.'),
              ],
        steps: [
          BrownStep(
            'Itô for log S: the drift drops by σ²/2.',
            'd(\\ln S_{t}) = (${bnum(mu)} - ${bnum(h)}) dt + ${bnum(sigma)} dW_{t}',
          ),
          isMean
              ? BrownStep(
                  'Add back half the variance to average e^(log S):',
                  '${bnum(median)} + \\frac{${bnum(sigma * sigma * tt)}}{2} = '
                      '${bnum(mean)}',
                )
              : BrownStep(
                  'The median of log S is its mean, since it\'s normal:',
                  '(${bnum(mu)} - ${bnum(h)}) \\cdot $t = ${bnum(median)}',
                ),
          BrownStep('So:', isMean ? 'E[S_{$t}] = ${e(mean)}' : e(median)),
        ],
        insight: isMean
            ? 'Right: E[Sₜ] = S₀e^(μt); the median is lower.'
            : 'Right: the median is S₀e^((μ − σ²/2)t), below the mean.',
        params: {
          'mu': mu.value,
          'sigma': sigma.value,
          't': t,
          'mean': isMean ? 1 : 0,
        },
      );
    }
    // σ√t = 1, so z is just the log's mean.
    final (sigma, t) = _pick(rng, [
      (_half, Frac(4)),
      (Frac(1, 5), Frac(25)),
      (Frac(1), Frac(1)),
    ]);
    final h = sigma * sigma / Frac(2);
    final rt = root(t)!;
    final z2 = _pick(
      rng,
      sigma == Frac.one ? const [-1, 1, 2, 3] : const [-1, 0, 1, 2, 3, 4],
    );
    final z = Frac(z2, 2);
    final m = z * sigma / rt; // μ − σ²/2
    final mu = m + h;
    final zMu = twice(mu * rt / sigma);
    // The SD taken as σt instead of σ√t.
    final zT = twice(m / sigma);
    final cols = _window(z2, [zMu, zT]);
    final ans = tail(-z2)!;
    final traps = <(Frac, String)?>[
      _ifShown(
        cols,
        zMu == null ? null : -zMu,
        (x) => x,
        'That forgets the −σ²/2: log S grows at μ − σ²/2, not μ.',
      ),
      _ifShown(
        cols,
        zT == null ? null : -zT,
        (x) => x,
        'That uses t for the SD; the SD of σWₜ is σ√t = 1.',
      ),
      (Frac.one - ans, 'That\'s the chance it ends below 100.'),
      if (z2 != 0)
        (_half, 'S₀ is the median only when μ = σ²/2; here log S drifts.'),
    ];
    // Tail beyond −z, from the table entry for |z|.
    final q = z2 == 0 ? _half : tail(z2.abs())!;
    final mt = m * t;
    return _Draft(
      variant: v,
      card: 'P(S_{${bnum(t)}} > S_{0})',
      given: 'dS_{t} = ${bnum(mu)}S_{t} dt + ${bnum(sigma)}S_{t} dW_{t}',
      caption: 'A stock from S₀ = 100',
      bell: BrownBell(
        cut: -z.value,
        shade: BellShade.above,
        labels: {-z.value: '100', if (z2 != 0) 0: 'median'},
      ),
      table: cols,
      question:
          'What\'s the chance the stock is above its start, 100, at time '
          '${tnum(t)}?',
      hint: 'log S is normal: mean (μ − σ²/2)t, SD σ√t.',
      value: ans,
      format: pc,
      above: Frac.zero,
      below: Frac.one,
      fillers: [..._tableFillers(cols), _half],
      traps: [...traps.nonNulls],
      steps: [
        BrownStep(
          'log(S/S₀) is normal: mean (μ − σ²/2)t, SD σ√t = 1.',
          '(${bnum(mu)} - ${bnum(h)}) \\cdot ${bnum(t)} = ${bnum(mt)}',
        ),
        BrownStep(
          'Above 100 means the log is above 0: z = mean ÷ SD.',
          'z = ${bnum(z)}',
        ),
        z2 > 0
            ? BrownStep('The table:', '100% - ${pc(q)} = ${pc(ans)}')
            : z2 == 0
            ? const BrownStep('0 is the middle:', 'P = 50%')
            : BrownStep(
                'The table:',
                'P(Z > ${bnum(Frac.zero - z)}) = ${pc(ans)}',
              ),
      ],
      insight: 'Right: whether S ends up depends on μ − σ²/2, not μ.',
      params: {'mu': mu.value, 'sigma': sigma.value, 't': t.value},
    );
  }
}

class _Draft {
  _Draft({
    required this.variant,
    required this.card,
    this.given,
    required this.caption,
    this.path,
    this.bell,
    this.table,
    required this.question,
    required this.hint,
    this.value,
    this.traps = const [],
    this.unit = Frac.one,
    this.fillers,
    this.format,
    this.note,
    this.above,
    this.below,
    this.formula,
    this.formulaTraps = const [],
    this.review = true,
    required this.steps,
    required this.insight,
    required this.params,
  });

  final int variant;
  final String card;
  final String? given;
  final String caption;
  final BrownPath? path;
  final BrownBell? bell;
  final List<int>? table;
  final String question;
  final String hint;

  /// A number answer, its named slips and the step for near misses.
  final Frac? value;
  final List<(Frac, String)> traps;
  final Frac unit;

  /// Near misses to use instead of steps of [unit].
  final List<Frac>? fillers;

  /// How a number option is written, if not as a plain number.
  final String Function(Frac)? format;

  /// A note under each option, if not the fraction's "about".
  final String Function(Frac)? note;

  /// Options stay strictly between these.
  final Frac? above, below;

  /// A formula answer and its named slips.
  final String? formula;
  final List<(String, String)> formulaTraps;

  /// Show the picture again after answering.
  final bool review;

  final List<BrownStep> steps;
  final String insight;
  final Map<String, num> params;
}
