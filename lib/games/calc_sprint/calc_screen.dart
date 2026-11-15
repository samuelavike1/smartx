import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/math_text.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'calc_controller.dart';
import 'calc_puzzle.dart';
import 'calc_sprint_game.dart';

// Built from the "Calc Sprint · slope", "· area" and "· review" artboards.

/// Options this long (as plain text) get a row each.
bool calcWide(List<String> options) =>
    options.any((o) => mathPlain(o).length > 10);

class CalcScreen extends ConsumerWidget {
  const CalcScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(calcSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const CalcSprintGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(calcSessionProvider),
                  onTrySimilar: ref
                      .read(calcSessionProvider.notifier)
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

  final CalcSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(calcSessionProvider.notifier);
    final q = state.question;
    final wide = calcWide(q.options);

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    Widget option(int i) {
      final text = q.options[i];
      final near = q.notes[i];
      return PressScale(
        key: ValueKey('calc-$i'),
        semanticLabel: 'Answer ${mathPlain(text)}',
        onTap: () => choose(i),
        child: Container(
          constraints: BoxConstraints(
            minHeight: wide ? (d.compact ? 46 : 52) : (d.compact ? 50 : 58),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
            border: Border.all(color: p.line, width: 1.5),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: MathText(
                  text,
                  size: wide ? (d.compact ? 18 : 20) : (d.compact ? 20 : 23),
                  weight: 600,
                  color: p.ink,
                ),
              ),
              if (near != null)
                Text(
                  near,
                  style: lucidText(size: 11, weight: 500, color: p.muted),
                ),
            ],
          ),
        ),
      );
    }

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
          game: const CalcSprintGame(),
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
                if (wide)
                  for (var i = 0; i < 4; i++) ...[
                    if (i > 0) SizedBox(height: d.compact ? 8 : 10),
                    option(i),
                  ]
                else
                  for (var r = 0; r < 2; r++) ...[
                    if (r > 0) const SizedBox(height: 12),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: option(r * 2)),
                          const SizedBox(width: 12),
                          Expanded(child: option(r * 2 + 1)),
                        ],
                      ),
                    ),
                  ],
              ],
            ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.question});

  final CalcQuestion question;

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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: MathText(
                  q.card,
                  size: d.compact ? 24 : 30,
                  color: p.ink,
                ),
              ),
              if (q.graph != null) ...[
                SizedBox(height: d.compact ? 8 : 10),
                CalcGraphView(graph: q.graph!, height: d.compact ? 88 : 112),
              ],
              const SizedBox(height: 10),
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
          q.question,
          textAlign: TextAlign.center,
          style: lucidText(
            size: d.compact ? 18 : 21,
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

/// The function's graph: the curve, and in spark orange the point and its
/// tangent, where an estimate lands, or the shaded area.
class CalcGraphView extends StatelessWidget {
  const CalcGraphView({super.key, required this.graph, required this.height});

  final CalcGraph graph;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _GraphPainter(
          graph: graph,
          ink: p.ink,
          muted: p.muted,
          rule: p.lineStrong,
          spark: p.spark,
        ),
      ),
    );
  }
}

class _GraphPainter extends CustomPainter {
  _GraphPainter({
    required this.graph,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.spark,
  });

  final CalcGraph graph;
  final Color ink, muted, rule, spark;

  @override
  void paint(Canvas canvas, Size size) {
    final g = graph;
    const padX = 8.0, padTop = 6.0, labelH = 16.0;
    final w = size.width - 2 * padX;
    final h = size.height - padTop - labelH;
    const n = 120;
    final xs = [for (var i = 0; i <= n; i++) g.lo + (g.hi - g.lo) * i / n];
    final ys = [for (final x in xs) g.f(x)];
    final finite = ys.where((y) => y.isFinite).toList();
    if (finite.isEmpty) return;
    var bottom = finite.reduce((a, b) => a < b ? a : b);
    var top = finite.reduce((a, b) => a > b ? a : b);
    if (g.shaded) {
      if (bottom > 0) bottom = 0;
      if (top < 0) top = 0;
    }
    if (top - bottom < 1e-9) {
      top += 1;
      bottom -= 1;
    }
    final pad = (top - bottom) * 0.08;
    top += pad;
    bottom -= pad;
    double px(double x) => padX + (x - g.lo) / (g.hi - g.lo) * w;
    double py(double y) => padTop + (top - y) / (top - bottom) * h;

    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, padTop + h + 1));

    final axis = Paint()
      ..color = rule
      ..strokeWidth = 1.5;
    if (bottom <= 0 && top >= 0) {
      canvas.drawLine(Offset(padX, py(0)), Offset(padX + w, py(0)), axis);
    }
    if (g.lo <= 0 && g.hi >= 0) {
      canvas.drawLine(Offset(px(0), padTop), Offset(px(0), padTop + h), axis);
    }

    if (g.shaded) {
      final from = g.from!, to = g.to!;
      final area = Path()..moveTo(px(from), py(0));
      const m = 60;
      for (var i = 0; i <= m; i++) {
        final x = from + (to - from) * i / m;
        area.lineTo(px(x), py(g.f(x)));
      }
      area
        ..lineTo(px(to), py(0))
        ..close();
      canvas.drawPath(area, Paint()..color = spark.withValues(alpha: 0.28));
      final edge = Paint()
        ..color = spark
        ..strokeWidth = 2;
      for (final x in [from, to]) {
        canvas.drawLine(Offset(px(x), py(0)), Offset(px(x), py(g.f(x))), edge);
      }
    }

    final curve = Path();
    var started = false;
    for (var i = 0; i <= n; i++) {
      if (!ys[i].isFinite) {
        started = false;
        continue;
      }
      final o = Offset(px(xs[i]), py(ys[i]));
      if (started) {
        curve.lineTo(o.dx, o.dy);
      } else {
        curve.moveTo(o.dx, o.dy);
        started = true;
      }
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    final at = g.at;
    if (at != null) {
      final y0 = g.f(at);
      final slope = g.slope;
      if (slope != null) {
        canvas.drawLine(
          Offset(px(g.lo), py(y0 + slope * (g.lo - at))),
          Offset(px(g.hi), py(y0 + slope * (g.hi - at))),
          Paint()
            ..color = spark
            ..strokeWidth = 2
            ..strokeCap = StrokeCap.round,
        );
      }
      canvas.drawCircle(Offset(px(at), py(y0)), 5.5, Paint()..color = spark);
    }
    final target = g.target;
    if (target != null) {
      canvas.drawCircle(
        Offset(px(target), py(g.f(target))),
        4.5,
        Paint()
          ..color = spark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    canvas.restore();

    final small = lucidText(size: 11, weight: 500, color: muted);
    for (final MapEntry(key: x, value: label) in g.labels.entries) {
      final tp = TextPainter(
        text: TextSpan(text: label, style: small),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = px(x).clamp(tp.width / 2, size.width - tp.width / 2);
      tp.paint(
        canvas,
        Offset(cx - tp.width / 2, size.height - labelH / 2 - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_GraphPainter old) =>
      old.graph != graph || old.ink != ink || old.spark != spark;
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final CalcSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final pick = state.picked!;
    final picked = q.options[pick];
    final right = picked == q.answer;
    final wide = calcWide(q.options);

    Widget tile(String value, String? near, String label, bool good) =>
        Container(
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
              FittedBox(
                fit: BoxFit.scaleDown,
                child: MathText(value, size: 20, weight: 600, color: p.ink),
              ),
              const SizedBox(height: 2),
              Text(
                near == null ? label : '$label · $near',
                textAlign: TextAlign.center,
                style: lucidText(
                  size: 12,
                  weight: 600,
                  color: good ? p.correctText : p.missText,
                ),
              ),
            ],
          ),
        );

    final mine = tile(picked, q.notes[pick], 'Your answer', false);
    final best = tile(
      q.answer,
      q.notes[q.answerIndex],
      right ? 'Your answer · right' : 'Right',
      true,
    );

    final graph = q.reviewGraph;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: MathText(q.card, size: 22, color: p.ink),
        ),
        const SizedBox(height: 8),
        Text(
          q.question,
          textAlign: TextAlign.center,
          style: lucidText(size: d.body, color: p.muted, height: 1.45),
        ),
        SizedBox(height: d.gapM),
        if (right)
          best
        else if (wide) ...[
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
        if (graph != null) ...[
          SizedBox(height: d.gapM),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 8),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'The graph',
                      style: lucidText(size: 14, weight: 600, color: p.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        q.caption.toLowerCase(),
                        textAlign: TextAlign.end,
                        style: lucidText(size: 12, color: p.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                CalcGraphView(graph: graph, height: d.compact ? 80 : 96),
              ],
            ),
          ),
        ],
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
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step.text,
                            style: lucidText(
                              size: d.body,
                              color: p.ink,
                              height: 1.45,
                            ),
                          ),
                          if (step.math != null)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: MathText(
                                  step.math!,
                                  size: d.body + 1,
                                  color: p.ink,
                                ),
                              ),
                            ),
                        ],
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
