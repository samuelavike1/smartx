import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'bell_puzzle.dart';
import 'bell_screen.dart';

/// Quant track: variance, standard deviation and the bell curve (adding
/// variances, scaling, 68–95–99.7, z-scores, averages, binomial, Poisson,
/// covariance).
class SpreadBellGame extends GameDefinition {
  const SpreadBellGame();

  static const String gameId = 'spread_bell';

  @override
  String get id => gameId;

  @override
  String get title => 'Spread & Bell';

  @override
  String get tagline => 'How spread out is it? Variance and the bell curve.';

  @override
  IconData get icon => Icons.bar_chart_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.logic];

  @override
  String levelHint(int level) => BellDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.bar_chart_rounded,
        'Read the card',
        'Dice, a list, a bell curve or a chart, and the spread to find.',
      ),
      HowToStep(
        Icons.auto_fix_high_rounded,
        'Work with variances',
        'They add for independent pieces. Take the square root for the SD last.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the number',
        'Smallest first. Most wrong ones are common slips. No clock.',
      ),
    ],
    levels:
        'adding variances, scaling, the 68–95–99.7 rule, z-scores, averages, '
        'binomial and Poisson counts, covariance.',
  );

  @override
  Widget buildScreen() => const BellScreen();
}
