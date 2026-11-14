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

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.logic];

  @override
  String levelHint(int level) => OddsDifficulty.forLevel(level).hint;

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.casino_rounded,
        'Picture the setup',
        'Dice, coins, cards or a bag of balls. Everything is fair and random.',
      ),
      HowToStep(
        Icons.calculate_rounded,
        'Count equally likely outcomes',
        'Then pick the exact chance from four fractions. There is no clock.',
      ),
      HowToStep(
        Icons.school_rounded,
        'Learn from the working',
        'After each answer you see the steps, and what slip a wrong pick came from.',
      ),
    ],
    levels: 'from one die up to "at least one", "given that…" and Bayes.',
  );

  @override
  Widget buildScreen() => const OddsScreen();
}
