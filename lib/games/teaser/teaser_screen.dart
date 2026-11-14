import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'teaser_controller.dart';
import 'teaser_game.dart';

// Built from the "Teaser of the day · puzzle and hints" and "· how it works"
// artboards.

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

String _dayLabel(DateTime d) =>
    '${_weekdays[d.weekday - 1]} ${d.day} ${_months[d.month - 1]}';

class TeaserScreen extends ConsumerWidget {
  const TeaserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(teaserSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const TeaserGame(),
                  score: s.points,
                  correct: s.correct ? 1 : 0,
                  total: 1,
                  startLevel: s.level,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: null,
                  onPlayAgain: () => ref.invalidate(teaserSessionProvider),
                  onTrySimilar: () {},
                  showLevel: false,
                )
              : _TeaserView(key: const ValueKey('teaser'), state: s),
        ),
      ),
    );
  }
}

class _TeaserView extends ConsumerWidget {
  const _TeaserView({super.key, required this.state});

  final TeaserSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(teaserSessionProvider.notifier);
    final s = state;
    final t = s.teaser;

    void choose(int i) {
      c.select(i);
      i == s.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    return GameLayout(
      header: [
        GameTopBar(
          filled: s.answered ? 1 : 0,
          total: 1,
          score: s.points,
          game: const TeaserGame(),
        ),
        SizedBox(height: d.compact ? 10 : 14),
        Row(
          children: [
            // IntrinsicWidth: the pill hugs its text instead of stretching.
            Flexible(
              child: IntrinsicWidth(
                child: GamePill(
                  text: s.bonus
                      ? 'Bonus teaser'
                      : 'Teaser of the day · ${_dayLabel(s.day)}',
                  background: p.chip,
                  foreground: p.ink,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              height: d.pill,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.surface,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: p.line),
              ),
              child: Text(
                t.difficultyName,
                style: lucidText(size: d.pillText, weight: 600, color: p.muted),
              ),
            ),
          ],
        ),
      ],
      body: (context, _) => s.answered ? _Worked(state: s) : _Puzzle(state: s),
      dock: s.answered
          ? FeedbackSlot(
              child: FeedbackCard(
                correct: s.correct,
                points: s.points,
                explanation: t.feedbackFor(s.options[s.picked!]),
                isLastRound: true,
                onNext: c.next,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, option) in s.options.indexed) ...[
                  if (i > 0) const SizedBox(height: 10),
                  PressScale(
                    key: ValueKey('teaser-$i'),
                    semanticLabel: 'Answer: $option',
                    onTap: () => choose(i),
                    child: Container(
                      constraints: BoxConstraints(
                        minHeight: d.compact ? 46 : 52,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      alignment: Alignment.centerLeft,
                      decoration: BoxDecoration(
                        color: p.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: p.line, width: 1.5),
                      ),
                      child: Text(
                        option,
                        style: lucidText(
                          size: d.compact ? 15 : 16,
                          weight: 600,
                          color: p.ink,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class _Puzzle extends ConsumerWidget {
  const _Puzzle({required this.state});

  final TeaserSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final s = state;
    final t = s.teaser;
    final left = t.hints.length - s.hints;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: d.compact ? 14 : 18,
          ),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t.title,
                style: lucidText(
                  size: d.compact ? 20 : 22,
                  weight: 600,
                  display: true,
                  color: p.ink,
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                t.text,
                style: lucidText(
                  size: d.compact ? 15 : 16,
                  color: p.ink,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        for (var i = 0; i < s.hints; i++) ...[
          const SizedBox(height: 10),
          Container(
            key: ValueKey('hint-$i'),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: p.sparkTint,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('HINT ${i + 1}', style: lucidLabel(p.sparkText, size: 12)),
                const SizedBox(height: 2),
                Text(
                  t.hints[i],
                  style: lucidText(size: 14, color: p.ink, height: 1.45),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                left == 0
                    ? 'No hints left'
                    : '$left ${left == 1 ? 'hint' : 'hints'} left · each '
                          'costs 30 points',
                style: lucidText(size: 13, color: p.muted),
              ),
            ),
            if (left > 0)
              PressScale(
                key: const ValueKey('teaser-hint'),
                semanticLabel: 'Show a hint',
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(teaserSessionProvider.notifier).showHint();
                },
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.surface,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: p.line, width: 1.5),
                  ),
                  child: Text(
                    'Show a hint',
                    style: lucidText(size: 14, weight: 600, color: p.ink),
                  ),
                ),
              ),
          ],
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final TeaserSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final s = state;
    final t = s.teaser;
    final picked = s.options[s.picked!];
    final right = picked == t.answer;
    final long = t.answer.length > 14 || picked.length > 14;

    Widget tile(String value, String label, bool good) => Container(
      constraints: BoxConstraints(minHeight: d.compact ? 58 : 64),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: good ? p.correctTint : p.missTint,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: good ? p.correct : p.miss, width: 2.5),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: lucidText(
              size: long ? 16 : 22,
              weight: 700,
              display: true,
              color: p.ink,
              height: 1.25,
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
    );

    final mine = tile(picked, 'Your answer', false);
    final best = tile(t.answer, right ? 'Your answer · right' : 'Right', true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Text(
          t.title,
          textAlign: TextAlign.center,
          style: lucidText(size: 20, weight: 600, display: true, color: p.ink),
        ),
        const SizedBox(height: 4),
        Text(
          switch (s.hints) {
            0 => 'No hints used',
            1 => '1 hint used',
            final n => '$n hints used',
          },
          textAlign: TextAlign.center,
          style: lucidText(size: 14, color: p.muted),
        ),
        SizedBox(height: d.gapM),
        if (right)
          best
        else if (long) ...[
          mine,
          const SizedBox(height: 10),
          best,
        ] else
          // Both tiles as tall as the taller one.
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(child: mine),
                const SizedBox(width: 12),
                Expanded(child: best),
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
                'How it works',
                style: lucidText(size: d.rowTitle, weight: 600, color: p.ink),
              ),
              for (final (i, step) in t.steps.indexed) ...[
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
        Text(
          'A new teaser tomorrow. Play again for a bonus one.',
          textAlign: TextAlign.center,
          style: lucidText(size: 13, color: p.muted),
        ),
        SizedBox(height: d.gapM),
      ],
    );
  }
}
