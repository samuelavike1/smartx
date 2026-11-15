import 'dart:math';

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
import 'vol_controller.dart';
import 'vol_lab_game.dart';
import 'vol_puzzle.dart';

// Built from the "Vol Lab · digital", "· barrier" and "· review" artboards.

class VolScreen extends ConsumerWidget {
  const VolScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(volSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const VolLabGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(volSessionProvider),
                  onTrySimilar: ref
                      .read(volSessionProvider.notifier)
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

/// An option or answer: numbers in the display face, words smaller and
/// allowed to wrap.
class _Answer extends StatelessWidget {
  const _Answer(this.text, {required this.numeric, required this.size});

  final String text;
  final bool numeric;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    if (!numeric) {
      return Text(
        text,
        textAlign: TextAlign.center,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: lucidText(
          size: size * 0.7,
          weight: 600,
          color: p.ink,
          height: 1.2,
        ),
      );
    }
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(
        text,
        style: lucidText(size: size, weight: 700, display: true, color: p.ink),
      ),
    );
  }
}

class _RoundView extends ConsumerWidget {
  const _RoundView({super.key, required this.state});

  final VolSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(volSessionProvider.notifier);
    final q = state.question;

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    Widget option(int i) => PressScale(
      key: ValueKey('vol-$i'),
      semanticLabel: 'Answer ${q.options[i]}',
      onTap: () => choose(i),
      child: Container(
        constraints: BoxConstraints(minHeight: d.compact ? 50 : 58),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
          border: Border.all(color: p.line, width: 1.5),
        ),
        child: _Answer(
          q.options[i],
          numeric: q.numeric,
          size: d.compact ? 20 : 24,
        ),
      ),
    );

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
          game: const VolLabGame(),
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

/// The card's maths, side by side where it fits, shrinking if it must.
class _Lines extends StatelessWidget {
  const _Lines({required this.lines, required this.size});

  final List<String> lines;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: size * 0.8,
      runSpacing: 6,
      children: [
        for (final l in lines)
          FittedBox(
            fit: BoxFit.scaleDown,
            child: MathText(l, size: size, color: p.ink),
          ),
      ],
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.question});

  final VolQuestion question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = question;
    final scene = q.scene;
    final pic = scene.pictureOnCard ? scene.picture : null;
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
              if (scene.lines.isNotEmpty) ...[
                const SizedBox(height: 10),
                _Lines(lines: scene.lines, size: d.compact ? 19 : 22),
              ],
              if (pic != null) ...[
                const SizedBox(height: 10),
                VolChart(picture: pic, height: d.compact ? 92 : 108),
              ],
              const SizedBox(height: 10),
              Text(
                scene.caption.toUpperCase(),
                textAlign: TextAlign.center,
                style: lucidLabel(p.muted, size: d.label),
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

// ---- the picture ------------------------------------------------------------

/// A payoff chart, stock paths, a price curve or a bell curve. Spark orange
/// marks the unknown; on the review, [reveal] replaces each "?".
class VolChart extends StatelessWidget {
  const VolChart({
    super.key,
    required this.picture,
    required this.height,
    this.reveal,
  });

  final VolPicture picture;
  final double height;
  final String? reveal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: picture.title,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChartPainter(
            picture: picture,
            reveal: reveal,
            ink: p.ink,
            muted: p.muted,
            axis: p.lineStrong,
            spark: p.spark,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.picture,
    required this.reveal,
    required this.ink,
    required this.muted,
    required this.axis,
    required this.spark,
  });

  final VolPicture picture;
  final String? reveal;
  final Color ink, muted, axis, spark;

  String _label(String s) => s == '?' && reveal != null ? reveal! : s;

  @override
  void paint(Canvas canvas, Size size) {
    if (picture.visual == VolVisual.bell) {
      _bell(canvas, size);
      return;
    }
    final pic = picture;
    final pts = [
      ...pic.line,
      ...pic.ghost,
      for (final m in pic.marks) (m.x, m.y),
    ];
    var minX = pts.map((e) => e.$1).reduce(min);
    var maxX = pts.map((e) => e.$1).reduce(max);
    var minY = pts.map((e) => e.$2).reduce(min);
    var maxY = pts.map((e) => e.$2).reduce(max);
    for (final (x, _) in pic.ticks) {
      minX = min(minX, x);
      maxX = max(maxX, x);
    }
    if (pic.barrierX case final b?) {
      minX = min(minX, b);
      maxX = max(maxX, b);
    }
    if (pic.barrierY case final b?) {
      minY = min(minY, b);
      maxY = max(maxY, b);
    }
    final path = pic.visual == VolVisual.path;
    if (!path) minY = min(minY, 0);
    if (maxY - minY < 1e-9) maxY = minY + 1;
    if (maxX - minX < 1e-9) maxX = minX + 1;
    // Paths keep room on the left for today's price, beside the start.
    final left = path ? 38.0 : 10.0;
    const right = 10.0, top = 18.0;
    final bottom = path ? 14.0 : 18.0;
    final w = size.width - left - right, h = size.height - top - bottom;
    Offset at(double x, double y) => Offset(
      left + (x - minX) / (maxX - minX) * w,
      top + (maxY - y) / (maxY - minY) * h,
    );

    final base = at(minX, path ? minY : 0).dy;
    if (!path) {
      canvas.drawLine(
        Offset(left, base),
        Offset(size.width - right, base),
        Paint()
          ..color = axis
          ..strokeWidth = 2,
      );
    }

    final dashPen = Paint()
      ..color = ink
      ..strokeWidth = 1.5;
    if (pic.barrierX case final b?) {
      final x = at(b, 0).dx;
      _dashed(canvas, Offset(x, base), Offset(x, top - 6), dashPen);
      if (pic.barrierLabel case final l?) {
        _text(canvas, l, Offset(x + 5, top - 16), muted, align: TextAlign.left);
      }
    }
    if (pic.barrierY case final b?) {
      final y = at(minX, b).dy;
      _dashed(canvas, Offset(left, y), Offset(size.width - right, y), dashPen);
      if (pic.barrierLabel case final l?) {
        // Below a barrier at the bottom, above one at the top.
        final below = b <= minY + 1e-9;
        _text(
          canvas,
          l,
          Offset(size.width - right, below ? y + 1 : y - 14),
          muted,
          align: TextAlign.right,
          size: 10,
        );
      }
    }

    Path poly(List<(double, double)> line) {
      final o = at(line.first.$1, line.first.$2);
      final out = Path()..moveTo(o.dx, o.dy);
      for (final (x, y) in line.skip(1)) {
        final q = at(x, y);
        out.lineTo(q.dx, q.dy);
      }
      return out;
    }

    if (pic.ghost.isNotEmpty) {
      final pen = Paint()
        ..color = pic.sparkLine ? muted : spark
        ..strokeWidth = 2;
      for (var i = 0; i + 1 < pic.ghost.length; i++) {
        final a = pic.ghost[i], b = pic.ghost[i + 1];
        _dashed(canvas, at(a.$1, a.$2), at(b.$1, b.$2), pen);
      }
    }
    if (pic.line.isNotEmpty) {
      canvas.drawPath(
        poly(pic.line),
        Paint()
          ..color = pic.sparkLine ? spark : ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = pic.sparkLine ? 3 : 2.5
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    // Where a path first touches its barrier.
    if (path && pic.barrierY != null) {
      for (final (x, y) in pic.line) {
        if ((y - pic.barrierY!).abs() < 1e-6) {
          canvas.drawCircle(at(x, y), 4.5, Paint()..color = spark);
          break;
        }
      }
    }

    for (final m in pic.marks) {
      final o = at(m.x, m.y);
      final color = m.unknown ? spark : ink;
      canvas.drawCircle(o, m.unknown ? 5.5 : 4.5, Paint()..color = color);
      final label = _label(m.label);
      if (path) {
        _text(
          canvas,
          label,
          Offset(o.dx - 8, o.dy - 7),
          color,
          bold: true,
          align: TextAlign.right,
        );
        continue;
      }
      // Keep the label inside the chart.
      final align = o.dx > size.width - 30
          ? TextAlign.right
          : (o.dx < 30 ? TextAlign.left : TextAlign.center);
      final dx = switch (align) {
        TextAlign.right => 4.0,
        TextAlign.left => -4.0,
        _ => 0.0,
      };
      _text(
        canvas,
        label,
        Offset(o.dx + dx, max(0, o.dy - 18)),
        color,
        bold: true,
        align: align,
      );
    }

    final tickY = base + 3;
    for (final (x, l) in pic.ticks) {
      final o = at(x, 0);
      _text(
        canvas,
        _label(l),
        Offset(o.dx, tickY),
        l == '?' ? spark : muted,
        size: 10,
        bold: l == '?',
      );
    }
    if (pic.axis.isNotEmpty && !path) {
      // In whichever bottom corner has no tick.
      final xs = [for (final (x, _) in pic.ticks) at(x, 0).dx];
      final rightFree = xs.every((x) => x < size.width * 0.62);
      final leftFree = xs.every((x) => x > size.width * 0.38);
      if (rightFree || leftFree) {
        _text(
          canvas,
          pic.axis,
          Offset(rightFree ? size.width - right : left, tickY),
          muted,
          size: 10,
          align: rightFree ? TextAlign.right : TextAlign.left,
        );
      }
    }
  }

  void _bell(Canvas canvas, Size size) {
    final pic = picture;
    const lo = -3.2, hi = 3.2, top = 8.0, bottom = 16.0;
    final cut = pic.cut.clamp(lo, hi);
    final base = size.height - bottom;
    double px(double z) => (z - lo) / (hi - lo) * size.width;
    double py(double z) => base - exp(-z * z / 2) * (base - top);

    final area = Path()..moveTo(px(lo), base);
    final curve = Path()..moveTo(px(lo), py(lo));
    for (var i = 0; i <= 128; i++) {
      final z = lo + (hi - lo) * i / 128;
      curve.lineTo(px(z), py(z));
      if (z <= cut) area.lineTo(px(z), py(z));
    }
    area
      ..lineTo(px(cut), py(cut))
      ..lineTo(px(cut), base)
      ..close();
    canvas.drawPath(area, Paint()..color = spark);
    canvas.drawPath(
      curve,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      Offset(0, base),
      Offset(size.width, base),
      Paint()
        ..color = axis
        ..strokeWidth = 2,
    );
    _dashed(
      canvas,
      Offset(px(cut), base),
      Offset(px(cut), top),
      Paint()
        ..color = ink
        ..strokeWidth = 1.5,
    );
    _text(canvas, pic.cutLabel, Offset(px(cut), base + 2), muted, size: 10);
    // The area's name, just left of the cut where the shading is.
    final label = _label(pic.areaLabel);
    final roomy = px(cut) > size.width * 0.3;
    _text(
      canvas,
      label,
      roomy
          ? Offset(px(cut) - 6, (base + py(cut)) / 2 - 7)
          : Offset(px(cut) + 6, (base + top) / 2 - 7),
      ink,
      bold: true,
      align: roomy ? TextAlign.right : TextAlign.left,
    );
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.picture != picture ||
      old.reveal != reveal ||
      old.ink != ink ||
      old.spark != spark;
}

void _text(
  Canvas canvas,
  String t,
  Offset at,
  Color c, {
  bool bold = false,
  TextAlign align = TextAlign.center,
  double size = 11,
}) {
  final tp = TextPainter(
    text: TextSpan(
      text: t,
      style: lucidText(
        size: size,
        weight: bold ? 700 : 400,
        display: bold,
        color: c,
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

void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
  final len = (b - a).distance;
  if (len == 0) return;
  final dir = (b - a) / len;
  for (var t = 0.0; t < len; t += 9) {
    canvas.drawLine(a + dir * t, a + dir * min(t + 5, len), paint);
  }
}

// ---- the review -------------------------------------------------------------

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final VolSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final picked = q.options[state.picked!];
    final right = picked == q.answer;
    final pic = q.scene.picture;

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
          _Answer(value, numeric: q.numeric, size: 22),
          const SizedBox(height: 2),
          Text(
            label,
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

    final mine = tile(picked, 'Your answer', false);
    final best = tile(q.answer, right ? 'Your answer · right' : 'Right', true);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        _Chips(chips: q.scene.chips),
        const SizedBox(height: 10),
        Text(
          q.question,
          textAlign: TextAlign.center,
          style: lucidText(size: d.body, color: p.muted, height: 1.45),
        ),
        SizedBox(height: d.gapM),
        if (right)
          best
        else
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
        if (pic != null) ...[
          SizedBox(height: d.compact ? 10 : 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  pic.title,
                  style: lucidText(size: 14, weight: 600, color: p.ink),
                ),
                const SizedBox(height: 6),
                VolChart(
                  picture: pic,
                  height: d.compact ? 84 : 96,
                  reveal: q.numeric ? q.answer : null,
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: d.compact ? 10 : 14),
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
                          if (step.math case final m?)
                            Padding(
                              padding: const EdgeInsets.only(top: 4),
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: MathText(
                                  m,
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
