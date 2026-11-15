import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum BondKind {
  presentValue,
  futureValue,
  zeroPrice,
  couponPrice,
  premium,
  zeroYield,
  forward,
  macaulay,
  priceMove,
  zeroDuration,
  portfolio,
}

/// What the scene card draws above the question.
enum BondVisual { timeline, curve, portfolio, none }

/// How the numeric options are written.
enum BondUnit {
  /// "$70.72".
  money,

  /// A signed amount of money: "−$2.08", "+$2.08".
  change,

  /// "10%", "12.5%".
  percent,

  /// "1.8 years".
  years,
}

/// One payment on the timeline.
@immutable
class CashFlow {
  const CashFlow(this.year, this.amount, {this.paid = false, this.today});

  final int year;
  final Frac amount;

  /// Money you put in (a price or a deposit), drawn as an outline.
  final bool paid;

  /// What the payment is worth today, written under its year.
  final Frac? today;
}

/// One bond in a portfolio.
@immutable
class Holding {
  const Holding(this.name, this.value, this.face, this.duration);

  final String name;
  final Frac value;
  final Frac face;
  final Frac duration;
}

/// The card above the question.
@immutable
class BondScene {
  const BondScene({
    required this.visual,
    required this.chips,
    required this.caption,
    this.years = 0,
    this.flows = const [],
    this.unknownAt,
    this.spanFrom,
    this.spanTo,
    this.price,
    this.yieldUp = true,
    this.moveLabel = '',
    this.holdings = const [],
  });

  final BondVisual visual;
  final List<String> chips;
  final String caption;

  /// Timeline: years 0 (today) to [years], the payments, and where the
  /// spark-orange "?" goes.
  final int years;
  final List<CashFlow> flows;
  final int? unknownAt;

  /// Timeline: an unknown rate from year [spanFrom] to [spanTo].
  final int? spanFrom, spanTo;

  /// Curve: today's price and the yield move.
  final Frac? price;
  final bool yieldUp;
  final String moveLabel;

  /// Portfolio: the bonds held.
  final List<Holding> holdings;
}

/// A wrong answer and the slip behind it.
@immutable
class BondTrap {
  const BondTrap(this.label, this.why, [this.value]);

  final String label;
  final String why;

  /// For numeric answers: used to order the options.
  final Frac? value;
}

@immutable
class BondQuestion {
  const BondQuestion({
    required this.level,
    required this.seed,
    required this.kind,
    required this.scene,
    required this.question,
    required this.hint,
    required this.answer,
    required this.traps,
    required this.options,
    required this.optionValues,
    required this.steps,
    required this.insight,
    required this.params,
    this.unit,
    this.answerValue,
    this.approx = false,
  });

  final int level;
  final int seed;
  final BondKind kind;
  final BondScene scene;
  final String question;
  final String hint;
  final String answer;

  /// Null for the word questions.
  final Frac? answerValue;
  final BondUnit? unit;

  /// Every option is rounded to cents (they all read "about …").
  final bool approx;
  final List<BondTrap> traps;
  final List<String> options;

  /// The number behind each option (empty for word questions).
  final List<Frac> optionValues;
  final List<String> steps;
  final String insight;

  /// The numbers behind the question, for recomputing in tests.
  final Map<String, Frac> params;

  bool get words => answerValue == null;

  int get answerIndex => options.indexOf(answer);

  String feedbackFor(String picked) => picked == answer
      ? insight
      : traps.firstWhere((t) => t.label == picked).why;
}

/// True when [v] is a whole number of cents (at most two decimals).
bool exactCents(Frac v) => 100 % v.d == 0;

/// A terminating decimal written out in full ("1.1", "1.331",
/// "1.157625"); anything else to four places.
String decimal(Frac f) {
  var d = f.d;
  while (d % 2 == 0) {
    d ~/= 2;
  }
  while (d % 5 == 0) {
    d ~/= 5;
  }
  if (d != 1) return f.value.toStringAsFixed(4);
  for (var places = 0; places < 12; places++) {
    final scaled = f * Frac(pow(10, places).toInt());
    if (scaled.d == 1) {
      final neg = scaled.n < 0;
      final digits = scaled.n.abs().toString().padLeft(places + 1, '0');
      final cut = digits.length - places;
      final body = places == 0
          ? digits
          : '${digits.substring(0, cut)}.${digits.substring(cut)}';
      return neg ? '−$body' : body;
    }
  }
  return f.value.toStringAsFixed(4);
}

/// A rate written as a percentage: Frac(1, 10) → "10%".
String pct(Frac rate) => '${decimal(rate * Frac(100))}%';

String _grouped(int whole) {
  final s = whole.toString();
  final out = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) out.write(',');
    out.write(s[i]);
  }
  return out.toString();
}

/// Rounded to the nearest cent (or hundredth), as a whole number.
int hundredths(Frac v) => (v.n * 100 / v.d).round();

/// Dollars in the text: "$1,331", "$70.72", or "about $96.53" when the
/// amount isn't a whole number of cents.
String cash(Frac v) {
  final c = hundredths(v);
  final neg = c < 0;
  final a = c.abs();
  final whole = exactCents(v) && a % 100 == 0;
  final body = whole
      ? '\$${_grouped(a ~/ 100)}'
      : '\$${_grouped(a ~/ 100)}.${(a % 100).toString().padLeft(2, '0')}';
  return '${exactCents(v) ? '' : 'about '}${neg ? '−' : ''}$body';
}

/// How one option is written, given the places every option in the
/// question shares and whether they all read "about".
String optionLabel(Frac v, BondUnit unit, int places, bool approx) {
  final c = hundredths(v);
  final a = c.abs();
  final whole = a ~/ 100;
  final frac = a % 100;
  final digits = switch (places) {
    0 => '$whole',
    1 => '$whole.${frac ~/ 10}',
    _ => '$whole.${frac.toString().padLeft(2, '0')}',
  };
  final money =
      '\$${_grouped(whole)}${places == 0 ? '' : digits.substring(digits.indexOf('.'))}';
  final body = switch (unit) {
    BondUnit.money => c < 0 ? '−$money' : money,
    BondUnit.change => c < 0 ? '−$money' : '+$money',
    BondUnit.percent => '${c < 0 ? '−' : ''}$digits%',
    BondUnit.years => digits == '1' ? '1 year' : '$digits years',
  };
  return approx ? 'about $body' : body;
}

/// The decimal places a set of options shares: none if every one is
/// whole, else as few as the most precise needs (money: 0 or 2).
int sharedPlaces(Iterable<Frac> values, BondUnit unit, bool approx) {
  if (approx) return 2;
  final hs = [for (final v in values) hundredths(v)];
  if (hs.every((h) => h % 100 == 0)) return 0;
  if (unit == BondUnit.money || unit == BondUnit.change) return 2;
  return hs.every((h) => h % 10 == 0) ? 1 : 2;
}

class BondDifficulty {
  static List<BondKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [BondKind.presentValue],
    2 => const [BondKind.futureValue],
    3 => const [BondKind.zeroPrice],
    4 => const [BondKind.couponPrice],
    5 => const [BondKind.premium],
    6 => const [BondKind.zeroYield, BondKind.forward],
    7 => const [BondKind.macaulay],
    8 => const [BondKind.priceMove],
    9 => const [BondKind.zeroDuration, BondKind.portfolio],
    _ => const [
      BondKind.couponPrice,
      BondKind.premium,
      BondKind.zeroYield,
      BondKind.forward,
      BondKind.macaulay,
      BondKind.priceMove,
      BondKind.zeroDuration,
      BondKind.portfolio,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'what a later payment is worth today',
    2 => 'growing money, year on year',
    3 => 'pricing a zero-coupon bond',
    4 => 'pricing a bond with coupons',
    5 => 'premium, par or discount',
    6 => 'yields and forward rates',
    7 => 'Macaulay duration',
    8 => 'price moves from duration',
    9 => 'zeros and portfolios',
    _ => 'the whole desk',
  };
}

class BondGenerator {
  const BondGenerator();

  static const _again = 'Check the numbers again: see the working.';

  BondQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = BondDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final draft = switch (kind) {
      BondKind.presentValue => _presentValue(rng),
      BondKind.futureValue => _futureValue(rng),
      BondKind.zeroPrice => _zeroPrice(rng),
      BondKind.couponPrice => _couponPrice(rng),
      BondKind.premium => _premium(rng),
      BondKind.zeroYield => _zeroYield(rng),
      BondKind.forward => _forward(rng),
      BondKind.macaulay => _macaulay(rng),
      BondKind.priceMove => _priceMove(rng),
      BondKind.zeroDuration => _zeroDuration(rng),
      BondKind.portfolio => _portfolio(rng),
    };

    if (draft.value == null) {
      final traps = draft.traps.take(3).toList();
      return BondQuestion(
        level: level,
        seed: seed,
        kind: kind,
        scene: draft.scene,
        question: draft.question,
        hint: draft.hint,
        answer: draft.answer!,
        traps: traps,
        options: [draft.answer!, ...traps.map((t) => t.label)]..shuffle(rng),
        optionValues: const [],
        steps: draft.steps,
        insight: draft.insight,
        params: draft.params,
      );
    }

    // Numbers: smallest first, the answer at a random rank, named slips
    // first, then plain near misses. An exact answer only sits among exact
    // options; an inexact one makes every option read "about", so the
    // format never singles the answer out.
    final a = draft.value!;
    final unit = draft.unit;
    final approx = !exactCents(a);
    bool fits(Frac v) =>
        (unit == BondUnit.change ? v != Frac.zero : v > Frac.zero) &&
        (approx || exactCents(v));
    final named = [
      for (final t in draft.traps)
        if (fits(t.value!)) t,
    ];
    final fillers = [
      for (final k in [1, 2, 3])
        for (final sign in [1, -1])
          if (fits(a + draft.step * Frac(sign * k)))
            BondTrap('', _again, a + draft.step * Frac(sign * k)),
    ]..shuffle(rng);
    final chosen = balancedOptions(
      BondTrap('', '', a),
      named,
      fillers,
      rng,
      compare: (x, y) => hundredths(x.value!).compareTo(hundredths(y.value!)),
    );
    final places = sharedPlaces(chosen.map((t) => t.value!), unit, approx);
    String label(Frac v) => optionLabel(v, unit, places, approx);
    final answer = label(a);
    return BondQuestion(
      level: level,
      seed: seed,
      kind: kind,
      scene: draft.scene,
      question: draft.question,
      hint: draft.hint,
      answer: answer,
      answerValue: a,
      unit: unit,
      approx: approx,
      traps: [
        for (final t in chosen)
          if (t.value != a) BondTrap(label(t.value!), t.why, t.value),
      ],
      options: [for (final t in chosen) label(t.value!)],
      optionValues: [for (final t in chosen) t.value!],
      steps: [for (final s in draft.steps) s.replaceAll('{A}', answer)],
      insight: draft.insight,
      params: draft.params,
    );
  }

  // ---- helpers ------------------------------------------------------------

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  static BondTrap _t(Frac v, String why) => BondTrap('', why, v);

  /// A rate from a whole or half percentage.
  static Frac _rate(num percent) => Frac((percent * 10).round(), 1000);

  /// A tidy step for plain near misses: about 5% of [a].
  static Frac _moneyStep(Frac a) {
    for (final s in const [100, 50, 20, 10, 5, 2, 1]) {
      if (a.value.abs() >= s * 20) return Frac(s);
    }
    return a.value.abs() >= 5 ? Frac(1, 4) : Frac(1, 10);
  }

  static String _pow(int n) => switch (n) {
    1 => '',
    2 => '²',
    3 => '³',
    _ => '^$n',
  };

  static String _years(int n) => n == 1 ? '1 year' : '$n years';

  /// The growth factor written with its power: "1.1²".
  static String _g(Frac g, int n) => '${decimal(g)}${_pow(n)}';

  static List<CashFlow> _bondFlows(Frac coupon, Frac face, int n) => [
    for (var t = 1; t <= n; t++) CashFlow(t, t == n ? coupon + face : coupon),
  ];

  static String _list(List<String> xs) => xs.length == 1
      ? xs.first
      : '${xs.sublist(0, xs.length - 1).join(', ')} and ${xs.last}';

  // ---- kinds --------------------------------------------------------------

  /// One payment a year away, brought back to today.
  _Draft _presentValue(Random rng) {
    final p = Frac(_pick(rng, [20, 50, 80, 100, 200, 400, 500, 1000]));
    final r = _rate(_pick(rng, [4, 5, 8, 10, 20, 25]));
    final g = Frac.one + r;
    final f = p * g;
    return _Draft(
      scene: BondScene(
        visual: BondVisual.timeline,
        chips: ['Paid in 1 year', 'Rate ${pct(r)} a year'],
        caption: 'What it pays, year by year',
        years: 1,
        flows: [CashFlow(1, f)],
        unknownAt: 0,
      ),
      question: 'What is ${cash(f)} a year from now worth today?',
      hint: 'Today\'s value × ${decimal(g)} grows to ${cash(f)} in a year.',
      value: p,
      unit: BondUnit.money,
      step: _moneyStep(p),
      traps: [
        _t(
          f,
          'That\'s the amount in a year. Money later is worth less today, '
          'so discount it.',
        ),
        _t(
          p * r,
          'That\'s the interest the money earns, not what it\'s worth '
          'today.',
        ),
        _t(
          f * g,
          'That grows it by another year. To bring it back to today, '
          'divide by ${decimal(g)}.',
        ),
        _t(
          f * (Frac.one - r),
          'Taking ${pct(r)} off the later amount isn\'t discounting: '
          'divide by ${decimal(g)} instead.',
        ),
        _t(f / g / g, 'That discounts two years; the payment is one away.'),
      ],
      steps: [
        'Today\'s value × ${decimal(g)} = ${cash(f)}.',
        'So today\'s value = ${cash(f)} ÷ ${decimal(g)}.',
        'That\'s {A}.',
      ],
      insight: 'Right: divide by 1 + the rate for each year you wait.',
      params: {'f': f, 'r': r},
    );
  }

  /// Money growing with interest on interest.
  _Draft _futureValue(Random rng) {
    Frac p, r;
    int n;
    do {
      p = Frac(_pick(rng, [100, 200, 400, 500, 800, 1000, 2000]));
      r = _rate(_pick(rng, [4, 5, 6, 8, 10, 20, 25]));
      n = 2 + rng.nextInt(2);
    } while (!exactCents(p * (Frac.one + r).pow(n)));
    final g = Frac.one + r;
    final ans = p * g.pow(n);
    return _Draft(
      scene: BondScene(
        visual: BondVisual.timeline,
        chips: ['Invest ${cash(p)}', '${pct(r)} a year', _years(n)],
        caption: 'Interest added once a year',
        years: n,
        flows: [CashFlow(0, p, paid: true)],
        unknownAt: n,
      ),
      question:
          'Interest is added once a year, and then earns interest too. What '
          'do you have after ${_years(n)}?',
      hint: 'Multiply by ${decimal(g)} once for each year.',
      value: ans,
      unit: BondUnit.money,
      step: _moneyStep(p),
      traps: [
        _t(
          p * (Frac.one + r * Frac(n)),
          'That\'s simple interest: it forgets that the interest earns '
          'interest too.',
        ),
        _t(
          ans - p,
          'That\'s only the interest earned; add the ${cash(p)} you put '
          'in.',
        ),
        _t(
          p * g.pow(n - 1),
          'That grows it for ${_years(n - 1)}; it stays in for '
          '${_years(n)}.',
        ),
        _t(
          p * g.pow(n + 1),
          'That grows it for ${_years(n + 1)}; it stays in for '
          '${_years(n)}.',
        ),
        _t(
          p / g.pow(n),
          'That discounts back in time; the money is growing forward.',
        ),
      ],
      steps: [
        'Each year multiplies the money by ${decimal(g)}.',
        '${_g(g, n)} = ${decimal(g.pow(n))}.',
        '${cash(p)} × ${decimal(g.pow(n))} = {A}.',
      ],
      insight: 'Right: compounding multiplies by 1 + the rate every year.',
      params: {'p': p, 'r': r, 'n': Frac(n)},
    );
  }

  /// A zero-coupon bond: one payment, at the end.
  _Draft _zeroPrice(Random rng) {
    Frac r, p, f;
    int n;
    do {
      r = _rate(_pick(rng, [4, 5, 8, 10, 20, 25]));
      n = 2 + rng.nextInt(2);
      final g = (Frac.one + r).pow(n);
      if (r == _rate(25) && rng.nextBool()) {
        f = Frac(_pick(rng, [100, 1000]));
        p = f / g;
      } else {
        p = Frac(_pick(rng, [100, 200, 400, 500, 800, 1000]));
        f = p * g;
      }
    } while (!exactCents(f) || !exactCents(p));
    final g = Frac.one + r;
    return _Draft(
      scene: BondScene(
        visual: BondVisual.timeline,
        chips: ['Zero coupon', 'Face ${cash(f)}', 'Yield ${pct(r)}'],
        caption: 'What it pays, year by year',
        years: n,
        flows: [CashFlow(n, f)],
        unknownAt: 0,
      ),
      question:
          'A zero-coupon bond pays nothing until its ${cash(f)} face value '
          'in ${_years(n)}. What\'s its price today?',
      hint: 'Divide by ${decimal(g)} once for each year you wait.',
      value: p,
      unit: BondUnit.money,
      step: _moneyStep(p),
      traps: [
        _t(
          f,
          'That\'s what it pays at the end. Money then is worth less '
          'today.',
        ),
        _t(
          f / g.pow(n - 1),
          'That discounts ${_years(n - 1)}; the payment is ${_years(n)} '
          'away.',
        ),
        _t(
          f / g.pow(n + 1),
          'That discounts ${_years(n + 1)}; the payment is ${_years(n)} '
          'away.',
        ),
        _t(
          f * (Frac.one - r * Frac(n)),
          'Taking ${pct(r)} of the face off per year isn\'t discounting: '
          'divide by ${decimal(g)} each year.',
        ),
        _t(
          f / (Frac.one + r * Frac(n)),
          'That\'s simple discounting. Compound it: divide by '
          '${decimal(g)} once per year.',
        ),
        _t(f * g.pow(n), 'That grows the face instead of discounting it.'),
      ],
      steps: [
        'The only payment: ${cash(f)} in ${_years(n)}.',
        '${_g(g, n)} = ${decimal(g.pow(n))}.',
        '${cash(f)} ÷ ${decimal(g.pow(n))} = {A}.',
      ],
      insight: 'Right: a zero is its face value discounted to today.',
      params: {'f': f, 'r': r, 'n': Frac(n)},
    );
  }

  /// Coupons each year and the face at the end, each discounted.
  _Draft _couponPrice(Random rng) {
    final exact = rng.nextBool();
    final yp = exact ? 25 : _pick(rng, [4, 5, 6, 8, 10]);
    int cp;
    do {
      cp = exact ? _pick(rng, [5, 10, 15, 20, 30, 40]) : 2 + rng.nextInt(11);
    } while (cp == yp);
    final face = Frac(_pick(rng, [100, 100, 1000]));
    final c = face * Frac(cp, 100);
    final n = 2 + rng.nextInt(2);
    final y = _rate(yp);
    final g = Frac.one + y;
    final flows = _bondFlows(c, face, n);
    var coupons = Frac.zero, simple = Frac.zero;
    for (var t = 1; t <= n; t++) {
      coupons = coupons + c / g.pow(t);
      simple = simple + flows[t - 1].amount / (Frac.one + y * Frac(t));
    }
    final facePv = face / g.pow(n);
    final price = coupons + facePv;
    return _Draft(
      scene: BondScene(
        visual: BondVisual.timeline,
        chips: [
          'Coupon ${cash(c)} a year',
          'Face ${cash(face)}',
          'Yield ${pct(y)}',
        ],
        caption: 'What it pays, year by year',
        years: n,
        flows: flows,
        unknownAt: 0,
      ),
      question: 'What should this bond cost today?',
      hint:
          'Divide each payment by ${decimal(g)} once for every year you '
          'wait.',
      value: price,
      unit: BondUnit.money,
      step: _moneyStep(price),
      traps: [
        _t(
          face,
          'Discounting at the $cp% coupon rate gives the face value. Use '
          'the ${pct(y)} yield.',
        ),
        _t(
          coupons,
          'That forgets the ${cash(face)} face value paid back at the '
          'end.',
        ),
        _t(
          price - c / g.pow(n),
          'The last year pays the coupon as well as the face value.',
        ),
        _t(
          c * Frac(n) + face,
          'That adds up the payments without discounting them.',
        ),
        _t(
          (c * Frac(n) + face) / g.pow(n),
          'That discounts every payment ${_years(n)}; earlier coupons '
          'wait less.',
        ),
        _t(
          simple,
          'That\'s simple discounting. Compound it: divide by '
          '${decimal(g)} once per year.',
        ),
      ],
      steps: [
        'Coupons today: each ÷ ${decimal(g)} per year waited, '
            '${cash(coupons)} in all.',
        'Face today: ${cash(face)} ÷ ${_g(g, n)} = ${cash(facePv)}.',
        'Price: ${cash(coupons)} + ${cash(facePv)} = {A}.',
      ],
      insight: 'Right: a bond is worth its payments, each discounted.',
      params: {'c': c, 'face': face, 'y': y, 'n': Frac(n)},
    );
  }

  /// Word answers: premium, par or discount, and which way prices move.
  _Draft _premium(Random rng) {
    final which = rng.nextInt(5);
    switch (which) {
      case 0:
        // Coupon against yield.
        final cp = 3 + rng.nextInt(6);
        final side = rng.nextInt(5);
        final yp = side == 0
            ? cp
            : side <= 2
            ? cp + 1 + rng.nextInt(3)
            : cp - 1 - rng.nextInt(2);
        const disc = 'Below face: a discount';
        const par = 'At face: par';
        const prem = 'Above face: a premium';
        const depends = 'It depends on the maturity';
        final face = Frac(100);
        final String ans;
        final List<BondTrap> traps;
        final List<String> steps;
        if (yp > cp) {
          ans = disc;
          traps = [
            BondTrap(
              prem,
              'A premium needs a coupon above the yield; this coupon is '
              'below it.',
            ),
            BondTrap(par, 'Par needs the coupon to equal the yield.'),
            BondTrap(
              depends,
              'Maturity changes how far from face, not which side.',
            ),
          ];
          steps = [
            'The coupon pays $cp% a year; buyers want $yp%.',
            'To earn more than the coupon, they pay less than face.',
            'So it trades below face: a discount.',
          ];
        } else if (yp < cp) {
          ans = prem;
          traps = [
            BondTrap(
              disc,
              'A discount needs a coupon below the yield; this coupon is '
              'above it.',
            ),
            BondTrap(par, 'Par needs the coupon to equal the yield.'),
            BondTrap(
              depends,
              'Maturity changes how far from face, not which side.',
            ),
          ];
          steps = [
            'The coupon pays $cp% a year; buyers only need $yp%.',
            'They\'ll pay more than face for the richer coupon.',
            'So it trades above face: a premium.',
          ];
        } else {
          ans = par;
          traps = [
            BondTrap(
              disc,
              'Coupon and yield are equal, so the payments discount back '
              'to exactly face.',
            ),
            BondTrap(
              prem,
              'Coupon and yield are equal, so the payments discount back '
              'to exactly face.',
            ),
            BondTrap(
              depends,
              'With the coupon equal to the yield, it\'s par at any '
              'maturity.',
            ),
          ];
          steps = [
            'The coupon pays exactly the $cp% buyers want.',
            'Discounting at the coupon rate gives back the face value.',
            'So it trades at face: par.',
          ];
        }
        return _Draft(
          scene: BondScene(
            visual: BondVisual.timeline,
            chips: ['Coupon \$$cp', 'Face \$100', 'Yield $yp%'],
            caption: 'What it pays, year by year',
            years: 3,
            flows: _bondFlows(Frac(cp), face, 3),
            unknownAt: 0,
          ),
          question:
              'The coupon is $cp% of face and the market wants a $yp% '
              'yield. Where does the bond trade?',
          hint: 'Compare the coupon with the yield the market wants.',
          answer: ans,
          traps: traps,
          steps: steps,
          insight:
              'Right: coupon below the yield means a discount; above, a '
              'premium.',
          params: {'which': Frac(which), 'cp': Frac(cp), 'yp': Frac(yp)},
        );
      case 1:
        // Which way the price moves.
        final a = 3 + rng.nextInt(5);
        final up = rng.nextBool();
        final b = up ? a + 1 : a - 1;
        const falls = 'It falls', rises = 'It rises';
        return _Draft(
          scene: BondScene(
            visual: BondVisual.none,
            chips: ['Fixed coupons', 'Yield $a% → $b%'],
            caption: '',
          ),
          question:
              'Yields ${up ? 'rise' : 'fall'} from $a% to $b%. What '
              'happens to a bond\'s price?',
          hint: 'Price is the payments discounted at the yield.',
          answer: up ? falls : rises,
          traps: [
            BondTrap(
              up ? rises : falls,
              up
                  ? 'Wrong way: the payments are fixed, so a higher yield '
                        'makes them worth less today.'
                  : 'Wrong way: a lower yield makes the same fixed '
                        'payments worth more today.',
            ),
            const BondTrap(
              'It stays the same',
              'The payments are fixed, but what they\'re worth today '
                  'depends on the yield.',
            ),
            const BondTrap(
              'Its coupon changes instead',
              'A fixed coupon never changes; the price does the '
                  'adjusting.',
            ),
          ],
          steps: [
            'A bond\'s payments are fixed.',
            'A ${up ? 'higher' : 'lower'} yield discounts them '
                '${up ? 'more' : 'less'} heavily.',
            'So the price ${up ? 'falls' : 'rises'}.',
          ],
          insight: 'Right: bond prices move the opposite way to yields.',
          params: {'which': Frac(which), 'up': Frac(up ? 1 : 0)},
        );
      case 2:
        // The price says which side of the coupon the yield is.
        final cp = 4 + rng.nextInt(5);
        final price = Frac(_pick(rng, [92, 95, 97, 103, 105, 108]));
        final below = price < Frac(100);
        final above = 'Above $cp%', under = 'Below $cp%';
        return _Draft(
          scene: BondScene(
            visual: BondVisual.timeline,
            chips: ['Coupon \$$cp', 'Face \$100', 'Price ${cash(price)}'],
            caption: 'What it pays, year by year',
            years: 3,
            flows: [
              CashFlow(0, price, paid: true),
              ..._bondFlows(Frac(cp), Frac(100), 3),
            ],
          ),
          question:
              'A bond with a $cp% coupon costs ${cash(price)} for \$100 of '
              'face. Its yield is…',
          hint: 'Buying below face adds a gain; above face, a loss.',
          answer: below ? above : under,
          traps: [
            BondTrap(
              below ? under : above,
              below
                  ? 'A yield below the coupon would push the price above '
                        'face.'
                  : 'A yield above the coupon would pull the price below '
                        'face.',
            ),
            BondTrap(
              'Exactly $cp%',
              'Only a bond priced at exactly \$100 yields its coupon.',
            ),
            const BondTrap(
              'Can\'t tell without maturity',
              'Maturity sets how far the yield is from the coupon, not '
                  'which side.',
            ),
          ],
          steps: below
              ? [
                  'It costs less than the \$100 it pays back.',
                  'So you earn the coupon plus that gain.',
                  'Its yield is above the $cp% coupon.',
                ]
              : [
                  'It costs more than the \$100 it pays back.',
                  'That loss eats into the coupon.',
                  'Its yield is below the $cp% coupon.',
                ],
          insight:
              'Right: a discount bond yields more than its coupon; a '
              'premium bond, less.',
          params: {'which': Frac(which), 'cp': Frac(cp), 'price': price},
        );
      case 3:
        // Which price moves most.
        final n = _pick(rng, [10, 20, 30]);
        final up = rng.nextBool();
        return _Draft(
          scene: BondScene(
            visual: BondVisual.none,
            chips: ['Yields ${up ? '+' : '−'}1 point', 'Same yield for all'],
            caption: '',
          ),
          question:
              'Yields ${up ? 'rise' : 'fall'} 1 point. Whose price '
              '${up ? 'falls' : 'rises'} the most?',
          hint: 'The longer you wait for the money, the more rates matter.',
          answer: 'A $n-year zero',
          traps: [
            BondTrap(
              'A $n-year bond, 8% coupon',
              'Its coupons pay back sooner, so its duration is shorter '
                  'than $n years.',
            ),
            const BondTrap(
              'A 2-year zero',
              'A short bond\'s price barely moves.',
            ),
            const BondTrap(
              'A 1-year bond, 8% coupon',
              'Money back within a year hardly moves with rates.',
            ),
          ],
          steps: [
            'Price moves with duration: the average wait for the money.',
            'A zero\'s duration is its maturity; coupons shorten it.',
            'Longest wait: the $n-year zero.',
          ],
          insight: 'Right: the longest duration moves the most.',
          params: {'which': Frac(which), 'n': Frac(n)},
        );
      default:
        // Pull to par.
        final price = Frac(_pick(rng, [92, 95, 105, 108, 110]));
        final prem = price > Frac(100);
        final p = cash(price);
        return _Draft(
          scene: BondScene(
            visual: BondVisual.timeline,
            chips: ['Face \$100', 'Price $p', '3 years'],
            caption: 'What it pays, year by year',
            years: 3,
            flows: [
              CashFlow(0, price, paid: true),
              ..._bondFlows(Frac(prem ? 7 : 3), Frac(100), 3),
            ],
          ),
          question:
              'Yields don\'t change. As the bond nears maturity, its '
              'price…',
          hint: 'What is it worth on the day it pays back the face?',
          answer: prem ? 'Drifts down to \$100' : 'Rises to \$100',
          traps: [
            BondTrap(
              'Stays at $p',
              'At maturity it pays exactly \$100, so the gap to face must '
                  'close.',
            ),
            BondTrap(
              prem ? 'Rises above $p' : 'Falls below $p',
              'It\'s heading for the \$100 it pays at the end, not away '
              'from it.',
            ),
            const BondTrap(
              'Falls to zero',
              'It pays \$100 at the end, so that\'s where its price ends.',
            ),
          ],
          steps: [
            'At maturity the bond is worth exactly its \$100 face.',
            'With yields unchanged, the price moves steadily toward it.',
            prem ? 'So it drifts down to \$100.' : 'So it rises to \$100.',
          ],
          insight: 'Right: a bond\'s price is pulled to face as it matures.',
          params: {'which': Frac(which), 'price': price},
        );
    }
  }

  /// The yield of a zero from its price.
  _Draft _zeroYield(Random rng) {
    Frac r, p, f;
    int n;
    do {
      r = _rate(_pick(rng, [4, 5, 8, 10, 20, 25]));
      n = 2 + rng.nextInt(2);
      p = Frac(_pick(rng, [100, 200, 400, 500, 800, 1000]));
      f = p * (Frac.one + r).pow(n);
    } while (!exactCents(f));
    final g = Frac.one + r;
    final growth = f / p;
    final hundred = Frac(100);
    return _Draft(
      scene: BondScene(
        visual: BondVisual.timeline,
        chips: ['Zero coupon', 'Price ${cash(p)}', 'Face ${cash(f)}'],
        caption: 'What it pays, year by year',
        years: n,
        flows: [CashFlow(0, p, paid: true), CashFlow(n, f)],
        spanFrom: 0,
        spanTo: n,
      ),
      question:
          'A zero-coupon bond costs ${cash(p)} and pays ${cash(f)} in '
          '${_years(n)}. What yield is that, per year?',
      hint: 'Find the yearly rate that grows ${cash(p)} to ${cash(f)}.',
      value: r * hundred,
      unit: BondUnit.percent,
      step: Frac.one,
      traps: [
        _t(
          (growth - Frac.one) * hundred / Frac(n),
          'That splits the growth evenly over the years; with compounding, '
          'less a year does it.',
        ),
        _t(
          (growth - Frac.one) * hundred,
          'That\'s the growth over all ${_years(n)}, not per year.',
        ),
        _t(
          (growth - Frac.one) * hundred / Frac(n + 1),
          'That spreads the growth over ${n + 1} years. From today to year '
          '$n is ${_years(n)}.',
        ),
        if (n > 2)
          _t(
            (growth - Frac.one) * hundred / Frac(n - 1),
            'That spreads the growth over ${_years(n - 1)}; it has '
            '${_years(n)} to grow.',
          ),
        _t(
          (Frac.one - p / f) * hundred,
          'That\'s how far below face the price is, not a yearly rate.',
        ),
        _t(
          r / g * hundred,
          'That\'s the share each year takes off the later value. Yield '
          'is growth from the price.',
        ),
      ],
      steps: [
        'It grows ${cash(f)} ÷ ${cash(p)} = ${decimal(growth)} times.',
        'Over ${_years(n)}: ${_g(g, n)} = ${decimal(growth)}.',
        'So it grows ${decimal(g)} times a year: {A}.',
      ],
      insight: 'Right: the yield is the yearly rate that compounds to it.',
      params: {'p': p, 'f': f, 'n': Frac(n)},
    );
  }

  /// A one-year forward rate from two zero prices.
  _Draft _forward(Random rng) {
    Frac p1, p2, r;
    do {
      p2 = Frac(_pick(rng, [60, 64, 70, 72, 75, 80, 81, 84, 85, 90]));
      r = _rate(_pick(rng, [4, 5, 8, 10, 20, 25]));
      p1 = p2 * (Frac.one + r);
    } while (p1 >= Frac(96) || !exactCents(p1));
    final hundred = Frac(100);
    final two = hundred / p2 - Frac.one;
    return _Draft(
      scene: BondScene(
        visual: BondVisual.timeline,
        chips: [
          '1-year zero ${cash(p1)}',
          '2-year zero ${cash(p2)}',
          'Each pays \$100',
        ],
        caption: 'Forward rate: year 2, locked in today',
        years: 2,
        spanFrom: 1,
        spanTo: 2,
      ),
      question:
          'What one-year rate do these prices lock in for year 2? That\'s '
          'the forward rate.',
      hint: 'Year 2 alone takes the price from ${cash(p1)} to ${cash(p2)}.',
      value: r * hundred,
      unit: BondUnit.percent,
      step: Frac.one,
      traps: [
        _t(
          (hundred / p1 - Frac.one) * hundred,
          'That\'s the rate for year 1. The forward rate is for year 2 '
          'alone.',
        ),
        _t(two * hundred, 'That\'s the growth over both years together.'),
        _t(
          two * hundred / Frac(2),
          'Half the two-year growth averages both years; this asks for '
          'year 2 alone.',
        ),
        _t(
          p1 - p2,
          'That measures the gap against the \$100 face; divide it by the '
          '2-year price.',
        ),
        _t(
          (p1 - p2) / p1 * hundred,
          'That divides by the 1-year price; the growth starts from the '
          '2-year price.',
        ),
        _t(
          hundred - p1,
          'That\'s how far the 1-year zero sits below face, not the rate '
          'for year 2.',
        ),
        _t(
          hundred - p2,
          'That\'s how far the 2-year zero sits below face, over both '
          'years.',
        ),
      ],
      steps: [
        'Both pay \$100. One more year of waiting cuts ${cash(p1)} to '
            '${cash(p2)}.',
        '1 + forward = ${cash(p1)} ÷ ${cash(p2)} = '
            '${decimal(p1 / p2)}.',
        'Forward rate: {A}.',
      ],
      insight: 'Right: 1 + forward = the 1-year price ÷ the 2-year price.',
      params: {'p1': p1, 'p2': p2},
    );
  }

  /// Macaulay duration: the years, weighted by today's values.
  _Draft _macaulay(Random rng) {
    final c = Frac(_pick(rng, [5, 10, 15, 20, 25, 30, 40, 50]));
    final face = Frac(100);
    final n = 2 + rng.nextInt(2);
    final y = _rate(25);
    final g = Frac.one + y;
    final flows = _bondFlows(c, face, n);
    final today = [for (final f in flows) f.amount / g.pow(f.year)];
    final price = today.reduce((a, b) => a + b);
    var weighted = Frac.zero, byCash = Frac.zero, cash0 = Frac.zero;
    for (final (i, f) in flows.indexed) {
      weighted = weighted + Frac(f.year) * today[i];
      byCash = byCash + Frac(f.year) * f.amount;
      cash0 = cash0 + f.amount;
    }
    final d = weighted / price;
    String plain(Frac v) => cash(v).replaceAll('\$', '');
    return _Draft(
      scene: BondScene(
        visual: BondVisual.timeline,
        chips: ['Coupon ${cash(c)} a year', 'Face ${cash(face)}', 'Yield 25%'],
        caption: 'Payments, and their value now',
        years: n,
        flows: [
          for (final (i, f) in flows.indexed)
            CashFlow(f.year, f.amount, today: today[i]),
        ],
      ),
      question: 'What\'s this bond\'s Macaulay duration?',
      hint: 'Average the years, weighting each by its payment\'s value now.',
      value: d,
      unit: BondUnit.years,
      step: Frac(1, 10),
      traps: [
        _t(
          d / g,
          'That\'s modified duration: Macaulay ÷ 1.25. This asks for '
          'Macaulay.',
        ),
        _t(
          byCash / cash0,
          'That weights by the payments themselves; weight by what each '
          'is worth today.',
        ),
        _t(
          Frac(n),
          'Only a zero\'s duration equals its maturity; coupons pull it '
          'earlier.',
        ),
        _t(
          Frac(n + 1, 2),
          'That weights every year the same; the face value makes the '
          'last year count most.',
        ),
        _t(
          d * g,
          'Nothing to multiply by 1.25: Macaulay is just the weighted '
          'average of the years.',
        ),
      ],
      steps: [
        'Worth now: ${_list([for (final v in today) cash(v)])}; '
            '${cash(price)} in all.',
        'Weight each year: (${[for (final (i, v) in today.indexed) '${i + 1} × ${plain(v)}'].join(' + ')}) '
            '÷ ${plain(price)}.',
        'That\'s {A}.',
      ],
      insight:
          'Right: duration is the average wait, weighted by value '
          'today.',
      params: {'c': c, 'face': face, 'y': y, 'n': Frac(n)},
    );
  }

  /// Price change from modified duration.
  _Draft _priceMove(Random rng) {
    late Frac price, dMod, move, change;
    Frac? dMac, y;
    late bool askNew;
    do {
      price = Frac(_pick(rng, [80, 90, 95, 96, 98, 102, 104, 105, 110, 120]));
      move =
          Frac(_pick(rng, [25, 50, 100, 200]), 100) *
          Frac(rng.nextBool() ? 1 : -1);
      askNew = rng.nextInt(5) < 2;
      if (rng.nextBool()) {
        final (m, yp) = _pick(rng, const [
          (21, 5),
          (42, 5),
          (63, 5),
          (22, 10),
          (44, 10),
          (55, 10),
          (33, 10),
          (25, 25),
          (50, 25),
          (52, 4),
          (27, 8),
          (54, 8),
        ]);
        dMac = Frac(m, 10);
        y = _rate(yp);
        dMod = dMac / (Frac.one + y);
      } else {
        dMac = null;
        y = null;
        dMod = _pick(rng, [
          Frac(2),
          Frac(3),
          Frac(4),
          Frac(5),
          Frac(6),
          Frac(8),
          Frac(5, 2),
          Frac(9, 2),
          Frac(7),
        ]);
      }
      change = Frac.zero - dMod * move / Frac(100) * price;
    } while (!exactCents(change));
    final mac = dMac;
    final yy = y ?? Frac.zero;
    final up = move > Frac.zero;
    final size = up ? move : Frac.zero - move;
    final pts = '${decimal(size)} point${size > Frac.one ? 's' : ''}';
    final base = askNew ? price : Frac.zero;
    final unitMove = Frac.zero - dMod * Frac(up ? 1 : -1) / Frac(100) * price;
    return _Draft(
      scene: BondScene(
        visual: BondVisual.curve,
        chips: [
          'Price ${cash(price)}',
          if (mac != null) ...[
            'Macaulay duration ${decimal(mac)}',
            'Yield ${pct(yy)}',
          ] else
            'Modified duration ${decimal(dMod)}',
          'Yields ${up ? 'up' : 'down'} $pts',
        ],
        caption: 'Price against yield',
        price: price,
        yieldUp: up,
        moveLabel: '${up ? '+' : '−'}${decimal(size)} pt',
      ),
      question: askNew
          ? 'Roughly what\'s the new price?'
          : 'Roughly how much does the price change?',
      hint: mac != null
          ? 'Modified duration = Macaulay ÷ (1 + yield).'
          : 'Change ≈ − modified duration × yield change × price.',
      value: base + change,
      unit: askNew ? BondUnit.money : BondUnit.change,
      step: change.value.abs() >= 8
          ? Frac.one
          : change.value.abs() >= 4
          ? Frac(1, 2)
          : Frac(1, 4),
      traps: [
        _t(
          base - change,
          up
              ? 'Wrong way: when yields rise, bond prices fall.'
              : 'Wrong way: when yields fall, bond prices rise.',
        ),
        if (mac != null) ...[
          _t(
            base - mac * move / Frac(100) * price,
            'That uses Macaulay duration. Divide it by '
            '${decimal(Frac.one + yy)} first to get modified duration.',
          ),
          _t(
            base - mac * (Frac.one + yy) * move / Frac(100) * price,
            'Modified duration divides Macaulay by 1 + yield; it doesn\'t '
            'multiply.',
          ),
        ],
        _t(
          base - dMod * move,
          'That\'s the change for a \$100 price; this bond costs '
          '${cash(price)}.',
        ),
        if (size != Frac.one)
          _t(base + unitMove, 'That\'s for a 1-point move; this one is $pts.'),
      ],
      steps: [
        if (mac != null)
          'Modified duration: ${decimal(mac)} ÷ '
              '${decimal(Frac.one + yy)} = ${decimal(dMod)}.'
        else
          '$pts is ${decimal(size / Frac(100))} as a decimal.',
        'Change ≈ −${decimal(dMod)} × ${decimal(move / Frac(100))} × '
            '${cash(price)} = ${cash(change)}.',
        askNew
            ? 'New price: ${cash(price)} ${up ? '−' : '+'} '
                  '${cash(up ? Frac.zero - change : change)} = {A}.'
            : 'So the price ${up ? 'falls' : 'rises'}: {A}.',
      ],
      insight:
          'Right: price moves about − modified duration × the yield '
          'change.',
      params: {
        'price': price,
        'dMod': dMod,
        'dMac': mac ?? Frac.zero,
        'y': yy,
        'move': move,
        'askNew': Frac(askNew ? 1 : 0),
      },
    );
  }

  /// A zero's duration is its maturity.
  _Draft _zeroDuration(Random rng) {
    final (n, yp) = _pick(rng, const [
      (21, 5),
      (11, 10),
      (22, 10),
      (26, 4),
      (27, 8),
      (5, 25),
      (10, 25),
      (15, 25),
      (6, 20),
      (12, 20),
    ]);
    final y = _rate(yp);
    final g = Frac.one + y;
    final modified = rng.nextBool();
    final mac = Frac(n);
    final mod = mac / g;
    return _Draft(
      scene: BondScene(
        visual: BondVisual.timeline,
        chips: ['Zero coupon', 'Matures in $n years', 'Yield ${pct(y)}'],
        caption: 'What it pays, year by year',
        years: n,
        flows: [CashFlow(n, Frac(100))],
      ),
      question: modified
          ? 'What\'s its modified duration?'
          : 'What\'s its Macaulay duration?',
      hint: modified
          ? 'Modified duration = Macaulay ÷ (1 + yield).'
          : 'Duration is the average wait for the money, by value.',
      value: modified ? mod : mac,
      unit: BondUnit.years,
      step: modified ? Frac(1, 2) : Frac.one,
      traps: modified
          ? [
              _t(
                mac,
                'That\'s Macaulay duration. Modified divides it by '
                '${decimal(g)}.',
              ),
              _t(
                mac * g,
                'Modified duration divides by 1 + yield; it doesn\'t '
                'multiply.',
              ),
              _t(
                mac * (Frac.one - y),
                'Taking ${pct(y)} off isn\'t the same as dividing by '
                '${decimal(g)}.',
              ),
              _t(
                Frac(n + 1, 2) / g,
                'That averages the years, but a zero pays only at the end.',
              ),
            ]
          : [
              _t(
                mod,
                'That\'s modified duration (÷ ${decimal(g)}). Macaulay for '
                'a zero is its maturity.',
              ),
              _t(
                Frac(n + 1, 2),
                'That averages the years, but a zero pays only at the end.',
              ),
              _t(
                Frac(n, 2),
                'Half the life fits money paid evenly; a zero pays it all '
                'at the end.',
              ),
              _t(
                mac * g,
                'Nothing to multiply: one payment at year $n means an '
                'average wait of $n.',
              ),
            ],
      steps: modified
          ? [
              'A zero\'s Macaulay duration is its maturity: $n years.',
              'Modified = Macaulay ÷ (1 + yield) = $n ÷ ${decimal(g)}.',
              'That\'s {A}.',
            ]
          : [
              'A zero makes one payment, at year $n.',
              'All of its value waits $n years.',
              'So its Macaulay duration is {A}.',
            ],
      insight: modified
          ? 'Right: modified is Macaulay ÷ (1 + yield).'
          : 'Right: a zero\'s duration is its maturity.',
      params: {'n': mac, 'y': y, 'modified': Frac(modified ? 1 : 0)},
    );
  }

  /// A portfolio's duration: the value-weighted average.
  _Draft _portfolio(Random rng) {
    late Frac va, vb, da, db, fa, fb, d, byFace;
    do {
      final total = _pick(rng, [400, 500, 800, 1000]);
      final step = total ~/ 10;
      final a = step * (2 + rng.nextInt(7));
      va = Frac(a);
      vb = Frac(total - a);
      da = Frac(_pick(rng, [1, 2, 3, 4, 5, 6, 8, 10]));
      db = Frac(_pick(rng, [1, 2, 3, 4, 5, 6, 8, 10]));
      // Price per $100 of face.
      final pa = Frac(_pick(rng, [50, 80, 100, 125]), 100);
      final pb = Frac(_pick(rng, [50, 80, 100, 125]), 100);
      fa = va / pa;
      fb = vb / pb;
      d = (va * da + vb * db) / (va + vb);
      byFace = (fa * da + fb * db) / (fa + fb);
    } while (da == db || byFace == d || va == vb || !exactCents(byFace));
    final shareA = va / (va + vb), shareB = vb / (va + vb);
    return _Draft(
      scene: BondScene(
        visual: BondVisual.portfolio,
        chips: [
          'A: worth ${cash(va)}, face ${cash(fa)}',
          'B: worth ${cash(vb)}, face ${cash(fb)}',
        ],
        caption: 'Each bond\'s duration, in years',
        holdings: [Holding('A', va, fa, da), Holding('B', vb, fb, db)],
      ),
      question: 'What\'s the duration of the two bonds together?',
      hint: 'Weight each bond\'s duration by its share of the money.',
      value: d,
      unit: BondUnit.years,
      step: Frac(1, 5),
      traps: [
        _t(
          byFace,
          'That weights by face value; weight by what each bond is worth '
          'today.',
        ),
        _t(
          (da + db) / Frac(2),
          'That weights both bonds the same; weight by the money in each.',
        ),
        _t(
          (vb * da + va * db) / (va + vb),
          'That swaps the weights: more money sits in bond '
          '${va > vb ? 'A' : 'B'}.',
        ),
        _t(da + db, 'Durations don\'t add up; the mix\'s is an average.'),
      ],
      steps: [
        'Shares of the money: A ${decimal(shareA)}, B ${decimal(shareB)}.',
        'Weighted: ${decimal(shareA)} × ${decimal(da)} + '
            '${decimal(shareB)} × ${decimal(db)}.',
        'That\'s {A}.',
      ],
      insight:
          'Right: a portfolio\'s duration is the value-weighted '
          'average.',
      params: {'va': va, 'vb': vb, 'da': da, 'db': db, 'fa': fa, 'fb': fb},
    );
  }
}

class _Draft {
  _Draft({
    required this.scene,
    required this.question,
    required this.hint,
    required this.traps,
    required this.steps,
    required this.insight,
    required this.params,
    this.value,
    this.answer,
    this.unit = BondUnit.money,
    Frac? step,
  }) : step = step ?? Frac.one;

  final BondScene scene;
  final String question;
  final String hint;
  final Frac? value;

  /// Word questions only.
  final String? answer;
  final BondUnit unit;
  final List<BondTrap> traps;

  /// May hold "{A}": the answer as its option reads.
  final List<String> steps;
  final String insight;
  final Map<String, Frac> params;

  /// The step for plain near misses.
  final Frac step;
}
