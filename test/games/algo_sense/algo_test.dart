import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/algo_sense/algo_puzzle.dart';
import 'package:smartx/games/odds_on/odds_math.dart';

// Every answer is recomputed here by brute force or simulation: running
// the loops, sorting, recursing, enumerating routes and coin mixes,
// Floyd–Warshall, bit strings. Nothing is shared with the generator.

/// Worst-case looks binary search makes on n items, over every target
/// (each item, and each gap between items).
int worstLooks(int n) {
  var worst = 0;
  for (var t = -1; t < 2 * n; t++) {
    final target = t / 2; // whole: an item; half: a missing value
    var lo = 0, hi = n - 1, looks = 0;
    while (lo <= hi) {
      looks++;
      final mid = (lo + hi) ~/ 2;
      if (mid == target) break;
      if (mid < target) {
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    worst = max(worst, looks);
  }
  return worst;
}

int naiveFibCalls(int n, Map<int, int> seen) {
  seen[n] = (seen[n] ?? 0) + 1;
  if (n < 2) return 1;
  return 1 + naiveFibCalls(n - 1, seen) + naiveFibCalls(n - 2, seen);
}

/// Runs the memo code: (calls, calls that reach the adding line).
(int, int) memoRun(int n) {
  final memo = <int, int>{};
  var calls = 0, adds = 0;
  int fib(int k) {
    calls++;
    if (k < 2) return k;
    if (memo.containsKey(k)) return memo[k]!;
    adds++;
    memo[k] = fib(k - 1) + fib(k - 2);
    return memo[k]!;
  }

  fib(n);
  return (calls, adds);
}

int climbs(int left, List<int> steps) {
  if (left == 0) return 1;
  var total = 0;
  for (final s in steps) {
    if (s <= left) total += climbs(left - s, steps);
  }
  return total;
}

/// Coin mixes (counts of each coin) that make [amount].
List<List<int>> mixes(int amount, List<int> coins) {
  final out = <List<int>>[];
  void go(int i, int left, List<int> counts) {
    if (i == coins.length) {
      if (left == 0) out.add([...counts]);
      return;
    }
    for (var k = 0; k * coins[i] <= left; k++) {
      go(i + 1, left - k * coins[i], [...counts, k]);
    }
  }

  go(0, amount, []);
  return out;
}

int routes(int w, int h, (int, int) wall) {
  int walk(int x, int y) {
    if (x > w || y > h || (x, y) == wall) return 0;
    if (x == w && y == h) return 1;
    return walk(x + 1, y) + walk(x, y + 1);
  }

  return walk(0, 0);
}

/// "1011" XOR "0110" digit by digit.
int xorByDigits(int a, int b) {
  final w = max(a.bitLength, b.bitLength);
  final x = a.toRadixString(2).padLeft(w, '0');
  final y = b.toRadixString(2).padLeft(w, '0');
  final out = [for (var i = 0; i < w; i++) x[i] == y[i] ? '0' : '1'].join();
  return int.parse(out, radix: 2);
}

/// Clears the last '1' of n's binary string.
int clearLowest(int n) {
  final s = n.toRadixString(2);
  final i = s.lastIndexOf('1');
  return int.parse('${s.substring(0, i)}0${s.substring(i + 1)}', radix: 2);
}

/// log₁₀ of each rate at n = 1,000.
double digitsAt1000(String rate) {
  const n = 1000;
  return switch (rate) {
    'log n' => log(log(n) / ln2) / ln10,
    '√n' => log(sqrt(n)) / ln10,
    'n' => 3,
    'n log n' => log(n * log(n) / ln2) / ln10,
    'n²' => 6,
    'n³' => 9,
    '2ⁿ' => n * log(2) / ln10,
    _ => [for (var k = 2; k <= n; k++) log(k) / ln10].reduce((a, b) => a + b),
  };
}

const taskRate = {
  'binary search in a sorted list': 'log n',
  'trying divisors up to √n': '√n',
  'one pass over the items': 'n',
  'merge sort': 'n log n',
  'checking every pair': 'n²',
  'checking every triple': 'n³',
  'trying every subset': '2ⁿ',
  'trying every order': 'n!',
};

String rateOf(String source) => switch (source) {
  r'O(\log n)' => 'log n',
  r'O(\sqrt{n})' => '√n',
  'O(n)' => 'n',
  r'O(n \log n)' => 'n log n',
  'O(n^2)' => 'n²',
  'O(n^3)' => 'n³',
  'O(2^n)' => '2ⁿ',
  'O(n!)' => 'n!',
  _ => throw StateError(source),
};

double parseOption(String s) =>
    double.parse(s.replaceAll(',', '').replaceAll('−', '-'));

/// The answer's value recomputed; growth questions check the options and
/// return null.
double? recompute(AlgoQuestion q) {
  final p = q.params;
  int i(String k) => p[k]! as int;
  switch (q.kind) {
    case AlgoKind.searchLooks:
      return worstLooks(i('n')).toDouble();
    case AlgoKind.searchCover:
      var n = 1;
      while (worstLooks(n + 1) <= i('k')) {
        n++;
      }
      return n.toDouble();
    case AlgoKind.loopCount:
      final n = i('n');
      var count = 0;
      switch (p['variant']) {
        case 'doubling':
          for (var x = 1; x < n; x *= 2) {
            count++;
          }
        case 'pairs':
          for (var a = 1; a <= n; a++) {
            for (var b = a + 1; b <= n; b++) {
              count++;
            }
          }
        default:
          for (var a = 1; a <= n; a++) {
            for (var b = 1; b <= a; b++) {
              count++;
            }
          }
      }
      return count.toDouble();
    case AlgoKind.scaleTime:
      double cost(num n) => switch (p['variant']) {
        'square' => pow(n, 2).toDouble(),
        'cubic' => pow(n, 3).toDouble(),
        'exp' => pow(2, n).toDouble(),
        _ => log(n),
      };
      return i('t') * cost(i('n2')) / cost(i('n1'));
    case AlgoKind.growth:
      final rates = (p['rates']! as List).cast<String>();
      final options = [for (final o in q.options) rateOf(o)];
      expect(options.toSet(), rates.toSet());
      final mine = rateOf(q.answer);
      switch (p['variant']) {
        case 'fastest':
          for (final r in rates) {
            expect(digitsAt1000(r) <= digitsAt1000(mine), isTrue);
          }
        case 'slowest':
          for (final r in rates) {
            expect(digitsAt1000(r) >= digitsAt1000(mine), isTrue);
          }
        default:
          expect(mine, taskRate[p['task']]);
      }
      return null;
    case AlgoKind.bubbleSwaps:
      final a = [...(p['array']! as List<int>)];
      var swaps = 0;
      for (var pass = 0; pass < a.length; pass++) {
        for (var j = 0; j + 1 < a.length - pass; j++) {
          if (a[j] > a[j + 1]) {
            final t = a[j];
            a[j] = a[j + 1];
            a[j + 1] = t;
            swaps++;
          }
        }
      }
      return swaps.toDouble();
    case AlgoKind.sortBound:
      var orders = BigInt.one;
      for (var k = 2; k <= i('n'); k++) {
        orders *= BigInt.from(k);
      }
      var c = 0;
      while (BigInt.two.pow(c) < orders) {
        c++;
      }
      return c.toDouble();
    case AlgoKind.fibCalls:
      return naiveFibCalls(i('n'), {}).toDouble();
    case AlgoKind.fibRepeat:
      final seen = <int, int>{};
      naiveFibCalls(i('n'), seen);
      return seen[i('k')]!.toDouble();
    case AlgoKind.memoCalls:
      final (calls, adds) = memoRun(i('n'));
      return (p['variant'] == 'adds' ? adds : calls).toDouble();
    case AlgoKind.stairs:
      return climbs(i('n'), (p['steps']! as List).cast<int>()).toDouble();
    case AlgoKind.coinWays:
      return mixes(
        i('amount'),
        (p['coins']! as List).cast<int>(),
      ).length.toDouble();
    case AlgoKind.coinFewest:
      return mixes(
        i('amount'),
        (p['coins']! as List).cast<int>(),
      ).map((m) => m.reduce((a, b) => a + b)).reduce(min).toDouble();
    case AlgoKind.setBits:
      return i('n')
          .toRadixString(2)
          .split('')
          .where((d) => d == '1')
          .length
          .toDouble();
    case AlgoKind.andMinusOne:
      return clearLowest(i('n')).toDouble();
    case AlgoKind.xorPair:
      return xorByDigits(i('a'), i('b')).toDouble();
    case AlgoKind.xorLone:
      final list = p['list']! as List<int>;
      final odd = list.toSet().where(
        (v) => list.where((x) => x == v).length.isOdd,
      );
      expect(odd, hasLength(1));
      return odd.single.toDouble();
    case AlgoKind.piDarts:
      return 4 * i('k') / i('n');
    case AlgoKind.mcSamples:
      // Error ∝ 1/√n: an error m times smaller needs n with √(n/n₁) = m.
      var n = i('n1');
      while (sqrt(n / i('n1')) < i('m') - 1e-9) {
        n += i('n1');
      }
      return n.toDouble();
    case AlgoKind.gridPaths:
      final wall = p['wall']! as List<int>;
      return routes(i('w'), i('h'), (wall[0], wall[1])).toDouble();
    case AlgoKind.bfsSteps:
      final size = i('size');
      const far = 1 << 20;
      final d = [
        for (var a = 0; a < size; a++)
          [for (var b = 0; b < size; b++) a == b ? 0 : far],
      ];
      for (final e in p['edges']! as List) {
        final ab = e as List<int>;
        d[ab[0]][ab[1]] = 1;
        d[ab[1]][ab[0]] = 1;
      }
      for (var k = 0; k < size; k++) {
        for (var a = 0; a < size; a++) {
          for (var b = 0; b < size; b++) {
            d[a][b] = min(d[a][b], d[a][k] + d[k][b]);
          }
        }
      }
      return d[0][i('target')].toDouble();
    case AlgoKind.newtonStep:
      final x0 = i('x0').toDouble(), a = i('a');
      return x0 - (x0 * x0 - a) / (2 * x0);
    case AlgoKind.bisection:
      final w = p['width']! as List<int>, t = p['tol']! as List<int>;
      // width ÷ 2ᵏ < tol  ⇔  w.n × t.d < t.n × w.d × 2ᵏ
      var k = 0;
      while (w[0] * t[1] >= t[0] * w[1] * (1 << k)) {
        k++;
      }
      return k.toDouble();
    case AlgoKind.newtonDigits:
      var digits = i('d0');
      for (var s = 0; s < i('s'); s++) {
        digits *= 2;
      }
      return digits.toDouble();
  }
}

void main() {
  const gen = AlgoGenerator();

  test('every answer, recomputed, at every level', () {
    final kinds = <AlgoKind>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 150; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        final why = '${q.kind} ${q.params} ${q.options}';
        expect(q.options, hasLength(4), reason: why);
        expect(q.options.toSet(), hasLength(4), reason: why);
        expect(q.options, contains(q.answer), reason: why);
        expect(q.traps, hasLength(3), reason: why);
        expect(q.steps, hasLength(3), reason: why);
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty, reason: why);
        }
        final v = recompute(q);
        if (v == null) {
          expect(q.numeric, isFalse);
        } else {
          expect(q.numeric, isTrue, reason: why);
          expect(q.answerValue!.value, closeTo(v, 1e-6), reason: why);
          expect(parseOption(q.answer), closeTo(v, 1e-6), reason: why);
        }
      }
    }
    expect(kinds, AlgoKind.values.toSet());
  });

  test('each level asks its own kinds', () {
    const expected = {
      1: {AlgoKind.searchLooks, AlgoKind.searchCover},
      3: {AlgoKind.bubbleSwaps, AlgoKind.sortBound},
      7: {AlgoKind.piDarts, AlgoKind.mcSamples},
      8: {AlgoKind.gridPaths, AlgoKind.bfsSteps},
    };
    for (final MapEntry(key: level, value: kinds) in expected.entries) {
      final seen = {
        for (var seed = 0; seed < 100; seed++)
          gen.generate(level: level, seed: seed).kind,
      };
      expect(seen, kinds, reason: 'level $level');
    }
    // Level 10 mixes levels 4 to 9.
    final mix = {
      for (var seed = 0; seed < 400; seed++)
        gen.generate(level: 10, seed: seed).kind,
    };
    expect(mix.length, greaterThanOrEqualTo(10));
    expect(mix.intersection(AlgoDifficulty.kindsFor(1).toSet()), isEmpty);
    expect(mix.intersection(AlgoDifficulty.kindsFor(3).toSet()), isEmpty);
  });

  test('options match their numbers, smallest first, and make sense', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) {
          for (final o in q.options) {
            expect(o, startsWith('O('));
          }
          continue;
        }
        final values = q.optionValues!;
        expect(values, orderedEquals([...values]..sort()));
        expect(values[q.answerIndex], q.answerValue);
        for (final (k, o) in q.options.indexed) {
          expect(parseOption(o), closeTo(values[k].value, 1e-9));
          // At most two decimals, never "about", never a fraction.
          expect(o, matches(RegExp(r'^[0-9,]+(\.[0-9]{1,2})?$')), reason: o);
          // Nothing at or below 0, except where 0 is a real result.
          if (q.kind == AlgoKind.andMinusOne) {
            expect(values[k] >= Frac.zero, isTrue);
          } else {
            expect(values[k] > Frac.zero, isTrue, reason: '${q.options}');
          }
        }
      }
    }
  });

  test('the answer is never the only whole number, or the only decimal', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) continue;
        bool whole(Frac v) => v.d == 1;
        final mine = whole(q.answerValue!);
        expect(
          q.optionValues!.where((v) => whole(v) == mine).length,
          greaterThanOrEqualTo(2),
          reason: 'level $level: ${q.options}',
        );
      }
    }
  });

  test('the right answer is not given away by its place', () {
    for (var level = 1; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (var seed = 0; seed < 400; seed++) {
        at[gen.generate(level: level, seed: seed).answerIndex]++;
      }
      for (final c in at) {
        expect(
          c / 400,
          inInclusiveRange(0.15, 0.35),
          reason: 'level $level: $at',
        );
      }
    }
  });

  test('growth rates are shuffled, the answer anywhere', () {
    final at = List.filled(4, 0);
    for (var seed = 0; seed < 3000; seed++) {
      final q = gen.generate(level: 2, seed: seed);
      if (!q.numeric) at[q.answerIndex]++;
    }
    final total = at.fold(0, (a, b) => a + b);
    expect(total, greaterThan(800));
    for (final c in at) {
      expect(c / total, inInclusiveRange(0.2, 0.3), reason: '$at');
    }
  });

  test('most wrong answers are named mistakes, not plain near misses', () {
    for (var level = 1; level <= 10; level++) {
      var named = 0, all = 0;
      for (var seed = 0; seed < 400; seed++) {
        for (final t in gen.generate(level: level, seed: seed).traps) {
          all++;
          if (t.why != AlgoGenerator.again) named++;
        }
      }
      expect(
        named / all,
        greaterThan(0.6),
        reason: 'level $level: $named/$all',
      );
    }
  });

  test('the named slips from the brief turn up', () {
    final whys = <String>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 400; seed++) {
        for (final t in gen.generate(level: level, seed: seed).traps) {
          whys.add(t.why);
        }
      }
    }
    bool any(String s) => whys.any((w) => w.contains(s));
    expect(any('log₂ n rounded down'), isTrue); // binary search off by one
    expect(any('That counts comparisons'), isTrue); // not swaps
    expect(any('counts the look-ups as new work'), isTrue); // memo
    expect(any('Times 4 for π'), isTrue); // the forgotten 4
    expect(any('so it takes'), isTrue); // twice the samples, half the error
    expect(any('Wrong sign'), isTrue); // Newton's step
  });

  test('text is plain, with full stops, and steps stay short', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        for (final s in [...q.steps, q.insight, ...q.traps.map((t) => t.why)]) {
          expect(s, matches(RegExp(r'[.…]$')), reason: s);
          expect(s.contains('  '), isFalse, reason: s);
          expect(s.contains('\\'), isFalse, reason: s);
        }
        for (final s in q.steps) {
          expect(s.length, lessThanOrEqualTo(150), reason: s);
        }
        expect(q.question, endsWith('?'));
        expect(q.hint.length, lessThanOrEqualTo(60), reason: q.hint);
      }
    }
  });

  test('each line on the review is shown once', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 1000; seed++) {
        final q = gen.generate(level: level, seed: seed);
        // The review's picture header is one short line.
        if (q.scene.picture case final pic?) {
          expect(pic.note.length, lessThanOrEqualTo(20), reason: pic.note);
          expect(pic.title.length, lessThanOrEqualTo(44), reason: pic.title);
        }
        final shown = [
          q.question,
          ...q.steps,
          if (q.scene.picture case final pic?) ...[pic.title, pic.note],
        ];
        for (final o in q.options) {
          final all = [...shown, q.feedbackFor(o)];
          expect(all.toSet(), hasLength(all.length), reason: '$all');
        }
      }
    }
  });

  test('pictures match their questions', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 200; seed++) {
        final q = gen.generate(level: level, seed: seed);
        final pic = q.scene.picture;
        final p = q.params;
        switch (pic) {
          case DartsPicture():
            expect(pic.darts, p['n']);
            expect(pic.inside, p['k']);
          case GridPicture():
            expect([pic.w, pic.h], [p['w'], p['h']]);
            expect([pic.wall.$1, pic.wall.$2], p['wall']);
          case GraphPicture():
            expect(pic.target, p['target']);
            // The drawn path is a shortest one, along drawn edges.
            expect(pic.path.length - 1, q.answerValue!.n);
            for (var k = 0; k + 1 < pic.path.length; k++) {
              final a = pic.path[k], b = pic.path[k + 1];
              expect(
                pic.edges.contains((min(a, b), max(a, b))),
                isTrue,
                reason: '${pic.path}',
              );
            }
          case RowsPicture() when q.kind == AlgoKind.bubbleSwaps:
            final a = p['array']! as List<int>;
            expect(pic.rows.single.cells, [for (final v in a) '$v']);
            expect(a[pic.arrowAt!] > a[pic.arrowAt! + 1], isTrue);
          case RowsPicture() when q.kind == AlgoKind.setBits:
            expect(int.parse(pic.rows.single.cells.join(), radix: 2), p['n']);
          case TreePicture():
            expect(pic.n, p['n']);
          default:
            break;
        }
        // Growth bars and loop squares would give the answer away.
        if (q.kind == AlgoKind.growth || q.kind == AlgoKind.loopCount) {
          expect(q.scene.pictureOnCard, isFalse);
        }
      }
    }
  });

  test('numbers are written for reading', () {
    expect(whole(16000), '16,000');
    expect(whole(1023), '1,023');
    expect(whole(999), '999');
    expect(numText(Frac(79, 25)), '3.16');
    expect(numText(Frac(9, 4)), '2.25');
    expect(numText(Frac(5)), '5');
    expect(pow2(10), '2¹⁰');
    expect(binary(5, 4), '0101');
  });

  test('the boards\' numbers', () {
    // Play: binary search on 100 items needs 7 looks.
    final play = gen.generate(level: 1, seed: 24);
    expect(play.kind, AlgoKind.searchLooks);
    expect(play.scene.lines, ['n = 100']);
    expect(play.options, ['7', '8', '50', '100']);
    expect(play.answer, '7');
    // Alt: 79 of 100 darts inside: π ≈ 3.16.
    final alt = gen.generate(level: 7, seed: 11);
    expect(alt.kind, AlgoKind.piDarts);
    expect(alt.scene.caption, '100 darts · 79 inside the quarter circle');
    expect(alt.options, ['0.79', '1.58', '3.16', '3.24']);
    expect(alt.answer, '3.16');
    // Review: one Newton step for √5 from 2; 1.75 has the wrong sign.
    final review = gen.generate(level: 9, seed: 14);
    expect(review.kind, AlgoKind.newtonStep);
    expect(review.scene.lines.last, 'a = 5,  x_0 = 2');
    expect(review.options, ['0.25', '1.75', '2.25', '2.5']);
    expect(review.answer, '2.25');
    expect(
      review.feedbackFor('1.75'),
      'Wrong sign: Newton subtracts f(x₀)/f′(x₀), so it moves towards the '
      'root.',
    );
    expect(review.steps, [
      'f(x) = x² − 5, f′(x) = 2x: x₁ = x₀ − f(x₀)/f′(x₀).',
      'f(2) = 4 − 5 = −1 and f′(2) = 4: the step is −1/4 = −0.25.',
      'x₁ = 2 − (−0.25) = 2.25.',
    ]);
  });
}
