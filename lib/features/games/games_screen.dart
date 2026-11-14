import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';

import '../../core/game/game_registry.dart';
import '../../core/storage/progress.dart';
import '../../ui/widgets/game_card.dart';

class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final d = Dims.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          d.compact ? 16 : 20,
          d.compact ? 8 : 20,
          d.compact ? 16 : 20,
          bottom + 24,
        ),
        children: [
          Text('Games', style: theme.textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            'Short sessions that each train one to three skills.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          for (final game in gameRegistry)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: GameCard(game: game, progress: progress.forGame(game.id)),
            ),
        ],
      ),
    );
  }
}
