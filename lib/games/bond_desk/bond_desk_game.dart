import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'bond_puzzle.dart';
import 'bond_screen.dart';

/// Quant track, Markets pack: present value, bond prices, yields, forward
/// rates and duration.
class BondDeskGame extends GameDefinition {
  const BondDeskGame();

  static const String gameId = 'bond_desk';

  @override
  String get id => gameId;

  @override
  String get title => 'Bond Desk';

  @override
  String get tagline => 'Price bonds, read yields, and measure duration.';

  @override
  IconData get icon => Icons.account_balance_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.problemSolving];

  @override
  String levelHint(int level) => BondDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.timeline_rounded,
        'Read the timeline',
        'Bars show what the bond pays each year. The orange ? is what you '
            'solve for.',
      ),
      HowToStep(
        Icons.south_west_rounded,
        'Bring money back to today',
        'Money later is worth less now: divide by 1 + the rate for each '
            'year you wait.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the answer',
        'Smallest first. The wrong ones are common slips. No clock.',
      ),
    ],
    levels:
        'present and future value, bond prices, premium or discount, '
        'yields and forward rates, then duration.',
  );

  @override
  Widget buildScreen() => const BondScreen();
}
