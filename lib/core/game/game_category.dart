import 'package:material_ui/material_ui.dart';

import '../skills/skill.dart';
import 'game_definition.dart';
import 'game_registry.dart';

/// The groups on the Games tab. Every game except the Teaser of the day
/// (which has its own card) belongs to exactly one, listed in play order.
enum GameCategory {
  focusMemory(
    'Focus & Memory',
    'Hold it in mind, tune out the noise',
    Icons.visibility_rounded,
    ['ink_clash', 'arrow_focus', 'odd_one_out', 'grid_recall', 'echo_back'],
  ),
  logic(
    'Logic & Puzzles',
    'Rules, clues and patterns',
    Icons.extension_rounded,
    ['pattern_sequence', 'deduce', 'path_finder', 'scale_sleuth'],
  ),
  numbers(
    'Numbers & Odds',
    'Quick sums, counting, probability',
    Icons.casino_rounded,
    ['mental_math', 'count_it', 'odds_on', 'expect_it', 'coin_race'],
  ),
  decisions(
    'Decisions',
    'Bets, stopping and timing',
    Icons.call_split_rounded,
    ['better_bet', 'stop_or_roll', 'best_run'],
  ),
  markets(
    'Markets',
    'Options, prices and the Greeks',
    Icons.candlestick_chart_rounded,
    ['options_desk'],
  );

  const GameCategory(this.title, this.blurb, this.icon, this.gameIds);

  final String title;
  final String blurb;
  final IconData icon;
  final List<String> gameIds;

  /// Tile colour: the skill most of the group trains. Markets has no single
  /// skill colour of its own, so it gets the dark hero tile (see the canvas).
  Color? get skillColor => switch (this) {
    focusMemory => Skill.memory.color,
    logic => Skill.logic.color,
    numbers => Skill.numbers.color,
    decisions => Skill.problemSolving.color,
    markets => null,
  };

  List<GameDefinition> get games => [for (final id in gameIds) ?findGame(id)];

  static GameCategory? byName(String name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}
