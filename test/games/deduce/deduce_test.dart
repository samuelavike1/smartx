import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/deduce/deduce_puzzle.dart';

ClueKind kindOf(Clue c) => switch (c) {
      IsAt() => ClueKind.at,
      NotAt() => ClueKind.notAt,
      LeftOf() => ClueKind.leftOf,
      NextTo() => ClueKind.nextTo,
      NotNextTo() => ClueKind.notNextTo,
      Between() => ClueKind.between,
    };

void main() {
  const generator = DeduceGenerator();

  test('same level and seed produce the same puzzle', () {
    final a = generator.generate(level: 7, seed: 11);
    final b = generator.generate(level: 7, seed: 11);
    expect(a.solution, b.solution);
    expect(a.clues.map((c) => c.text), b.clues.map((c) => c.text));
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level: one answer, no spare clues, right clue types', () {
      final d = DeduceDifficulty.forLevel(level);
      for (var seed = 0; seed < 120; seed++) {
        final p = generator.generate(level: level, seed: seed);
        expect(p.size, d.count);
        expect(p.tray.toSet(), p.solution.toSet());
        expect(p.tray, isNot(p.solution), reason: 'tray must not give it away');

        expect(p.clues.every((c) => c.holds(p.solution)), isTrue,
            reason: 'every clue is true for the solution (seed $seed)');
        expect(countSolutions(p.solution, p.clues), 1,
            reason: 'exactly one answer (seed $seed)');
        for (final c in p.clues) {
          final without = [...p.clues]..remove(c);
          expect(countSolutions(p.solution, without), greaterThan(1),
              reason: '"${c.text}" is needed (seed $seed)');
        }
        // The safety net may pin shapes, but otherwise kinds follow the level.
        for (final c in p.clues) {
          expect(d.kinds.contains(kindOf(c)) || c is IsAt, isTrue);
        }
      }
    });
  }

  test('clue wording', () {
    const n = 4;
    expect(const IsAt(DeduceItem.square, 3, n).text, 'The square is last.');
    expect(const NotAt(DeduceItem.triangle, 1, n).text, 'The triangle is not second.');
    expect(const LeftOf(DeduceItem.star, DeduceItem.circle).text,
        'The star is somewhere left of the circle.');
    expect(const Between(DeduceItem.square, DeduceItem.circle, DeduceItem.star).text,
        'The square is between the circle and the star.');
  });

  test('the review explains which clues an answer breaks', () {
    // The artboard example: answer triangle, star, circle, square.
    const p = DeducePuzzle(
      level: 3,
      seed: 0,
      tray: [DeduceItem.star, DeduceItem.circle, DeduceItem.triangle, DeduceItem.square],
      solution: [DeduceItem.triangle, DeduceItem.star, DeduceItem.circle, DeduceItem.square],
      clues: [
        LeftOf(DeduceItem.star, DeduceItem.circle),
        IsAt(DeduceItem.square, 3, 4),
        NextTo(DeduceItem.triangle, DeduceItem.star),
        NotAt(DeduceItem.triangle, 1, 4),
      ],
    );
    expect(countSolutions(p.solution, p.clues), 1);

    const wrong = [DeduceItem.triangle, DeduceItem.circle, DeduceItem.star, DeduceItem.square];
    expect(p.brokenClues(wrong), [0, 2]);
    expect(p.explain(wrong), 'Clues 1 and 3 aren’t true in your order. Compare it with the solution.');
    expect(p.explain(p.solution), startsWith('Every clue is true'));
  });
}
