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
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.list_rounded,
        'Read the clues',
        'Each one says where a shape goes: first, left of, next to, between…',
      ),
      HowToStep(
        Icons.view_week_rounded,
        'Place every shape',
        'Tap a shape, then a spot. Tap a placed shape to send it back.',
      ),
      HowToStep(
        Icons.check_rounded,
        'Check when the row is full',
        'Exactly one arrangement makes every clue true.',
      ),
    ],
    levels: 'more shapes, then "not" and "between" clues, then no first or last hints.',
  );

  @override
  Widget buildScreen() => const DeduceScreen();
}
