import 'package:smartx/core/game/game_registry.dart';

/// Saved preferences where every game's How to play page has already been
/// seen, so flow tests go straight into the game. Pass [extra] for more.
Map<String, Object> rulesSeen([Map<String, Object> extra = const {}]) => {
  for (final g in gameRegistry) 'howto.${g.id}.seen': true,
  ...extra,
};
