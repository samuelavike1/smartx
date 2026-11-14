import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/speed_game.dart';
import '../../core/skills/skill.dart';
import 'odd_one_out_game.dart';
import 'odd_puzzle.dart';

typedef OddSessionState = SpeedSessionState<OddBlock, OddTrial, int>;

final oddSessionProvider =
    NotifierProvider.autoDispose<OddController, OddSessionState>(
      OddController.new,
    );

class OddController extends SpeedController<OddBlock, OddTrial, int> {
  static const _generator = OddGenerator();

  @override
  String get gameId => OddOneOutGame.gameId;

  @override
  List<Skill> get skills => const OddOneOutGame().skills;

  @override
  OddBlock generate({required int level, required int seed}) =>
      _generator.generate(level: level, seed: seed);
}
