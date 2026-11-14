import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/game/speed_game.dart';

/// The four inks. Chosen to differ as much as possible; every button also
/// shows the name, so colour is never the only cue on the controls.
enum InkColour {
  blue('Blue', Color(0xFF1E5FD6), Color(0xFF6C9BFF)),
  orange('Orange', Color(0xFFD96500), Color(0xFFF59E4C)),
  green('Green', Color(0xFF2E8B3E), Color(0xFF4CC26B)),
  pink('Pink', Color(0xFFD0338A), Color(0xFFF06BB0));

  const InkColour(this.label, this.color, this.nightColor);

  final String label;
  final Color color;

  /// Brighter, so the word still reads on a dark ground.
  final Color nightColor;

  Color shade({required bool night}) => night ? nightColor : color;

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
class InkTrial implements SpeedTrial<InkColour> {
  const InkTrial(this.word, this.ink, this.rule);

  final InkColour word;
  final InkColour ink;
  final InkRule rule;

  bool get clash => word != ink;

  @override
  bool get conflict => clash;

  @override
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

typedef InkAnswer = SpeedAnswer<InkColour>;

@immutable
class InkBlock extends SpeedBlock<InkTrial, InkColour> {
  const InkBlock({
    required this.level,
    required this.seed,
    required this.trials,
    required this.limit,
  });

  @override
  final int level;
  @override
  final int seed;
  @override
  final List<InkTrial> trials;

  /// Time allowed per word.
  @override
  final Duration limit;

  @override
  int get passMark => InkDifficulty.passMark;

  bool get flips => trials.any((t) => t.rule == InkRule.word);

  @override
  InkBlock withTrials(List<InkTrial> trials) =>
      InkBlock(level: level, seed: seed, trials: trials, limit: limit);

  @override
  String get conflictName => 'Clashing words';

  @override
  String get noCostSentence => 'Clashing words didn\'t slow you down.';

  @override
  String mistake(SpeedResult r, List<InkAnswer> answers) {
    final first = r.correct.indexOf(false);
    if (first < 0) return 'All $length right.';
    final t = trials[first];
    final a = first < answers.length ? answers[first] : null;
    final said =
        'Word ${first + 1} said ${t.word.word} in '
        '${t.ink.label.toLowerCase()} ink';
    final why = flips ? ', and the cue said ${t.rule.cue}' : '';
    return a?.tapped == null
        ? '$said and ran out of time; the answer was '
              '${t.answer.label.toLowerCase()}.'
        : '$said$why, so the answer was ${t.answer.label.toLowerCase()}.';
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
