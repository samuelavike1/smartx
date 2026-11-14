import '../../games/arrow_focus/arrow_focus_game.dart';
import '../../games/better_bet/better_bet_game.dart';
import '../../games/deduce/deduce_game.dart';
import '../../games/echo_back/echo_back_game.dart';
import '../../games/grid_recall/grid_recall_game.dart';
import '../../games/ink_clash/ink_clash_game.dart';
import '../../games/mental_math/mental_math_game.dart';
import '../../games/odd_one_out/odd_one_out_game.dart';
import '../../games/odds_on/odds_on_game.dart';
import '../../games/path_finder/path_finder_game.dart';
import '../../games/pattern_sequence/pattern_sequence_game.dart';
import '../../games/scale_sleuth/scale_sleuth_game.dart';
import '../../games/stop_or_roll/stop_or_roll_game.dart';
import 'game_definition.dart';

/// All games available in the app, in display order.
const List<GameDefinition> gameRegistry = [
  PatternSequenceGame(),
  GridRecallGame(),
  DeduceGame(),
  PathFinderGame(),
  EchoBackGame(),
  InkClashGame(),
  ArrowFocusGame(),
  OddOneOutGame(),
  OddsOnGame(),
  MentalMathGame(),
  BetterBetGame(),
  ScaleSleuthGame(),
  StopOrRollGame(),
];

GameDefinition? findGame(String id) {
  for (final game in gameRegistry) {
    if (game.id == id) return game;
  }
  return null;
}
