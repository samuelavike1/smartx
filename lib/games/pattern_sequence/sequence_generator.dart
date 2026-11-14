import 'dart:math';

import 'sequence_puzzle.dart';

/// Knobs derived from the 1–10 difficulty level.
class SequenceDifficulty {
  const SequenceDifficulty({
    required this.varyingAttributes,
    required this.maxCycleLength,
    required this.allowSteps,
    required this.optionCount,
  });

  factory SequenceDifficulty.forLevel(int level) {
    final l = level.clamp(1, 10);
    return SequenceDifficulty(
      varyingAttributes: l <= 2 ? 1 : (l <= 6 ? 2 : 3),
      maxCycleLength: l <= 3 ? 2 : (l <= 7 ? 3 : 4),
      allowSteps: l >= 4,
      optionCount: l <= 2 ? 3 : 4,
    );
  }

  /// How many attributes change along the sequence (the rest stay fixed).
  final int varyingAttributes;
  final int maxCycleLength;

  /// Whether count may follow an increasing/decreasing rule.
  final bool allowSteps;
  final int optionCount;
}

/// Builds puzzles from a seed, so the same (level, seed) always gives the
/// same puzzle. That makes daily challenges and bug reports reproducible.
class SequenceGenerator {
  const SequenceGenerator();

  static const int minVisible = 4;
  static const int maxVisible = 8;

  SequencePuzzle generate({required int level, required int seed}) {
    final rng = Random(seed);
    final difficulty = SequenceDifficulty.forLevel(level);

    final shuffled = [...TokenAttribute.values]..shuffle(rng);
    final varying = shuffled.take(difficulty.varyingAttributes).toSet();

    final rules = {
      for (final a in TokenAttribute.values)
        a: varying.contains(a)
            ? _varyingRule(a, difficulty, rng)
            : ConstantRule(a, rng.nextInt(a.size)),
    };

    PatternToken tokenAt(int i) => PatternToken(
      shape: rules[TokenAttribute.shape]!.valueAt(i),
      color: rules[TokenAttribute.color]!.valueAt(i),
      count: rules[TokenAttribute.count]!.valueAt(i),
    );

    final visibleCount = rules.values
        .map((r) => r.minVisible)
        .fold<int>(minVisible, max)
        .clamp(minVisible, maxVisible);

    final answer = tokenAt(visibleCount);
    final options = _buildOptions(answer, varying, difficulty.optionCount, rng);

    return SequencePuzzle(
      level: level,
      seed: seed,
      visible: List.generate(visibleCount, tokenAt),
      options: options,
      answerIndex: options.indexOf(answer),
      rules: rules.values.toList(),
    );
  }

  AttributeRule _varyingRule(
    TokenAttribute a,
    SequenceDifficulty d,
    Random rng,
  ) {
    if (a == TokenAttribute.count && d.allowSteps && rng.nextBool()) {
      return StepRule(
        a,
        start: rng.nextInt(a.size),
        step: rng.nextBool() ? 1 : a.size - 1, // +1 or −1 (mod size)
      );
    }

    final length = 2 + rng.nextInt(min(d.maxCycleLength, a.size) - 1);
    final List<int> values;
    if (length == 2) {
      // Two distinct values: A, B, A, B…
      values = ([
        ...List.generate(a.size, (i) => i),
      ]..shuffle(rng)).take(2).toList();
    } else {
      // Longer cycles may repeat a value (A, A, B) but never be constant.
      List<int> candidate;
      do {
        candidate = List.generate(length, (_) => rng.nextInt(a.size));
      } while (candidate.toSet().length < 2);
      values = candidate;
    }
    return CycleRule(a, values);
  }

  /// Distractors differ from the answer in exactly one attribute, mostly a
  /// varying one, so they look plausible and need real attention to reject.
  List<PatternToken> _buildOptions(
    PatternToken answer,
    Set<TokenAttribute> varying,
    int count,
    Random rng,
  ) {
    final options = <PatternToken>{answer};
    final varyingList = varying.toList();
    while (options.length < count) {
      final attribute = rng.nextDouble() < 0.7
          ? varyingList[rng.nextInt(varyingList.length)]
          : TokenAttribute.values[rng.nextInt(TokenAttribute.values.length)];
      final current = answer.valueOf(attribute);
      final offset = 1 + rng.nextInt(attribute.size - 1);
      options.add(
        answer.withValue(attribute, (current + offset) % attribute.size),
      );
    }
    return options.toList()..shuffle(rng);
  }
}
