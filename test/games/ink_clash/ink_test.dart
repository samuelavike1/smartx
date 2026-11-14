import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/ink_clash/ink_puzzle.dart';

void main() {
  const generator = InkGenerator();

  test('same level and seed produce the same block', () {
    final a = generator.generate(level: 8, seed: 3);
    final b = generator.generate(level: 8, seed: 3);
    expect(
      [for (final t in a.trials) (t.word, t.ink, t.rule)],
      [for (final t in b.trials) (t.word, t.ink, t.rule)],
    );
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level blocks mix matching and clashing words', () {
      final d = InkDifficulty.forLevel(level);
      for (var seed = 0; seed < 200; seed++) {
        final b = generator.generate(level: level, seed: seed);
        expect(b.length, InkDifficulty.words);
        expect(b.limit.inMilliseconds, d.limitMs);
        expect(b.trials.where((t) => t.clash).length, greaterThanOrEqualTo(4));
        expect(b.trials.where((t) => !t.clash).length, greaterThanOrEqualTo(2));
        final flips = b.trials.where((t) => t.rule == InkRule.word).length;
        if (d.flipShare == 0) {
          expect(flips, 0, reason: 'no rule flips below level 7');
        } else {
          expect(flips, inInclusiveRange(2, 6));
        }
      }
    });
  }

  test('the answer follows the rule', () {
    const ink = InkTrial(InkColour.green, InkColour.pink, InkRule.ink);
    const word = InkTrial(InkColour.green, InkColour.pink, InkRule.word);
    expect(ink.answer, InkColour.pink);
    expect(word.answer, InkColour.green);
    expect(ink.clash, isTrue);
  });

  test('scoring, clash cost and explanations', () {
    const b = InkBlock(
      level: 7,
      seed: 0,
      limit: Duration(milliseconds: 2600),
      trials: [
        InkTrial(InkColour.blue, InkColour.blue, InkRule.ink), // match
        InkTrial(InkColour.green, InkColour.pink, InkRule.ink), // clash
        InkTrial(InkColour.orange, InkColour.blue, InkRule.word), // clash
      ],
    );
    final answers = [
      const InkAnswer(InkColour.blue, Duration(milliseconds: 900)),
      const InkAnswer(InkColour.green, Duration(milliseconds: 1400)), // wrong
      const InkAnswer(InkColour.orange, Duration(milliseconds: 1300)),
    ];
    final r = b.evaluate(answers);
    expect(r.right, 2);
    expect(r.correct, [true, false, true]);
    expect(r.calmAvg, closeTo(0.9, 1e-9));
    expect(r.conflictAvg, closeTo(1.3, 1e-9));
    expect(r.conflictCost, closeTo(0.4, 1e-9));
    expect(
      b.explain(r, answers),
      'Word 2 said GREEN in pink ink, and the cue said INK, so the answer '
      'was pink. Clashing words took 0.40 s longer.',
    );

    final timedOut = [answers[0], const InkAnswer(null, Duration(seconds: 3))];
    expect(
      b.explain(b.evaluate(timedOut), timedOut),
      startsWith('Word 2 said GREEN in pink ink and ran out of time'),
    );
  });

  test('a block passes at 10 of 12', () {
    final b = generator.generate(level: 1, seed: 1);
    List<InkAnswer> rightFor(int n) => [
      for (final (i, t) in b.trials.indexed)
        InkAnswer(i < n ? t.answer : null, const Duration(seconds: 1)),
    ];
    expect(b.evaluate(rightFor(10)).passed, isTrue);
    expect(b.evaluate(rightFor(9)).passed, isFalse);
  });
}
