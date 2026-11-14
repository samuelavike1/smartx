import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'arrow_puzzle.dart';
import 'arrow_screen.dart';

class ArrowFocusGame extends GameDefinition {
  const ArrowFocusGame();

  static const String gameId = 'arrow_focus';

  @override
  String get id => gameId;

  @override
  String get title => 'Arrow Focus';

  @override
  String get tagline => 'Follow the middle arrow, ignore the rest.';

  @override
  IconData get icon => Icons.double_arrow_rounded;

  @override
  List<Skill> get skills => const [Skill.attention];

  @override
  String levelHint(int level) {
    final d = ArrowDifficulty.forLevel(level);
    final secs = (d.limitMs / 1000).toStringAsFixed(1);
    final ways = d.fourWays ? ', 4 ways' : '';
    return '${d.count} arrows, ${(d.conflictShare * 100).round()}% '
        'disagree$ways, $secs s a row';
  }

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.compare_arrows_rounded,
        'Look only at the middle arrow',
        'A row of arrows appears. The one above the yellow dot is the one that counts.',
      ),
      HowToStep(
        Icons.swipe_rounded,
        'Answer its direction',
        'Swipe that way anywhere on the screen, or tap the button.',
      ),
      HowToStep(
        Icons.timer_outlined,
        'Beat the bar',
        'Each row has a time limit. A block of 12 passes at 10 right.',
      ),
    ],
    levels: 'longer rows, less time, more arrows that disagree, then up and down too.',
  );

  @override
  bool get timed => true;

  @override
  Widget buildScreen() => const ArrowScreen();
}
