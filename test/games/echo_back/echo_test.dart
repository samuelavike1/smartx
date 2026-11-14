import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/echo_back/echo_puzzle.dart';

EchoBlock blockOf(List<int> cells, {int n = 2}) => EchoBlock(
  level: 3,
  seed: 0,
  n: n,
  dual: false,
  interval: const Duration(milliseconds: 2200),
  items: [for (final c in cells) EchoItem(c, 0)],
);

void main() {
  const generator = EchoGenerator();

  test('same level and seed produce the same block', () {
    final a = generator.generate(level: 7, seed: 5);
    final b = generator.generate(level: 7, seed: 5);
    expect(
      [for (final i in a.items) (i.cell, i.colour)],
      [for (final i in b.items) (i.cell, i.colour)],
    );
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level blocks have a fair number of matches', () {
      final d = EchoDifficulty.forLevel(level);
      for (var seed = 0; seed < 150; seed++) {
        final b = generator.generate(level: level, seed: seed);
        expect(b.n, d.n);
        expect(b.dual, d.dual);
        expect(b.length, d.n + EchoDifficulty.steps);
        expect(b.items.every((i) => i.cell >= 0 && i.cell < 9), isTrue);
        final sq = b.targetCount(EchoChannel.square);
        if (d.dual) {
          expect(sq, inInclusiveRange(3, 5));
          expect(b.targetCount(EchoChannel.colour), inInclusiveRange(3, 5));
        } else {
          expect(sq, inInclusiveRange(4, 6));
          expect(b.targetCount(EchoChannel.colour), 0);
        }
        // Warm-up steps can never be matches.
        for (var i = 0; i < b.n; i++) {
          expect(b.isTarget(i, EchoChannel.square), isFalse);
        }
      }
    });
  }

  test('perfect play passes; scoring counts hits, misses and false taps', () {
    // 2-back: matches at steps 2 (=0), 4 (=2), 6 (=4).
    final b = blockOf([3, 5, 3, 1, 3, 7, 3, 0]);
    final targets = {2, 4, 6};
    expect({
      for (var i = 0; i < b.length; i++)
        if (b.isTarget(i, EchoChannel.square)) i,
    }, targets);

    final perfect = b.evaluate(squareTaps: targets);
    expect(perfect.hits, 3);
    expect(perfect.passed, isTrue);
    expect(b.explain(perfect), 'Caught all 3 matches with no false taps.');

    final sloppy = b.evaluate(squareTaps: {2, 6, 7});
    expect(sloppy.hits, 2);
    expect(sloppy.misses.single.$1, 4);
    expect(sloppy.falseTaps.single.$1, 7);
    expect(sloppy.passed, isFalse, reason: '2 of 3 is below 75%');
    expect(sloppy.outcomes[4], StepOutcome.miss);
    expect(sloppy.outcomes[7], StepOutcome.falseTap);
    expect(sloppy.outcomes[0], StepOutcome.warmup);
    expect(
      b.explain(sloppy),
      'You missed step 5: it lit the same square as step 3. '
      '2 of 3 matches caught, 1 false tap.',
    );
  });

  test('two false taps fail a single-mode block even with every hit', () {
    final b = blockOf([3, 5, 3, 1, 3, 7, 3, 0]);
    expect(b.evaluate(squareTaps: {2, 4, 6, 7}).passed, isTrue);
    expect(b.evaluate(squareTaps: {2, 4, 6, 7, 5}).passed, isFalse);
  });

  test('dual mode judges square and colour separately', () {
    final b = EchoBlock(
      level: 7,
      seed: 0,
      n: 1,
      dual: true,
      interval: const Duration(milliseconds: 2400),
      items: const [EchoItem(0, 0), EchoItem(0, 1), EchoItem(4, 1)],
    );
    // Step 1: same square (0), new colour. Step 2: new square, same colour.
    expect(b.isTarget(1, EchoChannel.square), isTrue);
    expect(b.isTarget(1, EchoChannel.colour), isFalse);
    expect(b.isTarget(2, EchoChannel.colour), isTrue);
    final r = b.evaluate(squareTaps: {1}, colourTaps: {2});
    expect((r.hits, r.targets, r.passed), (2, 2, true));
  });
}
