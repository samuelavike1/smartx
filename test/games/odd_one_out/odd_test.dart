import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/odd_one_out/odd_one_out_game.dart';
import 'package:smartx/games/odd_one_out/odd_puzzle.dart';

/// The value of [f] on [t], for comparing tiles one feature at a time.
Object _value(OddTile t, OddFeature f) => switch (f) {
  OddFeature.colour => t.tint,
  OddFeature.shape => t.shape,
  OddFeature.turn => t.turn,
  OddFeature.size => t.scale,
};

void main() {
  const generator = OddGenerator();

  test('same level and seed produce the same block', () {
    final a = generator.generate(level: 9, seed: 4);
    final b = generator.generate(level: 9, seed: 4);
    expect(
      [
        for (final t in a.trials)
          (t.odd, t.feature, t.tiles[t.odd].description),
      ],
      [
        for (final t in b.trials)
          (t.odd, t.feature, t.tiles[t.odd].description),
      ],
    );
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level: exactly one tile breaks the rule, one way only', () {
      final d = OddDifficulty.forLevel(level);
      for (var seed = 0; seed < 150; seed++) {
        final b = generator.generate(level: level, seed: seed);
        expect(b.length, OddDifficulty.grids);
        expect(b.limit.inMilliseconds, d.limitMs);
        expect(
          b.trials.where((t) => !t.conflict).length,
          greaterThanOrEqualTo(3),
        );
        expect(
          b.trials.where((t) => t.conflict).length,
          greaterThanOrEqualTo(3),
        );

        int? last;
        for (final t in b.trials) {
          expect(t.side, d.side);
          expect(t.tiles, hasLength(d.side * d.side));
          expect(d.features, contains(t.feature));
          expect(
            t.odd,
            isNot(last),
            reason: 'odd one never in the same spot twice',
          );
          last = t.odd;

          final odd = t.tiles[t.odd];
          final others = [
            for (final (i, x) in t.tiles.indexed)
              if (i != t.odd) x,
          ];
          // The odd one's feature value is unique, and the rest agree on it
          // (with mixed tints the rest come in two colours, never orange).
          final rest = {for (final x in others) _value(x, t.feature)};
          if (!(t.feature == OddFeature.colour && d.mixedTints)) {
            expect(rest, hasLength(1), reason: '${t.feature} must be shared');
          }
          expect(rest, isNot(contains(_value(odd, t.feature))));
          // Every other feature gives the odd one away no more than any tile.
          for (final f in OddFeature.values.where((f) => f != t.feature)) {
            if (f == OddFeature.colour && d.mixedTints) {
              expect(odd.tint, isNot(OddTint.orange));
              continue;
            }
            expect(
              _value(odd, f),
              _value(others.first, f),
              reason: 'odd by ${t.feature} only, not $f',
            );
          }
          if (d.mixedTints) {
            final tints = {for (final x in others) x.tint};
            expect(tints, {OddTint.ink, OddTint.blue});
          } else {
            expect({for (final x in others) x.tint}, {OddTint.ink});
          }
          if (t.feature == OddFeature.colour) {
            expect(odd.tint, OddTint.orange);
          }
          if (t.feature == OddFeature.size) {
            expect(odd.scale, d.smallScale);
          }
        }
      }
    });
  }

  test('scoring, search cost and explanations', () {
    const ink = OddTile(shape: OddShape.triangle, tint: OddTint.ink);
    const down = OddTile(shape: OddShape.triangle, tint: OddTint.ink, turn: 2);
    const orange = OddTile(shape: OddShape.triangle, tint: OddTint.orange);
    const b = OddBlock(
      level: 5,
      seed: 0,
      limit: Duration(milliseconds: 3000),
      features: [OddFeature.colour, OddFeature.turn],
      trials: [
        OddTrial(
          side: 2,
          tiles: [ink, orange, ink, ink],
          odd: 1,
          feature: OddFeature.colour,
        ),
        OddTrial(
          side: 2,
          tiles: [ink, ink, ink, down],
          odd: 3,
          feature: OddFeature.turn,
        ),
        OddTrial(
          side: 2,
          tiles: [down, ink, ink, ink],
          odd: 0,
          feature: OddFeature.turn,
        ),
      ],
    );
    final answers = [
      const OddAnswer(1, Duration(milliseconds: 740)),
      const OddAnswer(2, Duration(milliseconds: 1500)), // wrong
      const OddAnswer(0, Duration(milliseconds: 1620)),
    ];
    final r = b.evaluate(answers);
    expect(r.correct, [true, false, true]);
    expect(r.calmAvg, closeTo(0.74, 1e-9));
    expect(r.conflictAvg, closeTo(1.62, 1e-9));
    expect(r.conflictCost, closeTo(0.88, 1e-9));
    expect(b.firstMiss(r), 1);
    expect(
      b.explain(r, answers),
      'Grid 2: the odd one was in row 2, column 2, the only triangle pointing '
      'down. Odd shapes, turns and sizes took 0.88 s longer.',
    );

    final timedOut = [const OddAnswer(null, Duration(seconds: 3))];
    expect(
      b.mistake(b.evaluate(timedOut), timedOut),
      'Grid 1 ran out of time: the odd one was in row 1, column 2, the only '
      'orange one.',
    );
  });

  test('a block passes at 10 of 12', () {
    final b = generator.generate(level: 1, seed: 1);
    List<OddAnswer> rightFor(int n) => [
      for (final (i, t) in b.trials.indexed)
        OddAnswer(i < n ? t.answer : null, const Duration(seconds: 1)),
    ];
    expect(b.evaluate(rightFor(10)).passed, isTrue);
    expect(b.evaluate(rightFor(9)).passed, isFalse);
  });

  test('tiles describe themselves for screen readers', () {
    const t = OddTile(
      shape: OddShape.triangle,
      tint: OddTint.orange,
      turn: 1,
      scale: 0.8,
    );
    expect(t.description, 'small orange triangle pointing right');
    expect(
      const OddTile(shape: OddShape.circle, tint: OddTint.ink).description,
      'black circle',
    );
    expect(
      oddWays(OddDifficulty.forLevel(5).features),
      'colour, shape, turn or size',
    );
  });
}
