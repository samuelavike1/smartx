import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/coin_race/coin_puzzle.dart';
import 'package:smartx/games/odds_on/odds_math.dart';

/// The state after some flips: the longest ending that starts a pattern.
String state(String seen, List<String> patterns) {
  for (var k = seen.length; k > 0; k--) {
    final end = seen.substring(seen.length - k);
    if (patterns.any((p) => p.startsWith(end))) return end;
  }
  return '';
}

/// Average flips until [p], by repeatedly updating every state's value
/// (no overlap formula).
double markovWait(String p, double heads) {
  final states = [for (var k = 0; k < p.length; k++) p.substring(0, k)];
  final v = {for (final s in states) s: 0.0};
  for (var it = 0; it < 20000; it++) {
    for (final s in states) {
      var e = 1.0;
      for (final (c, pr) in [('H', heads), ('T', 1 - heads)]) {
        final next = state(s + c, [p]);
        if (next != p) e += pr * v[next]!;
      }
      v[s] = e;
    }
  }
  return v['']!;
}

/// The chance [a] turns up before [b] on a fair coin, the same way.
double markovRace(String a, String b) {
  final states = <String>{''};
  for (final p in [a, b]) {
    for (var k = 1; k < p.length; k++) {
      states.add(p.substring(0, k));
    }
  }
  final v = {for (final s in states) s: 0.0};
  for (var it = 0; it < 5000; it++) {
    for (final s in states) {
      var w = 0.0;
      for (final c in ['H', 'T']) {
        final seen = s + c;
        if (seen.endsWith(a)) {
          w += 0.5;
        } else if (!seen.endsWith(b)) {
          w += 0.5 * v[state(seen, [a, b])]!;
        }
      }
      v[s] = w;
    }
  }
  return v['']!;
}

List<String> allPatterns(int n) => [
  for (var i = 0; i < 1 << n; i++)
    [for (var j = n - 1; j >= 0; j--) (i >> j) & 1 == 1 ? 'H' : 'T'].join(),
];

void main() {
  const gen = CoinGenerator();
  final half = Frac(1, 2);

  test('the classic numbers', () {
    expect(waitFor('HH', half), Frac(6));
    expect(waitFor('HT', half), Frac(4));
    expect(waitFor('HHH', half), Frac(14));
    expect(waitFor('HTH', half), Frac(10));
    expect(waitFor('HTHT', half), Frac(20));
    expect(raceChance('HH', 'TH'), Frac(1, 4));
    expect(raceChance('HHT', 'THH'), Frac(1, 4));
    expect(raceChance('HH', 'HT'), half);
    expect(penney('HHT'), 'THH');
    expect(waitFor('HH', Frac(2, 3)), Frac(15, 4));
  });

  test('every wait matches a state-by-state solve', () {
    for (final heads in [half, Frac(2, 3), Frac(1, 3)]) {
      for (var n = 1; n <= 4; n++) {
        for (final p in allPatterns(n)) {
          expect(
            waitFor(p, heads).value,
            closeTo(markovWait(p, heads.value), 1e-6),
            reason: '$p at heads $heads',
          );
        }
      }
    }
  });

  test('every race matches a state-by-state solve', () {
    for (final n in [2, 3]) {
      for (final a in allPatterns(n)) {
        for (final b in allPatterns(n)) {
          if (a == b) continue;
          expect(
            raceChance(a, b).value,
            closeTo(markovRace(a, b), 1e-6),
            reason: '$a vs $b',
          );
        }
      }
    }
  });

  test('Penney\'s reply is the best pattern against every friend', () {
    for (final f in allPatterns(3)) {
      final best = penney(f);
      for (final x in allPatterns(3)) {
        if (x == f || x == best) continue;
        expect(
          raceChance(best, f) > raceChance(x, f),
          isTrue,
          reason: '$f: $x',
        );
      }
    }
  });

  test('every level asks fair questions with named traps', () {
    final kinds = <CoinKind>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 40; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        expect(q.options, hasLength(4));
        expect(q.options.toSet(), hasLength(4));
        expect(q.options, contains(q.answer));
        expect(q.traps.map((t) => t.label), isNot(contains(q.answer)));
        expect(q.steps, hasLength(3));
        for (final o in q.options) {
          expect(q.feedbackFor(o), isNotEmpty);
        }
        expect(q.tried, isNotEmpty);
        switch (q.kind) {
          case CoinKind.wait:
            expect(q.answer, flipText(waitFor(q.patterns.single, q.heads)));
            expect(q.fair, level != 7);
          case CoinKind.race:
            expect(q.answer, '${raceChance(q.patterns[0], q.patterns[1])}');
          case CoinKind.pick:
            expect(q.answer, penney(q.patterns.single));
        }
      }
    }
    expect(kinds, CoinKind.values.toSet());
  });

  test('the board\'s question: waiting for HH', () {
    for (var seed = 0; seed < 200; seed++) {
      final q = gen.generate(level: 1, seed: seed);
      if (q.patterns.single != 'HH' || !q.options.contains('4')) continue;
      expect(q.answer, '6');
      expect(
        q.steps.first,
        'Find where HH\'s start matches its end: after 1 flip (H) and after '
        '2 (HH).',
      );
      expect(q.steps[1], 'A match k flips long adds 2 to the power k: 2 + 4.');
      expect(q.feedbackFor('4'), startsWith('4 is 1 ÷ the chance of HH.'));
      return;
    }
    fail('no HH question offering 4');
  });

  test('the right answer is not given away by its size', () {
    double value(String s) {
      final p = s.split('/');
      return p.length == 2
          ? int.parse(p[0]) / int.parse(p[1])
          : double.parse(s);
    }

    for (var level = 1; level <= 10; level++) {
      final at = List.filled(4, 0);
      for (var seed = 0; seed < 300; seed++) {
        final q = gen.generate(level: level, seed: seed);
        if (q.kind == CoinKind.pick) continue;
        final values = q.options.map(value).toList();
        expect(values, orderedEquals([...values]..sort()));
        at[q.answerIndex]++;
      }
      final total = at.fold(0, (a, b) => a + b);
      if (total == 0) continue;
      for (final c in at) {
        expect(
          c / total,
          inInclusiveRange(0.15, 0.35),
          reason: 'level $level: $at',
        );
      }
    }
  });
}
