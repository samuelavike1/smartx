import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'deduce_puzzle.dart';
import 'deduce_screen.dart';

class DeduceGame extends GameDefinition {
  const DeduceGame();

  static const String gameId = 'deduce';

  @override
  String get id => gameId;

  @override
  String get title => 'Deduce';

  @override
  String get tagline => 'Place the shapes so every clue is true.';

  @override
  IconData get icon => Icons.psychology_alt_outlined;

  @override
  List<Skill> get skills => const [Skill.logic, Skill.problemSolving];

  @override
  String levelHint(int level) {
    final d = DeduceDifficulty.forLevel(level);
    return '${d.count} shapes'
        '${d.kinds.contains(ClueKind.at) ? '' : ', no first/last clues'}'
        '${d.kinds.contains(ClueKind.between) ? ', “between” clues' : ''}';
  }

  @override
  Widget buildScreen() => const DeduceScreen();
}
