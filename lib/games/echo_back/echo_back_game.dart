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
  Widget buildScreen() => const EchoScreen();
}
