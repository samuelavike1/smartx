import 'dart:math';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../density.dart';
import '../lucid.dart';
import 'press_scale.dart';
import '../palette.dart';
import '../../core/game/game_definition.dart';
import 'how_to_play.dart';

// Shared pieces of every game screen, taken from the "In game" and
// "Results" artboards on the design canvas. New games compose these so they
// look and behave the same.

/// The layout every game screen uses: a fixed [header], the puzzle [body]
/// centred in the space between, and a [dock] anchored to the bottom so the
/// controls (and the feedback card) sit within thumb reach on tall phones.
/// On short phones only the body scrolls; header and dock stay put.
class GameLayout extends StatelessWidget {
  const GameLayout({
    super.key,
    required this.header,
    required this.body,
    this.dock,
  });

  final List<Widget> header;

  /// Builds the body; gets the height available to it (e.g. to size a board).
  final Widget Function(BuildContext context, double height) body;
  final Widget? dock;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    return Column(
      children: [
        Padding(
          padding: EdgeInsets.fromLTRB(16, d.topPad, 16, 0),
          child: Column(children: header),
        ),
        Expanded(
          child: LayoutBuilder(
            builder: (context, c) => SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: c.maxHeight),
                child: Center(child: body(context, c.maxHeight)),
              ),
            ),
          ),
        ),
        if (dock != null)
          Padding(
            padding: EdgeInsets.fromLTRB(16, d.gapS, 16, d.compact ? 12 : 20),
            child: AnimatedSize(
              duration: Lucid.pop,
              curve: Curves.easeOutCubic,
              alignment: Alignment.bottomCenter,
              child: dock,
            ),
          ),
      ],
    );
  }
}

/// Quit button · segmented round progress · animated score.
class GameTopBar extends StatelessWidget {
  const GameTopBar({
    super.key,
    required this.filled,
    required this.total,
    required this.score,
    this.game,
    this.helpReady = true,
  });

  final int filled;
  final int total;
  final int score;

  /// Shows a ? that opens this game's rules.
  final GameDefinition? game;

  /// False while a timed game's clock runs (the ? is dimmed).
  final bool helpReady;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    return Row(
      children: [
        PressScale(
          semanticLabel: 'Quit game',
          onTap: () => context.pop(),
          // 44 in both densities: it's a touch target.
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(
              Icons.close_rounded,
              size: d.compact ? 18 : 20,
              color: scheme.onSurface,
            ),
          ),
        ),
        SizedBox(width: d.compact ? 10 : 12),
        Expanded(
          child: Semantics(
            // [filled] includes the current round once it's answered, so
            // say what is done rather than guess the round number.
            label: '$filled of $total rounds done',
            child: Row(
              children: [
                for (var i = 0; i < total; i++)
                  Expanded(
                    child: AnimatedContainer(
                      duration: Lucid.pop,
                      height: d.compact ? 5 : 6,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: i < filled
                            ? scheme.primary
                            : scheme.outlineVariant,
                        borderRadius: BorderRadius.circular(99),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        if (game case final game?) ...[
          SizedBox(width: d.compact ? 2 : 4),
          HowToButton(game: game, ready: helpReady),
          SizedBox(width: d.compact ? 2 : 4),
        ] else
          SizedBox(width: d.compact ? 10 : 12),
        CountUp(
          value: score,
          style: lucidText(
            size: d.compact ? 16 : 18,
            weight: 700,
            display: true,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}

/// Level badge on the left, combo badge (from ×2) on the right.
class LevelComboRow extends StatelessWidget {
  const LevelComboRow({
    super.key,
    required this.level,
    required this.combo,
    this.practice = false,
  });

  final int level;
  final int combo;

  /// An unscored "Try a similar one" round.
  final bool practice;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        GamePill(
          text: practice ? 'Practice · level $level' : 'Level $level',
          background: scheme.surfaceContainerHigh,
          foreground: scheme.onSurface,
        ),
        AnimatedSwitcher(
          duration: Lucid.pop,
          transitionBuilder: (child, a) =>
              ScaleTransition(scale: a, child: child),
          child: combo >= 2
              ? GamePill(
                  key: ValueKey('combo-$combo'),
                  text: '×$combo combo',
                  background: context.palette.spark,
                  foreground: context.palette.onSpark,
                )
              : SizedBox(height: Dims.of(context).pill),
        ),
      ],
    );
  }
}

class GamePill extends StatelessWidget {
  const GamePill({
    super.key,
    required this.text,
    required this.background,
    required this.foreground,
  });

  final String text;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    return Container(
      height: d.pill,
      padding: EdgeInsets.symmetric(horizontal: d.compact ? 10 : 12),
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: lucidText(size: d.pillText, weight: 700, color: foreground),
      ),
    );
  }
}

/// Slides in after an answer: result, points, the explanation, Next.
/// On short screens it scrolls itself into view, so the result is never
/// below the fold.
class FeedbackCard extends StatefulWidget {
  const FeedbackCard({
    super.key,
    required this.correct,
    required this.points,
    required this.explanation,
    required this.isLastRound,
    required this.onNext,
  });

  final bool correct;
  final int points;
  final String explanation;
  final bool isLastRound;
  final VoidCallback onNext;

  @override
  State<FeedbackCard> createState() => _FeedbackCardState();
}

class _FeedbackCardState extends State<FeedbackCard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Scrollable.ensureVisible(
        context,
        alignment: 1.0,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final correct = widget.correct;
    final points = widget.points;
    final p = context.palette;
    final color = correct ? p.correct : p.miss;
    final textColor = correct ? p.correctText : p.missText;
    final d = Dims.of(context);
    final headline = d.compact ? 18.0 : 20.0;

    return Container(
      padding: EdgeInsets.all(d.cardPad),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(Lucid.radiusL),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: p.shadow,
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: d.compact ? 28 : 32,
                height: d.compact ? 28 : 32,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
                child: Icon(
                  correct ? Icons.check_rounded : Icons.close_rounded,
                  size: d.compact ? 18 : 20,
                  color: correct ? p.onCorrect : p.onMiss,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  correct ? 'Correct!' : 'Not quite',
                  style: lucidText(
                    size: headline,
                    weight: 700,
                    display: true,
                    color: textColor,
                  ),
                ),
              ),
              if (correct && points > 0)
                Text(
                  '+$points',
                  style: lucidText(
                    size: headline,
                    weight: 700,
                    display: true,
                    color: theme.colorScheme.onSurface,
                  ),
                ),
            ],
          ),
          SizedBox(height: d.compact ? 8 : 10),
          Text(widget.explanation, style: theme.textTheme.bodyMedium),
          SizedBox(height: d.gapS + 4),
          FilledButton(
            onPressed: widget.onNext,
            child: Text(widget.isLastRound ? 'See results' : 'Next'),
          ),
        ],
      ),
    );
  }
}

/// Animated wrapper used under [FeedbackCard] so it slides and fades in.
class FeedbackSlot extends StatelessWidget {
  const FeedbackSlot({super.key, required this.child});

  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Lucid.pop,
      transitionBuilder: (child, a) => SlideTransition(
        position: Tween(
          begin: const Offset(0, 0.15),
          end: Offset.zero,
        ).animate(a),
        child: FadeTransition(opacity: a, child: child),
      ),
      child: child ?? const SizedBox.shrink(),
    );
  }
}

/// Animates a number counting up to [value].
class CountUp extends StatelessWidget {
  const CountUp({super.key, required this.value, required this.style});

  final int value;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: Lucid.pop * 2,
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('$v', style: style),
    );
  }
}

/// Horizontal shake for a wrong answer (6 px, decaying).
class Shake extends StatelessWidget {
  const Shake({super.key, required this.active, required this.child});

  final bool active;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (!active) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Lucid.shake,
      builder: (_, t, child) => Transform.translate(
        offset: Offset(sin(t * pi * 6) * 6 * (1 - t), 0),
        child: child,
      ),
      child: child,
    );
  }
}

/// Staggered scale-in, so items appear left to right.
class PopIn extends StatelessWidget {
  const PopIn({
    super.key,
    required this.index,
    required this.child,
    this.stepMs = 70,
  });

  final int index;
  final int stepMs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final total = 300 + index * stepMs;
    final start = (index * stepMs) / total;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(start, 1, curve: Curves.easeOutBack),
      builder: (_, t, child) => Transform.scale(scale: t, child: child),
      child: child,
    );
  }
}
