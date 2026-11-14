import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/game/speed_game.dart';
import '../density.dart';
import '../lucid.dart';
import 'game_chrome.dart';
import 'press_scale.dart';
import 'session_results.dart';

// Screens for the timed-trials games. A game supplies the stimulus, its
// answer buttons and its wording; layout, timer, flash and review are shared
// (built from the Ink Clash and Arrow Focus artboards).

/// Wording for the block review.
@immutable
class SpeedReviewText {
  const SpeedReviewText({
    required this.item,
    required this.calm,
    required this.conflict,
    required this.cost,
    required this.noCost,
  });

  /// One trial, capitalised: "Word", "Row".
  final String item;

  /// Labels of the two speed bars: "Matching words", "Clashing words".
  final String calm;
  final String conflict;

  /// The cost line, given the seconds ("0.39"). Ends with a full stop.
  final String Function(String secs) cost;
  final String noCost;
}

/// The cue pill above the stimulus. [outlined] marks an unusual rule.
@immutable
class SpeedCue {
  const SpeedCue(this.text, {this.outlined = false});

  final String text;
  final bool outlined;
}

class SpeedGameScreen<B extends SpeedBlock<T, A>, T extends SpeedTrial<A>, A>
    extends ConsumerWidget {
  const SpeedGameScreen({
    super.key,
    required this.provider,
    required this.game,
    required this.cue,
    required this.stimulus,
    required this.stimulusHeight,
    required this.hint,
    required this.controls,
    required this.review,
    this.swipe,
  });

  final NotifierProvider<SpeedController<B, T, A>, SpeedSessionState<B, T, A>>
  provider;
  final GameDefinition game;
  final SpeedCue Function(SpeedSessionState<B, T, A> s) cue;

  /// The trial itself; only built while there is one.
  final Widget Function(BuildContext context, T trial, int index) stimulus;

  /// Fixed height for the stimulus, so the layout doesn't jump.
  final double Function(BuildContext context) stimulusHeight;
  final String Function(SpeedSessionState<B, T, A> s) hint;

  /// The answer buttons. Call [press] with the option tapped.
  final Widget Function(
    BuildContext context,
    SpeedSessionState<B, T, A> s,
    void Function(A option) press,
  )
  controls;
  final SpeedReviewText review;

  /// Maps a swipe (finger travel) to an answer, or null to ignore it.
  final A? Function(SpeedSessionState<B, T, A> s, Offset travel)? swipe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(provider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: game,
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(provider),
                  onTrySimilar: ref.read(provider.notifier).trySimilar,
                )
              : _SpeedRound<B, T, A>(
                  key: ValueKey('round-${s.round}-${s.practice}'),
                  screen: this,
                  state: s,
                ),
        ),
      ),
    );
  }
}

class _SpeedRound<B extends SpeedBlock<T, A>, T extends SpeedTrial<A>, A>
    extends ConsumerStatefulWidget {
  const _SpeedRound({super.key, required this.screen, required this.state});

  final SpeedGameScreen<B, T, A> screen;
  final SpeedSessionState<B, T, A> state;

  @override
  ConsumerState<_SpeedRound<B, T, A>> createState() =>
      _SpeedRoundState<B, T, A>();
}

class _SpeedRoundState<B extends SpeedBlock<T, A>, T extends SpeedTrial<A>, A>
    extends ConsumerState<_SpeedRound<B, T, A>> {
  // Swipes are read from raw pointer events so they never fight the
  // body's scroll view or the buttons.
  final _downs = <int, (Offset, Duration)>{};

  static const _minTravel = 40.0;
  static const _maxSwipeTime = Duration(milliseconds: 600);

  void _press(A option) {
    final correct = ref.read(widget.screen.provider.notifier).answer(option);
    if (correct == null) return;
    correct ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
  }

  void _up(PointerUpEvent e) {
    final down = _downs.remove(e.pointer);
    final swipe = widget.screen.swipe;
    if (down == null || swipe == null) return;
    final travel = e.position - down.$1;
    if (travel.distance < _minTravel || e.timeStamp - down.$2 > _maxSwipeTime) {
      return;
    }
    final option = swipe(widget.state, travel);
    if (option != null) _press(option);
  }

  @override
  Widget build(BuildContext context) {
    final screen = widget.screen;
    final state = widget.state;
    final d = Dims.of(context);
    final c = ref.read(screen.provider.notifier);

    final layout = GameLayout(
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
      body: (context, _) => state.answered
          ? SpeedReview(
              round: state.round,
              totalRounds: state.totalRounds,
              length: state.block.length,
              limit: state.block.limit,
              result: state.result!,
              text: screen.review,
            )
          : _Prompt<B, T, A>(screen: screen, state: state),
      dock: !state.answered
          ? Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  screen.hint(state),
                  textAlign: TextAlign.center,
                  style: lucidText(
                    size: d.small,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: d.gapS),
                screen.controls(context, state, _press),
              ],
            )
          : FeedbackSlot(
              child: FeedbackCard(
                correct: state.lastCorrect,
                points: state.lastPoints,
                explanation: state.block.mistake(state.result!, state.answers),
                isLastRound: state.round + 1 >= state.totalRounds,
                onNext: c.next,
              ),
            ),
    );

    if (screen.swipe == null || state.answered) return layout;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => _downs[e.pointer] = (e.position, e.timeStamp),
      onPointerUp: _up,
      onPointerCancel: (e) => _downs.remove(e.pointer),
      child: layout,
    );
  }
}

class _Prompt<B extends SpeedBlock<T, A>, T extends SpeedTrial<A>, A>
    extends StatelessWidget {
  const _Prompt({required this.screen, required this.state});

  final SpeedGameScreen<B, T, A> screen;
  final SpeedSessionState<B, T, A> state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final t = state.trial;
    final cue = screen.cue(state);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(height: d.gapM),
        Text(
          state.phase == SpeedPhase.ready
              ? 'Get ready…'
              : '${screen.review.item} ${state.index + 1} of '
                    '${state.block.length}',
          style: lucidText(size: d.small + 1, color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: d.gapM),
        AnimatedSwitcher(
          duration: Lucid.tap * 2,
          child: SpeedCuePill(key: ValueKey(cue.text), cue: cue),
        ),
        SizedBox(height: d.gapL),
        SizedBox(
          height: screen.stimulusHeight(context),
          child: Center(
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 140),
              transitionBuilder: (child, a) => ScaleTransition(
                scale: Tween(begin: 0.85, end: 1.0).animate(a),
                child: child,
              ),
              child: t == null
                  ? const SizedBox.shrink()
                  : KeyedSubtree(
                      key: ValueKey(state.index),
                      child: screen.stimulus(context, t, state.index),
                    ),
            ),
          ),
        ),
        SizedBox(height: d.gapM),
        SpeedTimerBar(
          running: state.timing,
          index: state.index,
          limit: state.block.limit,
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}

/// A pill sized to its text: ink fill, or outlined for an unusual rule.
class SpeedCuePill extends StatelessWidget {
  const SpeedCuePill({super.key, required this.cue});

  final SpeedCue cue;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final filled = !cue.outlined;
    // No alignment on the Container, or it would stretch to the full width.
    return Container(
      height: d.compact ? 32 : 36,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: filled ? Lucid.ink : Lucid.surface,
        borderRadius: BorderRadius.circular(999),
        border: filled ? null : Border.all(color: Lucid.ink, width: 2),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          cue.text,
          style: lucidText(
            size: d.compact ? 13 : 14,
            weight: 700,
            color: filled ? Colors.white : Lucid.ink,
            letterSpacing: 0.9,
          ),
        ),
      ),
    );
  }
}

/// Time left for the current trial.
class SpeedTimerBar extends StatelessWidget {
  const SpeedTimerBar({
    super.key,
    required this.running,
    required this.index,
    required this.limit,
  });

  final bool running;
  final int index;
  final Duration limit;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: 220,
      height: 6,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: !running
            ? ColoredBox(color: scheme.outlineVariant)
            : TweenAnimationBuilder<double>(
                key: ValueKey('timer-$index'),
                tween: Tween(begin: 1, end: 0),
                duration: limit,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 6,
                  color: scheme.primary,
                  backgroundColor: scheme.outlineVariant,
                ),
              ),
      ),
    );
  }
}

/// An answer button that flashes [mark] after a tap.
class SpeedButton extends StatelessWidget {
  const SpeedButton({
    super.key,
    required this.label,
    required this.mark,
    required this.onTap,
    required this.child,
  });

  final String label;
  final SpeedMark mark;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final (bg, edge, width) = switch (mark) {
      SpeedMark.right => (Lucid.correctTint, Lucid.correct, 2.5),
      SpeedMark.wrong => (Lucid.missTint, Lucid.miss, 2.5),
      SpeedMark.answer => (scheme.surface, Lucid.correct, 2.5),
      SpeedMark.none => (scheme.surface, scheme.outlineVariant, 1.5),
    };
    return PressScale(
      semanticLabel: label,
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 120),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
          border: Border.all(color: edge, width: width),
        ),
        child: child,
      ),
    );
  }
}

/// Block review: right count, calm vs conflict speed, and a ✓/✕ strip.
class SpeedReview extends StatelessWidget {
  const SpeedReview({
    super.key,
    required this.round,
    required this.totalRounds,
    required this.length,
    required this.limit,
    required this.result,
    required this.text,
  });

  final int round;
  final int totalRounds;
  final int length;
  final Duration limit;
  final SpeedResult result;
  final SpeedReviewText text;

  /// Colour of the conflict bar (the Ink Clash orange, in every game).
  static const conflictColor = Color(0xFFE06C00);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final r = result;
    final limitS = limit.inMilliseconds / 1000;

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

    final cost = r.conflictCost;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Text(
          'Block ${round + 1} of $totalRounds',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall,
        ),
        SizedBox(height: d.compact ? 2 : 4),
        Text.rich(
          TextSpan(
            style: lucidText(size: d.small + 1, color: scheme.onSurfaceVariant),
            children: [
              TextSpan(
                text: '${r.right} of $length',
                style: lucidText(
                  size: d.small + 1,
                  weight: 700,
                  color: scheme.onSurface,
                ),
              ),
              TextSpan(
                text: r.passed ? ' right' : ' right · ${r.passMark} needed',
              ),
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
              bar(text.calm, r.calmAvg, scheme.primary),
              SizedBox(height: d.gapS),
              bar(text.conflict, r.conflictAvg, conflictColor),
              if (cost != null) ...[
                SizedBox(height: d.gapS),
                Text(
                  cost > SpeedResult.noticeable
                      ? '${text.cost(cost.toStringAsFixed(2))} '
                            'That gap shrinks as focus improves.'
                      : text.noCost,
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
                  label: '${text.item} ${i + 1}, ${ok ? 'right' : 'wrong'}',
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
