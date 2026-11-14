import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'count_puzzle.dart';
import 'count_screen.dart';

/// Quant track: counting (arrangements, choices, codes, routes).
class CountItGame extends GameDefinition {
  const CountItGame();

  static const String gameId = 'count_it';

  @override
  String get id => gameId;

  @override
  String get title => 'Count It';

  @override
  String get tagline => 'How many ways? Count without listing them all.';

  @override
  IconData get icon => Icons.tag_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.logic];

  @override
  String levelHint(int level) => CountDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.visibility_rounded,
        'Look at the setup',
        'People, tiles, a code, a street grid: the picture shows what\'s being counted.',
      ),
      HowToStep(
        Icons.swap_horiz_rounded,
        'Ask: does order matter?',
        'Jobs and codes care about order; groups and handshakes don\'t.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the count',
        'Three of the answers are common slips. No clock.',
      ),
    ],
    levels:
        'groups, repeats, routes on a grid, round tables, "at least one", '
        'and overlaps.',
  );

  @override
  Widget buildScreen() => const CountScreen();
}
