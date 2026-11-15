import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'brown_puzzle.dart';
import 'brown_screen.dart';

/// Quant track: Brownian motion and martingales, the continuous step after
/// Random Walk (scaling, increments, reflection, optional stopping, drift,
/// Itô's rule and geometric Brownian motion).
class BrownianPathGame extends GameDefinition {
  const BrownianPathGame();

  static const String gameId = 'brownian_path';

  @override
  String get id => gameId;

  @override
  String get title => 'Brownian Path';

  @override
  String get tagline => 'Random paths in continuous time.';

  @override
  IconData get icon => Icons.timeline_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.logic];

  @override
  String levelHint(int level) => BrownDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.timeline_rounded,
        'Read the path',
        'One possible path, its levels and times, or a bell curve with a table.',
      ),
      HowToStep(
        Icons.functions_rounded,
        'Use the rules',
        'The SD grows like √t. Fair games keep their average. Itô adds a dt.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the answer',
        'Numbers are smallest first. Most wrong ones are common slips. No clock.',
      ),
    ],
    levels:
        'scaling, steps and overlaps, the normal table, reflection, '
        'martingales, stopping times, drift, Itô\'s rule and stock prices.',
  );

  @override
  Widget buildScreen() => const BrownScreen();
}
