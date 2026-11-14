import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'stop_puzzle.dart';
import 'stop_screen.dart';

/// Quant track: optimal stopping. Keep the roll you have, or roll again?
class StopOrRollGame extends GameDefinition {
  const StopOrRollGame();

  static const String gameId = 'stop_or_roll';

  @override
  String get id => gameId;

  @override
  String get title => 'Stop or Roll';

  @override
  String get tagline => 'Keep what you rolled, or roll again?';

  @override
  IconData get icon => Icons.casino_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.problemSolving];

  @override
  String levelHint(int level) => StopSetup.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.casino_rounded,
        'Roll',
        'The first roll is free. You win money for the roll you keep.',
      ),
      HowToStep(
        Icons.calculate_rounded,
        'Price a roll',
        'A roll is worth the average of what you\'d end up with. Compare it with what you hold.',
      ),
      HowToStep(
        Icons.check_circle_outline_rounded,
        'Keep or roll again',
        'Every call is checked; the luck of the dice isn\'t. No clock.',
      ),
    ],
    levels:
        'a cost to roll again, bigger dice, two dice, then games where you '
        'add up rolls and a 1 or 2 loses it all.',
  );

  @override
  Widget buildScreen() => const StopScreen();
}
