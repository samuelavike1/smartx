import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'ink_clash_game.dart';
import 'ink_controller.dart';
import 'ink_puzzle.dart';

// Built from the "Ink Clash · play" and "Ink Clash · review" artboards.

class InkScreen extends ConsumerWidget {
  const InkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(inkSessionProvider);

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const InkClashGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(inkSessionProvider),
                  onTrySimilar: ref
                      .read(inkSessionProvider.notifier)
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

  final InkSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final c = ref.read(inkSessionProvider.notifier);
    final b = state.block;
    final r = state.result;

    void press(InkColour colour) {
      final correct = c.answer(colour);
      if (correct == null) return;
      correct ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
    }

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
      body: (context, _) =>
          state.answered ? _Review(state: state) : _Prompt(state: state),
      dock: !state.answered
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  b.flips
                      ? 'Follow the cue: tap the ink, or tap the word.'
                      : 'Tap the colour of the ink, not the word.',
                  textAlign: TextAlign.center,
                  style: lucidText(
                    size: d.small,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: d.gapS),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: d.compact ? 3.4 : 2.9,
                  children: [
                    for (final colour in InkColour.values)
                      _ColourButton(
                        key: ValueKey('ink-${colour.name}'),
                        colour: colour,
                        state: state,
                        onTap: () => press(colour),
                      ),
                  ],
                ),
              ],
            )
          : FeedbackSlot(
              child: FeedbackCard(
                correct: state.lastCorrect,
                points: state.lastPoints,
                explanation: b.explain(r!, state.answers),
                isLastRound: state.round + 1 >= state.totalRounds,
                onNext: c.next,
              ),
            ),
    );
  }
}

class _Prompt extends StatelessWidget {
  const _Prompt({required this.state});

  final InkSessionState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final t = state.trial;
    final wordSize = d.compact ? 52.0 : 64.0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: d.gapM),
        Text(
          state.phase == InkPhase.ready
              ? 'Get ready…'
              : 'Word ${state.index + 1} of ${state.block.length}',
          style: lucidText(size: d.small + 1, color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: d.gapM),
        // The cue: INK (ink pill) or WORD (outlined), so a flip is obvious.
        AnimatedSwitcher(
          duration: Lucid.tap * 2,
          child: _Cue(
            key: ValueKey(t?.rule ?? InkRule.ink),
            rule: t?.rule ?? InkRule.ink,
          ),
        ),
        SizedBox(height: d.gapL),
        SizedBox(
          height: wordSize * 1.3,
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.0).animate(a),
                child: child,
              ),
              child: t == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      key: ValueKey(state.index),
                      label:
                          'The word ${t.word.word}, written in ${t.ink.label.toLowerCase()} ink',
                      liveRegion: true,
                      excludeSemantics: true,
                      child: Text(
                        t.word.word,
                        style: lucidText(
                          size: wordSize,
                          weight: 700,
                          display: true,
                          color: t.ink.color,
                          letterSpacing: wordSize * 0.02,
                        ),
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(height: d.gapM),
        // Time left for this word.
        SizedBox(
          width: 220,
          height: 6,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: state.phase != InkPhase.playing || state.flash != null
                ? ColoredBox(color: scheme.outlineVariant)
                : TweenAnimationBuilder<double>(
                    key: ValueKey('timer-${state.index}'),
                    tween: Tween(begin: 1, end: 0),
                    duration: state.block.limit,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: scheme.primary,
                      backgroundColor: scheme.outlineVariant,
                    ),
                  ),
          ),
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}

class _Cue extends StatelessWidget {
  const _Cue({super.key, required this.rule});

  final InkRule rule;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final ink = rule == InkRule.ink;
    // A pill sized to its text (no alignment, or the Container would
    // stretch to the full width).
    return Container(
      height: d.compact ? 32 : 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: ink ? Lucid.ink : Lucid.surface,
        borderRadius: BorderRadius.circular(999),
        border: ink ? null : Border.all(color: Lucid.ink, width: 2),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          'TAP THE ${rule.cue}',
          style: lucidText(
            size: d.compact ? 13 : 14,
            weight: 700,
            color: ink ? Colors.white : Lucid.ink,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}

class _ColourButton extends StatelessWidget {
  const _ColourButton({
    super.key,
    required this.colour,
    required this.state,
    required this.onTap,
  });

  final InkColour colour;
  final InkSessionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final f = state.flash;
    final mine = f != null && f.index == state.index;
    final tapped = mine && f.tapped == colour;
    final isAnswer = mine && state.trial?.answer == colour;

    final (bg, edge, width) = tapped
        ? (f.correct
              ? (Lucid.correctTint, Lucid.correct, 2.5)
              : (Lucid.missTint, Lucid.miss, 2.5))
        : isAnswer
        ? (scheme.surface, Lucid.correct, 2.5)
        : (scheme.surface, scheme.outlineVariant, 1.5);

    return PressScale(
      semanticLabel: colour.label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
          border: Border.all(color: edge, width: width),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 18,
              height: 18,
              decoration: BoxDecoration(
                color: colour.color,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 10),
            Text(
              colour.label,
              style: lucidText(
                size: d.rowTitle,
                weight: 600,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Review extends StatelessWidget {
  const _Review({required this.state});

  final InkSessionState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final r = state.result!;
    final limitS = state.block.limit.inMilliseconds / 1000;

    Widget bar(String label, double? secs, Color color) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: lucidText(size: d.small + 1, color: scheme.onSurface),
              ),
            ),
            Text(
              secs == null ? '—' : '${secs.toStringAsFixed(2)} s',
              style: lucidText(
                size: d.small + 1,
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
            tween: Tween(
              begin: 0,
              end: secs == null ? 0 : min(1, secs / limitS),
            ),
            duration: Lucid.pop * 2,
            curve: Curves.easeOutCubic,
            builder: (_, v, _) => LinearProgressIndicator(
              value: v,
              minHeight: 10,
              color: color,
              backgroundColor: scheme.surfaceContainerHigh,
            ),
          ),
        ),
      ],
    );

    final cost = r.clashCost;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Text(
          'Block ${state.round + 1} of ${state.totalRounds}',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        SizedBox(height: d.compact ? 2 : 4),
        Text.rich(
          TextSpan(
            style: lucidText(size: d.small + 1, color: scheme.onSurfaceVariant),
            children: [
              TextSpan(
                text: '${r.right} of ${state.block.length}',
                style: lucidText(
                  size: d.small + 1,
                  weight: 700,
                  color: scheme.onSurface,
                ),
              ),
              const TextSpan(text: ' right'),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        SizedBox(height: d.gapL),
        Container(
          padding: EdgeInsets.all(d.compact ? 12 : 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Your speed',
                style: lucidText(
                  size: d.rowTitle,
                  weight: 600,
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: d.gapS),
              bar('Matching words', r.matchAvg, scheme.primary),
              SizedBox(height: d.gapS),
              bar('Clashing words', r.clashAvg, InkColour.orange.color),
              if (cost != null) ...[
                SizedBox(height: d.gapS),
                Text(
                  cost > 0.05
                      ? 'The clash cost you ${cost.toStringAsFixed(2)} s a word. '
                            'That gap shrinks as focus improves.'
                      : 'Clashing words didn\'t slow you down. Sharp focus.',
                  style: lucidText(
                    size: d.small,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: d.gapM),
        Row(
          children: [
            for (final (i, ok) in r.correct.indexed) ...[
              if (i > 0) const SizedBox(width: 5),
              Expanded(
                child: Semantics(
                  label: 'Word ${i + 1}, ${ok ? 'right' : 'wrong'}',
                  excludeSemantics: true,
                  child: Container(
                    height: d.compact ? 22 : 26,
                    decoration: BoxDecoration(
                      color: ok ? Lucid.correctTint : Lucid.missTint,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: ok ? Lucid.correct : Lucid.miss,
                        width: 1.5,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}
