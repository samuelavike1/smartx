import 'dart:math';

/// Adaptive difficulty shared by all games.
///
/// It looks at the last [window] answers: all correct moves the player up a
/// level, two or more wrong moves them down. That keeps most players in the
/// ~70–85% success band where training is challenging but not discouraging.
class DifficultyEngine {
  DifficultyEngine({int level = minLevel, this.window = 3})
    : _level = level.clamp(minLevel, maxLevel);

  static const int minLevel = 1;
  static const int maxLevel = 10;

  final int window;
  int _level;
  final List<bool> _recent = [];

  int get level => _level;

  /// Records one answer and returns the (possibly changed) level.
  int record({required bool correct}) {
    _recent.add(correct);
    if (_recent.length > window) _recent.removeAt(0);

    final wrong = _recent.where((c) => !c).length;
    if (_recent.length == window && wrong == 0) {
      _level = min(_level + 1, maxLevel);
      _recent.clear();
    } else if (wrong >= 2) {
      _level = max(_level - 1, minLevel);
      _recent.clear();
    }
    return _level;
  }
}
