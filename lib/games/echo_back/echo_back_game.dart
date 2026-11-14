import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'echo_puzzle.dart';
import 'echo_screen.dart';

class EchoBackGame extends GameDefinition {
  const EchoBackGame();

  static const String gameId = 'echo_back';

  @override
  String get id => gameId;

  @override
  String get title => 'Echo Back';

  @override
  String get tagline => 'Tap when a square matches the one N steps back.';

  @override
  IconData get icon => Icons.graphic_eq_rounded;

  @override
  List<Skill> get skills => const [Skill.memory, Skill.attention];

  @override
  String levelHint(int level) {
    final d = EchoDifficulty.forLevel(level);
    final secs = (d.interval / 1000).toStringAsFixed(1);
    return '${d.n} back${d.dual ? ', square and colour' : ''}, $secs s per step';
  }

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.grid_view_rounded,
        'Watch the squares',
        'One square lights at a time.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Tap Match when it repeats',
        'Tap when the square is the same one that lit N steps earlier. N is shown on screen.',
      ),
      HowToStep(
        Icons.do_not_touch_rounded,
        'Don\'t tap otherwise',
        'False taps count against you. A block passes when you catch most matches.',
      ),
    ],
    levels: 'from 1 back to 2 back, faster steps, square and colour at once, then 3 back.',
  );

  @override
  bool get timed => true;

  @override
  Widget buildScreen() => const EchoScreen();
}
