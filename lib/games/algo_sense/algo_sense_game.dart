import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'algo_puzzle.dart';
import 'algo_screen.dart';

/// Quant and coding interviews: algorithms and numerical methods, answered
/// by reasoning rather than code: binary search, loop counts, sorting,
/// recursion, dynamic programming, bits, Monte Carlo, paths, Newton.
class AlgoSenseGame extends GameDefinition {
  const AlgoSenseGame();

  static const String gameId = 'algo_sense';

  @override
  String get id => gameId;

  @override
  String get title => 'Algo Sense';

  @override
  String get tagline => 'Algorithms by reasoning, not code.';

  @override
  IconData get icon => Icons.code_rounded;

  @override
  List<Skill> get skills => const [Skill.logic, Skill.problemSolving];

  @override
  String levelHint(int level) => AlgoDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.account_tree_rounded,
        'Read the setup',
        'A sorted list, a loop, a call tree, coins, bits, darts or a graph. '
            'Orange marks the unknown.',
      ),
      HowToStep(
        Icons.psychology_rounded,
        'Reason, don\'t code',
        'Count the work or find the value: halve, add up, cancel pairs, '
            'take a Newton step.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the answer',
        'Numbers go smallest first. Most wrong ones are common slips. No '
            'clock.',
      ),
    ],
    levels:
        'binary search, counting work, sorting, recursion, dynamic '
        'programming, bits, Monte Carlo, paths and Newton\'s method.',
  );

  @override
  Widget buildScreen() => const AlgoScreen();
}
