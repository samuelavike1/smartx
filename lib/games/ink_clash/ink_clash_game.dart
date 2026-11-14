import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'ink_puzzle.dart';
import 'ink_screen.dart';

class InkClashGame extends GameDefinition {
  const InkClashGame();

  static const String gameId = 'ink_clash';

  @override
  String get id => gameId;

  @override
  String get title => 'Ink Clash';

  @override
  String get tagline => 'Tap the colour of the ink, not the word.';

  @override
  IconData get icon => Icons.format_color_text_rounded;

  @override
  List<Skill> get skills => const [Skill.attention];

  @override
  String levelHint(int level) {
    final d = InkDifficulty.forLevel(level);
    final secs = (d.limitMs / 1000).toStringAsFixed(1);
    final clash = '${(d.clashShare * 100).round()}% clashing words';
    return '$clash${d.flipShare > 0 ? ', rule flips' : ''}, $secs s a word';
  }

  @override
  Widget buildScreen() => const InkScreen();
}
