import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/answer_options.dart';
import '../odds_on/odds_math.dart';

/// The kinds of question, in the order the levels bring them in.
enum MatrixKind {
  det2,
  matVec,
  product,
  inverse,
  singular,
  det3,
  eigen,
  eigenvector,
  eigenvalue,
  corrRange,
  corrEigen,
  combo,
  weight,
  powerTrace,
  projection,
  system,
}

/// A small 2D picture of what a 2 × 2 matrix does: to the unit square, or
/// to one vector.
@immutable
class MatrixPicture {
  const MatrixPicture({required this.m, required this.title, this.v});

  /// The matrix, rows first.
  final List<List<int>> m;

  /// The vector drawn with its image; null for the unit square.
  final List<int>? v;

  /// Shown above the picture on the review.
  final String title;

  /// Where A sends (x, y).
  List<int> apply(int x, int y) => [
    m[0][0] * x + m[0][1] * y,
    m[1][0] * x + m[1][1] * y,
  ];
}

/// The card above the question.
@immutable
class MatrixScene {
  const MatrixScene({
    required this.lines,
    required this.caption,
    this.picture,
    this.pictureOnCard = false,
  });

  /// Maths shown large, in `MathText` shorthand ("A = \mat{3,1;2,4}").
  final List<String> lines;
  final String caption;
  final MatrixPicture? picture;

  /// The picture is part of the question (otherwise it waits for the
  /// review, where it would give the answer away).
  final bool pictureOnCard;
}

/// A wrong answer and the slip behind it.
@immutable
class MatrixTrap {
  const MatrixTrap(this.label, this.why, [this.value]);

  /// The option in `MathText` shorthand.
  final String label;
  final String why;

  /// Its number, for numeric questions.
  final Frac? value;
}

@immutable
class MatrixQuestion {
  const MatrixQuestion({
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
  final MatrixKind kind;
  final MatrixScene scene;
  final String question;
  final String hint;

  /// Options are `MathText` shorthand: a number ("-3", "\frac{2}{5}"), a
  /// vector or matrix ("\mat{5;0}") or a combination ("2c_1 - c_2").
  final String answer;

  /// Null when the options are vectors, matrices or combinations.
  final Frac? answerValue;
  final List<MatrixTrap> traps;
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

class MatrixDifficulty {
  static List<MatrixKind> kindsFor(int level) => switch (level.clamp(1, 10)) {
    1 => const [MatrixKind.det2],
    2 => const [MatrixKind.matVec, MatrixKind.product],
    3 => const [MatrixKind.inverse, MatrixKind.singular],
    4 => const [MatrixKind.det3],
    5 => const [MatrixKind.eigen],
    6 => const [MatrixKind.eigenvector, MatrixKind.eigenvalue],
    7 => const [MatrixKind.corrRange, MatrixKind.corrEigen],
    8 => const [MatrixKind.combo, MatrixKind.weight],
    9 => const [
      MatrixKind.powerTrace,
      MatrixKind.projection,
      MatrixKind.system,
    ],
    _ => const [
      MatrixKind.det3,
      MatrixKind.eigen,
      MatrixKind.eigenvector,
      MatrixKind.eigenvalue,
      MatrixKind.corrRange,
      MatrixKind.corrEigen,
      MatrixKind.combo,
      MatrixKind.weight,
      MatrixKind.powerTrace,
      MatrixKind.projection,
      MatrixKind.system,
    ],
  };

  static String hint(int level) => switch (level.clamp(1, 10)) {
    1 => 'the determinant of a 2 × 2',
    2 => 'a matrix times a vector or a matrix',
    3 => 'inverses, and matrices without one',
    4 => 'quick 3 × 3 determinants',
    5 => 'eigenvalues from the trace and determinant',
    6 => 'eigenvectors and their eigenvalues',
    7 => 'correlation matrices',
    8 => 'rank: a column built from the others',
    9 => 'powers of a matrix, and 2 × 2 systems',
    _ => 'any of the matrices',
  };
}

// ---- writing numbers and matrices --------------------------------------------

/// "−3" for steps and captions.
String signed(int x) => x < 0 ? '−${-x}' : '$x';

/// "(−3)" inside a product or sum, "3" otherwise.
String _p(int x) => x < 0 ? '(−${-x})' : '$x';

/// A tidy decimal, "0.48", "−0.6", "1".
String _decimal(Frac f) {
  var s = f.value.abs().toStringAsFixed(2);
  while (s.contains('.') && (s.endsWith('0') || s.endsWith('.'))) {
    s = s.substring(0, s.length - 1);
  }
  return f < Frac.zero ? '−$s' : s;
}

/// A number in `MathText` shorthand: "-3", "\frac{2}{5}", "0.48".
String mathNum(Frac f, {bool decimal = false}) {
  if (f.d == 1) return '${f.n}';
  if (decimal) return _decimal(f).replaceAll('−', '-');
  final top = '\\frac{${f.n.abs()}}{${f.d}}';
  return f.n < 0 ? '-$top' : top;
}

/// The same number as plain text: "−3", "2/5", "0.48".
String plainNum(Frac f, {bool decimal = false}) {
  if (f.d == 1) return signed(f.n);
  if (decimal) return _decimal(f);
  return '${signed(f.n)}/${f.d}';
}

/// `\mat{3,1;2,4}`.
String matSource(List<List<Object>> rows) =>
    '\\mat{${rows.map((r) => r.join(',')).join(';')}}';

/// A column vector, `\mat{5;0}`.
String vecSource(List<int> v) => matSource([
  for (final x in v) [x],
]);

/// "[3, 1; 2, 4]".
String matPlain(List<List<int>> m) =>
    '[${m.map((r) => r.map(signed).join(', ')).join('; ')}]';

/// "(5, 0)".
String vecPlain(List<int> v) => '(${v.map(signed).join(', ')})';

/// "2c_1 - c_2" in shorthand.
String comboSource(int x, int y) {
  String term(int k, String c, bool first) {
    final mag = k.abs() == 1 ? c : '${k.abs()}$c';
    if (first) return k < 0 ? '-$mag' : mag;
    return k < 0 ? ' - $mag' : ' + $mag';
  }

  return '${term(x, 'c_1', true)}${term(y, 'c_2', false)}';
}

/// "2c₁ − c₂" as plain text.
String comboPlain(int x, int y) => comboSource(
  x,
  y,
).replaceAll('c_1', 'c₁').replaceAll('c_2', 'c₂').replaceAll('-', '−');

const _sup = {2: '²', 3: '³', 4: '⁴', 5: '⁵'};

const _corner = ['top-left', 'top-right', 'bottom-left', 'bottom-right'];

class MatrixGenerator {
  const MatrixGenerator();

  static const _again = 'Check the numbers again: see the working.';

  MatrixQuestion generate({required int level, required int seed}) {
    final rng = Random(seed);
    final kinds = MatrixDifficulty.kindsFor(level);
    final kind = kinds[rng.nextInt(kinds.length)];
    final draft = switch (kind) {
      MatrixKind.det2 => _det2(rng),
      MatrixKind.matVec => _matVec(rng),
      MatrixKind.product => _product(rng),
      MatrixKind.inverse => _inverse(rng),
      MatrixKind.singular => _singular(rng),
      MatrixKind.det3 => _det3(rng),
      MatrixKind.eigen => _eigen(rng),
      MatrixKind.eigenvector => _eigenvector(rng),
      MatrixKind.eigenvalue => _eigenvalue(rng),
      MatrixKind.corrRange => _corrRange(rng),
      MatrixKind.corrEigen => _corrEigen(rng),
      MatrixKind.combo => _combo(rng),
      MatrixKind.weight => _weight(rng),
      MatrixKind.powerTrace => _powerTrace(rng),
      MatrixKind.projection => _projection(rng),
      MatrixKind.system => _system(rng),
    };

    final List<MatrixTrap> chosen;
    final String answer;
    if (draft.value case final a?) {
      chosen = _numeric(draft, a, rng);
      answer = mathNum(a, decimal: draft.decimal);
    } else {
      answer = draft.answerSource!;
      chosen = _shuffled(answer, draft.wrong, rng);
    }

    return MatrixQuestion(
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
  List<MatrixTrap> _numeric(_Draft draft, Frac a, Random rng) {
    MatrixTrap t(Frac v, String why) =>
        MatrixTrap(mathNum(v, decimal: draft.decimal), why, v);
    bool fits(Frac v) {
      if (draft.decimal && (v * Frac(100)).d != 1) return false;
      return draft.fits?.call(v) ?? true;
    }

    final unit = draft.unit;
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
    final chosen = balancedOptions(
      t(a, ''),
      named,
      fillers,
      rng,
      compare: (x, y) => x.value!.compareTo(y.value!),
    );
    // A whole number among fractions (or the other way round) mustn't be
    // the answer just because it looks different.
    final spare = [
      for (final u in [unit, unit * Frac(1, 2), Frac(1, a.d), Frac.one])
        for (final k in [1, 2, 3, 4])
          for (final sign in [1, -1])
            if (fits(a + u * Frac(sign * k))) t(a + u * Frac(sign * k), _again),
    ];
    return _mixFormats(chosen, a, [...named, ...fillers, ...spare]);
  }

  static List<MatrixTrap> _mixFormats(
    List<MatrixTrap> chosen,
    Frac a,
    List<MatrixTrap> pool,
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
        (x, y) => (x.why == _again ? 0 : 1).compareTo(y.why == _again ? 0 : 1),
      );
      return [
        for (final o in chosen)
          if (o != out.first) o,
        c,
      ]..sort((x, y) => x.value!.compareTo(y.value!));
    }
    return chosen;
  }

  /// Vectors, matrices or combinations: shuffled, the answer anywhere.
  static List<MatrixTrap> _shuffled(
    String answer,
    List<(String, String)> wrong,
    Random rng,
  ) {
    final pool = [...wrong]..shuffle(rng);
    final chosen = <MatrixTrap>[];
    for (final (s, why) in pool) {
      if (s == answer || chosen.any((c) => c.label == s)) continue;
      chosen.add(MatrixTrap(s, why));
      if (chosen.length == 3) break;
    }
    return chosen
      ..insert(rng.nextInt(chosen.length + 1), MatrixTrap(answer, ''));
  }

  // ---- helpers ------------------------------------------------------------

  static T _pick<T>(Random rng, List<T> xs) => xs[rng.nextInt(xs.length)];

  /// A whole number from [lo] to [hi].
  static int _r(Random rng, int lo, int hi) => lo + rng.nextInt(hi - lo + 1);

  /// The same, never 0.
  static int _nz(Random rng, int lo, int hi) {
    int x;
    do {
      x = _r(rng, lo, hi);
    } while (x == 0);
    return x;
  }

  static int _det(List<List<int>> m) => m[0][0] * m[1][1] - m[0][1] * m[1][0];

  static List<int> _times(List<List<int>> m, List<int> v) => [
    for (final row in m) row[0] * v[0] + row[1] * v[1],
  ];

  static bool _parallel(List<int> u, List<int> v) =>
      u[0] * v[1] - u[1] * v[0] == 0;

  /// The simplest whole vector along [v], first non-zero entry positive.
  static List<int> _reduce(List<int> v) {
    int gcd(int a, int b) => b == 0 ? a.abs() : gcd(b, a % b);
    final g = gcd(v[0], v[1]);
    if (g == 0) return v;
    var r = [v[0] ~/ g, v[1] ~/ g];
    if (r[0] < 0 || (r[0] == 0 && r[1] < 0)) r = [-r[0], -r[1]];
    return r;
  }

  /// "λ² − 7λ + 10".
  static String _quad(int t, int d) {
    final mid = switch (t) {
      0 => '',
      1 => ' − λ',
      -1 => ' + λ',
      _ => t > 0 ? ' − $tλ' : ' + ${-t}λ',
    };
    final end = d == 0 ? '' : (d > 0 ? ' + $d' : ' − ${-d}');
    return 'λ²$mid$end';
  }

  /// "(λ − 5)", "(λ + 2)", "λ".
  static String _factor(int l) =>
      l == 0 ? 'λ' : (l > 0 ? '(λ − $l)' : '(λ + ${-l})');

  /// "x + 2y", "−y", "3x".
  static String _lin(int p, int q) {
    String term(int k, String v) => k.abs() == 1 ? v : '${k.abs()}$v';
    final parts = <String>[];
    if (p != 0) parts.add('${p < 0 ? '−' : ''}${term(p, 'x')}');
    if (q != 0) {
      parts.add(
        parts.isEmpty
            ? '${q < 0 ? '−' : ''}${term(q, 'y')}'
            : '${q < 0 ? '− ' : '+ '}${term(q, 'y')}',
      );
    }
    return parts.join(' ');
  }

  /// A 2 × 2 with whole eigenvalues [l1] and [l2] and nothing zero off the
  /// diagonal, so its eigenvalues are not simply its diagonal; null if none
  /// turned up.
  static List<List<int>>? _withEigen(Random rng, int l1, int l2) {
    final t = l1 + l2, p = l1 * l2;
    for (var tries = 0; tries < 60; tries++) {
      final a = _r(rng, -2, 7);
      final d = t - a;
      if (d.abs() > 8) continue;
      final bc = a * d - p;
      if (bc == 0) continue;
      final divisors = [
        for (var b = -6; b <= 6; b++)
          if (b != 0 && bc % b == 0 && (bc ~/ b).abs() <= 6) b,
      ];
      if (divisors.isEmpty) continue;
      final b = _pick(rng, divisors);
      return [
        [a, b],
        [bc ~/ b, d],
      ];
    }
    return null;
  }

  static String _a(List<List<Object>> m) => 'A = ${matSource(m)}';

  // ---- kinds --------------------------------------------------------------

  /// ad − bc.
  _Draft _det2(Random rng) {
    late int a, b, c, d;
    do {
      a = _r(rng, 1, 6);
      b = _r(rng, 1, 5);
      c = _r(rng, 1, 5);
      d = _r(rng, 1, 6);
      final flip = rng.nextInt(4);
      if (flip == 0) b = -b;
      if (flip == 1) c = -c;
    } while (a * d - b * c == 0);
    final m = [
      [a, b],
      [c, d],
    ];
    final det = a * d - b * c;
    return _Draft(
      scene: MatrixScene(
        lines: [_a(m)],
        caption: 'The unit square and where A sends it',
        picture: MatrixPicture(m: m, title: 'The unit square under A'),
        pictureOnCard: true,
      ),
      question: 'What is the determinant of A?',
      hint: 'Main diagonal product, minus the other one.',
      value: Frac(det),
      unit: Frac.one,
      traps: [
        (
          Frac(a * d + b * c),
          'That adds, ad + bc. The determinant subtracts: ad − bc.',
        ),
        (
          Frac(b * c - a * d),
          'That\'s bc − ad, the wrong way round. Start with the main '
              'diagonal.',
        ),
        (
          Frac(a * b - c * d),
          'That multiplies along the rows. Use the diagonals: ad − bc.',
        ),
        (
          Frac(a * c - b * d),
          'That multiplies down the columns. Use the diagonals: ad − bc.',
        ),
        (Frac(a * d), 'That\'s only ad. Take away bc as well.'),
        (Frac(a + d), 'That\'s the trace, a + d. The determinant is ad − bc.'),
      ],
      steps: [
        'Main diagonal: $a × ${_p(d)} = ${signed(a * d)}.',
        'Other diagonal: ${signed(b)} × ${_p(c)} = ${signed(b * c)}.',
        'det A = ${signed(a * d)} − ${_p(b * c)} = ${signed(det)}.',
      ],
      insight: 'Right: ad − bc. Its size is how much A stretches areas.',
      params: {'A': m},
    );
  }

  /// Av, as a whole vector.
  _Draft _matVec(Random rng) {
    late List<List<int>> m;
    late List<int> v, av;
    late List<(String, String)> wrong;
    do {
      m = [
        [_r(rng, -1, 5), _nz(rng, -2, 4)],
        [_nz(rng, -2, 4), _r(rng, -1, 5)],
      ];
      v = [_nz(rng, -2, 3), _nz(rng, -2, 3)];
      av = _times(m, v);
      final x = v[0], y = v[1];
      final tv = [m[0][0] * x + m[1][0] * y, m[0][1] * x + m[1][1] * y];
      final swapped = _times(m, [y, x]);
      final diag = [m[0][0] * x, m[1][1] * y];
      wrong = [
        for (final (w, why) in [
          (tv, 'That uses the columns of A as its rows: a transpose slip.'),
          (
            swapped,
            'The weights are swapped: x goes with column 1, y with column 2.',
          ),
          (diag, 'That uses only the diagonal. Each row of A meets all of v.'),
        ])
          if (vecSource(w) != vecSource(av)) (vecSource(w), why),
      ];
    } while (wrong.map((w) => w.$1).toSet().length < 3);
    final c1 = [m[0][0], m[1][0]], c2 = [m[0][1], m[1][1]];
    final x = v[0], y = v[1];
    return _Draft(
      scene: MatrixScene(
        lines: [_a(m), 'v = ${vecSource(v)}'],
        caption: 'A matrix and a vector',
        picture: MatrixPicture(m: m, v: v, title: 'v and Av'),
      ),
      question: 'What is Av?',
      hint: 'Each entry: a row of A times v, in pairs.',
      answerSource: vecSource(av),
      wrong: wrong,
      steps: [
        'Av = x × column 1 + y × column 2 = ${signed(x)} × ${vecPlain(c1)} '
            '+ ${_p(y)} × ${vecPlain(c2)}.',
        '= ${vecPlain([x * c1[0], x * c1[1]])} + '
            '${vecPlain([y * c2[0], y * c2[1]])}.',
        '= ${vecPlain(av)}.',
      ],
      insight: 'Right: Av mixes the columns of A, weighted by v.',
      params: {'A': m, 'v': v, 'answer': av},
    );
  }

  /// One entry of AB.
  _Draft _product(Random rng) {
    late List<List<int>> a, b;
    late int i, j, ans, rowRow, ba;
    do {
      a = [
        for (var r = 0; r < 2; r++) [_r(rng, -2, 5), _r(rng, -2, 5)],
      ];
      b = [
        for (var r = 0; r < 2; r++) [_r(rng, -2, 5), _r(rng, -2, 5)],
      ];
      i = rng.nextInt(2);
      j = rng.nextInt(2);
      ans = a[i][0] * b[0][j] + a[i][1] * b[1][j];
      rowRow = a[i][0] * b[j][0] + a[i][1] * b[j][1];
      ba = b[i][0] * a[0][j] + b[i][1] * a[1][j];
    } while (rowRow == ans || ba == ans);
    final row = a[i], col = [b[0][j], b[1][j]];
    return _Draft(
      scene: MatrixScene(
        lines: [_a(a), 'B = ${matSource(b)}'],
        caption: 'Rows of A meet columns of B',
      ),
      question: 'What is the entry in row ${i + 1}, column ${j + 1} of AB?',
      hint: 'Row of A times column of B, in pairs.',
      value: Frac(ans),
      unit: Frac.one,
      traps: [
        (
          Frac(rowRow),
          'That goes row by row. Use row ${i + 1} of A with column '
              '${j + 1} of B.',
        ),
        (
          Frac(ba),
          'That\'s the entry of BA. Order matters: rows of A, columns of B.',
        ),
        (
          Frac(a[i][j] * b[i][j]),
          'That multiplies matching entries only. Use a whole row and '
              'column.',
        ),
        if (i != j)
          (
            Frac(a[j][0] * b[0][i] + a[j][1] * b[1][i]),
            'That\'s row ${j + 1}, column ${i + 1}: the transposed spot.',
          ),
        (
          Frac(a[i][0] * b[0][j]),
          'That\'s only the first pair. Add the second pair too.',
        ),
        (
          Frac(a[0][i] * b[j][0] + a[1][i] * b[j][1]),
          'That\'s column ${i + 1} of A times row ${j + 1} of B: turned '
              'around.',
        ),
      ],
      steps: [
        'Row ${i + 1} of A is ${vecPlain(row)}; column ${j + 1} of B is '
            '${vecPlain(col)}.',
        'Multiply in pairs and add: ${signed(row[0])} × ${_p(col[0])} + '
            '${_p(row[1])} × ${_p(col[1])}.',
        '= ${signed(row[0] * col[0])} + ${_p(row[1] * col[1])} = '
            '${signed(ans)}.',
      ],
      insight: 'Right: each entry of AB is a row of A times a column of B.',
      params: {'A': a, 'B': b, 'i': i, 'j': j},
    );
  }

  /// One entry of A⁻¹ = (1/det) [d, −b; −c, a].
  _Draft _inverse(Random rng) {
    late int a, b, c, d, det;
    do {
      a = _nz(rng, -2, 7);
      b = _nz(rng, -3, 6);
      c = _nz(rng, -3, 6);
      d = _nz(rng, -2, 7);
      det = a * d - b * c;
    } while (det == 0 || det.abs() > 5 || a * d + b * c == 0);
    final m = [
      [a, b],
      [c, d],
    ];
    final adj = [
      [d, -b],
      [-c, a],
    ];
    final pos = rng.nextInt(4);
    final r = pos ~/ 2, k = pos % 2;
    final e = adj[r][k];
    final ans = Frac(e, det);
    final diagonal = r == k;
    final where = _corner[pos];
    return _Draft(
      scene: MatrixScene(
        lines: [_a(m)],
        caption: 'Find one entry of its inverse',
      ),
      question: 'What is the $where entry of the inverse of A?',
      hint: 'Swap, flip the signs, divide by the determinant.',
      value: ans,
      unit: Frac(1, det.abs()),
      traps: [
        if (det != 1)
          (Frac(e), 'You forgot to divide by det A = ${signed(det)}.'),
        (
          Frac(e, a * d + b * c),
          'That divides by ad + bc. det A is ad − bc = ${signed(det)}.',
        ),
        (Frac(1, m[r][k]), 'A⁻¹ isn\'t 1 over each entry of A.'),
        if (diagonal) ...[
          (
            Frac(m[r][k], det),
            'The diagonal entries swap places: a and d trade.',
          ),
          (
            Frac(-e, det),
            'Only b and c change sign. The diagonal keeps its sign.',
          ),
        ] else ...[
          (Frac(-e, det), 'b and c change sign in the inverse.'),
          (
            Frac(adj[k][r], det),
            'That\'s the other corner: b and c stay in their places.',
          ),
        ],
      ],
      steps: [
        'det A = ${signed(a)} × ${_p(d)} − ${_p(b)} × ${_p(c)} = '
            '${signed(det)}.',
        'Swap a and d, flip the signs of b and c: ${matPlain(adj)}.',
        'Divide by ${signed(det)}: the $where entry is ${plainNum(ans)}.',
      ],
      insight: 'Right: A⁻¹ = (1/det A) × [d, −b; −c, a].',
      params: {'A': m, 'pos': pos},
    );
  }

  /// Which of four matrices has determinant 0.
  _Draft _singular(Random rng) {
    final p = _r(rng, 1, 5), q = _nz(rng, -3, 5);
    final m = _pick(rng, const [2, 3, -1, -2]);
    final byRows = rng.nextBool();
    final ans = byRows
        ? [
            [p, q],
            [m * p, m * q],
          ]
        : [
            [p, m * p],
            [q, m * q],
          ];

    List<List<int>> plusZero() {
      final s = _r(rng, 1, 4), t = _r(rng, 1, 4), k = _r(rng, 1, 2);
      return [
        [s, t],
        [-k * s, k * t],
      ];
    }

    List<List<int>> zeroEntry() {
      final s = _nz(rng, -3, 5), t = _nz(rng, -3, 5), u = _r(rng, 1, 6);
      final at = rng.nextInt(4);
      final cells = [0, s, t, u];
      // The zero goes in a random corner; the rest stay invertible.
      final order = [for (var i = 0; i < 4; i++) cells[(i - at + 4) % 4]];
      return [
        [order[0], order[1]],
        [order[2], order[3]],
      ];
    }

    List<List<int>> near() {
      final s = _r(rng, 1, 4), t = _r(rng, 1, 4);
      return [
        [s, t],
        [m * s, m * t + 1],
      ];
    }

    List<List<int>> negative() {
      List<List<int>> x;
      do {
        x = [
          [_r(rng, 1, 5), _r(rng, 2, 6)],
          [_r(rng, 2, 6), _r(rng, 1, 5)],
        ];
      } while (_det(x) >= 0);
      return x;
    }

    final wrong = <(String, String)>[];
    void add(List<List<int>> x, String why) {
      final dt = _det(x);
      if (dt == 0) return;
      wrong.add((matSource(x), why.replaceAll('#', signed(dt))));
    }

    add(plusZero(), 'Here ad + bc is 0, but det = ad − bc = #.');
    add(zeroEntry(), 'A zero entry doesn\'t stop an inverse: det = #.');
    add(
      near(),
      'Row 2 is almost ${signed(m)} × row 1, but not quite: det = #.',
    );
    add(
      negative(),
      'A negative determinant is fine: det = #. Only 0 has no inverse.',
    );
    final mult = byRows
        ? 'Row 2 is ${signed(m)} × row 1'
        : 'Column 2 is '
              '${signed(m)} × column 1';
    return _Draft(
      scene: MatrixScene(
        lines: const [
          r'\mat{a,b;c,d}^{-1} = \frac{1}{ad - bc} \mat{d,-b;-c,a}',
        ],
        caption: 'The 2 × 2 inverse',
        picture: MatrixPicture(m: ans, title: 'The unit square, flattened'),
      ),
      question: 'Which matrix has no inverse?',
      hint: 'No inverse means the determinant is 0.',
      answerSource: matSource(ans),
      wrong: wrong,
      steps: [
        'A matrix has an inverse exactly when its determinant isn\'t 0.',
        '${matPlain(ans)}: ${signed(ans[0][0])} × ${_p(ans[1][1])} − '
            '${_p(ans[0][1])} × ${_p(ans[1][0])} = 0.',
        '$mult, so it squashes the plane onto a line.',
      ],
      insight: 'Right: det = 0, so there\'s no way back.',
      params: {'answer': ans},
    );
  }

  /// A 3 × 3 that's quick: triangular, or a row with one entry.
  _Draft _det3(Random rng) {
    if (rng.nextInt(4) == 0) {
      final upper = rng.nextBool();
      late List<List<int>> m;
      late int prod, trace;
      do {
        m = [
          for (var r = 0; r < 3; r++)
            [
              for (var c = 0; c < 3; c++)
                if (r == c)
                  _nz(rng, -3, 4)
                else if ((c > r) == upper)
                  _r(rng, -3, 6)
                else
                  0,
            ],
        ];
        prod = m[0][0] * m[1][1] * m[2][2];
        trace = m[0][0] + m[1][1] + m[2][2];
      } while (prod.abs() < 4 || m[2][2] == 1);
      final side = upper ? 'Below' : 'Above';
      return _Draft(
        scene: MatrixScene(
          lines: ['\\det${matSource(m).substring(4)}'],
          caption: 'A 3 × 3 determinant',
        ),
        question: 'What is this determinant?',
        hint: '$side the diagonal it\'s all zeros.',
        value: Frac(prod),
        unit: Frac(prod.abs() >= 12 ? 2 : 1),
        traps: [
          (
            Frac(trace),
            'That\'s the trace, the sum of the diagonal. The determinant '
                'multiplies it.',
          ),
          (
            Frac(-prod),
            'No sign change here: the diagonal term carries a plus.',
          ),
          (
            Frac(m[0][0] * m[1][1] - m[0][1] * m[1][0]),
            'That\'s only the top-left 2 × 2. Multiply by the last diagonal '
                'entry too.',
          ),
          (
            Frac.zero,
            'The zeros don\'t make it 0: a triangular determinant is the '
                'product of the diagonal.',
          ),
          for (var skip = 0; skip < 3; skip++)
            (
              Frac(prod ~/ m[skip][skip]),
              'That leaves out a diagonal entry. Multiply all three.',
            ),
        ],
        steps: [
          '$side the diagonal everything is 0: the matrix is triangular.',
          'Then the determinant is the product of the diagonal.',
          '${signed(m[0][0])} × ${_p(m[1][1])} × ${_p(m[2][2])} = '
              '${signed(prod)}.',
        ],
        insight: 'Right: for a triangular matrix, multiply the diagonal.',
        params: {'A': m},
      );
    }
    late List<List<int>> m, minor;
    late int r, c, k, mdet, mplus;
    do {
      r = rng.nextInt(3);
      c = rng.nextInt(3);
      k = _pick(rng, const [-3, -2, 2, 3, 4]);
      m = [
        for (var i = 0; i < 3; i++)
          [
            for (var j = 0; j < 3; j++)
              if (i == r) j == c ? k : 0 else _r(rng, -2, 4),
          ],
      ];
      minor = [
        for (var i = 0; i < 3; i++)
          if (i != r)
            [
              for (var j = 0; j < 3; j++)
                if (j != c) m[i][j],
            ],
      ];
      mdet = _det(minor);
      mplus = minor[0][0] * minor[1][1] + minor[0][1] * minor[1][0];
    } while (mdet == 0 ||
        mplus == mdet ||
        mplus == -mdet ||
        (k * mdet).abs() > 40);
    final sign = (r + c).isEven ? 1 : -1;
    final ans = sign * k * mdet;
    final column = rng.nextBool();
    // Slips: crossing out the wrong lines, and half of Sarrus' rule.
    int minorOf(int row, int col) => _det([
      for (var i = 0; i < 3; i++)
        if (i != row)
          [
            for (var j = 0; j < 3; j++)
              if (j != col) m[i][j],
          ],
    ]);
    final forward = [
      for (var s = 0; s < 3; s++)
        m[0][s] * m[1][(s + 1) % 3] * m[2][(s + 2) % 3],
    ].fold(0, (a, b) => a + b);
    final backward = [
      for (var s = 0; s < 3; s++)
        m[0][s] * m[1][(s + 2) % 3] * m[2][(s + 1) % 3],
    ].fold(0, (a, b) => a + b);
    // Read as a column: the same determinant, transposed.
    final shown = column
        ? [
            for (var j = 0; j < 3; j++) [for (var i = 0; i < 3; i++) m[i][j]],
          ]
        : m;
    final line = column ? 'Column ${r + 1}' : 'Row ${r + 1}';
    final other = column ? 'row ${c + 1}' : 'column ${c + 1}';
    final at = column ? '(${c + 1}, ${r + 1})' : '(${r + 1}, ${c + 1})';
    final shownMinor = column
        ? [
            for (var j = 0; j < 2; j++)
              [for (var i = 0; i < 2; i++) minor[i][j]],
          ]
        : minor;
    return _Draft(
      scene: MatrixScene(
        lines: ['\\det${matSource(shown).substring(4)}'],
        caption: 'A 3 × 3 determinant',
      ),
      question: 'What is this determinant?',
      hint:
          'Expand along the ${column ? 'column' : 'row'} with the most '
          'zeros.',
      value: Frac(ans),
      unit: Frac(ans.abs() >= 12 ? 2 : 1),
      traps: [
        (
          Frac(-ans),
          'Sign pattern: the spot $at carries a ${sign > 0 ? 'plus' : 'minus'}.',
        ),
        (
          Frac(sign * k * mplus),
          'The 2 × 2 left over is ad − bc, not ad + bc.',
        ),
        (
          Frac(sign * mdet),
          'That\'s the 2 × 2 alone. Multiply by ${signed(k)} too.',
        ),
        for (final other in [(c + 1) % 3, (c + 2) % 3])
          (
            Frac(sign * k * minorOf(r, other)),
            'That crosses out the wrong line. Remove the row and column of '
                '${signed(k)}.',
          ),
        if (r != c)
          (
            Frac(sign * k * minorOf(c, r)),
            'That crosses out the transposed spot. Remove the row and column '
                'of ${signed(k)}.',
          ),
        (
          Frac(forward),
          'That adds the three down-right diagonals only. The up-right ones '
              'are taken away.',
        ),
        (
          Frac(forward + backward),
          'That adds all six diagonal products. The three up-right ones are '
              'taken away.',
        ),
        (
          Frac(shown[0][0] + shown[1][1] + shown[2][2]),
          'That\'s the trace, the sum of the diagonal, not the determinant.',
        ),
      ],
      steps: [
        '$line has one entry that isn\'t 0, ${signed(k)}, in $other: '
            'expand along it.',
        'Cross out its row and column: ${matPlain(shownMinor)} has det '
            '${signed(mdet)}.',
        'The sign at $at is ${sign > 0 ? '+' : '−'}: '
            '${sign > 0 ? '' : '−'}${_p(k)} × ${_p(mdet)} = ${signed(ans)}.',
      ],
      insight: 'Right: one entry, its sign, and the 2 × 2 left over.',
      params: {'A': shown},
    );
  }

  /// The larger or smaller eigenvalue from the trace and determinant.
  _Draft _eigen(Random rng) {
    late int l1, l2;
    List<List<int>>? found;
    do {
      l1 = _r(rng, -2, 6);
      l2 = _r(rng, -3, 5);
      if (l1 <= l2) continue;
      found = _withEigen(rng, l1, l2);
    } while (found == null);
    final m = found;
    final a = m[0][0], b = m[0][1], c = m[1][0], d = m[1][1];
    final t = l1 + l2, det = l1 * l2;
    final larger = rng.nextBool();
    final ans = larger ? l1 : l2;
    final other = larger ? l2 : l1;
    const diag =
        'Eigenvalues are the diagonal entries only when the matrix is '
        'triangular.';
    return _Draft(
      scene: MatrixScene(
        lines: [_a(m)],
        caption: 'An eigenvalue: how far A stretches',
      ),
      question: 'What is the ${larger ? 'larger' : 'smaller'} eigenvalue of A?',
      hint: 'Eigenvalues add up to the trace (a + d) and multiply to det A.',
      value: Frac(ans),
      unit: Frac.one,
      traps: [
        (Frac(a), diag),
        (Frac(d), diag),
        (Frac(t), 'That\'s the trace, the sum of the two eigenvalues.'),
        (Frac(det), 'That\'s the determinant, the product of the two.'),
        (Frac(other), 'That\'s the ${larger ? 'smaller' : 'larger'} one.'),
        (Frac(-ans), 'Sign slip: solve λ² − (trace)λ + det = 0.'),
      ],
      steps: [
        'Trace = ${signed(a)} + ${_p(d)} = ${signed(t)}; det = ${signed(a)} × '
            '${_p(d)} − ${_p(b)} × ${_p(c)} = ${signed(det)}.',
        '${_quad(t, det)} = 0 factors as ${_factor(l1)}${_factor(l2)} = 0.',
        'The eigenvalues are ${signed(l1)} and ${signed(l2)}: the '
            '${larger ? 'larger' : 'smaller'} is ${signed(ans)}.',
      ],
      insight: 'Right: the trace and determinant pin down both eigenvalues.',
      params: {'A': m, 'larger': larger},
    );
  }

  /// A matrix with eigenvector (1, k): its entries, λ for (1, k) and μ for
  /// the other eigenvector.
  static (List<List<int>>, int, int, int) _eigenPair(Random rng) {
    while (true) {
      final a = _r(rng, -2, 5), b = _nz(rng, -3, 3), d = _r(rng, -2, 5);
      final k = _pick(rng, const [-2, -1, 1, 2, 3]);
      final c = k * a + b * k * k - d * k;
      final l = a + b * k, mu = d - b * k;
      if (c == 0 || c.abs() > 8 || l == mu || l == 0) continue;
      if (l.abs() > 9 || mu.abs() > 9) continue;
      return (
        [
          [a, b],
          [c, d],
        ],
        k,
        l,
        mu,
      );
    }
  }

  /// Which of four vectors only gets stretched.
  _Draft _eigenvector(Random rng) {
    late List<List<int>> m;
    late int k, l;
    late List<int> v;
    late List<(String, String)> wrong;
    do {
      final (mm, kk, ll, mu) = _eigenPair(rng);
      m = mm;
      k = kk;
      l = ll;
      v = [1, k];
      final a = m[0][0], b = m[0][1], c = m[1][0];
      final w = [b, mu - a];
      final tv = _reduce([c, l - a]);
      wrong = [];
      for (final (u, slip) in [
        ([a, c], 'That\'s column 1 of A.'),
        ([a, b], 'That\'s row 1 of A.'),
        ([k, 1], 'Its entries are swapped.'),
        ([1, -k], 'A sign slip: the second entry\'s sign is flipped.'),
        (tv, 'That belongs to the transpose, rows and columns swapped.'),
      ]) {
        if (u[0] == 0 && u[1] == 0) continue;
        if (_parallel(u, v) || _parallel(u, w)) continue;
        final au = _times(m, u);
        wrong.add((
          vecSource(u),
          '$slip A times it is ${vecPlain(au)}: not a multiple of it.',
        ));
      }
    } while (wrong.map((x) => x.$1).toSet().length < 3);
    final av = _times(m, v);
    return _Draft(
      scene: MatrixScene(
        lines: [_a(m)],
        caption: 'An eigenvector keeps its direction',
        picture: MatrixPicture(m: m, v: v, title: 'v and Av'),
      ),
      question: 'Which vector is an eigenvector of A?',
      hint: 'Multiply each by A: an eigenvector only gets stretched.',
      answerSource: vecSource(v),
      wrong: wrong,
      steps: [
        'An eigenvector keeps its direction: Av is a multiple of v.',
        'A × ${vecPlain(v)} = ${vecPlain(av)}.',
        'That\'s ${signed(l)} × ${vecPlain(v)}: an eigenvector, with '
            'eigenvalue ${signed(l)}.',
      ],
      insight: 'Right: A only stretches it, by λ = ${signed(l)}.',
      params: {'A': m, 'answer': v},
    );
  }

  /// The eigenvalue of a given eigenvector.
  _Draft _eigenvalue(Random rng) {
    final (m, k, l, mu) = _eigenPair(rng);
    final s = _pick(rng, const [1, 2, -1]);
    final v = [s, s * k];
    final av = _times(m, v);
    final a = m[0][0], d = m[1][1];
    const diag =
        'Eigenvalues are the diagonal entries only for a triangular '
        'matrix.';
    const entry = 'That\'s an entry of Av. Divide by the matching entry of v.';
    return _Draft(
      scene: MatrixScene(
        lines: [_a(m), 'v = ${vecSource(v)}'],
        caption: 'A stretches v along its own line',
        picture: MatrixPicture(m: m, v: v, title: 'v and Av'),
      ),
      question: 'v is an eigenvector of A. What is its eigenvalue?',
      hint: 'Work out Av and compare it with v.',
      value: Frac(l),
      unit: Frac.one,
      traps: [
        (Frac(a), diag),
        (Frac(d), diag),
        (Frac(av[0]), entry),
        (Frac(av[1]), entry),
        (
          Frac(mu),
          'That\'s the other eigenvalue, which belongs to a different '
              'eigenvector.',
        ),
        (Frac(a + d), 'That\'s the trace, the sum of both eigenvalues.'),
        (Frac(_det(m)), 'That\'s the determinant, the product of both.'),
      ],
      steps: [
        'A × ${vecPlain(v)} = ${vecPlain(av)}.',
        'Av = λv: compare the top entries, ${signed(av[0])} = λ × ${_p(s)}.',
        'So λ = ${signed(l)}.',
      ],
      insight: 'Right: Av = λv, so λ is the stretch along v.',
      params: {'A': m, 'v': v},
    );
  }

  /// The smallest or largest missing correlation in a 3 × 3.
  _Draft _corrRange(Random rng) {
    // Correlations whose √(1 − r²) is tidy.
    final rs = [Frac(3, 5), Frac(4, 5), Frac(-3, 5), Frac(-4, 5), Frac.zero];
    Frac root(Frac r) =>
        r == Frac.zero ? Frac.one : (r.n.abs() == 3 ? Frac(4, 5) : Frac(3, 5));
    late Frac r1, r2, mid, half, ans;
    late bool low;
    do {
      r1 = _pick(rng, rs);
      r2 = _pick(rng, rs);
      mid = r1 * r2;
      half = root(r1) * root(r2);
      low = rng.nextBool();
      ans = low ? mid - half : mid + half;
    } while ((r1 == Frac.zero && r2 == Frac.zero) ||
        ans >= Frac.one ||
        ans <= Frac(-1));
    final lo = mid - half, hi = mid + half;
    String f(Frac x) => plainNum(x, decimal: true);
    final room = low ? ans - Frac(-1) : Frac.one - ans;
    return _Draft(
      scene: MatrixScene(
        lines: [
          'R = ${matSource([
            ['1', mathNum(r1, decimal: true), mathNum(r2, decimal: true)],
            [mathNum(r1, decimal: true), '1', r'\rho'],
            [mathNum(r2, decimal: true), r'\rho', '1'],
          ])}',
        ],
        caption: 'Correlations of X₁, X₂ and X₃',
      ),
      question:
          'What is the ${low ? 'smallest' : 'largest'} correlation X₂ and '
          'X₃ can have?',
      hint: 'ρ is the missing one. The determinant can\'t go below 0.',
      value: ans,
      decimal: true,
      unit: room < Frac(3, 25) ? Frac(1, 100) : Frac(1, 25),
      fits: (x) => x >= Frac(-1) && x <= Frac.one,
      traps: [
        (
          low ? Frac(-1) : Frac.one,
          'That\'s the limit for one correlation alone. With the other two '
              'fixed the range is narrower.',
        ),
        (mid, 'That\'s the centre of the range, ρ₁₂ρ₁₃, not its end.'),
        (
          low ? hi : lo,
          'That\'s the ${low ? 'largest' : 'smallest'} it can be.',
        ),
        if (mid != Frac.zero)
          (
            low ? Frac.zero - mid - half : Frac.zero - mid + half,
            'Sign slip: the centre is +ρ₁₂ρ₁₃ = ${f(mid)}.',
          ),
        (
          low ? mid - half * half : mid + half * half,
          'That forgets the square root in √((1 − a²)(1 − b²)).',
        ),
      ],
      steps: [
        'With a = ${f(r1)} and b = ${f(r2)}, the determinant 1 − a² − b² − '
            'ρ² + 2abρ can\'t go below 0.',
        'So ρ = ab ± √((1 − a²)(1 − b²)) = ${f(mid)} ± ${f(half)} at the '
            'edges.',
        'ρ runs from ${f(lo)} to ${f(hi)}: the ${low ? 'smallest' : 'largest'} '
            'is ${f(ans)}.',
      ],
      insight: 'Right: two correlations fixed, the third has a narrower range.',
      params: {'r1': r1, 'r2': r2, 'low': low},
    );
  }

  /// [[1, ρ], [ρ, 1]] has eigenvalues 1 ± ρ.
  _Draft _corrEigen(Random rng) {
    final larger = rng.nextBool();
    int tenths;
    do {
      tenths = _nz(rng, -9, 9);
    } while (tenths.abs() < 2 || (!larger && tenths.abs() > 7));
    final rho = Frac(tenths, 10);
    final r = rho < Frac.zero ? Frac.zero - rho : rho;
    final big = Frac.one + r, small = Frac.one - r;
    final ans = larger ? big : small;
    String f(Frac x) => plainNum(x, decimal: true);
    const trace = 'That\'s the trace, 2, the sum of the eigenvalues.';
    return _Draft(
      scene: MatrixScene(
        lines: [
          'R = ${matSource([
            ['1', mathNum(rho, decimal: true)],
            [mathNum(rho, decimal: true), '1'],
          ])}',
        ],
        caption: 'A 2 × 2 correlation matrix',
      ),
      question:
          'What is the ${larger ? 'larger' : 'smaller'} eigenvalue of this '
          'correlation matrix?',
      hint: 'The eigenvalues add up to 2 and multiply to 1 − ρ².',
      value: ans,
      decimal: true,
      unit: ans < Frac(1, 2) ? Frac(1, 20) : Frac(1, 10),
      fits: (x) => x > Frac.zero,
      traps: [
        (
          Frac.one,
          'The diagonal entries are the eigenvalues only for a diagonal '
              'matrix.',
        ),
        (Frac(2), trace),
        (
          Frac.one - rho * rho,
          'That\'s the determinant, the product of the eigenvalues.',
        ),
        (
          larger ? small : big,
          'That\'s the ${larger ? 'smaller' : 'larger'} one.',
        ),
        (r, 'ρ is an entry of the matrix, not an eigenvalue.'),
        (
          rho * rho,
          'ρ² is the share of variance explained, not an eigenvalue.',
        ),
        (
          Frac.one / small,
          'That\'s an eigenvalue of the inverse. R\'s are 1 ± ρ.',
        ),
      ],
      steps: [
        'The eigenvalues add up to the trace, 2, and multiply to the '
            'determinant, 1 − ${f(rho * rho)} = ${f(Frac.one - rho * rho)}.',
        'That makes them 1 + ρ and 1 − ρ: ${f(big)} and ${f(small)}.',
        'The ${larger ? 'larger' : 'smaller'} is ${f(ans)}.',
      ],
      insight: 'Right: [1, ρ; ρ, 1] has eigenvalues 1 ± ρ.',
      params: {'rho': rho, 'larger': larger},
    );
  }

  /// Two independent columns and a third built from them.
  static (List<int>, List<int>, int, int) _columns(Random rng) {
    while (true) {
      final c1 = [_r(rng, -2, 4), _r(rng, -2, 4), _r(rng, -2, 4)];
      final c2 = [_r(rng, -2, 4), _r(rng, -2, 4), _r(rng, -2, 4)];
      final cross = [
        c1[1] * c2[2] - c1[2] * c2[1],
        c1[2] * c2[0] - c1[0] * c2[2],
        c1[0] * c2[1] - c1[1] * c2[0],
      ];
      if (cross.every((x) => x == 0)) continue;
      final x = _pick(rng, const [-2, -1, 1, 2, 3]);
      final y = _pick(rng, const [-2, -1, 1, 2, 3]);
      final c3 = [for (var i = 0; i < 3; i++) x * c1[i] + y * c2[i]];
      if (c3.any((e) => e.abs() > 12)) continue;
      if (c3.every((e) => e == 0)) continue;
      // No row of zeros: every row should count.
      if ([for (var i = 0; i < 3; i++) c1[i] == 0 && c2[i] == 0]
          .any((z) => z)) {
        continue;
      }
      return (c1, c2, x, y);
    }
  }

  static List<List<int>> _byColumns(List<int> c1, List<int> c2, List<int> c3) =>
      [
        for (var i = 0; i < 3; i++) [c1[i], c2[i], c3[i]],
      ];

  /// The weights that build row 3 from rows 1 and 2, if there are some.
  static (Frac, Frac)? _rowWeights(List<List<int>> m) {
    final r1 = m[0], r2 = m[1], r3 = m[2];
    for (final (i, j) in [(0, 1), (0, 2), (1, 2)]) {
      final det = r1[i] * r2[j] - r2[i] * r1[j];
      if (det == 0) continue;
      final g = Frac(r3[i] * r2[j] - r2[i] * r3[j], det);
      final h = Frac(r1[i] * r3[j] - r3[i] * r1[j], det);
      for (var c = 0; c < 3; c++) {
        if (g * Frac(r1[c]) + h * Frac(r2[c]) != Frac(r3[c])) return null;
      }
      return (g, h);
    }
    return null;
  }

  /// Which combination of c₁ and c₂ gives c₃.
  _Draft _combo(Random rng) {
    late List<int> c1, c2, c3;
    late int x, y;
    late List<(String, String)> wrong;
    do {
      (c1, c2, x, y) = _columns(rng);
      c3 = [for (var i = 0; i < 3; i++) x * c1[i] + y * c2[i]];
      final rows = _rowWeights(_byColumns(c1, c2, c3));
      wrong = [];
      void add(int p, int q, String slip) {
        if ((p, q) == (x, y) || (p == 0 && q == 0)) return;
        final got = [for (var i = 0; i < 3; i++) p * c1[i] + q * c2[i]];
        wrong.add((
          comboSource(p, q),
          '$slip It gives ${vecPlain(got)}, not c₃.',
        ));
      }

      add(y, x, 'The weights are swapped.');
      add(x, -y, 'A sign slip on the c₂ part.');
      add(-x, y, 'A sign slip on the c₁ part.');
      add(1, 1, 'Just adding the columns doesn\'t do it.');
      if (rows case (final g, final h)
          when g.d == 1 && h.d == 1 && g.n != 0 && h.n != 0) {
        add(g.n, h.n, 'That builds row 3 from rows 1 and 2: a transpose slip.');
      }
    } while (wrong.map((w) => w.$1).toSet().length < 3);
    final m = _byColumns(c1, c2, c3);
    final xc1 = [for (final e in c1) x * e], yc2 = [for (final e in c2) y * e];
    return _Draft(
      scene: MatrixScene(
        lines: [matSource(m)],
        caption: 'Three columns, rank 2',
      ),
      question:
          'The rank is 2: column 3 is built from columns 1 and 2. Which '
          'way gives c₃?',
      hint: 'Check the top entries first, then the rest.',
      answerSource: comboSource(x, y),
      wrong: wrong,
      steps: [
        'c₁ = ${vecPlain(c1)}, c₂ = ${vecPlain(c2)}, c₃ = ${vecPlain(c3)}.',
        '${comboPlain(x, y)} = ${vecPlain(xc1)} + ${vecPlain(yc2)}.',
        '= ${vecPlain(c3)}: column 3, so only two columns are independent.',
      ],
      insight: 'Right: rank 2 means one column is a mix of the other two.',
      params: {'A': m, 'x': x, 'y': y},
    );
  }

  /// c₃ = x c₁ + y c₂: one of the weights.
  _Draft _weight(Random rng) {
    final (c1, c2, x, y) = _columns(rng);
    final c3 = [for (var i = 0; i < 3; i++) x * c1[i] + y * c2[i]];
    final m = _byColumns(c1, c2, c3);
    final askX = rng.nextBool();
    final ans = askX ? x : y;
    // Two rows that pin down x and y, and the third to check.
    final (i, j) = [
      (0, 1),
      (0, 2),
      (1, 2),
    ].firstWhere((p) => c1[p.$1] * c2[p.$2] - c1[p.$2] * c2[p.$1] != 0);
    final k = 3 - i - j;
    const names = ['top', 'middle', 'bottom'];
    final rows = _rowWeights(m);
    final mine = askX ? c1 : c2;
    return _Draft(
      scene: MatrixScene(
        lines: [matSource(m)],
        caption: 'Three columns, rank 2',
      ),
      question: 'Column 3 is x·c₁ + y·c₂. What is ${askX ? 'x' : 'y'}?',
      hint: 'Match two entries of column 3 and solve.',
      value: Frac(ans),
      unit: Frac.one,
      traps: [
        (
          Frac(askX ? y : x),
          'That\'s ${askX ? 'y, the weight on c₂' : 'x, the weight on c₁'}.',
        ),
        (Frac(-ans), 'Sign slip: check it against column 3.'),
        if (mine[0] != 0)
          (
            Frac(c3[0], mine[0]),
            'Dividing the top entries ignores the other column\'s part.',
          ),
        if (rows case (final g, final h))
          (
            askX ? g : h,
            'That\'s a weight that builds row 3 from rows 1 and 2: a '
                'transpose slip.',
          ),
        (Frac(x + y), 'That adds the two weights together.'),
      ],
      steps: [
        '${names[i][0].toUpperCase()}${names[i].substring(1)} and ${names[j]} '
            'rows: ${_lin(c1[i], c2[i])} = ${signed(c3[i])} and '
            '${_lin(c1[j], c2[j])} = ${signed(c3[j])}.',
        'Solving them: x = ${signed(x)} and y = ${signed(y)}.',
        'Check the ${names[k]} row: ${signed(x)} × ${_p(c1[k])} + ${_p(y)} × '
            '${_p(c2[k])} = ${signed(c3[k])}.',
      ],
      insight: 'Right: the weights that build column 3 from the other two.',
      params: {'A': m, 'askX': askX},
    );
  }

  /// The trace of A² or A³ from the eigenvalues.
  _Draft _powerTrace(Random rng) {
    late int l1, l2;
    List<List<int>>? found;
    do {
      l1 = _r(rng, -3, 4);
      l2 = _r(rng, -3, 4);
      if (l1 <= l2 || l1 == 0 || l2 == 0) continue;
      found = _withEigen(rng, l1, l2);
    } while (found == null);
    final m = found;
    final a = m[0][0], b = m[0][1], c = m[1][0], d = m[1][1];
    final n = rng.nextInt(3) == 0 ? 3 : 2;
    int pw(int x) => n == 2 ? x * x : x * x * x;
    final ans = pw(l1) + pw(l2);
    final t = l1 + l2, det = l1 * l2;
    final sup = _sup[n]!;
    return _Draft(
      scene: MatrixScene(
        lines: [_a(m)],
        caption: 'Trace: the sum of the diagonal',
      ),
      question: 'What is the trace of A$sup?',
      hint: 'A$sup has eigenvalues λ₁$sup and λ₂$sup.',
      value: Frac(ans),
      unit: Frac(ans.abs() > 30 ? 3 : 1),
      traps: [
        (
          Frac(pw(t)),
          'That\'s (trace)$sup. The trace of A$sup adds the eigenvalues\' '
              'powers.',
        ),
        (
          Frac(pw(a) + pw(d)),
          'That powers the diagonal entries; they aren\'t the eigenvalues '
              'here.',
        ),
        if (n == 2)
          (
            Frac(a * a + b * b + c * c + d * d),
            'That squares every entry: the trace of A transposed times A.',
          ),
        (Frac(pw(det)), 'That\'s det(A$sup), the product, not the sum.'),
        (Frac(n * t), 'That multiplies the trace by $n.'),
      ],
      steps: [
        'Trace ${signed(t)} and det ${signed(det)} give eigenvalues '
            '${signed(l1)} and ${signed(l2)}.',
        'A$sup has eigenvalues ${_p(l1)}$sup = ${signed(pw(l1))} and '
            '${_p(l2)}$sup = ${signed(pw(l2))}.',
        'Trace of A$sup = ${signed(pw(l1))} + ${_p(pw(l2))} = ${signed(ans)}.',
      ],
      insight: 'Right: powers act on eigenvalues, and the trace adds them.',
      params: {'A': m, 'n': n},
    );
  }

  /// A projection: P² = P, so every power is P.
  _Draft _projection(Random rng) {
    late List<int> u, w;
    late List<List<int>> m;
    do {
      u = [_r(rng, -2, 3), _r(rng, -2, 3)];
      w = [_r(rng, -2, 3), _r(rng, -2, 3)];
      m = [
        [u[0] * w[0], u[0] * w[1]],
        [u[1] * w[0], u[1] * w[1]],
      ];
    } while (u[0] * w[0] + u[1] * w[1] != 1 ||
        m.any((r) => r.any((e) => e.abs() > 4)) ||
        (m[0][1] == 0 && m[1][0] == 0) ||
        m.every((r) => r.every((e) => e.abs() < 2)));
    // Mostly an entry that isn't 0 or 1: those match too many slips.
    final cells = [
      for (var pos = 0; pos < 4; pos++)
        if (m[pos ~/ 2][pos % 2] != 0) pos,
    ];
    final bigger = [
      for (final pos in cells)
        if (m[pos ~/ 2][pos % 2] != 1) pos,
    ];
    final pos = _pick(rng, rng.nextInt(4) == 0 ? cells : bigger);
    final i = pos ~/ 2, j = pos % 2;
    final e = m[i][j];
    final n = _pick(rng, const [3, 4, 5]);
    final sup = _sup[n]!;
    var power = 1;
    for (var t = 0; t < n; t++) {
      power *= e;
    }
    final rowRow = m[i][0] * m[j][0] + m[i][1] * m[j][1];
    return _Draft(
      scene: MatrixScene(
        lines: ['P = ${matSource(m)}'],
        caption: 'P flattens the plane onto a line',
        picture: MatrixPicture(m: m, title: 'The unit square under P'),
        pictureOnCard: true,
      ),
      question: 'What is the ${_corner[pos]} entry of P$sup?',
      hint: 'Work out P² first.',
      value: Frac(e),
      unit: Frac.one,
      traps: [
        (Frac(power), 'Matrix powers don\'t work entry by entry.'),
        (Frac(n * e), 'Powers don\'t multiply the entries by $n.'),
        (Frac.one, '1 is an eigenvalue of P, not this entry.'),
        (Frac.zero, 'P has eigenvalues 1 and 0, but P$sup is P, not 0.'),
        (
          Frac(rowRow),
          'That squares P row by row. Row by column gives P² = P.',
        ),
      ],
      steps: [
        'P² = P × P = ${matPlain(m)}: P again.',
        'So every power is P: P$sup = P.',
        'Its ${_corner[pos]} entry is ${signed(e)}.',
      ],
      insight: 'Right: P² = P, so projecting twice changes nothing.',
      params: {'P': m, 'pos': pos, 'n': n},
    );
  }

  /// ax + by = e, cx + dy = f: x or y.
  _Draft _system(Random rng) {
    late int a, b, c, d, x, y, det;
    do {
      a = _nz(rng, -2, 5);
      b = _nz(rng, -2, 5);
      c = _nz(rng, -2, 5);
      d = _nz(rng, -2, 5);
      x = _r(rng, -3, 5);
      y = _r(rng, -3, 5);
      det = a * d - b * c;
    } while (det == 0 || x == y || a * d + b * c == 0);
    final e = a * x + b * y, f = c * x + d * y;
    final m = [
      [a, b],
      [c, d],
    ];
    final askX = rng.nextBool();
    final ans = askX ? x : y;
    final top = askX ? d * e - b * f : a * f - c * e;
    return _Draft(
      scene: MatrixScene(
        lines: [
          '${matSource(m)} ${matSource([
            ['x'],
            ['y'],
          ])} = ${vecSource([e, f])}',
        ],
        caption: 'Two equations, two unknowns',
      ),
      question: 'What is ${askX ? 'x' : 'y'}?',
      hint: 'Use A⁻¹, or take one equation from the other.',
      value: Frac(ans),
      unit: Frac.one,
      traps: [
        (Frac(askX ? y : x), 'That\'s ${askX ? 'y' : 'x'}.'),
        (Frac(top), 'You forgot to divide by det A = ${signed(det)}.'),
        (
          Frac(top, a * d + b * c),
          'That divides by ad + bc. det A is ad − bc.',
        ),
        (
          Frac(askX ? a * e - b * f : d * f - c * e, det),
          'In A⁻¹ the diagonal entries a and d swap places.',
        ),
        (
          Frac(askX ? d * e - c * f : a * f - b * e, det),
          'In A⁻¹, b and c stay in their places: a transpose slip.',
        ),
      ],
      steps: [
        'det A = ${signed(a)} × ${_p(d)} − ${_p(b)} × ${_p(c)} = '
            '${signed(det)}.',
        'A⁻¹ = (1/${signed(det)}) × ${matPlain([
          [d, -b],
          [-c, a],
        ])}.',
        askX
            ? 'x = (${signed(d)} × ${_p(e)} − ${_p(b)} × ${_p(f)}) ÷ '
                  '${_p(det)} = ${signed(x)}.'
            : 'y = (${signed(a)} × ${_p(f)} − ${_p(c)} × ${_p(e)}) ÷ '
                  '${_p(det)} = ${signed(y)}.',
      ],
      insight: 'Right: (x, y) = A⁻¹ × ${vecPlain([e, f])}.',
      params: {'A': m, 'e': e, 'f': f, 'askX': askX},
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
    this.decimal = false,
    this.fits,
    this.answerSource,
    this.wrong = const [],
  }) : unit = unit ?? Frac.one;

  final MatrixScene scene;
  final String question;
  final String hint;
  final List<String> steps;
  final String insight;
  final Map<String, Object> params;

  /// Numeric questions: the answer, named mistakes, the near-miss step.
  final Frac? value;
  final List<(Frac, String)> traps;
  final Frac unit;

  /// Written as decimals ("0.48") rather than fractions.
  final bool decimal;

  /// Which numbers make sense as options.
  final bool Function(Frac)? fits;

  /// Pick questions: the answer and the wrong options with their slips.
  final String? answerSource;
  final List<(String, String)> wrong;
}
