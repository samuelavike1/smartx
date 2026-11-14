import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/core/game/game_registry.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/today/daily_workout.dart';

void main() {
  final today = DateTime(2026, 11, 14);
  final id = gameRegistry.first.id;

  ProgressSnapshot snapshot({GameProgress? game, Map<Skill, int> xp = const {}}) =>
      ProgressSnapshot(games: {id: ?game}, skillXp: xp);

  test('an unplayed game is up next', () {
    final items = dailyWorkout(snapshot(), today);
    expect(items, hasLength(gameRegistry.length.clamp(0, 3)));
    expect(items.first.status, WorkoutStatus.next);
  });

  test('a game finished today is done; yesterday does not count', () {
    final doneToday = dailyWorkout(
      snapshot(game: GameProgress(lastPlayedDay: dayKey(today), lastScore: 920)),
      today,
    );
    expect(doneToday.first.status, WorkoutStatus.done);
    expect(doneToday.first.progress.lastScore, 920);

    final yesterday = dailyWorkout(
      snapshot(game: GameProgress(lastPlayedDay: dayKey(today.subtract(const Duration(days: 1))))),
      today,
    );
    expect(yesterday.first.status, WorkoutStatus.next);
  });

  test('a game played today stays in the workout even after its XP rises', () {
    // Pattern Sequence played today; its main skill now has the most XP.
    final p = ProgressSnapshot(
      games: {
        'pattern_sequence': GameProgress(lastPlayedDay: dayKey(today), lastScore: 500),
      },
      skillXp: const {Skill.patternRecognition: 100, Skill.logic: 50, Skill.attention: 50},
    );
    final items = dailyWorkout(p, today);
    expect(items, hasLength(3));
    expect(items.first.game.id, 'pattern_sequence');
    expect(items.first.status, WorkoutStatus.done);
    expect(items[1].status, WorkoutStatus.next);
    expect(items.where((i) => i.status == WorkoutStatus.done), hasLength(1));
  });

  test('weakest skill is null until something is played', () {
    expect(weakestSkill(snapshot()), isNull);
    expect(
      weakestSkill(snapshot(xp: {
        for (final s in Skill.values) s: s == Skill.memory ? 5 : 50,
      })),
      Skill.memory,
    );
  });

  test('dayKey pads month and day', () {
    expect(dayKey(DateTime(2026, 3, 7)), '2026-03-07');
  });
}
