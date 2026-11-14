import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'path_finder_screen.dart';
import 'path_puzzle.dart';

class PathFinderGame extends GameDefinition {
  const PathFinderGame();

  static const String gameId = 'path_finder';

  @override
  String get id => gameId;

  @override
  String get title => 'Path Finder';

  @override
  String get tagline => 'Slide to the flag within the move limit.';

  @override
  IconData get icon => Icons.alt_route_rounded;

  @override
  List<Skill> get skills => const [Skill.problemSolving, Skill.logic];

  @override
  String levelHint(int level) {
    final d = PathDifficulty.forLevel(level);
    final extras = [
      if (d.useKey) 'key and gate',
      if (d.arrows == 1) '1 arrow tile',
      if (d.arrows > 1) '${d.arrows} arrow tiles',
    ];
    final spare = switch (d.slack) {
      0 => 'no spare moves',
      1 => '1 spare move',
      _ => '${d.slack} spare moves',
    };
    return '${d.size}×${d.size} board${extras.isEmpty ? '' : ', ${extras.join(', ')}'}, $spare';
  }

  @override
  Widget buildScreen() => const PathFinderScreen();
}
