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
import '../expect_it/expect_puzzle.dart' show ev;
import '../odds_on/odds_math.dart';
import 'brown_controller.dart';
import 'brown_puzzle.dart';
import 'brownian_path_game.dart';

// Built from the "Brownian Path · reflection", "· tail" and "· review"
// artboards.

/// Options this long (as plain text) get a row each.
bool brownWide(List<String> options) =>
    options.any((o) => mathPlain(o).length > 10);

class BrownScreen extends ConsumerWidget {
  const BrownScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(brownSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const BrownianPathGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(brownSessionProvider),
                  onTrySimilar: ref
                      .read(brownSessionProvider.notifier)
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

  final BrownSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(brownSessionProvider.notifier);
    final q = state.question;
    final wide = brownWide(q.options);

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
        key: ValueKey('brown-$i'),
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
                  size: wide ? (d.compact ? 17 : 19) : (d.compact ? 20 : 23),
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
          game: const BrownianPathGame(),
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

  final BrownQuestion question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = question;
    final table = q.table;
    // The table takes room: the picture gives some back on small phones.
    final h = d.compact ? (table == null ? 88.0 : 72.0) : 112.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Container(
          padding: EdgeInsets.symmetric(
            vertical: d.compact ? 12 : 18,
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
              if (q.given != null) ...[
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MathText(
                    q.given!,
                    size: d.compact ? 15 : 17,
                    color: p.muted,
                  ),
                ),
              ],
              SizedBox(height: d.compact ? 8 : 10),
              BrownPicture(question: q, height: h),
              if (table != null) ...[
                SizedBox(height: d.compact ? 6 : 8),
                NormalTable(columns: table),
              ],
              SizedBox(height: d.compact ? 8 : 10),
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

/// The table on the card: z, and the share of the bell above it.
class NormalTable extends StatelessWidget {
  const NormalTable({super.key, required this.columns});

  /// 2z for each column.
  final List<int> columns;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final size = d.compact ? 12.0 : 13.0;
    final head = lucidText(size: size, weight: 600, color: p.muted);
    final cell = lucidText(size: size, weight: 500, color: p.ink);
    final value = lucidText(size: size, weight: 600, color: p.ink);
    Widget col(String top, String bottom, TextStyle a, TextStyle b) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(top, style: a),
        const SizedBox(height: 4),
        Text(bottom, style: b),
      ],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          col('z', 'P(Z > z)', head, head),
          for (final c in columns) ...[
            const SizedBox(width: 18),
            col(ev(Frac(c, 2)), pc(normalTable[c]!), cell, value),
          ],
        ],
      ),
    );
  }
}

/// The question's picture: one possible path, or the bell curve.
class BrownPicture extends StatelessWidget {
  const BrownPicture({super.key, required this.question, required this.height});

  final BrownQuestion question;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final path = question.path;
    final bell = question.bell;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: path != null
            ? _PathPainter(
                path: path,
                ink: p.ink,
                muted: p.muted,
                rule: p.lineStrong,
                spark: p.spark,
              )
            : _BellPainter(
                bell: bell!,
                ink: p.ink,
                muted: p.muted,
                rule: p.lineStrong,
                spark: p.spark,
              ),
      ),
    );
  }
}

void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
  const dash = 5.0, gap = 4.0;
  final total = (b - a).distance;
  if (total == 0) return;
  final dir = (b - a) / total;
  for (var s = 0.0; s < total; s += dash + gap) {
    canvas.drawLine(a + dir * s, a + dir * min(s + dash, total), paint);
  }
}

TextPainter _label(String text, Color color) => TextPainter(
  text: TextSpan(
    text: text,
    style: lucidText(size: 11, weight: 500, color: color),
  ),
  textDirection: TextDirection.ltr,
)..layout();

class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.path,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.spark,
  });

  final BrownPath path;
  final Color ink, muted, rule, spark;

  @override
  void paint(Canvas canvas, Size size) {
    final g = path;
    const padX = 8.0, padTop = 6.0, labelH = 16.0;
    final w = size.width - 2 * padX;
    final h = size.height - padTop - labelH;
    final ys = g.ys;
    var lo = [0.0, ...ys, for (final l in g.levels) l.y].reduce(min);
    var hi = [0.0, ...ys, for (final l in g.levels) l.y].reduce(max);
    if (hi - lo < 1e-9) hi = lo + 1;
    final pad = (hi - lo) * 0.08;
    lo -= pad;
    hi += pad;
    final n = ys.length - 1;
    // The drawn stretch ends where the path stopped.
    final dtStep = g.tEnd / max(1, n);
    final shown = n * dtStep;
    double px(double t) => padX + t / shown * w;
    double py(double y) => padTop + (hi - y) / (hi - lo) * h;
    final bottom = padTop + h;

    final axis = Paint()
      ..color = rule
      ..strokeWidth = 1.5;
    canvas.drawLine(Offset(padX, bottom), Offset(padX + w, bottom), axis);
    if (!g.levels.any((l) => l.y == 0)) {
      canvas.drawLine(
        Offset(padX, py(0)),
        Offset(padX + w, py(0)),
        Paint()
          ..color = rule.withValues(alpha: 0.6)
          ..strokeWidth = 1,
      );
    }

    for (final m in g.marks) {
      final x = px(m.t.clamp(0, shown));
      _dashed(
        canvas,
        Offset(x, padTop),
        Offset(x, bottom),
        Paint()
          ..color = m.spark ? spark : rule
          ..strokeWidth = m.spark ? 2 : 1.5,
      );
    }

    for (final l in g.levels) {
      _dashed(
        canvas,
        Offset(padX, py(l.y)),
        Offset(padX + w, py(l.y)),
        Paint()
          ..color = l.spark ? spark : muted
          ..strokeWidth = l.spark ? 2 : 1.5,
      );
    }

    Offset at(int i) => Offset(px(i * dtStep), py(ys[i]));
    final line = Path()..moveTo(at(0).dx, at(0).dy);
    for (var i = 1; i <= n; i++) {
      line.lineTo(at(i).dx, at(i).dy);
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    final from = g.from, to = g.to;
    if (from != null && to != null) {
      final i0 = (from / dtStep).round().clamp(0, n);
      final i1 = (to / dtStep).round().clamp(0, n);
      final part = Path()..moveTo(at(i0).dx, at(i0).dy);
      for (var i = i0 + 1; i <= i1; i++) {
        part.lineTo(at(i).dx, at(i).dy);
      }
      canvas.drawPath(
        part,
        Paint()
          ..color = spark
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    if (g.endDot) {
      canvas.drawCircle(at(n), 5, Paint()..color = spark);
    }

    // Level labels at the left, just above their line.
    for (final l in g.levels) {
      final tp = _label(l.label, l.spark ? ink : muted);
      final y = (py(l.y) - tp.height - 1).clamp(0.0, bottom - tp.height);
      tp.paint(canvas, Offset(padX + 2, y));
    }

    // The time axis: 0, then each marked time.
    final zero = _label('0', muted);
    final ly = size.height - labelH / 2 - zero.height / 2;
    zero.paint(canvas, Offset(padX, ly));
    for (final m in g.marks) {
      final tp = _label(m.label, m.spark ? ink : muted);
      final cx = px(
        m.t.clamp(0, shown),
      ).clamp(padX + zero.width + 4 + tp.width / 2, size.width - tp.width / 2);
      tp.paint(canvas, Offset(cx - tp.width / 2, ly));
    }
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.path != path || old.ink != ink || old.spark != spark;
}

class _BellPainter extends CustomPainter {
  _BellPainter({
    required this.bell,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.spark,
  });

  final BrownBell bell;
  final Color ink, muted, rule, spark;

  @override
  void paint(Canvas canvas, Size size) {
    const padX = 8.0, padTop = 6.0, labelH = 16.0, lo = -3.2, hi = 3.2;
    final w = size.width - 2 * padX;
    final h = size.height - padTop - labelH;
    final base = padTop + h;
    double px(double z) => padX + (z - lo) / (hi - lo) * w;
    double py(double z) => base - exp(-z * z / 2) * h;

    final c = bell.cut.clamp(lo, hi);
    final ranges = switch (bell.shade) {
      BellShade.above => [(c, hi)],
      BellShade.below => [(lo, c)],
      BellShade.outside => [(lo, -c.abs()), (c.abs(), hi)],
    };
    final fill = Paint()..color = spark.withValues(alpha: 0.28);
    final edge = Paint()
      ..color = spark
      ..strokeWidth = 2;
    for (final (a, b) in ranges) {
      final area = Path()..moveTo(px(a), base);
      const m = 40;
      for (var i = 0; i <= m; i++) {
        final z = a + (b - a) * i / m;
        area.lineTo(px(z), py(z));
      }
      area
        ..lineTo(px(b), base)
        ..close();
      canvas.drawPath(area, fill);
    }
    for (final z in {
      if (bell.shade == BellShade.outside) ...[-c.abs(), c.abs()] else c,
    }) {
      canvas.drawLine(Offset(px(z), base), Offset(px(z), py(z)), edge);
    }

    canvas.drawLine(
      Offset(padX, base),
      Offset(padX + w, base),
      Paint()
        ..color = rule
        ..strokeWidth = 1.5,
    );

    final curve = Path();
    const n = 96;
    for (var i = 0; i <= n; i++) {
      final z = lo + (hi - lo) * i / n;
      i == 0 ? curve.moveTo(px(z), py(z)) : curve.lineTo(px(z), py(z));
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

    for (final MapEntry(key: z, value: label) in bell.labels.entries) {
      final tp = _label(label, muted);
      final cx = px(z).clamp(tp.width / 2, size.width - tp.width / 2);
      canvas.drawLine(
        Offset(px(z), base - 3),
        Offset(px(z), base + 3),
        Paint()
          ..color = rule
          ..strokeWidth = 1.5,
      );
      tp.paint(
        canvas,
        Offset(cx - tp.width / 2, size.height - labelH / 2 - tp.height / 2),
      );
    }
  }

  @override
  bool shouldRepaint(_BellPainter old) =>
      old.bell != bell || old.ink != ink || old.spark != spark;
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final BrownSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final pick = state.picked!;
    final picked = q.options[pick];
    final right = picked == q.answer;
    final wide = brownWide(q.options);

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
        if (q.showPictureInReview) ...[
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
                      q.path != null ? 'One possible path' : 'The bell curve',
                      style: lucidText(size: 14, weight: 600, color: p.ink),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        q.caption,
                        textAlign: TextAlign.end,
                        style: lucidText(size: 12, color: p.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                BrownPicture(question: q, height: d.compact ? 80 : 96),
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
