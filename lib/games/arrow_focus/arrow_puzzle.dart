import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/game/speed_game.dart';

enum ArrowDir {
  left('Left', Icons.arrow_back_rounded),
  up('Up', Icons.arrow_upward_rounded),
  down('Down', Icons.arrow_downward_rounded),
  right('Right', Icons.arrow_forward_rounded);

  const ArrowDir(this.label, this.icon);

  final String label;
  final IconData icon;

  String get word => label.toLowerCase();
  bool get vertical => this == up || this == down;

  /// The direction of a swipe, or null when it's too diagonal to tell.
  /// Vertical swipes only count when [fourWays].
  static ArrowDir? fromSwipe(Offset travel, {required bool fourWays}) {
    final dx = travel.dx.abs(), dy = travel.dy.abs();
    if (dx > dy * 1.5) return travel.dx < 0 ? left : right;
    if (fourWays && dy > dx * 1.5) return travel.dy < 0 ? up : down;
    return null;
  }
}

/// A row of [count] arrows: the middle one points [middle], all the others
/// point [flank].
@immutable
class ArrowTrial implements SpeedTrial<ArrowDir> {
  const ArrowTrial(this.middle, this.flank, this.count);

  final ArrowDir middle;
  final ArrowDir flank;
  final int count;

  @override
  ArrowDir get answer => middle;

  /// The other arrows disagree with the middle one.
  @override
  bool get conflict => middle != flank;

  List<ArrowDir> get arrows => [
    for (var i = 0; i < count; i++) i == count ~/ 2 ? middle : flank,
  ];
}

@immutable
class ArrowDifficulty {
  const ArrowDifficulty({
    required this.count,
    required this.conflictShare,
    required this.fourWays,
    required this.limitMs,
  });

  factory ArrowDifficulty.forLevel(int level) => switch (level.clamp(1, 10)) {
    <= 2 => const ArrowDifficulty(
      count: 5,
      conflictShare: 0.3,
      fourWays: false,
      limitMs: 3000,
    ),
    <= 4 => const ArrowDifficulty(
      count: 5,
      conflictShare: 0.5,
      fourWays: false,
      limitMs: 2400,
    ),
    <= 6 => const ArrowDifficulty(
      count: 7,
      conflictShare: 0.6,
      fourWays: false,
      limitMs: 2000,
    ),
    <= 8 => const ArrowDifficulty(
      count: 7,
      conflictShare: 0.6,
      fourWays: true,
      limitMs: 2400,
    ),
    _ => const ArrowDifficulty(
      count: 9,
      conflictShare: 0.7,
      fourWays: true,
      limitMs: 1800,
    ),
  };

  /// Arrows in a row (odd, so there is a middle).
  final int count;

  /// Share of rows where the other arrows disagree with the middle one.
  final double conflictShare;

  /// Up and down too, not just left and right.
  final bool fourWays;

  /// Time limit per row, in milliseconds.
  final int limitMs;

  List<ArrowDir> get directions =>
      fourWays ? ArrowDir.values : const [ArrowDir.left, ArrowDir.right];

  static const int rows = 12;

  /// A block passes at this many right.
  static const int passMark = 10;
}

typedef ArrowAnswer = SpeedAnswer<ArrowDir>;

@immutable
class ArrowBlock extends SpeedBlock<ArrowTrial, ArrowDir> {
  const ArrowBlock({
    required this.level,
    required this.seed,
    required this.trials,
    required this.limit,
    required this.fourWays,
  });

  @override
  final int level;
  @override
  final int seed;
  @override
  final List<ArrowTrial> trials;

  /// Time allowed per row.
  @override
  final Duration limit;

  final bool fourWays;

  @override
  int get passMark => ArrowDifficulty.passMark;

  @override
  ArrowBlock withTrials(List<ArrowTrial> trials) => ArrowBlock(
    level: level,
    seed: seed,
    trials: trials,
    limit: limit,
    fourWays: fourWays,
  );

  List<ArrowDir> get directions =>
      fourWays ? ArrowDir.values : const [ArrowDir.left, ArrowDir.right];

  @override
  String get conflictName => 'Rows where the arrows disagreed';

  @override
  String get noCostSentence => 'The other arrows didn\'t slow you down.';

  @override
  String mistake(SpeedResult r, List<ArrowAnswer> answers) {
    final first = r.correct.indexOf(false);
    if (first < 0) return 'All $length right.';
    final t = trials[first];
    final a = first < answers.length ? answers[first] : null;
    final row = 'Row ${first + 1}';
    final what = t.conflict
        ? 'the middle arrow pointed ${t.middle.word} while the others '
              'pointed ${t.flank.word}'
        : 'all the arrows pointed ${t.middle.word}';
    return a?.tapped == null
        ? '$row ran out of time: $what.'
        : '$row: $what, so the answer was ${t.middle.word}.';
  }
}

/// Builds blocks from a seed, always with some agreeing and some
/// disagreeing rows (so the cost can be measured), both answers well used,
/// and, with four ways, some up/down answers.
class ArrowGenerator {
  const ArrowGenerator();

  ArrowBlock generate({required int level, required int seed}) {
    final rng = Random(seed);
    final d = ArrowDifficulty.forLevel(level);
    final dirs = d.directions;

    while (true) {
      final trials = <ArrowTrial>[];
      for (var i = 0; i < ArrowDifficulty.rows; i++) {
        final middle = dirs[rng.nextInt(dirs.length)];
        final conflict = rng.nextDouble() < d.conflictShare;
        final flank = conflict
            ? (dirs.where((x) => x != middle).toList()..shuffle(rng)).first
            : middle;
        trials.add(ArrowTrial(middle, flank, d.count));
      }
      final conflicts = trials.where((t) => t.conflict).length;
      final calm = trials.length - conflicts;
      final lefts = trials.where((t) => t.middle == ArrowDir.left).length;
      final rights = trials.where((t) => t.middle == ArrowDir.right).length;
      final verticals = trials.where((t) => t.middle.vertical).length;
      final enoughEach = conflicts >= 3 && calm >= 2;
      final balanced = d.fourWays
          ? verticals >= 3 && lefts + rights >= 3
          : lefts >= 3 && rights >= 3;
      if (enoughEach && balanced) {
        return ArrowBlock(
          level: level,
          seed: seed,
          trials: trials,
          limit: Duration(milliseconds: d.limitMs),
          fourWays: d.fourWays,
        );
      }
    }
  }
}
