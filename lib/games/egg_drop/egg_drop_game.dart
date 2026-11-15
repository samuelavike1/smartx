import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'egg_puzzle.dart';
import 'egg_screen.dart';

/// Decisions: find the highest safe floor with a few eggs and a drop budget.
class EggDropGame extends GameDefinition {
  const EggDropGame();

  static const String gameId = 'egg_drop';

  @override
  String get id => gameId;

  @override
  String get title => 'Egg Drop';

  @override
  String get tagline => 'Find the highest safe floor in the fewest drops.';

  @override
  IconData get icon => Icons.egg_alt_rounded;

  @override
  List<Skill> get skills => const [Skill.problemSolving, Skill.logic];

  @override
  String levelHint(int level) => EggSetup.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.touch_app_rounded,
        'Pick a floor, then drop',
        'Above the safe floor an egg breaks and is gone. At or below it, the '
            'egg survives for reuse.',
      ),
      HowToStep(
        Icons.egg_alt_rounded,
        'Find the highest safe floor',
        'It could be 0, if eggs break even from floor 1. Grey floors are '
            'ruled out.',
      ),
      HowToStep(
        Icons.psychology_alt_rounded,
        'Plan for the worst',
        'Each drop gets the answer that is worst for you. Settle it within '
            'the drops. No clock.',
      ),
    ],
    levels:
        'more floors, then three eggs; the drop budget is always just '
        'enough.',
  );

  @override
  Widget buildScreen() => const EggScreen();
}
