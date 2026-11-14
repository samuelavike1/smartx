import 'package:flutter/widgets.dart';

import '../skills/skill.dart';
import 'how_to_play.dart';

export 'how_to_play.dart';

/// Contract every mini-game implements so the shell (home, routing, stats)
/// can list and launch it without knowing anything game-specific.
///
/// To add a game: create `lib/games/<name>/`, implement this class, and add
/// an instance to `gameRegistry` in `game_registry.dart`.
abstract class GameDefinition {
  const GameDefinition();

  /// Stable id used in routes and storage keys. Never change it once shipped.
  String get id;
  String get title;
  String get tagline;
  IconData get icon;

  /// Skills this game trains. The first is the main skill (full XP).
  List<Skill> get skills;

  /// One line describing what a level looks like, shown on the results
  /// screen when the level changes ("4×4 grid with 5 cells").
  String levelHint(int level) => 'Level $level';

  /// The rules: shown before the first session, and from the ? button.
  HowToPlay get howTo;

  /// The game has a clock running during play, so its rules can only be
  /// opened between rounds (the ? is dimmed while the clock runs).
  bool get timed => false;

  /// False for games without levels (Teaser of the day): no level card on
  /// results, no level on Profile.
  bool get hasLevels => true;

  /// Builds the screen that runs one session of the game.
  Widget buildScreen();
}

/// Outcome of one finished session, reported back to the progress store.
@immutable
class GameResult {
  const GameResult({
    required this.gameId,
    required this.score,
    required this.correct,
    required this.total,
    required this.endLevel,
    required this.skills,
  });

  final String gameId;
  final int score;
  final int correct;
  final int total;

  /// Difficulty level the player ended on; the next session starts here.
  final int endLevel;
  final List<Skill> skills;

  /// XP for [skill]: 10 per correct answer for the main (first) skill,
  /// 5 for the others — the split shown on the Results artboard.
  int xpFor(Skill skill) {
    if (!skills.contains(skill)) return 0;
    return correct * (skill == skills.first ? 10 : 5);
  }
}

/// The round a player most recently got wrong, for "Try a similar one".
@immutable
class NearMiss {
  const NearMiss({
    required this.round,
    required this.level,
    required this.reason,
  });

  /// 1-based round number shown to the player.
  final int round;

  /// Level the round was played at; the practice round uses the same level.
  final int level;

  /// Short reason, e.g. "You found 2 of 3."
  final String reason;
}

/// First sentence of an explanation (up to and including the first '.').
String firstSentence(String text) {
  final i = text.indexOf('.');
  return i < 0 ? text : text.substring(0, i + 1);
}
