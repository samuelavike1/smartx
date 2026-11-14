import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/dashed_outline.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import '../pattern_sequence/widgets/token_tile.dart';
import 'deduce_controller.dart';
import 'deduce_game.dart';
import 'deduce_puzzle.dart';
import '../../ui/palette.dart';

// Built from the "Deduce · solve" and "Deduce · review" artboards.

const _ordinals = ['1st', '2nd', '3rd', '4th', '5th'];

class DeduceScreen extends ConsumerWidget {
  const DeduceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deduceSessionProvider);

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const DeduceGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(deduceSessionProvider),
                  onTrySimilar: ref
                      .read(deduceSessionProvider.notifier)
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

  final DeduceSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final c = ref.read(deduceSessionProvider.notifier);
    final p = state.puzzle;
    final broken = state.answered
        ? p.brokenClues(state.order).toSet()
        : const <int>{};

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
          game: const DeduceGame(),
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
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: d.gapM),
          Text(
            'Who goes where?',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          if (!state.answered) ...[
            SizedBox(height: d.compact ? 2 : 4),
            Text(
              'Make all ${p.clues.length} clues true',
              textAlign: TextAlign.center,
              style: lucidText(
                size: d.small + 1,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          SizedBox(height: d.gapL),

          // Clues
          Container(
            padding: EdgeInsets.all(d.compact ? 14 : 16),
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Column(
              children: [
                for (final (i, clue) in p.clues.indexed) ...[
                  if (i > 0) SizedBox(height: d.compact ? 8 : 10),
                  _ClueRow(
                    number: i + 1,
                    text: clue.text,
                    status: !state.answered
                        ? null
                        : (broken.contains(i) ? false : true),
                  ),
                ],
              ],
            ),
          ),

          if (!state.answered) ...[
            SizedBox(height: d.gapL),
            _Spots(
              state: state,
              onTap: (i) {
                HapticFeedback.selectionClick();
                c.tapSpot(i);
              },
            ),
          ] else ...[
            SizedBox(height: d.gapM),
            Text(
              'YOUR ANSWER',
              style: lucidLabel(scheme.onSurfaceVariant, size: d.label),
            ),
            const SizedBox(height: 8),
            _ReviewRow(
              items: state.order,
              marks: [
                for (var i = 0; i < p.size; i++)
                  state.order[i] == p.solution[i],
              ],
            ),
            if (!state.lastCorrect) ...[
              const SizedBox(height: 12),
              Text(
                'SOLUTION',
                style: lucidLabel(scheme.onSurfaceVariant, size: d.label),
              ),
              const SizedBox(height: 8),
              _ReviewRow(items: p.solution),
            ],
          ],
          SizedBox(height: d.gapM),
        ],
      ),
      // Tray + Check while solving, the feedback card after: thumb zone.
      dock: !state.answered
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  state.tray.isEmpty
                      ? 'ALL PLACED · TAP ONE TO MOVE IT'
                      : 'TAP A SHAPE, THEN A SPOT',
                  style: lucidLabel(scheme.onSurfaceVariant, size: d.label),
                ),
                AnimatedSize(
                  duration: Lucid.pop,
                  curve: Curves.easeOutCubic,
                  child: state.tray.isEmpty
                      ? const SizedBox(width: double.infinity)
                      : Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: SizedBox(
                            height: d.tray + 4,
                            child: Wrap(
                              spacing: 12,
                              children: [
                                for (final item in state.tray)
                                  PressScale(
                                    key: ValueKey('tray-${item.name}'),
                                    semanticLabel: item.name,
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      c.pick(item);
                                    },
                                    child: AnimatedScale(
                                      duration: Lucid.tap,
                                      scale: state.selected == item ? 1.06 : 1,
                                      child: TokenTile(
                                        token: item.token,
                                        size: d.tray,
                                        borderColor: state.selected == item
                                            ? scheme.primary
                                            : null,
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                          ),
                        ),
                ),
                SizedBox(height: d.gapL),
                FilledButton(
                  key: const ValueKey('check'),
                  onPressed: state.complete
                      ? () {
                          c.check();
                          ref.read(deduceSessionProvider).lastCorrect
                              ? HapticFeedback.lightImpact()
                              : HapticFeedback.mediumImpact();
                        }
                      : null,
                  child: const Text('Check'),
                ),
              ],
            )
          : FeedbackSlot(
              child: FeedbackCard(
                correct: state.lastCorrect,
                points: state.lastPoints,
                explanation: p.explain(state.order),
                isLastRound: state.round + 1 >= state.totalRounds,
                onNext: c.next,
              ),
            ),
    );
  }
}

class _ClueRow extends StatelessWidget {
  const _ClueRow({
    required this.number,
    required this.text,
    required this.status,
  });

  final int number;
  final String text;

  /// null = not checked yet, true = kept, false = broken.
  final bool? status;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final Widget badge = switch (status) {
      null => Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          shape: BoxShape.circle,
        ),
        child: Text(
          '$number',
          style: lucidText(size: 12, weight: 700, color: scheme.onSurface),
        ),
      ),
      true => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: context.palette.correctTint,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.check_rounded,
          size: 14,
          color: context.palette.correct,
          semanticLabel: 'Kept',
        ),
      ),
      false => Container(
        width: 22,
        height: 22,
        decoration: BoxDecoration(
          color: context.palette.miss,
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.close_rounded,
          size: 14,
          color: context.palette.onMiss,
          semanticLabel: 'Broken',
        ),
      ),
    };

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        badge,
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            text,
            style: lucidText(
              size: Dims.of(context).body,
              height: 1.35,
              color: status == false
                  ? context.palette.missText
                  : scheme.onSurface,
            ),
          ),
        ),
      ],
    );
  }
}

class _Spots extends StatelessWidget {
  const _Spots({required this.state, required this.onTap});

  final DeduceSessionState state;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final n = state.puzzle.size;
    return LayoutBuilder(
      builder: (context, c) {
        const gap = 10.0;
        final tile = min(
          Dims.of(context).spot,
          (c.maxWidth - gap * (n - 1)) / n,
        );
        return Row(
          children: [
            for (var i = 0; i < n; i++) ...[
              if (i > 0) const SizedBox(width: gap),
              Expanded(
                child: Column(
                  children: [
                    PressScale(
                      key: ValueKey('slot-$i'),
                      semanticLabel: state.placed[i] == null
                          ? 'Spot ${i + 1}, empty'
                          : 'Spot ${i + 1}: ${state.placed[i]!.name}',
                      onTap: () => onTap(i),
                      child: AnimatedSwitcher(
                        duration: Lucid.tap * 2,
                        transitionBuilder: (child, a) =>
                            ScaleTransition(scale: a, child: child),
                        child: state.placed[i] == null
                            ? DashedOutline(
                                key: const ValueKey('empty'),
                                size: tile,
                                color: state.selected != null
                                    ? scheme.primary
                                    : context.palette.lineStrong,
                              )
                            : TokenTile(
                                key: ValueKey(state.placed[i]),
                                token: state.placed[i]!.token,
                                size: tile,
                              ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      _ordinals[i],
                      style: lucidText(
                        size: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.items, this.marks});

  final List<DeduceItem> items;

  /// Per spot: true = right place, false = wrong. Null = plain tiles.
  final List<bool>? marks;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final (i, item) in items.indexed)
          Expanded(
            child: Center(
              child: TokenTile(
                token: item.token,
                size: Dims.of(context).tray,
                borderColor: marks == null
                    ? null
                    : (marks![i]
                          ? context.palette.correct
                          : context.palette.miss),
                background: marks == null
                    ? null
                    : (marks![i]
                          ? context.palette.correctTint
                          : context.palette.missTint),
              ),
            ),
          ),
      ],
    );
  }
}
