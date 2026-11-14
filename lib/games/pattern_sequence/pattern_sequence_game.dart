import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'pattern_sequence_screen.dart';
import 'sequence_generator.dart';

class PatternSequenceGame extends GameDefinition {
  const PatternSequenceGame();

  static const String gameId = 'pattern_sequence';

  @override
  String get id => gameId;

  @override
  String get title => 'Pattern Sequence';

  @override
  String get tagline => 'Find the rule and pick what comes next.';

  @override
  IconData get icon => Icons.auto_awesome_motion_outlined;

  @override
  List<Skill> get skills => const [
    Skill.patternRecognition,
    Skill.logic,
    Skill.attention,
  ];

  @override
  String levelHint(int level) {
    final d = SequenceDifficulty.forLevel(level);
    final rules = d.varyingAttributes == 1
        ? '1 changing rule'
        : '${d.varyingAttributes} changing rules';
    return '$rules, cycles up to ${d.maxCycleLength} tiles'
        '${d.allowSteps ? ', counting rules' : ''}';
  }

  @override
  Widget buildScreen() => const PatternSequenceScreen();
}
