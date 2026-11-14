import 'dart:math';

import 'package:flutter/foundation.dart';

import '../../core/game/speed_game.dart';
import '../../core/skills/skill.dart';
import '../../games/arrow_focus/arrow_focus_game.dart';
import '../../games/ink_clash/ink_clash_game.dart';
import '../../games/mental_math/mental_math_game.dart';
import '../../games/odd_one_out/odd_one_out_game.dart';
import '../../games/pattern_sequence/pattern_sequence_game.dart';

// The Quick feed: a fixed run of short cards from several games, then a
// summary. Pure logic here (plan, bursts, summary) so it can be tested
// without widgets.

/// The games a feed card can come from.
enum FeedKind {
  ink(InkClashGame.gameId, 'Ink Clash', Skill.attention),
  arrow(ArrowFocusGame.gameId, 'Arrow Focus', Skill.attention),
  odd(OddOneOutGame.gameId, 'Odd One Out', Skill.attention),
  math(MentalMathGame.gameId, 'Mental Math', Skill.numbers),
  pattern(
    PatternSequenceGame.gameId,
    'Pattern Sequence',
    Skill.patternRecognition,
  );

  const FeedKind(this.gameId, this.title, this.skill);

  final String gameId;
  final String title;

  /// The skill a right card counts towards.
  final Skill skill;

  bool get speed => this != pattern;
}

@immutable
class FeedCardSpec {
  const FeedCardSpec(this.kind, {required this.level, required this.seed});

  final FeedKind kind;

  /// The player's current level in that game (the feed never changes it).
  final int level;
  final int seed;
}

abstract final class FeedRules {
  static const int cards = 20;

  /// Answers in a speed card, and how many make the card right.
  static const int burst = 5;
  static const int burstPass = 4;

  static const int xpPerCard = 5;

  /// Pause before a speed card's first answer.
  static const getReady = Duration(milliseconds: 700);
}

/// Builds the run of cards: an equal share of each game, shuffled so the
/// same game never comes twice in a row.
List<FeedCardSpec> planFeed({
  required int Function(FeedKind kind) levelFor,
  required int seed,
  int cards = FeedRules.cards,
}) {
  final rng = Random(seed);
  final kinds = FeedKind.values;
  while (true) {
    final left = {for (final k in kinds) k: cards ~/ kinds.length};
    for (var i = 0; i < cards % kinds.length; i++) {
      left[kinds[i]] = left[kinds[i]]! + 1;
    }
    final order = <FeedKind>[];
    FeedKind? last;
    var stuck = false;
    for (var i = 0; i < cards; i++) {
      final options = [
        for (final k in kinds)
          for (var n = 0; n < left[k]!; n++)
            if (k != last) k,
      ];
      if (options.isEmpty) {
        stuck = true;
        break;
      }
      final k = options[rng.nextInt(options.length)];
      order.add(k);
      left[k] = left[k]! - 1;
      last = k;
    }
    if (stuck) continue;
    return [
      for (final k in order)
        FeedCardSpec(k, level: levelFor(k), seed: rng.nextInt(1 << 31)),
    ];
  }
}

/// Picks a short burst from a full block: some calm and some conflict
/// trials when the block has them, kept in their original order.
List<T> burstOf<T extends SpeedTrial<Object?>>(
  List<T> trials, {
  int size = FeedRules.burst,
}) {
  final calm = [
    for (final (i, t) in trials.indexed)
      if (!t.conflict) i,
  ];
  final conflict = [
    for (final (i, t) in trials.indexed)
      if (t.conflict) i,
  ];
  final picked = <int>{
    ...conflict.take((size / 2).ceil()),
    ...calm.take(size ~/ 2),
  };
  for (var i = 0; picked.length < size && i < trials.length; i++) {
    picked.add(i);
  }
  return [for (final i in picked.toList()..sort()) trials[i]];
}

@immutable
class FeedCardResult {
  const FeedCardResult({
    required this.kind,
    required this.correct,
    required this.total,
    required this.right,
    required this.detail,
  });

  final FeedKind kind;

  /// Answers right in the card (a pattern card has one).
  final int correct;
  final int total;

  /// The card counts as right.
  final bool right;

  /// The first mistake explained, or what the rule was.
  final String detail;
}

@immutable
class FeedSkillLine {
  const FeedSkillLine({
    required this.skill,
    required this.correct,
    required this.total,
    required this.last,
  });

  final Skill skill;
  final int correct;
  final int total;

  /// Percent right in the previous feed, or null for a first feed.
  final int? last;

  int get percent => total == 0 ? 0 : (100 * correct / total).round();

  /// Change in percentage points since the last feed.
  int? get change => last == null ? null : percent - last!;
}

@immutable
class FeedSummary {
  const FeedSummary({
    required this.right,
    required this.cards,
    required this.lines,
    required this.bestCombo,
    required this.xp,
    required this.time,
  });

  final int right;
  final int cards;
  final List<FeedSkillLine> lines;
  final int bestCombo;
  final int xp;
  final Duration time;
}

/// Totals per skill (answers for speed cards, sequences for pattern cards)
/// against the last feed's percentages.
FeedSummary summarizeFeed(
  List<FeedCardResult> results, {
  required int? Function(Skill skill) lastPercent,
  required int bestCombo,
  required Duration time,
}) {
  final skills = <Skill>[];
  final correct = <Skill, int>{}, total = <Skill, int>{};
  for (final r in results) {
    final s = r.kind.skill;
    if (!skills.contains(s)) skills.add(s);
    correct[s] = (correct[s] ?? 0) + r.correct;
    total[s] = (total[s] ?? 0) + r.total;
  }
  final right = results.where((r) => r.right).length;
  return FeedSummary(
    right: right,
    cards: results.length,
    lines: [
      for (final s in skills)
        FeedSkillLine(
          skill: s,
          correct: correct[s]!,
          total: total[s]!,
          last: lastPercent(s),
        ),
    ],
    bestCombo: bestCombo,
    xp: right * FeedRules.xpPerCard,
    time: time,
  );
}
