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
import 'bond_controller.dart';
import 'bond_desk_game.dart';
import 'bond_puzzle.dart';

// Built from the "Bond Desk · timeline", "· duration curve" and "· review"
// artboards.

class BondScreen extends ConsumerWidget {
  const BondScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(bondSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const BondDeskGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(bondSessionProvider),
                  onTrySimilar: ref
                      .read(bondSessionProvider.notifier)
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

/// "about $96.53" splits into a small "about" over the number.
(String?, String) _split(String label) =>
    label.startsWith('about ') ? ('about', label.substring(6)) : (null, label);

class _RoundView extends ConsumerWidget {
  const _RoundView({super.key, required this.state});

  final BondSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(bondSessionProvider.notifier);
    final q = state.question;
    final words = q.words;

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    Widget option(int i, String text) {
      final (near, body) = _split(text);
      return PressScale(
        key: ValueKey('bond-$i'),
        semanticLabel: 'Answer $text',
        onTap: () => choose(i),
        child: Container(
          constraints: BoxConstraints(
            minHeight: words ? (d.compact ? 42 : 52) : (d.compact ? 50 : 58),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          alignment: words ? Alignment.centerLeft : Alignment.center,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
            border: Border.all(color: p.line, width: 1.5),
          ),
          child: words
              ? Text(
                  text,
                  style: lucidText(size: 15, weight: 600, color: p.ink),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (near != null)
                      Text(
                        near,
                        style: lucidText(size: 11, weight: 500, color: p.muted),
                      ),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        body,
                        style: lucidText(
                          size: d.compact ? 20 : 24,
                          weight: 700,
                          display: true,
                          color: p.ink,
                        ),
                      ),
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
          game: const BondDeskGame(),
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
                    if (i > 0) SizedBox(height: d.compact ? 8 : 10),
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

  final BondQuestion question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = question;
    final scene = q.scene;
    final picture = switch (scene.visual) {
      BondVisual.timeline => CashTimeline(
        scene: scene,
        height: scene.flows.any((f) => f.today != null)
            ? (d.compact ? 122 : 136)
            : (d.compact ? 104 : 120),
      ),
      BondVisual.curve => YieldCurve(
        scene: scene,
        height: d.compact ? 108 : 128,
      ),
      BondVisual.portfolio => DurationLine(
        scene: scene,
        height: d.compact ? 92 : 104,
      ),
      BondVisual.none => null,
    };
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
              _Chips(chips: scene.chips),
              if (picture != null) ...[
                SizedBox(height: d.compact ? 8 : 12),
                picture,
              ],
              if (scene.caption.isNotEmpty) ...[
                const SizedBox(height: 10),
                Text(
                  scene.caption.toUpperCase(),
                  textAlign: TextAlign.center,
                  style: lucidLabel(p.muted),
                ),
              ],
            ],
          ),
        ),
        SizedBox(height: d.gapL),
        Text(
          q.question,
          textAlign: TextAlign.center,
          style: lucidText(
            size: d.compact ? 18 : 22,
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

void _label(
  Canvas canvas,
  String text,
  Offset at,
  Color color, {
  double size = 11,
  bool bold = false,
  TextAlign align = TextAlign.center,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: text,
      style: lucidText(
        size: size,
        weight: bold ? 700 : 400,
        display: bold,
        color: color,
      ),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final dx = switch (align) {
    TextAlign.left => 0.0,
    TextAlign.right => tp.width,
    _ => tp.width / 2,
  };
  tp.paint(canvas, at - Offset(dx, 0));
}

void _mark(Canvas canvas, Offset c, double r, Color fill, Color text) {
  canvas.drawCircle(c, r, Paint()..color = fill);
  final tp = TextPainter(
    text: TextSpan(
      text: '?',
      style: lucidText(size: r + 1, weight: 700, display: true, color: text),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
}

/// Years along a line from today, a bar for each payment (an outline for
/// money paid in), and a spark-orange "?" on the unknown.
class CashTimeline extends StatelessWidget {
  const CashTimeline({super.key, required this.scene, required this.height});

  final BondScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pays = [
      for (final f in scene.flows)
        '${f.year == 0 ? 'today' : 'year ${f.year}'} '
            '${f.paid ? 'you pay' : 'it pays'} ${cash(f.amount)}',
    ].join(', ');
    return Semantics(
      label: 'Timeline over ${scene.years} years: $pays.',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _TimelinePainter(
            scene: scene,
            ink: p.ink,
            line: p.lineStrong,
            muted: p.muted,
            spark: p.spark,
            onSpark: p.onSpark,
          ),
        ),
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.scene,
    required this.ink,
    required this.line,
    required this.muted,
    required this.spark,
    required this.onSpark,
  });

  final BondScene scene;
  final Color ink, line, muted, spark, onSpark;

  @override
  void paint(Canvas canvas, Size size) {
    final n = max(scene.years, 1);
    final withToday = scene.flows.any((f) => f.today != null);
    const padX = 26.0;
    final axis = size.height - (withToday ? 40 : 24);
    double x(int year) => padX + year / n * (size.width - 2 * padX);
    final sparse = n > 6;

    canvas.drawLine(
      Offset(8, axis),
      Offset(size.width - 8, axis),
      Paint()
        ..color = line
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    for (var t = 0; t <= n; t++) {
      if (sparse && t != 0 && t != n) continue;
      canvas.drawCircle(Offset(x(t), axis), 4, Paint()..color = line);
      _label(canvas, t == 0 ? 'Today' : 'Yr $t', Offset(x(t), axis + 6), muted);
    }

    final top = scene.flows.fold(0.0, (m, f) => max(m, f.amount.value));
    final room = axis - 6 - 18;
    for (final f in scene.flows) {
      final h = max(10.0, room * 0.85 * f.amount.value / top);
      final r = RRect.fromRectAndRadius(
        Rect.fromLTWH(x(f.year) - 11, axis - 5 - h, 22, h),
        const Radius.circular(6),
      );
      if (f.paid) {
        canvas.drawRRect(
          r.deflate(1),
          Paint()
            ..color = ink
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
      } else {
        canvas.drawRRect(r, Paint()..color = ink);
      }
      _label(
        canvas,
        cash(f.amount),
        Offset(x(f.year), axis - 5 - h - 16),
        ink,
        size: 12,
        bold: true,
      );
      final now = f.today;
      if (now != null) {
        _label(
          canvas,
          'now ${cash(now)}',
          Offset(x(f.year), axis + 21),
          ink,
          bold: true,
        );
      }
    }

    final at = scene.unknownAt;
    if (at != null) {
      _mark(canvas, Offset(x(at), axis - 22), 13, spark, onSpark);
    }
    final from = scene.spanFrom, to = scene.spanTo;
    if (from != null && to != null) {
      canvas.drawLine(
        Offset(x(from), axis),
        Offset(x(to), axis),
        Paint()
          ..color = spark
          ..strokeWidth = 4
          ..strokeCap = StrokeCap.round,
      );
      _mark(
        canvas,
        Offset((x(from) + x(to)) / 2, axis - 22),
        13,
        spark,
        onSpark,
      );
    }
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.scene != scene || old.ink != ink;
}

/// Price against yield: today's point, its tangent (the duration line), and
/// the move to a spark-orange "?".
class YieldCurve extends StatelessWidget {
  const YieldCurve({super.key, required this.scene, required this.height});

  final BondScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label:
          'Price against yield. Today ${cash(scene.price!)}; yields '
          '${scene.yieldUp ? 'rise' : 'fall'} ${scene.moveLabel}.',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _CurvePainter(
            scene: scene,
            ink: p.ink,
            line: p.lineStrong,
            muted: p.muted,
            spark: p.spark,
            onSpark: p.onSpark,
          ),
        ),
      ),
    );
  }
}

class _CurvePainter extends CustomPainter {
  _CurvePainter({
    required this.scene,
    required this.ink,
    required this.line,
    required this.muted,
    required this.spark,
    required this.onSpark,
  });

  final BondScene scene;
  final Color ink, line, muted, spark, onSpark;

  @override
  void paint(Canvas canvas, Size size) {
    const x0 = 14.0;
    final x1 = size.width - 6;
    final base = size.height - 26;
    final span = x1 - x0;
    final drop = base - 20;
    double py(double x) => base - drop * exp(-(x - x0) / (span * 0.6));
    final axis = Paint()
      ..color = line
      ..strokeWidth = 2;
    canvas.drawLine(Offset(x0, base), Offset(x1, base), axis);
    canvas.drawLine(Offset(x0, 4), Offset(x0, base), axis);
    _label(canvas, 'price', Offset(x0 + 6, 2), muted, align: TextAlign.left);
    _label(
      canvas,
      'yield',
      Offset(x1, base + 8),
      muted,
      align: TextAlign.right,
    );

    final path = Path()..moveTo(x0, py(x0));
    for (var x = x0; x <= x1; x += 4) {
      path.lineTo(x, py(x));
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeJoin = StrokeJoin.round,
    );

    final cx = x0 + span * (scene.yieldUp ? 0.38 : 0.62);
    final nx = x0 + span * (scene.yieldUp ? 0.62 : 0.38);
    final cy = py(cx);
    final slope = (base - cy) / (span * 0.6);
    double tangent(double x) => cy + slope * (x - cx);
    final dash = Paint()
      ..color = muted
      ..strokeWidth = 1.5;
    final a = min(cx, nx) - span * 0.18, b = max(cx, nx) + span * 0.1;
    for (var x = a; x < b; x += 8) {
      canvas.drawLine(
        Offset(x, tangent(x)),
        Offset(x + 4, tangent(x + 4)),
        dash,
      );
    }
    void vertical(double x, double fromY, Color c) {
      final paint = Paint()
        ..color = c
        ..strokeWidth = 1.5;
      for (var y = fromY; y < base; y += 6) {
        canvas.drawLine(Offset(x, y), Offset(x, min(y + 3, base)), paint);
      }
    }

    vertical(cx, cy, line);
    vertical(nx, tangent(nx), spark);

    // The move along the yield axis.
    final arrow = Paint()
      ..color = spark
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    final ay = base + 8;
    final dir = nx > cx ? 1.0 : -1.0;
    canvas.drawLine(Offset(cx + 4 * dir, ay), Offset(nx - 4 * dir, ay), arrow);
    canvas.drawPath(
      Path()
        ..moveTo(nx - 9 * dir, ay - 5)
        ..lineTo(nx - 4 * dir, ay)
        ..lineTo(nx - 9 * dir, ay + 5),
      arrow,
    );
    _label(
      canvas,
      scene.moveLabel,
      Offset((cx + nx) / 2, ay + 4),
      ink,
      size: 12,
      bold: true,
    );

    canvas.drawCircle(Offset(cx, cy), 6, Paint()..color = ink);
    _label(
      canvas,
      cash(scene.price!),
      Offset(cx + 8, cy - 22),
      ink,
      size: 13,
      bold: true,
      align: TextAlign.left,
    );
    _mark(canvas, Offset(nx, tangent(nx)), 12, spark, onSpark);
  }

  @override
  bool shouldRepaint(_CurvePainter old) => old.scene != scene || old.ink != ink;
}

/// Two bonds on a duration line, each dot sized by the money in it.
class DurationLine extends StatelessWidget {
  const DurationLine({super.key, required this.scene, required this.height});

  final BondScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: [
        for (final h in scene.holdings)
          'Bond ${h.name}: worth ${cash(h.value)}, duration '
              '${decimal(h.duration)} years',
      ].join('. '),
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _DurationPainter(
            scene: scene,
            ink: p.ink,
            onInk: p.onInk,
            line: p.lineStrong,
            muted: p.muted,
          ),
        ),
      ),
    );
  }
}

class _DurationPainter extends CustomPainter {
  _DurationPainter({
    required this.scene,
    required this.ink,
    required this.onInk,
    required this.line,
    required this.muted,
  });

  final BondScene scene;
  final Color ink, onInk, line, muted;

  @override
  void paint(Canvas canvas, Size size) {
    final hs = scene.holdings;
    final most = hs.fold(0.0, (m, h) => max(m, h.duration.value)).ceil() + 1;
    const padX = 14.0;
    final axis = size.height - 24;
    double x(double d) => padX + d / most * (size.width - 2 * padX);
    canvas.drawLine(
      Offset(padX - 6, axis),
      Offset(size.width - padX + 6, axis),
      Paint()
        ..color = line
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    final every = most > 8 ? 2 : 1;
    for (var t = 0; t <= most; t += every) {
      canvas.drawCircle(
        Offset(x(t.toDouble()), axis),
        3,
        Paint()..color = line,
      );
      _label(canvas, '$t', Offset(x(t.toDouble()), axis + 6), muted);
    }
    final total = hs.fold(0.0, (s, h) => s + h.value.value);
    final gap = (size.width - 2 * padX) / most;
    for (final h in hs) {
      final r = min(gap * 0.48, 9 + 12 * sqrt(h.value.value / total));
      final c = Offset(x(h.duration.value), axis - r - 4);
      canvas.drawCircle(c, r, Paint()..color = ink);
      final tp = TextPainter(
        text: TextSpan(
          text: h.name,
          style: lucidText(size: 12, weight: 700, display: true, color: onInk),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
      _label(
        canvas,
        cash(h.value),
        Offset(c.dx, c.dy - r - 16),
        ink,
        size: 12,
        bold: true,
      );
    }
  }

  @override
  bool shouldRepaint(_DurationPainter old) =>
      old.scene != scene || old.ink != ink;
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final BondSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final picked = q.options[state.picked!];
    final right = picked == q.answer;
    final words = q.words;

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
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              textAlign: TextAlign.center,
              style: lucidText(
                size: words ? 15 : 22,
                weight: 700,
                display: !words,
                color: p.ink,
              ),
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
