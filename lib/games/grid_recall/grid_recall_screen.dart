import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/skills/skill.dart';
import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/session_results.dart';
import 'grid_recall_controller.dart';
import 'grid_recall_game.dart';
import '../../ui/palette.dart';

/// Lit cells use the Memory skill colour: this is the memory game.
final _lit = Skill.memory.color;

class GridRecallScreen extends ConsumerWidget {
  const GridRecallScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(gridSessionProvider);

    // Haptics when a recall attempt is judged.
    ref.listen(gridSessionProvider, (prev, next) {
      if (prev?.phase != GridPhase.review && next.phase == GridPhase.review) {
        next.lastCorrect
            ? HapticFeedback.lightImpact()
            : HapticFeedback.mediumImpact();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const GridRecallGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(gridSessionProvider),
                  onTrySimilar: ref
                      .read(gridSessionProvider.notifier)
                      .trySimilar,
                )
              : _RoundView(key: ValueKey('round-${s.round}'), state: s),
        ),
      ),
    );
  }
}

class _RoundView extends ConsumerWidget {
  const _RoundView({super.key, required this.state});

  final GridSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final controller = ref.read(gridSessionProvider.notifier);
    final p = state.puzzle;
    final n = p.cells.length;

    final (title, subtitle) = switch (state.phase) {
      GridPhase.memorize => (
        p.ordered ? 'Watch the order' : 'Watch the cells',
        'Remember $n cells',
      ),
      GridPhase.recall => (
        p.ordered ? 'Tap them in order' : 'Tap the cells you saw',
        '${state.taps.length} of $n',
      ),
      GridPhase.review => ('Here’s the pattern', ''),
    };

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
          game: const GridRecallGame(),
          helpReady: state.answered,
        ),
        SizedBox(height: d.compact ? 10 : 14),
        LevelComboRow(
          level: state.level,
          combo: state.combo,
          practice: state.practice,
        ),
      ],
      body: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: d.gapM),
          Text(
            title,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          SizedBox(height: d.compact ? 2 : 4),
          SizedBox(
            height: 20,
            child: Text(
              subtitle,
              textAlign: TextAlign.center,
              style: lucidText(
                size: d.small + 1,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
          SizedBox(height: d.gapL),
          Center(
            child: LayoutBuilder(
              builder: (context, c) {
                final side = min(c.maxWidth, 340.0);
                const gap = 8.0;
                final cell = (side - gap * (p.size - 1)) / p.size;
                return SizedBox.square(
                  dimension: side,
                  child: Wrap(
                    spacing: gap,
                    runSpacing: gap,
                    children: [
                      for (var i = 0; i < p.size * p.size; i++)
                        PopIn(
                          index: i,
                          stepMs: 12,
                          child: _Cell(
                            key: ValueKey('cell-$i'),
                            index: i,
                            size: cell,
                            state: state,
                            onTap: state.phase == GridPhase.recall
                                ? () {
                                    HapticFeedback.selectionClick();
                                    controller.tap(i);
                                  }
                                : null,
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
          SizedBox(height: d.gapM),
        ],
      ),
      dock: state.answered
          ? FeedbackSlot(
              child: FeedbackCard(
                correct: state.lastCorrect,
                points: state.lastPoints,
                explanation: p.explain(state.taps),
                isLastRound: state.round + 1 >= state.totalRounds,
                onNext: controller.next,
              ),
            )
          : null,
    );
  }
}

class _Cell extends StatelessWidget {
  const _Cell({
    super.key,
    required this.index,
    required this.size,
    required this.state,
    required this.onTap,
  });

  final int index;
  final double size;
  final GridSessionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final p = state.puzzle;
    final isTarget = p.cells.contains(index);
    final tapOrder = state.taps.indexOf(index);
    final tapped = tapOrder >= 0;

    var fill = scheme.surface;
    var border = scheme.outlineVariant;
    var borderWidth = 1.0;
    String? label;
    var labelColor = Colors.white;
    var semantics = 'Cell ${index + 1}';

    switch (state.phase) {
      case GridPhase.memorize:
        final lit = p.ordered
            ? (state.flashIndex != null && p.cells[state.flashIndex!] == index)
            : isTarget;
        if (lit) {
          fill = _lit;
          border = _lit;
          semantics += ', lit';
        }
      case GridPhase.recall:
        if (tapped) {
          fill = scheme.primary;
          border = scheme.primary;
          labelColor = scheme.onPrimary;
          if (p.ordered) label = '${tapOrder + 1}';
          semantics += ', selected';
        }
      case GridPhase.review:
        final orderedRight = p.ordered && tapped && p.cells[tapOrder] == index;
        final right = p.ordered ? orderedRight : (tapped && isTarget);
        if (tapped && right) {
          fill = context.palette.correctTint;
          border = context.palette.correct;
          borderWidth = 2.5;
          semantics += ', correct';
        } else if (tapped) {
          fill = context.palette.missTint;
          border = context.palette.miss;
          borderWidth = 2.5;
          semantics += ', wrong';
        } else if (isTarget) {
          border = _lit;
          borderWidth = 2.5;
          semantics += ', missed';
        }
        if (p.ordered && isTarget) {
          label = '${p.cells.indexOf(index) + 1}';
          labelColor = scheme.onSurface;
        }
    }

    return Semantics(
      button: onTap != null,
      label: semantics,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: AnimatedScale(
          duration: Lucid.tap,
          scale: state.phase == GridPhase.recall && tapped ? 0.94 : 1,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            width: size,
            height: size,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(Lucid.radiusS),
              border: Border.all(color: border, width: borderWidth),
            ),
            child: label == null
                ? null
                : Text(
                    label,
                    style: lucidText(
                      size: size * 0.32,
                      weight: 700,
                      display: true,
                      color: labelColor,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}
