import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/games/egg_drop/egg_controller.dart';
import 'package:smartx/games/egg_drop/egg_drop_game.dart';
import 'package:smartx/games/egg_drop/egg_puzzle.dart';

/// Worst-case drops to pin down one of [n] possible answers with [e] eggs,
/// by a full minimax search over every drop (no shared code with the game).
/// Dropping at the x-th possible answer leaves x answers if it breaks and
/// n − x if it survives.
final _memo = <(int, int), int>{};
const _never = 1 << 20;
int minimax(int e, int n) {
  if (n <= 1) return 0;
  if (e == 0) return _never;
  final key = (e, n);
  final hit = _memo[key];
  if (hit != null) return hit;
  var best = _never;
  for (var x = 1; x < n; x++) {
    final worst = 1 + max<int>(minimax(e - 1, x), minimax(e, n - x));
    if (worst < best) best = worst;
  }
  return _memo[key] = best;
}

/// The drop a perfect player makes with answers lo..hi and [e] eggs: one
/// that keeps the worst case smallest (lowest such floor).
int bestDrop(int lo, int hi, int e) {
  int? pick;
  var best = _never;
  for (var x = lo + 1; x <= hi; x++) {
    final worst = 1 + max<int>(minimax(e - 1, x - lo), minimax(e, hi - x + 1));
    if (worst < best) {
      best = worst;
      pick = x;
    }
  }
  return pick!;
}

/// Floors consistent with every drop, by brute force.
Set<int> fitting(int floors, List<EggDrop> log) => {
  for (var t = 0; t <= floors; t++)
    if (log.every((d) => d.broke ? t < d.floor : t >= d.floor)) t,
};

/// Plays perfect (minimax) drops against the building until the round ends.
EggPuzzle playWell(EggPuzzle p) {
  while (!p.over) {
    p = p.drop(bestDrop(p.lo, p.hi, p.eggsLeft));
  }
  return p;
}

void main() {
  test('the floors table matches a full minimax search', () {
    for (var e = 1; e <= 4; e++) {
      for (var d = 0; d <= 9; d++) {
        // The most floors (answers 0..F) that d drops always settle.
        var most = 0;
        while (minimax(e, most + 2) <= d) {
          most++;
        }
        expect(floorsSettled(e, d), most, reason: 'f($e, $d)');
      }
      for (var f = 0; f <= 45; f++) {
        expect(dropsNeeded(e, f), minimax(e, f + 1), reason: '$e eggs, $f');
      }
    }
    expect(dropsNeeded(0, 3), isNull);
    expect(dropsNeeded(0, 0), 0);
    // The textbook values.
    expect(
      [for (var d = 1; d <= 8; d++) floorsSettled(2, d)],
      [1, 3, 6, 10, 15, 21, 28, 36],
    );
    expect([4, 5, 6].map((d) => floorsSettled(3, d)), [14, 25, 41]);
  });

  test('the levels match the rules, with the best possible budget', () {
    const ranges = {
      1: (1, 4, 6),
      2: (2, 6, 10),
      3: (2, 11, 15),
      4: (2, 20, 21),
      5: (2, 27, 28),
      6: (3, 13, 14),
      7: (3, 24, 25),
      8: (2, 35, 36),
      9: (3, 40, 41),
    };
    const budgets = {3: 5, 4: 6, 5: 7, 6: 4, 7: 5, 8: 8, 9: 6};
    for (var level = 1; level <= 10; level++) {
      final seen = <int>{};
      for (var seed = 0; seed < 150; seed++) {
        final p = EggPuzzle.generate(level: level, seed: seed);
        final s = p.setup;
        seen.add(s.floors);
        expect(s.drops, minimax(s.eggs, s.floors + 1), reason: 'level $level');
        if (budgets[level] case final b?) expect(s.drops, b);
        if (level == 1) expect(s.drops, s.floors);
        if (ranges[level] case (final e, final lo, final hi)) {
          expect(s.eggs, e);
          expect(s.floors, inInclusiveRange(lo, hi));
        } else {
          // Level 10: a level 4–9 setup at its top floor count, so one more
          // floor would need one more drop.
          expect(s.eggs, inInclusiveRange(2, 3));
          expect(minimax(s.eggs, s.floors + 2), s.drops + 1);
        }
        expect(p.lo, 0);
        expect(p.hi, s.floors);
        expect(p.inReach, isTrue);
        expect(p.over, isFalse);
      }
      expect(seen.length, greaterThan(1), reason: 'level $level never varies');
      expect(EggSetup.hint(level), isNotEmpty);
    }
  });

  test('the building never contradicts itself', () {
    final rng = Random(3);
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 120; seed++) {
        var p = EggPuzzle.generate(level: level, seed: seed);
        while (!p.over) {
          final live = [
            for (var x = 1; x <= p.floors; x++)
              if (p.canDrop(x)) x,
          ];
          expect(live, isNotEmpty);
          p = p.drop(live[rng.nextInt(live.length)]);
          final fits = fitting(p.floors, p.log);
          expect(fits, isNotEmpty);
          expect(fits, {for (var t = p.lo; t <= p.hi; t++) t});
          expect(p.eggsLeft, greaterThanOrEqualTo(0));
          expect(p.dropsLeft, greaterThanOrEqualTo(0));
        }
        expect(p.won, p.lo == p.hi);
        expect(p.won || p.eggsLeft == 0 || p.dropsLeft == 0, isTrue);
        // Ruled-out floors can't be dropped from.
        for (var x = 1; x <= p.floors; x++) {
          expect(p.canDrop(x), isFalse);
        }
      }
    }
  });

  test('best play always wins within the budget, at every level', () {
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 120; seed++) {
        final start = EggPuzzle.generate(level: level, seed: seed);
        final end = playWell(start);
        expect(end.won, isTrue, reason: 'level $level seed $seed');
        expect(end.log.length, lessThanOrEqualTo(start.budget));
        expect(end.slip, isNull);
        expect(end.feedback, contains('Found in ${end.log.length} of'));
        // The game's own "keeps it in reach" drop wins too.
        var p = start;
        while (!p.over) {
          final x = keepInReach(p.lo, p.hi, p.eggsLeft, p.dropsLeft);
          expect(x, isNotNull);
          p = p.drop(x!);
        }
        expect(p.won, isTrue);
      }
    }
  });

  test('the best first drop wins against every hidden floor', () {
    for (final (e, f) in [
      (1, 5),
      (2, 10),
      (2, 21),
      (2, 28),
      (2, 36),
      (3, 14),
      (3, 25),
      (3, 41),
      (2, 17),
      (3, 20),
    ]) {
      final setup = EggSetup.of(e, f);
      for (var t = 0; t <= f; t++) {
        var lo = 0, hi = f, eggs = e, drops = setup.drops;
        while (lo < hi) {
          final x = keepInReach(lo, hi, eggs, drops)!;
          expect(x, greaterThan(lo));
          expect(x, lessThanOrEqualTo(hi));
          drops--;
          if (t < x) {
            hi = x - 1;
            eggs--;
          } else {
            lo = x;
          }
          expect(drops, greaterThanOrEqualTo(0), reason: '$e/$f, floor $t');
          expect(eggs, greaterThanOrEqualTo(lo == hi ? 0 : 1));
        }
        expect(lo, t);
      }
    }
  });

  test('two eggs climb D, then D + (D − 1), and so on', () {
    for (final f in [6, 10, 15, 21, 28, 36]) {
      final p = EggPuzzle(level: 5, seed: 0, setup: EggSetup.of(2, f));
      final d = p.budget;
      expect(p.bestStart, d);
      var x = 0;
      expect(p.climb, [for (var k = d; k >= 1; k--) x += k]);
      expect(p.climb.last, f);
    }
    final three = EggPuzzle(level: 6, seed: 0, setup: EggSetup.of(3, 14));
    expect(three.bestStart, 7);
    expect(three.climb, [7, 11, 13, 14]);
    final one = EggPuzzle(level: 1, seed: 0, setup: EggSetup.of(1, 5));
    expect(one.climb, [1, 2, 3, 4, 5]);
  });

  test('a wasted first drop can be made to lose', () {
    for (final (e, f) in EggSetup.tight) {
      final start = EggPuzzle(level: 10, seed: 1, setup: EggSetup.of(e, f));
      for (var x = 1; x <= f; x++) {
        final after = start.drop(x);
        if (x == start.bestStart) {
          expect(after.inReach, isTrue);
          expect(playWell(after).won, isTrue);
          continue;
        }
        // On a tight budget every other first floor wastes a drop.
        expect(after.inReach, isFalse, reason: '$e eggs, $f floors, $x');
        final end = playWell(after);
        expect(end.won, isFalse);
        expect(end.slip, (1, start.bestStart));
        expect(end.feedback, startsWith('Out of '));
        expect(end.feedback, contains('floor ${start.bestStart} would have'));
        expect(end.slipNote(1), startsWith('The slip: '));
      }
    }
  });

  test('a slip later in the round is found, with a drop that was safe', () {
    // 3 eggs, 14 floors, 4 drops: floor 9 first is too high.
    var p = EggPuzzle(level: 6, seed: 0, setup: EggSetup.of(3, 14));
    p = p.drop(9);
    expect(p.log.single.broke, isTrue);
    expect((p.lo, p.hi, p.eggsLeft, p.dropsLeft), (0, 8, 2, 3));
    expect(p.slip, (1, 7));
    expect(p.slipNote(1), 'The slip: 0 to 8 left for 2 eggs and 3 drops');
    // Good first drop, then a wasted one: dropping from the lowest floor.
    var q = EggPuzzle(level: 4, seed: 0, setup: EggSetup.of(2, 21));
    q = q.drop(6);
    expect(q.inReach, isTrue);
    q = q.drop(q.lo + 1);
    expect(q.slip?.$1, 2);
    final y = q.slip!.$2;
    final (lo, hi, eggs, drops) = q.before(2);
    expect(minimax(eggs - 1, y - lo), lessThanOrEqualTo(drops - 1));
    expect(minimax(eggs, hi - y + 1), lessThanOrEqualTo(drops - 1));
  });

  test('every round has three steps of working and feedback', () {
    final rng = Random(9);
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 40; seed++) {
        var p = EggPuzzle.generate(level: level, seed: seed);
        expect(p.steps, hasLength(3));
        for (final s in p.steps) {
          expect(s, endsWith('.'));
        }
        // The climb, starting from the best first drop, is spelled out.
        expect(p.steps[1], contains(p.climb.join(', ')));
        expect(p.climb.first, p.bestStart);
        while (!p.over) {
          final live = [
            for (var x = 1; x <= p.floors; x++)
              if (p.canDrop(x)) x,
          ];
          p = p.drop(live[rng.nextInt(live.length)]);
        }
        expect(p.feedback, isNotEmpty);
        if (!p.won) {
          expect(p.slip, isNotNull, reason: 'a lost round always has a slip');
        }
      }
    }
  });

  group('the session', () {
    late ProviderContainer c;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      EggController.seed = 4;
      c = ProviderContainer(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            ProgressRepository(prefs),
          ),
        ],
      );
      c.listen(eggSessionProvider, (_, _) {});
    });

    tearDown(() {
      c.dispose();
      EggController.seed = null;
    });

    void play({required bool well}) {
      final ctrl = c.read(eggSessionProvider.notifier);
      while (!c.read(eggSessionProvider).answered) {
        final p = c.read(eggSessionProvider).puzzle;
        // A poor plan: always the lowest floor still in play.
        ctrl.tapFloor(well ? bestDrop(p.lo, p.hi, p.eggsLeft) : p.lo + 1);
        ctrl.drop();
      }
    }

    test(
      'wins score, three in a row level up, two misses level down',
      () async {
        final ctrl = c.read(eggSessionProvider.notifier);
        expect(c.read(eggSessionProvider).level, 1);
        for (var r = 0; r < 3; r++) {
          play(well: true);
          final s = c.read(eggSessionProvider);
          expect(s.lastCorrect, isTrue);
          expect(s.lastPoints, greaterThanOrEqualTo(60));
          expect(s.combo, r + 1);
          await ctrl.next();
        }
        expect(c.read(eggSessionProvider).level, 2);
        final before = c.read(eggSessionProvider).score;
        for (var r = 0; r < 2; r++) {
          play(well: false);
          final s = c.read(eggSessionProvider);
          expect(s.lastCorrect, isFalse);
          expect(s.lastPoints, 0);
          expect(s.score, before);
          expect(s.combo, 0);
          await ctrl.next();
        }
        expect(c.read(eggSessionProvider).level, 1);
        play(well: true);
        await ctrl.next();
        final done = c.read(eggSessionProvider);
        expect(done.finished, isTrue);
        expect(done.correctCount, 4);
        expect(done.nearMiss, isNotNull);
        expect(c.read(progressProvider).forGame(EggDropGame.gameId).level, 1);
        // Practice: one unscored round, then back to the results.
        ctrl.trySimilar();
        expect(c.read(eggSessionProvider).practice, isTrue);
        play(well: true);
        expect(c.read(eggSessionProvider).score, done.score);
        await ctrl.next();
        expect(c.read(eggSessionProvider).finished, isTrue);
      },
    );

    test('only live floors can be picked, and a pick can be undone', () {
      final ctrl = c.read(eggSessionProvider.notifier);
      ctrl.tapFloor(2);
      expect(c.read(eggSessionProvider).selected, 2);
      ctrl.tapFloor(2);
      expect(c.read(eggSessionProvider).selected, isNull);
      ctrl.drop();
      expect(c.read(eggSessionProvider).puzzle.log, isEmpty);
      ctrl.tapFloor(1);
      ctrl.drop();
      final p = c.read(eggSessionProvider).puzzle;
      expect(p.log, hasLength(1));
      // Floor 1 is now known: it survived (or the round is settled).
      ctrl.tapFloor(1);
      expect(c.read(eggSessionProvider).selected, isNull);
    });
  });
}
