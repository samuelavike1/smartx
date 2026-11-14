import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/skills/skill.dart';
import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'echo_back_game.dart';
import 'echo_controller.dart';
import 'echo_puzzle.dart';
import '../../ui/palette.dart';

// Built from the "Echo Back · play" and "Echo Back · review" artboards.

final _lit = Skill.memory.color;

/// Text for a missed step: deep violet by day, light violet at night.
Color _missInk(LucidPalette p) =>
    p.isNight ? const Color(0xFFC4B5FD) : const Color(0xFF5B21B6);

class EchoScreen extends ConsumerWidget {
  const EchoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(echoSessionProvider);

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const EchoBackGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(echoSessionProvider),
                  onTrySimilar: ref
                      .read(echoSessionProvider.notifier)
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

  final EchoSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final c = ref.read(echoSessionProvider.notifier);
    final b = state.block;
    final r = state.result;

    void press(EchoChannel ch) {
      final correct = c.tap(ch);
      if (correct == null) return;
      correct ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
    }

    final subtitle = switch (state.phase) {
      EchoPhase.ready => Text(
        'Get ready…',
        textAlign: TextAlign.center,
        style: lucidText(size: d.small + 1, color: scheme.onSurfaceVariant),
      ),
      EchoPhase.playing => Text(
        'Step ${state.step + 1} of ${b.length}',
        textAlign: TextAlign.center,
        style: lucidText(size: d.small + 1, color: scheme.onSurfaceVariant),
      ),
      EchoPhase.review => Text.rich(
        TextSpan(
          style: lucidText(size: d.small + 1, color: scheme.onSurfaceVariant),
          children: [
            const TextSpan(text: 'Caught '),
            TextSpan(
              text: '${r!.hits} of ${r.targets}',
              style: lucidText(
                size: d.small + 1,
                weight: 700,
                color: scheme.onSurface,
              ),
            ),
            TextSpan(
              text:
                  ' · ${r.misses.length} missed · '
                  '${r.falseTaps.length == 1 ? '1 false tap' : '${r.falseTaps.length} false taps'}',
            ),
          ],
        ),
        textAlign: TextAlign.center,
      ),
    };

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
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
            state.answered
                ? 'Block ${state.round + 1} of ${state.totalRounds}'
                : 'Match ${b.n} back',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall,
          ),
          SizedBox(height: d.compact ? 2 : 4),
          subtitle,
          SizedBox(height: d.gapL),
          if (!state.answered)
            _Grid(state: state)
          else ...[
            _Timeline(result: r!),
            SizedBox(height: d.gapS + 2),
            const _Legend(),
          ],
          SizedBox(height: d.gapM),
        ],
      ),
      dock: !state.answered
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  b.dual
                      ? 'Tap a button when the square or the colour matches ${b.n} back.'
                      : 'Tap only if this square also lit ${b.n} '
                            '${b.n == 1 ? 'step' : 'steps'} ago.',
                  textAlign: TextAlign.center,
                  style: lucidText(
                    size: d.small,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: d.gapS),
                Row(
                  children: [
                    for (final (i, ch) in b.channels.indexed) ...[
                      if (i > 0) const SizedBox(width: 12),
                      Expanded(
                        child: _MatchButton(
                          key: ValueKey('echo-${ch.word}'),
                          label: b.dual ? 'Same ${ch.word}' : 'Match',
                          flash:
                              state.lastTap != null &&
                                  state.lastTap!.step == state.step &&
                                  state.lastTap!.channel == ch
                              ? state.lastTap!.correct
                              : null,
                          onTap: () => press(ch),
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            )
          : FeedbackSlot(
              child: FeedbackCard(
                correct: state.lastCorrect,
                points: state.lastPoints,
                explanation: b.explain(r!),
                isLastRound: state.round + 1 >= state.totalRounds,
                onNext: c.next,
              ),
            ),
    );
  }
}

class _Grid extends StatelessWidget {
  const _Grid({required this.state});

  final EchoSessionState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final b = state.block;
    final item = state.step >= 0 && state.visible ? b.items[state.step] : null;
    final colour = item == null
        ? null
        : (b.dual ? echoColours[item.colour] : _lit);

    return LayoutBuilder(
      builder: (context, c) {
        final side = min(c.maxWidth, d.compact ? 248.0 : 300.0);
        final gap = d.compact ? 8.0 : 10.0;
        final cell = (side - 2 * gap) / 3;
        return Semantics(
          label: item == null
              ? 'Grid, nothing lit'
              : 'Square ${item.cell + 1} lit',
          liveRegion: true,
          child: SizedBox.square(
            dimension: side,
            child: Wrap(
              spacing: gap,
              runSpacing: gap,
              children: [
                for (var i = 0; i < 9; i++)
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: cell,
                    height: cell,
                    decoration: BoxDecoration(
                      color: item?.cell == i ? colour : scheme.surface,
                      borderRadius: BorderRadius.circular(d.compact ? 14 : 16),
                      border: item?.cell == i
                          ? null
                          : Border.all(color: scheme.outlineVariant),
                      boxShadow: item?.cell == i
                          ? [
                              BoxShadow(
                                color: colour!.withValues(alpha: 0.35),
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ]
                          : null,
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _MatchButton extends StatelessWidget {
  const _MatchButton({
    super.key,
    required this.label,
    required this.flash,
    required this.onTap,
  });

  final String label;

  /// true = just tapped a real match, false = a false tap, null = idle.
  final bool? flash;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final p = context.palette;
    final (bg, fg) = switch (flash) {
      true => (p.correct, p.onCorrect),
      false => (p.miss, p.onMiss),
      null => (p.ink, p.onInk),
    };
    return PressScale(
      semanticLabel: label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        height: d.button + 12,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          label,
          style: lucidText(size: d.compact ? 16 : 18, weight: 700, color: fg),
        ),
      ),
    );
  }
}

class _Timeline extends StatelessWidget {
  const _Timeline({required this.result});

  final EchoResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    return LayoutBuilder(
      builder: (context, c) {
        const perRow = 8, gap = 8.0;
        final w = min(c.maxWidth, 344.0);
        final chip = (w - gap * (perRow - 1)) / perRow;
        final h = d.compact ? 32.0 : 36.0;
        return SizedBox(
          width: w,
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (final (i, o) in result.outcomes.indexed)
                _chip(i, o, chip, h, scheme, context.palette),
            ],
          ),
        );
      },
    );
  }

  Widget _chip(
    int i,
    StepOutcome o,
    double w,
    double h,
    ColorScheme scheme,
    LucidPalette p,
  ) {
    final number = Text(
      '${i + 1}',
      style: lucidText(size: 12, color: scheme.onSurfaceVariant),
    );
    final (bg, border, child, label) = switch (o) {
      StepOutcome.warmup => (
        Colors.transparent,
        Border.all(color: p.lineStrong),
        Text('${i + 1}', style: lucidText(size: 12, color: p.faint)),
        'warm-up',
      ),
      StepOutcome.quiet => (
        scheme.surface,
        Border.all(color: scheme.outlineVariant),
        number,
        'no match',
      ),
      StepOutcome.hit => (
        p.correctTint,
        Border.all(color: p.correct, width: 2),
        Icon(Icons.check_rounded, size: 16, color: p.correct),
        'caught',
      ),
      StepOutcome.miss => (
        scheme.surface,
        Border.all(color: _lit, width: 2.5),
        Text(
          '${i + 1}',
          style: lucidText(size: 12, weight: 700, color: _missInk(p)),
        ),
        'missed',
      ),
      StepOutcome.falseTap => (
        p.missTint,
        Border.all(color: p.miss, width: 2),
        Icon(Icons.close_rounded, size: 14, color: p.miss),
        'false tap',
      ),
    };
    return Semantics(
      label: 'Step ${i + 1}, $label',
      // The label says it all; don't also read the number inside.
      excludeSemantics: true,
      child: Container(
        width: w,
        height: h,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(10),
          border: border,
        ),
        child: child,
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    Widget item(Color? fill, Color edge, double width, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: edge, width: width),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          text,
          style: lucidText(size: d.small, color: scheme.onSurfaceVariant),
        ),
      ],
    );
    return Wrap(
      spacing: 14,
      runSpacing: 6,
      alignment: WrapAlignment.center,
      children: [
        item(context.palette.correctTint, context.palette.correct, 2, 'Caught'),
        item(null, _lit, 2.5, 'Missed'),
        item(context.palette.missTint, context.palette.miss, 2, 'False tap'),
        item(null, context.palette.lineStrong, 1, 'Warm-up'),
      ],
    );
  }
}
