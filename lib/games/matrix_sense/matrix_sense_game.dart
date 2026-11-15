import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import 'matrix_puzzle.dart';
import 'matrix_screen.dart';

/// Quant track: the linear algebra an interview expects: determinants,
/// products, inverses, eigenvalues, correlation matrices, rank and powers.
class MatrixSenseGame extends GameDefinition {
  const MatrixSenseGame();

  static const String gameId = 'matrix_sense';

  @override
  String get id => gameId;

  @override
  String get title => 'Matrix Sense';

  @override
  String get tagline => 'Determinants, eigenvalues and correlations, by eye.';

  @override
  IconData get icon => Icons.apps_rounded;

  @override
  List<Skill> get skills => const [Skill.numbers, Skill.logic];

  @override
  String levelHint(int level) => MatrixDifficulty.hint(level);

  @override
  HowToPlay get howTo => const HowToPlay(
    steps: [
      HowToStep(
        Icons.grid_on_rounded,
        'Read the matrix',
        'The card shows the matrix, sometimes a vector, and what it does to '
            'a square.',
      ),
      HowToStep(
        Icons.functions_rounded,
        'Find the shortcut',
        'Trace and determinant give the eigenvalues; zeros make a 3 × 3 '
            'quick.',
      ),
      HowToStep(
        Icons.touch_app_rounded,
        'Pick the answer',
        'Numbers go smallest first. Most wrong ones are common slips. No '
            'clock.',
      ),
    ],
    levels:
        'determinants, products, inverses, eigenvalues and eigenvectors, '
        'correlation matrices, rank and powers.',
  );

  @override
  Widget buildScreen() => const MatrixScreen();
}
