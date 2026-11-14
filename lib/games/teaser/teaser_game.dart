import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'teaser_screen.dart';

/// Quant track: one classic brain teaser a day, retold in our own words,
/// with hints shown one at a time.
class TeaserGame extends GameDefinition {
  const TeaserGame();

  static const String gameId = 'teaser';

  @override
  String get id => gameId;

  @override
  String get title => 'Teaser of the day';

  @override
  String get tagline =>
      'One classic puzzle a day, with hints if you need them.';

  @override
  IconData get icon => Icons.lightbulb_rounded;

  @override
  List<Skill> get skills => const [Skill.problemSolving, Skill.logic];

  @override
  String levelHint(int level) => 'a new teaser every day';

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.menu_book_rounded,
        'Read the teaser',
        'A classic puzzle, retold. Most have a tempting wrong answer.',
      ),
      HowToStep(
        Icons.lightbulb_outline_rounded,
        'Take a hint if stuck',
        'Up to three, one at a time. Each costs 30 points.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the answer',
        'One teaser a day; play again for a bonus one. No clock.',
      ),
    ],
    levels: 'every day brings a new one, from easy to hard.',
  );

  @override
  Widget buildScreen() => const TeaserScreen();
}
