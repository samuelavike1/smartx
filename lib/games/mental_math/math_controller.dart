import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/speed_game.dart';
import '../../core/skills/skill.dart';
import 'math_puzzle.dart';
import 'mental_math_game.dart';

typedef MathSessionState = SpeedSessionState<MathBlock, MathTrial, int>;

final mathSessionProvider =
    NotifierProvider.autoDispose<MathController, MathSessionState>(
      MathController.new,
    );

class MathController extends SpeedController<MathBlock, MathTrial, int> {
  static const _generator = MathGenerator();

  @override
  String get gameId => MentalMathGame.gameId;

  @override
  List<Skill> get skills => const MentalMathGame().skills;

  @override
  MathBlock generate({required int level, required int seed}) =>
      _generator.generate(level: level, seed: seed);
}
