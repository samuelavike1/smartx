import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'odd_puzzle.dart';
import 'odd_screen.dart';

class OddOneOutGame extends GameDefinition {
  const OddOneOutGame();

  static const String gameId = 'odd_one_out';

  @override
  String get id => gameId;

  @override
  String get title => 'Odd One Out';

  @override
  String get tagline => 'Spot the one tile that breaks the rule.';

  @override
  IconData get icon => Icons.grid_view_rounded;

  @override
  List<Skill> get skills => const [Skill.attention, Skill.patternRecognition];

  @override
  String levelHint(int level) {
    final d = OddDifficulty.forLevel(level);
    final secs = (d.limitMs / 1000).toStringAsFixed(1);
    final ways = oddWays(d.features);
    return '${d.side}×${d.side} grid, odd by $ways, $secs s a grid';
  }

  @override
  Widget buildScreen() => const OddScreen();
}

/// "colour, shape or turn".
String oddWays(List<OddFeature> features) {
  final words = [for (final f in features) f.word];
  if (words.length == 1) return words.single;
  return '${words.sublist(0, words.length - 1).join(', ')} or ${words.last}';
}
