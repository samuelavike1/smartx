import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/arrow_focus/arrow_puzzle.dart';

void main() {
  const generator = ArrowGenerator();

  test('same level and seed produce the same block', () {
    final a = generator.generate(level: 9, seed: 5);
    final b = generator.generate(level: 9, seed: 5);
    expect(
      [for (final t in a.trials) (t.middle, t.flank, t.count)],
      [for (final t in b.trials) (t.middle, t.flank, t.count)],
    );
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level blocks are fair', () {
      final d = ArrowDifficulty.forLevel(level);
      for (var seed = 0; seed < 200; seed++) {
        final b = generator.generate(level: level, seed: seed);
        expect(b.length, ArrowDifficulty.rows);
        expect(b.limit.inMilliseconds, d.limitMs);
        expect(b.fourWays, d.fourWays);
        expect(
          b.trials.where((t) => t.conflict).length,
          greaterThanOrEqualTo(3),
        );
        expect(
          b.trials.where((t) => !t.conflict).length,
          greaterThanOrEqualTo(2),
        );
        for (final t in b.trials) {
          expect(t.count, d.count);
          expect(t.count.isOdd, isTrue, reason: 'a row needs a middle');
          expect(d.directions, contains(t.middle));
          expect(d.directions, contains(t.flank));
        }
        final verticals = b.trials.where((t) => t.middle.vertical).length;
        if (d.fourWays) {
          expect(verticals, greaterThanOrEqualTo(3));
        } else {
          expect(verticals, 0, reason: 'left and right only below level 7');
          for (final dir in [ArrowDir.left, ArrowDir.right]) {
            expect(
              b.trials.where((t) => t.middle == dir).length,
              greaterThanOrEqualTo(3),
            );
          }
        }
      }
    });
  }

  test('the middle arrow is the answer', () {
    const t = ArrowTrial(ArrowDir.left, ArrowDir.right, 5);
    expect(t.answer, ArrowDir.left);
    expect(t.conflict, isTrue);
    expect(t.arrows, [
      ArrowDir.right,
      ArrowDir.right,
      ArrowDir.left,
      ArrowDir.right,
      ArrowDir.right,
    ]);
    expect(const ArrowTrial(ArrowDir.up, ArrowDir.up, 7).conflict, isFalse);
  });

  test('scoring, distraction cost and explanations', () {
    const b = ArrowBlock(
      level: 5,
      seed: 0,
      limit: Duration(milliseconds: 2000),
      fourWays: false,
      trials: [
        ArrowTrial(ArrowDir.right, ArrowDir.right, 7), // agree
        ArrowTrial(ArrowDir.left, ArrowDir.right, 7), // disagree
        ArrowTrial(ArrowDir.right, ArrowDir.left, 7), // disagree
      ],
    );
    final answers = [
      const ArrowAnswer(ArrowDir.right, Duration(milliseconds: 580)),
      const ArrowAnswer(ArrowDir.right, Duration(milliseconds: 700)), // wrong
      const ArrowAnswer(ArrowDir.right, Duration(milliseconds: 710)),
    ];
    final r = b.evaluate(answers);
    expect(r.right, 2);
    expect(r.correct, [true, false, true]);
    expect(r.calmAvg, closeTo(0.58, 1e-9));
    expect(r.conflictAvg, closeTo(0.71, 1e-9));
    expect(r.conflictCost, closeTo(0.13, 1e-9));
    expect(
      b.explain(r, answers),
      'Row 2: the middle arrow pointed left while the others pointed right, '
      'so the answer was left. Rows where the arrows disagreed took 0.13 s '
      'longer.',
    );

    final timedOut = [
      const ArrowAnswer(null, Duration(seconds: 2)),
      ...answers.skip(1),
    ];
    expect(
      b.explain(b.evaluate(timedOut), timedOut),
      startsWith('Row 1 ran out of time: all the arrows pointed right.'),
    );
  });

  test('a block passes at 10 of 12', () {
    final b = generator.generate(level: 1, seed: 1);
    List<ArrowAnswer> rightFor(int n) => [
      for (final (i, t) in b.trials.indexed)
        ArrowAnswer(i < n ? t.answer : null, const Duration(seconds: 1)),
    ];
    expect(b.evaluate(rightFor(10)).passed, isTrue);
    expect(b.evaluate(rightFor(9)).passed, isFalse);
  });

  test(
    'swipes map to directions; diagonal and off-mode swipes are ignored',
    () {
      expect(
        ArrowDir.fromSwipe(const Offset(-80, 10), fourWays: false),
        ArrowDir.left,
      );
      expect(
        ArrowDir.fromSwipe(const Offset(90, -20), fourWays: false),
        ArrowDir.right,
      );
      expect(ArrowDir.fromSwipe(const Offset(5, -90), fourWays: false), isNull);
      expect(
        ArrowDir.fromSwipe(const Offset(5, -90), fourWays: true),
        ArrowDir.up,
      );
      expect(
        ArrowDir.fromSwipe(const Offset(-4, 70), fourWays: true),
        ArrowDir.down,
      );
      expect(ArrowDir.fromSwipe(const Offset(60, 60), fourWays: true), isNull);
    },
  );
}
