import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'grid_puzzle.dart';
import 'grid_recall_screen.dart';

class GridRecallGame extends GameDefinition {
  const GridRecallGame();

  static const String gameId = 'grid_recall';

  @override
  String get id => gameId;

  @override
  String get title => 'Grid Recall';

  @override
  String get tagline => 'Remember which cells lit up.';

  @override
  IconData get icon => Icons.grid_on_rounded;

  @override
  List<Skill> get skills => const [Skill.memory, Skill.attention];

  @override
  String levelHint(int level) {
    final d = GridDifficulty.forLevel(level);
    return '${d.size}×${d.size} grid with ${d.cellCount} cells'
        '${d.ordered ? ', tapped in order' : ''}';
  }

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.visibility_rounded,
        'Watch the grid',
        'Some cells light up for a moment, then go dark.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Tap the cells that lit',
        'Tap again to undo. The round ends when you have tapped as many as you saw.',
      ),
      HowToStep(
        Icons.format_list_numbered_rounded,
        'Mind the order later on',
        'From level 8 cells flash one at a time: tap them in the same order.',
      ),
    ],
    levels: 'bigger grids, more cells to remember, then the order matters.',
  );

  @override
  bool get timed => true;

  @override
  Widget buildScreen() => const GridRecallScreen();
}
