import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/skills/skill.dart';
import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/speed_widgets.dart';
import 'arrow_controller.dart';
import 'arrow_focus_game.dart';
import 'arrow_puzzle.dart';

// Built from the "Arrow Focus · play" and "Arrow Focus · review" artboards,
// on the shared timed-trials screen.

class ArrowScreen extends StatelessWidget {
  const ArrowScreen({super.key});

  static double _maxArrow(BuildContext context) =>
      Dims.of(context).compact ? 32.0 : 38.0;

  @override
  Widget build(BuildContext context) {
    return SpeedGameScreen<ArrowBlock, ArrowTrial, ArrowDir>(
      provider: arrowSessionProvider,
      game: const ArrowFocusGame(),
      cue: (_) => const SpeedCue('FOLLOW THE MIDDLE'),
      stimulusHeight: (context) =>
          _maxArrow(context) + (Dims.of(context).compact ? 36 : 52),
      stimulus: (context, _, t, _) =>
          _ArrowRow(trial: t, max: _maxArrow(context)),
      hint: (_) => 'Swipe or tap the way the middle arrow points.',
      swipe: (s, travel) =>
          ArrowDir.fromSwipe(travel, fourWays: s.block.fourWays),
      controls: (context, s, press) {
        final d = Dims.of(context);
        final dirs = s.block.directions;
        final four = dirs.length == 4;
        return SizedBox(
          height: d.compact ? 54 : 64,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final (i, dir) in dirs.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: SpeedButton(
                    key: ValueKey('arrow-${dir.name}'),
                    label: dir.label,
                    mark: s.markFor(dir),
                    onTap: () => press(dir),
                    child: _DirLabel(dir, iconOnly: four),
                  ),
                ),
              ],
            ],
          ),
        );
      },
      review: SpeedReviewText(
        item: 'Row',
        calm: 'Arrows agreed',
        conflict: 'Arrows disagreed',
        cost: (secs) => 'The other arrows cost you $secs s a row.',
        noCost: 'The other arrows didn\'t slow you down. Sharp focus.',
      ),
    );
  }
}

class _ArrowRow extends StatelessWidget {
  const _ArrowRow({required this.trial, required this.max});

  final ArrowTrial trial;
  final double max;

  @override
  Widget build(BuildContext context) {
    final t = trial;
    final others = t.conflict
        ? 'the others point ${t.flank.word}'
        : 'the others point the same way';
    return Semantics(
      label:
          '${t.count} arrows. The middle arrow points ${t.middle.word}, '
          '$others.',
      liveRegion: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          const gap = 8.0;
          final size = min(max, (c.maxWidth - gap * (t.count - 1)) / t.count);
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final (i, dir) in t.arrows.indexed) ...[
                    if (i > 0) const SizedBox(width: gap),
                    Icon(dir.icon, size: size, color: Lucid.ink),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              // Marks the middle, so the target is never in doubt.
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  color: Skill.attention.color,
                  shape: BoxShape.circle,
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DirLabel extends StatelessWidget {
  const _DirLabel(this.dir, {required this.iconOnly});

  final ArrowDir dir;
  final bool iconOnly;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final color = Theme.of(context).colorScheme.onSurface;
    final icon = Icon(dir.icon, size: 24, color: color);
    if (iconOnly) return Center(child: icon);
    final label = Text(
      dir.label,
      style: lucidText(size: d.rowTitle, weight: 600, color: color),
    );
    // The arrow sits on the side it points to.
    final right = dir == ArrowDir.right;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        right ? label : icon,
        const SizedBox(width: 10),
        right ? icon : label,
      ],
    );
  }
}
