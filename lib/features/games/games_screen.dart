import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/game_category.dart';
import '../../core/storage/progress.dart';
import '../../games/teaser/teaser_book.dart';
import '../../games/teaser/teaser_game.dart';
import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/motion.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/press_scale.dart';

/// The Games tab: the Teaser of the day, then the five groups (see the
/// "Games · groups and progress" canvas row).
class GamesScreen extends ConsumerWidget {
  const GamesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final d = Dims.of(context);
    final levelled = [for (final c in GameCategory.values) ...c.games];
    final reached = levelled.fold(
      0,
      (sum, g) => sum + progress.forGame(g.id).levelsReached,
    );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          d.compact ? 16 : 20,
          d.compact ? 8 : 20,
          d.compact ? 16 : 20,
          bottom + d.navHeight + 32,
        ),
        children: [
          Text('Games', style: theme.textTheme.displaySmall),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Pick a group, then a game.',
                  style: theme.textTheme.bodyMedium?.copyWith(color: p.muted),
                ),
              ),
              Text.rich(
                TextSpan(
                  text: '$reached',
                  children: [
                    TextSpan(
                      text: ' / ${levelled.length * 10} levels',
                      style: TextStyle(
                        color: p.muted,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                style: lucidText(size: 13, weight: 700, color: p.ink),
              ),
            ],
          ),
          SizedBox(height: d.compact ? 12 : 16),
          FadeSlideIn(index: 0, child: _TeaserCard(progress: progress)),
          for (final (i, c) in GameCategory.values.indexed)
            FadeSlideIn(
              index: i + 1,
              child: Padding(
                padding: const EdgeInsets.only(top: 10),
                child: CategoryCard(category: c, progress: progress),
              ),
            ),
        ],
      ),
    );
  }
}

/// A group's tile colour and icon colour, in either theme.
(Color, Color) categoryColors(BuildContext context, GameCategory c) {
  final p = context.palette;
  final dark = Theme.of(context).brightness == Brightness.dark;
  final skill = c.skillColor;
  if (skill != null) return (skill, onFill(skill));
  return (dark ? p.heroRow : p.hero, p.spark);
}

class _TeaserCard extends StatelessWidget {
  const _TeaserCard({required this.progress});

  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final today = DateTime.now();
    final done = progress.forGame(TeaserGame.gameId).playedOn(today);
    return PressScale(
      semanticLabel: 'Play Teaser of the day',
      onTap: () => context.push('/game/${TeaserGame.gameId}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.hero,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: p.spark,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(Icons.lightbulb_outline_rounded, color: p.onSpark),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TEASER OF THE DAY',
                    style: lucidText(
                      size: 12,
                      weight: 700,
                      color: p.heroLabel,
                      letterSpacing: 0.9,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    TeaserBook.forDay(today).title,
                    style: lucidText(size: 16, weight: 600, color: p.heroText),
                  ),
                  Text(
                    done
                        ? 'Done today · play a bonus one'
                        : 'One classic puzzle, new each day',
                    style: lucidText(size: 13, color: p.heroQuiet),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: p.heroQuiet),
          ],
        ),
      ),
    );
  }
}

/// One group on the Games tab: icon, name, games played, levels reached.
class CategoryCard extends StatelessWidget {
  const CategoryCard({
    super.key,
    required this.category,
    required this.progress,
  });

  final GameCategory category;
  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final games = category.games;
    final played = games.where((g) => progress.forGame(g.id).sessions > 0);
    final levels = games.fold(
      0,
      (sum, g) => sum + progress.forGame(g.id).levelsReached,
    );
    final fill = games.isEmpty ? 0.0 : levels / (games.length * 10);
    final (tile, icon) = categoryColors(context, category);

    return PressScale(
      semanticLabel:
          '${category.title}, ${played.length} of '
          '${games.length} played',
      onTap: () => context.push('/games/${category.name}'),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: p.line),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: tile,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(category.icon, color: icon),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    category.title,
                    style: lucidText(size: 16, weight: 600, color: p.ink),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    category.blurb,
                    style: lucidText(size: 13, color: p.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: _Bar(fill: fill, color: p.ink),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        played.isEmpty
                            ? 'New'
                            : '${played.length} of ${games.length} played',
                        style: lucidText(
                          size: 12,
                          weight: 700,
                          color: played.isEmpty ? p.sparkStrong : p.muted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(Icons.chevron_right_rounded, color: p.muted),
          ],
        ),
      ),
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.fill, required this.color});

  final double fill;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 6,
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(
        color: context.palette.chip,
        borderRadius: BorderRadius.circular(99),
      ),
      child: FractionallySizedBox(
        widthFactor: fill.clamp(0.0, 1.0),
        child: Container(
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(99),
          ),
        ),
      ),
    );
  }
}
