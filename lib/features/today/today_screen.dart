import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/game_category.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/game_registry.dart';
import '../../core/skills/skill.dart';
import '../../core/storage/progress.dart';
import '../../ui/density.dart';
import '../../ui/motion.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/skill_marker.dart';
import '../../games/teaser/teaser_game.dart';
import '../feed/feed_plan.dart';
import '../games/games_screen.dart' show categoryColors;
import 'daily_workout.dart';
import '../../ui/palette.dart';

// Values come from the "Today (home)" artboard (regular) and the
// "Today · compact 360×640" artboard, via the density tokens in Dims.

const _weekdays = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _months = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

class TodayScreen extends ConsumerWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final now = DateTime.now();
    final bottom = MediaQuery.paddingOf(context).bottom;
    final side = d.compact ? 16.0 : 20.0;

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(side, d.topPad, side, bottom + 24),
        children: [
          Text(
            '${_weekdays.elementAt(now.weekday - 1)}, ${now.day} ${_months.elementAt(now.month - 1)}',
            style: lucidText(size: d.small + 1, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            'Today',
            style: lucidText(
              size: d.screenTitle,
              weight: 700,
              display: true,
              color: scheme.onSurface,
            ),
          ),
          SizedBox(height: d.gapL),
          FadeSlideIn(
            index: 0,
            child: _WorkoutCard(
              items: dailyWorkout(progress, now),
              weakest: weakestSkill(progress),
            ),
          ),
          SizedBox(height: d.gapL),
          const FadeSlideIn(index: 1, child: _FeedRow()),
          SizedBox(height: d.gapL),
          FadeSlideIn(index: 2, child: _SkillsCard(progress: progress)),
          SizedBox(height: d.gapL),
          Text(
            'FREE PLAY',
            style: lucidLabel(scheme.onSurfaceVariant, size: d.label),
          ),
          SizedBox(height: d.gapS),
          const FadeSlideIn(index: 3, child: _FreePlayGrid()),
        ],
      ),
    );
  }
}

class _WorkoutCard extends StatelessWidget {
  const _WorkoutCard({required this.items, required this.weakest});

  final List<WorkoutItem> items;
  final Skill? weakest;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final done = items.where((i) => i.status == WorkoutStatus.done).length;
    final next = items.where((i) => i.status == WorkoutStatus.next).firstOrNull;
    final buttonText = next == null
        ? 'Workout done · play again'
        : (done == 0 ? 'Start workout' : 'Continue workout');
    final target = next ?? items.first;
    final p = context.palette;

    return Container(
      padding: EdgeInsets.all(d.cardPad),
      // The hero card: ink by day, a raised card with a border at night.
      decoration: BoxDecoration(
        color: p.hero,
        borderRadius: BorderRadius.circular(d.compact ? 22 : Lucid.radiusL),
        border: p.isNight ? Border.all(color: p.line) : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'DAILY WORKOUT',
                  style: lucidLabel(p.heroLabel, size: d.label),
                ),
              ),
              Text(
                '$done of ${items.length} · about ${items.length * minutesPerGame} min',
                style: lucidText(size: d.small + 1, color: p.heroQuiet),
              ),
            ],
          ),
          SizedBox(height: d.gapM),
          for (final (i, item) in items.indexed) ...[
            if (i > 0) SizedBox(height: d.compact ? 8 : 10),
            _WorkoutRow(item: item, weakest: weakest),
          ],
          SizedBox(height: d.gapM),
          PressScale(
            key: const ValueKey('start-training'),
            semanticLabel: '$buttonText: ${target.game.title}',
            onTap: () => context.push('/game/${target.game.id}'),
            child: Container(
              height: d.button,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.heroAccent,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                buttonText,
                style: lucidText(
                  size: d.rowTitle,
                  weight: 700,
                  color: p.onHeroAccent,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WorkoutRow extends StatelessWidget {
  const _WorkoutRow({required this.item, required this.weakest});

  final WorkoutItem item;
  final Skill? weakest;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final skill = item.game.skills.first;
    final isNext = item.status == WorkoutStatus.next;
    final circle = d.rowCircle;
    final p = context.palette;

    final Widget leading = switch (item.status) {
      WorkoutStatus.done => Container(
        width: circle,
        height: circle,
        decoration: BoxDecoration(
          color: context.palette.spark,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          size: circle * 0.56,
          color: context.palette.onSpark,
          semanticLabel: 'Done',
        ),
      ),
      WorkoutStatus.next => Container(
        width: circle,
        height: circle,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: skill.color.withValues(alpha: 0.14),
          shape: BoxShape.circle,
        ),
        child: SkillMarkerIcon(skill, size: circle * 0.44),
      ),
      WorkoutStatus.pending => Container(
        width: circle,
        height: circle,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: p.heroText.withValues(alpha: 0.6),
            width: 1.5,
          ),
        ),
      ),
    };

    final subtitle = switch (item.status) {
      WorkoutStatus.done => 'Done · ${item.progress.lastScore} pts',
      WorkoutStatus.next =>
        skill == weakest
            ? 'Up next · trains ${skill.label}, your weakest skill'
            : 'Up next · trains ${skill.label}',
      WorkoutStatus.pending => item.game.skills.map((s) => s.label).join(' · '),
    };

    return Container(
      padding: EdgeInsets.all(d.rowPad),
      decoration: BoxDecoration(
        color: isNext ? p.heroAccent : p.heroRow,
        borderRadius: BorderRadius.circular(d.compact ? 14 : Lucid.radiusM),
      ),
      child: Row(
        children: [
          leading,
          SizedBox(width: d.compact ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.game.title,
                  style: lucidText(
                    size: d.rowTitle,
                    weight: 600,
                    color: isNext ? p.onHeroAccent : p.heroText,
                  ),
                ),
                Text(
                  subtitle,
                  style: lucidText(
                    size: d.small,
                    // The up-next row stays light at night: day muted.
                    color: isNext ? LucidPalette.light.muted : p.heroQuiet,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Opens the Quick feed (row from the Today artboard).
class _FeedRow extends StatelessWidget {
  const _FeedRow();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final icon = d.compact ? 40.0 : 44.0;
    return PressScale(
      key: const ValueKey('open-feed'),
      semanticLabel:
          'Quick feed: ${FeedRules.cards} micro-puzzles, about 5 minutes',
      onTap: () => context.push('/feed'),
      child: Container(
        padding: EdgeInsets.all(d.compact ? 14 : 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(d.compact ? 18 : 20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: icon,
              height: icon,
              decoration: BoxDecoration(
                color: context.palette.sparkTint,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                Icons.bolt_rounded,
                size: icon * 0.55,
                color: context.palette.sparkStrong,
              ),
            ),
            SizedBox(width: d.compact ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick feed',
                    style: lucidText(
                      size: d.rowTitle,
                      weight: 600,
                      color: scheme.onSurface,
                    ),
                  ),
                  Text(
                    '${FeedRules.cards} micro-puzzles · about 5 min',
                    style: lucidText(
                      size: d.small,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              size: 22,
              color: scheme.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillsCard extends StatelessWidget {
  const _SkillsCard({required this.progress});

  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final maxXp = Skill.values
        .map(progress.xpFor)
        .fold<int>(0, (a, b) => a > b ? a : b);

    return PressScale(
      semanticLabel: 'Open skills',
      onTap: () => context.go('/skills'),
      child: Container(
        padding: EdgeInsets.all(d.compact ? 14 : 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(d.compact ? 18 : 20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    'Your skills',
                    style: lucidText(
                      size: d.rowTitle,
                      weight: 600,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                Text(
                  'All time',
                  style: lucidText(
                    size: d.small,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            SizedBox(height: d.gapS),
            SizedBox(
              height: d.skillBars,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (final (i, s) in Skill.values.indexed) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(
                      child: AnimatedFractionallySizedBox(
                        duration: Lucid.pop,
                        alignment: Alignment.bottomCenter,
                        heightFactor: maxXp == 0
                            ? 0.08
                            : (progress.xpFor(s) / maxXp).clamp(0.08, 1.0),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: s.color,
                            borderRadius: BorderRadius.circular(
                              d.compact ? 7 : 8,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: d.gapS),
            Row(
              children: [
                for (final (i, s) in Skill.values.indexed) ...[
                  if (i > 0) const SizedBox(width: 8),
                  // Six skills on a narrow phone: a long label ("Numbers")
                  // shrinks a touch rather than wrap or clip.
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        s.shortLabel,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                        style: lucidText(
                          size: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Free play, grouped like the Games tab (see "Today · Free play by group"):
/// the Teaser of the day first as "Daily", then each group's games in a
/// 3-wide grid of tiles in the group's colour.
class _FreePlayGrid extends StatelessWidget {
  const _FreePlayGrid();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final teaser = findGame(TeaserGame.gameId);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (teaser != null)
          _FreePlayGroup(
            title: 'Daily',
            tile: p.spark,
            icon: p.onSpark,
            games: [teaser],
            first: true,
          ),
        for (final c in GameCategory.values)
          if (c.games.isNotEmpty)
            Builder(
              builder: (context) {
                final (tile, icon) = categoryColors(context, c);
                return _FreePlayGroup(
                  title: c.title,
                  tile: tile,
                  icon: icon,
                  games: c.games,
                );
              },
            ),
      ],
    );
  }
}

class _FreePlayGroup extends StatelessWidget {
  const _FreePlayGroup({
    required this.title,
    required this.tile,
    required this.icon,
    required this.games,
    this.first = false,
  });

  final String title;
  final Color tile;

  /// The game icons' colour (spark orange on Markets' dark tiles).
  final Color icon;
  final List<GameDefinition> games;
  final bool first;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final name = onFill(tile);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(2, first ? 4 : d.gapL, 2, 10),
          child: Row(
            children: [
              Container(
                width: 18,
                height: 18,
                decoration: BoxDecoration(
                  color: tile,
                  borderRadius: BorderRadius.circular(6),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: lucidText(size: 15, weight: 600, color: p.ink),
                ),
              ),
              Text(
                '${games.length}',
                style: lucidText(size: 13, weight: 600, color: p.muted),
              ),
            ],
          ),
        ),
        LayoutBuilder(
          builder: (context, c) {
            final w = (c.maxWidth - 2 * 10) / 3;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final g in games)
                  PressScale(
                    semanticLabel: 'Play ${g.title}',
                    onTap: () => context.push('/game/${g.id}'),
                    child: Container(
                      width: w,
                      height: d.freeTile,
                      padding: EdgeInsets.all(d.compact ? 10 : 12),
                      decoration: BoxDecoration(
                        color: tile,
                        borderRadius: BorderRadius.circular(
                          d.compact ? 18 : 20,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Icon(g.icon, size: d.compact ? 18 : 20, color: icon),
                          Text(
                            g.title,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: lucidText(
                              size: d.small + 1,
                              weight: 600,
                              color: name,
                              height: 1.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }
}
