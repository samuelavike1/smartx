import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'calc_puzzle.dart';
import 'calc_screen.dart';

/// Quant track: the calculus an interview expects in your head (slopes,
/// areas, limits, tangent-line estimates, Taylor series, turning points).
class CalcSprintGame extends GameDefinition {
  const CalcSprintGame();

  static const String gameId = 'calc_sprint';

  @override
  String get id => gameId;

  @override
  String get title => 'Calc Sprint';

  @override
  String get tagline => 'Slopes, areas and limits, in your head.';

  @override
  IconData get icon => Icons.trending_up_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.problemSolving];

  @override
  String levelHint(int level) => CalcDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.functions_rounded,
        'Read the maths',
        'A function, an integral or a limit, often with its graph.',
      ),
      HowToStep(
        Icons.edit_note_rounded,
        'Work it out in your head',
        'Use the rules: power, product, chain, L\'Hôpital, one tangent step.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the answer',
        'Most wrong ones are common slips. No clock.',
      ),
    ],
    levels:
        'derivatives, the product and chain rules, eˣ and ln x, integrals, '
        'limits, quick estimates, Taylor series, maxima and minima.',
  );

  @override
  Widget buildScreen() => const CalcScreen();
}
