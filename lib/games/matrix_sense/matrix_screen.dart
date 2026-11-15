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
import 'matrix_controller.dart';
import 'matrix_puzzle.dart';
import 'matrix_sense_game.dart';

// Built from the "Matrix Sense · determinant", "· projection" and
// "· review" artboards.

class MatrixScreen extends ConsumerWidget {
  const MatrixScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(matrixSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const MatrixSenseGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(matrixSessionProvider),
                  onTrySimilar: ref
                      .read(matrixSessionProvider.notifier)
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

final _plainNumber = RegExp(r'^-?[0-9.]+$');

/// An option or answer: plain numbers in the display face, anything else
/// (fractions, vectors, matrices, combinations) as maths.
class _Answer extends StatelessWidget {
  const _Answer(this.source, {required this.size});

  final String source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget child = _plainNumber.hasMatch(source)
        ? Text(
            mathPlain(source),
            style: lucidText(
              size: size,
              weight: 700,
              display: true,
              color: p.ink,
            ),
          )
        : MathText(source, size: size * 0.8, color: p.ink, weight: 600);
    return FittedBox(fit: BoxFit.scaleDown, child: child);
  }
}

class _RoundView extends ConsumerWidget {
  const _RoundView({super.key, required this.state});

  final MatrixSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(matrixSessionProvider.notifier);
    final q = state.question;

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    Widget option(int i) {
      final text = q.options[i];
      return PressScale(
        key: ValueKey('matrix-$i'),
        semanticLabel: 'Answer ${mathPlain(text)}',
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
          child: _Answer(text, size: d.compact ? 20 : 24),
        ),
      );
    }

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
          game: const MatrixSenseGame(),
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

/// The question's matrices, side by side, shrinking to fit.
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
      spacing: size * 0.7,
      runSpacing: 8,
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

  final MatrixQuestion question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = question;
    final pic = q.scene.pictureOnCard ? q.scene.picture : null;
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
              _Lines(lines: q.scene.lines, size: d.compact ? 24 : 30),
              if (pic != null) ...[
                SizedBox(height: d.compact ? 6 : 10),
                MatrixPlane(picture: pic, height: d.compact ? 100 : 124),
              ],
              SizedBox(height: d.compact ? 8 : 10),
              Text(
                q.scene.caption.toUpperCase(),
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

/// A grid with the unit square (grey) and where the matrix sends it, or a
/// vector and its image; the image in spark orange.
class MatrixPlane extends StatelessWidget {
  const MatrixPlane({super.key, required this.picture, required this.height});

  final MatrixPicture picture;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _PlanePainter(
          picture: picture,
          ink: p.ink,
          muted: p.muted,
          grid: p.line,
          axis: p.lineStrong,
          spark: p.spark,
        ),
      ),
    );
  }
}

class _PlanePainter extends CustomPainter {
  _PlanePainter({
    required this.picture,
    required this.ink,
    required this.muted,
    required this.grid,
    required this.axis,
    required this.spark,
  });

  final MatrixPicture picture;
  final Color ink, muted, grid, axis, spark;

  @override
  void paint(Canvas canvas, Size size) {
    final v = picture.v;
    final List<List<int>> before, after;
    if (v == null) {
      before = const [
        [0, 0],
        [1, 0],
        [1, 1],
        [0, 1],
      ];
      after = [for (final pt in before) picture.apply(pt[0], pt[1])];
    } else {
      before = [v];
      after = [picture.apply(v[0], v[1])];
    }
    final all = [
      const [0, 0],
      ...before,
      ...after,
    ];
    const pad = 0.6;
    final minX = all.map((e) => e[0]).reduce(min) - pad;
    final maxX = all.map((e) => e[0]).reduce(max) + pad;
    final minY = all.map((e) => e[1]).reduce(min) - pad;
    final maxY = all.map((e) => e[1]).reduce(max) + pad;
    final unit = min(
      28.0,
      min(size.width / (maxX - minX), size.height / (maxY - minY)),
    );
    final left = (size.width - (maxX - minX) * unit) / 2;
    final top = (size.height - (maxY - minY) * unit) / 2;
    Offset at(num x, num y) =>
        Offset(left + (x - minX) * unit, top + (maxY - y) * unit);

    // The grid, if the squares are big enough to read.
    if (unit >= 7) {
      final pen = Paint()
        ..color = grid
        ..strokeWidth = 1;
      for (var x = minX.ceil(); x <= maxX.floor(); x++) {
        canvas.drawLine(at(x, minY), at(x, maxY), pen);
      }
      for (var y = minY.ceil(); y <= maxY.floor(); y++) {
        canvas.drawLine(at(minX, y), at(maxX, y), pen);
      }
    }
    final axes = Paint()
      ..color = axis
      ..strokeWidth = 2;
    canvas.drawLine(at(minX, 0), at(maxX, 0), axes);
    canvas.drawLine(at(0, minY), at(0, maxY), axes);

    if (v == null) {
      Path shape(List<List<int>> pts) {
        final path = Path()
          ..moveTo(at(pts[0][0], pts[0][1]).dx, at(pts[0][0], pts[0][1]).dy);
        for (final pt in pts.skip(1)) {
          final o = at(pt[0], pt[1]);
          path.lineTo(o.dx, o.dy);
        }
        return path..close();
      }

      final m = picture.m;
      final flat = m[0][0] * m[1][1] - m[0][1] * m[1][0] == 0;
      if (flat) {
        // Squashed onto a line: draw the line between the far ends.
        var best = (after[0], after[0]);
        var far = -1;
        for (final a in after) {
          for (final b in after) {
            final dd =
                (a[0] - b[0]) * (a[0] - b[0]) + (a[1] - b[1]) * (a[1] - b[1]);
            if (dd > far) {
              far = dd;
              best = (a, b);
            }
          }
        }
        canvas.drawLine(
          at(best.$1[0], best.$1[1]),
          at(best.$2[0], best.$2[1]),
          Paint()
            ..color = spark
            ..strokeWidth = 5
            ..strokeCap = StrokeCap.round,
        );
      } else {
        canvas.drawPath(
          shape(after),
          Paint()..color = spark.withValues(alpha: 0.22),
        );
        canvas.drawPath(
          shape(after),
          Paint()
            ..color = spark
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2.5
            ..strokeJoin = StrokeJoin.round,
        );
      }
      canvas.drawPath(
        shape(before),
        Paint()..color = ink.withValues(alpha: 0.08),
      );
      canvas.drawPath(
        shape(before),
        Paint()
          ..color = muted
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      return;
    }

    final label = lucidText(size: 11, weight: 600, color: muted);
    void arrow(List<int> to, Color color, double width, String name) {
      if (to[0] == 0 && to[1] == 0) return;
      final from = at(0, 0), tip = at(to[0], to[1]);
      final dir = tip - from;
      final unitDir = dir / dir.distance;
      final normal = Offset(-unitDir.dy, unitDir.dx);
      final base = tip - unitDir * 10;
      canvas.drawLine(
        from,
        base,
        Paint()
          ..color = color
          ..strokeWidth = width
          ..strokeCap = StrokeCap.round,
      );
      canvas.drawPath(
        Path()
          ..moveTo(tip.dx, tip.dy)
          ..lineTo((base + normal * 5.5).dx, (base + normal * 5.5).dy)
          ..lineTo((base - normal * 5.5).dx, (base - normal * 5.5).dy)
          ..close(),
        Paint()..color = color,
      );
      final tp = TextPainter(
        text: TextSpan(
          text: name,
          style: label.copyWith(color: color),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      // Beside the tip, on the side away from the other arrow.
      final spot = tip + normal * 12 - unitDir * 14;
      tp.paint(canvas, spot - Offset(tp.width / 2, tp.height / 2));
    }

    arrow(after[0], spark, 3, 'Av');
    arrow(before[0], ink, 2.5, 'v');
  }

  @override
  bool shouldRepaint(_PlanePainter old) =>
      old.picture != picture || old.ink != ink || old.spark != spark;
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final MatrixSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final pick = state.picked!;
    final picked = q.options[pick];
    final right = picked == q.answer;

    Widget tile(String value, String label, bool good) {
      return Container(
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
            _Answer(value, size: 22),
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
    }

    final mine = tile(picked, 'Your answer', false);
    final best = tile(q.answer, right ? 'Your answer · right' : 'Right', true);
    final pic = q.scene.picture;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        _Lines(lines: q.scene.lines, size: 20),
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
          SizedBox(height: d.gapM),
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
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        pic.title,
                        style: lucidText(size: 14, weight: 600, color: p.ink),
                      ),
                    ),
                    Text(
                      _note(pic),
                      style: lucidText(size: 12, color: p.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                MatrixPlane(picture: pic, height: d.compact ? 88 : 100),
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

  /// "Av = (−4, 4)" or "area 7" beside the picture's title.
  static String _note(MatrixPicture pic) {
    if (pic.v case final v?) return 'Av = ${vecPlain(pic.apply(v[0], v[1]))}';
    final m = pic.m;
    return 'area ${(m[0][0] * m[1][1] - m[0][1] * m[1][0]).abs()}';
  }
}
