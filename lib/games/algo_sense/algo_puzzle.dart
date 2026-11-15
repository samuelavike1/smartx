import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum AlgoKind {
  searchLooks,
  searchCover,
  loopCount,
  scaleTime,
  growth,
  bubbleSwaps,
  sortBound,
  fibCalls,
  fibRepeat,
  memoCalls,
  stairs,
  coinWays,
  coinFewest,
  setBits,
  andMinusOne,
  xorPair,
  xorLone,
  piDarts,
  mcSamples,
  gridPaths,
  bfsSteps,
  newtonStep,
  bisection,
  newtonDigits,
}

// ---- pictures ---------------------------------------------------------------

/// What the card (or the review) draws. Spark orange marks the unknown; on
/// the review the unknown is filled in.
@immutable
sealed class AlgoPicture {
  const AlgoPicture({required this.title, this.note = ''});

  /// Above the picture on the review.
  final String title;

  /// Beside the title on the review: "7 looks", "17 routes".
  final String note;
}

/// A sorted list being halved: the full row, then half, then a quarter,
/// the middle item of each in spark orange.
class SearchPicture extends AlgoPicture {
  const SearchPicture({required this.n, required super.title, super.note});

  final int n;
}

/// One row of boxes.
@immutable
class CellRow {
  const CellRow(
    this.label,
    this.cells, {
    this.marked = const {},
    this.unknown = false,
  });

  /// Left of the row ("13", "n − 1"); empty for none.
  final String label;
  final List<String> cells;

  /// Boxes drawn in spark orange.
  final Set<int> marked;

  /// The row is what the question asks: "?" boxes on the card, filled in on
  /// the review.
  final bool unknown;
}

/// Rows of boxes: an array, bits under their place values, a memo table.
class RowsPicture extends AlgoPicture {
  const RowsPicture({
    required this.rows,
    required super.title,
    super.note,
    this.header,
    this.arrowAt,
  });

  final List<CellRow> rows;

  /// Small labels above the first row's boxes (place values 8, 4, 2, 1).
  final List<String>? header;

  /// A swap arrow over boxes [arrowAt] and [arrowAt] + 1 of the first row.
  final int? arrowAt;
}

/// The (i, j) pairs a double loop visits, as an n × n grid of squares.
class PairsPicture extends AlgoPicture {
  const PairsPicture({
    required this.n,
    required this.includeDiagonal,
    required super.title,
    super.note,
  });

  final int n;

  /// j runs up to i (the diagonal counts) rather than from i + 1.
  final bool includeDiagonal;
}

/// Two runs of the same program as bars: the known time and the unknown.
class BarsPicture extends AlgoPicture {
  const BarsPicture({
    required this.sizes,
    required this.known,
    required this.unknown,
    required super.title,
    super.note,
  });

  /// "1,000 items", "4,000 items".
  final List<String> sizes;

  /// "2 s" and the answer, "32 s".
  final String known, unknown;
}

/// Growth rates as bars on a log scale, at n = 1,000.
class RatesPicture extends AlgoPicture {
  const RatesPicture({
    required this.labels,
    required this.digits,
    required this.highlight,
    required super.title,
    super.note,
  });

  /// "n²", "2ⁿ".
  final List<String> labels;

  /// log₁₀ of the step count at n = 1,000.
  final List<double> digits;
  final int highlight;
}

/// The call tree of naive fib(n), cut off a few levels down; nodes for
/// fib([mark]) in spark orange. With [memo], the memo's chain: one call per
/// level, the second call each time a look-up.
class TreePicture extends AlgoPicture {
  const TreePicture({
    required this.n,
    required super.title,
    super.note,
    this.mark,
    this.memo = false,
  });

  final int n;
  final int? mark;
  final bool memo;
}

/// A staircase of [n] steps, one possible climb drawn as hops.
class StairsPicture extends AlgoPicture {
  const StairsPicture({
    required this.n,
    required this.hops,
    required super.title,
    super.note,
  });

  final int n;

  /// One climb, e.g. [1, 2, 2, 1, 1].
  final List<int> hops;
}

/// The coins on offer and the amount to make.
class CoinsPicture extends AlgoPicture {
  const CoinsPicture({
    required this.coins,
    required this.amount,
    required this.answer,
    required super.title,
    super.note,
  });

  final List<int> coins;
  final int amount;

  /// Shown on the review in place of "?".
  final String answer;
}

/// Darts in a unit square with a quarter circle.
class DartsPicture extends AlgoPicture {
  const DartsPicture({
    required this.darts,
    required this.inside,
    required this.seed,
    required super.title,
    super.note,
  });

  final int darts, inside;

  /// Where the dots go (fixed per question).
  final int seed;
}

/// Error against samples: the 1/√n curve, the known point and the target.
class ErrorPicture extends AlgoPicture {
  const ErrorPicture({
    required this.error,
    required this.target,
    required this.samples,
    required this.answer,
    required super.title,
    super.note,
  });

  /// "0.04", "0.01".
  final String error, target;

  /// "1,000" and the answer "16,000".
  final String samples, answer;
}

/// A street grid, [w] blocks across and [h] down, with one closed corner.
class GridPicture extends AlgoPicture {
  const GridPicture({
    required this.w,
    required this.h,
    required this.wall,
    required super.title,
    super.note,
  });

  final int w, h;

  /// The closed corner, (across, down) from the top-left.
  final (int, int) wall;
}

/// A small graph on a grid of spots; [start] in ink, [target] in spark.
class GraphPicture extends AlgoPicture {
  const GraphPicture({
    required this.cols,
    required this.rows,
    required this.edges,
    required this.start,
    required this.target,
    required super.title,
    super.note,
    this.path = const [],
  });

  final int cols, rows;

  /// Node i sits at column i % cols, row i ~/ cols; labels A, B, C, …
  final List<(int, int)> edges;
  final int start, target;

  /// A shortest path, drawn on the review.
  final List<int> path;
}

/// y = x² − a with the tangent at x₀; x₁ where it meets the axis.
class TangentPicture extends AlgoPicture {
  const TangentPicture({
    required this.a,
    required this.x0,
    required this.x1,
    required this.answer,
    required super.title,
    super.note,
  });

  final int a;
  final double x0, x1;
  final String answer;
}

/// An interval halved again and again around a root.
class HalvingPicture extends AlgoPicture {
  const HalvingPicture({
    required this.width,
    required this.tolerance,
    required super.title,
    super.note,
  });

  final String width, tolerance;
}

// ---- the question -------------------------------------------------------------

/// The card above the question.
@immutable
class AlgoScene {
  const AlgoScene({
    required this.caption,
    this.lines = const [],
    this.code = const [],
    this.picture,
    this.pictureOnCard = true,
  });

  /// Maths shown large, in `MathText` shorthand ("n = 100").
  final List<String> lines;

  /// Lines of pseudo-code, indented with two spaces a level.
  final List<String> code;
  final String caption;
  final AlgoPicture? picture;

  /// The picture is part of the question (otherwise it waits for the
  /// review, where it would give the answer away).
  final bool pictureOnCard;
}

/// A wrong answer and the slip behind it.
@immutable
class AlgoTrap {
  const AlgoTrap(this.label, this.why, [this.value]);

  /// The option: a number ("16,000", "3.14") or `MathText` ("O(n^2)").
  final String label;
  final String why;

  /// Its number, for numeric questions.
  final Frac? value;
}

@immutable
class AlgoQuestion {
  const AlgoQuestion({
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
  final AlgoKind kind;
  final AlgoScene scene;
  final String question;
  final String hint;

  /// A number as text ("16,000", "3.14"), or a growth rate in `MathText`
  /// shorthand ("O(n \log n)").
  final String answer;

  /// Null when the options are growth rates.
  final Frac? answerValue;
  final List<AlgoTrap> traps;
  final List<String> options;

  /// The number behind each option (numeric questions only).
  final List<Frac>? optionValues;
  final List<String> steps;
  final String insight;

  /// The numbers behind the question, for recomputing in tests.
  final Map<String, Object> params;

  bool get numeric => optionValues != null;

  int get answerIndex => options.indexOf(answer);

  String feedbackFor(String picked) => picked == answer
      ? insight
      : traps.firstWhere((t) => t.label == picked).why;
}

class AlgoDifficulty {
  static List<AlgoKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [AlgoKind.searchLooks, AlgoKind.searchCover],
    2 => const [AlgoKind.loopCount, AlgoKind.scaleTime, AlgoKind.growth],
    3 => const [AlgoKind.bubbleSwaps, AlgoKind.sortBound],
    4 => const [AlgoKind.fibCalls, AlgoKind.fibRepeat, AlgoKind.memoCalls],
    5 => const [AlgoKind.stairs, AlgoKind.coinWays, AlgoKind.coinFewest],
    6 => const [
      AlgoKind.setBits,
      AlgoKind.andMinusOne,
      AlgoKind.xorPair,
      AlgoKind.xorLone,
    ],
    7 => const [AlgoKind.piDarts, AlgoKind.mcSamples],
    8 => const [AlgoKind.gridPaths, AlgoKind.bfsSteps],
    9 => const [AlgoKind.newtonStep, AlgoKind.bisection, AlgoKind.newtonDigits],
    _ => const [
      AlgoKind.fibCalls,
      AlgoKind.memoCalls,
      AlgoKind.stairs,
      AlgoKind.coinWays,
      AlgoKind.coinFewest,
      AlgoKind.andMinusOne,
      AlgoKind.xorPair,
      AlgoKind.piDarts,
      AlgoKind.mcSamples,
      AlgoKind.gridPaths,
      AlgoKind.bfsSteps,
      AlgoKind.newtonStep,
      AlgoKind.bisection,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'binary search: halving a sorted list',
    2 => 'counting a loop\'s work, and growth rates',
    3 => 'sorting: swaps and comparisons',
    4 => 'recursion, with and without a memo',
    5 => 'dynamic programming: stairs and coins',
    6 => 'bits: counting 1s, AND and XOR',
    7 => 'Monte Carlo: π from darts, and sample sizes',
    8 => 'paths on a grid and breadth-first search',
    9 => 'Newton\'s method and bisection',
    _ => 'any of levels 4 to 9',
  };
}

// ---- writing numbers ----------------------------------------------------------

/// A whole number with thousands commas: "16,000", "−3".
String whole(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '−$b' : '$b';
}

/// A number as an option: "16,000", "3.14", "0.005".
String numText(Frac f) {
  if (f.d == 1) return whole(f.n);
  var s = f.value.abs().toStringAsFixed(3);
  while (s.endsWith('0')) {
    s = s.substring(0, s.length - 1);
  }
  return f < Frac.zero ? '−$s' : s;
}

const _supDigits = ['⁰', '¹', '²', '³', '⁴', '⁵', '⁶', '⁷', '⁸', '⁹'];

/// "2¹⁰".
String pow2(int k) =>
    '2${k.toString().split('').map((c) => _supDigits[int.parse(c)]).join()}';

/// Binary digits, [width] long.
String binary(int n, [int width = 0]) => n.toRadixString(2).padLeft(width, '0');

int _fib(int n) {
  var a = 0, b = 1;
  for (var i = 0; i < n; i++) {
    final t = a + b;
    a = b;
    b = t;
  }
  return a;
}

/// Calls naive fib(n) makes, the first included.
int _naiveCalls(int n) => 2 * _fib(n + 1) - 1;

/// Smallest k with 2ᵏ ≥ x.
int _ceilLog2(int x) {
  var k = 0;
  while ((1 << k) < x) {
    k++;
  }
  return k;
}

int _popcount(int n) => binary(n).split('').where((c) => c == '1').length;

/// "1, 2 and 5".
String _and(List<Object> xs) => xs.length == 1
    ? '${xs.first}'
    : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';

class AlgoGenerator {
  const AlgoGenerator();

  static const again = 'Check the numbers again: see the working.';

  AlgoQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = AlgoDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final draft = switch (kind) {
      AlgoKind.searchLooks => _searchLooks(rng),
      AlgoKind.searchCover => _searchCover(rng),
      AlgoKind.loopCount => _loopCount(rng),
      AlgoKind.scaleTime => _scaleTime(rng),
      AlgoKind.growth => _growth(rng),
      AlgoKind.bubbleSwaps => _bubbleSwaps(rng),
      AlgoKind.sortBound => _sortBound(rng),
      AlgoKind.fibCalls => _fibCalls(rng),
      AlgoKind.fibRepeat => _fibRepeat(rng),
      AlgoKind.memoCalls => _memoCalls(rng),
      AlgoKind.stairs => _stairs(rng),
      AlgoKind.coinWays => _coinWays(rng),
      AlgoKind.coinFewest => _coinFewest(rng),
      AlgoKind.setBits => _setBits(rng),
      AlgoKind.andMinusOne => _andMinusOne(rng),
      AlgoKind.xorPair => _xorPair(rng),
      AlgoKind.xorLone => _xorLone(rng),
      AlgoKind.piDarts => _piDarts(rng, seed),
      AlgoKind.mcSamples => _mcSamples(rng),
      AlgoKind.gridPaths => _gridPaths(rng),
      AlgoKind.bfsSteps => _bfsSteps(rng),
      AlgoKind.newtonStep => _newtonStep(rng),
      AlgoKind.bisection => _bisection(rng),
      AlgoKind.newtonDigits => _newtonDigits(rng),
    };

    final List<AlgoTrap> chosen;
    final String answer;
    if (draft.value case final a?) {
      chosen = _numeric(draft, a, rng);
      answer = numText(a);
    } else {
      answer = draft.answerSource!;
      chosen = _shuffled(answer, draft.wrong, rng);
    }

    return AlgoQuestion(
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

  static bool _whole(Frac v) => v.d == 1;

  /// Four numbers, smallest first, the answer's rank uniform.
  List<AlgoTrap> _numeric(_Draft draft, Frac a, Random rng) {
    AlgoTrap t(Frac v, String why) => AlgoTrap(numText(v), why, v);
    bool fits(Frac v) {
      if (draft.allowZero ? v < Frac.zero : v <= Frac.zero) return false;
      final scale = Frac([1, 10, 100, 1000][draft.places]);
      return (v * scale).d == 1;
    }

    final unit = draft.unit;
    final fillers = [
      for (final k in [1, 2, 3])
        for (final sign in [1, -1])
          if (fits(a + unit * Frac(sign * k)))
            t(a + unit * Frac(sign * k), again),
    ]..shuffle(rng);
    final named = <AlgoTrap>[];
    for (final (v, why) in draft.traps) {
      if (v == a || !fits(v) || named.any((n) => n.value == v)) continue;
      named.add(t(v, why));
    }
    final chosen = balancedOptions(
      t(a, ''),
      named,
      fillers,
      rng,
      compare: (x, y) => x.value!.compareTo(y.value!),
    );
    if (draft.places == 0) return chosen;
    // A whole number among decimals (or the other way round) mustn't be
    // the answer just because it looks different.
    final spare = [
      for (final u in [unit, unit * Frac(1, 2), Frac(1, a.d), Frac.one])
        for (final k in [1, 2, 3, 4])
          for (final sign in [1, -1])
            if (fits(a + u * Frac(sign * k))) t(a + u * Frac(sign * k), again),
    ];
    return _mixFormats(chosen, a, [...named, ...fillers, ...spare]);
  }

  static List<AlgoTrap> _mixFormats(
    List<AlgoTrap> chosen,
    Frac a,
    List<AlgoTrap> pool,
  ) {
    final mine = _whole(a);
    if (chosen.where((o) => _whole(o.value!) == mine).length >= 2) {
      return chosen;
    }
    for (final c in pool) {
      if (_whole(c.value!) != mine || c.value == a) continue;
      if (chosen.any((o) => o.value == c.value)) continue;
      final below = c.value! < a;
      final out = [
        for (final o in chosen)
          if (o.value != a && (o.value! < a) == below) o,
      ];
      if (out.isEmpty) continue;
      // Give up a plain near miss before a named mistake.
      out.sort(
        (x, y) => (x.why == again ? 0 : 1).compareTo(y.why == again ? 0 : 1),
      );
      return [
        for (final o in chosen)
          if (o != out.first) o,
        c,
      ]..sort((x, y) => x.value!.compareTo(y.value!));
    }
    return chosen;
  }

  /// Growth rates: shuffled, the answer anywhere.
  static List<AlgoTrap> _shuffled(
    String answer,
    List<(String, String)> wrong,
    Random rng,
  ) {
    final pool = [...wrong]..shuffle(rng);
    final chosen = <AlgoTrap>[];
    for (final (s, why) in pool) {
      if (s == answer || chosen.any((c) => c.label == s)) continue;
      chosen.add(AlgoTrap(s, why));
      if (chosen.length == 3) break;
    }
    return chosen..insert(rng.nextInt(chosen.length + 1), AlgoTrap(answer, ''));
  }

  // ---- helpers ------------------------------------------------------------

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  /// A whole number from [lo] to [hi].
  static int _r(Random rng, int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

  static Frac _f(int n, [int d = 1]) => Frac(n, d);

  // ---- level 1: binary search ---------------------------------------------

  static const _listSizes = [
    12, 15, 16, 20, 25, 30, 31, 32, 40, 50, 60, 63, 64, 100, 127, 128, 200, //
    250, 255, 256, 300, 500, 511, 512, 1000,
  ];

  _Draft _searchLooks(Random rng) {
    final n = _pick(rng, _listSizes);
    final k = _ceilLog2(n + 1);
    final low = (1 << (k - 1)) - 1, high = (1 << k) - 1;
    return _Draft(
      scene: AlgoScene(
        lines: ['n = ${whole(n)}'],
        caption: 'Binary search on a sorted list',
        picture: SearchPicture(
          n: n,
          title: 'Halving ${whole(n)} items',
          note: '$k looks',
        ),
      ),
      question:
          'At most how many looks to find any item, or show it\'s '
          'missing?',
      hint: 'Each look checks the middle and keeps one half.',
      value: _f(k),
      traps: [
        (
          _f(k - 1),
          'That\'s log₂ n rounded down. Each look also rules out the middle '
              'item: k looks cover 2ᵏ − 1 items.',
        ),
        (
          _f(n),
          'That\'s checking items one by one. Each look halves the list.',
        ),
        (
          _f((n + 1) ~/ 2),
          'That\'s half the list, a one-by-one search on average. Binary '
              'search halves again and again.',
        ),
        (
          _f(k + 1),
          'One look too many: the last look already says found or missing.',
        ),
      ],
      steps: [
        'Each look checks the middle item, then keeps at most half of the '
            'rest.',
        '${k - 1} looks cover at most ${pow2(k - 1)} − 1 = ${whole(low)} items; '
            '$k looks cover ${pow2(k)} − 1 = ${whole(high)}.',
        '${whole(n)} items need $k looks: log₂(n + 1) rounded up.',
      ],
      insight: 'Right: k looks cover 2ᵏ − 1 items, so log₂(n + 1) rounded up.',
      params: {'n': n},
    );
  }

  _Draft _searchCover(Random rng) {
    final k = _r(rng, 3, 10);
    final cover = (1 << k) - 1;
    final seq = [for (var i = 1; i <= 4; i++) (1 << i) - 1].join(', ');
    return _Draft(
      scene: AlgoScene(
        lines: ['k = $k'],
        caption: 'Binary search with k looks',
        picture: SearchPicture(
          n: cover,
          title: 'Halving ${whole(cover)} items',
          note: '$k looks',
        ),
        pictureOnCard: false,
      ),
      question:
          'With $k looks, binary search can handle a sorted list of at most '
          'how many items?',
      hint: 'Each look doubles the reach, plus the middle one.',
      value: _f(cover),
      traps: [
        (
          _f(1 << k),
          'One too many: with ${pow2(k)} items, some target needs one more '
              'look.',
        ),
        (
          _f((1 << (k - 1)) - 1),
          'That\'s what ${k - 1} looks cover. The last look doubles the '
              'reach, plus one.',
        ),
        (
          _f(2 * k),
          'That adds 2 a look. Each look doubles the reach, so it grows like '
              '2ᵏ.',
        ),
        (
          _f(k * k),
          'That\'s k², which grows far slower than doubling every look.',
        ),
      ],
      steps: [
        '1 look settles 1 item: the middle one.',
        'Each extra look doubles the reach and adds a middle item: $seq, …',
        '$k looks: ${pow2(k)} − 1 = ${whole(cover)} items.',
      ],
      insight: 'Right: the reach doubles each look, plus one: 2ᵏ − 1.',
      params: {'k': k},
    );
  }

  // ---- level 2: counting work -----------------------------------------------

  _Draft _loopCount(Random rng) {
    final variant = rng.nextInt(3);
    if (variant == 2) {
      final n = _pick(rng, const [
        10,
        20,
        30,
        50,
        64,
        100,
        128,
        200,
        500,
        1000,
      ]);
      final c = _ceilLog2(n);
      final values = [for (var i = 1; i <= c; i++) (1 << i)];
      return _Draft(
        scene: AlgoScene(
          code: [
            'i = 1, count = 0',
            'while i < ${whole(n)}:',
            '  i = 2 × i',
            '  count = count + 1',
          ],
          caption: 'i doubles each time round',
          picture: RowsPicture(
            rows: [
              CellRow(
                'i',
                [for (final v in values) whole(v)],
                marked: {values.length - 1},
              ),
            ],
            title: 'i after each pass',
            note: '$c passes',
          ),
          pictureOnCard: false,
        ),
        question: 'What is count when the loop ends?',
        hint: 'i doubles each time round.',
        value: _f(c),
        traps: [
          (
            _f(n - 1),
            'That\'s adding 1 each time. Doubling reaches ${whole(n)} in about '
                'log₂ n steps.',
          ),
          (_f(n ~/ 2), 'That\'s adding 2 each time. Doubling is far quicker.'),
          (
            _f(c + 1),
            'One too many: the last check, when i ≥ ${whole(n)}, doesn\'t run '
                'the body.',
          ),
          if ((1 << c) != n)
            (
              _f(c - 1),
              'That stops short: after ${c - 1} passes i is only '
                  '${whole(1 << (c - 1))}, still below ${whole(n)}.',
            ),
        ],
        steps: [
          'i goes 1, 2, 4, 8, …, and the loop stops once i ≥ ${whole(n)}.',
          '${pow2(c - 1)} = ${whole(1 << (c - 1))} is below ${whole(n)}; '
              '${pow2(c)} = ${whole(1 << c)} is not.',
          'So the body runs $c times: count = $c.',
        ],
        insight: 'Right: doubling to n takes about log₂ n steps.',
        params: {'variant': 'doubling', 'n': n},
      );
    }
    final n = _r(rng, 5, 12);
    final diagonal = variant == 1;
    final count = diagonal ? n * (n + 1) ~/ 2 : n * (n - 1) ~/ 2;
    return _Draft(
      scene: AlgoScene(
        code: [
          'count = 0',
          'for i = 1 to $n:',
          diagonal ? '  for j = 1 to i:' : '  for j = i + 1 to $n:',
          '    count = count + 1',
        ],
        caption: diagonal ? 'j runs from 1 up to i' : 'j starts just after i',
        picture: PairsPicture(
          n: n,
          includeDiagonal: diagonal,
          title: 'The (i, j) pairs visited',
          note: '$count squares',
        ),
        pictureOnCard: false,
      ),
      question: 'What is count when the loops end?',
      hint: diagonal
          ? 'i = 1 runs once, i = 2 twice, …'
          : 'Each pair i < j once.',
      value: _f(count),
      traps: [
        (
          _f(n * n),
          'That counts every (i, j). The inner loop only runs over part of '
              'the row.',
        ),
        if (diagonal)
          (
            _f(n * (n - 1) ~/ 2),
            'That leaves out j = i. The inner loop runs up to i itself.',
          )
        else
          (
            _f(n * (n + 1) ~/ 2),
            'That lets j equal i. Here j starts at i + 1.',
          ),
        if (diagonal)
          (
            _f(n * (n + 1)),
            'That forgets to halve: 1 + 2 + … + n is n(n + 1)/2.',
          )
        else
          (
            _f(n * (n - 1)),
            'That counts each pair twice. j > i means each pair once.',
          ),
        (_f(n), 'That\'s only the outer loop. The inner one runs too.'),
      ],
      steps: diagonal
          ? [
              'For i = 1 the inner line runs once, for i = 2 twice, … for '
                  'i = $n, $n times.',
              '1 + 2 + … + $n = $n × ${n + 1} ÷ 2.',
              'count = $count.',
            ]
          : [
              'For i = 1 the inner line runs ${n - 1} times, for i = 2, '
                  '${n - 2} times, … for i = $n, none.',
              '${n - 1} + ${n - 2} + … + 1 = $n × ${n - 1} ÷ 2.',
              'count = $count: one for each pair.',
            ],
      insight: diagonal
          ? 'Right: n(n + 1)/2, which grows like n².'
          : 'Right: n(n − 1)/2, the number of pairs. Still O(n²).',
      params: {'variant': diagonal ? 'triangle' : 'pairs', 'n': n},
    );
  }

  _Draft _scaleTime(Random rng) {
    final variant = rng.nextInt(4);
    switch (variant) {
      case 0 || 1:
        final cubic = variant == 1;
        final p = cubic ? 3 : 2;
        final m = cubic ? _r(rng, 2, 3) : _pick(rng, const [2, 3, 4, 5, 10]);
        final t = _pick(rng, const [1, 2, 3, 5]);
        final n1 = _pick(rng, const [1000, 2000, 5000]);
        final n2 = n1 * m;
        final factor = pow(m, p).toInt();
        final ans = t * factor;
        final other = cubic ? m * m : m * m * m;
        return _Draft(
          scene: AlgoScene(
            lines: [cubic ? 'O(n^3)' : 'O(n^2)'],
            caption: 'The same program on more items',
            picture: BarsPicture(
              sizes: ['${whole(n1)} items', '${whole(n2)} items'],
              known: '$t s',
              unknown: '${whole(ans)} s',
              title: 'Run times',
              note: '× ${whole(factor)}',
            ),
          ),
          question:
              'An O(n${cubic ? '³' : '²'}) program takes $t s on ${whole(n1)} '
              'items. How many seconds on ${whole(n2)}?',
          hint: 'Scale n, then raise the scale to the power.',
          value: _f(ans),
          unit: _f(t),
          traps: [
            (
              _f(t * m),
              'That\'s linear growth. O(n${cubic ? '³' : '²'}) means $m times '
                  'the items takes $m${cubic ? '³' : '²'} times as long.',
            ),
            (
              _f(t * other),
              cubic
                  ? 'That squares the scale. O(n³) cubes it.'
                  : 'That cubes the scale. O(n²) squares it.',
            ),
            (
              _f(t * 2 * m),
              'That doubles the scale. O(n${cubic ? '³' : '²'}) raises it to '
                  'a power.',
            ),
          ],
          steps: [
            'O(n${cubic ? '³' : '²'}): the time grows with n${cubic ? '³' : '²'}.',
            '${whole(n2)} is $m times ${whole(n1)}, so the time is '
                '$m${cubic ? '³' : '²'} = ${whole(factor)} times as long.',
            '$t × ${whole(factor)} = ${whole(ans)} seconds.',
          ],
          insight: 'Right: multiply n by m and an O(nᵖ) time grows mᵖ times.',
          params: {
            'variant': cubic ? 'cubic' : 'square',
            't': t,
            'n1': n1,
            'n2': n2,
          },
        );
      case 2:
        final n1 = _pick(rng, const [20, 30, 40]);
        final k = _r(rng, 2, 6);
        final t = _pick(rng, const [1, 2, 3]);
        final ans = t << k;
        return _Draft(
          scene: AlgoScene(
            lines: ['O(2^n)'],
            caption: 'Trying every subset of the items',
            picture: BarsPicture(
              sizes: ['$n1 items', '${n1 + k} items'],
              known: '$t s',
              unknown: '${whole(ans)} s',
              title: 'Run times',
              note: '× ${pow2(k)}',
            ),
          ),
          question:
              'An O(2ⁿ) program takes $t s on $n1 items. How many seconds on '
              '${n1 + k}?',
          hint: 'Each extra item doubles the time.',
          value: _f(ans),
          unit: _f(t),
          traps: [
            (
              _f(t * 2 * k),
              'That adds two lots per item. Each extra item doubles the time.',
            ),
            (_f(t + k), 'That adds a second per item. 2ⁿ doubles per item.'),
            (
              _f(t * k * k),
              'That\'s k², a power of the extra items. 2ⁿ doubles per item.',
            ),
            (
              _f(t * (1 << (k - 1))),
              'One doubling short: $k extra items means $k doublings.',
            ),
          ],
          steps: [
            'O(2ⁿ): one more item doubles the work.',
            '${n1 + k} is $k more than $n1: $k doublings, ${pow2(k)} = '
                '${whole(1 << k)} times as long.',
            '$t × ${whole(1 << k)} = ${whole(ans)} seconds.',
          ],
          insight:
              'Right: 2ⁿ doubles with every item, which is why it '
              'explodes.',
          params: {'variant': 'exp', 't': t, 'n1': n1, 'n2': n1 + k},
        );
      default:
        final t = _r(rng, 2, 6);
        final e = _r(rng, 2, 3);
        final n2 = pow(1000, e).toInt();
        final ans = t * e;
        return _Draft(
          scene: AlgoScene(
            lines: ['O(\\log n)'],
            caption: 'A search that halves the data each step',
            picture: BarsPicture(
              sizes: ['1,000 items', '${whole(n2)} items'],
              known: '$t ms',
              unknown: '${whole(ans)} ms',
              title: 'Run times',
              note: '× $e',
            ),
          ),
          question:
              'An O(log n) search takes $t ms on 1,000 items. How many ms on '
              '${whole(n2)}?',
          hint: 'log of n${e == 2 ? '²' : '³'} is $e × log n.',
          value: _f(ans),
          unit: _f(1),
          traps: [
            (
              _f(t * n2 ~/ 1000),
              'That\'s linear growth. log n only grows by a fixed step when '
                  'n is multiplied.',
            ),
            (_f(t + e), 'That adds $e. The steps grow $e times, not by $e.'),
            (
              _f(t * (e + 1)),
              'One step too many: ${whole(n2)} = 1,000${e == 2 ? '²' : '³'}, '
                  'so $e times log n.',
            ),
            (_f(t), 'The time does grow, just slowly: log n goes up too.'),
          ],
          steps: [
            '${whole(n2)} = 1,000${e == 2 ? '²' : '³'}.',
            'log(n${e == 2 ? '²' : '³'}) = $e × log n, so the steps grow $e '
                'times.',
            '$t × $e = $ans ms.',
          ],
          insight:
              'Right: squaring n only doubles log n. That\'s why log n '
              'is cheap.',
          params: {'variant': 'log', 't': t, 'n1': 1000, 'n2': n2},
        );
    }
  }

  /// Growth rates, slowest first.
  static const _rates = [
    (r'O(\log n)', 'log n', 1.0, 'binary search in a sorted list'),
    (r'O(\sqrt{n})', '√n', 1.5, 'trying divisors up to √n'),
    ('O(n)', 'n', 3.0, 'one pass over the items'),
    (r'O(n \log n)', 'n log n', 4.0, 'merge sort'),
    ('O(n^2)', 'n²', 6.0, 'checking every pair'),
    ('O(n^3)', 'n³', 9.0, 'checking every triple'),
    ('O(2^n)', '2ⁿ', 301.0, 'trying every subset'),
    ('O(n!)', 'n!', 2567.0, 'trying every order'),
  ];

  static String _steps(double digits) => switch (digits) {
    1.0 => 'about 10',
    1.5 => 'about 32',
    3.0 => '1,000',
    4.0 => 'about 10,000',
    6.0 => 'a million',
    9.0 => 'a billion',
    301.0 => 'a 302-digit number',
    _ => 'a 2,568-digit number',
  };

  _Draft _growth(Random rng) {
    final idx = [for (var i = 0; i < _rates.length; i++) i]..shuffle(rng);
    final four = idx.take(4).toList()..sort();
    final variant = rng.nextInt(3);
    final int ans;
    final String question, hint, insight;
    final List<(String, String)> wrong;
    final List<String> steps;
    final (src, plain, dig, task) =
        _rates[switch (variant) {
          0 => four.last,
          1 => four.first,
          _ => four[rng.nextInt(4)],
        }];
    ans = _rates.indexWhere((r) => r.$1 == src);
    switch (variant) {
      case 0 || 1:
        final fastest = variant == 0;
        question = fastest
            ? 'Which of these grows fastest as n gets large?'
            : 'Which of these grows slowest as n gets large?';
        hint = 'Try n = 1,000 in each.';
        wrong = [
          for (final i in four)
            if (i != ans)
              (
                _rates[i].$1,
                'At n = 1,000, ${_rates[i].$2} is ${_steps(_rates[i].$3)} but '
                    '$plain is ${_steps(dig)}.',
              ),
        ];
        steps = [
          'Put n = 1,000 into each: '
              '${[for (final i in four) '${_rates[i].$2} ≈ ${_digits(_rates[i].$3)}'].join(', ')}.',
          fastest
              ? 'Powers of n beat logs; 2ⁿ and n! beat any power of n.'
              : 'Logs grow slower than any power of n; powers grow slower '
                    'than 2ⁿ and n!.',
          '${fastest ? 'Fastest' : 'Slowest'}: $plain.',
        ];
        insight = fastest
            ? 'Right: $plain. At n = 1,000 it\'s ${_steps(dig)}.'
            : 'Right: $plain. At n = 1,000 it\'s only ${_steps(dig)}.';
      default:
        question = 'Which growth rate fits $task?';
        hint = 'How much work does one more item add?';
        wrong = [
          for (final i in four)
            if (i != ans)
              (
                _rates[i].$1,
                'That\'s the cost of ${_rates[i].$4}. ${_why(ans)}',
              ),
        ];
        steps = [
          _why(ans),
          'At n = 1,000 that is ${_steps(dig)} steps.',
          'So $task is $plain.',
        ];
        insight = 'Right: ${_why(ans)}';
    }
    return _Draft(
      scene: AlgoScene(
        lines: variant == 2 ? const [] : [r'n \to \infty'],
        caption: variant == 2
            ? 'Steps for n items'
            : 'Steps for n items, n large',
        picture: RatesPicture(
          labels: [for (final i in four) _rates[i].$2],
          digits: [for (final i in four) _rates[i].$3],
          highlight: four.indexOf(ans),
          title: 'Steps at n = 1,000',
          note: 'log scale',
        ),
        pictureOnCard: false,
      ),
      question: question,
      hint: hint,
      answerSource: src,
      wrong: wrong,
      steps: steps,
      insight: insight,
      params: {
        'variant': ['fastest', 'slowest', 'task'][variant],
        'rates': [for (final i in four) _rates[i].$2],
        'task': task,
      },
    );
  }

  static String _digits(double d) => switch (d) {
    1.0 => '10',
    1.5 => '32',
    3.0 => '10³',
    4.0 => '10⁴',
    6.0 => '10⁶',
    9.0 => '10⁹',
    301.0 => '10³⁰¹',
    _ => '10²⁵⁶⁷',
  };

  static String _why(int i) => switch (i) {
    0 => 'Binary search halves the list each look: O(log n).',
    1 => 'Divisors only need trying up to √n: O(√n).',
    2 => 'One pass touches each item once: O(n).',
    3 =>
      'Merge sort halves log n times and merges n items each time: '
          'O(n log n).',
    4 => 'There are n(n − 1)/2 pairs: O(n²).',
    5 => 'There are about n³/6 triples: O(n³).',
    6 => 'Each item is in or out, so 2ⁿ subsets: O(2ⁿ).',
    _ => 'There are n! orders of n items: O(n!).',
  };

  // ---- level 3: sorting -----------------------------------------------------

  _Draft _bubbleSwaps(Random rng) {
    late List<int> a;
    late int inv, misplaced, passes;
    final n = _r(rng, 5, 6);
    final most = n * (n - 1) ~/ 2;
    do {
      final pool = [for (var v = 1; v <= 9; v++) v]..shuffle(rng);
      a = pool.take(n).toList();
      inv = 0;
      for (var i = 0; i < n; i++) {
        for (var j = i + 1; j < n; j++) {
          if (a[i] > a[j]) inv++;
        }
      }
      final sorted = [...a]..sort();
      misplaced = [
        for (var i = 0; i < n; i++)
          if (a[i] != sorted[i]) i,
      ].length;
      // Passes that swap something: the furthest any item moves left.
      passes = 0;
      for (var i = 0; i < n; i++) {
        final bigger = [
          for (var j = 0; j < i; j++)
            if (a[j] > a[i]) j,
        ].length;
        passes = max(passes, bigger);
      }
    } while (inv < 4 || inv > most - 3 || misplaced == inv);
    final after = [
      for (var i = 0; i < n; i++)
        [
          for (var j = i + 1; j < n; j++)
            if (a[j] < a[i]) j,
        ].length,
    ];
    final firstSwap = [
      for (var i = 0; i < n - 1; i++)
        if (a[i] > a[i + 1]) i,
    ].first;
    return _Draft(
      scene: AlgoScene(
        caption: 'Bubble sort, smallest first',
        picture: RowsPicture(
          rows: [
            CellRow('', [for (final v in a) '$v']),
          ],
          arrowAt: firstSwap,
          title: 'The array',
          note: '$inv swaps',
        ),
      ),
      question: 'How many swaps does bubble sort make to put these in order?',
      hint: 'It only swaps neighbours that are out of order.',
      value: _f(inv),
      traps: [
        (
          _f(most),
          'That counts comparisons. Bubble sort only swaps neighbours that '
              'are out of order.',
        ),
        (
          _f(misplaced),
          'That counts numbers out of place. One number can need several '
              'swaps to get home.',
        ),
        (
          _f(passes),
          'That\'s the passes that swap something. Most passes make several '
              'swaps.',
        ),
        (_f(n - 1), 'That\'s one swap per pass. A pass can make several.'),
      ],
      steps: [
        'Each swap of neighbours fixes exactly one out-of-order pair.',
        'For each number, count the smaller ones after it: '
            '${after.join(' + ')}.',
        'So $inv out-of-order pairs, and $inv swaps.',
      ],
      insight:
          'Right: swaps = out-of-order pairs. That\'s why bubble sort is '
          'O(n²) on a shuffled list.',
      params: {'array': a},
    );
  }

  _Draft _sortBound(Random rng) {
    final n = _r(rng, 4, 8);
    var fact = 1;
    for (var i = 2; i <= n; i++) {
      fact *= i;
    }
    final c = _ceilLog2(fact);
    final nlogn = (n * log(n) / ln2).ceil();
    return _Draft(
      scene: AlgoScene(
        lines: ['n = $n', '$n! = ${whole(fact)}'],
        caption: 'Orders $n items could be in',
      ),
      question:
          'Sorting $n items by comparing pairs: in the worst case, at least '
          'how many comparisons does the best method need?',
      hint: 'Each comparison can at best halve the possible orders.',
      value: _f(c),
      traps: [
        (
          _f(c - 1),
          'That\'s log₂ $n! rounded down. c comparisons tell apart at most '
              '2ᶜ orders, so round up.',
        ),
        (
          _f(n * (n - 1) ~/ 2),
          'That compares every pair. A good sort needs fewer.',
        ),
        (
          _f(nlogn),
          'That\'s n log₂ n, only the rough size. The exact floor is '
              'log₂ n!.',
        ),
        (_f(n - 1), 'That only checks a list that\'s already in order.'),
      ],
      steps: [
        '$n items can be in $n! = ${whole(fact)} orders.',
        'Each yes-or-no comparison can at best halve them: c comparisons '
            'tell apart 2ᶜ orders.',
        '${pow2(c - 1)} = ${whole(1 << (c - 1))} is short of ${whole(fact)}; '
            '${pow2(c)} = ${whole(1 << c)} is enough. So $c.',
      ],
      insight: 'Right: log₂ n! rounded up, which grows like n log n.',
      params: {'n': n},
    );
  }

  // ---- level 4: recursion -----------------------------------------------------

  static const _fibCode = [
    'fib(n):',
    '  if n < 2: return n',
    '  return fib(n − 1) + fib(n − 2)',
  ];

  _Draft _fibCalls(Random rng) {
    final n = _r(rng, 4, 9);
    final calls = _naiveCalls(n);
    final upTo = [for (var i = 2; i <= n; i++) _naiveCalls(i)];
    return _Draft(
      scene: AlgoScene(
        code: _fibCode,
        caption: 'Naive recursion, no memo',
        picture: TreePicture(
          n: n,
          title: 'The call tree',
          note: '$calls calls',
        ),
      ),
      question:
          'How many calls does fib($n) make in all, the first one '
          'included?',
      hint: 'calls(n) = 1 + calls(n − 1) + calls(n − 2).',
      value: _f(calls),
      traps: [
        (_f(_fib(n)), 'That\'s fib($n) itself, the value, not the calls.'),
        (
          _f(1 << n),
          'That\'s a full tree. The fib(n − 2) side is shorter, so fewer.',
        ),
        (_f(calls - 1), 'That leaves out the first call, fib($n) itself.'),
        (
          _f(_fib(n + 1)),
          'That counts only the calls that return at once, at the bottom.',
        ),
        (_f(2 * n - 1), 'That\'s with a memo. Without one, calls repeat.'),
      ],
      steps: [
        'calls(n) = 1 + calls(n − 1) + calls(n − 2), and calls(0) = '
            'calls(1) = 1.',
        'From n = 2 up: ${upTo.join(', ')}.',
        'So fib($n) makes $calls calls.',
      ],
      insight: 'Right: the calls grow like the Fibonacci numbers, about 1.6ⁿ.',
      params: {'variant': 'naive', 'n': n},
    );
  }

  _Draft _fibRepeat(Random rng) {
    late int n, k;
    do {
      n = _r(rng, 7, 11);
      k = _r(rng, 2, n - 4);
    } while (_fib(n - k + 1) > 60);
    final times = _fib(n - k + 1);
    final counts = [for (var j = n; j >= k; j--) _fib(n - j + 1)];
    return _Draft(
      scene: AlgoScene(
        code: _fibCode,
        caption: 'Naive recursion: the same calls again and again',
        picture: TreePicture(
          n: n,
          mark: k,
          title: 'The top of the call tree',
          note: 'fib($k) × $times',
        ),
      ),
      question:
          'Working out fib($n) this way, how many times is fib($k) '
          'called?',
      hint: 'Count the calls to fib($n), fib(${n - 1}), … down to fib($k).',
      value: _f(times),
      traps: [
        (_f(1), 'That\'s with a memo. Without one, fib($k) is redone.'),
        (
          _f(n - k),
          'That\'s one per level. The number doubles, roughly, each level '
              'down.',
        ),
        (
          _f(1 << (n - k)),
          'That\'s a full tree. The fib(n − 2) side is shorter, so fewer.',
        ),
        (
          _f(_fib(n - k)),
          'One level short: fib($k) is called from fib(${k + 1}) and '
              'fib(${k + 2}).',
        ),
      ],
      steps: [
        'fib(j) is called once from each call to fib(j + 1) and each call '
            'to fib(j + 2).',
        'Counts from fib($n) down: ${counts.join(', ')}: the Fibonacci numbers.',
        'So fib($k) is called $times times.',
      ],
      insight:
          'Right: the repeats are Fibonacci numbers. A memo cuts them '
          'to one.',
      params: {'variant': 'repeat', 'n': n, 'k': k},
    );
  }

  _Draft _memoCalls(Random rng) {
    final adds = rng.nextBool();
    final n = adds ? _r(rng, 6, 30) : _r(rng, 5, 15);
    final code = [
      'fib(n):',
      '  if n < 2: return n',
      '  if n in memo: return memo[n]',
      '  memo[n] = fib(n − 1) + fib(n − 2)',
      '  return memo[n]',
    ];
    final total = 2 * n - 1;
    return _Draft(
      scene: AlgoScene(
        code: code,
        caption: 'With a memo: each answer is kept',
        picture: TreePicture(
          n: n,
          memo: true,
          title: 'The calls with a memo',
          note: adds ? '${n - 1} adds' : '$total calls',
        ),
        pictureOnCard: false,
      ),
      question: adds
          ? 'Working out fib($n), how many calls reach the adding line?'
          : 'Working out fib($n), how many calls are made in all, look-ups '
                'included?',
      hint: adds
          ? 'Each value from fib(2) up is added once.'
          : 'A value is worked out once, then looked up.',
      value: _f(adds ? n - 1 : total),
      traps: adds
          ? [
              (
                _f(total),
                'That counts the look-ups as new work. Each value is added '
                    'up only once.',
              ),
              (
                _f(n + 1),
                'fib(0) and fib(1) return at once. Only fib(2) to fib($n) '
                    'add.',
              ),
              (_f(n), 'fib(1) returns at once, so it never adds.'),
              if (n <= 15)
                (
                  _f(_fib(n + 1) - 1),
                  'That\'s without the memo. With it, each sum is done once.',
                ),
            ]
          : [
              (
                _f(n + 1),
                'That counts each value once. The look-ups are calls too.',
              ),
              (
                _f(_naiveCalls(n)),
                'That\'s without the memo. A look-up makes no further calls.',
              ),
              (_f(2 * n), 'One too many: fib(0) is only asked for once.'),
              (
                _f(n - 1),
                'Those are the calls that add. Look-ups and fib(0), fib(1) '
                    'count too.',
              ),
            ],
      steps: adds
          ? [
              'The first call to each fib(j) for j ≥ 2 adds and stores it.',
              'Later calls to it hit the memo, and fib(0), fib(1) return at '
                  'once.',
              'So fib(2) to fib($n): ${n - 1} calls add.',
            ]
          : [
              'The first call for a value works it out; a second call is a '
                  'look-up, or returns at once for fib(1).',
              'fib($n) and fib(${n - 1}) are called once, fib(${n - 2}) down '
                  'to fib(1) twice each, fib(0) once.',
              '2 + 2 × ${n - 2} + 1 = $total calls.',
            ],
      insight: adds
          ? 'Right: with a memo the work is O(n), not about 1.6ⁿ.'
          : 'Right: 2n − 1 calls, O(n), against about 1.6ⁿ without the memo.',
      params: {'variant': adds ? 'adds' : 'calls', 'n': n},
    );
  }

  // ---- level 5: dynamic programming -----------------------------------------

  static List<int> _waysUp(int n, List<int> steps) {
    final w = List.filled(n + 1, 0)..[0] = 1;
    for (var i = 1; i <= n; i++) {
      for (final s in steps) {
        if (i >= s) w[i] += w[i - s];
      }
    }
    return w;
  }

  _Draft _stairs(Random rng) {
    final three = rng.nextInt(3) == 0;
    final steps = three ? const [1, 2, 3] : const [1, 2];
    final n = three ? _r(rng, 5, 8) : _r(rng, 5, 10);
    final w = _waysUp(n, steps);
    final ans = w[n];
    final hops = <int>[];
    var at = 0;
    while (at < n) {
      final s = min(n - at, _pick(rng, steps));
      hops.add(s);
      at += s;
    }
    final two = _waysUp(n, const [1, 2]);
    return _Draft(
      scene: AlgoScene(
        lines: ['n = $n'],
        caption: three ? 'Steps of 1, 2 or 3' : 'Steps of 1 or 2',
        picture: StairsPicture(
          n: n,
          hops: hops,
          title: 'One way up',
          note: '$ans ways',
        ),
      ),
      question:
          'Climbing $n stairs, ${three ? '1, 2 or 3' : '1 or 2'} at a time: '
          'how many different ways to the top?',
      hint: 'The last move is a ${three ? '1, 2 or 3' : '1 or 2'}.',
      value: _f(ans),
      traps: [
        (
          _f(w[n - 1]),
          'That\'s the ways to stair ${n - 1}, one short. Count on to $n.',
        ),
        (
          _f(1 << (n - 1)),
          'That allows a step of any size. Here they\'re ${three ? '1, 2 or 3' : '1 or 2'}.',
        ),
        if (three)
          (_f(two[n]), 'That leaves out the 3-steps. Add ways(n − 3) too.')
        else
          (_f(n), 'That counts only climbs with at most one 2-step.'),
        if (three)
          (
            _f(w[n - 1] + w[n - 2]),
            'That adds only two earlier stairs. A 3-step adds ways(n − 3).',
          )
        else
          (
            _f(w[n] + w[n - 1]),
            'That\'s the ways to stair ${n + 1}, one too far.',
          ),
      ],
      steps: three
          ? [
              'The last move is 1, 2 or 3, so ways(n) = ways(n − 1) + '
                  'ways(n − 2) + ways(n − 3).',
              'Start with ways(0) = 1: then ${[for (var i = 1; i <= n; i++) w[i]].join(', ')}.',
              'So $ans ways.',
            ]
          : [
              'The last move is 1 or 2, so ways(n) = ways(n − 1) + '
                  'ways(n − 2).',
              'ways(1) = 1, ways(2) = 2, then ${[for (var i = 3; i <= n; i++) w[i]].join(', ')}.',
              'So $ans ways: Fibonacci numbers again.',
            ],
      insight:
          'Right: build up from the bottom stair, adding the ways '
          'below.',
      params: {'n': n, 'steps': steps},
    );
  }

  /// Ways to make [amount] from [coins], order ignored.
  static int _change(int amount, List<int> coins) {
    final w = List.filled(amount + 1, 0)..[0] = 1;
    for (final c in coins) {
      for (var v = c; v <= amount; v++) {
        w[v] += w[v - c];
      }
    }
    return w[amount];
  }

  /// Ways to make [amount] where order counts.
  static int _ordered(int amount, List<int> coins) {
    final w = List.filled(amount + 1, 0)..[0] = 1;
    for (var v = 1; v <= amount; v++) {
      for (final c in coins) {
        if (v >= c) w[v] += w[v - c];
      }
    }
    return w[amount];
  }

  static const _coinSets = [
    [1, 2, 5],
    [1, 2, 3],
    [2, 3, 5],
    [1, 3, 5],
    [1, 5, 10],
  ];

  _Draft _coinWays(Random rng) {
    late List<int> coins;
    late int amount, ans;
    do {
      coins = _pick(rng, _coinSets);
      amount = _r(rng, coins.last == 10 ? 12 : 7, coins.last == 10 ? 25 : 12);
      ans = _change(amount, coins);
    } while (ans < 5 || ans > 40);
    final big = coins.last, rest = coins.sublist(0, 2);
    final split = [
      for (var q = 0; q * big <= amount; q++)
        (q, _change(amount - q * big, rest)),
    ];
    final ordered = _ordered(amount, coins);
    return _Draft(
      scene: AlgoScene(
        caption: 'Make ${whole(amount)} from these coins',
        picture: CoinsPicture(
          coins: coins,
          amount: amount,
          answer: '$ans ways',
          title: 'Coins and the amount',
          note: '$ans ways',
        ),
      ),
      question:
          'Ignoring order, how many ways to make $amount from coins of '
          '${_and(coins)}?',
      hint: 'Sort the ways by how many ${big}s they use.',
      value: _f(ans),
      traps: [
        (
          _f(ordered),
          'That counts orders: ${coins[0]} + ${coins[1]} and ${coins[1]} + '
              '${coins[0]} are the same change.',
        ),
        (
          _f(_change(amount, rest)),
          'That never uses a $big. Add the ways with one or more.',
        ),
        (
          _f(_change(amount, [coins[1], big])),
          'That never uses a ${coins[0]}. Add the ways with them.',
        ),
        (
          _f(split.length),
          'That counts how many ${big}s you could use. Each count has '
              'several ways.',
        ),
      ],
      steps: [
        'Sort the ways by how many ${big}s: ${[for (final (q, _) in split) q].join(', ')}.',
        'For each, make the rest from ${coins[0]}s and ${coins[1]}s: '
            '${[for (final (q, w) in split) '$q × $big: $w'].join(', ')}.',
        '${[for (final (_, w) in split) w].join(' + ')} = $ans ways.',
      ],
      insight:
          'Right: go coin by coin so each mix is counted once, in one '
          'order.',
      params: {'amount': amount, 'coins': coins},
    );
  }

  static const _trickySets = [
    [1, 3, 4],
    [1, 4, 5],
    [1, 5, 6],
    [1, 7, 10],
    [1, 6, 9],
  ];

  static List<int> _fewest(int amount, List<int> coins) {
    const inf = 1 << 20;
    final best = List.filled(amount + 1, inf)..[0] = 0;
    final last = List.filled(amount + 1, 0);
    for (var v = 1; v <= amount; v++) {
      for (final c in coins) {
        if (v >= c && best[v - c] + 1 < best[v]) {
          best[v] = best[v - c] + 1;
          last[v] = c;
        }
      }
    }
    final used = <int>[];
    for (var v = amount; v > 0; v -= last[v]) {
      used.add(last[v]);
    }
    return used..sort((a, b) => b - a);
  }

  static List<int> _greedy(int amount, List<int> coins) {
    final used = <int>[];
    var left = amount;
    for (final c in coins.reversed) {
      while (left >= c) {
        used.add(c);
        left -= c;
      }
    }
    return used;
  }

  _Draft _coinFewest(Random rng) {
    late List<int> coins, best, greedy;
    late int amount;
    do {
      coins = _pick(rng, _trickySets);
      amount = _r(rng, 8, 30);
      best = _fewest(amount, coins);
      greedy = _greedy(amount, coins);
    } while (greedy.length <= best.length || best.length < 4);
    final b = best.length;
    final top = coins.last;
    return _Draft(
      scene: AlgoScene(
        caption: 'Fewest coins that make ${whole(amount)}',
        picture: CoinsPicture(
          coins: coins,
          amount: amount,
          answer: '$b coins',
          title: 'Fewest: ${best.join(' + ')}',
          note: '$b coins',
        ),
      ),
      question:
          'What is the fewest coins that make $amount, from coins of '
          '${_and(coins)}?',
      hint: 'Biggest first isn\'t always best.',
      value: _f(b),
      traps: [
        (
          _f(greedy.length),
          'That\'s biggest first: ${greedy.join(' + ')}. With these coins a '
              'smaller mix wins.',
        ),
        (
          _f((amount / top).ceil()),
          'That\'s ${whole(amount)} ÷ $top rounded up, but those coins '
              'don\'t make ${whole(amount)} exactly.',
        ),
        (_f(b + 1), 'There\'s a mix with one coin fewer: ${best.join(' + ')}.'),
      ],
      steps: [
        'Biggest first: ${greedy.join(' + ')} is ${greedy.length} coins.',
        'Fewer big ones: ${best.join(' + ')} = ${whole(amount)} is $b coins.',
        (b - 1) * top < amount
            ? '${b - 1} coins make at most ${b - 1} × $top = ${(b - 1) * top}, '
                  'short of $amount. So $b.'
            : 'No mix of ${b - 1} coins makes $amount, so $b.',
      ],
      insight:
          'Right: the fewest-coins table, built up from 1, beats '
          'grabbing the biggest coin.',
      params: {'amount': amount, 'coins': coins},
    );
  }

  // ---- level 6: bits -----------------------------------------------------------

  _Draft _setBits(Random rng) {
    late int n;
    do {
      n = _r(rng, 100, 255);
    } while (_popcount(n) < 4 || _popcount(n) > 7);
    final bits = binary(n);
    final ones = _popcount(n);
    final width = bits.length;
    final places = [for (var i = width - 1; i >= 0; i--) 1 << i];
    final parts = [
      for (var i = 0; i < width; i++)
        if (bits[i] == '1') places[i],
    ];
    return _Draft(
      scene: AlgoScene(
        lines: ['n = $n'],
        caption: 'n written in binary',
        picture: RowsPicture(
          header: [for (final p in places) '$p'],
          rows: [
            CellRow(
              '',
              bits.split(''),
              marked: {
                for (var i = 0; i < width; i++)
                  if (bits[i] == '1') i,
              },
              unknown: true,
            ),
          ],
          title: '$n in binary',
          note: '$ones ones',
        ),
      ),
      question: 'How many 1s are in $n written in binary?',
      hint: 'Take the biggest powers of two that fit.',
      value: _f(ones),
      traps: [
        (
          _f(width),
          'That\'s how many binary digits $n has. Count only the 1s.',
        ),
        (_f(width - ones), 'That counts the 0s. Count the 1s instead.'),
        (
          _f(_popcount(n - 1)),
          'That\'s the 1s in ${n - 1}. Check the last few digits again.',
        ),
      ],
      steps: [
        'Take the biggest powers of two that fit: $n = ${parts.join(' + ')}.',
        'So $n is $bits in binary.',
        '$ones of the digits are 1.',
      ],
      insight:
          'Right. Code counts them with n & (n − 1), which clears one 1 '
          'at a time.',
      params: {'n': n},
    );
  }

  _Draft _andMinusOne(Random rng) {
    late int n, ans;
    do {
      // Even, so the lowest 1 isn't the last digit (then the answer would
      // simply be n − 1).
      n = 2 * _r(rng, 5, 31);
      ans = n & (n - 1);
    } while (ans < 4);
    final w = binary(n).length;
    final low = n & -n;
    return _Draft(
      scene: AlgoScene(
        lines: ['n = $n'],
        caption: '& keeps a 1 only where both have one',
        picture: RowsPicture(
          rows: [
            CellRow('$n', binary(n, w).split('')),
            CellRow('${n - 1}', binary(n - 1, w).split('')),
            CellRow(
              '&',
              binary(ans, w).split(''),
              marked: {
                for (var i = 0; i < w; i++)
                  if (binary(ans, w)[i] == '1') i,
              },
              unknown: true,
            ),
          ],
          title: '$n & ${n - 1}',
          note: '= $ans',
        ),
      ),
      question: 'What is n & (n − 1)?',
      hint: 'Subtracting 1 flips the lowest 1 and the 0s after it.',
      value: _f(ans),
      allowZero: true,
      traps: [
        (
          _f(n - 1),
          'That\'s n − 1 itself. & keeps only the 1s both numbers share.',
        ),
        (
          _f(n | (n - 1)),
          'That\'s OR. AND keeps a 1 only where both have a 1.',
        ),
        (
          _f(low),
          'That\'s the lowest 1 on its own. n & (n − 1) clears it and keeps '
              'the rest.',
        ),
        (_f(0), 'Only a power of two gives 0, and $n isn\'t one.'),
      ],
      steps: [
        '$n = ${binary(n, w)} and ${n - 1} = ${binary(n - 1, w)} in binary.',
        'Subtracting 1 flips the lowest 1 and the 0s after it, so & clears '
            'that lowest 1.',
        '${binary(n, w)} & ${binary(n - 1, w)} = ${binary(ans, w)}, which is '
            '$ans.',
      ],
      insight:
          'Right: n & (n − 1) clears the lowest 1. It\'s 0 exactly when '
          'n is a power of two.',
      params: {'n': n},
    );
  }

  _Draft _xorPair(Random rng) {
    late int a, b, ans;
    do {
      a = _r(rng, 5, 15);
      b = _r(rng, 3, 15);
      ans = a ^ b;
    } while (a == b || ans < 4 || (a & b) == 0 || (a | b) == ans);
    final w = binary(max(a, b)).length;
    return _Draft(
      scene: AlgoScene(
        lines: ['a = $a', 'b = $b'],
        caption: 'XOR: 1 where the bits differ',
        picture: RowsPicture(
          rows: [
            CellRow('a', binary(a, w).split('')),
            CellRow('b', binary(b, w).split('')),
            CellRow(
              '⊕',
              binary(ans, w).split(''),
              marked: {
                for (var i = 0; i < w; i++)
                  if (binary(ans, w)[i] == '1') i,
              },
              unknown: true,
            ),
          ],
          title: '$a ⊕ $b',
          note: '= $ans',
        ),
      ),
      question: 'What is a ⊕ b (a XOR b)?',
      hint: 'Line the bits up; 1 where they differ.',
      value: _f(ans),
      traps: [
        (
          _f(a + b),
          'That adds. XOR is adding without carrying: 1 + 1 gives 0.',
        ),
        (_f(a | b), 'That\'s OR. XOR gives 0 where both bits are 1.'),
        (
          _f(a & b),
          'That\'s AND: 1 only where both are 1. XOR is where they '
              'differ.',
        ),
        (_f((a - b).abs()), 'That subtracts. XOR works bit by bit.'),
      ],
      steps: [
        '$a = ${binary(a, w)} and $b = ${binary(b, w)} in binary.',
        'XOR puts a 1 where the bits differ: ${binary(ans, w)}.',
        '${binary(ans, w)} in binary is $ans.',
      ],
      insight: 'Right: XOR is 1 where the bits differ, and x ⊕ x = 0.',
      params: {'a': a, 'b': b},
    );
  }

  _Draft _xorLone(Random rng) {
    late List<int> list, pairs;
    late int lone, distinct;
    do {
      final pool = [for (var v = 1; v <= 15; v++) v]..shuffle(rng);
      lone = pool[0];
      pairs = pool.sublist(1, 4);
      list = [lone, ...pairs, ...pairs]..shuffle(rng);
      distinct = pairs.fold(lone, (x, y) => x ^ y);
    } while (lone < 4 || distinct == lone || distinct == 0);
    final firstTwo = list[0] ^ list[1];
    return _Draft(
      scene: AlgoScene(
        caption: 'Every number twice, but one',
        picture: RowsPicture(
          rows: [
            CellRow(
              '',
              [for (final v in list) '$v'],
              marked: {list.indexOf(lone)},
            ),
          ],
          title: 'The list',
          note: 'XOR of all = $lone',
        ),
        pictureOnCard: true,
      ),
      question: 'XOR all seven numbers together. What is left?',
      hint: 'x ⊕ x = 0, and order doesn\'t matter.',
      value: _f(lone),
      traps: [
        (
          _f(distinct),
          'That XORs each value once. The pairs cancel: x ⊕ x = 0.',
        ),
        (
          _f(list.fold(0, (x, y) => x + y)),
          'That adds them. XOR cancels pairs instead.',
        ),
        if (firstTwo != lone && firstTwo > 0)
          (
            _f(firstTwo),
            'That\'s only the first two. Keep going through the list.',
          ),
      ],
      steps: [
        'x ⊕ x = 0 and x ⊕ 0 = x, in any order.',
        'So the pairs cancel: ${_and([
              for (final p in [...pairs]..sort()) p,
            ])} '
            'each appear twice.',
        'What\'s left is the one without a pair: $lone.',
      ],
      insight:
          'Right: XOR finds the odd one out in one pass, with no extra '
          'memory.',
      params: {'list': list},
    );
  }

  // ---- level 7: Monte Carlo -----------------------------------------------------

  _Draft _piDarts(Random rng, int seed) {
    final n = _pick(rng, const [20, 25, 50, 100]);
    final lo = (n * 0.74).round(), hi = (n * 0.82).round();
    final k = _r(rng, lo, hi);
    final ans = _f(4 * k, n);
    final frac = _f(k, n);
    return _Draft(
      scene: AlgoScene(
        caption: '$n darts · $k inside the quarter circle',
        picture: DartsPicture(
          darts: n,
          inside: k,
          seed: seed,
          title: 'Darts in the unit square',
          note: 'π ≈ ${numText(ans)}',
        ),
      ),
      question: 'What do these darts estimate π as?',
      hint: 'What share of the square is the quarter circle?',
      value: ans,
      unit: _f(4, n),
      places: 2,
      traps: [
        (frac, 'That\'s inside ÷ all, which estimates π/4. Times 4 for π.'),
        (
          _f(2 * k, n),
          'The quarter circle covers π/4 of the square, so times 4, not 2.',
        ),
        (
          _f(4 * (n - k), n),
          'That uses the darts outside. π/4 is the share inside.',
        ),
        (
          _f(314, 100),
          'That\'s π from memory. These darts give a rougher estimate.',
        ),
      ],
      steps: [
        'The quarter circle covers π/4 of the square, so inside ÷ all ≈ π/4.',
        '$k ÷ $n = ${numText(frac)}.',
        'π ≈ 4 × ${numText(frac)} = ${numText(ans)}.',
      ],
      insight: 'Right: π ≈ 4 × inside ÷ all. More darts, a better estimate.',
      params: {'n': n, 'k': k},
    );
  }

  _Draft _mcSamples(Random rng) {
    late int m, n1;
    late Frac e2, e1;
    do {
      m = _pick(rng, const [2, 3, 4, 5, 10]);
      n1 = _pick(rng, const [100, 200, 500, 1000, 2000]);
      e2 = _pick(rng, [_f(1, 100), _f(2, 100), _f(5, 100), _f(1, 10)]);
      e1 = e2 * _f(m);
    } while (e1 > _f(1, 2) || n1 * m * m > 200000);
    final ans = n1 * m * m;
    return _Draft(
      scene: AlgoScene(
        caption: 'A Monte Carlo estimate and its error',
        picture: ErrorPicture(
          error: numText(e1),
          target: numText(e2),
          samples: whole(n1),
          answer: whole(ans),
          title: 'Error against samples',
          note: '${whole(ans)} samples',
        ),
      ),
      question:
          '${whole(n1)} samples give an error of about ${numText(e1)}. '
          'About how many samples for ${numText(e2)}?',
      hint: 'The error shrinks like 1 ÷ √samples.',
      value: _f(ans),
      unit: _f(n1 * m),
      traps: [
        (
          _f(n1 * m),
          'That\'s $m times the samples for a $m times smaller error. The '
              'error shrinks like 1/√n, so it takes $m².',
        ),
        (
          _f(n1 * m * m * m),
          'That cubes the factor. The error shrinks like 1/√n: square it.',
        ),
        (
          _f(n1 * 2 * m),
          'That doubles the factor. The error shrinks like 1/√n: square it.',
        ),
        (
          _f(n1 * m * m ~/ 2),
          'Half of the right count: the error goes as 1/√n, so $m² = '
              '${m * m} times the samples.',
        ),
      ],
      steps: [
        'Monte Carlo error shrinks like 1/√n.',
        '${numText(e1)} → ${numText(e2)} is $m times smaller, so n must grow '
            '$m² = ${m * m} times.',
        '${whole(n1)} × ${m * m} = ${whole(ans)} samples.',
      ],
      insight: 'Right: halving the error takes 4 times the samples.',
      params: {'n1': n1, 'm': m},
    );
  }

  // ---- level 8: paths ---------------------------------------------------------

  static int _choose(int n, int k) {
    var r = 1;
    for (var i = 1; i <= k; i++) {
      r = r * (n - k + i) ~/ i;
    }
    return r;
  }

  _Draft _gridPaths(Random rng) {
    late int w, h, wx, wy, all, through, ans;
    do {
      w = _r(rng, 2, 4);
      h = _r(rng, 2, 4);
      wx = _r(rng, 0, w);
      wy = _r(rng, 0, h);
      if ((wx == 0 && wy == 0) || (wx == w && wy == h)) continue;
      all = _choose(w + h, w);
      final into = _choose(wx + wy, wx);
      final outOf = _choose(w - wx + h - wy, w - wx);
      through = into * outOf;
      ans = all - through;
    } while ((wx == 0 && wy == 0) ||
        (wx == w && wy == h) ||
        w + h < 5 ||
        ans < 5 ||
        through < 2);
    final into = _choose(wx + wy, wx);
    final outOf = _choose(w - wx + h - wy, w - wx);
    return _Draft(
      scene: AlgoScene(
        caption: 'Right or down only · the dark dot is closed',
        picture: GridPicture(
          w: w,
          h: h,
          wall: (wx, wy),
          title: 'Routes from S to T',
          note: '$ans routes',
        ),
      ),
      question:
          'Moving only right or down, how many routes from S to T avoid '
          'the closed corner?',
      hint: 'All routes, minus the ones through the closed corner.',
      value: _f(ans),
      traps: [
        (
          _f(all),
          'That ignores the closed corner. Take away routes through it.',
        ),
        (_f(through), 'Those are the routes through the closed corner.'),
        (_f(w + h), 'That\'s the length of each route, not how many.'),
        (
          _f(all - 1),
          'That takes away one route. Every route through the corner goes.',
        ),
      ],
      steps: [
        'All routes: choose which $w of the ${w + h} moves go right: '
            '${_choose(w + h, w)}.',
        'Through the closed corner: $into ${into == 1 ? 'way' : 'ways'} to '
            'it × $outOf ${outOf == 1 ? 'way' : 'ways'} on = $through.',
        '$all − $through = $ans routes.',
      ],
      insight:
          'Right: count all, take away the blocked ones. A table of '
          'sums does the same.',
      params: {
        'w': w,
        'h': h,
        'wall': [wx, wy],
      },
    );
  }

  _Draft _bfsSteps(Random rng) {
    const cols = 4, rows = 3, size = cols * rows;
    List<int> around(int i) => [
      if (i % cols > 0) i - 1,
      if (i % cols < cols - 1) i + 1,
      if (i >= cols) i - cols,
      if (i < size - cols) i + cols,
    ];
    late Set<(int, int)> edges;
    late List<int> dist, path;
    late int target, dfsLen, crow, order;
    (int, int) e(int a, int b) => a < b ? (a, b) : (b, a);
    while (true) {
      // A random spanning tree from a random walk, plus a few shortcuts.
      edges = {};
      final seen = {0};
      var at = 0;
      final stack = [0];
      while (seen.length < size) {
        final next = [
          for (final j in around(at))
            if (!seen.contains(j)) j,
        ];
        if (next.isEmpty) {
          stack.removeLast();
          at = stack.last;
          continue;
        }
        final j = _pick(rng, next);
        edges.add(e(at, j));
        seen.add(j);
        stack.add(j);
        at = j;
      }
      final extra = _r(rng, 2, 4);
      for (var t = 0; t < 40 && edges.length < size - 1 + extra; t++) {
        final i = rng.nextInt(size);
        edges.add(e(i, _pick(rng, around(i))));
      }
      final adj = {
        for (var i = 0; i < size; i++)
          i: [
            for (final (a, b) in edges)
              if (a == i) b else if (b == i) a,
          ]..sort(),
      };
      dist = List.filled(size, -1)..[0] = 0;
      final from = List.filled(size, -1);
      final queue = [0];
      final visit = <int>[];
      while (queue.isNotEmpty) {
        final u = queue.removeAt(0);
        visit.add(u);
        for (final v in adj[u]!) {
          if (dist[v] < 0) {
            dist[v] = dist[u] + 1;
            from[v] = u;
            queue.add(v);
          }
        }
      }
      final far = [
        for (var i = 0; i < size; i++)
          if (dist[i] >= 4 && dist[i] <= 6) i,
      ];
      if (far.isEmpty) continue;
      target = _pick(rng, far);
      path = [target];
      while (path.last != 0) {
        path.add(from[path.last]);
      }
      path = path.reversed.toList();
      order = visit.indexOf(target);
      crow = (target % cols) + (target ~/ cols);
      // Depth-first, taking the first neighbour in alphabetical order.
      final onPath = <int>[];
      bool dfs(int u, Set<int> used) {
        onPath.add(u);
        if (u == target) return true;
        for (final v in adj[u]!) {
          if (used.add(v) && dfs(v, used)) return true;
        }
        onPath.removeLast();
        return false;
      }

      dfs(0, {0});
      dfsLen = onPath.length - 1;
      if (dfsLen != dist[target] && crow != dist[target]) break;
    }
    final d = dist[target];
    String name(int i) => String.fromCharCode(65 + i);
    final rings = [
      for (var r = 1; r <= d; r++)
        [
          for (var i = 0; i < size; i++)
            if (dist[i] == r) name(i),
        ].join(', '),
    ];
    return _Draft(
      scene: AlgoScene(
        caption: 'Breadth-first search from A',
        picture: GraphPicture(
          cols: cols,
          rows: rows,
          edges: edges.toList(),
          start: 0,
          target: target,
          path: path,
          title: 'A shortest path: ${path.map(name).join(' → ')}',
          note: '$d edges',
        ),
      ),
      question: 'What is the fewest edges from A to ${name(target)}?',
      hint: 'Breadth-first: all nodes 1 edge away, then 2, …',
      value: _f(d),
      traps: [
        (
          _f(d + 1),
          'That counts the nodes on the path. Count the edges between them.',
        ),
        (
          _f(dfsLen),
          'That\'s a path depth-first search finds by always going to the '
              'first neighbour. Breadth-first finds the shortest.',
        ),
        (
          _f(crow),
          'That\'s the distance across the grid. Only the drawn edges count.',
        ),
        (
          _f(order),
          'That counts every node visited before ${name(target)}. Count '
              'rings, not nodes.',
        ),
      ],
      steps: [
        'Breadth-first search visits nodes in rings: 1 edge from A, then 2, …',
        '${[for (var r = 0; r < d; r++) 'ring ${r + 1}: ${rings[r]}'].join('; ').replaceFirst('r', 'R')}.',
        '${name(target)} is first reached in ring $d: $d edges.',
      ],
      insight:
          'Right: breadth-first search finds the fewest edges, ring by '
          'ring.',
      params: {
        'edges': [
          for (final (a, b) in edges) [a, b],
        ],
        'target': target,
        'size': size,
      },
    );
  }

  // ---- level 9: numerical methods ---------------------------------------------

  _Draft _newtonStep(Random rng) {
    late int a, x0;
    late Frac x1, c;
    do {
      x0 = _r(rng, 2, 10);
      a = _r(rng, max(2, x0 * x0 - 2 * x0), x0 * x0 + 2 * x0);
      c = _f(x0 * x0 - a, 2 * x0);
      x1 = _f(x0) - c;
    } while (a == x0 * x0 ||
        ((x1 * _f(100)).d != 1) ||
        sqrt(a) == sqrt(a).roundToDouble());
    final fx = x0 * x0 - a;
    final cAbs = c < Frac.zero ? Frac.zero - c : c;
    return _Draft(
      scene: AlgoScene(
        lines: [r'x_1 = x_0 - \frac{x_0^2 - a}{2x_0}', 'a = $a,  x_0 = $x0'],
        caption: 'Newton\'s method for √$a',
        picture: TangentPicture(
          a: a,
          x0: x0.toDouble(),
          x1: x1.value,
          answer: numText(x1),
          title: 'The tangent at x₀ = $x0',
          note: 'x₁ = ${numText(x1)}',
        ),
      ),
      question: 'One Newton step towards √$a from x₀ = $x0: what is x₁?',
      hint: 'f(x) = x² − $a and f′(x) = 2x.',
      value: x1,
      unit: x1.d == 1 ? _f(1, 2) : _f(1, x1.d),
      places: 2,
      traps: [
        (
          _f(x0) + c,
          'Wrong sign: Newton subtracts f(x₀)/f′(x₀), so it moves towards '
              'the root.',
        ),
        (
          _f(a, x0),
          'That divides by x₀. The slope of x² − $a is 2x₀ = ${2 * x0}.',
        ),
        (cAbs, 'That\'s just the size of the step. Take it from x₀.'),
        (
          _f(x0 + a, 2),
          'That averages x₀ with $a. Average x₀ with $a ÷ x₀ instead.',
        ),
      ],
      steps: [
        'f(x) = x² − $a, f′(x) = 2x: x₁ = x₀ − f(x₀)/f′(x₀).',
        'f($x0) = ${x0 * x0} − $a = ${whole(fx)} and f′($x0) = ${2 * x0}: the '
            'step is ${whole(fx)}/${2 * x0} = ${numText(c)}.',
        'x₁ = $x0 − ${c < Frac.zero ? '(${numText(c)})' : numText(c)} = '
            '${numText(x1)}.',
      ],
      insight:
          'Right: the same as averaging x₀ and $a ÷ x₀. √$a ≈ '
          '${sqrt(a).toStringAsFixed(3)}.',
      params: {'a': a, 'x0': x0},
    );
  }

  _Draft _bisection(Random rng) {
    late Frac width, tol, ratio;
    late int k;
    do {
      width = _pick(rng, [_f(1), _f(2), _f(4), _f(10), _f(3), _f(5)]);
      tol = _pick(rng, [
        _f(1, 10),
        _f(1, 100),
        _f(1, 1000),
        _f(5, 100),
        _f(5, 1000),
        _f(2, 100),
        _f(1, 10000),
      ]);
      ratio = width / tol;
      k = _ceilLog2(ratio.n);
    } while (ratio.d != 1 || (1 << k) == ratio.n || k < 4 || k > 15);
    final r = ratio.n;
    var tens = 0;
    while (pow(10, tens) < r) {
      tens++;
    }
    return _Draft(
      scene: AlgoScene(
        caption: 'Halve the interval that holds the root',
        picture: HalvingPicture(
          width: numText(width),
          tolerance: numText(tol),
          title: 'Each step keeps one half',
          note: '$k halvings',
        ),
      ),
      question:
          'Bisection starts with an interval ${numText(width)} wide. How many '
          'halvings until it\'s narrower than ${numText(tol)}?',
      hint: 'After k halvings the width is ${numText(width)} ÷ 2ᵏ.',
      value: _f(k),
      traps: [
        (
          _f(k - 1),
          'One short: after ${k - 1} halvings it\'s still ${numText(width)} '
              '÷ ${whole(1 << (k - 1))}, not below ${numText(tol)}.',
        ),
        (
          _f(tens),
          'That counts tenths. Each step halves; it doesn\'t divide by 10.',
        ),
        (
          _f(k + 1),
          'One too many: ${pow2(k)} = ${whole(1 << k)} already '
              'beats ${whole(r)}.',
        ),
        (
          _f(r ~/ 2),
          'That shrinks by a fixed amount each step. Bisection halves.',
        ),
      ],
      steps: [
        'After k halvings the width is ${numText(width)} ÷ 2ᵏ.',
        'Need 2ᵏ > ${numText(width)} ÷ ${numText(tol)} = ${whole(r)}.',
        '${pow2(k - 1)} = ${whole(1 << (k - 1))} is short; ${pow2(k)} = '
            '${whole(1 << k)} is enough: $k halvings.',
      ],
      insight:
          'Right: each halving buys one binary digit, about 0.3 decimal '
          'digits.',
      params: {
        'width': [width.n, width.d],
        'tol': [tol.n, tol.d],
      },
    );
  }

  _Draft _newtonDigits(Random rng) {
    final d0 = _r(rng, 1, 3);
    final s = _r(rng, 2, 4);
    final ans = d0 << s;
    final chain = [for (var i = 0; i <= s; i++) d0 << i].join(' → ');
    return _Draft(
      scene: AlgoScene(
        lines: [r"x_{k+1} = x_k - \frac{f(x_k)}{f'(x_k)}"],
        caption: 'Newton\'s method, close to a simple root',
      ),
      question:
          'Newton\'s method has $d0 correct digit${d0 == 1 ? '' : 's'} now. '
          'About how many after $s more steps?',
      hint: 'Near the root, the error is squared each step.',
      value: _f(ans),
      traps: [
        (_f(d0 + s), 'That adds a digit a step. Newton about doubles them.'),
        (
          _f(d0 * 2 * s),
          'That adds $d0 digits a step. Newton doubles what it has.',
        ),
        (
          _f(1 << s),
          'That forgets the $d0 digit${d0 == 1 ? '' : 's'} you start with: '
              '$d0 × ${pow2(s)}.',
        ),
        (_f(d0 << (s - 1)), 'One doubling short: $s steps mean $s doublings.'),
      ],
      steps: [
        'Near the root, Newton\'s error is about squared each step.',
        'Squaring the error doubles the correct digits: $chain.',
        'About $ans digits.',
      ],
      insight:
          'Right: digits double each step. Bisection gains about one '
          'every 3.3.',
      params: {'d0': d0, 's': s},
    );
  }
}

class _Draft {
  _Draft({
    required this.scene,
    required this.question,
    required this.hint,
    required this.steps,
    required this.insight,
    required this.params,
    this.value,
    this.traps = const [],
    Frac? unit,
    this.places = 0,
    this.allowZero = false,
    this.answerSource,
    this.wrong = const [],
  }) : unit = unit ?? Frac.one;

  final AlgoScene scene;
  final String question;
  final String hint;
  final List<String> steps;
  final String insight;
  final Map<String, Object> params;

  /// Numeric questions: the answer, named mistakes, the near-miss step.
  final Frac? value;
  final List<(Frac, String)> traps;
  final Frac unit;

  /// Decimal places allowed in options (0: whole numbers only).
  final int places;

  /// 0 makes sense as an answer here.
  final bool allowZero;

  /// Pick questions: the answer and the wrong options with their slips.
  final String? answerSource;
  final List<(String, String)> wrong;
}
