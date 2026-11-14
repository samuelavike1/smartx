import '../../games/deduce/deduce_game.dart';
import '../../games/grid_recall/grid_recall_game.dart';
import '../../games/path_finder/path_finder_game.dart';
import '../../games/pattern_sequence/pattern_sequence_game.dart';
import 'game_definition.dart';

/// All games available in the app, in display order.
const List<GameDefinition> gameRegistry = [
  PatternSequenceGame(),
  GridRecallGame(),
  DeduceGame(),
  PathFinderGame(),
];

GameDefinition? findGame(String id) {
  for (final game in gameRegistry) {
    if (game.id == id) return game;
  }
  return null;
}
