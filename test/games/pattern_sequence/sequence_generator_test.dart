import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/pattern_sequence/sequence_generator.dart';
import 'package:smartx/games/pattern_sequence/sequence_puzzle.dart';

void main() {
  const generator = SequenceGenerator();

  PatternToken expectedAt(SequencePuzzle p, int i) {
    int v(TokenAttribute a) =>
        p.rules.firstWhere((r) => r.attribute == a).valueAt(i);
    return PatternToken(
      shape: v(TokenAttribute.shape),
      color: v(TokenAttribute.color),
      count: v(TokenAttribute.count),
    );
  }

  test('same level and seed produce the same puzzle', () {
    final a = generator.generate(level: 5, seed: 42);
    final b = generator.generate(level: 5, seed: 42);
    expect(a.visible, b.visible);
    expect(a.options, b.options);
    expect(a.answerIndex, b.answerIndex);
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level puzzles are valid', () {
      final difficulty = SequenceDifficulty.forLevel(level);
      for (var seed = 0; seed < 300; seed++) {
        final p = generator.generate(level: level, seed: seed);

        expect(p.options, hasLength(difficulty.optionCount));
        expect(p.options.toSet(), hasLength(p.options.length),
            reason: 'options must be distinct (seed $seed)');
        expect(p.visible.length, inInclusiveRange(4, 8));

        for (var i = 0; i < p.visible.length; i++) {
          expect(p.visible[i], expectedAt(p, i));
        }
        expect(p.answer, expectedAt(p, p.visible.length),
            reason: 'answer must continue the rules (seed $seed)');

        final varying = p.rules.where((r) => r.isVarying).length;
        expect(varying, difficulty.varyingAttributes);

        // Every rule must be shown often enough to be inferable.
        for (final rule in p.rules) {
          expect(p.visible.length, greaterThanOrEqualTo(rule.minVisible));
        }
      }
    });
  }

  test('StepRule wraps around', () {
    const rule = StepRule(TokenAttribute.count, start: 2, step: 1);
    expect([for (var i = 0; i < 5; i++) rule.valueAt(i)], [2, 3, 0, 1, 2]);
  });
}
