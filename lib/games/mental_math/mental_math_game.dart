import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'math_puzzle.dart';
import 'math_screen.dart';

/// Quant track: quick sums against the clock, with the shortcut shown.
class MentalMathGame extends GameDefinition {
  const MentalMathGame();

  static const String gameId = 'mental_math';

  @override
  String get id => gameId;

  @override
  String get title => 'Mental Math';

  @override
  String get tagline => 'Quick sums against the clock.';

  @override
  IconData get icon => Icons.calculate_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers];

  @override
  String levelHint(int level) {
    final d = MathDifficulty.forLevel(level);
    final secs = (d.limitMs / 1000).toStringAsFixed(0);
    return '${d.hint}, $secs s a problem';
  }

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.functions_rounded,
        'Work it out in your head',
        'A sum appears: add, take away, times, divide, then percentages.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Tap the answer in time',
        'Four choices and a time bar. Estimate first, then check the last digit.',
      ),
      HowToStep(
        Icons.school_rounded,
        'Learn the shortcuts',
        'The review shows the working, like 48 × 52 = 50² − 2².',
      ),
    ],
    levels:
        'bigger numbers, times tables, then percentages, squares and '
        'two digits × two digits.',
  );

  @override
  bool get timed => true;

  @override
  Widget buildScreen() => const MathScreen();
}
