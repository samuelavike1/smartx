import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/features/feed/feed_plan.dart';
import 'package:smartx/games/ink_clash/ink_puzzle.dart';

void main() {
  test(
    'a feed has 20 cards, 5 per game, never the same game twice running',
    () {
      for (var seed = 0; seed < 300; seed++) {
        final plan = planFeed(levelFor: (k) => k.index + 2, seed: seed);
        expect(plan, hasLength(FeedRules.cards));
        for (final k in FeedKind.values) {
          expect(plan.where((c) => c.kind == k), hasLength(5));
        }
        for (var i = 1; i < plan.length; i++) {
          expect(plan[i].kind, isNot(plan[i - 1].kind), reason: 'seed $seed');
        }
        for (final c in plan) {
          expect(c.level, c.kind.index + 2, reason: 'plays at the game level');
        }
      }
      expect(
        [
          for (final c in planFeed(levelFor: (_) => 1, seed: 9))
            (c.kind, c.seed),
        ],
        [
          for (final c in planFeed(levelFor: (_) => 1, seed: 9))
            (c.kind, c.seed),
        ],
      );
    },
  );

  test('a burst keeps calm and conflict trials, in order', () {
    const gen = InkGenerator();
    for (var seed = 0; seed < 100; seed++) {
      final trials = gen.generate(level: 3, seed: seed).trials;
      final burst = burstOf(trials);
      expect(burst, hasLength(FeedRules.burst));
      expect(burst.where((t) => t.conflict), isNotEmpty);
      expect(burst.where((t) => !t.conflict), isNotEmpty);
      final positions = [for (final t in burst) trials.indexOf(t)];
      expect(positions, [...positions]..sort());
    }
  });

  test(
    'summary: per-skill accuracy against the last feed, XP for right cards',
    () {
      FeedCardResult speed(int correct) => FeedCardResult(
        kind: FeedKind.arrow,
        correct: correct,
        total: 5,
        right: correct >= FeedRules.burstPass,
        detail: '',
      );
      FeedCardResult pattern(bool right) => FeedCardResult(
        kind: FeedKind.pattern,
        correct: right ? 1 : 0,
        total: 1,
        right: right,
        detail: '',
      );
      final s = summarizeFeed(
        [speed(5), speed(3), pattern(true), speed(4), pattern(false)],
        lastPercent: (skill) => skill == Skill.attention ? 70 : null,
        bestCombo: 2,
        time: const Duration(minutes: 4),
      );
      expect(s.cards, 5);
      expect(s.right, 3);
      expect(s.xp, 3 * FeedRules.xpPerCard);
      final focus = s.lines.firstWhere((l) => l.skill == Skill.attention);
      expect((focus.correct, focus.total, focus.percent), (12, 15, 80));
      expect(focus.change, 10);
      final pat = s.lines.firstWhere(
        (l) => l.skill == Skill.patternRecognition,
      );
      expect((pat.correct, pat.total, pat.percent), (1, 2, 50));
      expect(pat.change, isNull, reason: 'first feed');
    },
  );
}
