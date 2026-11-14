import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'best_run_game.dart';
import 'run_controller.dart';
import 'run_puzzle.dart';

// Built from the "Best Run · pick the stretch", "· running total" and
// "· buy once, sell once" artboards.

class RunScreen extends ConsumerWidget {
  const RunScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(runSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const BestRunGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(runSessionProvider),
                  onTrySimilar: ref
                      .read(runSessionProvider.notifier)
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

  final RunSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(runSessionProvider.notifier);
    final s = state;
    final q = s.puzzle;

    void lock() {
      c.lock();
      ref.read(runSessionProvider).lastCorrect
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    void tap(int i) {
      HapticFeedback.selectionClick();
      c.tapDay(i);
    }

    final chart = _Chart(state: s, onTap: tap);

    final String? pill = s.start == null
        ? null
        : (s.end == null
              ? 'Buy day ${s.start! + 1} at \$${q.values[s.start!]} · now '
                    'a later day to sell'
              : q.choiceText(s.start!, s.end!));

    return GameLayout(
      header: [
        GameTopBar(
          filled: s.round + (s.answered ? 1 : 0),
          total: s.totalRounds,
          score: s.score,
          game: const BestRunGame(),
        ),
        SizedBox(height: d.compact ? 10 : 14),
        LevelComboRow(level: s.level, combo: s.combo, practice: s.practice),
      ],
      body: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: d.gapM),
          if (!s.answered) ...[
            Text(
              q.title,
              textAlign: TextAlign.center,
              style: lucidText(
                size: d.compact ? 20 : 22,
                weight: 600,
                display: true,
                color: p.ink,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              q.question,
              textAlign: TextAlign.center,
              style: lucidText(size: d.body, color: p.muted, height: 1.45),
            ),
            SizedBox(height: d.gapM),
          ],
          chart,
          SizedBox(height: d.gapM),
          if (!s.answered)
            Center(
              child: _Pill(
                text: pill ?? ' ',
                background: pill == null ? null : p.sparkTint,
                foreground: p.sparkText,
              ),
            )
          else
            _Verdict(state: s),
          if (s.answered) ...[
            SizedBox(height: d.gapM),
            _Working(steps: q.steps),
          ],
          SizedBox(height: d.gapM),
        ],
      ),
      dock: s.answered
          ? FeedbackSlot(
              child: FeedbackCard(
                correct: s.lastCorrect,
                points: s.lastPoints,
                explanation: q.feedbackFor(s.start!, s.end!),
                isLastRound: s.round + 1 >= s.totalRounds,
                onNext: c.next,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  q.prices
                      ? 'Tap the day to buy, then a later day to sell.'
                      : 'Tap the first day, then the last. Tap again to start '
                            'over.',
                  textAlign: TextAlign.center,
                  style: lucidText(size: d.small, color: p.muted),
                ),
                SizedBox(height: d.gapS),
                SizedBox(
                  height: d.compact ? 52 : 60,
                  child: PressScale(
                    key: const ValueKey('run-lock'),
                    semanticLabel: 'Lock in',
                    onTap: s.canLock ? lock : null,
                    child: Container(
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: s.canLock ? p.ink : p.chip,
                        borderRadius: BorderRadius.circular(
                          d.compact ? 16 : 18,
                        ),
                      ),
                      child: Text(
                        s.canLock
                            ? 'Lock in ${q.prices ? signedMoney(q.valueOf(s.start!, s.end!)) : signed(q.valueOf(s.start!, s.end!))}'
                            : 'Lock in',
                        style: lucidText(
                          size: d.rowTitle,
                          weight: 600,
                          color: s.canLock ? p.onInk : p.faint,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, this.background, required this.foreground});

  final String text;
  final Color? background;
  final Color foreground;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 32),
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
    decoration: BoxDecoration(
      color: background,
      borderRadius: BorderRadius.circular(999),
    ),
    child: Text(
      text,
      textAlign: TextAlign.center,
      style: lucidText(size: 14, weight: 700, color: foreground),
    ),
  );
}

/// After locking in: yours (rose, when wrong) and the best (green).
class _Verdict extends StatelessWidget {
  const _Verdict({required this.state});

  final RunSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final q = state.puzzle;
    final (bs, be) = q.bestChoice;
    String short(int s, int e) => q.prices
        ? 'day ${s + 1} → ${e + 1} · ${signedMoney(q.valueOf(s, e))}'
        : '${daysText(s, e)} · ${signed(q.valueOf(s, e))}';
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        if (!state.lastCorrect)
          _Pill(
            text: 'Yours: ${short(state.start!, state.end!)}',
            background: p.missTint,
            foreground: p.missText,
          ),
        _Pill(
          text: state.lastCorrect
              ? 'Yours: ${short(bs, be)} · the best'
              : 'Best: ${short(bs, be)}',
          background: p.correctTint,
          foreground: p.correctText,
        ),
      ],
    );
  }
}

/// The days, one column each: bars of profit, or a line of prices. Columns
/// are the tap targets in both.
class _Chart extends StatelessWidget {
  const _Chart({required this.state, required this.onTap});

  final RunSessionState state;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final s = state;
    final q = s.puzzle;
    final n = q.days;
    final review = s.answered;
    final (bs, be) = q.bestChoice;
    final running = q.running;
    final peak = running.reduce(max);
    final restarts = q.restarts;

    final band = review
        ? (bs, be)
        : (s.start == null ? null : (s.start!, s.end ?? s.start!));
    final yours = review ? (s.start!, s.end!) : null;

    // Bars: units sized so the tallest bar fits.
    final top = max(1, q.values.reduce(max));
    final bottom = max(1, -q.values.reduce(min));
    // The review adds a row of running totals, so its chart is shorter.
    final shrink = review ? 0.65 : 1.0;
    final unit =
        min(d.compact ? 6.5 : 8.0, (d.compact ? 56 : 72) / max(top, bottom)) *
        shrink;
    final upH = q.prices
        ? 0.0
        : (q.values.reduce(max) > 0 ? top * unit + 22 : 8.0);
    final dnH = q.prices
        ? 0.0
        : (q.values.reduce(min) < 0 ? bottom * unit + 22 : 8.0);
    final lineH = (d.compact ? 130.0 : 156.0) * shrink;
    final label = lucidText(size: 11, weight: 600, display: true, color: p.ink);

    Widget column(int i, double colW) {
      final v = q.values[i];
      final inYours = yours != null && i >= yours.$1 && i <= yours.$2;
      final barColour = v > 0 ? p.ink : p.lineStrong;
      return GestureDetector(
        key: ValueKey('day-$i'),
        behavior: HitTestBehavior.opaque,
        onTap: review ? null : () => onTap(i),
        child: Semantics(
          button: !review,
          label:
              'Day ${i + 1}: ${q.prices ? '\$$v' : signed(v)}'
              '${band != null && i >= band.$1 && i <= band.$2 ? ', chosen' : ''}',
          excludeSemantics: true,
          child: SizedBox(
            width: colW,
            child: Column(
              children: [
                if (q.prices)
                  SizedBox(height: lineH)
                else ...[
                  SizedBox(
                    height: upH,
                    child: v > 0
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              Text(signed(v), style: label),
                              const SizedBox(height: 2),
                              Container(
                                width: colW * 0.7,
                                height: v * unit,
                                decoration: BoxDecoration(
                                  color: barColour,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ],
                          )
                        : null,
                  ),
                  Container(height: 2, color: p.lineStrong),
                  SizedBox(
                    height: dnH,
                    child: v < 0
                        ? Column(
                            mainAxisAlignment: MainAxisAlignment.start,
                            children: [
                              Container(
                                width: colW * 0.7,
                                height: -v * unit,
                                decoration: BoxDecoration(
                                  color: barColour,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                signed(v),
                                style: label.copyWith(color: p.muted),
                              ),
                            ],
                          )
                        : null,
                  ),
                ],
                const SizedBox(height: 4),
                Text('${i + 1}', style: lucidText(size: 11, color: p.faint)),
                if (review) ...[
                  Container(
                    height: 3,
                    margin: const EdgeInsets.only(top: 3),
                    color: inYours && !s.lastCorrect ? p.miss : null,
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 20,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: i == be && running[i] == peak ? p.correct : null,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        signed(running[i]),
                        style: lucidText(
                          size: 12,
                          weight: 700,
                          display: true,
                          color: i == be && running[i] == peak
                              ? p.onCorrect
                              : (restarts.contains(i) ? p.faint : p.ink),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final colW = box.maxWidth / n;
          return Stack(
            children: [
              if (band != null)
                Positioned(
                  left: band.$1 * colW,
                  width: (band.$2 - band.$1 + 1) * colW,
                  top: 0,
                  bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: review ? p.correctTint : p.sparkTint,
                      borderRadius: BorderRadius.circular(12),
                      border: review
                          ? Border.all(color: p.correct, width: 2)
                          : null,
                    ),
                  ),
                ),
              if (q.prices)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  height: lineH,
                  child: IgnorePointer(
                    child: CustomPaint(
                      painter: _PricePainter(
                        values: q.values,
                        colW: colW,
                        buy: review ? bs : s.start,
                        sell: review ? be : s.end,
                        wrongBuy: review && !s.lastCorrect ? s.start : null,
                        wrongSell: review && !s.lastCorrect ? s.end : null,
                        ink: p.ink,
                        surface: p.surface,
                        mark: review ? p.correct : p.spark,
                        onMark: review ? p.onCorrect : p.onSpark,
                        miss: p.miss,
                      ),
                    ),
                  ),
                ),
              Row(children: [for (var i = 0; i < n; i++) column(i, colW)]),
            ],
          );
        },
      ),
    );
  }
}

class _PricePainter extends CustomPainter {
  _PricePainter({
    required this.values,
    required this.colW,
    required this.buy,
    required this.sell,
    required this.wrongBuy,
    required this.wrongSell,
    required this.ink,
    required this.surface,
    required this.mark,
    required this.onMark,
    required this.miss,
  });

  final List<int> values;
  final double colW;
  final int? buy, sell, wrongBuy, wrongSell;
  final Color ink, surface, mark, onMark, miss;

  @override
  void paint(Canvas canvas, Size size) {
    final lo = values.reduce(min) - 2, hi = values.reduce(max) + 2;
    const top = 24.0, bottom = 14.0;
    Offset at(int i) => Offset(
      colW * (i + 0.5),
      top + (hi - values[i]) * (size.height - top - bottom) / (hi - lo),
    );
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    void text(String t, Offset c, Color colour, {double size = 11}) {
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: lucidText(
            size: size,
            weight: 700,
            display: true,
            color: colour,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    for (var i = 0; i < values.length; i++) {
      final c = at(i);
      final tag = i == buy ? 'B' : (i == sell ? 'S' : null);
      final wrong = i == wrongBuy || i == wrongSell;
      if (tag != null) {
        canvas.drawCircle(c, 11, Paint()..color = mark);
        text(tag, c, onMark, size: 12);
      } else {
        canvas.drawCircle(c, 5, Paint()..color = surface);
        canvas.drawCircle(
          c,
          5,
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      }
      if (wrong && tag == null) {
        canvas.drawCircle(
          c,
          10,
          Paint()
            ..color = miss
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5,
        );
      }
      text('${values[i]}', c - Offset(0, tag != null || wrong ? 19 : 13), ink);
    }
  }

  @override
  bool shouldRepaint(_PricePainter old) =>
      old.buy != buy ||
      old.sell != sell ||
      old.wrongBuy != wrongBuy ||
      old.wrongSell != wrongSell ||
      old.colW != colW ||
      old.ink != ink;
}

class _Working extends StatelessWidget {
  const _Working({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    return Container(
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
                    style: lucidText(size: d.body, color: p.ink, height: 1.45),
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
