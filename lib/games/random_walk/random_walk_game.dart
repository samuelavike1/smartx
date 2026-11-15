import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'walk_puzzle.dart';
import 'walk_screen.dart';

/// Quant track: random walks: gambler's ruin, drift, the cliff, and fair
/// games that keep their average.
class RandomWalkGame extends GameDefinition {
  const RandomWalkGame();

  static const String gameId = 'random_walk';

  @override
  String get id => gameId;

  @override
  String get title => 'Random Walk';

  @override
  String get tagline => 'Left or right at random: where does it end?';

  @override
  IconData get icon => Icons.directions_walk_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.problemSolving];

  @override
  String levelHint(int level) => WalkDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.linear_scale_rounded,
        'Read the track',
        'Where the walk starts, how it steps, and what stops it.',
      ),
      HowToStep(
        Icons.functions_rounded,
        'Find the shortcut',
        'Fair walks keep their average; drift adds up step by step.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the number',
        'Smallest first. Three are common slips. No clock.',
      ),
    ],
    levels:
        'how long walks last, where they end up, leaning coins, cliffs and '
        'lazy walkers.',
  );

  @override
  Widget buildScreen() => const WalkScreen();
}
