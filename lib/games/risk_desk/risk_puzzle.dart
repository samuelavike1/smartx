import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../expect_it/expect_puzzle.dart' show ev;
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum RiskKind {
  mixReturn,
  twoVol,
  hedge,
  sharpe,
  capm,
  diversify,
  covariance,
  valueAtRisk,
  minVariance,
}

/// What the card draws above the question.
enum RiskVisual { split, dots, beta, bell, grid, quote }

/// One part of the split bar: an asset and its share of the money.
@immutable
class Slice {
  const Slice(this.label, this.weight, {this.filled = false});

  final String label;

  /// Share of the money, 0 to 1.
  final Frac weight;
  final bool filled;
}

/// A point on the risk–return chart; [ret] is null when it's the unknown.
@immutable
class RiskDot {
  const RiskDot(this.label, this.vol, this.ret, {this.spark = false});

  final String label;
  final Frac vol;
  final Frac? ret;
  final bool spark;
}

/// The card above the question.
@immutable
class RiskScene {
  const RiskScene({
    required this.visual,
    required this.chips,
    this.caption = '',
    this.slices = const [],
    this.unknownSplit = false,
    this.dots = const [],
    this.riskFree,
    this.frontier = false,
    this.marketReturn,
    this.beta,
    this.confidence,
    this.cells = const [],
  });

  final RiskVisual visual;
  final List<String> chips;
  final String caption;

  /// Split bar: the weights (shown as "?" when [unknownSplit]).
  final List<Slice> slices;
  final bool unknownSplit;

  /// Risk–return chart: assets, the risk-free rate on the left edge, and
  /// (for two uncorrelated assets) the curve of every mix between them.
  final List<RiskDot> dots;
  final Frac? riskFree;
  final bool frontier;

  /// Beta line: risk-free at beta 0, the market at beta 1, the stock at
  /// [beta].
  final Frac? marketReturn;
  final Frac? beta;

  /// Bell curve: 95 or 99, the worst 5% or 1% shaded.
  final int? confidence;

  /// Covariance grid, row by row: A·A, A·B, B·A, B·B. "?" is the unknown.
  final List<String> cells;
}

/// A wrong answer and the slip behind it.
@immutable
class RiskTrap {
  const RiskTrap(this.label, this.why, this.value);

  final String label;
  final String why;
  final Frac value;
}

@immutable
class RiskQuestion {
  const RiskQuestion({
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
  final RiskKind kind;
  final RiskScene scene;
  final String question;
  final String hint;
  final String answer;
  final Frac answerValue;
  final List<RiskTrap> traps;
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

/// A percentage, given in percent: "8%", "12.5%", "−0.5%".
String pct(Frac f) => '${signed(f)}%';

/// A tidy number with a real minus sign: "0.75", "−0.5".
String signed(Frac f) => f < Frac.zero ? '−${ev(Frac.zero - f)}' : ev(f);

/// A decimal to up to four places: "0.03", "0.0125", "−0.015".
String dec(Frac f) {
  final a = f < Frac.zero ? Frac.zero - f : f;
  var s = a.value.toStringAsFixed(4);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return f < Frac.zero ? '−$s' : s;
}

/// Whole dollars with thousands separators: "$16,500".
String usd(Frac f) {
  final digits = f.value.round().abs().toString();
  final out = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) out.write(',');
    out.write(digits[i]);
  }
  return '${f < Frac.zero ? '−' : ''}\$$out';
}

/// The exact square root, or null when it isn't a tidy number.
Frac? exactRoot(Frac f) {
  if (f < Frac.zero) return null;
  int? root(int x) {
    final r = sqrt(x).round();
    return r * r == x ? r : null;
  }

  final n = root(f.n), d = root(f.d);
  return n == null || d == null ? null : Frac(n, d);
}

class RiskDifficulty {
  static List<RiskKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [RiskKind.mixReturn],
    2 => const [RiskKind.twoVol],
    3 => const [RiskKind.hedge],
    4 => const [RiskKind.sharpe],
    5 => const [RiskKind.capm],
    6 => const [RiskKind.diversify],
    7 => const [RiskKind.covariance],
    8 => const [RiskKind.valueAtRisk],
    9 => const [RiskKind.minVariance],
    _ => const [
      RiskKind.sharpe,
      RiskKind.capm,
      RiskKind.diversify,
      RiskKind.covariance,
      RiskKind.valueAtRisk,
      RiskKind.minVariance,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'expected return of a mix',
    2 => 'risk at correlation 1 or 0',
    3 => 'correlation −1: zero risk',
    4 => 'the Sharpe ratio',
    5 => 'beta and CAPM',
    6 => 'diversification',
    7 => 'covariance and the cross term',
    8 => 'Value at Risk',
    9 => 'the lowest-risk mix',
    _ => 'the whole desk',
  };
}

class RiskGenerator {
  const RiskGenerator();

  static const _again = 'Check the numbers again: see the working.';

  RiskQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = RiskDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final draft = switch (kind) {
      RiskKind.mixReturn => _mixReturn(rng),
      RiskKind.twoVol => _twoVol(rng),
      RiskKind.hedge => _hedge(rng),
      RiskKind.sharpe => _sharpe(rng),
      RiskKind.capm => _capm(rng),
      RiskKind.diversify => _diversify(rng),
      RiskKind.covariance => _covariance(rng),
      RiskKind.valueAtRisk => _valueAtRisk(rng),
      RiskKind.minVariance => _minVariance(rng),
    };

    final a = draft.value;
    bool ok(Frac v) =>
        v > draft.low &&
        (draft.high == null || v <= draft.high!) &&
        draft.tidy(v) &&
        v != a;

    // Named slips first, then plain near misses; the answer at a random
    // rank, smallest first.
    final named = [
      for (final t in draft.traps)
        if (ok(t.value)) t,
    ];
    final fillers = <RiskTrap>[];
    for (final side in [-1, 1]) {
      var got = 0;
      for (final step in [Frac.one, Frac(1, 2), Frac(1, 4), Frac(1, 10)]) {
        final u = draft.unit * step;
        for (var k = 1; k <= 3 && got < 3; k++) {
          final v = a + u * Frac(side * k);
          if (ok(v) && !fillers.any((t) => t.value == v)) {
            fillers.add(RiskTrap(draft.format(v), _again, v));
            got++;
          }
        }
        if (got >= 3) break;
      }
    }
    final chosen = balancedOptions(
      RiskTrap(draft.answer, '', a),
      named,
      fillers,
      rng,
      compare: (x, y) => x.value.compareTo(y.value),
    );

    return RiskQuestion(
      level: level,
      seed: seed,
      kind: kind,
      scene: draft.scene,
      question: draft.question,
      hint: draft.hint,
      answer: draft.answer,
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

  /// x/100: a decimal from a number given in hundredths.
  static Frac _c(int x) => Frac(x, 100);

  static RiskTrap _p(Frac v, String why) => RiskTrap(pct(v), why, v);

  static bool _tidy2(Frac v) => 100 % v.d == 0;
  static bool _tidy4(Frac v) => 10000 % v.d == 0;
  static bool _whole(Frac v) => v.d == 1;

  static Frac _abs(Frac f) => f < Frac.zero ? Frac.zero - f : f;

  /// Weighted vols (a, b) whose squares add to a square c², with the
  /// weight in A (in %) and the two vols (in %) behind them.
  static final List<(int, int, int, int, int, int)> _pyth = () {
    final out = <(int, int, int, int, int, int)>[];
    for (var a = 2; a <= 24; a++) {
      for (var b = 2; b <= 24; b++) {
        if (a == b) continue;
        final c = sqrt(a * a + b * b).round();
        if (c * c != a * a + b * b) continue;
        for (final w in const [20, 25, 40, 50, 60, 75, 80]) {
          if ((a * 100) % w != 0 || (b * 100) % (100 - w) != 0) continue;
          final sa = a * 100 ~/ w, sb = b * 100 ~/ (100 - w);
          if (sa < 4 || sb < 4 || sa > 45 || sb > 45) continue;
          out.add((w, sa, sb, a, b, c));
        }
      }
    }
    return out;
  }();

  static String _w(int w) => ev(_c(w));

  // ---- kinds --------------------------------------------------------------

  _Draft _mixReturn(Random rng) {
    final w = _pick(rng, const [20, 25, 30, 40, 60, 70, 75, 80]);
    final ra = 2 + rng.nextInt(15);
    var rb = 2 + rng.nextInt(15);
    while (rb == ra) {
      rb = 2 + rng.nextInt(15);
    }
    final dollars = rng.nextBool();
    final total = _pick(rng, const [10000, 20000, 50000, 100000]);
    final wa = _c(w), wb = _c(100 - w);
    final inA = Frac(total * w ~/ 100), inB = Frac(total * (100 - w) ~/ 100);
    final partA = wa * Frac(ra), partB = wb * Frac(rb);
    final ans = partA + partB;
    final more = w > 50 ? 'A' : 'B';
    return _Draft(
      scene: RiskScene(
        visual: RiskVisual.split,
        chips: ['A · return $ra%', 'B · return $rb%'],
        slices: [
          Slice(dollars ? 'A ${usd(inA)}' : 'A $w%', wa, filled: true),
          Slice(dollars ? 'B ${usd(inB)}' : 'B ${100 - w}%', wb),
        ],
        caption: dollars ? 'Where the money is' : 'Portfolio weights',
      ),
      question: dollars
          ? 'You put ${usd(inA)} in A and ${usd(inB)} in B. What\'s the '
                'expected return?'
          : 'What\'s the portfolio\'s expected return?',
      hint: 'Weight each return by its share of the money.',
      value: ans,
      traps: [
        _p(
          (Frac(ra) + Frac(rb)) / Frac(2),
          'Averaging the two returns ignores the weights: $more holds more '
          'of the money.',
        ),
        _p(
          wb * Frac(ra) + wa * Frac(rb),
          'That swaps the weights: A holds $w% of the money, not '
          '${100 - w}%.',
        ),
        _p(partA, 'That counts only A. The money in B earns its return too.'),
        _p(partB, 'That counts only B. The money in A earns its return too.'),
        _p(
          Frac(ra + rb),
          'Adding the returns counts the money twice; each return applies '
          'only to its share.',
        ),
        _p(
          partA + Frac(rb),
          'That weights A\'s return but not B\'s; B earns $rb% only on its '
          '${100 - w}%.',
        ),
        _p(
          Frac(ra) + partB,
          'That weights B\'s return but not A\'s; A earns $ra% only on its '
          '$w%.',
        ),
      ],
      steps: [
        dollars
            ? 'A holds ${usd(inA)} of ${usd(Frac(total))}: $w%. B holds '
                  '${100 - w}%.'
            : 'A has $w% of the money and B has ${100 - w}%.',
        '${_w(w)} × $ra% = ${pct(partA)}; ${_w(100 - w)} × $rb% = '
            '${pct(partB)}.',
        'Add them: ${pct(partA)} + ${pct(partB)} = ${pct(ans)}.',
      ],
      insight:
          'Right: a portfolio\'s return is the weighted average of its '
          'assets\' returns.',
      params: {
        'w': Frac(w),
        'ra': Frac(ra),
        'rb': Frac(rb),
        'dollars': Frac(dollars ? 1 : 0),
      },
    );
  }

  _Draft _twoVol(Random rng) {
    final (w, sa, sb, a, b, c) = _pick(rng, _pyth);
    final one = rng.nextBool();
    final ans = Frac(one ? a + b : c);
    final avg = Frac(sa + sb, 2);
    final big = a > b ? 'A' : 'B', other = a > b ? 'B' : 'A';
    final split = [
      Slice('A $w%', _c(w), filled: true),
      Slice('B ${100 - w}%', _c(100 - w)),
    ];
    final traps = one
        ? [
            _p(
              Frac(c),
              'That adds variances, the rule for correlation 0. With '
              'correlation 1 nothing cancels: the risks add.',
            ),
            _p(
              avg,
              'That\'s a plain average of the two vols; weight each by its '
              'share.',
            ),
            _p(
              Frac(sa + sb),
              'That adds the full vols, but each asset carries only its '
              'weight.',
            ),
            _p(
              Frac((a - b).abs()),
              'Subtracting is the rule for correlation −1, when the two '
              'cancel.',
            ),
            _p(
              Frac(max(a, b)),
              'That counts only $big\'s part. $other adds risk too.',
            ),
          ]
        : [
            _p(
              Frac(a + b),
              'Averaging vols only works when correlation is 1. '
              'Independent risks partly cancel.',
            ),
            _p(
              avg,
              'A plain average of the vols ignores the weights and the '
              'cancelling.',
            ),
            _p(
              Frac(c * c),
              'That\'s the variance. Take its square root to get back to '
              'volatility.',
            ),
            _p(
              Frac((a - b).abs()),
              'Subtracting is the rule for correlation −1, when the two '
              'exactly offset.',
            ),
            _p(
              Frac(max(a, b)),
              'That counts only $big\'s part. $other adds risk too, even if '
              'it partly cancels.',
            ),
            if (exactRoot(_c(w) * Frac(sa * sa) + _c(100 - w) * Frac(sb * sb))
                case final r?)
              _p(r, 'That forgets to square the weights.'),
          ];
    return _Draft(
      scene: RiskScene(
        visual: RiskVisual.split,
        chips: ['A · vol $sa%', 'B · vol $sb%', 'Correlation ${one ? 1 : 0}'],
        slices: split,
        caption: 'Portfolio weights',
      ),
      question: one
          ? 'A and B move in lockstep. What\'s the portfolio\'s volatility?'
          : 'A and B move independently. What\'s the portfolio\'s '
                'volatility?',
      hint: one
          ? 'Correlation 1: the weighted risks simply add.'
          : 'Correlation 0: add the variances, then take the square root.',
      value: ans,
      traps: traps,
      steps: [
        '${_w(w)} × $sa% = $a% and ${_w(100 - w)} × $sb% = $b%.',
        one
            ? 'Correlation 1: nothing cancels, so the parts add.'
            : 'Correlation 0: add the squares: $a² + $b² = ${c * c}.',
        one ? '$a% + $b% = ${a + b}%.' : 'Square root: √${c * c} = $c%.',
      ],
      insight: one
          ? 'Right: with correlation 1, the risk is the weighted average of '
                'the vols.'
          : 'Right: independent risks add as squares, so the mix is safer '
                'than the average.',
      params: {
        'w': Frac(w),
        'sa': Frac(sa),
        'sb': Frac(sb),
        'rho': Frac(one ? 1 : 0),
      },
    );
  }

  static final List<(int, int)> _hedgePairs = () {
    const vols = [5, 6, 8, 10, 12, 15, 16, 18, 20, 24, 25, 30, 32, 35, 40];
    return [
      for (final sa in vols)
        for (final sb in vols)
          if (sa != sb &&
              (100 * sb) % (sa + sb) == 0 &&
              100 * sb ~/ (sa + sb) >= 10 &&
              100 * sb ~/ (sa + sb) <= 90)
            (sa, sb),
    ];
  }();

  _Draft _hedge(Random rng) {
    if (rng.nextInt(5) < 3) {
      final (sa, sb) = _pick(rng, _hedgePairs);
      // Ask for the safer asset's share: the slips fall on both sides.
      final askA = sa < sb;
      final safe = askA ? 'A' : 'B', risky = askA ? 'B' : 'A';
      final lo = min(sa, sb), hi = max(sa, sb);
      final ans = Frac(100 * hi, sa + sb);
      return _Draft(
        scene: RiskScene(
          visual: RiskVisual.split,
          chips: ['A · vol $sa%', 'B · vol $sb%', 'Correlation −1'],
          slices: [Slice('A ?', _c(50), filled: true), Slice('B ?', _c(50))],
          unknownSplit: true,
          caption: 'Find the split',
        ),
        question:
            'A and B always move opposite ways. What share in $safe makes '
            'the risk zero?',
        hint: 'Make the weighted vols equal: share × vol, the same for both.',
        value: ans,
        high: Frac(100),
        unit: Frac(5),
        traps: [
          _p(
            Frac(100 * lo, sa + sb),
            'That swaps the weights: the safer asset needs the bigger share '
            'to cancel the riskier one.',
          ),
          _p(
            Frac(50),
            'Equal weights only cancel when the two vols are equal.',
          ),
          _p(
            Frac(100 * hi * hi, sa * sa + sb * sb),
            'That splits by variances, the rule for correlation 0. With '
            'correlation −1, the vols cancel directly.',
          ),
          _p(
            Frac(100 * lo, hi),
            'That\'s the ratio of the two vols, not a share of the money.',
          ),
          _p(
            Frac(100),
            'All in $safe still carries its $lo%; some $risky is needed to '
            'cancel it.',
          ),
        ],
        steps: [
          'Correlation −1: the risks cancel when A\'s share × $sa% = B\'s '
              'share × $sb%.',
          'So $safe\'s share = $hi ÷ ($sa + $sb) = $hi ÷ ${sa + sb}.',
          'That\'s ${pct(ans)} in $safe and ${pct(Frac(100) - ans)} in '
              '$risky.',
        ],
        insight:
            'Right: with correlation −1 the safer asset takes the bigger '
            'share, and risk drops to zero.',
        params: {
          'variant': Frac.zero,
          'sa': Frac(sa),
          'sb': Frac(sb),
          'askA': Frac(askA ? 1 : 0),
        },
      );
    }
    final pool = [
      for (final p in _pyth)
        if ((p.$4 - p.$5).abs() >= 2) p,
    ];
    final (w, sa, sb, a, b, c) = _pick(rng, pool);
    final ans = Frac((a - b).abs());
    return _Draft(
      scene: RiskScene(
        visual: RiskVisual.split,
        chips: ['A · vol $sa%', 'B · vol $sb%', 'Correlation −1'],
        slices: [
          Slice('A $w%', _c(w), filled: true),
          Slice('B ${100 - w}%', _c(100 - w)),
        ],
        caption: 'Portfolio weights',
      ),
      question:
          'A and B always move opposite ways. What\'s the portfolio\'s '
          'volatility?',
      hint: 'Opposite moves cancel: take the difference of the weighted vols.',
      value: ans,
      traps: [
        _p(
          Frac(a + b),
          'Adding the parts is the rule for correlation 1. Here the two '
          'move against each other.',
        ),
        _p(
          Frac(c),
          'Adding variances is the rule for correlation 0. Opposite moves '
          'cancel even more.',
        ),
        _p(
          Frac(sa + sb, 2),
          'A plain average of the vols ignores the weights and the '
          'cancelling.',
        ),
        _p(
          Frac(max(a, b)),
          'That\'s only the bigger part. The other part cancels some of it.',
        ),
        _p(
          Frac((sa - sb).abs()),
          'That subtracts the full vols; weight each one first.',
        ),
      ],
      steps: [
        '${_w(w)} × $sa% = $a% and ${_w(100 - w)} × $sb% = $b%.',
        'Correlation −1: when one rises the other falls, so the parts '
            'cancel.',
        'The bigger minus the smaller: ${max(a, b)}% − ${min(a, b)}% = '
            '${pct(ans)}.',
      ],
      insight:
          'Right: perfectly opposite assets cancel, leaving the difference '
          'of the weighted vols.',
      params: {
        'variant': Frac.one,
        'w': Frac(w),
        'sa': Frac(sa),
        'sb': Frac(sb),
      },
    );
  }

  static final List<(int, int, Frac)> _sharpePool = () {
    const vols = [5, 8, 10, 12, 15, 16, 20, 25];
    final ratios = [25, 40, 50, 60, 75, 80, 100, 120, 125, 150].map(_c);
    return [
      for (var rf = 1; rf <= 5; rf++)
        for (final s in vols)
          for (final sr in ratios)
            if (10 % (Frac(rf) + sr * Frac(s)).d == 0 &&
                Frac(rf) + sr * Frac(s) <= Frac(30))
              (rf, s, sr),
    ];
  }();

  _Draft _sharpe(Random rng) {
    final (rf, s, sr) = _pick(rng, _sharpePool);
    final r = Frac(rf) + sr * Frac(s);
    final excess = r - Frac(rf);
    RiskScene chart(bool known) => RiskScene(
      visual: RiskVisual.dots,
      chips: known
          ? ['Fund · return ${pct(r)}', 'Vol $s%', 'Risk-free $rf%']
          : ['Fund · vol $s%', 'Sharpe ${ev(sr)}', 'Risk-free $rf%'],
      dots: [RiskDot('fund', Frac(s), known ? r : null, spark: true)],
      riskFree: Frac(rf),
      caption: 'Risk across · return up',
    );
    if (rng.nextInt(3) < 2) {
      return _Draft(
        scene: chart(true),
        question: 'What\'s the fund\'s Sharpe ratio?',
        hint: 'Return above the risk-free rate, per 1% of volatility.',
        value: sr,
        format: ev,
        unit: Frac(1, 10),
        traps: [
          RiskTrap(
            ev(r / Frac(s)),
            'That forgets the risk-free rate: Sharpe counts only the '
            'return above it.',
            r / Frac(s),
          ),
          RiskTrap(
            ev((r + Frac(rf)) / Frac(s)),
            'That adds the risk-free rate; take it away instead.',
            (r + Frac(rf)) / Frac(s),
          ),
          RiskTrap(
            ev(Frac(s) / excess),
            'That\'s upside down: the extra return goes on top, the vol '
            'underneath.',
            Frac(s) / excess,
          ),
          RiskTrap(
            ev((r - Frac(2 * rf)) / Frac(s)),
            'That takes the risk-free rate off twice.',
            (r - Frac(2 * rf)) / Frac(s),
          ),
          RiskTrap(
            ev(excess * Frac(100) / Frac(s * s)),
            'That divides by the variance; Sharpe uses the vol.',
            excess * Frac(100) / Frac(s * s),
          ),
        ],
        steps: [
          'Extra return over the risk-free rate: ${pct(r)} − $rf% = '
              '${pct(excess)}.',
          'Divide by the vol: ${ev(excess)} ÷ $s.',
          'Sharpe ratio = ${ev(sr)}.',
        ],
        insight: 'Right: Sharpe is the extra return per unit of risk.',
        params: {
          'variant': Frac.zero,
          'rf': Frac(rf),
          's': Frac(s),
          'r': r,
          'sr': sr,
        },
      );
    }
    final bare = sr * Frac(s);
    return _Draft(
      scene: chart(false),
      question:
          'What return does the fund need for a Sharpe ratio of '
          '${ev(sr)}?',
      hint: 'Sharpe × vol is the return above the risk-free rate.',
      value: r,
      traps: [
        _p(bare, 'That\'s only the extra return; add the risk-free $rf% back.'),
        _p(
          bare - Frac(rf),
          'That subtracts the risk-free rate; the fund has to beat it, so '
          'add it.',
        ),
        _p(r + Frac(rf), 'That adds the risk-free rate twice.'),
        _p(
          Frac(s + rf),
          'That adds the whole vol; only ${ev(sr)} × the vol is extra '
          'return.',
        ),
        _p(
          Frac(rf) + Frac(s) / sr,
          'That divides the vol by the Sharpe ratio; multiply instead.',
        ),
      ],
      steps: [
        'Sharpe = (return − $rf%) ÷ $s%.',
        'So the extra return is ${ev(sr)} × $s% = ${pct(bare)}.',
        'Add the risk-free rate: ${pct(bare)} + $rf% = ${pct(r)}.',
      ],
      insight:
          'Right: the return needed is the risk-free rate plus Sharpe × '
          'vol.',
      params: {
        'variant': Frac.one,
        'rf': Frac(rf),
        's': Frac(s),
        'r': r,
        'sr': sr,
      },
    );
  }

  static final List<(int, int, Frac)> _betaPool = () {
    final rhos = [20, 25, 40, 50, 60, 75, 80, 90].map(_c);
    return [
      for (final sm in const [10, 15, 20, 25])
        for (var si = 10; si <= 50; si += 5)
          for (final rho in rhos)
            if (si != sm &&
                _tidy2(rho * Frac(si, sm)) &&
                rho * Frac(si, sm) >= _c(20) &&
                rho * Frac(si, sm) <= _c(250))
              (sm, si, rho),
    ];
  }();

  _Draft _capm(Random rng) {
    if (rng.nextInt(5) < 3) {
      final rf = Frac(2 + rng.nextInt(4));
      final rm = Frac(7 + rng.nextInt(6));
      final b = _pick(
        rng,
        [50, 60, 75, 80, 120, 125, 150, 200].map(_c).toList(),
      );
      final extra = b * (rm - rf);
      final ans = rf + extra;
      return _Draft(
        scene: RiskScene(
          visual: RiskVisual.beta,
          chips: ['Beta ${ev(b)}', 'Market ${pct(rm)}', 'Risk-free ${pct(rf)}'],
          riskFree: rf,
          marketReturn: rm,
          beta: b,
          caption: 'Beta across · return up',
        ),
        question:
            'The stock moves ${ev(b)}× as much as the market (its beta). '
            'What return does CAPM expect?',
        hint: 'The risk-free rate, plus beta × the market\'s extra return.',
        value: ans,
        unit: Frac(1, 2),
        traps: [
          _p(
            b * rm,
            'Beta × the market return leaves out the risk-free part: it\'s '
            'risk-free + beta × (market − risk-free).',
          ),
          _p(
            extra,
            'That\'s only the extra return over the risk-free rate; add the '
            '${pct(rf)} back.',
          ),
          _p(
            rm,
            'That\'s a beta of 1. This stock moves ${ev(b)}× as much as the '
            'market.',
          ),
          _p(
            rf + b * rm,
            'That uses the whole market return, not just the part above the '
            'risk-free rate.',
          ),
          _p(
            rf + (rm - rf) / b,
            'That divides by beta; multiply by it instead.',
          ),
        ],
        steps: [
          'The market\'s extra return: ${pct(rm)} − ${pct(rf)} = '
              '${pct(rm - rf)}.',
          'Times beta: ${ev(b)} × ${pct(rm - rf)} = ${pct(extra)}.',
          'Add the risk-free rate: ${pct(rf)} + ${pct(extra)} = ${pct(ans)}.',
        ],
        insight:
            'Right: CAPM pays the risk-free rate plus beta times the '
            'market\'s extra return.',
        params: {'variant': Frac.zero, 'rf': rf, 'rm': rm, 'beta': b},
      );
    }
    final (sm, si, rho) = _pick(rng, _betaPool);
    final ans = rho * Frac(si, sm);
    return _Draft(
      scene: RiskScene(
        visual: RiskVisual.quote,
        chips: [
          'Stock · vol $si%',
          'Market · vol $sm%',
          'Correlation ${ev(rho)}',
        ],
        caption: 'Stock against the market',
      ),
      question:
          'Beta is how far the stock moves per 1% move in the market. '
          'What\'s its beta?',
      hint: 'Correlation × the stock\'s vol ÷ the market\'s vol.',
      value: ans,
      format: ev,
      unit: Frac(1, 10),
      traps: [
        RiskTrap(
          ev(Frac(si, sm)),
          'That forgets the correlation: only the part that moves with the '
          'market counts.',
          Frac(si, sm),
        ),
        RiskTrap(
          ev(rho),
          'Correlation alone ignores how much more the stock swings than '
          'the market.',
          rho,
        ),
        RiskTrap(
          ev(rho * Frac(sm, si)),
          'That\'s upside down: the stock\'s vol goes on top.',
          rho * Frac(sm, si),
        ),
        RiskTrap(
          ev(rho * Frac(si * si, sm * sm)),
          'That squares the ratio of the vols; beta uses it once.',
          rho * Frac(si * si, sm * sm),
        ),
      ],
      steps: [
        'Beta = correlation × stock vol ÷ market vol.',
        '${ev(rho)} × $si = ${ev(rho * Frac(si))}.',
        '${ev(rho * Frac(si))} ÷ $sm = ${ev(ans)}.',
      ],
      insight:
          'Right: beta is the correlation, scaled by how much more the '
          'stock swings.',
      params: {'variant': Frac.one, 'sm': Frac(sm), 'si': Frac(si), 'rho': rho},
    );
  }

  _Draft _diversify(Random rng) {
    final roll = rng.nextInt(20);
    if (roll < 9) {
      final n = _pick(rng, const [4, 9, 16, 25]);
      final root = sqrt(n).round();
      final ks = [
        for (var k = 3; k <= 12; k++)
          if (k * root <= 60) k,
      ];
      final k = _pick(rng, ks);
      final s = k * root;
      return _Draft(
        scene: RiskScene(
          visual: RiskVisual.split,
          chips: ['$n assets', 'Each vol $s%', 'Independent'],
          slices: [
            for (var i = 0; i < n; i++)
              Slice(n <= 4 ? '${100 ~/ n}%' : '', Frac(1, n), filled: i == 0),
          ],
          caption: 'Equal weights',
        ),
        question:
            '$n independent assets, equal money in each. What\'s the '
            'portfolio\'s volatility?',
        hint: 'Independent risks shrink with the square root of the count.',
        value: Frac(k),
        traps: [
          _p(
            Frac(s, n),
            'That divides by $n. Risk falls with the square root: √$n = '
            '$root.',
          ),
          _p(
            Frac(s),
            'That\'s one asset\'s risk. Independent risks partly cancel.',
          ),
          _p(
            Frac(k * k),
            'That\'s the variance. Take its square root to get back to '
            'volatility.',
          ),
          _p(Frac(s, 2), 'Halving is the rule for 4 assets, not $n.'),
        ],
        steps: [
          'Each holds 1/$n of the money, and the risks are independent.',
          'Variance falls by $n, so the vol falls by √$n = $root.',
          '$s% ÷ $root = $k%.',
        ],
        insight: 'Right: n independent bets cut risk by √n, not by n.',
        params: {'variant': Frac.zero, 'n': Frac(n), 's': Frac(s)},
      );
    }
    if (roll < 13) {
      final k = _pick(rng, const [2, 3, 4, 5]);
      final t = _pick(rng, [
        for (final t in const [4, 5, 6, 8, 10, 12])
          if (k * t <= 60) t,
      ]);
      final s = k * t;
      return _Draft(
        scene: RiskScene(
          visual: RiskVisual.quote,
          chips: ['Each vol $s%', 'Independent', 'Target $t%'],
          caption: 'Equal weights',
        ),
        question:
            'How many independent assets, equal money in each, bring the '
            'vol down to $t%?',
        hint: 'Vol falls with the square root of the number of assets.',
        value: Frac(k * k),
        format: (v) => ev(v),
        tidy: _whole,
        low: Frac.one,
        traps: [
          RiskTrap(
            '$k',
            'Risk falls with the square root, so a $k-fold cut takes $k² '
                'assets.',
            Frac(k),
          ),
          RiskTrap(
            '${k * k * k}',
            'That cubes the cut; squaring it is enough.',
            Frac(k * k * k),
          ),
          RiskTrap(
            '${2 * k}',
            'That doubles the cut; vol falls with √n, so square it.',
            Frac(2 * k),
          ),
          RiskTrap(
            '$s',
            'That counts one asset per 1% of vol. Vol falls with √n.',
            Frac(s),
          ),
        ],
        steps: [
          'You need to cut the vol $s% ÷ $t% = $k times.',
          'Vol falls with √n, so √n = $k.',
          'n = $k² = ${k * k}.',
        ],
        insight:
            'Right: to cut risk k times with independent assets, you need k² '
            'of them.',
        params: {'variant': Frac.one, 's': Frac(s), 't': Frac(t)},
      );
    }
    final s = _pick(rng, const [10, 15, 20, 25, 30, 40]);
    final rt = _pick(rng, const [2, 3, 4, 5, 6, 7, 8]);
    final rho = Frac(rt * rt, 100);
    final ans = Frac(s) * Frac(rt, 10);
    final varLeft = Frac(s * s) * rho;
    return _Draft(
      scene: RiskScene(
        visual: RiskVisual.split,
        chips: ['Each vol $s%', 'Correlation ${ev(rho)}', 'Equal weights'],
        slices: [
          for (var i = 0; i < 20; i++) Slice('', Frac(1, 20), filled: i == 0),
        ],
        caption: 'Very many assets',
      ),
      question:
          'Every pair of assets has correlation ${ev(rho)}. With very many '
          'of them, what vol is left?',
      hint: 'The shared part of the risk never diversifies away.',
      value: ans,
      traps: [
        _p(
          rho * Frac(s),
          'That forgets the square root: what\'s left is vol × '
          '√correlation.',
        ),
        _p(
          Frac(s),
          'Diversifying still removes the part each asset has alone.',
        ),
        if (exactRoot(Frac.one - rho) case final q?)
          _p(
            q * Frac(s),
            'That\'s the part that diversifies away, not the part that '
            'stays.',
          ),
        _p(
          (Frac.one - rho) * Frac(s),
          'That\'s the part that cancels, and it forgets the square root.',
        ),
      ],
      steps: [
        'Adding assets shrinks only the risk each one has alone.',
        'The shared part stays: variance $s² × ${ev(rho)} = '
            '${ev(varLeft)}.',
        'Vol: √${ev(varLeft)} = ${pct(ans)}.',
      ],
      insight:
          'Right: shared risk stays however many assets you add: vol × '
          '√correlation.',
      params: {'variant': Frac(2), 's': Frac(s), 'rho': rho},
    );
  }

  static const _covVols = [10, 15, 20, 25, 30, 40, 50];

  _Draft _covariance(Random rng) {
    final roll = rng.nextInt(3);
    if (roll < 2) {
      final pool = [
        for (final a in _covVols)
          for (final b in _covVols)
            for (final rho in const [20, 25, 40, 50, 60, 75, 80])
              if (a != b && _tidy4(_c(rho) * _c(a) * _c(b))) (a, b, rho),
      ];
      final (va, vb, r) = _pick(rng, pool);
      final sa = _c(va), sb = _c(vb), rho = _c(r);
      final cov = rho * sa * sb;
      if (roll == 0) {
        return _Draft(
          scene: RiskScene(
            visual: RiskVisual.grid,
            chips: ['A · vol $va%', 'B · vol $vb%', 'Correlation ${ev(rho)}'],
            cells: [dec(sa * sa), '?', '?', dec(sb * sb)],
            caption: 'Covariance grid',
          ),
          question: 'What\'s the covariance of A and B?',
          hint: 'Correlation scaled by both vols, as decimals.',
          value: cov,
          format: dec,
          tidy: _tidy4,
          unit: cov >= _c(4)
              ? _c(1)
              : cov >= Frac(15, 1000)
              ? Frac(5, 1000)
              : Frac(1, 1000),
          traps: [
            RiskTrap(
              dec(sa * sb),
              'That forgets the correlation: covariance is correlation × '
              'both vols.',
              sa * sb,
            ),
            RiskTrap(
              dec(rho * sa),
              'That uses only A\'s vol; covariance needs both.',
              rho * sa,
            ),
            RiskTrap(
              dec(rho * sb),
              'That uses only B\'s vol; covariance needs both.',
              rho * sb,
            ),
            RiskTrap(
              dec(rho * rho * sa * sb),
              'That squares the correlation; use it once.',
              rho * rho * sa * sb,
            ),
            RiskTrap(
              dec(rho * sa * sa * sb * sb),
              'That multiplies the variances; use the vols.',
              rho * sa * sa * sb * sb,
            ),
          ],
          steps: [
            'Write the vols as decimals: ${dec(sa)} and ${dec(sb)}.',
            'Covariance = correlation × A\'s vol × B\'s vol.',
            '${ev(rho)} × ${dec(sa)} × ${dec(sb)} = ${dec(cov)}.',
          ],
          insight:
              'Right: covariance is correlation scaled by both '
              'volatilities.',
          params: {'variant': Frac.zero, 'sa': sa, 'sb': sb, 'rho': rho},
        );
      }
      return _Draft(
        scene: RiskScene(
          visual: RiskVisual.grid,
          chips: ['A · vol $va%', 'B · vol $vb%', 'Covariance ${dec(cov)}'],
          cells: [dec(sa * sa), dec(cov), dec(cov), dec(sb * sb)],
          caption: 'Covariance grid',
        ),
        question: 'What\'s the correlation of A and B?',
        hint: 'Divide the covariance by both vols.',
        value: rho,
        format: dec,
        tidy: _tidy4,
        high: Frac.one,
        unit: rho >= _c(80) ? _c(5) : _c(10),
        traps: [
          RiskTrap(
            dec(cov),
            'That\'s the covariance itself; divide by both vols to get the '
            'correlation.',
            cov,
          ),
          RiskTrap(
            dec(cov * sa * sb),
            'That multiplies by the vols; divide instead.',
            cov * sa * sb,
          ),
          RiskTrap(
            dec(cov / (sa + sb)),
            'That divides by the sum of the vols; use their product.',
            cov / (sa + sb),
          ),
          RiskTrap(
            dec(cov / sa),
            'That divides by A\'s vol only; divide by B\'s too.',
            cov / sa,
          ),
          RiskTrap(
            dec(cov / sb),
            'That divides by B\'s vol only; divide by A\'s too.',
            cov / sb,
          ),
        ],
        steps: [
          'Write the vols as decimals: ${dec(sa)} and ${dec(sb)}.',
          'Their product: ${dec(sa)} × ${dec(sb)} = ${dec(sa * sb)}.',
          '${dec(cov)} ÷ ${dec(sa * sb)} = ${dec(rho)}.',
        ],
        insight:
            'Right: correlation is covariance with both vols divided out, '
            'so it sits between −1 and 1.',
        params: {'variant': Frac.one, 'sa': sa, 'sb': sb, 'cov': cov},
      );
    }
    final pool = [
      for (final w in const [40, 50, 60])
        for (final a in const [10, 20, 30, 40])
          for (final b in const [10, 20, 30, 40])
            for (final r in const [25, 50, 75, -25, -50])
              if (a != b && _tidy4(_portVar(_c(w), _c(a), _c(b), _c(r))))
                (w, a, b, r),
    ];
    final (w, va, vb, r) = _pick(rng, pool);
    final wa = _c(w), wb = _c(100 - w), sa = _c(va), sb = _c(vb), rho = _c(r);
    final cov = rho * sa * sb;
    final own = wa * wa * sa * sa + wb * wb * sb * sb;
    final cross = Frac(2) * wa * wb * cov;
    final ans = own + cross;
    final lockstep = (wa * sa + wb * sb) * (wa * sa + wb * sb);
    return _Draft(
      scene: RiskScene(
        visual: RiskVisual.grid,
        chips: [
          'A $w% · vol $va%',
          'B ${100 - w}% · vol $vb%',
          'Correlation ${signed(rho)}',
        ],
        cells: [dec(sa * sa), dec(cov), dec(cov), dec(sb * sb)],
        caption: 'Covariance grid',
      ),
      question: 'What\'s the variance of the portfolio?',
      hint: 'Each weight² × its variance, plus the cross term.',
      value: ans,
      format: dec,
      tidy: _tidy4,
      unit: ans >= _c(4)
          ? _c(1)
          : ans >= Frac(15, 1000)
          ? Frac(5, 1000)
          : Frac(1, 1000),
      traps: [
        RiskTrap(
          dec(own),
          'That forgets the cross term: 2 × each weight × the covariance.',
          own,
        ),
        RiskTrap(
          dec(own + cross / Frac(2)),
          'The cross term counts twice: 2 × each weight × the covariance.',
          own + cross / Frac(2),
        ),
        RiskTrap(
          dec(wa * sa * sa + wb * sb * sb + cross),
          'Square the weights too: ${ev(wa)}² × A\'s variance.',
          wa * sa * sa + wb * sb * sb + cross,
        ),
        RiskTrap(
          dec(lockstep),
          'That\'s correlation 1, the weighted vols added then squared.',
          lockstep,
        ),
      ],
      steps: [
        '${ev(wa)}² × ${dec(sa * sa)} + ${ev(wb)}² × ${dec(sb * sb)} = '
            '${dec(own)}.',
        'Cross term: 2 × ${ev(wa)} × ${ev(wb)} × ${dec(cov)} = '
            '${dec(cross)}.',
        'Add: ${dec(own)} ${cross < Frac.zero ? '−' : '+'} '
            '${dec(_abs(cross))} = ${dec(ans)}.',
      ],
      insight:
          'Right: the cross term is where correlation enters portfolio '
          'risk.',
      params: {'variant': Frac(2), 'w': wa, 'sa': sa, 'sb': sb, 'rho': rho},
    );
  }

  static Frac _portVar(Frac w, Frac sa, Frac sb, Frac rho) {
    final v = Frac.one - w;
    return w * w * sa * sa + v * v * sb * sb + Frac(2) * w * v * rho * sa * sb;
  }

  /// A round step for near misses: about an eighth of [a].
  static Frac _niceUnit(Frac a) {
    var best = Frac(50);
    for (final u in const [50, 100, 250, 500, 1000, 2500, 5000, 10000, 25000]) {
      if (Frac(u * 6) <= a) best = Frac(u);
    }
    return best;
  }

  _Draft _valueAtRisk(Random rng) {
    final v = Frac(
      _pick(rng, const [100000, 200000, 500000, 1000000, 2000000]),
    );
    final sd = _pick(rng, [Frac(1, 2), Frac.one, Frac(3, 2), Frac(2)]);
    final conf = rng.nextBool() ? 95 : 99;
    final z = conf == 95 ? _c(165) : _c(233);
    final zOther = conf == 95 ? _c(233) : _c(165);
    final days = _pick(rng, const [4, 9, 16, 25]);
    final root = Frac(sqrt(days).round());
    final oneSd = sd / Frac(100) * v;
    final oneDay = z * oneSd;
    final ans = oneDay * root;
    final tail = 100 - conf;
    RiskScene scene(List<String> chips) => RiskScene(
      visual: RiskVisual.bell,
      chips: chips,
      confidence: conf,
      caption: 'One day\'s gains and losses',
    );
    if (rng.nextInt(3) < 2) {
      return _Draft(
        scene: scene([
          'Portfolio ${usd(v)}',
          'Daily vol ${pct(sd)}',
          '$conf%: ${ev(z)}σ',
        ]),
        question: 'What\'s the $conf% Value at Risk over $days days?',
        hint: 'VaR is a loss you\'d only exceed $tail% of the time.',
        value: ans,
        format: usd,
        tidy: _whole,
        unit: _niceUnit(ans),
        traps: [
          RiskTrap(
            usd(oneDay * Frac(days)),
            '${usd(oneDay * Frac(days))} scales by the $days days. Risk '
            'grows with the square root of time, so multiply by '
            '√$days = $root.',
            oneDay * Frac(days),
          ),
          RiskTrap(
            usd(oneDay),
            'That\'s one day. Over $days days the risk grows by √$days = '
            '$root.',
            oneDay,
          ),
          RiskTrap(
            usd(zOther * oneSd * root),
            '${ev(zOther)} is the ${conf == 95 ? 99 : 95}% multiplier; '
            '$conf% uses ${ev(z)}.',
            zOther * oneSd * root,
          ),
          RiskTrap(
            usd(oneSd * root),
            'That\'s one standard deviation. $conf% VaR goes ${ev(z)} of '
            'them out.',
            oneSd * root,
          ),
          RiskTrap(
            usd(oneDay / root),
            'That divides by √$days; risk grows with time, so multiply.',
            oneDay / root,
          ),
        ],
        steps: [
          'One day: ${ev(z)} × ${pct(sd)} × ${usd(v)} = ${usd(oneDay)}.',
          'Risk grows with the square root of time: √$days = $root.',
          '${usd(oneDay)} × $root = ${usd(ans)}.',
        ],
        insight: 'Right: VaR is a multiple of vol, and vol grows with √time.',
        params: {
          'variant': Frac.zero,
          'v': v,
          'sd': sd,
          'conf': Frac(conf),
          'days': Frac(days),
        },
      );
    }
    return _Draft(
      scene: scene(['1-day $conf% VaR ${usd(oneDay)}', 'Normal model']),
      question:
          'Nothing else changes. What\'s the $conf% Value at Risk over '
          '$days days?',
      hint: 'Risk grows with the square root of time.',
      value: ans,
      format: usd,
      tidy: _whole,
      unit: _niceUnit(ans),
      traps: [
        RiskTrap(
          usd(oneDay * Frac(days)),
          '${usd(oneDay * Frac(days))} scales by the $days days. Risk grows '
          'with √days, so multiply by $root.',
          oneDay * Frac(days),
        ),
        RiskTrap(
          usd(oneDay),
          'That\'s still one day. Over $days days the risk grows by '
          '√$days = $root.',
          oneDay,
        ),
        RiskTrap(
          usd(oneDay / root),
          'That divides by √$days; risk grows with time, so multiply.',
          oneDay / root,
        ),
        RiskTrap(
          usd(oneDay * Frac(days, 2)),
          'That halves the days; VaR grows with √days instead.',
          oneDay * Frac(days, 2),
        ),
      ],
      steps: [
        'VaR is a multiple of the vol, so it scales like the vol.',
        'Over $days days the vol is √$days = $root times the daily vol.',
        '${usd(oneDay)} × $root = ${usd(ans)}.',
      ],
      insight: 'Right: VaR scales with the square root of the holding period.',
      params: {
        'variant': Frac.one,
        'v': v,
        'sd': sd,
        'conf': Frac(conf),
        'days': Frac(days),
      },
    );
  }

  _Draft _minVariance(Random rng) {
    if (rng.nextInt(3) < 2) {
      final pool = [
        for (final (x, y) in const [(1, 2), (1, 3), (3, 4)])
          for (var k = 1; k <= 20; k++)
            if (x * k >= 5 && y * k <= 40) ...[(x * k, y * k), (y * k, x * k)],
      ];
      final (sa, sb) = _pick(rng, pool);
      final va = sa * sa, vb = sb * sb;
      final ans = Frac(100 * vb, va + vb);
      Frac ret(int s) => Frac(2 + (s / 3).round());
      return _Draft(
        scene: RiskScene(
          visual: RiskVisual.dots,
          chips: ['A · vol $sa%', 'B · vol $sb%', 'Correlation 0'],
          dots: [
            RiskDot('A', Frac(sa), ret(sa)),
            RiskDot('B', Frac(sb), ret(sb)),
          ],
          frontier: true,
          caption: 'Every mix of A and B',
        ),
        question:
            'A and B are uncorrelated. What share in A gives the lowest '
            'possible risk?',
        hint: 'Each weight follows the other asset\'s variance.',
        value: ans,
        high: Frac(100),
        unit: Frac(5),
        traps: [
          _p(
            Frac(100 * va, va + vb),
            'That swaps the weights: the safer asset gets the bigger share.',
          ),
          _p(
            Frac(100 * sb, sa + sb),
            'That splits by vols, the correlation −1 rule. With correlation '
            '0, use the variances.',
          ),
          _p(
            Frac(50),
            'Equal weights are only best when the two risks are equal.',
          ),
          if (sa < sb)
            _p(
              Frac(100),
              'All in the safer asset isn\'t lowest: a little of an '
              'uncorrelated one cuts risk further.',
            ),
        ],
        steps: [
          'Variances: $sa² = $va and $sb² = $vb.',
          'A\'s weight = B\'s variance ÷ the total: $vb ÷ ${va + vb}.',
          'That\'s ${pct(ans)} in A and ${pct(Frac(100) - ans)} in B.',
        ],
        insight:
            'Right: with correlation 0, each weight is proportional to 1 ÷ '
            'its variance.',
        params: {'variant': Frac.zero, 'sa': Frac(sa), 'sb': Frac(sb)},
      );
    }
    final k = _pick(rng, const [2, 3, 4, 5, 6, 8, 10]);
    final flip = rng.nextBool();
    final sa = flip ? 4 * k : 3 * k, sb = flip ? 3 * k : 4 * k;
    final w = flip ? 36 : 64;
    final wa = _c(w), wb = _c(100 - w);
    final a = wa * Frac(sa), b = wb * Frac(sb);
    final sq = a * a + b * b;
    final ans = Frac(12 * k, 5);
    return _Draft(
      scene: RiskScene(
        visual: RiskVisual.split,
        chips: ['A · vol $sa%', 'B · vol $sb%', 'Correlation 0'],
        slices: [Slice('A $w%', wa, filled: true), Slice('B ${100 - w}%', wb)],
        caption: 'The lowest-risk mix',
      ),
      question:
          'This is the lowest-risk mix of two uncorrelated assets. What\'s '
          'its volatility?',
      hint: 'Square the weighted vols, add them, then take the root.',
      value: ans,
      unit: Frac(k, 5),
      traps: [
        _p(
          Frac(5 * k, 2),
          'That\'s the 50/50 mix; the lowest-risk mix does a little better.',
        ),
        _p(
          Frac(min(sa, sb)),
          'That\'s the safer asset alone; mixing in the other cuts risk.',
        ),
        _p(a + b, 'Averaging vols ignores that the two partly cancel.'),
        _p(
          _abs(a - b),
          'Subtracting is the rule for correlation −1, when the two '
          'exactly offset.',
        ),
        _p(sq, 'That\'s the variance. Take its square root.'),
      ],
      steps: [
        '${ev(wa)} × $sa% = ${pct(a)} and ${ev(wb)} × $sb% = ${pct(b)}.',
        'Correlation 0: ${ev(a)}² + ${ev(b)}² = ${ev(sq)}.',
        'Square root: √${ev(sq)} = ${pct(ans)}.',
      ],
      insight:
          'Right: mixing two uncorrelated assets gets below the safer one\'s '
          'risk.',
      params: {
        'variant': Frac.one,
        'w': Frac(w),
        'sa': Frac(sa),
        'sb': Frac(sb),
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
    String Function(Frac)? format,
    bool Function(Frac)? tidy,
    Frac? unit,
    Frac? low,
    this.high,
  }) : format = format ?? pct,
       tidy = tidy ?? RiskGenerator._tidy2,
       unit = unit ?? Frac.one,
       low = low ?? Frac.zero,
       answer = (format ?? pct)(value);

  final RiskScene scene;
  final String question;
  final String hint;
  final Frac value;
  final String answer;
  final List<RiskTrap> traps;
  final List<String> steps;
  final String insight;
  final Map<String, Frac> params;

  /// How options are written, which values can be written exactly, and the
  /// step for near misses.
  final String Function(Frac) format;
  final bool Function(Frac) tidy;
  final Frac unit;

  /// Options must lie above [low] and (when set) at or below [high].
  final Frac low;
  final Frac? high;
}
