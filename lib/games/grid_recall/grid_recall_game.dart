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
  Widget buildScreen() => const GridRecallScreen();
}
