import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/skills/skill.dart';
import '../../core/storage/progress.dart';
import '../../features/today/daily_workout.dart';
import '../density.dart';
import '../lucid.dart';
import 'game_chrome.dart';
import 'press_scale.dart';
import '../palette.dart';

// Built from the "Results · level up" artboard on the design canvas.

/// End of a session: score, level change, skill XP, the last miss, and the
/// way on (next workout game, or play again).
class SessionResults extends ConsumerWidget {
  const SessionResults({
    super.key,
    required this.game,
    required this.score,
    required this.correct,
    required this.total,
    required this.startLevel,
    required this.level,
    required this.isNewBest,
    required this.nearMiss,
    required this.onPlayAgain,
    required this.onTrySimilar,
    this.showLevel = true,
  });

  final GameDefinition game;
  final int score;
  final int correct;
  final int total;
  final int startLevel;
  final int level;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final VoidCallback onPlayAgain;
  final VoidCallback onTrySimilar;

  /// Off for games without levels (Teaser of the day).
  final bool showLevel;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final progress = ref.watch(progressProvider);
    final workout = dailyWorkout(progress, DateTime.now());
    final inWorkout = workout.any((i) => i.game.id == game.id);
    final done = workout.where((i) => i.status == WorkoutStatus.done).length;
    final next = workout
        .where((i) => i.status != WorkoutStatus.done && i.game.id != game.id)
        .firstOrNull;

    final label = !inWorkout
        ? 'SESSION COMPLETE'
        : (next == null
              ? 'DAILY WORKOUT COMPLETE'
              : 'WORKOUT · GAME $done OF ${workout.length} DONE');

    final result = GameResult(
      gameId: game.id,
      score: score,
      correct: correct,
      total: total,
      endLevel: level,
      skills: game.skills,
    );

    // Content scrolls; the way on stays pinned at the bottom, so the primary
    // action is always in reach (even on 360×640 phones).
    final d = Dims.of(context);
    final side = d.compact ? 16.0 : 20.0;
    final gap = d.compact ? 12.0 : 18.0;

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(side, d.compact ? 16 : 32, side, gap),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Text(
                  label,
                  textAlign: TextAlign.center,
                  style: lucidLabel(scheme.onSurfaceVariant, size: d.label),
                ),
                SizedBox(height: d.compact ? 4 : 6),
                Center(
                  child: CountUp(
                    value: score,
                    style: lucidText(
                      size: d.score,
                      weight: 700,
                      display: true,
                      height: 1.05,
                      letterSpacing: -0.03 * d.score,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                SizedBox(height: d.compact ? 4 : 6),
                Text(
                  '$correct of $total correct${isNewBest ? ' · new personal best' : ''}',
                  textAlign: TextAlign.center,
                  style: lucidText(
                    size: d.body,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                if (showLevel) ...[
                  SizedBox(height: gap),
                  _LevelBanner(
                    from: startLevel,
                    to: level,
                    hint: game.levelHint(level),
                  ),
                ],
                SizedBox(height: gap),
                _XpCard(result: result, progress: progress),
                if (nearMiss != null) ...[
                  SizedBox(height: gap),
                  _NearMissCard(miss: nearMiss!, onTry: onTrySimilar),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(side, 8, side, d.compact ? 12 : 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (next != null) ...[
                FilledButton(
                  key: const ValueKey('next-game'),
                  style: ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(
                      Size.fromHeight(d.button + 2),
                    ),
                  ),
                  onPressed: () =>
                      context.pushReplacement('/game/${next.game.id}'),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Long game names shrink rather than overflow.
                      Flexible(
                        child: Text(
                          'Next game: ${next.game.title}',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(Icons.chevron_right_rounded, size: 20),
                    ],
                  ),
                ),
                SizedBox(height: d.compact ? 4 : 10),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Finish later'),
                ),
              ] else ...[
                FilledButton.icon(
                  key: const ValueKey('play-again'),
                  style: ButtonStyle(
                    minimumSize: WidgetStatePropertyAll(
                      Size.fromHeight(d.button + 2),
                    ),
                  ),
                  onPressed: onPlayAgain,
                  icon: const Icon(Icons.replay_rounded),
                  label: const Text('Play again'),
                ),
                SizedBox(height: d.compact ? 4 : 10),
                TextButton(
                  onPressed: () => context.pop(),
                  child: const Text('Done'),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _LevelBanner extends StatelessWidget {
  const _LevelBanner({
    required this.from,
    required this.to,
    required this.hint,
  });

  final int from;
  final int to;
  final String hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final up = to > from;
    final down = to < from;

    final (title, sub, icon) = up
        ? (
            'Level $from → $to',
            'Next session: $hint.',
            Icons.arrow_upward_rounded,
          )
        : down
        ? (
            'Level $from → $to',
            'Next session eases off: $hint.',
            Icons.arrow_downward_rounded,
          )
        : (
            'Staying on level $to',
            'Three right in a row moves you up.',
            Icons.horizontal_rule_rounded,
          );

    final p = context.palette;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.92, end: 1),
      duration: Lucid.pop,
      curve: Curves.easeOutBack,
      builder: (_, s, child) => Transform.scale(scale: s, child: child),
      child: Container(
        padding: EdgeInsets.all(d.compact ? 12 : 16),
        decoration: BoxDecoration(
          color: up ? p.hero : scheme.surface,
          borderRadius: BorderRadius.circular(d.compact ? 18 : 20),
          border: up && !p.isNight
              ? null
              : Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Container(
              width: d.compact ? 40 : 48,
              height: d.compact ? 40 : 48,
              decoration: BoxDecoration(
                color: up
                    ? p.heroText.withValues(alpha: 0.16)
                    : scheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: up ? p.heroText : scheme.onSurface),
            ),
            SizedBox(width: d.compact ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: lucidText(
                      size: d.compact ? 17 : 20,
                      weight: 700,
                      display: true,
                      color: up ? p.heroText : scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    sub,
                    style: lucidText(
                      size: d.small + 1,
                      color: up ? p.heroQuiet : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _XpCard extends StatelessWidget {
  const _XpCard({required this.result, required this.progress});

  final GameResult result;
  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    return Container(
      padding: EdgeInsets.all(d.compact ? 12 : 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(d.compact ? 18 : 20),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Skill XP earned',
            style: lucidText(
              size: d.rowTitle,
              weight: 600,
              color: scheme.onSurface,
            ),
          ),
          for (final Skill s in result.skills) ...[
            SizedBox(height: d.compact ? 8 : 12),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.label,
                    style: lucidText(size: 14, color: scheme.onSurface),
                  ),
                ),
                Text(
                  '+${result.xpFor(s)} XP',
                  style: lucidText(
                    size: 14,
                    weight: 600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (progress.xpFor(s) % 100) / 100),
                duration: Lucid.pop * 3,
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: s.color,
                  backgroundColor: scheme.outlineVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NearMissCard extends StatelessWidget {
  const _NearMissCard({required this.miss, required this.onTry});

  final NearMiss miss;
  final VoidCallback onTry;

  @override
  Widget build(BuildContext context) {
    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Round ${miss.round} slipped by',
          style: lucidText(size: 15, weight: 600, color: context.palette.ink),
        ),
        const SizedBox(height: 2),
        Text(
          '${miss.reason} Try one like it?',
          style: lucidText(size: 13, color: context.palette.sparkText),
        ),
      ],
    );
    final button = PressScale(
      key: const ValueKey('try-similar'),
      semanticLabel: 'Try a similar one',
      onTap: onTry,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.palette.surface,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Text(
          'Try a similar one',
          style: lucidText(size: 14, weight: 600, color: context.palette.ink),
        ),
      ),
    );

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: context.palette.sparkTint,
        borderRadius: BorderRadius.circular(20),
      ),
      // Side by side as on the artboard (390 wide); stacked on narrower
      // phones so the title doesn't wrap word by word.
      child: LayoutBuilder(
        builder: (context, c) => c.maxWidth >= 320
            ? Row(
                children: [
                  Expanded(child: text),
                  const SizedBox(width: 14),
                  button,
                ],
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [text, const SizedBox(height: 12), button],
              ),
      ),
    );
  }
}
