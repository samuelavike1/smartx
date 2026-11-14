import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'run_puzzle.dart';
import 'run_screen.dart';

/// Quant track: the best stretch of a sequence (and buy once, sell once).
class BestRunGame extends GameDefinition {
  const BestRunGame();

  static const String gameId = 'best_run';

  @override
  String get id => gameId;

  @override
  String get title => 'Best Run';

  @override
  String get tagline => 'Find the stretch of days that made the most.';

  @override
  IconData get icon => Icons.insights_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.problemSolving];

  @override
  String levelHint(int level) => RunDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.bar_chart_rounded,
        'Read the days',
        'Each bar is a day\'s profit: up for a gain, down for a loss.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick a stretch',
        'Tap the first day, then the last. Tap again to start over.',
      ),
      HowToStep(
        Icons.lock_rounded,
        'Lock it in',
        'Right if no other run of days in a row makes more. No clock.',
      ),
    ],
    levels:
        'longer charts, losses worth crossing (and not), then buying and '
        'selling a share once.',
  );

  @override
  Widget buildScreen() => const RunScreen();
}
