import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'vol_puzzle.dart';
import 'vol_screen.dart';

/// Quant track: option pricing past the basics: the at-the-money rule,
/// digitals, barriers, d₁ and d₂, delta and implied volatility.
class VolLabGame extends GameDefinition {
  const VolLabGame();

  static const String gameId = 'vol_lab';

  @override
  String get id => gameId;

  @override
  String get title => 'Vol Lab';

  @override
  String get tagline => 'Black–Scholes by feel: digitals, barriers, delta.';

  @override
  IconData get icon => Icons.waves_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.problemSolving];

  @override
  String levelHint(int level) => VolDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.receipt_long_rounded,
        'Read the option',
        'The chips give the stock, strike, volatility (σ) and time; the '
            'card adds any formula.',
      ),
      HowToStep(
        Icons.functions_rounded,
        'Find the shortcut',
        'At the money, price ≈ 0.4 × S × σ√T. N(d₂) is the chance; N(d₁) '
            'is the delta.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the answer',
        'Numbers go smallest first. Most wrong ones are common slips. No '
            'clock.',
      ),
    ],
    levels:
        'which way prices move, the 0.4 rule, scaling, digitals, call '
        'spreads, barriers, d₁ and d₂, delta and implied volatility.',
  );

  @override
  Widget buildScreen() => const VolScreen();
}
