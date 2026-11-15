import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'risk_puzzle.dart';
import 'risk_screen.dart';

/// Quant track, Markets pack: portfolio risk and return, from a two-asset
/// mix to Sharpe, CAPM, covariance and Value at Risk.
class RiskDeskGame extends GameDefinition {
  const RiskDeskGame();

  static const String gameId = 'risk_desk';

  @override
  String get id => gameId;

  @override
  String get title => 'Risk Desk';

  @override
  String get tagline => 'Weigh risk against return, one portfolio at a time.';

  @override
  IconData get icon => Icons.pie_chart_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.problemSolving];

  @override
  String levelHint(int level) => RiskDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.pie_chart_rounded,
        'Read the portfolio',
        'Chips give each asset\'s return and vol: how much the return swings '
            '(its standard deviation).',
      ),
      HowToStep(
        Icons.scatter_plot_rounded,
        'Use the picture',
        'The weights as a split bar, a risk–return chart, a covariance grid '
            'or a bell curve of losses.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the number',
        'Smallest first. Most wrong ones are common slips. No clock.',
      ),
    ],
    levels:
        'expected return, risk at correlation 1, 0 and −1, Sharpe, CAPM, '
        'diversification, covariance, Value at Risk, then the lowest-risk '
        'mix.',
  );

  @override
  Widget buildScreen() => const RiskScreen();
}
