import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'bet_controller.dart';
import 'bet_puzzle.dart';
import 'better_bet_game.dart';

// Built from the "Better Bet · choose" and "· worked answer" artboards.

class BetScreen extends ConsumerWidget {
  const BetScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(betSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const BetterBetGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(betSessionProvider),
                  onTrySimilar: ref
                      .read(betSessionProvider.notifier)
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

  final BetSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final c = ref.read(betSessionProvider.notifier);
    final q = state.question;

    void choose(BetPick p) {
      c.select(p);
      p == q.answer
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    final labels = q.walkAway
        ? const {
            BetPick.a: 'Play',
            BetPick.same: 'Same',
            BetPick.b: 'Walk away',
          }
        : const {BetPick.a: 'Bet A', BetPick.same: 'Same', BetPick.b: 'Bet B'};

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
          game: const BetterBetGame(),
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
          if (!state.answered) ...[
            Text(
              q.question,
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall?.copyWith(height: 1.3),
            ),
            SizedBox(height: d.gapL),
          ],
          _BetCard(tag: 'A', bet: q.a, state: state, side: BetPick.a),
          SizedBox(height: d.gapS),
          _BetCard(tag: 'B', bet: q.b, state: state, side: BetPick.b),
          if (state.answered) ...[
            SizedBox(height: d.gapM),
            _Working(steps: q.steps),
          ],
          SizedBox(height: d.gapM),
        ],
      ),
      dock: state.answered
          ? FeedbackSlot(
              child: FeedbackCard(
                correct: state.lastCorrect,
                points: state.lastPoints,
                explanation: q.feedbackFor(state.picked!),
                isLastRound: state.round + 1 >= state.totalRounds,
                onNext: c.next,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Average win = chance × prize, minus any cost.',
                  textAlign: TextAlign.center,
                  style: lucidText(
                    size: d.small,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                SizedBox(height: d.gapS),
                SizedBox(
                  height: d.compact ? 52 : 60,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, p) in BetPick.values.indexed) ...[
                        if (i > 0) const SizedBox(width: 10),
                        Expanded(
                          flex: p == BetPick.same ? 4 : 5,
                          child: PressScale(
                            key: ValueKey('bet-${p.name}'),
                            semanticLabel: labels[p],
                            onTap: () => choose(p),
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
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                  ),
                                  child: Text(
                                    labels[p]!,
                                    style: lucidText(
                                      size: d.rowTitle,
                                      weight: 600,
                                      color: scheme.onSurface,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// One bet: its letter, what you play and what it pays. After answering it
/// shows what it's worth a go, green for the better bet (both when equal)
/// and rose for a wrong pick.
class _BetCard extends StatelessWidget {
  const _BetCard({
    required this.tag,
    required this.bet,
    required this.state,
    required this.side,
  });

  final String tag;
  final Bet bet;
  final BetSessionState state;
  final BetPick side;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final p = context.palette;
    final q = state.question;
    final answered = state.answered;
    final better = q.answer == side || q.answer == BetPick.same;
    final pickedWrong = answered && state.picked == side && !better;

    final (bg, edge, width) = !answered
        ? (scheme.surface, scheme.outlineVariant, 1.0)
        : better
        ? (p.correctTint, p.correct, 2.5)
        : pickedWrong
        ? (p.missTint, p.miss, 2.5)
        : (scheme.surface, scheme.outlineVariant, 1.0);

    final status = !answered
        ? null
        : '${pickedWrong ? 'Your pick' : (better ? (q.answer == BetPick.same ? 'Same' : 'Better') : 'Worse')} · '
              'worth ${money(bet.value)} a go';

    return Semantics(
      label:
          'Bet $tag: ${bet.title}. ${bet.detail}${status == null ? '' : ' $status.'}',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(d.compact ? 12 : 16),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(d.compact ? 18 : 20),
          border: Border.all(color: edge, width: width),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: d.compact ? 34 : 40,
              height: d.compact ? 34 : 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.chip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                tag,
                style: lucidText(
                  size: 18,
                  weight: 700,
                  display: true,
                  color: scheme.onSurface,
                ),
              ),
            ),
            SizedBox(width: d.compact ? 12 : 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    bet.title,
                    style: lucidText(
                      size: d.rowTitle,
                      weight: 600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    status ?? bet.detail,
                    style: lucidText(
                      size: status == null ? d.body : d.small,
                      weight: status == null ? 400 : 600,
                      color: status == null
                          ? scheme.onSurfaceVariant
                          : (better
                                ? p.correctText
                                : (pickedWrong
                                      ? p.missText
                                      : scheme.onSurfaceVariant)),
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Working extends StatelessWidget {
  const _Working({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    return Container(
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
          for (final (i, step) in steps.indexed) ...[
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
    );
  }
}
