import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'odds_controller.dart';
import 'odds_math.dart';
import 'odds_on_game.dart';
import 'odds_puzzle.dart';
import '../../ui/palette.dart';

// Built from the "Odds On · question" and "Odds On · worked answer"
// artboards.

class OddsScreen extends ConsumerWidget {
  const OddsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(oddsSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const OddsOnGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(oddsSessionProvider),
                  onTrySimilar: ref
                      .read(oddsSessionProvider.notifier)
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

  final OddsSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final c = ref.read(oddsSessionProvider.notifier);
    final q = state.question;

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
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
          state.answered ? _Worked(state: state) : _Question(question: q),
      dock: state.answered
          ? FeedbackSlot(
              child: FeedbackCard(
                correct: state.lastCorrect,
                points: state.lastPoints,
                explanation: q.feedbackFor(q.options[state.picked!]),
                isLastRound: state.round + 1 >= state.totalRounds,
                onNext: c.next,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Take your time. Think in equally likely outcomes.',
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
                  childAspectRatio: d.compact ? 2.8 : 2.45,
                  children: [
                    for (final (i, option) in q.options.indexed)
                      PressScale(
                        key: ValueKey('odds-$i'),
                        semanticLabel: 'Answer $option',
                        onTap: () => choose(i),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: scheme.surface,
                            borderRadius: BorderRadius.circular(
                              d.compact ? 16 : 18,
                            ),
                            border: Border.all(
                              color: scheme.outlineVariant,
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            '$option',
                            style: lucidText(
                              size: d.compact ? 22 : 26,
                              weight: 700,
                              display: true,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.question});

  final OddsQuestion question;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = Dims.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        OddsSceneCard(scene: question.scene),
        SizedBox(height: d.gapL),
        Text(
          question.question,
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(height: 1.3),
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}

/// The picture of the setup: dice, coins, a deck, a bag of balls or a test.
class OddsSceneCard extends StatelessWidget {
  const OddsSceneCard({super.key, required this.scene});

  final OddsScene scene;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final s = scene;
    final die = d.compact ? 54.0 : 68.0;

    Widget mark(String text, double size, {bool round = false}) => Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: context.palette.surface,
        borderRadius: BorderRadius.circular(round ? size : size * 0.22),
        border: Border.all(color: context.palette.ink, width: 2),
      ),
      child: Text(
        text,
        style: lucidText(
          size: size * 0.42,
          weight: 700,
          display: true,
          color: context.palette.ink,
        ),
      ),
    );

    final Widget picture;
    if (s.test) {
      picture = Icon(
        Icons.biotech_rounded,
        size: die,
        color: context.palette.ink,
      );
    } else if (s.balls.isNotEmpty) {
      picture = Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (colour, n) in s.balls)
            for (var i = 0; i < n; i++)
              Container(
                width: d.compact ? 22 : 26,
                height: d.compact ? 22 : 26,
                decoration: BoxDecoration(
                  color: colour.shade(night: context.palette.isNight),
                  shape: BoxShape.circle,
                ),
              ),
        ],
      );
    } else if (s.deck) {
      picture = SizedBox(
        width: die * 1.3,
        height: die * 1.25,
        child: Stack(
          children: [
            for (var i = 0; i < 3; i++)
              Positioned(
                left: i * 6.0,
                top: i * 4.0,
                child: Container(
                  width: die * 0.85,
                  height: die * 1.1,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.palette.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: context.palette.ink, width: 2),
                  ),
                  child: i == 2
                      ? Text(
                          '52',
                          style: lucidText(
                            size: die * 0.32,
                            weight: 700,
                            display: true,
                            color: context.palette.ink,
                          ),
                        )
                      : null,
                ),
              ),
          ],
        ),
      );
    } else {
      final dice = [for (var i = 0; i < s.dice; i++) mark('?', die)];
      final coins = [
        for (var i = 0; i < s.coins; i++)
          mark('?', die * (s.coins > 3 ? 0.62 : 0.8), round: true),
      ];
      picture = Wrap(
        alignment: WrapAlignment.center,
        spacing: 14,
        runSpacing: 10,
        children: [...dice, ...coins],
      );
    }

    return Semantics(
      label: s.label,
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: d.compact ? 16 : 22,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(d.compact ? 20 : 24),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            picture,
            SizedBox(height: d.compact ? 10 : 14),
            Text(
              s.label.toUpperCase(),
              textAlign: TextAlign.center,
              style: lucidLabel(scheme.onSurfaceVariant, size: d.label),
            ),
          ],
        ),
      ),
    );
  }
}

/// After answering: your pick against the right one, then the working.
class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final OddsSessionState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final q = state.question;
    final picked = q.options[state.picked!];

    Widget tile(Frac f, String label, bool right) => Expanded(
      child: Semantics(
        label: '$label: $f, ${f.shortPercent}',
        excludeSemantics: true,
        // Sized by its text (plus padding), so bigger fonts never clip it.
        child: Container(
          padding: EdgeInsets.symmetric(vertical: d.compact ? 8 : 10),
          decoration: BoxDecoration(
            color: right
                ? context.palette.correctTint
                : context.palette.missTint,
            borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
            border: Border.all(
              color: right ? context.palette.correct : context.palette.miss,
              width: 2.5,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '$f',
                style: lucidText(
                  size: d.compact ? 19 : 22,
                  weight: 700,
                  display: true,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                '$label · ${f.shortPercent}',
                style: lucidText(
                  size: 12,
                  weight: 600,
                  color: right
                      ? context.palette.correctText
                      : context.palette.missText,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Text(
          q.short,
          textAlign: TextAlign.center,
          style: lucidText(size: d.body, color: scheme.onSurfaceVariant),
        ),
        SizedBox(height: d.gapM),
        Row(
          children: [
            if (!state.lastCorrect) ...[
              tile(picked, 'Your answer', false),
              const SizedBox(width: 12),
            ],
            tile(q.answer, 'Right', true),
          ],
        ),
        SizedBox(height: d.gapM),
        Container(
          padding: EdgeInsets.all(d.compact ? 14 : 16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Working it out',
                style: lucidText(
                  size: d.rowTitle,
                  weight: 600,
                  color: scheme.onSurface,
                ),
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
                        color: context.palette.chip,
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        '${i + 1}',
                        style: lucidText(
                          size: 12,
                          weight: 700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        step,
                        style: lucidText(
                          size: d.body,
                          color: scheme.onSurface,
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
