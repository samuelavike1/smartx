import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/speed_game.dart';
import '../../core/skills/skill.dart';
import 'ink_clash_game.dart';
import 'ink_puzzle.dart';

typedef InkSessionState = SpeedSessionState<InkBlock, InkTrial, InkColour>;

final inkSessionProvider =
    NotifierProvider.autoDispose<InkController, InkSessionState>(
      InkController.new,
    );

class InkController extends SpeedController<InkBlock, InkTrial, InkColour> {
  static const _generator = InkGenerator();

  @override
  String get gameId => InkClashGame.gameId;

  @override
  List<Skill> get skills => const InkClashGame().skills;

  @override
  InkBlock generate({required int level, required int seed}) =>
      _generator.generate(level: level, seed: seed);
}
