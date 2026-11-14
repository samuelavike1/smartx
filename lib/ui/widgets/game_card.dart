import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/storage/progress.dart';
import '../lucid.dart';
import 'press_scale.dart';
import 'skill_marker.dart';

/// A game in a list: icon tile in its main skill's colour, skills, progress.
class GameCard extends StatelessWidget {
  const GameCard({super.key, required this.game, required this.progress});

  final GameDefinition game;
  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final main = game.skills.first;

    return PressScale(
      semanticLabel: 'Play ${game.title}',
      onTap: () => context.push('/game/${game.id}'),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: main.color,
                  borderRadius: BorderRadius.circular(Lucid.radiusM),
                ),
                child: Icon(game.icon, color: onFill(main.color)),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(game.title, style: theme.textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text(game.tagline, style: theme.textTheme.bodySmall),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 10,
                      runSpacing: 4,
                      children: [
                        for (final skill in game.skills)
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SkillMarkerIcon(skill, size: 10),
                              const SizedBox(width: 5),
                              Text(
                                skill.shortLabel,
                                style: theme.textTheme.labelSmall,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    progress.sessions == 0 ? 'New' : 'Lv ${progress.level}',
                    style: theme.textTheme.titleSmall,
                  ),
                  if (progress.bestScore > 0)
                    Text(
                      'Best ${progress.bestScore}',
                      style: theme.textTheme.labelSmall,
                    ),
                  const SizedBox(height: 6),
                  Icon(
                    Icons.chevron_right_rounded,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
