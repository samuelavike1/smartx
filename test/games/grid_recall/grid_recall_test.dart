import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/grid_recall/grid_puzzle.dart';

void main() {
  const generator = GridRecallGenerator();

  test('same level and seed produce the same grid', () {
    final a = generator.generate(level: 6, seed: 7);
    final b = generator.generate(level: 6, seed: 7);
    expect(a.cells, b.cells);
    expect(a.size, b.size);
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level grids are valid', () {
      final d = GridDifficulty.forLevel(level);
      for (var seed = 0; seed < 300; seed++) {
        final p = generator.generate(level: level, seed: seed);
        expect(p.size, d.size);
        expect(p.cells, hasLength(d.cellCount));
        expect(
          p.cells.toSet(),
          hasLength(p.cells.length),
          reason: 'lit cells must be distinct',
        );
        expect(p.cells.every((c) => c >= 0 && c < p.size * p.size), isTrue);
        expect(p.cells.length, lessThanOrEqualTo(p.size * p.size * 0.45));
        expect(p.ordered, d.ordered);
      }
    });
  }

  test('difficulty grows from 3×3 with 3 cells to 6×6 in order', () {
    final easy = GridDifficulty.forLevel(1);
    expect((easy.size, easy.cellCount, easy.ordered), (3, 3, false));
    final hard = GridDifficulty.forLevel(10);
    expect((hard.size, hard.cellCount, hard.ordered), (6, 10, true));
  });

  test('free-order recall ignores tap order; ordered recall does not', () {
    const free = GridPuzzle(
      level: 1,
      seed: 0,
      size: 3,
      cells: [0, 4, 8],
      ordered: false,
    );
    expect(free.isCorrect([8, 0, 4]), isTrue);
    expect(free.isCorrect([8, 0, 5]), isFalse);
    expect(free.explain([8, 0, 5]), contains('found 2 of 3'));

    const ordered = GridPuzzle(
      level: 9,
      seed: 0,
      size: 3,
      cells: [0, 4, 8],
      ordered: true,
    );
    expect(ordered.isCorrect([0, 4, 8]), isTrue);
    expect(ordered.isCorrect([0, 8, 4]), isFalse);
    expect(ordered.explain([0, 8, 4]), contains('step 2 of 3'));
  });
}
