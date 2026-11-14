import 'dart:math';

import 'package:material_ui/material_ui.dart';

/// The four inks. Chosen to differ as much as possible; every button also
/// shows the name, so colour is never the only cue on the controls.
enum InkColour {
  blue('Blue', Color(0xFF1E5FD6)),
  orange('Orange', Color(0xFFE06C00)),
  green('Green', Color(0xFF2E8B3E)),
  pink('Pink', Color(0xFFD0338A));

  const InkColour(this.label, this.color);

  final String label;
  final Color color;

  String get word => label.toUpperCase();
}

/// What to tap: the ink colour (usual) or what the word says.
enum InkRule {
  ink('INK'),
  word('WORD');

  const InkRule(this.cue);
  final String cue;
}

@immutable
class InkTrial {
  const InkTrial(this.word, this.ink, this.rule);

  final InkColour word;
  final InkColour ink;
  final InkRule rule;

  bool get clash => word != ink;
  InkColour get answer => rule == InkRule.ink ? ink : word;
}

@immutable
class InkDifficulty {
  const InkDifficulty({
    required this.clashShare,
    required this.flipShare,
    required this.limitMs,
  });

  factory InkDifficulty.forLevel(int level) => switch (level.clamp(1, 10)) {
    <= 2 => const InkDifficulty(clashShare: 0.5, flipShare: 0, limitMs: 3000),
    <= 4 => const InkDifficulty(clashShare: 0.7, flipShare: 0, limitMs: 2600),
    <= 6 => const InkDifficulty(clashShare: 0.85, flipShare: 0, limitMs: 2200),
    <= 8 => const InkDifficulty(clashShare: 0.7, flipShare: 0.3, limitMs: 2600),
    _ => const InkDifficulty(clashShare: 0.85, flipShare: 0.4, limitMs: 2200),
  };

  final double clashShare;

  /// Share of words where the cue flips the rule to WORD.
  final double flipShare;

  /// Time limit per word, in milliseconds.
  final int limitMs;

  static const int words = 12;

  /// A block passes at this many right.
  static const int passMark = 10;
}

/// One answer: what was tapped (null = ran out of time) and how fast.
@immutable
class InkAnswer {
  const InkAnswer(this.tapped, this.time);

  final InkColour? tapped;
  final Duration time;
}

@immutable
class InkResult {
  const InkResult({
    required this.right,
    required this.correct,
    required this.matchAvg,
    required this.clashAvg,
  });

  final int right;

  /// Per word: answered correctly?
  final List<bool> correct;

  /// Average time on correctly answered matching / clashing words, in
  /// seconds (null when there were none).
  final double? matchAvg;
  final double? clashAvg;

  bool get passed => right >= InkDifficulty.passMark;

  /// Extra seconds the clash cost on average (null if not measurable).
  double? get clashCost =>
      matchAvg == null || clashAvg == null ? null : clashAvg! - matchAvg!;
}

@immutable
class InkBlock {
  const InkBlock({
    required this.level,
    required this.seed,
    required this.trials,
    required this.limit,
  });

  final int level;
  final int seed;
  final List<InkTrial> trials;

  /// Time allowed per word.
  final Duration limit;

  int get length => trials.length;
  bool get flips => trials.any((t) => t.rule == InkRule.word);

  InkResult evaluate(List<InkAnswer> answers) {
    final correct = <bool>[];
    final matchTimes = <double>[], clashTimes = <double>[];
    for (final (i, t) in trials.indexed) {
      final a = i < answers.length ? answers[i] : null;
      final ok = a?.tapped == t.answer;
      correct.add(ok);
      if (ok) {
        (t.clash ? clashTimes : matchTimes).add(a!.time.inMilliseconds / 1000);
      }
    }
    double? avg(List<double> xs) =>
        xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    return InkResult(
      right: correct.where((c) => c).length,
      correct: correct,
      matchAvg: avg(matchTimes),
      clashAvg: avg(clashTimes),
    );
  }

  /// Review text: the first mistake explained, then what the clash cost.
  String explain(InkResult r, List<InkAnswer> answers) {
    final parts = <String>[];
    final first = r.correct.indexOf(false);
    if (first < 0) {
      parts.add('All $length right.');
    } else {
      final t = trials[first];
      final a = first < answers.length ? answers[first] : null;
      final said =
          'Word ${first + 1} said ${t.word.word} in '
          '${t.ink.label.toLowerCase()} ink';
      final why = flips ? ', and the cue said ${t.rule.cue}' : '';
      parts.add(
        a?.tapped == null
            ? '$said and ran out of time; the answer was '
                  '${t.answer.label.toLowerCase()}.'
            : '$said$why, so the answer was ${t.answer.label.toLowerCase()}.',
      );
    }
    final cost = r.clashCost;
    if (cost != null) {
      parts.add(
        cost > 0.05
            ? 'Clashing words took ${cost.toStringAsFixed(2)} s longer.'
            : 'Clashing words didn\'t slow you down.',
      );
    }
    return parts.join(' ');
  }
}

/// Builds blocks from a seed, always with some matching and some clashing
/// words, so the clash cost can be measured.
class InkGenerator {
  const InkGenerator();

  InkBlock generate({required int level, required int seed}) {
    final rng = Random(seed);
    final d = InkDifficulty.forLevel(level);
    final colours = InkColour.values;

    while (true) {
      final trials = <InkTrial>[];
      for (var i = 0; i < InkDifficulty.words; i++) {
        final ink = colours[rng.nextInt(colours.length)];
        final clash = rng.nextDouble() < d.clashShare;
        final word = clash
            ? (colours.where((c) => c != ink).toList()..shuffle(rng)).first
            : ink;
        final rule = d.flipShare > 0 && rng.nextDouble() < d.flipShare
            ? InkRule.word
            : InkRule.ink;
        trials.add(InkTrial(word, ink, rule));
      }
      final clashes = trials.where((t) => t.clash).length;
      final flips = trials.where((t) => t.rule == InkRule.word).length;
      final enoughEach = clashes >= 4 && trials.length - clashes >= 2;
      final flipOk = d.flipShare == 0 || (flips >= 2 && flips <= 6);
      if (enoughEach && flipOk) {
        return InkBlock(
          level: level,
          seed: seed,
          trials: trials,
          limit: Duration(milliseconds: d.limitMs),
        );
      }
    }
  }
}
