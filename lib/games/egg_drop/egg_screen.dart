import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'egg_controller.dart';
import 'egg_drop_game.dart';
import 'egg_puzzle.dart';

// Built from the "Egg Drop · play", "· one egg" and "· review" artboards.

class EggScreen extends ConsumerWidget {
  const EggScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(eggSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const EggDropGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(eggSessionProvider),
                  onTrySimilar: ref
                      .read(eggSessionProvider.notifier)
                      .trySimilar,
                )
              : _RoundView(
                  key: ValueKey('round-${s.round}-${s.practice}'),
                  state: s,
                ),
        ),
      ),
    );
  }
}

class _RoundView extends ConsumerWidget {
  const _RoundView({super.key, required this.state});

  final EggSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(eggSessionProvider.notifier);
    final s = state;
    final q = s.puzzle;

    void drop() {
      c.drop();
      final after = ref.read(eggSessionProvider);
      if (!after.answered) {
        HapticFeedback.selectionClick();
      } else {
        after.lastCorrect
            ? HapticFeedback.lightImpact()
            : HapticFeedback.mediumImpact();
      }
    }

    return GameLayout(
      header: [
        GameTopBar(
          filled: s.round + (s.answered ? 1 : 0),
          total: s.totalRounds,
          score: s.score,
          game: const EggDropGame(),
        ),
        SizedBox(height: d.compact ? 10 : 14),
        LevelComboRow(level: s.level, combo: s.combo, practice: s.practice),
      ],
      body: (context, _) =>
          s.answered ? _Worked(puzzle: q) : _Play(state: s, onTap: c.tapFloor),
      dock: s.answered
          ? FeedbackSlot(
              child: FeedbackCard(
                correct: s.lastCorrect,
                points: s.lastPoints,
                explanation: q.feedback,
                isLastRound: s.round + 1 >= s.totalRounds,
                onNext: c.next,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  _hint(q),
                  textAlign: TextAlign.center,
                  style: lucidText(size: d.small, color: p.muted),
                ),
                SizedBox(height: d.gapS),
                SizedBox(
                  height: d.compact ? 52 : 60,
                  child: _DockButton(
                    key: const ValueKey('egg-drop'),
                    label: s.selected == null
                        ? 'Pick a floor'
                        : 'Drop from floor ${s.selected}',
                    onTap: s.selected == null ? null : drop,
                  ),
                ),
              ],
            ),
    );
  }

  static String _hint(EggPuzzle q) {
    if (q.log.isEmpty) {
      return q.eggs == 1
          ? 'One egg: go up one floor at a time.'
          : 'Tap a floor, then drop an egg from it.';
    }
    final last = q.log.last;
    if (last.broke) {
      final left = q.eggsLeft == 1 ? '1 egg left' : '${q.eggsLeft} eggs left';
      return 'Floor ${last.floor}: it broke. $left.';
    }
    final safe = q.lo == 1 ? 'Floor 1 is safe' : 'Floors 1 to ${q.lo} are safe';
    return 'Floor ${last.floor}: it survived. $safe.';
  }
}

class _Play extends StatelessWidget {
  const _Play({required this.state, required this.onTap});

  final EggSessionState state;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.puzzle;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Text(
          'Find the highest safe floor',
          textAlign: TextAlign.center,
          style: lucidText(
            size: d.compact ? 20 : 22,
            weight: 600,
            display: true,
            color: scheme.onSurface,
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          q.question,
          textAlign: TextAlign.center,
          style: lucidText(
            size: d.body,
            color: scheme.onSurfaceVariant,
            height: 1.45,
          ),
        ),
        SizedBox(height: d.compact ? 10 : 12),
        _Supplies(puzzle: q),
        SizedBox(height: d.gapM),
        _Building(puzzle: q, selected: state.selected, onTap: onTap),
        const SizedBox(height: 12),
        Semantics(
          liveRegion: true,
          child: Text(
            'Highest safe floor: ${q.range}'.toUpperCase(),
            textAlign: TextAlign.center,
            style: lucidLabel(p.muted),
          ),
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}

/// Eggs left (as eggs) and drops left (as dots).
class _Supplies extends StatelessWidget {
  const _Supplies({required this.puzzle});

  final EggPuzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = puzzle;
    final eggs = q.eggsLeft;
    final drops = q.dropsLeft;
    final text = lucidText(size: 13, weight: 700, color: p.ink);

    Widget chip(String label, List<Widget> marks) => Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.chip,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ...marks,
            const SizedBox(width: 6),
            Text(label, style: text),
          ],
        ),
      ),
    );

    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        chip(eggs == 1 ? '1 egg' : '$eggs eggs', [
          for (var i = 0; i < q.eggs; i++)
            Icon(
              Icons.egg_rounded,
              size: 16,
              color: i < eggs ? p.ink : p.lineStrong,
            ),
        ]),
        chip(drops == 1 ? '1 drop left' : '$drops drops left', [
          for (var i = 0; i < q.budget; i++) ...[
            if (i > 0) const SizedBox(width: 4),
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < drops ? p.ink : null,
                border: i < drops
                    ? null
                    : Border.all(color: p.lineStrong, width: 1.5),
              ),
            ),
          ],
        ]),
      ],
    );
  }
}

/// The building: floor buttons with floor 1 at the bottom. Small buildings
/// are one tall column; taller ones read like a lift panel, left to right
/// and bottom to top.
class _Building extends StatelessWidget {
  const _Building({
    required this.puzzle,
    required this.selected,
    required this.onTap,
  });

  final EggPuzzle puzzle;
  final int? selected;
  final void Function(int) onTap;

  static int columnsFor(int floors) => floors <= 6 ? 1 : (floors / 7).ceil();

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = puzzle;
    final cols = columnsFor(q.floors);
    final rows = (q.floors / cols).ceil();
    final gap = d.compact ? 5.0 : 6.0;
    final tileH = d.compact ? 40.0 : 44.0;
    final dropped = {for (final x in q.log) x.floor: x.broke};

    return LayoutBuilder(
      builder: (context, box) {
        final tileW = cols == 1
            ? 120.0
            : min(
                72.0,
                ((box.maxWidth - 23 - gap * (cols - 1)) / cols).floorToDouble(),
              );
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(18),
                  bottom: Radius.circular(6),
                ),
                border: Border.all(color: p.lineStrong, width: 1.5),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (var r = rows - 1; r >= 0; r--) ...[
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (var c = 0; c < cols; c++) ...[
                          if (c > 0) SizedBox(width: gap),
                          if (r * cols + c + 1 <= q.floors)
                            _Floor(
                              n: r * cols + c + 1,
                              width: tileW,
                              height: tileH,
                              puzzle: q,
                              selected: selected == r * cols + c + 1,
                              broke: dropped[r * cols + c + 1],
                              onTap: onTap,
                            )
                          else
                            SizedBox(width: tileW, height: tileH),
                        ],
                      ],
                    ),
                    if (r > 0) SizedBox(height: gap),
                  ],
                ],
              ),
            ),
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: p.ink,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Floor extends StatelessWidget {
  const _Floor({
    required this.n,
    required this.width,
    required this.height,
    required this.puzzle,
    required this.selected,
    required this.broke,
    required this.onTap,
  });

  final int n;
  final double width;
  final double height;
  final EggPuzzle puzzle;
  final bool selected;

  /// What the egg did from this floor, if one was dropped from it.
  final bool? broke;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final live = puzzle.canDrop(n);
    final (Color bg, Color edge, Color fg) = selected
        ? (p.ink, p.ink, p.onInk)
        : live
        ? (p.surface, p.lineStrong, p.ink)
        : (p.chip, p.chip, p.faint);
    final label = [
      'Floor $n',
      if (broke == true) 'the egg broke here',
      if (broke == false) 'the egg survived here',
      if (!live && broke == null)
        puzzle.safe(n) ? 'known safe' : 'an egg breaks here',
      if (selected) 'selected',
    ].join(', ');

    return PressScale(
      key: ValueKey('floor-$n'),
      semanticLabel: label,
      onTap: live ? () => onTap(n) : null,
      child: SizedBox(
        width: width,
        height: height,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(
              child: AnimatedContainer(
                duration: Lucid.tap,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: edge, width: 1.5),
                ),
                child: Text(
                  '$n',
                  style: lucidText(
                    size: 16,
                    weight: 600,
                    display: true,
                    color: fg,
                  ),
                ),
              ),
            ),
            if (broke != null)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.ink,
                    border: Border.all(color: p.surface, width: 2),
                  ),
                  child: Icon(
                    broke! ? Icons.close_rounded : Icons.check_rounded,
                    size: 11,
                    color: p.onInk,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.chips});

  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips)
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: p.chip,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Align(
              widthFactor: 1,
              child: Text(
                c,
                style: lucidText(size: 13, weight: 700, color: p.ink),
              ),
            ),
          ),
      ],
    );
  }
}

/// The review: the floor found (or the slip and a better drop), every drop
/// made, and three steps for the best first drop.
class _Worked extends StatelessWidget {
  const _Worked({required this.puzzle});

  final EggPuzzle puzzle;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = puzzle;
    final slip = q.won ? null : q.slip;

    Widget tile(String value, String label, bool good) => Container(
      constraints: BoxConstraints(minHeight: d.compact ? 58 : 64),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: good ? p.correctTint : p.missTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: good ? p.correct : p.miss, width: 2.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: lucidText(
                size: 22,
                weight: 700,
                display: true,
                color: p.ink,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: lucidText(
              size: 12,
              weight: 600,
              color: good ? p.correctText : p.missText,
            ),
          ),
        ],
      ),
    );

    final Widget tiles;
    if (q.won) {
      tiles = tile(
        q.lo == 0 ? 'None safe' : 'Floor ${q.lo}',
        'Found in ${q.log.length} of ${q.budget} drops',
        true,
      );
    } else if (slip != null) {
      final (n, better) = slip;
      tiles = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: tile('Floor ${q.log[n - 1].floor}', 'Your drop $n', false),
            ),
            const SizedBox(width: 12),
            Expanded(child: tile('Floor $better', 'Keeps it in reach', true)),
          ],
        ),
      );
    } else {
      tiles = tile('Floor ${q.bestStart}', 'Best first drop', true);
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        _Chips(
          chips: [
            q.eggs == 1 ? '1 egg' : '${q.eggs} eggs',
            '${q.floors} floors',
            '${q.budget} drops',
          ],
        ),
        const SizedBox(height: 10),
        Text(
          'Find the highest safe floor.',
          textAlign: TextAlign.center,
          style: lucidText(size: d.body, color: p.muted, height: 1.45),
        ),
        SizedBox(height: d.gapM),
        tiles,
        SizedBox(height: d.gapM),
        _DropLog(puzzle: q, slipAt: slip?.$1),
        SizedBox(height: d.gapM),
        Container(
          padding: EdgeInsets.all(d.compact ? 14 : 16),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Working it out',
                style: lucidText(size: d.rowTitle, weight: 600, color: p.ink),
              ),
              for (final (i, step) in q.steps.indexed) ...[
                SizedBox(height: d.compact ? 10 : 12),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: p.chip,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: lucidText(size: 12, weight: 700, color: p.ink),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: lucidText(
                          size: d.body,
                          color: p.ink,
                          height: 1.45,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}

class _DropLog extends StatelessWidget {
  const _DropLog({required this.puzzle, required this.slipAt});

  final EggPuzzle puzzle;
  final int? slipAt;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = puzzle;
    final status = q.won ? 'settled' : '${q.range} still fit';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                'Your drops',
                style: lucidText(size: 14, weight: 600, color: p.ink),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${q.log.length} of ${q.budget} · $status',
                  textAlign: TextAlign.right,
                  style: lucidText(size: 12, color: p.muted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final (i, x) in q.log.indexed)
                Semantics(
                  label:
                      'Drop ${i + 1}: floor ${x.floor}, '
                      '${x.broke ? 'broke' : 'survived'}'
                      '${slipAt == i + 1 ? ', the slip' : ''}',
                  excludeSemantics: true,
                  child: Container(
                    height: 30,
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    decoration: BoxDecoration(
                      color: slipAt == i + 1 ? p.missTint : p.chip,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: slipAt == i + 1 ? p.miss : p.chip,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '${x.floor}',
                          style: lucidText(
                            size: 14,
                            weight: 600,
                            display: true,
                            color: slipAt == i + 1 ? p.missText : p.ink,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          x.broke ? Icons.close_rounded : Icons.check_rounded,
                          size: 14,
                          color: slipAt == i + 1 ? p.missText : p.ink,
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (slipAt != null) ...[
            const SizedBox(height: 8),
            Text(
              q.slipNote(slipAt!),
              style: lucidText(size: 13, weight: 600, color: p.missText),
            ),
          ],
        ],
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final enabled = onTap != null;
    final (bg, fg) = enabled ? (p.ink, p.onInk) : (p.chip, p.faint);
    return PressScale(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
          border: Border.all(color: bg, width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: lucidText(size: d.rowTitle, weight: 600, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
