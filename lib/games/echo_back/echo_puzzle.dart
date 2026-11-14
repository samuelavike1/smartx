import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// What a tap claims matches N steps back.
enum EchoChannel {
  square('square'),
  colour('colour');

  const EchoChannel(this.word);
  final String word;
}

/// How one step went, for the review timeline.
enum StepOutcome { warmup, quiet, hit, miss, falseTap }

/// Colours used in dual mode (content colours from the shared puzzle
/// palette, chosen to differ in lightness as well as hue).
const echoColours = [
  Color(0xFF1E88E5), // blue
  Color(0xFFE53935), // red
  Color(0xFF43A047), // green
  Color(0xFFFB8C00), // orange
];

@immutable
class EchoDifficulty {
  const EchoDifficulty({
    required this.n,
    required this.dual,
    required this.interval,
  });

  factory EchoDifficulty.forLevel(int level) => switch (level.clamp(1, 10)) {
    <= 2 => const EchoDifficulty(n: 1, dual: false, interval: 2200),
    <= 4 => const EchoDifficulty(n: 2, dual: false, interval: 2200),
    <= 6 => const EchoDifficulty(n: 2, dual: false, interval: 1800),
    <= 8 => const EchoDifficulty(n: 2, dual: true, interval: 2400),
    _ => const EchoDifficulty(n: 3, dual: false, interval: 2200),
  };

  /// Compare with the item this many steps back.
  final int n;

  /// Square and colour both count (two buttons).
  final bool dual;

  /// Milliseconds per step.
  final int interval;

  /// Scored steps per block (after the first [n] warm-up steps).
  static const int steps = 14;
}

@immutable
class EchoItem {
  const EchoItem(this.cell, this.colour);

  /// 0–8 on the 3×3 grid, row-major.
  final int cell;

  /// Index into [echoColours] (always 0 in single mode).
  final int colour;
}

@immutable
class EchoResult {
  const EchoResult({
    required this.targets,
    required this.hits,
    required this.misses,
    required this.falseTaps,
    required this.outcomes,
    required this.dual,
  });

  final int targets;
  final int hits;

  /// Missed matches as (step, channel), in step order.
  final List<(int, EchoChannel)> misses;

  /// Taps on non-matches as (step, channel), in step order.
  final List<(int, EchoChannel)> falseTaps;
  final List<StepOutcome> outcomes;
  final bool dual;

  /// ≥ 75% of matches caught and at most 1 false tap (2 in dual mode).
  bool get passed =>
      hits >= (targets * 0.75).ceil() && falseTaps.length <= (dual ? 2 : 1);
}

/// One block: a stream of items and the rules for judging taps.
@immutable
class EchoBlock {
  const EchoBlock({
    required this.level,
    required this.seed,
    required this.n,
    required this.dual,
    required this.interval,
    required this.items,
  });

  final int level;
  final int seed;
  final int n;
  final bool dual;
  final Duration interval;
  final List<EchoItem> items;

  int get length => items.length;

  /// How long each item stays lit.
  Duration get showFor =>
      Duration(milliseconds: min(700, interval.inMilliseconds * 45 ~/ 100));

  bool isTarget(int step, EchoChannel channel) {
    if (step < n || step >= length) return false;
    final now = items[step], back = items[step - n];
    return channel == EchoChannel.square
        ? now.cell == back.cell
        : dual && now.colour == back.colour;
  }

  List<EchoChannel> get channels =>
      dual ? EchoChannel.values : const [EchoChannel.square];

  int targetCount(EchoChannel channel) => [
    for (var i = 0; i < length; i++)
      if (isTarget(i, channel)) i,
  ].length;

  EchoResult evaluate({
    required Set<int> squareTaps,
    Set<int> colourTaps = const {},
  }) {
    var targets = 0, hits = 0;
    final misses = <(int, EchoChannel)>[];
    final falseTaps = <(int, EchoChannel)>[];
    final outcomes = <StepOutcome>[];

    for (var i = 0; i < length; i++) {
      if (i < n) {
        outcomes.add(StepOutcome.warmup);
        // A tap during warm-up can't be a match.
        if (squareTaps.contains(i)) falseTaps.add((i, EchoChannel.square));
        if (colourTaps.contains(i)) falseTaps.add((i, EchoChannel.colour));
        continue;
      }
      var stepHit = false, stepMiss = false, stepFalse = false;
      for (final ch in channels) {
        final tapped = (ch == EchoChannel.square ? squareTaps : colourTaps)
            .contains(i);
        if (isTarget(i, ch)) {
          targets++;
          if (tapped) {
            hits++;
            stepHit = true;
          } else {
            misses.add((i, ch));
            stepMiss = true;
          }
        } else if (tapped) {
          falseTaps.add((i, ch));
          stepFalse = true;
        }
      }
      outcomes.add(
        stepMiss
            ? StepOutcome.miss
            : stepFalse
            ? StepOutcome.falseTap
            : stepHit
            ? StepOutcome.hit
            : StepOutcome.quiet,
      );
    }
    return EchoResult(
      targets: targets,
      hits: hits,
      misses: misses,
      falseTaps: falseTaps,
      outcomes: outcomes,
      dual: dual,
    );
  }

  /// Review text: the first miss with the step it matched, then totals.
  String explain(EchoResult r) {
    final f = r.falseTaps.length;
    final taps = f == 1 ? '1 false tap' : '$f false taps';
    if (r.misses.isEmpty && f == 0) {
      return 'Caught all ${r.targets} matches with no false taps.';
    }
    final summary = '${r.hits} of ${r.targets} matches caught, $taps.';
    if (r.misses.isNotEmpty) {
      final (step, ch) = r.misses.first;
      return 'You missed step ${step + 1}: it lit the same ${ch.word} as '
          'step ${step - n + 1}. $summary';
    }
    final (step, ch) = r.falseTaps.first;
    final back = step - n + 1;
    return back < 1
        ? 'Step ${step + 1} came before anything $n back. $summary'
        : 'Step ${step + 1} wasn\'t the same ${ch.word} as step $back. $summary';
  }
}

/// Builds blocks from a seed. Around 1 step in 3 is a match, and each block
/// has a fair number of them (4–6, or 3–5 per channel in dual mode).
class EchoGenerator {
  const EchoGenerator();

  EchoBlock generate({required int level, required int seed}) {
    final rng = Random(seed);
    final d = EchoDifficulty.forLevel(level);
    final length = d.n + EchoDifficulty.steps;

    int other(int avoid, int size) {
      final v = rng.nextInt(size - 1);
      return v >= avoid ? v + 1 : v;
    }

    while (true) {
      final items = <EchoItem>[];
      for (var i = 0; i < length; i++) {
        if (i < d.n) {
          items.add(EchoItem(rng.nextInt(9), d.dual ? rng.nextInt(4) : 0));
          continue;
        }
        final back = items[i - d.n];
        final cell = rng.nextDouble() < 0.3 ? back.cell : other(back.cell, 9);
        final colour = !d.dual
            ? 0
            : (rng.nextDouble() < 0.3 ? back.colour : other(back.colour, 4));
        items.add(EchoItem(cell, colour));
      }
      final block = EchoBlock(
        level: level,
        seed: seed,
        n: d.n,
        dual: d.dual,
        interval: Duration(milliseconds: d.interval),
        items: items,
      );
      final sq = block.targetCount(EchoChannel.square);
      final co = block.targetCount(EchoChannel.colour);
      final ok = d.dual
          ? (sq >= 3 && sq <= 5 && co >= 3 && co <= 5)
          : (sq >= 4 && sq <= 6);
      if (ok) return block;
    }
  }
}
