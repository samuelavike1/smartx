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
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.visibility_rounded,
        'Study the row',
        'Each tile follows rules for its shape, its colour and how many there are.',
      ),
      HowToStep(
        Icons.lightbulb_rounded,
        'Find what changes',
        'A rule can repeat a cycle, like circle, square, circle, or count up or down.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the next tile',
        'Choose from the options. Faster answers score a little more.',
      ),
    ],
    levels: 'more features change at once, cycles get longer and counting rules join in.',
  );

  @override
  Widget buildScreen() => const PatternSequenceScreen();
}
