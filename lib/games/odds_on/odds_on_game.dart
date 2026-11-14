import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'odds_puzzle.dart';
import 'odds_screen.dart';

/// The first quant-track game: exact probabilities with worked answers.
class OddsOnGame extends GameDefinition {
  const OddsOnGame();

  static const String gameId = 'odds_on';

  @override
  String get id => gameId;

  @override
  String get title => 'Odds On';

  @override
  String get tagline => 'Pick the right probability, then see the working.';

  @override
  IconData get icon => Icons.casino_rounded;

  // Until there is a Numbers skill, probability trains problem solving and
  // logic.
  @override
  List<Skill> get skills => const [Skill.problemSolving, Skill.logic];

  @override
  String levelHint(int level) => OddsDifficulty.forLevel(level).hint;

  @override
  Widget buildScreen() => const OddsScreen();
}
