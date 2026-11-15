import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/game_category.dart';
import '../../core/game/game_definition.dart';
import '../../core/storage/progress.dart';
import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/motion.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/press_scale.dart';
import 'game_start_sheet.dart';
import 'games_screen.dart';

/// One group's games, each with its level track. Tapping a game opens the
/// Continue / Start over sheet.
class GroupScreen extends ConsumerWidget {
  const GroupScreen({super.key, required this.category});

  final GameCategory category;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final p = context.palette;
    final d = Dims.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final games = category.games;
    final reached = games.fold(
      0,
      (sum, g) => sum + progress.forGame(g.id).levelsReached,
    );
    final total = games.length * 10;
    final (tile, icon) = categoryColors(context, category);

    return Material(
      color: p.ground,
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: EdgeInsets.fromLTRB(
            d.compact ? 16 : 20,
            d.compact ? 8 : 16,
            d.compact ? 16 : 20,
            bottom + d.navHeight + 32,
          ),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: PressScale(
                semanticLabel: 'Back to Games',
                onTap: () => context.pop(),
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.line),
                  ),
                  child: Icon(Icons.chevron_left_rounded, color: p.ink),
                ),
              ),
            ),
            SizedBox(height: d.compact ? 12 : 16),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: tile,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(category.icon, color: icon, size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        category.title,
                        style: lucidText(
                          size: d.compact ? 24 : 28,
                          weight: 700,
                          display: true,
                          color: p.ink,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        category.blurb,
                        style: lucidText(size: 14, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: p.chip,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                children: [
                  Text.rich(
                    TextSpan(
                      text: '$reached',
                      children: [
                        TextSpan(
                          text: ' / $total',
                          style: lucidText(size: 14, color: p.muted),
                        ),
                        TextSpan(
                          text: ' levels',
                          style: lucidText(size: 13, color: p.muted),
                        ),
                      ],
                    ),
                    style: lucidText(
                      size: 20,
                      weight: 700,
                      display: true,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Container(
                      height: 6,
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(99),
                      ),
                      child: FractionallySizedBox(
                        widthFactor: total == 0 ? 0 : reached / total,
                        child: Container(
                          decoration: BoxDecoration(
                            // Markets' dark tile would vanish on black.
                            color: category.skillColor ?? p.spark,
                            borderRadius: BorderRadius.circular(99),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            for (final (i, g) in games.indexed)
              FadeSlideIn(
                index: i,
                child: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: GameRow(game: g, progress: progress.forGame(g.id)),
                ),
              ),
            if (games.any((g) => _hasPeak(progress.forGame(g.id))))
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text(
                  'Dark: the level you\'re on. Grey: the highest you '
                  'reached before starting over.',
                  style: lucidText(size: 12, color: p.muted, height: 1.5),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

bool _hasPeak(GameProgress p) => p.sessions > 0 && p.peakLevel > p.level;

/// A game in a group: tile, name, tagline and a 10-step level track.
class GameRow extends StatelessWidget {
  const GameRow({super.key, required this.game, required this.progress});

  final GameDefinition game;
  final GameProgress progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final main = game.skills.first.color;
    final isNew = progress.sessions == 0;

    return PressScale(
      semanticLabel: 'Play ${game.title}',
      onTap: () => showGameStartSheet(context, game),
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
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: main,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(game.icon, color: onFill(main), size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: lucidText(size: 16, weight: 600, color: p.ink),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    game.tagline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: lucidText(size: 13, color: p.muted),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: LevelTrack(
                          level: isNew ? 0 : progress.level,
                          peak: isNew ? 0 : progress.peakLevel,
                          height: 6,
                          gap: 3,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text.rich(
                        TextSpan(
                          text: isNew ? 'New' : 'Lv ${progress.level}',
                          children: [
                            if (_hasPeak(progress))
                              TextSpan(
                                text: ' · top ${progress.peakLevel}',
                                style: TextStyle(
                                  color: p.muted,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                          ],
                        ),
                        style: lucidText(
                          size: 12,
                          weight: 700,
                          color: isNew ? p.sparkStrong : p.ink,
                        ),
                      ),
                    ],
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

/// Ten segments: dark up to [level], grey up to [peak], empty after.
class LevelTrack extends StatelessWidget {
  const LevelTrack({
    super.key,
    required this.level,
    required this.peak,
    this.height = 6,
    this.gap = 3,
  });

  final int level;
  final int peak;
  final double height;
  final double gap;

  static const int levels = 10;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Row(
      children: [
        for (var i = 1; i <= levels; i++) ...[
          if (i > 1) SizedBox(width: gap),
          Expanded(
            child: Container(
              height: height,
              decoration: BoxDecoration(
                color: i <= level
                    ? p.ink
                    : i <= peak
                    ? p.faint.withValues(alpha: 0.5)
                    : p.chip,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
