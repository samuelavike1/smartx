import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/mental_math/math_puzzle.dart';

/// Works out a problem from its text, independently of the generator.
int solve(String text) {
  final percent = RegExp(r'^(\d+)% of (\d+)$').firstMatch(text);
  if (percent != null) {
    final p = int.parse(percent[1]!), n = int.parse(percent[2]!);
    expect((n * p) % 100, 0, reason: '$text must come out whole');
    return n * p ~/ 100;
  }
  final fraction = RegExp(r'^(\d+)/(\d+) of (\d+)$').firstMatch(text);
  if (fraction != null) {
    final k = int.parse(fraction[1]!), d = int.parse(fraction[2]!);
    final n = int.parse(fraction[3]!);
    expect(n % d, 0, reason: '$text must come out whole');
    return n ~/ d * k;
  }
  final square = RegExp(r'^(\d+)²$').firstMatch(text);
  if (square != null) {
    final n = int.parse(square[1]!);
    return n * n;
  }
  final op = RegExp(r'^(\d+) ([+−×÷]) (\d+)$').firstMatch(text)!;
  final a = int.parse(op[1]!), b = int.parse(op[3]!);
  return switch (op[2]) {
    '+' => a + b,
    '−' => a - b,
    '×' => a * b,
    _ => () {
      expect(a % b, 0, reason: '$text must divide exactly');
      return a ~/ b;
    }(),
  };
}

void main() {
  const gen = MathGenerator();

  for (final kind in MathKind.values) {
    test('${kind.name}: the answer is right and the options are fair', () {
      final rng = Random(kind.index);
      for (var i = 0; i < 300; i++) {
        final t = gen.trial(kind, rng);
        expect(t.kind, kind);
        expect(t.answer, solve(t.text), reason: t.text);
        expect(t.options, hasLength(4), reason: t.text);
        expect(t.options.toSet(), hasLength(4));
        expect(t.options, contains(t.answer));
        expect(t.options, [...t.options]..sort());
        expect(t.options.every((o) => o > 0), isTrue, reason: '${t.options}');
        expect(t.how, isNotEmpty);
        expect(t.spoken, isNot(contains('×')), reason: 'read aloud as words');
      }
    });
  }

  test('carries and borrows are flagged exactly when they happen', () {
    final rng = Random(1);
    for (var i = 0; i < 500; i++) {
      final add = gen.trial(MathKind.add, rng);
      final [a, b] = [for (final s in add.text.split(' + ')) int.parse(s)];
      expect(add.hard, a % 10 + b % 10 >= 10, reason: add.text);

      final sub = gen.trial(MathKind.sub, rng);
      final [c, d] = [for (final s in sub.text.split(' − ')) int.parse(s)];
      expect(sub.hard, c % 10 < d % 10, reason: sub.text);
      expect(sub.answer, greaterThan(0));
    }
  });

  for (var level = 1; level <= 10; level++) {
    test('level $level blocks mix easy and hard problems', () {
      final d = MathDifficulty.forLevel(level);
      for (var seed = 0; seed < 100; seed++) {
        final b = gen.generate(level: level, seed: seed);
        expect(b.length, MathDifficulty.problems);
        expect(b.limit.inMilliseconds, d.limitMs);
        expect(b.trials.where((t) => t.hard).length, greaterThanOrEqualTo(3));
        expect(b.trials.where((t) => !t.hard).length, greaterThanOrEqualTo(3));
        for (final t in b.trials) {
          expect(d.kinds, contains(t.kind));
        }
      }
    });
  }

  test('same level and seed give the same block', () {
    final a = gen.generate(level: 9, seed: 3);
    final b = gen.generate(level: 9, seed: 3);
    expect(
      [for (final t in a.trials) t.text],
      [for (final t in b.trials) t.text],
    );
  });

  test('the first miss is explained with its working', () {
    final b = gen.generate(level: 5, seed: 2);
    final answers = [
      for (final (i, t) in b.trials.indexed)
        MathAnswer(
          i == 1 ? t.options.firstWhere((o) => o != t.answer) : t.answer,
          const Duration(seconds: 2),
        ),
    ];
    final r = b.evaluate(answers);
    expect(r.right, 11);
    expect(r.passed, isTrue);
    final t = b.trials[1];
    expect(
      b.mistake(r, answers),
      'Problem 2: ${t.text} = ${t.answer}. ${t.how}',
    );
  });
}
