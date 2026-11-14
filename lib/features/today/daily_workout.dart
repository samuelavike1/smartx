import '../../core/game/game_definition.dart';
import '../../core/game/game_registry.dart';
import '../../core/skills/skill.dart';
import '../../core/storage/progress.dart';

enum WorkoutStatus { done, next, pending }

class WorkoutItem {
  const WorkoutItem(this.game, this.status, this.progress);

  final GameDefinition game;
  final WorkoutStatus status;
  final GameProgress progress;
}

/// Rough length of one session, used for the "about N min" estimate.
const int minutesPerGame = 3;

/// Today's workout: up to [size] games. Games already finished today stay in
/// it (so playing one never drops it out); the free slots go to the games
/// whose main skill has the least XP, so the next game trains the skill
/// that needs it most.
List<WorkoutItem> dailyWorkout(
  ProgressSnapshot progress,
  DateTime today, {
  List<GameDefinition> games = gameRegistry,
  int size = 3,
}) {
  final played = games.where((g) => progress.forGame(g.id).playedOn(today));

  // Stable: ties keep registry order (Dart's sort is not stable).
  final indexed =
      [
        for (final (i, g) in games.indexed)
          if (!progress.forGame(g.id).playedOn(today)) (i, g),
      ]..sort((a, b) {
        final byXp = progress
            .xpFor(a.$2.skills.first)
            .compareTo(progress.xpFor(b.$2.skills.first));
        return byXp != 0 ? byXp : a.$1.compareTo(b.$1);
      });
  final ordered = [...played, for (final (_, g) in indexed) g];

  var nextAssigned = false;
  return [
    for (final g in ordered.take(size))
      () {
        final p = progress.forGame(g.id);
        if (p.playedOn(today)) return WorkoutItem(g, WorkoutStatus.done, p);
        if (!nextAssigned) {
          nextAssigned = true;
          return WorkoutItem(g, WorkoutStatus.next, p);
        }
        return WorkoutItem(g, WorkoutStatus.pending, p);
      }(),
  ];
}

/// The skill with the least XP among skills some game trains, or null before
/// anything has been played.
Skill? weakestSkill(
  ProgressSnapshot progress, {
  List<GameDefinition> games = gameRegistry,
}) {
  final trained = Skill.values
      .where((s) => games.any((g) => g.skills.contains(s)))
      .toList();
  if (trained.isEmpty || trained.every((s) => progress.xpFor(s) == 0)) {
    return null;
  }
  return trained.reduce(
    (a, b) => progress.xpFor(b) < progress.xpFor(a) ? b : a,
  );
}
