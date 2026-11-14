import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/core/difficulty/difficulty_engine.dart';

void main() {
  test('three correct answers in a row levels up', () {
    final engine = DifficultyEngine(level: 3);
    engine.record(correct: true);
    engine.record(correct: true);
    expect(engine.level, 3);
    expect(engine.record(correct: true), 4);
  });

  test('two misses in the window levels down', () {
    final engine = DifficultyEngine(level: 3);
    engine.record(correct: false);
    engine.record(correct: true);
    expect(engine.record(correct: false), 2);
  });

  test('level is clamped to bounds', () {
    final low = DifficultyEngine(level: 1);
    low
      ..record(correct: false)
      ..record(correct: false);
    expect(low.level, DifficultyEngine.minLevel);

    final high = DifficultyEngine(level: 99);
    expect(high.level, DifficultyEngine.maxLevel);
    for (var i = 0; i < 3; i++) {
      high.record(correct: true);
    }
    expect(high.level, DifficultyEngine.maxLevel);
  });
}
