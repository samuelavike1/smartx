import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../better_bet/bet_puzzle.dart' show money;
import '../odds_on/odds_math.dart';

enum OptType { call, put }

/// One option in a position.
@immutable
class Leg {
  const Leg({
    required this.type,
    required this.strike,
    this.long = true,
    this.premium,
  });

  final OptType type;
  final Frac strike;
  final bool long;

  /// What it cost (long) or brought in (short); null when not given.
  final Frac? premium;

  String get name =>
      '${long ? 'Long' : 'Short'} 1 ${type == OptType.call ? 'call' : 'put'}';

  /// What it pays at expiry with the stock at [s], from the holder's side.
  Frac payoff(Frac s) {
    final raw = type == OptType.call ? s - strike : strike - s;
    final pay = raw > Frac.zero ? raw : Frac.zero;
    return long ? pay : Frac.zero - pay;
  }

  /// Payoff less the premium paid (or plus the premium collected).
  Frac profit(Frac s) {
    final p = premium ?? Frac.zero;
    return long ? payoff(s) - p : payoff(s) + p;
  }
}

enum DeskKind {
  payoff,
  profit,
  short,
  breakeven,
  straddle,
  spread,
  parity,
  binomial,
  hedge,
  deltaGamma,
  theta,
  vega,
  concept,
}

enum DeskVisual { chart, tree, quote, none }

/// The card above the question.
@immutable
class DeskScene {
  const DeskScene({
    required this.visual,
    required this.chips,
    this.legs = const [],
    this.stock,
    this.showProfit = false,
    this.s0,
    this.up,
    this.down,
    this.payUp,
    this.payDown,
    this.caption = '',
  });

  final DeskVisual visual;
  final List<String> chips;

  /// Chart: the position, the stock at expiry, payoff or profit.
  final List<Leg> legs;
  final Frac? stock;
  final bool showProfit;

  /// Tree: today's price, the two prices at expiry, what the option pays.
  final Frac? s0, up, down, payUp, payDown;
  final String caption;

  Frac value(Frac s) => legs.fold(
    Frac.zero,
    (t, l) => t + (showProfit ? l.profit(s) : l.payoff(s)),
  );
}

/// A wrong answer and the slip behind it.
@immutable
class DeskTrap {
  const DeskTrap(this.label, this.why, [this.value]);

  final String label;
  final String why;

  /// For numeric answers: used to order the options.
  final Frac? value;
}

@immutable
class DeskQuestion {
  const DeskQuestion({
    required this.level,
    required this.seed,
    required this.kind,
    required this.scene,
    required this.question,
    required this.hint,
    required this.answer,
    required this.traps,
    required this.options,
    required this.steps,
    required this.insight,
    required this.params,
    this.answerValue,
  });

  final int level;
  final int seed;
  final DeskKind kind;
  final DeskScene scene;
  final String question;
  final String hint;
  final String answer;
  final Frac? answerValue;
  final List<DeskTrap> traps;
  final List<String> options;
  final List<String> steps;
  final String insight;

  /// The numbers behind the question, for recomputing in tests.
  final Map<String, Frac> params;

  int get answerIndex => options.indexOf(answer);

  String feedbackFor(String picked) => picked == answer
      ? insight
      : traps.firstWhere((t) => t.label == picked).why;
}

/// A plain number to two places: "0.60", "1.25", "−0.40".
String dec(Frac f) {
  final s = f.value.abs().toStringAsFixed(2);
  return f.value < 0 ? '−$s' : s;
}

/// A share count or ratio: "1/2" style when it isn't a tidy decimal.
String ratio(Frac f) {
  if (f.d == 1) return '${f.n}';
  if (100 % f.d == 0) {
    var s = (f.value).toStringAsFixed(2);
    if (s.endsWith('0')) s = s.substring(0, s.length - 1);
    return s;
  }
  return '$f';
}

class DeskDifficulty {
  static List<DeskKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [DeskKind.payoff],
    2 => const [DeskKind.profit],
    3 => const [DeskKind.short, DeskKind.payoff],
    4 => const [DeskKind.breakeven],
    5 => const [DeskKind.straddle, DeskKind.spread],
    6 => const [DeskKind.parity],
    7 => const [DeskKind.binomial],
    8 => const [DeskKind.hedge, DeskKind.binomial],
    9 => const [DeskKind.deltaGamma, DeskKind.theta, DeskKind.vega],
    _ => const [
      DeskKind.spread,
      DeskKind.parity,
      DeskKind.binomial,
      DeskKind.hedge,
      DeskKind.deltaGamma,
      DeskKind.concept,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'what an option pays',
    2 => 'profit after the premium',
    3 => 'selling options; puts',
    4 => 'break-even prices',
    5 => 'straddles and spreads',
    6 => 'put–call parity',
    7 => 'pricing on a tree',
    8 => 'the hedge ratio',
    9 => 'delta, gamma, theta, vega',
    _ => 'the whole desk',
  };
}

class DeskGenerator {
  const DeskGenerator();

  static const _again = 'Check the numbers again: see the working.';

  DeskQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = DeskDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final draft = switch (kind) {
      DeskKind.payoff => _payoff(rng, level),
      DeskKind.profit => _profit(rng),
      DeskKind.short => _short(rng),
      DeskKind.breakeven => _breakeven(rng),
      DeskKind.straddle => _straddle(rng),
      DeskKind.spread => _spread(rng),
      DeskKind.parity => _parity(rng),
      DeskKind.binomial => _binomial(rng),
      DeskKind.hedge => _hedge(rng),
      DeskKind.deltaGamma => _deltaGamma(rng, level),
      DeskKind.theta => _theta(rng),
      DeskKind.vega => _vega(rng),
      DeskKind.concept => _concept(rng),
    };

    final List<DeskTrap> traps;
    final List<String> options;
    if (draft.value == null) {
      traps = draft.traps.take(3).toList();
      options = [draft.answer, ...traps.map((t) => t.label)]..shuffle(rng);
    } else {
      // Numbers: smallest first, the answer at a random rank, named slips
      // first, then plain near misses.
      final a = draft.value!;
      final unit = draft.unit;
      final fillers = [
        for (final k in [1, 2, 3])
          for (final sign in [1, -1])
            DeskTrap(
              draft.format(a + unit * Frac(sign * k)),
              _again,
              a + unit * Frac(sign * k),
            ),
      ];
      final chosen = balancedOptions(
        DeskTrap(draft.answer, '', a),
        draft.traps,
        fillers,
        rng,
        compare: (x, y) => x.value!.compareTo(y.value!),
      );
      traps = [
        for (final t in chosen)
          if (t.value != a) t,
      ];
      options = [for (final t in chosen) t.label];
    }

    return DeskQuestion(
      level: level,
      seed: seed,
      kind: kind,
      scene: draft.scene,
      question: draft.question,
      hint: draft.hint,
      answer: draft.answer,
      answerValue: draft.value,
      traps: traps,
      options: options,
      steps: draft.steps,
      insight: draft.insight,
      params: draft.params,
    );
  }

  // ---- helpers ------------------------------------------------------------

  static Frac _f(num x) => x is int ? Frac(x) : Frac((x * 100).round(), 100);

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  static DeskTrap _m(Frac v, String why) => DeskTrap(money(v), why, v);

  static List<String> _chips(List<Leg> legs) => [
    for (final l in legs) ...[
      l.name,
      'Strike ${money(l.strike)}',
      if (l.premium != null) '${l.long ? 'Paid' : 'Got'} ${money(l.premium!)}',
    ],
  ];

  // ---- kinds --------------------------------------------------------------

  _Draft _payoff(Random rng, int level) {
    final type = level >= 3 && rng.nextBool() ? OptType.put : OptType.call;
    final k = _f(_pick(rng, [40, 50, 60, 80, 100]));
    // In the money about 70% of the time.
    final itm = rng.nextInt(10) < 7;
    final d = _f(1 + rng.nextInt(12));
    final s = type == OptType.call
        ? (itm ? k + d : k - d)
        : (itm ? k - d : k + d);
    final leg = Leg(type: type, strike: k);
    final ans = leg.payoff(s);
    final other = Leg(
      type: type == OptType.call ? OptType.put : OptType.call,
      strike: k,
    ).payoff(s);
    final raw = type == OptType.call ? s - k : k - s;
    final call = type == OptType.call;
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.chart,
        chips: _chips([leg]),
        legs: [leg],
        stock: s,
        caption: 'Payoff at expiry',
      ),
      question:
          'At expiry the stock is ${money(s)}. What does the '
          '${call ? 'call' : 'put'} pay?',
      hint: call
          ? 'A call pays the amount above the strike.'
          : 'A put pays the amount below the strike.',
      value: ans,
      traps: [
        _m(
          other,
          call
              ? '${money(other)} is a put\'s payoff: puts pay when the stock '
                    'ends below the strike.'
              : '${money(other)} is a call\'s payoff: calls pay when the '
                    'stock ends above the strike.',
        ),
        if (raw < Frac.zero)
          _m(
            raw,
            '${money(raw)} would be a loss, but you\'d simply not use the '
            'option: a long option never pays less than zero.',
          ),
        _m(
          s,
          '${money(s)} is the stock price. The option pays only the part '
          '${call ? 'above' : 'below'} the strike.',
        ),
        _m(k, '${money(k)} is the strike, not what the option pays.'),
      ],
      steps: [
        call
            ? 'A call pays the stock minus the strike, if that\'s positive.'
            : 'A put pays the strike minus the stock, if that\'s positive.',
        call
            ? '${money(s)} − ${money(k)} = ${money(raw)}.'
            : '${money(k)} − ${money(s)} = ${money(raw)}.',
        raw > Frac.zero
            ? 'So it pays ${money(ans)}.'
            : 'That\'s below zero, so you don\'t use it: it pays \$0.',
      ],
      insight:
          'Right: an option pays the part beyond the strike, or '
          'nothing.',
      params: {'k': k, 's': s, 'call': Frac(call ? 1 : 0)},
    );
  }

  _Draft _profit(Random rng) {
    final type = rng.nextInt(3) == 0 ? OptType.put : OptType.call;
    final call = type == OptType.call;
    final k = _f(_pick(rng, [40, 50, 60, 80]));
    final p = _f(_pick(rng, [2, 3, 4, 5, 2.5, 3.5]));
    final d = _f(rng.nextInt(14) - 3);
    final s = call ? k + d : k - d;
    final leg = Leg(type: type, strike: k, premium: p);
    final pay = leg.payoff(s);
    final ans = leg.profit(s);
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.chart,
        chips: _chips([leg]),
        legs: [leg],
        stock: s,
        showProfit: true,
        caption: 'Profit at expiry',
      ),
      question: 'At expiry the stock is ${money(s)}. What\'s your profit?',
      hint: 'Payoff at expiry, minus what you paid.',
      value: ans,
      traps: [
        _m(
          pay,
          '${money(pay)} is the payoff; it forgets the ${money(p)} '
          'you paid.',
        ),
        _m(
          pay + p,
          '${money(pay + p)} adds the premium instead of taking '
          'it off.',
        ),
        if (pay > Frac.zero)
          _m(
            Frac.zero - p,
            '${money(Frac.zero - p)} is the loss only if '
            'the option expires worthless.',
          ),
        _m(pay - p - p, 'That takes the premium off twice.'),
        _m(p, '${money(p)} is the premium, not the profit.'),
      ],
      steps: [
        'Payoff at ${money(s)}: ${money(pay)}.',
        'You paid ${money(p)} for it.',
        '${money(pay)} − ${money(p)} = ${money(ans)}.',
      ],
      insight: 'Right: profit is payoff minus what you paid.',
      params: {'k': k, 's': s, 'p': p, 'call': Frac(call ? 1 : 0)},
    );
  }

  _Draft _short(Random rng) {
    final type = rng.nextBool() ? OptType.put : OptType.call;
    final call = type == OptType.call;
    final k = _f(_pick(rng, [40, 50, 60, 80]));
    final p = _f(_pick(rng, [2, 3, 4, 5, 2.5]));
    final d = _f(rng.nextInt(14) - 4);
    final s = call ? k + d : k - d;
    final leg = Leg(type: type, strike: k, long: false, premium: p);
    final owe = Frac.zero - leg.payoff(s);
    final ans = leg.profit(s);
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.chart,
        chips: _chips([leg]),
        legs: [leg],
        stock: s,
        showProfit: true,
        caption: 'Profit at expiry',
      ),
      question:
          'You sold the ${call ? 'call' : 'put'}. At expiry the stock '
          'is ${money(s)}. What\'s your profit?',
      hint: 'You keep the premium, and pay out what the buyer gets.',
      value: ans,
      traps: [
        _m(
          Frac.zero - ans,
          '${money(Frac.zero - ans)} is the buyer\'s '
          'profit; yours is the opposite.',
        ),
        _m(
          p,
          '${money(p)} keeps the premium but forgets what you pay '
          'out.',
        ),
        if (owe > Frac.zero)
          _m(
            Frac.zero - owe,
            '${money(Frac.zero - owe)} pays out but '
            'forgets the ${money(p)} you collected.',
          ),
        _m(ans + p, 'That counts the premium twice.'),
        _m(
          owe + p,
          'That adds what you pay out instead of taking it '
          'off.',
        ),
      ],
      steps: [
        'You collected ${money(p)} when you sold.',
        owe > Frac.zero
            ? 'The buyer uses it: you pay out ${money(owe)}.'
            : 'It expires unused: you pay out nothing.',
        '${money(p)} − ${money(owe)} = ${money(ans)}.',
      ],
      insight:
          'Right: a seller keeps the premium and pays what the buyer '
          'gets.',
      params: {'k': k, 's': s, 'p': p, 'call': Frac(call ? 1 : 0)},
    );
  }

  _Draft _breakeven(Random rng) {
    final type = rng.nextBool() ? OptType.put : OptType.call;
    final call = type == OptType.call;
    final k = _f(_pick(rng, [40, 50, 60, 75, 80, 100]));
    final p = _f(_pick(rng, [2, 3, 4, 5, 6, 2.5, 4.5]));
    final leg = Leg(type: type, strike: k, premium: p);
    final ans = call ? k + p : k - p;
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.chart,
        chips: _chips([leg]),
        legs: [leg],
        showProfit: true,
        caption: 'Profit at expiry',
      ),
      question: 'Where must the stock end for you to break even?',
      hint: 'Where the payoff exactly covers what you paid.',
      value: ans,
      traps: [
        _m(
          k,
          '${money(k)} is the strike; you also need to win back the '
          '${money(p)} you paid.',
        ),
        call
            ? _m(
                k - p,
                '${money(k - p)} is a put\'s break-even. A call '
                'needs the stock higher.',
              )
            : _m(
                k + p,
                '${money(k + p)} is a call\'s break-even. A put '
                'needs the stock lower.',
              ),
        call
            ? _m(k + p + p, 'That wins the premium back twice.')
            : _m(k - p - p, 'That wins the premium back twice.'),
        _m(p, '${money(p)} is the premium, not a stock price.'),
      ],
      steps: [
        call
            ? 'Above the strike, the call pays \$1 for each \$1 the stock '
                  'rises.'
            : 'Below the strike, the put pays \$1 for each \$1 the stock '
                  'falls.',
        'It has to pay back the ${money(p)} premium.',
        call
            ? '${money(k)} + ${money(p)} = ${money(ans)}.'
            : '${money(k)} − ${money(p)} = ${money(ans)}.',
      ],
      insight: 'Right: strike plus (or minus) the premium.',
      params: {'k': k, 'p': p, 'call': Frac(call ? 1 : 0)},
    );
  }

  _Draft _straddle(Random rng) {
    final k = _f(_pick(rng, [50, 60, 80, 100]));
    final c = _f(_pick(rng, [2, 3, 4, 5]));
    final pp = _f(_pick(rng, [2, 3, 4]));
    final d = _f(rng.nextInt(17) - 8);
    final s = k + d;
    final legs = [
      Leg(type: OptType.call, strike: k, premium: c),
      Leg(type: OptType.put, strike: k, premium: pp),
    ];
    final move = d > Frac.zero ? d : Frac.zero - d;
    final ans = move - c - pp;
    final callOnly = legs[0].payoff(s) - c - pp;
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.chart,
        chips: [
          'Long call + put',
          'Strike ${money(k)}',
          'Paid ${money(c)} + ${money(pp)}',
        ],
        legs: legs,
        stock: s,
        showProfit: true,
        caption: 'Straddle: profit at expiry',
      ),
      question:
          'You bought a call and a put at the same strike. At expiry '
          'the stock is ${money(s)}. What\'s your profit?',
      hint: 'One of the two pays; you paid for both.',
      value: ans,
      traps: [
        _m(move, '${money(move)} is the payoff; it forgets both premiums.'),
        _m(
          move - c,
          'That takes off the call\'s premium but forgets the '
          'put\'s.',
        ),
        if (callOnly != ans)
          _m(
            callOnly,
            '${money(callOnly)} only counts the call. The put '
            'pays when the stock falls.',
          ),
        _m(
          Frac.zero - c - pp,
          '${money(Frac.zero - c - pp)} is the loss '
          'only if the stock ends exactly at the strike.',
        ),
        _m(
          move + c + pp,
          'That adds the premiums instead of taking them '
          'off.',
        ),
      ],
      steps: [
        'The stock ended ${money(move)} from the strike, so one option '
            'pays ${money(move)}.',
        'You paid ${money(c)} + ${money(pp)} = ${money(c + pp)}.',
        '${money(move)} − ${money(c + pp)} = ${money(ans)}.',
      ],
      insight:
          'Right: a straddle pays the size of the move, less both '
          'premiums.',
      params: {'k': k, 's': s, 'c': c, 'p': pp},
    );
  }

  _Draft _spread(Random rng) {
    final k1 = _f(_pick(rng, [40, 50, 60]));
    final width = _f(_pick(rng, [5, 10]));
    final k2 = k1 + width;
    final net = _f(_pick(rng, [1, 2, 3, 1.5, 2.5]));
    final d = _f(rng.nextInt(26) - 6);
    final s = k1 + d;
    final legs = [
      Leg(type: OptType.call, strike: k1, premium: net),
      Leg(type: OptType.call, strike: k2, long: false),
    ];
    final pay = legs[0].payoff(s) + legs[1].payoff(s);
    final ans = pay - net;
    final uncapped = legs[0].payoff(s) - net;
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.chart,
        chips: [
          'Long call ${money(k1)}',
          'Short call ${money(k2)}',
          'Net cost ${money(net)}',
        ],
        legs: [
          Leg(type: OptType.call, strike: k1, premium: net),
          legs[1],
        ],
        stock: s,
        showProfit: true,
        caption: 'Call spread: profit at expiry',
      ),
      question:
          'You bought the ${money(k1)} call and sold the ${money(k2)} '
          'call, paying ${money(net)} in all. At expiry the stock is '
          '${money(s)}. What\'s your profit?',
      hint: 'The short call caps what you can make.',
      value: ans,
      traps: [
        _m(
          pay,
          '${money(pay)} is the payoff; it forgets the ${money(net)} '
          'net cost.',
        ),
        if (uncapped != ans)
          _m(
            uncapped,
            '${money(uncapped)} forgets the short call: above '
            '${money(k2)} you pay out what you gain.',
          ),
        _m(
          width - net,
          '${money(width - net)} is the best case, only if '
          'the stock ends above ${money(k2)}.',
        ),
        _m(
          Frac.zero - net,
          '${money(Frac.zero - net)} is the worst case, '
          'only if the stock ends below ${money(k1)}.',
        ),
        _m(pay + net, 'That adds the cost instead of taking it off.'),
      ],
      steps: [
        'The long call pays ${money(legs[0].payoff(s))}; the short call '
            'costs ${money(Frac.zero - legs[1].payoff(s))}.',
        'Payoff ${money(pay)} (never more than ${money(width)}).',
        '${money(pay)} − ${money(net)} = ${money(ans)}.',
      ],
      insight:
          'Right: a spread pays the move between the strikes, less its '
          'cost.',
      params: {'k1': k1, 'k2': k2, 's': s, 'net': net},
    );
  }

  _Draft _parity(Random rng) {
    final k = _f(_pick(rng, [50, 60, 80, 100]));
    final d = _f(rng.nextInt(13) - 6);
    final s = k + d;
    // Make both prices positive: the call is worth at least S − K.
    final c = (d > Frac.zero ? d : Frac.zero) + _f(_pick(rng, [2, 3, 4, 5]));
    final p = c - s + k;
    final askPut = rng.nextBool();
    final ans = askPut ? p : c;
    final given = askPut ? c : p;
    final w = askPut ? 'put' : 'call';
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.quote,
        chips: [
          'Stock ${money(s)}',
          'Strike ${money(k)}',
          '${askPut ? 'Call' : 'Put'} ${money(given)}',
          'Rates 0%',
        ],
        caption: 'Same strike, same expiry',
      ),
      question:
          'A call and a put share a strike and expiry. What should '
          'the $w cost?',
      hint: 'Call − put = stock − strike, when rates are zero.',
      value: ans,
      traps: [
        _m(
          askPut ? c + s - k : p - s + k,
          'That flips the sign of stock − strike.',
        ),
        _m(
          given,
          '${money(given)} assumes the call and put cost the '
          'same; they differ by stock − strike.',
        ),
        _m(
          askPut ? k - s : s - k,
          'That\'s the $w\'s value if exercised today, with no time value.',
        ),
        _m(given + s + k, _again),
      ],
      steps: [
        'Call − put = stock − strike = ${money(s)} − ${money(k)} = '
            '${money(s - k)}.',
        askPut
            ? 'So put = call − ${money(s - k)}.'
            : 'So call = put + ${money(s - k)}.',
        askPut
            ? '${money(c)} − ${money(s - k)} = ${money(p)}.'
            : '${money(p)} + ${money(s - k)} = ${money(c)}.',
      ],
      insight: 'Right: call − put = stock − strike when rates are zero.',
      params: {'k': k, 's': s, 'c': c, 'p': p, 'askPut': Frac(askPut ? 1 : 0)},
    );
  }

  ({Frac s0, Frac up, Frac down, Frac k, bool call, Frac q, Frac pu, Frac pd})
  _tree(Random rng) {
    final s0 = _f(_pick(rng, [50, 80, 100]));
    // Moves (in %) whose fair odds are tidy (1/4, 2/5, 1/2, 3/5, 3/4), so
    // every price comes out in exact cents.
    final (u, dn) = _pick(rng, const [
      (20, 20),
      (25, 25),
      (30, 10),
      (10, 30),
      (30, 20),
      (20, 30),
    ]);
    final upBy = _f(u);
    final downBy = _f(dn);
    final up = s0 * (Frac(100) + upBy) / Frac(100);
    final down = s0 * (Frac(100) - downBy) / Frac(100);
    final call = rng.nextInt(3) != 0;
    final k = s0;
    final pu = Leg(
      type: call ? OptType.call : OptType.put,
      strike: k,
    ).payoff(up);
    final pd = Leg(
      type: call ? OptType.call : OptType.put,
      strike: k,
    ).payoff(down);
    final q = (s0 - down) / (up - down);
    return (s0: s0, up: up, down: down, k: k, call: call, q: q, pu: pu, pd: pd);
  }

  DeskScene _treeScene(
    ({Frac s0, Frac up, Frac down, Frac k, bool call, Frac q, Frac pu, Frac pd})
    t,
  ) => DeskScene(
    visual: DeskVisual.tree,
    chips: ['${t.call ? 'Call' : 'Put'} · strike ${money(t.k)}', 'Rates 0%'],
    s0: t.s0,
    up: t.up,
    down: t.down,
    payUp: t.pu,
    payDown: t.pd,
    caption: 'One step to expiry',
  );

  _Draft _binomial(Random rng) {
    final t = _tree(rng);
    // Analysts' odds, never the fair ones.
    var real = _pick(rng, [Frac(3, 5), Frac(7, 10), Frac(3, 4), Frac(2, 5)]);
    if (real == t.q) real = Frac(4, 5);
    final ans = t.q * t.pu + (Frac.one - t.q) * t.pd;
    final byReal = real * t.pu + (Frac.one - real) * t.pd;
    final name = t.call ? 'call' : 'put';
    final pct = (real.value * 100).round();
    return _Draft(
      scene: _treeScene(t),
      question:
          'Analysts give the rise a $pct% chance. What\'s the $name '
          'worth today?',
      hint: 'Price with the odds that make the stock fair.',
      value: ans,
      traps: [
        _m(
          byReal,
          '${money(byReal)} uses the analysts\' $pct%. Prices use '
          'the odds that make the stock\'s average today\'s price.',
        ),
        _m(
          (t.pu + t.pd) / Frac(2),
          'That splits it 50/50; the fair odds '
          'come from the prices.',
        ),
        _m(
          t.call ? t.pu : t.pd,
          'That\'s what it pays in its best case, '
          'not what it\'s worth today.',
        ),
        _m(t.pu + t.pd, _again),
        // Too small: the worst case, and the odds the wrong way round.
        _m(
          t.call ? t.pd : t.pu,
          'That\'s what it pays in its worst case; '
          'the chance of the good case is worth something today.',
        ),
        _m(
          (Frac.one - t.q) * t.pu + t.q * t.pd,
          'That swaps the odds: '
          '${ratio(t.q)} is the chance of a rise, not a fall.',
        ),
        _m(
          t.q * (t.pu + t.pd) / Frac(2),
          'That halves it again: the fair '
          'odds already weigh each case.',
        ),
        // A slip that lands between cents would stand out as wrong.
      ].where((m) => 100 % m.value!.d == 0).toList(),
      steps: [
        'Fair odds of a rise: (${money(t.s0)} − ${money(t.down)}) ÷ '
            '(${money(t.up)} − ${money(t.down)}) = ${ratio(t.q)}.',
        'Average payoff: ${ratio(t.q)} × ${money(t.pu)} + '
            '${ratio(Frac.one - t.q)} × ${money(t.pd)}.',
        'That\'s ${money(ans)} today, with rates at zero.',
      ],
      insight:
          'Right: options are priced with the fair odds, not anyone\'s '
          'forecast.',
      params: {
        's0': t.s0,
        'up': t.up,
        'down': t.down,
        'k': t.k,
        'call': Frac(t.call ? 1 : 0),
      },
    );
  }

  _Draft _hedge(Random rng) {
    final t = _tree(rng);
    final ans = (t.pu - t.pd) / (t.up - t.down);
    final name = t.call ? 'call' : 'put';
    final abs = ans > Frac.zero ? ans : Frac.zero - ans;
    String sh(Frac f) => ratio(f);
    return _Draft(
      scene: _treeScene(t),
      question:
          'Delta is how many shares move like one $name. What\'s the '
          '$name\'s delta?',
      hint: 'Change in the option ÷ change in the stock.',
      value: ans,
      format: sh,
      unit: Frac(1, 10),
      traps: [
        DeskTrap(
          sh(t.q),
          '${sh(t.q)} is the fair chance of a rise, not '
          'the delta.',
          t.q,
        ),
        if (!t.call)
          DeskTrap(
            sh(abs),
            '${sh(abs)} has the wrong sign: a put falls '
            'when the stock rises.',
            abs,
          ),
        DeskTrap(
          sh(t.call ? Frac.one : Frac(-1)),
          'A full share moves '
          'more than the option does here.',
          t.call ? Frac.one : Frac(-1),
        ),
        DeskTrap(
          sh((t.pu - t.pd) / t.s0),
          'That divides by today\'s price; '
          'use the gap between the two prices.',
          (t.pu - t.pd) / t.s0,
        ),
      ],
      steps: [
        'The $name moves from ${money(t.pd)} to ${money(t.pu)}: '
            '${money(t.pu - t.pd)}.',
        'The stock moves from ${money(t.down)} to ${money(t.up)}: '
            '${money(t.up - t.down)}.',
        '${money(t.pu - t.pd)} ÷ ${money(t.up - t.down)} = ${sh(ans)}.',
      ],
      insight: 'Right: delta is the option\'s move per \$1 of stock.',
      params: {
        's0': t.s0,
        'up': t.up,
        'down': t.down,
        'k': t.k,
        'call': Frac(t.call ? 1 : 0),
      },
    );
  }

  _Draft _deltaGamma(Random rng, int level) {
    final c = _f(_pick(rng, [3.2, 4.2, 5.6, 6.4, 2.8]));
    final delta = _f(_pick(rng, [0.4, 0.5, 0.6, 0.7]));
    final gamma = _f(_pick(rng, [0.02, 0.04, 0.05, 0.08]));
    // ½ × 0.05 × an odd move² lands between cents, so 0.05 takes even moves.
    final move = Frac(
      gamma == _f(0.05) ? _pick(rng, [2, -2]) : _pick(rng, [1, 2, 3, -1, -2]),
    );
    final withGamma = level >= 9 || rng.nextBool();
    final linear = delta * move;
    final bend = withGamma ? Frac(1, 2) * gamma * move * move : Frac.zero;
    final ans = c + linear + bend;
    final m = move.value.abs().round();
    final dir = move > Frac.zero ? 'rises' : 'falls';
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.quote,
        chips: [
          'Call ${money(c)}',
          'Δ ${dec(delta)}',
          if (withGamma) 'Γ ${dec(gamma)}',
        ],
        caption: 'Today\'s quote',
      ),
      question: 'The stock $dir \$$m. Roughly what\'s the call worth now?',
      hint: withGamma
          ? 'Delta for the move, plus ½ × gamma × move².'
          : 'Delta × the move.',
      value: ans,
      traps: [
        if (withGamma)
          _m(
            c + linear,
            '${money(c + linear)} uses delta alone. Gamma adds '
            'a little as the stock moves: ½ × Γ × move².',
          ),
        _m(
          c + move,
          '${money(c + move)} moves the call as much as the '
          'stock; it moves delta × as much.',
        ),
        if (withGamma)
          _m(
            c + linear + bend + bend,
            'That forgets the ½ in ½ × Γ × '
            'move².',
          ),
        _m(
          c - linear + bend,
          'That moves the call the wrong way: calls '
          'rise with the stock.',
        ),
        _m(c + delta, 'That\'s a \$1 move; this one is \$$m.'),
      ],
      steps: [
        'Delta: ${dec(delta)} × ${money(move)} = ${money(linear)}.',
        withGamma
            ? 'Gamma bends it: ½ × ${dec(gamma)} × $m² = ${money(bend)}.'
            : 'No gamma given, so delta alone.',
        '${money(c)} + ${money(linear)}'
            '${withGamma ? ' + ${money(bend)}' : ''} = ${money(ans)}.',
      ],
      insight: 'Right: delta for the move, and gamma for the bend.',
      params: {
        'c': c,
        'delta': delta,
        'gamma': withGamma ? gamma : Frac.zero,
        'move': move,
      },
    );
  }

  _Draft _theta(Random rng) {
    final c = _f(_pick(rng, [3.2, 4.2, 5.6, 6.4]));
    final theta = _f(_pick(rng, [-0.03, -0.04, -0.05, -0.08]));
    final days = _pick(rng, [3, 5, 7, 10]);
    final ans = c + theta * Frac(days);
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.quote,
        chips: ['Call ${money(c)}', 'Θ ${dec(theta)} a day'],
        caption: 'Today\'s quote',
      ),
      question:
          'Nothing else changes for $days days. Roughly what\'s the '
          'call worth then?',
      hint: 'Theta is the change per day, and it\'s negative.',
      value: ans,
      traps: [
        _m(
          c - theta * Frac(days),
          'That adds the time decay; a long '
          'option loses value as days pass.',
        ),
        _m(c + theta, 'That\'s one day; this is $days.'),
        _m(
          c,
          'Time passing costs an option value, even if nothing else '
          'moves.',
        ),
        _m(c + theta * Frac(days * 2), 'That counts each day twice.'),
      ],
      steps: [
        'Theta: ${money(theta)} a day.',
        '$days days × ${money(theta)} = ${money(theta * Frac(days))}.',
        '${money(c)} − ${money(Frac.zero - theta * Frac(days))} = '
            '${money(ans)}.',
      ],
      insight: 'Right: theta is the daily cost of waiting.',
      params: {'c': c, 'theta': theta, 'days': Frac(days)},
    );
  }

  _Draft _vega(Random rng) {
    final c = _f(_pick(rng, [3.2, 4.2, 5.6, 6.4]));
    final vega = _f(_pick(rng, [0.1, 0.12, 0.15, 0.2]));
    final pts = _pick(rng, [2, 3, 4, 5, -2, -3]);
    final ans = c + vega * Frac(pts);
    final up = pts > 0;
    final p = pts.abs();
    return _Draft(
      scene: DeskScene(
        visual: DeskVisual.quote,
        chips: ['Call ${money(c)}', 'Vega ${dec(vega)} a point'],
        caption: 'Today\'s quote',
      ),
      question:
          'Volatility ${up ? 'rises' : 'falls'} $p points. Roughly '
          'what\'s the call worth now?',
      hint: 'Vega is the change per volatility point.',
      value: ans,
      traps: [
        _m(
          c - vega * Frac(pts),
          'That moves it the wrong way: more '
          'volatility makes options worth more.',
        ),
        _m(
          c + (up ? vega : Frac.zero - vega),
          'That\'s one point; this is '
          '$p.',
        ),
        _m(
          c,
          'Volatility changes an option\'s price even when the stock '
          'doesn\'t move.',
        ),
        _m(c + vega * Frac(pts * 10), 'That reads vega as per 0.1 point.'),
      ],
      steps: [
        'Vega: ${money(vega)} per volatility point.',
        '$pts points × ${money(vega)} = ${money(vega * Frac(pts))}.',
        '${money(c)} ${up ? '+' : '−'} ${money(vega * Frac(p))} = '
            '${money(ans)}.',
      ],
      insight: 'Right: vega is the price change per volatility point.',
      params: {'c': c, 'vega': vega, 'pts': Frac(pts)},
    );
  }

  static const _concepts = [
    (
      'Which change raises a call\'s price?',
      'Higher volatility',
      [
        (
          'Less time to expiry',
          'Less time means less chance of a big '
              'move: the call is worth less.',
        ),
        ('A higher strike', 'A higher strike means the call pays less.'),
        (
          'A lower stock price',
          'A call gains when the stock rises, not '
              'falls.',
        ),
      ],
      'Wider swings mean a bigger chance of a big payoff; the loss is '
          'capped at the premium.',
    ),
    (
      'Which change raises a put\'s price?',
      'A lower stock price',
      [
        (
          'Lower volatility',
          'Less volatility lowers every option\'s '
              'price.',
        ),
        ('A lower strike', 'A lower strike means the put pays less.'),
        (
          'Higher interest rates',
          'Higher rates make puts slightly '
              'cheaper.',
        ),
      ],
      'A put pays the amount below the strike, so a lower stock raises it.',
    ),
    (
      'A call is deep in the money. Its delta is closest to…',
      '1',
      [
        ('0', 'That\'s a call far out of the money.'),
        ('0.5', 'That\'s a call right at the money.'),
        ('−1', 'That\'s a deep in-the-money put.'),
      ],
      'Deep in the money, the call moves almost one for one with the '
          'stock.',
    ),
    (
      'Which option has the most gamma?',
      'At the money, close to expiry',
      [
        (
          'Deep in the money',
          'Its delta is already near 1 and barely '
              'changes.',
        ),
        (
          'Deep out of the money',
          'Its delta is near 0 and barely '
              'changes.',
        ),
        (
          'At the money, a year out',
          'With lots of time left, delta '
              'changes slowly.',
        ),
      ],
      'Near expiry at the money, delta flips fast between 0 and 1.',
    ),
    (
      'For someone who bought an option, theta is usually…',
      'Negative: it loses value each day',
      [
        (
          'Positive: it gains value each day',
          'That\'s the seller\'s '
              'side.',
        ),
        (
          'Zero until expiry',
          'Time value drains every day, faster near '
              'the end.',
        ),
        (
          'The same as vega',
          'Vega is about volatility; theta is about '
              'time.',
        ),
      ],
      'Time value drains away as expiry gets closer.',
    ),
    (
      'A put\'s delta is always…',
      'Between −1 and 0',
      [
        ('Between 0 and 1', 'That\'s a call\'s delta.'),
        ('Exactly −0.5', 'Only roughly so, and only at the money.'),
        ('Above 1', 'No option moves more than the stock itself.'),
      ],
      'A put falls as the stock rises, so its delta is negative.',
    ),
  ];

  _Draft _concept(Random rng) {
    final i = rng.nextInt(_concepts.length);
    final (q, ans, wrong, why) = _concepts[i];
    return _Draft(
      scene: const DeskScene(visual: DeskVisual.none, chips: []),
      question: q,
      hint: 'Think about what makes a big payoff more likely.',
      traps: [for (final (l, w) in wrong) DeskTrap(l, w)],
      answer: ans,
      steps: [why, 'So: $ans.'],
      insight: 'Right: $why',
      params: {'concept': Frac(i)},
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
    String? answer,
    String Function(Frac)? format,
    Frac? unit,
  }) : format = format ?? money,
       unit = unit ?? Frac.one,
       answer = answer ?? (format ?? money)(value!);

  final DeskScene scene;
  final String question;
  final String hint;
  final Frac? value;
  final String answer;
  final List<DeskTrap> traps;
  final List<String> steps;
  final String insight;
  final Map<String, Frac> params;

  /// How numeric options are written, and the step for near misses.
  final String Function(Frac) format;
  final Frac unit;
}
