import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'coin_puzzle.dart';
import 'coin_screen.dart';

/// Quant track: waiting for coin patterns, and races between them.
class CoinRaceGame extends GameDefinition {
  const CoinRaceGame();

  static const String gameId = 'coin_race';

  @override
  String get id => gameId;

  @override
  String get title => 'Coin Race';

  @override
  String get tagline => 'Which pattern turns up first, HH or HT?';

  @override
  IconData get icon => Icons.toll_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.logic];

  @override
  String levelHint(int level) => CoinDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.toll_rounded,
        'Read the patterns',
        'H is heads (filled), T is tails. Patterns are flips in a row.',
      ),
      HowToStep(
        Icons.compare_arrows_rounded,
        'Watch the overlaps',
        'Where a pattern\'s end can start it again, or start its rival, decides waits and races.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the answer',
        'Three of the four are common slips. No clock.',
      ),
    ],
    levels:
        'three- and four-flip patterns, picking a pattern against a friend, '
        'and a bent coin.',
  );

  @override
  Widget buildScreen() => const CoinScreen();
}
