import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/best_run/run_puzzle.dart';

/// The best result by trying every choice, written plainly.
int bruteBest(RunPuzzle p) {
  var best = -1 << 30;
  final v = p.values;
  for (var s = 0; s < v.length; s++) {
    for (var e = s; e < v.length; e++) {
      if (p.prices && e == s) continue;
      final got = p.prices
          ? v[e] - v[s]
          : v.sublist(s, e + 1).fold(0, (a, b) => a + b);
      best = max(best, got);
    }
  }
  return best;
}

void main() {
  const gen = RunGenerator();

  test('every level has one clear best, matching a brute force', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 60; seed++) {
        final p = gen.generate(level: level, seed: seed);
        expect(p.best, bruteBest(p), reason: 'level $level ${p.values}');
        expect(p.bestChoices, hasLength(1));
        expect(p.mode, level >= 9 ? RunMode.prices : RunMode.bars);
        expect(
          RunGenerator.fits(p, level),
          isTrue,
          reason: 'level $level twist missing: ${p.values}',
        );
        final (s, e) = p.bestChoice;
        // The running total's peak is the answer, on the best run's last day.
        expect(p.running.reduce(max), p.best);
        expect(p.running[e], p.best);
        if (!p.prices) {
          expect(s == 0 || p.restarts.contains(s), isTrue);
        }
        expect(p.steps, hasLength(3));
        expect(p.feedbackFor(s, e), isNotEmpty);
        // Every other choice gets a reason too.
        for (final (a, b) in p.choices) {
          expect(p.feedbackFor(a, b), isNotEmpty);
        }
      }
    }
  });

  test('the board\'s chart: stopping too soon', () {
    const p = RunPuzzle(
      level: 5,
      seed: 0,
      mode: RunMode.bars,
      values: [4, -6, 5, 3, -2, 6, -1, 4, -7, 2],
    );
    expect(p.best, 15);
    expect(p.bestChoice, (2, 7));
    expect(p.running, [4, -2, 5, 8, 6, 12, 11, 15, 8, 10]);
    expect(p.valueOf(2, 5), 12);
    expect(
      p.feedbackFor(2, 5),
      'Stopped too soon: days 7–8 add +3 more. The −1 is paid back by the +4.',
    );
    expect(p.steps[1], 'It starts again on day 3 and peaks at +15 on day 8.');
    expect(p.feedbackFor(2, 9), startsWith('Trim it: days 9–10 cost −5.'));
    expect(p.feedbackFor(2, 8), startsWith('Trim it: day 9 costs −7.'));
    expect(p.feedbackFor(2, 6), 'Stopped too soon: day 8 adds +4 more.');
    expect(
      p.feedbackFor(5, 5),
      'The biggest day isn\'t the best run: days 3–8 make +15.',
    );
  });

  test('the price board: the lowest price comes too late', () {
    const p = RunPuzzle(
      level: 9,
      seed: 0,
      mode: RunMode.prices,
      values: [20, 26, 18, 22, 15, 21, 27, 24, 13, 19, 16],
    );
    expect(p.best, 12);
    expect(p.bestChoice, (4, 6));
    expect(p.feedbackFor(8, 9), startsWith('The lowest price, day 9, comes '));
    expect(p.feedbackFor(4, 5), startsWith('Right day to buy'));
    expect(p.choiceText(4, 6), r'Buy day 5 at $15, sell day 7 at $27 · +$12');
  });
}
