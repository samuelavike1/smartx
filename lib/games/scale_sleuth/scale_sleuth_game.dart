import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'scale_puzzle.dart';
import 'scale_screen.dart';

/// Quant track: find the fake coin with a balance in a few weighings.
class ScaleSleuthGame extends GameDefinition {
  const ScaleSleuthGame();

  static const String gameId = 'scale_sleuth';

  @override
  String get id => gameId;

  @override
  String get title => 'Scale Sleuth';

  @override
  String get tagline => 'Find the fake coin with a balance scale.';

  @override
  IconData get icon => Icons.scale_rounded;

  @override
  List<Skill> get skills => const [Skill.logic, Skill.problemSolving];

  @override
  String levelHint(int level) => ScaleSetup.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.touch_app_rounded,
        'Load the pans',
        'Pick a pan, then tap coins to put them on it. Tap a coin on a pan to take it off.',
      ),
      HowToStep(
        Icons.scale_rounded,
        'Weigh',
        'Same number on each side. The scale shows which side is heavier, or that they balance.',
      ),
      HowToStep(
        Icons.search_rounded,
        'Name the fake',
        'Luck won\'t help: the fake stays open until only one coin fits. No clock.',
      ),
    ],
    levels:
        'more coins, three weighings, then a fake that could be heavier or '
        'lighter.',
  );

  @override
  Widget buildScreen() => const ScaleScreen();
}
