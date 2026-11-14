import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/count_it/count_puzzle.dart';

/// Every ordering of [xs] (as lists).
Iterable<List<int>> perms(List<int> xs) sync* {
  if (xs.isEmpty) {
    yield [];
    return;
  }
  for (var i = 0; i < xs.length; i++) {
    final rest = [...xs]..removeAt(i);
    for (final p in perms(rest)) {
      yield [xs[i], ...p];
    }
  }
}

/// Every sequence of [len] values from 0..a-1.
Iterable<List<int>> tuples(int a, int len) sync* {
  if (len == 0) {
    yield [];
    return;
  }
  for (final t in tuples(a, len - 1)) {
    for (var x = 0; x < a; x++) {
      yield [...t, x];
    }
  }
}

/// Every subset of 0..n-1, as bit masks.
Iterable<int> masks(int n) sync* {
  for (var m = 0; m < 1 << n; m++) {
    yield m;
  }
}

int bits(int m) => m == 0 ? 0 : (m & 1) + bits(m >> 1);

/// Counts the answer by listing every case, with no formulas.
int recount(CountQuestion q) {
  final p = q.params;
  switch (q.kind) {
    case CountKind.lineUp:
      return perms(List.generate(p['n']!, (i) => i)).length;
    case CountKind.jobs:
      return tuples(
        p['n']!,
        p['k']!,
      ).where((t) => t.toSet().length == t.length).length;
    case CountKind.handshakes:
      return masks(p['n']!).where((m) => bits(m) == 2).length;
    case CountKind.choose:
      return masks(p['n']!).where((m) => bits(m) == p['k']).length;
    case CountKind.codeRepeat:
      return tuples(p['a']!, p['len']!).length;
    case CountKind.codeNoRepeat:
      return tuples(
        p['a']!,
        p['len']!,
      ).where((t) => t.toSet().length == t.length).length;
    case CountKind.subsets:
      return masks(p['n']!).length;
    case CountKind.tiles:
      final tiles = [
        for (final (i, c) in q.counts.indexed)
          for (var j = 0; j < c; j++) i,
      ];
      return perms(tiles).map((t) => t.join()).toSet().length;
    case CountKind.grid:
      final w = p['w']!, h = p['h']!;
      // 0 = right, 1 = up; a route has exactly h ups.
      return tuples(
        2,
        w + h,
      ).where((t) => t.where((m) => m == 1).length == h).length;
    case CountKind.roundTable:
      final n = p['n']!;
      final seen = <String>{};
      for (final s in perms(List.generate(n, (i) => i))) {
        // Turn the table until person 0 is in seat 0.
        final at = s.indexOf(0);
        seen.add([for (var i = 0; i < n; i++) s[(at + i) % n]].join(','));
      }
      return seen.length;
    case CountKind.atLeastOne:
      return tuples(p['a']!, p['len']!).where((t) => t.contains(0)).length;
    case CountKind.divisible:
      final n = p['n']!;
      return [
        for (var i = 1; i <= n; i++)
          if (i % p['p']! == 0 || i % p['q']! == 0) i,
      ].length;
    case CountKind.committee:
      final m = p['m']!, w = p['w']!;
      // Bits below m are seniors; the rest are juniors.
      return masks(m + w).where((x) => bits(x) == 3 && (x >> m) != 0).length;
    case CountKind.share:
      final s = p['s']!, c = p['c']!;
      return tuples(
        s + 1,
        c,
      ).where((t) => t.fold(0, (a, b) => a + b) == s).length;
  }
}

void main() {
  const gen = CountGenerator();

  test('every answer matches a full listing, at every level', () {
    final kindsSeen = <CountKind>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 40; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kindsSeen.add(q.kind);
        expect(q.answer, recount(q), reason: '${q.kind} ${q.params}');
        expect(q.options, hasLength(4));
        expect(q.options.toSet(), hasLength(4));
        expect(q.options, contains(q.answer));
        expect(q.options.every((o) => o > 0), isTrue);
        expect(q.steps, hasLength(3));
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty);
        }
        // Each wrong option is a named trap, not filler, nearly always.
        final named = q.traps
            .where((t) => !t.why.startsWith('Count it again'))
            .length;
        expect(named, greaterThanOrEqualTo(2), reason: '${q.kind} ${q.params}');
      }
    }
    expect(kindsSeen, CountKind.values.toSet());
  });

  test('grid traps are the mistakes they name', () {
    // Spot checks against hand counts: the named grid mistakes, or the
    // shared fallbacks (twice, half, off by one) when a side runs short.
    for (var seed = 0; seed < 40; seed++) {
      final q = gen.generate(level: 6, seed: seed);
      expect(q.kind, CountKind.grid);
      final w = q.params['w']!, h = q.params['h']!, a = q.answer;
      expect(
        q.traps.map((t) => t.value),
        everyElement(
          isIn([
            w * h,
            ipow(2, w + h),
            fact(w + h),
            w + h,
            a * 2,
            a ~/ 2,
            a + 1,
            a - 1,
          ]),
        ),
      );
    }
  });

  test('the right answer is not given away by its size', () {
    // Each size rank (smallest … largest) gets 15–35% of right answers,
    // overall and within every level.
    for (var level = 0; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (final l
          in level == 0 ? [for (var i = 1; i <= 10; i++) i] : [level]) {
        for (var seed = 0; seed < 300; seed++) {
          final q = gen.generate(level: l, seed: seed);
          expect(q.options, orderedEquals([...q.options]..sort()));
          at[q.options.indexOf(q.answer)]++;
        }
      }
      final total = at.fold(0, (a, b) => a + b);
      for (final c in at) {
        expect(
          c / total,
          inInclusiveRange(0.15, 0.35),
          reason: 'level ${level == 0 ? 'all' : level}: $at',
        );
      }
    }
  });

  test('the board\'s tiles: A A B B C', () {
    for (var seed = 0; seed < 400; seed++) {
      final q = gen.generate(level: 5, seed: seed);
      if (q.counts.length != 3 || q.counts[0] != 2 || q.counts[1] != 2) {
        continue;
      }
      expect(q.answer, 30);
      expect(
        q.feedbackFor(120),
        '120 treats matching tiles as different. Swapping two A\'s doesn\'t '
        'make a new row.',
      );
      expect(
        q.steps[1],
        'Swapping the two A\'s, or the two B\'s, gives the same row: each '
        'row was counted 2 × 2 = 4 times.',
      );
      return;
    }
    fail('no A A B B C question in 400 seeds');
  });

  test('numbers read with commas', () {
    expect(fmt(10000), '10,000');
    expect(fmt(720), '720');
    expect(fmt(1234567), '1,234,567');
  });
}
