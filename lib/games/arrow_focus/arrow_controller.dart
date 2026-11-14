import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/speed_game.dart';
import '../../core/skills/skill.dart';
import 'arrow_focus_game.dart';
import 'arrow_puzzle.dart';

typedef ArrowSessionState = SpeedSessionState<ArrowBlock, ArrowTrial, ArrowDir>;

final arrowSessionProvider =
    NotifierProvider.autoDispose<ArrowController, ArrowSessionState>(
      ArrowController.new,
    );

class ArrowController
    extends SpeedController<ArrowBlock, ArrowTrial, ArrowDir> {
  static const _generator = ArrowGenerator();

  @override
  String get gameId => ArrowFocusGame.gameId;

  @override
  List<Skill> get skills => const ArrowFocusGame().skills;

  @override
  ArrowBlock generate({required int level, required int seed}) =>
      _generator.generate(level: level, seed: seed);
}
