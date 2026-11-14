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
  Widget buildScreen() => const ArrowScreen();
}
