import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'bet_puzzle.dart';
import 'bet_screen.dart';

/// Quant track: compare two bets by their average win (expected value).
class BetterBetGame extends GameDefinition {
  const BetterBetGame();

  static const String gameId = 'better_bet';

  @override
  String get id => gameId;

  @override
  String get title => 'Better Bet';

  @override
  String get tagline => 'Pick the bet that pays more on average.';

  @override
  IconData get icon => Icons.balance_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.problemSolving];

  @override
  String levelHint(int level) => BetDifficulty.forLevel(level).hint;

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.casino_rounded,
        'Read both bets',
        'Each is played with dice, coins or cards. Work out the chance of each prize yourself.',
      ),
      HowToStep(
        Icons.calculate_rounded,
        'Find the average win',
        'Chance × prize, added up, minus any cost to play.',
      ),
      HowToStep(
        Icons.balance_rounded,
        'Pick the better one',
        'Bet A, Bet B, or Same if they average exactly the same. No clock.',
      ),
    ],
    levels:
        'costs to play, several prizes, win-or-lose bets, then whether to '
        'pay to play at all.',
  );

  @override
  Widget buildScreen() => const BetScreen();
}
