import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'expect_puzzle.dart';
import 'expect_screen.dart';

/// Quant track: expected values, each with a shortcut (linearity, tallies,
/// waiting times, symmetry).
class ExpectItGame extends GameDefinition {
  const ExpectItGame();

  static const String gameId = 'expect_it';

  @override
  String get id => gameId;

  @override
  String get title => 'Expect It';

  @override
  String get tagline => 'What happens on average? Find the shortcut.';

  @override
  IconData get icon => Icons.functions_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.logic];

  @override
  String levelHint(int level) => ExpDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.casino_outlined,
        'Read the setup',
        'Dice, coins, cards or a stick, and what to average.',
      ),
      HowToStep(
        Icons.auto_fix_high_rounded,
        'Find the shortcut',
        'Add averages, tally chances, or use symmetry. No long sums.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the number',
        'Smallest first. Three are common slips. No clock.',
      ),
    ],
    levels:
        'adding averages, waiting times, tallies, the higher of two dice, '
        'collecting faces, sticks and decks.',
  );

  @override
  Widget buildScreen() => const ExpectScreen();
}
