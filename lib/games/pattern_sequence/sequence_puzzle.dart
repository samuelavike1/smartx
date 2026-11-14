import 'package:flutter/foundation.dart';

/// Visual attributes a token has. [size] is how many values each can take.
enum TokenAttribute {
  shape('shape', 6),
  color('colour', 6),
  count('count', 4);

  const TokenAttribute(this.label, this.size);

  final String label;
  final int size;
}

enum TokenShape { circle, square, triangle, diamond, hexagon, star }

/// One tile in a sequence: [count] is 0-based (0 = one shape drawn).
@immutable
class PatternToken {
  const PatternToken({
    required this.shape,
    required this.color,
    required this.count,
  });

  final int shape;
  final int color;
  final int count;

  int valueOf(TokenAttribute a) => switch (a) {
    TokenAttribute.shape => shape,
    TokenAttribute.color => color,
    TokenAttribute.count => count,
  };

  PatternToken withValue(TokenAttribute a, int value) => switch (a) {
    TokenAttribute.shape => PatternToken(
      shape: value,
      color: color,
      count: count,
    ),
    TokenAttribute.color => PatternToken(
      shape: shape,
      color: value,
      count: count,
    ),
    TokenAttribute.count => PatternToken(
      shape: shape,
      color: color,
      count: value,
    ),
  };

  @override
  bool operator ==(Object other) =>
      other is PatternToken &&
      other.shape == shape &&
      other.color == color &&
      other.count == count;

  @override
  int get hashCode => Object.hash(shape, color, count);

  @override
  String toString() => 'Token(shape: $shape, color: $color, count: $count)';
}

/// How one attribute evolves along the sequence.
sealed class AttributeRule {
  const AttributeRule(this.attribute);

  final TokenAttribute attribute;

  int valueAt(int index);

  /// How many tiles must be visible for the rule to be inferable.
  int get minVisible;

  bool get isVarying => true;

  String describe();
}

final class ConstantRule extends AttributeRule {
  const ConstantRule(super.attribute, this.value);

  final int value;

  @override
  int valueAt(int index) => value;

  @override
  int get minVisible => 1;

  @override
  bool get isVarying => false;

  @override
  String describe() => 'The ${attribute.label} never changes';
}

/// Repeats [values] in order, e.g. red, blue, red, blue…
final class CycleRule extends AttributeRule {
  const CycleRule(super.attribute, this.values);

  final List<int> values;

  @override
  int valueAt(int index) => values[index % values.length];

  /// Two full repetitions make a cycle unambiguous.
  @override
  int get minVisible => values.length * 2;

  @override
  String describe() =>
      'The ${attribute.label} repeats every ${values.length} tiles';
}

/// Moves by [step] each tile, wrapping around (used for count: 1→2→3→4→1).
final class StepRule extends AttributeRule {
  const StepRule(super.attribute, {required this.start, required this.step});

  final int start;
  final int step;

  @override
  int valueAt(int index) => (start + step * index) % attribute.size;

  @override
  int get minVisible => 3;

  @override
  String describe() {
    final direction = step == 1 ? 'goes up' : 'goes down';
    return 'The ${attribute.label} $direction by one each tile, wrapping around';
  }
}

@immutable
class SequencePuzzle {
  const SequencePuzzle({
    required this.level,
    required this.seed,
    required this.visible,
    required this.options,
    required this.answerIndex,
    required this.rules,
  });

  final int level;
  final int seed;
  final List<PatternToken> visible;
  final List<PatternToken> options;
  final int answerIndex;
  final List<AttributeRule> rules;

  PatternToken get answer => options[answerIndex];

  /// Shown after answering so players learn the rule, not just the result.
  String get explanation =>
      '${rules.where((r) => r.isVarying).map((r) => r.describe()).join('. ')}.';
}
