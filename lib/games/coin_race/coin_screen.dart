import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'coin_controller.dart';
import 'coin_puzzle.dart';
import 'coin_race_game.dart';

// Built from the "Coin Race · question" and "· worked answer" artboards.

class CoinScreen extends ConsumerWidget {
  const CoinScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(coinSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const CoinRaceGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(coinSessionProvider),
                  onTrySimilar: ref
                      .read(coinSessionProvider.notifier)
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

  final CoinSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(coinSessionProvider.notifier);
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
          game: const CoinRaceGame(),
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
                  'Take your time. Watch how the patterns overlap.',
                  textAlign: TextAlign.center,
                  style: lucidText(size: d.small, color: p.muted),
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
                        key: ValueKey('coin-$i'),
                        semanticLabel: 'Answer $option',
                        onTap: () => choose(i),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(
                              d.compact ? 16 : 18,
                            ),
                            border: Border.all(color: p.line, width: 1.5),
                          ),
                          child: q.kind == CoinKind.pick
                              ? CoinRow(pattern: option, size: 30)
                              : Text(
                                  option,
                                  style: lucidText(
                                    size: d.compact ? 22 : 26,
                                    weight: 700,
                                    display: true,
                                    color: p.ink,
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

/// Flips in a row: H filled ink, T outlined.
class CoinRow extends StatelessWidget {
  const CoinRow({super.key, required this.pattern, this.size = 40});

  final String pattern;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: pattern
          .split('')
          .map((c) => c == 'H' ? 'heads' : 'tails')
          .join(', '),
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (final (i, c) in pattern.split('').indexed) ...[
            if (i > 0) SizedBox(width: size * 0.2),
            Container(
              width: size,
              height: size,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c == 'H' ? p.ink : p.surface,
                border: Border.all(color: p.ink, width: 2),
              ),
              child: Text(
                c,
                style: lucidText(
                  size: size * 0.42,
                  weight: 700,
                  display: true,
                  color: c == 'H' ? p.onInk : p.ink,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The pattern (or the two racers, or the friend's pick).
class _Scene extends StatelessWidget {
  const _Scene({required this.question, this.small = false});

  final CoinQuestion question;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = question;
    final size = small ? 30.0 : (d.compact ? 34.0 : 40.0);
    Widget labelled(String who, String pattern) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: who.length > 1 ? 64 : 28,
          child: Text(
            who,
            style: lucidText(
              size: 15,
              weight: 700,
              display: true,
              color: p.muted,
            ),
          ),
        ),
        CoinRow(pattern: pattern, size: size),
      ],
    );
    return switch (q.kind) {
      CoinKind.wait => CoinRow(pattern: q.patterns.single, size: size),
      CoinKind.race => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          labelled('A', q.patterns[0]),
          SizedBox(height: small ? 8 : 12),
          labelled('B', q.patterns[1]),
        ],
      ),
      CoinKind.pick => labelled('Friend', q.patterns.single),
    };
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.question});

  final CoinQuestion question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = question;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Container(
          padding: EdgeInsets.symmetric(
            vertical: d.compact ? 16 : 22,
            horizontal: 16,
          ),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: [
              _Scene(question: q),
              SizedBox(height: d.compact ? 10 : 14),
              Text(
                q.caption.toUpperCase(),
                textAlign: TextAlign.center,
                style: lucidLabel(p.muted),
              ),
            ],
          ),
        ),
        SizedBox(height: d.gapL),
        Text(
          q.kind == CoinKind.wait
              ? q.question.replaceFirst(' of a fair coin', '')
              : q.question,
          textAlign: TextAlign.center,
          style: lucidText(
            size: d.compact ? 20 : 24,
            weight: 600,
            display: true,
            color: p.ink,
            height: 1.3,
          ),
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final CoinSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final picked = q.options[state.picked!];
    final right = picked == q.answer;

    Widget tile(String value, String label, bool good) => Expanded(
      child: Container(
        height: d.compact ? 58 : 64,
        decoration: BoxDecoration(
          color: good ? p.correctTint : p.missTint,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: good ? p.correct : p.miss, width: 2.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            q.kind == CoinKind.pick
                ? CoinRow(pattern: value, size: 22)
                : Text(
                    value,
                    style: lucidText(
                      size: 22,
                      weight: 700,
                      display: true,
                      color: p.ink,
                    ),
                  ),
            const SizedBox(height: 2),
            Text(
              label,
              style: lucidText(
                size: 12,
                weight: 600,
                color: good ? p.correctText : p.missText,
              ),
            ),
          ],
        ),
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Center(child: _Scene(question: q, small: true)),
        const SizedBox(height: 10),
        Text(
          q.question,
          textAlign: TextAlign.center,
          style: lucidText(size: d.body, color: p.muted, height: 1.45),
        ),
        SizedBox(height: d.gapM),
        Semantics(
          label: right
              ? 'Your answer $picked is right'
              : 'Your answer $picked. Right answer ${q.answer}',
          excludeSemantics: true,
          child: Row(
            children: [
              if (!right) ...[
                tile(picked, 'Your answer', false),
                const SizedBox(width: 12),
              ],
              tile(q.answer, right ? 'Your answer · right' : 'Right', true),
            ],
          ),
        ),
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
        const SizedBox(height: 10),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: 'TRIED 1,000 TIMES',
                style: lucidLabel(p.muted, size: 12),
              ),
              TextSpan(text: '  ·  ${q.tried}'),
            ],
          ),
          textAlign: TextAlign.center,
          style: lucidText(size: 13, color: p.muted),
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}
