import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'desk_puzzle.dart';
import 'desk_screen.dart';

/// Quant track, Markets pack: option payoffs, parity, a one-step tree and
/// the Greeks.
class OptionsDeskGame extends GameDefinition {
  const OptionsDeskGame();

  static const String gameId = 'options_desk';

  @override
  String get id => gameId;

  @override
  String get title => 'Options Desk';

  @override
  String get tagline => 'Price and trade options, one question at a time.';

  @override
  IconData get icon => Icons.candlestick_chart_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.problemSolving];

  @override
  String levelHint(int level) => DeskDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.receipt_long_rounded,
        'Read the position',
        'The chips say what you hold: call or put, strike, and what you paid.',
      ),
      HowToStep(
        Icons.show_chart_rounded,
        'Use the picture',
        'A payoff chart, a price tree or a quote with the Greeks.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the number',
        'Smallest first. Three are common slips. No clock.',
      ),
    ],
    levels:
        'profits, break-evens, spreads, put–call parity, pricing on a tree, '
        'then the Greeks.',
  );

  @override
  Widget buildScreen() => const DeskScreen();
}
