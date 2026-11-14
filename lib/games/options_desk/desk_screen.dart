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
import '../better_bet/bet_puzzle.dart' show money;
import '../odds_on/odds_math.dart';
import 'desk_controller.dart';
import 'desk_puzzle.dart';
import 'options_desk_game.dart';

// Built from the "Options Desk · payoff chart", "· one-step tree" and
// "· Greeks review" artboards.

class DeskScreen extends ConsumerWidget {
  const DeskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deskSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const OptionsDeskGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(deskSessionProvider),
                  onTrySimilar: ref
                      .read(deskSessionProvider.notifier)
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

  final DeskSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(deskSessionProvider.notifier);
    final q = state.question;
    final words = q.kind == DeskKind.concept;

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    Widget option(int i, String text) => PressScale(
      key: ValueKey('desk-$i'),
      semanticLabel: 'Answer $text',
      onTap: () => choose(i),
      child: Container(
        constraints: BoxConstraints(minHeight: d.compact ? 46 : 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: words ? Alignment.centerLeft : Alignment.center,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
          border: Border.all(color: p.line, width: 1.5),
        ),
        child: words
            ? Text(text, style: lucidText(size: 15, weight: 600, color: p.ink))
            : FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  text,
                  style: lucidText(
                    size: d.compact ? 20 : 24,
                    weight: 700,
                    display: true,
                    color: p.ink,
                  ),
                ),
              ),
      ),
    );

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
          game: const OptionsDeskGame(),
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
                  q.hint,
                  textAlign: TextAlign.center,
                  style: lucidText(size: d.small, color: p.muted),
                ),
                SizedBox(height: d.gapS),
                if (words)
                  for (final (i, o) in q.options.indexed) ...[
                    if (i > 0) const SizedBox(height: 10),
                    option(i, o),
                  ]
                else
                  for (var r = 0; r < 2; r++) ...[
                    if (r > 0) const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: option(r * 2, q.options[r * 2])),
                          const SizedBox(width: 12),
                          Expanded(
                            child: option(r * 2 + 1, q.options[r * 2 + 1]),
                          ),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
    );
  }
}

class _Chips extends StatelessWidget {
  const _Chips({required this.chips});

  final List<String> chips;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: [
        for (final c in chips)
          Container(
            height: 30,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: p.chip,
              borderRadius: BorderRadius.circular(999),
            ),
            // widthFactor 1: the chip hugs its text instead of stretching.
            child: Align(
              widthFactor: 1,
              child: Text(
                c,
                style: lucidText(size: 13, weight: 700, color: p.ink),
              ),
            ),
          ),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.question});

  final DeskQuestion question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = question;
    final scene = q.scene;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        if (scene.visual != DeskVisual.none) ...[
          Container(
            padding: EdgeInsets.symmetric(
              vertical: d.compact ? 14 : 18,
              horizontal: 16,
            ),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: p.line),
            ),
            child: Column(
              children: [
                _Chips(chips: scene.chips),
                if (scene.visual == DeskVisual.chart) ...[
                  const SizedBox(height: 12),
                  PayoffChart(scene: scene, height: d.compact ? 110 : 140),
                ],
                if (scene.visual == DeskVisual.tree) ...[
                  const SizedBox(height: 12),
                  PriceTree(scene: scene, height: d.compact ? 124 : 150),
                ],
                const SizedBox(height: 10),
                Text(scene.caption.toUpperCase(), style: lucidLabel(p.muted)),
              ],
            ),
          ),
          SizedBox(height: d.gapL),
        ],
        Text(
          q.question,
          textAlign: TextAlign.center,
          style: lucidText(
            size: d.compact ? 19 : 22,
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

/// Payoff or profit at expiry across stock prices: strikes dashed, the
/// stock at expiry in spark orange.
class PayoffChart extends StatelessWidget {
  const PayoffChart({super.key, required this.scene, required this.height});

  final DeskScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '${scene.caption} chart',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChartPainter(
            scene: scene,
            ink: p.ink,
            line: p.lineStrong,
            muted: p.muted,
            spark: p.spark,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.scene,
    required this.ink,
    required this.line,
    required this.muted,
    required this.spark,
  });

  final DeskScene scene;
  final Color ink, line, muted, spark;

  @override
  void paint(Canvas canvas, Size size) {
    final strikes = scene.legs.map((l) => l.strike.value).toList();
    final lo = max(0.0, strikes.reduce(min) - 20);
    final hi = strikes.reduce(max) + 20;
    // Values at the ends and at each strike: the line is straight between.
    final xs = {lo, hi, ...strikes}.toList()..sort();
    double v(double s) => scene.value(Frac((s * 100).round(), 100)).value;
    final vs = [for (final x in xs) v(x)];
    final top = max(vs.reduce(max), 1.0), bottom = min(vs.reduce(min), -1.0);
    const padX = 8.0, padTop = 18.0, padBottom = 18.0;
    double px(double s) =>
        padX + (s - lo) / (hi - lo) * (size.width - 2 * padX);
    double py(double val) =>
        padTop +
        (top - val) / (top - bottom) * (size.height - padTop - padBottom);

    void label(String t, Offset at, Color c, {bool bold = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: t,
          style: lucidText(
            size: 11,
            weight: bold ? 700 : 400,
            display: bold,
            color: c,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, at - Offset(tp.width / 2, 0));
    }

    final axis = Paint()
      ..color = line
      ..strokeWidth = 2;
    canvas.drawLine(
      Offset(padX, py(0)),
      Offset(size.width - padX, py(0)),
      axis,
    );
    final dash = Paint()
      ..color = line
      ..strokeWidth = 1.5;
    for (final k in strikes.toSet()) {
      final x = px(k);
      for (var y = padTop - 6; y < size.height - padBottom; y += 8) {
        canvas.drawLine(Offset(x, y), Offset(x, y + 4), dash);
      }
      label('strike ${k.round()}', Offset(x, size.height - 14), muted);
    }
    final path = Path()..moveTo(px(xs.first), py(vs.first));
    for (var i = 1; i < xs.length; i++) {
      path.lineTo(px(xs[i]), py(vs[i]));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );
    final s = scene.stock?.value;
    if (s != null) {
      final x = px(s);
      canvas.drawLine(
        Offset(x, padTop - 8),
        Offset(x, size.height - padBottom),
        Paint()
          ..color = spark
          ..strokeWidth = 2,
      );
      canvas.drawCircle(Offset(x, py(v(s))), 6, Paint()..color = spark);
      final right = x > size.width * 0.7;
      label(
        'stock ${s.round()}',
        Offset(right ? x - 34 : x + 34, 0),
        ink,
        bold: true,
      );
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) => old.scene != scene || old.ink != ink;
}

/// Today's price, then up or down at expiry with what the option pays.
class PriceTree extends StatelessWidget {
  const PriceTree({super.key, required this.scene, required this.height});

  final DeskScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final name = scene.chips.first.startsWith('Call') ? 'call' : 'put';
    Widget node(String price, String? sub, {bool today = false}) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: today ? p.ink : p.surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: p.ink, width: 2),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            price,
            style: lucidText(
              size: 15,
              weight: 700,
              display: true,
              color: today ? p.onInk : p.ink,
            ),
          ),
          if (sub != null)
            Text(sub, style: lucidText(size: 11, color: p.muted)),
        ],
      ),
    );
    return Semantics(
      label:
          'Today ${money(scene.s0!)}. At expiry ${money(scene.up!)}, the '
          '$name pays ${money(scene.payUp!)}; or ${money(scene.down!)}, it '
          'pays ${money(scene.payDown!)}.',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        child: Stack(
          children: [
            Positioned.fill(
              child: CustomPaint(painter: _TreeLines(p.lineStrong)),
            ),
            Align(
              alignment: const Alignment(-0.85, 0),
              child: node(money(scene.s0!), null, today: true),
            ),
            Align(
              alignment: const Alignment(0.8, -1),
              child: node(
                money(scene.up!),
                '$name pays ${money(scene.payUp!)}',
              ),
            ),
            Align(
              alignment: const Alignment(0.8, 1),
              child: node(
                money(scene.down!),
                '$name pays ${money(scene.payDown!)}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TreeLines extends CustomPainter {
  _TreeLines(this.colour);

  final Color colour;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = colour
      ..strokeWidth = 2.5;
    final from = Offset(size.width * 0.2, size.height / 2);
    canvas.drawLine(from, Offset(size.width * 0.72, size.height * 0.18), paint);
    canvas.drawLine(from, Offset(size.width * 0.72, size.height * 0.82), paint);
  }

  @override
  bool shouldRepaint(_TreeLines old) => old.colour != colour;
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final DeskSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final picked = q.options[state.picked!];
    final right = picked == q.answer;
    final words = q.kind == DeskKind.concept;

    Widget tile(String value, String label, bool good) => Container(
      constraints: BoxConstraints(minHeight: d.compact ? 58 : 64),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
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
              size: words ? 15 : 22,
              weight: 700,
              display: !words,
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
    );

    final mine = tile(picked, 'Your answer', false);
    final best = tile(q.answer, right ? 'Your answer · right' : 'Right', true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        if (q.scene.chips.isNotEmpty) ...[
          _Chips(chips: q.scene.chips),
          const SizedBox(height: 10),
        ],
        Text(
          q.question,
          textAlign: TextAlign.center,
          style: lucidText(size: d.body, color: p.muted, height: 1.45),
        ),
        SizedBox(height: d.gapM),
        if (right)
          best
        else if (words) ...[
          mine,
          const SizedBox(height: 10),
          best,
        ] else
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
        SizedBox(height: d.gapM),
      ],
    );
  }
}
