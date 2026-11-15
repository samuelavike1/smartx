import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/matrix_sense/matrix_puzzle.dart';
import 'package:smartx/games/odds_on/odds_math.dart';

// Everything here is recomputed from the raw entries with plain doubles:
// elimination, brute-force searches and repeated multiplication. Nothing is
// shared with the generator's formulas.

typedef Mat = List<List<double>>;

Mat toMat(Object m) => [
  for (final r in m as List) [for (final e in r as List) (e as num).toDouble()],
];

/// Determinant by Gaussian elimination with pivoting.
double det(Mat m) {
  final a = [
    for (final r in m) [...r],
  ];
  final n = a.length;
  var d = 1.0;
  for (var c = 0; c < n; c++) {
    var p = c;
    for (var r = c + 1; r < n; r++) {
      if (a[r][c].abs() > a[p][c].abs()) p = r;
    }
    if (a[p][c].abs() < 1e-12) return 0;
    if (p != c) {
      final t = a[p];
      a[p] = a[c];
      a[c] = t;
      d = -d;
    }
    d *= a[c][c];
    for (var r = c + 1; r < n; r++) {
      final f = a[r][c] / a[c][c];
      for (var k = c; k < n; k++) {
        a[r][k] -= f * a[c][k];
      }
    }
  }
  return d;
}

/// Inverse by Gauss–Jordan.
Mat inverse(Mat m) {
  final n = m.length;
  final a = [
    for (var i = 0; i < n; i++)
      [...m[i], for (var j = 0; j < n; j++) i == j ? 1.0 : 0.0],
  ];
  for (var c = 0; c < n; c++) {
    var p = c;
    for (var r = c + 1; r < n; r++) {
      if (a[r][c].abs() > a[p][c].abs()) p = r;
    }
    final t = a[p];
    a[p] = a[c];
    a[c] = t;
    final piv = a[c][c];
    for (var k = 0; k < 2 * n; k++) {
      a[c][k] /= piv;
    }
    for (var r = 0; r < n; r++) {
      if (r == c) continue;
      final f = a[r][c];
      for (var k = 0; k < 2 * n; k++) {
        a[r][k] -= f * a[c][k];
      }
    }
  }
  return [for (final r in a) r.sublist(n)];
}

Mat mul(Mat a, Mat b) => [
  for (var i = 0; i < a.length; i++)
    [
      for (var j = 0; j < b[0].length; j++)
        [for (var k = 0; k < b.length; k++) a[i][k] * b[k][j]]
            .fold(0.0, (s, x) => s + x),
    ],
];

Mat power(Mat a, int n) {
  var r = a;
  for (var i = 1; i < n; i++) {
    r = mul(r, a);
  }
  return r;
}

List<double> times(Mat a, List<double> v) => [
  for (final c in mul(a, [
    for (final x in v) [x],
  ]))
    c[0],
];

/// `\mat{1,2;3,4}` back to numbers.
Mat parseMat(String s) {
  final body = s.substring(s.indexOf('{') + 1, s.lastIndexOf('}'));
  return [
    for (final r in body.split(';'))
      [for (final e in r.split(',')) double.parse(e)],
  ];
}

List<double> parseVec(String s) => [for (final r in parseMat(s)) r[0]];

/// "2c_1 - c_2" to (2, −1).
(int, int) parseCombo(String s) {
  final m = RegExp(r'^(-?)(\d*)c_1 ([+-]) (\d*)c_2$').firstMatch(s)!;
  final x = int.parse(m[2]!.isEmpty ? '1' : m[2]!) * (m[1] == '-' ? -1 : 1);
  final y = int.parse(m[4]!.isEmpty ? '1' : m[4]!) * (m[3] == '-' ? -1 : 1);
  return (x, y);
}

bool parallel(List<double> u, List<double> v) =>
    (u[0] * v[1] - u[1] * v[0]).abs() < 1e-9;

List<double> col(Mat m, int j) => [for (final r in m) r[j]];

/// Integer eigenvalues of a 2 × 2, by searching for det(A − λI) = 0.
List<int> intEigen(Mat a) => [
  for (var l = -40; l <= 40; l++)
    if (det([
          [a[0][0] - l, a[0][1]],
          [a[1][0], a[1][1] - l],
        ]).abs() <
        1e-9)
      l,
];

/// The answer's value recomputed; for pick questions, checks the options
/// directly and returns null.
double? recompute(MatrixQuestion q) {
  final p = q.params;
  switch (q.kind) {
    case MatrixKind.det2:
    case MatrixKind.det3:
      return det(toMat(p['A']!));
    case MatrixKind.matVec:
      final a = toMat(p['A']!);
      final v = [for (final x in p['v']! as List<int>) x.toDouble()];
      final want = [for (final r in a) r[0] * v[0] + r[1] * v[1]];
      for (final o in q.options) {
        final got = parseVec(o);
        final same = got[0] == want[0] && got[1] == want[1];
        expect(same, o == q.answer, reason: '$o for $want');
      }
      return null;
    case MatrixKind.product:
      final ab = mul(toMat(p['A']!), toMat(p['B']!));
      return ab[p['i']! as int][p['j']! as int];
    case MatrixKind.inverse:
      final pos = p['pos']! as int;
      return inverse(toMat(p['A']!))[pos ~/ 2][pos % 2];
    case MatrixKind.singular:
      for (final o in q.options) {
        expect(det(parseMat(o)).abs() < 1e-9, o == q.answer, reason: o);
      }
      return null;
    case MatrixKind.eigen:
      final l = intEigen(toMat(p['A']!))..sort();
      expect(l, hasLength(2));
      return (p['larger']! as bool ? l.last : l.first).toDouble();
    case MatrixKind.eigenvector:
      final a = toMat(p['A']!);
      for (final o in q.options) {
        final u = parseVec(o);
        expect(parallel(times(a, u), u), o == q.answer, reason: o);
      }
      return null;
    case MatrixKind.eigenvalue:
      final a = toMat(p['A']!);
      final v = [for (final x in p['v']! as List<int>) x.toDouble()];
      final av = times(a, v);
      expect(parallel(av, v), isTrue);
      return v[0] != 0 ? av[0] / v[0] : av[1] / v[1];
    case MatrixKind.corrRange:
      final a = (p['r1']! as Frac).value, b = (p['r2']! as Frac).value;
      final ok = <int>[];
      // Every principal minor at least 0: the matrix is a valid
      // correlation matrix.
      for (var k = -100; k <= 100; k++) {
        final r = k / 100;
        final m = [
          [1.0, a, b],
          [a, 1.0, r],
          [b, r, 1.0],
        ];
        if (1 - r * r >= -1e-12 && det(m) >= -1e-9) ok.add(k);
      }
      return (p['low']! as bool ? ok.first : ok.last) / 100;
    case MatrixKind.corrEigen:
      final rho = (p['rho']! as Frac).value;
      // Power iteration for the biggest; the trace gives the other.
      var v = [1.0, 0.3];
      var big = 0.0;
      for (var i = 0; i < 400; i++) {
        final w = [v[0] + rho * v[1], rho * v[0] + v[1]];
        final n = (w[0] * w[0] + w[1] * w[1]);
        big = (w[0] * v[0] + w[1] * v[1]) / (v[0] * v[0] + v[1] * v[1]);
        v = [w[0] / n, w[1] / n];
      }
      return p['larger']! as bool ? big : 2 - big;
    case MatrixKind.combo:
      final m = toMat(p['A']!);
      for (final o in q.options) {
        final (x, y) = parseCombo(o);
        final ok = [
          for (var i = 0; i < 3; i++) x * m[i][0] + y * m[i][1] == m[i][2],
        ].every((e) => e);
        expect(ok, o == q.answer, reason: o);
      }
      return null;
    case MatrixKind.weight:
      final m = toMat(p['A']!);
      final found = [
        for (var x = -12; x <= 12; x++)
          for (var y = -12; y <= 12; y++)
            if ([
              for (var i = 0; i < 3; i++) x * m[i][0] + y * m[i][1] == m[i][2],
            ].every((e) => e))
              (x, y),
      ];
      expect(found, hasLength(1));
      return (p['askX']! as bool ? found.single.$1 : found.single.$2)
          .toDouble();
    case MatrixKind.powerTrace:
      final an = power(toMat(p['A']!), p['n']! as int);
      return an[0][0] + an[1][1];
    case MatrixKind.projection:
      final pos = p['pos']! as int;
      return power(toMat(p['P']!), p['n']! as int)[pos ~/ 2][pos % 2];
    case MatrixKind.system:
      final a = toMat(p['A']!);
      final e = p['e']! as int, f = p['f']! as int;
      final found = [
        for (var x = -30; x <= 30; x++)
          for (var y = -30; y <= 30; y++)
            if (a[0][0] * x + a[0][1] * y == e &&
                a[1][0] * x + a[1][1] * y == f)
              (x, y),
      ];
      expect(found, hasLength(1));
      return (p['askX']! as bool ? found.single.$1 : found.single.$2)
          .toDouble();
  }
}

void main() {
  const gen = MatrixGenerator();

  test('every answer matches an independent recount, at every level', () {
    final kinds = <MatrixKind>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 150; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        final why = '${q.kind} ${q.params} ${q.options}';
        expect(q.options, hasLength(4), reason: why);
        expect(q.options.toSet(), hasLength(4), reason: why);
        expect(q.options, contains(q.answer), reason: why);
        expect(q.steps, hasLength(3));
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty, reason: why);
        }
        final v = recompute(q);
        if (v == null) {
          expect(q.numeric, isFalse);
        } else {
          expect(q.optionValues![q.answerIndex], q.answerValue);
          expect(q.answerValue!.value, closeTo(v, 1e-6), reason: why);
        }
      }
    }
    expect(kinds, MatrixKind.values.toSet());
  });

  test('correlations stay between −1 and 1; eigenvalues of R above 0', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 300; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (q.kind == MatrixKind.corrRange) {
          for (final v in q.optionValues!) {
            expect(v.value, inInclusiveRange(-1, 1), reason: '${q.options}');
          }
        }
        if (q.kind == MatrixKind.corrEigen) {
          for (final v in q.optionValues!) {
            expect(v > Frac.zero, isTrue, reason: '${q.options}');
          }
        }
      }
    }
  });

  test('the answer is never the only whole number, or the only fraction', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) {
          // Vectors, matrices or combinations: all four the same shape.
          final kinds = {
            for (final o in q.options) o.startsWith(r'\mat') ? 'mat' : 'combo',
          };
          expect(kinds, hasLength(1), reason: '${q.options}');
          continue;
        }
        bool whole(Frac v) => v.d == 1;
        final mine = whole(q.answerValue!);
        expect(
          q.optionValues!.where((v) => whole(v) == mine).length,
          greaterThanOrEqualTo(2),
          reason: 'level $level: ${q.options}',
        );
        // Decimals and fractions never mix within a question.
        final fractions = q.options.where((o) => o.contains(r'\frac'));
        final decimals = q.options.where((o) => o.contains('.'));
        expect(fractions.isEmpty || decimals.isEmpty, isTrue);
      }
    }
  });

  test('the right answer is not given away by its place', () {
    for (var level = 1; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (var seed = 0; seed < 400; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (q.numeric) {
          expect(
            q.optionValues,
            orderedEquals([...q.optionValues!]..sort((a, b) => a.compareTo(b))),
          );
        }
        at[q.answerIndex]++;
      }
      final total = at.fold(0, (a, b) => a + b);
      for (final c in at) {
        expect(
          c / total,
          inInclusiveRange(0.15, 0.35),
          reason: 'level $level: $at',
        );
      }
    }
  });

  test('shuffled options put the answer anywhere', () {
    final at = List.filled(4, 0);
    for (final level in [2, 3, 6, 8]) {
      for (var seed = 0; seed < 800; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (!q.numeric) at[q.answerIndex]++;
      }
    }
    final total = at.fold(0, (a, b) => a + b);
    expect(total, greaterThan(1000));
    for (final c in at) {
      expect(c / total, inInclusiveRange(0.2, 0.3), reason: '$at');
    }
  });

  test('most wrong answers are named mistakes, not plain near misses', () {
    for (var level = 1; level <= 10; level++) {
      var named = 0, all = 0;
      for (var seed = 0; seed < 200; seed++) {
        for (final t in gen.generate(level: level, seed: seed).traps) {
          all++;
          if (!t.why.startsWith('Check the numbers')) named++;
        }
      }
      expect(
        named / all,
        greaterThan(0.6),
        reason:
            'level $level: '
            '$named of $all',
      );
    }
  });

  test('the picture belongs to its matrix', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 100; seed++) {
        final q = gen.generate(level: level, seed: seed);
        final pic = q.scene.picture;
        final onCard = {MatrixKind.det2, MatrixKind.projection};
        expect(q.scene.pictureOnCard, onCard.contains(q.kind));
        if (pic == null) continue;
        expect(pic.m, hasLength(2));
        if (pic.v != null) {
          // The arrow drawn is the vector in the question.
          expect(pic.v, q.params['v'] ?? q.params['answer']);
        }
        expect(q.scene.lines, isNotEmpty);
      }
    }
  });

  test('numbers and matrices are written as MathText expects', () {
    expect(mathNum(Frac(-3)), '-3');
    expect(mathNum(Frac(2, 5)), r'\frac{2}{5}');
    expect(mathNum(Frac(-1, 4)), r'-\frac{1}{4}');
    expect(mathNum(Frac(12, 25), decimal: true), '0.48');
    expect(mathNum(Frac(-3, 5), decimal: true), '-0.6');
    expect(plainNum(Frac(-7, 10)), '−7/10');
    expect(
      matSource([
        [3, 1],
        [2, 4],
      ]),
      r'\mat{3,1;2,4}',
    );
    expect(vecSource([5, -1]), r'\mat{5;-1}');
    expect(comboSource(2, -1), '2c_1 - c_2');
    expect(comboSource(-1, 3), '-c_1 + 3c_2');
    expect(comboPlain(2, -1), '2c₁ − c₂');
    expect(parseCombo('-c_1 + 3c_2'), (-1, 3));
  });

  test('the boards\' numbers', () {
    // Play: det [3, 1; 2, 3] = 7.
    final play = gen.generate(level: 1, seed: 23);
    expect(play.scene.lines, [r'A = \mat{3,1;2,3}']);
    expect(play.options, ['-7', '7', '9', '11']);
    expect(play.answer, '7');
    // Alt: a projection; every power is P.
    final alt = gen.generate(level: 9, seed: 5);
    expect(alt.kind, MatrixKind.projection);
    expect(alt.scene.lines, [r'P = \mat{-2,2;-3,3}']);
    expect(alt.question, 'What is the top-left entry of P⁴?');
    expect(alt.options, ['-2', '0', '1', '16']);
    expect(alt.answer, '-2');
    // Review: v = (1, −1) has eigenvalue −4; −1 is a diagonal entry.
    final review = gen.generate(level: 6, seed: 0);
    expect(review.kind, MatrixKind.eigenvalue);
    expect(review.scene.lines, [r'A = \mat{-1,3;5,1}', r'v = \mat{1;-1}']);
    expect(review.options, ['-16', '-6', '-4', '-1']);
    expect(review.answer, '-4');
    expect(
      review.feedbackFor('-1'),
      'Eigenvalues are the diagonal entries only for a triangular matrix.',
    );
    expect(review.steps.first, 'A × (1, −1) = (−4, 4).');
  });
}
