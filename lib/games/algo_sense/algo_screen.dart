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
import 'algo_controller.dart';
import 'algo_puzzle.dart';
import 'algo_sense_game.dart';

// Built from the "Algo Sense · binary search", "· Monte Carlo" and
// "· review" artboards.

class AlgoScreen extends ConsumerWidget {
  const AlgoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(algoSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const AlgoSenseGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(algoSessionProvider),
                  onTrySimilar: ref
                      .read(algoSessionProvider.notifier)
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

final _plainNumber = RegExp(r'^−?[0-9.,]+$');

/// An option or answer: numbers in the display face, growth rates as maths.
class _Answer extends StatelessWidget {
  const _Answer(this.source, {required this.size});

  final String source;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final Widget child = _plainNumber.hasMatch(source)
        ? Text(
            source,
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

/// The plain text of an option, for screen readers and tests.
String optionText(String source) =>
    _plainNumber.hasMatch(source) ? source : mathPlain(source);

class _RoundView extends ConsumerWidget {
  const _RoundView({super.key, required this.state});

  final AlgoSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(algoSessionProvider.notifier);
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
        key: ValueKey('algo-$i'),
        semanticLabel: 'Answer ${optionText(text)}',
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
          game: const AlgoSenseGame(),
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

/// The question's maths, side by side, shrinking to fit.
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
      spacing: size * 0.9,
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

/// Pseudo-code, one line a row, indented by its leading spaces.
class AlgoCode extends StatelessWidget {
  const AlgoCode({super.key, required this.lines, required this.size});

  final List<String> lines;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: p.chip,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final l in lines)
            Padding(
              padding: EdgeInsets.only(
                left: (l.length - l.trimLeft().length) / 2 * size * 1.2,
                top: 1,
                bottom: 1,
              ),
              child: Text(
                l.trimLeft(),
                style: lucidText(
                  size: size,
                  weight: 500,
                  color: p.ink,
                  height: 1.35,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.question});

  final AlgoQuestion question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = question;
    final pic = q.scene.pictureOnCard ? q.scene.picture : null;
    final gap = SizedBox(height: d.compact ? 8 : 10);
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
              if (q.scene.lines.isNotEmpty) ...[
                _Lines(lines: q.scene.lines, size: d.compact ? 24 : 30),
                gap,
              ],
              if (q.scene.code.isNotEmpty) ...[
                AlgoCode(lines: q.scene.code, size: d.compact ? 14 : 15),
                gap,
              ],
              if (pic != null) ...[
                AlgoPictureView(picture: pic, height: d.compact ? 100 : 124),
                gap,
              ],
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

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final AlgoSessionState state;

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
        if (q.scene.lines.isNotEmpty) ...[
          _Lines(lines: q.scene.lines, size: 20),
          const SizedBox(height: 10),
        ],
        if (q.scene.code.isNotEmpty) ...[
          AlgoCode(lines: q.scene.code, size: 13),
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Text(
                        pic.title,
                        style: lucidText(size: 14, weight: 600, color: p.ink),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        pic.note,
                        textAlign: TextAlign.right,
                        style: lucidText(size: 12, color: p.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                AlgoPictureView(
                  picture: pic,
                  height: d.compact ? 88 : 100,
                  reveal: true,
                ),
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
}

// ---- pictures -----------------------------------------------------------------

/// Draws an [AlgoPicture]. On the card the unknown is a spark "?"; with
/// [reveal] (the review) it is filled in.
class AlgoPictureView extends StatelessWidget {
  const AlgoPictureView({
    super.key,
    required this.picture,
    required this.height,
    this.reveal = false,
  });

  final AlgoPicture picture;
  final double height;
  final bool reveal;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _AlgoPainter(
          picture: picture,
          reveal: reveal,
          c: _Colours(
            ink: p.ink,
            onInk: p.onInk,
            muted: p.muted,
            line: p.line,
            strong: p.lineStrong,
            surface: p.surface,
            chip: p.chip,
            spark: p.spark,
            onSpark: p.onSpark,
          ),
        ),
      ),
    );
  }
}

class _Colours {
  const _Colours({
    required this.ink,
    required this.onInk,
    required this.muted,
    required this.line,
    required this.strong,
    required this.surface,
    required this.chip,
    required this.spark,
    required this.onSpark,
  });

  final Color ink, onInk, muted, line, strong, surface, chip, spark, onSpark;
}

class _AlgoPainter extends CustomPainter {
  _AlgoPainter({required this.picture, required this.reveal, required this.c});

  final AlgoPicture picture;
  final bool reveal;
  final _Colours c;

  @override
  void paint(Canvas canvas, Size size) {
    switch (picture) {
      case final SearchPicture x:
        _search(canvas, size, x);
      case final RowsPicture x:
        _rows(canvas, size, x);
      case final PairsPicture x:
        _pairs(canvas, size, x);
      case final BarsPicture x:
        _bars(canvas, size, x);
      case final RatesPicture x:
        _rates(canvas, size, x);
      case final TreePicture x:
        x.memo ? _memo(canvas, size, x) : _tree(canvas, size, x);
      case final StairsPicture x:
        _stairs(canvas, size, x);
      case final CoinsPicture x:
        _coins(canvas, size, x);
      case final DartsPicture x:
        _darts(canvas, size, x);
      case final ErrorPicture x:
        _error(canvas, size, x);
      case final GridPicture x:
        _grid(canvas, size, x);
      case final GraphPicture x:
        _graph(canvas, size, x);
      case final TangentPicture x:
        _tangent(canvas, size, x);
      case final HalvingPicture x:
        _halving(canvas, size, x);
    }
  }

  // ---- drawing helpers ------------------------------------------------------

  TextStyle _style(Color color, double size, {int weight = 600}) =>
      lucidText(size: size, weight: weight, color: color);

  /// [text] placed so that [align] of its box sits at [at].
  void _text(
    Canvas canvas,
    String text,
    Offset at,
    TextStyle style, {
    Alignment align = Alignment.center,
  }) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(
      canvas,
      Offset(
        at.dx - tp.width * (align.x + 1) / 2,
        at.dy - tp.height * (align.y + 1) / 2,
      ),
    );
  }

  Paint _fill(Color color) => Paint()..color = color;

  Paint _stroke(Color color, double width) => Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = width
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  void _box(
    Canvas canvas,
    Rect r, {
    required Color fill,
    Color? border,
    double radius = 4,
  }) {
    final rr = RRect.fromRectAndRadius(r, Radius.circular(radius));
    canvas.drawRRect(rr, _fill(fill));
    if (border != null) {
      canvas.drawRRect(rr.deflate(0.75), _stroke(border, 1.5));
    }
  }

  void _dashed(Canvas canvas, Offset a, Offset b, Paint paint) {
    final len = (b - a).distance;
    if (len == 0) return;
    final dir = (b - a) / len;
    for (var t = 0.0; t < len; t += 8) {
      canvas.drawLine(a + dir * t, a + dir * min(t + 4, len), paint);
    }
  }

  // ---- kinds ------------------------------------------------------------------

  void _search(Canvas canvas, Size size, SearchPicture x) {
    final cells = min(x.n, 15);
    const labelW = 46.0, gap = 2.0;
    final cw = min(18.0, (size.width - labelW - gap * (cells - 1)) / cells);
    final rowH = min(24.0, (size.height - 16) / 3);
    final left = (size.width - labelW - cells * cw - gap * (cells - 1)) / 2;
    final top = (size.height - rowH * 3 - 16) / 2;
    var lo = 0, hi = cells - 1;
    for (var r = 0; r < 3 && lo <= hi; r++) {
      final y = top + r * (rowH + 8);
      _text(
        canvas,
        'look ${r + 1}',
        Offset(left, y + rowH / 2),
        _style(c.muted, 11),
        align: Alignment.centerLeft,
      );
      final mid = (lo + hi) ~/ 2;
      for (var i = 0; i < cells; i++) {
        final rect = Rect.fromLTWH(left + labelW + i * (cw + gap), y, cw, rowH);
        if (i == mid) {
          _box(canvas, rect, fill: c.spark);
        } else if (i >= lo && i <= hi) {
          _box(canvas, rect, fill: c.surface, border: c.strong);
        } else {
          _box(canvas, rect, fill: c.chip);
        }
      }
      if (r.isEven) {
        hi = mid - 1;
      } else {
        lo = mid + 1;
      }
    }
  }

  void _rows(Canvas canvas, Size size, RowsPicture x) {
    final most = x.rows.map((r) => r.cells.length).reduce(max);
    final labelW = x.rows.any((r) => r.label.isNotEmpty) ? 34.0 : 0.0;
    final headH = x.header == null ? 0.0 : 14.0;
    final arrowH = x.arrowAt == null ? 0.0 : 18.0;
    const gap = 4.0;
    final box = [
      34.0,
      (size.width - labelW - gap * (most - 1)) / most,
      (size.height - headH - arrowH - gap * (x.rows.length - 1)) /
          x.rows.length,
    ].reduce(min);
    final width = labelW + most * box + (most - 1) * gap;
    final height =
        headH + arrowH + x.rows.length * box + (x.rows.length - 1) * gap;
    final left = (size.width - width) / 2;
    var y = (size.height - height) / 2;
    double cx(int i) => left + labelW + i * (box + gap) + box / 2;
    if (x.header case final head?) {
      for (final (i, h) in head.indexed) {
        _text(canvas, h, Offset(cx(i), y + 6), _style(c.muted, 10));
      }
      y += headH;
    }
    if (x.arrowAt case final a?) {
      final from = Offset(cx(a), y + arrowH - 2);
      final to = Offset(cx(a + 1), y + arrowH - 2);
      final path = Path()
        ..moveTo(from.dx, from.dy)
        ..quadraticBezierTo((from.dx + to.dx) / 2, y - 6, to.dx, to.dy);
      canvas.drawPath(path, _stroke(c.spark, 2));
      for (final end in [from, to]) {
        canvas.drawPath(
          Path()
            ..moveTo(end.dx - 4, end.dy - 5)
            ..lineTo(end.dx, end.dy)
            ..lineTo(end.dx + 4, end.dy - 5),
          _stroke(c.spark, 2),
        );
      }
      y += arrowH;
    }
    for (final row in x.rows) {
      if (row.label.isNotEmpty) {
        _text(
          canvas,
          row.label,
          Offset(left + labelW - 8, y + box / 2),
          _style(c.muted, 12),
          align: Alignment.centerRight,
        );
      }
      for (final (i, cell) in row.cells.indexed) {
        final rect = Rect.fromLTWH(
          left + labelW + i * (box + gap),
          y,
          box,
          box,
        );
        final hidden = row.unknown && !reveal;
        final marked = reveal && row.marked.contains(i);
        _box(
          canvas,
          rect,
          fill: marked ? c.spark : c.surface,
          border: marked ? null : (hidden ? c.spark : c.strong),
          radius: 6,
        );
        _text(
          canvas,
          hidden ? '?' : cell,
          rect.center,
          _style(
            marked ? c.onSpark : (hidden ? c.spark : c.ink),
            min(16, box * 0.48),
            weight: 700,
          ),
        );
      }
      y += box + gap;
    }
  }

  void _pairs(Canvas canvas, Size size, PairsPicture x) {
    final n = x.n;
    final cell = min(14.0, (size.height - 4) / n);
    final left = (size.width - cell * n) / 2;
    final top = (size.height - cell * n) / 2;
    for (var i = 0; i < n; i++) {
      for (var j = 0; j < n; j++) {
        final counted = x.includeDiagonal ? j <= i : j > i;
        _box(
          canvas,
          Rect.fromLTWH(
            left + j * cell,
            top + i * cell,
            cell - 1.5,
            cell - 1.5,
          ),
          fill: counted ? c.spark : c.chip,
          radius: 2,
        );
      }
    }
    _text(
      canvas,
      'i ↓',
      Offset(left - 8, top + cell),
      _style(c.muted, 11),
      align: Alignment.centerRight,
    );
    _text(
      canvas,
      'j →',
      Offset(left + cell * n + 8, top + cell / 2),
      _style(c.muted, 11),
      align: Alignment.centerLeft,
    );
  }

  void _bars(Canvas canvas, Size size, BarsPicture x) {
    const labelW = 96.0;
    final barH = min(28.0, size.height / 3);
    final full = size.width - labelW - 70;
    final gap = (size.height - barH * 2) / 3;
    for (var r = 0; r < 2; r++) {
      final y = gap + r * (barH + gap);
      _text(
        canvas,
        x.sizes[r],
        Offset(labelW - 10, y + barH / 2),
        _style(c.muted, 12),
        align: Alignment.centerRight,
      );
      final known = r == 0;
      final w = known ? full * 0.22 : full;
      final rect = Rect.fromLTWH(labelW, y, w, barH);
      if (known) {
        _box(canvas, rect, fill: c.ink, radius: 6);
      } else if (reveal) {
        _box(canvas, rect, fill: c.spark, radius: 6);
      } else {
        final rr = RRect.fromRectAndRadius(rect, const Radius.circular(6));
        canvas.drawRRect(rr, _fill(c.spark.withValues(alpha: 0.12)));
        canvas.drawRRect(rr.deflate(1), _stroke(c.spark, 2));
      }
      _text(
        canvas,
        known ? x.known : (reveal ? x.unknown : '?'),
        Offset(labelW + w + 8, y + barH / 2),
        _style(known ? c.ink : c.spark, 14, weight: 700),
        align: Alignment.centerLeft,
      );
    }
  }

  void _rates(Canvas canvas, Size size, RatesPicture x) {
    const labelW = 64.0;
    final n = x.labels.length;
    final barH = min(16.0, size.height / n - 6);
    final gap = (size.height - barH * n) / (n + 1);
    final full = size.width - labelW - 64;
    final top = log(2568) / ln10;
    for (var i = 0; i < n; i++) {
      final y = gap + i * (barH + gap);
      _text(
        canvas,
        x.labels[i],
        Offset(labelW - 10, y + barH / 2),
        _style(c.muted, 12),
        align: Alignment.centerRight,
      );
      final w = max(6.0, full * (log(1 + x.digits[i]) / ln10) / top);
      _box(
        canvas,
        Rect.fromLTWH(labelW, y, w, barH),
        fill: i == x.highlight ? c.spark : c.strong,
        radius: 4,
      );
      final digits = x.digits[i];
      final value = switch (digits) {
        1.0 => '10',
        1.5 => '32',
        3.0 => '1,000',
        4.0 => '10⁴',
        6.0 => '10⁶',
        9.0 => '10⁹',
        301.0 => '10³⁰¹',
        _ => '10²⁵⁶⁷',
      };
      _text(
        canvas,
        value,
        Offset(labelW + w + 6, y + barH / 2),
        _style(i == x.highlight ? c.spark : c.muted, 11),
        align: Alignment.centerLeft,
      );
    }
  }

  void _node(
    Canvas canvas,
    Offset at,
    String label, {
    required bool marked,
    bool dashed = false,
    double w = 34,
    double h = 18,
  }) {
    final r = Rect.fromCenter(center: at, width: w, height: h);
    final rr = RRect.fromRectAndRadius(r, Radius.circular(h / 2));
    canvas.drawRRect(rr, _fill(marked ? c.spark : c.surface));
    if (!marked) {
      canvas.drawRRect(
        rr.deflate(0.75),
        _stroke(dashed ? c.line : c.strong, 1.5),
      );
    }
    _text(
      canvas,
      label,
      at,
      _style(marked ? c.onSpark : (dashed ? c.muted : c.ink), 10, weight: 700),
    );
  }

  void _tree(Canvas canvas, Size size, TreePicture x) {
    const depth = 3;
    final rowH = (size.height - 18) / depth;
    Offset at(int level, int slot) =>
        Offset(size.width * (slot + 0.5) / (1 << level), 9 + level * rowH);
    // Edges first, then nodes on top.
    final nodes = <(int, int, int)>[];
    void walk(int v, int level, int slot) {
      nodes.add((v, level, slot));
      if (v < 2 || level == depth) return;
      for (final (k, child) in [(0, v - 1), (1, v - 2)]) {
        canvas.drawLine(
          at(level, slot),
          at(level + 1, slot * 2 + k),
          _stroke(c.strong, 1.5),
        );
        walk(child, level + 1, slot * 2 + k);
      }
    }

    walk(x.n, 0, 0);
    final w = min(34.0, size.width / (1 << depth) - 4);
    for (final (v, level, slot) in nodes) {
      _node(
        canvas,
        at(level, slot),
        'f($v)',
        marked: x.mark != null ? v == x.mark : level == 0,
        w: w,
      );
      if (level == depth && v >= 2) {
        _text(
          canvas,
          '⋮',
          at(level, slot) + const Offset(0, 12),
          _style(c.muted, 10),
        );
      }
    }
  }

  void _memo(Canvas canvas, Size size, TreePicture x) {
    final rows = min(4, x.n - 1);
    final rowH = (size.height - 10) / (rows + 0.5);
    final spine = size.width * 0.38, side = size.width * 0.66;
    for (var r = 0; r < rows; r++) {
      final v = x.n - r;
      final y = 10 + r * rowH;
      final me = Offset(spine, y);
      if (r < rows - 1) {
        canvas.drawLine(me, Offset(spine, y + rowH), _stroke(c.strong, 1.5));
      }
      final look = Offset(side, y + rowH * 0.5);
      _dashed(canvas, me, look, _stroke(c.strong, 1.5));
      _node(canvas, look, 'f(${v - 2})', marked: false, dashed: true, w: 40);
      _node(canvas, me, 'f($v)', marked: r == 0, w: 40);
    }
    _text(
      canvas,
      '⋮',
      Offset(spine, 10 + rows * rowH - rowH * 0.35),
      _style(c.muted, 12),
    );
    _text(
      canvas,
      'look-ups',
      Offset(side + 26, 10),
      _style(c.muted, 11),
      align: Alignment.centerLeft,
    );
  }

  void _stairs(Canvas canvas, Size size, StairsPicture x) {
    final n = x.n;
    final stepW = min(30.0, (size.width - 40) / (n + 1));
    final stepH = (size.height - 22) / n;
    final left = (size.width - stepW * (n + 1)) / 2;
    final base = size.height - 4;
    Offset tread(int k) => Offset(left + stepW * (k + 0.5), base - stepH * k);
    final outline = Path()..moveTo(left, base);
    for (var k = 0; k <= n; k++) {
      outline
        ..lineTo(left + stepW * k, base - stepH * k)
        ..lineTo(left + stepW * (k + 1), base - stepH * k);
    }
    canvas.drawPath(outline, _stroke(c.ink, 2.5));
    // One climb as hops between treads.
    var at = 0;
    for (final h in x.hops) {
      final a = tread(at) - const Offset(0, 4);
      final b = tread(at + h) - const Offset(0, 4);
      final path = Path()
        ..moveTo(a.dx, a.dy)
        ..quadraticBezierTo(
          (a.dx + b.dx) / 2,
          min(a.dy, b.dy) - 8 - 5.0 * h,
          b.dx,
          b.dy,
        );
      canvas.drawPath(path, _stroke(c.muted, 1.5));
      at += h;
    }
    canvas.drawCircle(tread(n) - const Offset(0, 4), 5, _fill(c.spark));
    _text(
      canvas,
      reveal ? 'top' : 'top ?',
      tread(n) + const Offset(-10, -16),
      _style(c.spark, 11, weight: 700),
      align: Alignment.centerRight,
    );
  }

  void _coins(Canvas canvas, Size size, CoinsPicture x) {
    final r = min(20.0, size.height / 4);
    final mid = size.height / 2;
    final count = x.coins.length;
    const gap = 10.0;
    final coinsW = count * 2 * r + (count - 1) * gap;
    const amountW = 64.0, arrowW = 36.0;
    final left = (size.width - coinsW - arrowW - amountW) / 2;
    for (var i = 0; i < count; i++) {
      final at = Offset(left + r + i * (2 * r + gap), mid);
      canvas.drawCircle(at, r, _fill(c.chip));
      canvas.drawCircle(at, r - 1, _stroke(c.strong, 2));
      _text(canvas, '${x.coins[i]}', at, _style(c.ink, 15, weight: 700));
    }
    final ax = left + coinsW + 6;
    canvas.drawLine(
      Offset(ax, mid),
      Offset(ax + arrowW - 12, mid),
      _stroke(c.muted, 2),
    );
    canvas.drawPath(
      Path()
        ..moveTo(ax + arrowW - 18, mid - 5)
        ..lineTo(ax + arrowW - 12, mid)
        ..lineTo(ax + arrowW - 18, mid + 5),
      _stroke(c.muted, 2),
    );
    final box = Rect.fromLTWH(left + coinsW + arrowW, mid - 20, amountW, 40);
    _box(canvas, box, fill: c.ink, radius: 12);
    _text(canvas, '${x.amount}', box.center, _style(c.onInk, 18, weight: 700));
    _text(
      canvas,
      reveal ? x.answer : '?',
      Offset(box.center.dx, box.bottom + 12),
      _style(c.spark, 13, weight: 700),
    );
  }

  void _darts(Canvas canvas, Size size, DartsPicture x) {
    final s = size.height - 8;
    final left = (size.width - s) / 2, top = 4.0;
    final square = Rect.fromLTWH(left, top, s, s);
    canvas.drawRect(square, _stroke(c.strong, 2));
    final corner = Offset(left, top + s);
    final quarter = Path()
      ..moveTo(corner.dx, corner.dy)
      ..lineTo(left + s, top + s)
      ..arcTo(Rect.fromCircle(center: corner, radius: s), 0, -pi / 2, false)
      ..close();
    canvas.drawPath(quarter, _fill(c.spark.withValues(alpha: 0.10)));
    final rng = Random(x.seed);
    var inside = 0, outside = 0, tries = 0;
    final dot = min(2.6, s / 45);
    while ((inside < x.inside || outside < x.darts - x.inside) &&
        tries++ < 20000) {
      final u = rng.nextDouble(), v = rng.nextDouble();
      final isIn = u * u + v * v < 1;
      if (isIn ? inside >= x.inside : outside >= x.darts - x.inside) continue;
      isIn ? inside++ : outside++;
      canvas.drawCircle(
        Offset(left + u * s, top + s - v * s),
        dot,
        _fill(isIn ? c.ink : c.strong),
      );
    }
    canvas.drawArc(
      Rect.fromCircle(center: corner, radius: s),
      -pi / 2,
      pi / 2,
      false,
      _stroke(c.spark, 2.5),
    );
    _text(
      canvas,
      reveal ? picture.note : 'π ?',
      Offset(left + s + 10, top + s / 2),
      _style(c.spark, 13, weight: 700),
      align: Alignment.centerLeft,
    );
  }

  void _error(Canvas canvas, Size size, ErrorPicture x) {
    const left = 44.0, bottom = 18.0;
    final w = size.width - left - 12, h = size.height - bottom - 6;
    final e1 = double.parse(x.error), e2 = double.parse(x.target);
    // x runs with √n (so the curve is 1/x); n₂ sits at 85% of the width.
    final ratio = e1 / e2;
    double px(double rootN) => left + w * 0.85 * rootN / ratio;
    double py(double e) => 6 + h * (1 - e / (e1 * 1.25));
    final curve = Path();
    for (var i = 0; i <= 60; i++) {
      final r = 0.75 + (ratio * 1.15 - 0.75) * i / 60;
      final o = Offset(px(r), py(e1 / r));
      i == 0 ? curve.moveTo(o.dx, o.dy) : curve.lineTo(o.dx, o.dy);
    }
    canvas.drawLine(
      Offset(left, 6 + h),
      Offset(left + w, 6 + h),
      _stroke(c.strong, 2),
    );
    canvas.drawLine(Offset(left, 6), Offset(left, 6 + h), _stroke(c.strong, 2));
    canvas.drawPath(curve, _stroke(c.ink, 2.5));
    _dashed(
      canvas,
      Offset(left, py(e2)),
      Offset(px(ratio), py(e2)),
      _stroke(c.spark, 1.5),
    );
    canvas.drawCircle(Offset(px(1), py(e1)), 4.5, _fill(c.ink));
    canvas.drawCircle(Offset(px(ratio), py(e2)), 5, _fill(c.spark));
    final small = _style(c.muted, 10);
    _text(
      canvas,
      x.error,
      Offset(left - 6, py(e1)),
      small,
      align: Alignment.centerRight,
    );
    _text(
      canvas,
      x.target,
      Offset(left - 6, py(e2)),
      _style(c.spark, 10),
      align: Alignment.centerRight,
    );
    _text(canvas, x.samples, Offset(px(1), 6 + h + 9), small);
    _text(
      canvas,
      reveal ? x.answer : '?',
      Offset(px(ratio), 6 + h + 9),
      _style(c.spark, 10, weight: 700),
    );
  }

  void _grid(Canvas canvas, Size size, GridPicture x) {
    final cell = min(
      34.0,
      min((size.width - 60) / x.w, (size.height - 12) / x.h),
    );
    final left = (size.width - cell * x.w) / 2;
    final top = (size.height - cell * x.h) / 2;
    Offset at(int i, int j) => Offset(left + i * cell, top + j * cell);
    final pen = _stroke(c.strong, 2);
    for (var i = 0; i <= x.w; i++) {
      canvas.drawLine(at(i, 0), at(i, x.h), pen);
    }
    for (var j = 0; j <= x.h; j++) {
      canvas.drawLine(at(0, j), at(x.w, j), pen);
    }
    final (wx, wy) = x.wall;
    canvas.drawCircle(at(wx, wy), 7, _fill(c.ink));
    canvas.drawCircle(at(0, 0), 6, _fill(c.ink));
    canvas.drawCircle(at(x.w, x.h), 6, _fill(c.spark));
    _text(
      canvas,
      'S',
      at(0, 0) - const Offset(10, 0),
      _style(c.ink, 12, weight: 700),
      align: Alignment.centerRight,
    );
    _text(
      canvas,
      reveal ? 'T' : 'T ?',
      at(x.w, x.h) + const Offset(10, 0),
      _style(c.spark, 12, weight: 700),
      align: Alignment.centerLeft,
    );
  }

  void _graph(Canvas canvas, Size size, GraphPicture x) {
    final dx = min(70.0, (size.width - 40) / (x.cols - 1));
    final dy = (size.height - 24) / (x.rows - 1);
    final left = (size.width - dx * (x.cols - 1)) / 2;
    Offset at(int i) =>
        Offset(left + (i % x.cols) * dx, 12 + (i ~/ x.cols) * dy);
    final onPath = <(int, int)>{
      if (reveal)
        for (var k = 0; k + 1 < x.path.length; k++)
          x.path[k] < x.path[k + 1]
              ? (x.path[k], x.path[k + 1])
              : (x.path[k + 1], x.path[k]),
    };
    for (final (a, b) in x.edges) {
      final lit = onPath.contains(a < b ? (a, b) : (b, a));
      canvas.drawLine(
        at(a),
        at(b),
        _stroke(lit ? c.spark : c.strong, lit ? 3 : 2),
      );
    }
    for (var i = 0; i < x.cols * x.rows; i++) {
      final o = at(i);
      final start = i == x.start, target = i == x.target;
      final fill = start ? c.ink : (target && reveal ? c.spark : c.surface);
      canvas.drawCircle(o, 10, _fill(fill));
      if (!start && !(target && reveal)) {
        canvas.drawCircle(o, 9.25, _stroke(target ? c.spark : c.strong, 1.5));
      }
      _text(
        canvas,
        String.fromCharCode(65 + i),
        o,
        _style(
          start ? c.onInk : (target ? (reveal ? c.onSpark : c.spark) : c.ink),
          10,
          weight: 700,
        ),
      );
    }
  }

  void _tangent(Canvas canvas, Size size, TangentPicture x) {
    final root = sqrt(x.a);
    final xs = [x.x0, x.x1, root];
    final lo = max(0.0, xs.reduce(min) - 1), hi = xs.reduce(max) + 1;
    double f(double t) => t * t - x.a;
    final yLo = min(f(lo), f(x.x0) - 1), yHi = max(f(hi), 1.0);
    double px(double t) => 10 + (t - lo) / (hi - lo) * (size.width - 20);
    double py(double y) => 6 + (yHi - y) / (yHi - yLo) * (size.height - 12);
    canvas.drawLine(
      Offset(px(lo), py(0)),
      Offset(px(hi), py(0)),
      _stroke(c.strong, 2),
    );
    final curve = Path();
    for (var i = 0; i <= 60; i++) {
      final t = lo + (hi - lo) * i / 60;
      final o = Offset(px(t), py(f(t)));
      i == 0 ? curve.moveTo(o.dx, o.dy) : curve.lineTo(o.dx, o.dy);
    }
    canvas.save();
    canvas.clipRect(Offset.zero & size);
    canvas.drawPath(curve, _stroke(c.ink, 2.5));
    final slope = 2 * x.x0;
    final span = (hi - lo) * 0.3;
    Offset tan(double t) => Offset(px(t), py(f(x.x0) + slope * (t - x.x0)));
    _dashed(canvas, tan(x.x0 - span), tan(x.x0 + span), _stroke(c.muted, 1.5));
    canvas.restore();
    final p0 = Offset(px(x.x0), py(f(x.x0)));
    canvas.drawLine(Offset(p0.dx, py(0)), p0, _stroke(c.muted, 1.5));
    canvas.drawCircle(p0, 4.5, _fill(c.ink));
    final p1 = Offset(px(x.x1), py(0));
    canvas.drawCircle(p1, 5, _fill(c.spark));
    final below = f(x.x0) < 0;
    _text(
      canvas,
      'x₀',
      Offset(p0.dx, py(0) + (below ? -10 : 10)),
      _style(c.muted, 11),
    );
    _text(
      canvas,
      reveal ? 'x₁ = ${x.answer}' : 'x₁ ?',
      Offset(p1.dx, py(0) + (below ? 12 : -12)),
      _style(c.spark, 11, weight: 700),
    );
  }

  void _halving(Canvas canvas, Size size, HalvingPicture x) {
    const rows = 3;
    final barH = min(14.0, size.height / 6);
    final gap = (size.height - rows * barH) / (rows + 1);
    const rootAt = 0.62;
    final left = 70.0, full = size.width - left - 16;
    var lo = 0.0, hi = 1.0;
    for (var r = 0; r < rows; r++) {
      final y = gap + r * (barH + gap);
      _box(canvas, Rect.fromLTWH(left, y, full, barH), fill: c.chip, radius: 4);
      _box(
        canvas,
        Rect.fromLTWH(left + lo * full, y, (hi - lo) * full, barH),
        fill: r == rows - 1 ? c.spark : c.ink,
        radius: 4,
      );
      _text(
        canvas,
        r == 0 ? 'width ${x.width}' : '÷ ${1 << r}',
        Offset(left - 10, y + barH / 2),
        _style(c.muted, 11),
        align: Alignment.centerRight,
      );
      final mid = (lo + hi) / 2;
      if (rootAt < mid) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    final rx = left + rootAt * full;
    canvas.drawLine(
      Offset(rx, gap - 4),
      Offset(rx, size.height - gap + 4),
      _stroke(c.spark, 1.5),
    );
    _text(
      canvas,
      reveal ? '< ${x.tolerance}: ${picture.note}' : '< ${x.tolerance} ?',
      Offset(left + full, size.height - 4),
      _style(c.spark, 11, weight: 700),
      align: Alignment.bottomRight,
    );
  }

  @override
  bool shouldRepaint(_AlgoPainter old) =>
      old.picture != picture || old.reveal != reveal || old.c.ink != c.ink;
}
