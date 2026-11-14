import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/path_finder/path_puzzle.dart';

/// The artboard's board: 6×6, start bottom-left, flag top-right behind a
/// gate, key in the right-hand column.
PathBoard artboardBoard() {
  const n = 6;
  final cells = List<Cell>.filled(n * n, Cell.floor);
  int at(int r, int c) => r * n + c;
  for (final (r, c) in const [(0, 2), (2, 1), (3, 3), (5, 4)]) {
    cells[at(r, c)] = Cell.wall;
  }
  cells[at(0, 5)] = Cell.exit;
  cells[at(1, 5)] = Cell.gate;
  cells[at(3, 5)] = Cell.key;
  return PathBoard(n, cells);
}

void main() {
  const generator = PathGenerator();

  test('slide rules on the artboard board', () {
    final b = artboardBoard();
    const start = 5 * 6 + 0;

    var r = b.slide(start, false, Dir.right);
    expect(r.end, 5 * 6 + 3, reason: 'stops before the wall');
    r = b.slide(r.end, r.hasKey, Dir.up);
    expect(r.end, 4 * 6 + 3);
    r = b.slide(r.end, r.hasKey, Dir.right);
    expect(r.end, 4 * 6 + 5, reason: 'stops at the edge');
    r = b.slide(r.end, r.hasKey, Dir.up);
    expect(
      r.won,
      isTrue,
      reason: 'picks up the key, opens the gate, reaches the flag',
    );

    // Without the key the gate stops the same slide.
    final blocked = b.slide(4 * 6 + 5, false, Dir.up);
    expect(blocked.hasKey, isTrue); // the key is on the way…
    expect(
      b.slide(2 * 6 + 5, false, Dir.up).end,
      2 * 6 + 5,
    ); // …but not from above it

    expect(b.solve(start), [Dir.right, Dir.up, Dir.right, Dir.up]);
  });

  test('a blocked slide is not a move', () {
    final b = artboardBoard();
    expect(b.slide(5 * 6 + 3, false, Dir.right).moved, isFalse);
  });

  test('arrow tiles turn the slide; arrow loops stop safely', () {
    final cells = List<Cell>.filled(9, Cell.floor);
    cells[1] = Cell.arrowDown; // top middle turns down
    cells[7] = Cell.exit; // bottom middle
    final b = PathBoard(3, cells);
    expect(b.slide(0, false, Dir.right).won, isTrue);

    final loop = List<Cell>.filled(4, Cell.floor);
    loop[1] = Cell.arrowDown;
    loop[3] = Cell.arrowLeft;
    loop[2] = Cell.arrowUp;
    loop[0] = Cell.arrowRight;
    final r = PathBoard(2, loop).slide(0, false, Dir.right);
    expect(r.moved, isTrue, reason: 'terminates instead of looping forever');
  });

  test('same level and seed produce the same board', () {
    final a = generator.generate(level: 7, seed: 3);
    final b = generator.generate(level: 7, seed: 3);
    expect(a.board.cells, b.board.cells);
    expect(a.solution, b.solution);
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level boards are solvable, sized and fair', () {
      final d = PathDifficulty.forLevel(level);
      for (var seed = 0; seed < 40; seed++) {
        final p = generator.generate(level: level, seed: seed);
        expect(p.size, d.size);
        expect(p.shortest, inInclusiveRange(2, d.maxMoves));
        expect(p.moveLimit, p.shortest + d.slack);

        // Replaying the solution wins on exactly the last move.
        var pos = p.start;
        var key = false;
        for (final (i, dir) in p.solution.indexed) {
          final r = p.board.slide(pos, key, dir);
          expect(r.moved, isTrue);
          expect(
            r.won,
            i == p.solution.length - 1,
            reason: 'seed $seed move $i',
          );
          pos = r.end;
          key = r.hasKey;
        }

        if (d.useKey) {
          final noKey = [
            for (final c in p.board.cells) c == Cell.key ? Cell.floor : c,
          ];
          expect(
            PathBoard(p.size, noKey).solve(p.start),
            isNull,
            reason: 'the key must be needed (seed $seed)',
          );
        }
        expect(
          p.board.cells.where((c) => c.arrow != null),
          hasLength(d.arrows),
        );
      }
    });
  }

  test('review explains the route', () {
    final b = artboardBoard();
    final p = PathPuzzle(
      level: 5,
      seed: 0,
      board: b,
      start: 30,
      solution: b.solve(30)!,
      moveLimit: 5,
    );
    expect(
      p.explain(won: false, movesUsed: 5),
      'Out of moves. The shortest route takes 4: → ↑ → ↑. The numbers show where each move stops.',
    );
    expect(
      p.explain(won: true, movesUsed: 4),
      startsWith('Shortest route, 4 moves'),
    );
    final marks = p.routeMarks();
    expect(marks[33], 1);
    expect(marks[27], 2);
    expect(marks[29], 3);
    expect(marks[5], 4);
    expect(marks[31], 0, reason: 'passed over, not stopped on');
  });
}
