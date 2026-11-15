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
import '../expect_it/expect_puzzle.dart' show ev;
import 'risk_controller.dart';
import 'risk_desk_game.dart';
import 'risk_puzzle.dart';

// Built from the "Risk Desk · split bar", "· Sharpe chart" and "· VaR
// review" artboards.

class RiskScreen extends ConsumerWidget {
  const RiskScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(riskSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const RiskDeskGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(riskSessionProvider),
                  onTrySimilar: ref
                      .read(riskSessionProvider.notifier)
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

  final RiskSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(riskSessionProvider.notifier);
    final q = state.question;

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    Widget option(int i, String text) => PressScale(
      key: ValueKey('risk-$i'),
      semanticLabel: 'Answer $text',
      onTap: () => choose(i),
      child: Container(
        constraints: BoxConstraints(minHeight: d.compact ? 46 : 52),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
          border: Border.all(color: p.line, width: 1.5),
        ),
        child: FittedBox(
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
          game: const RiskDeskGame(),
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

/// The scene's picture at [height], or nothing for a plain quote.
Widget? _picture(RiskScene scene, double height) => switch (scene.visual) {
  RiskVisual.split => SplitBar(scene: scene, height: height >= 100 ? 44 : 38),
  RiskVisual.dots => RiskChart(scene: scene, height: height),
  RiskVisual.beta => BetaLine(scene: scene, height: height),
  RiskVisual.bell => BellCurve(scene: scene, height: height),
  RiskVisual.grid => CovGrid(scene: scene, cell: height < 100 ? 30 : 36),
  RiskVisual.quote => null,
};

class _Question extends StatelessWidget {
  const _Question({required this.question});

  final RiskQuestion question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = question;
    final scene = q.scene;
    final picture = _picture(scene, d.compact ? 110 : 140);
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
              if (picture != null) ...[const SizedBox(height: 12), picture],
              const SizedBox(height: 10),
              Text(scene.caption.toUpperCase(), style: lucidLabel(p.muted)),
            ],
          ),
        ),
        SizedBox(height: d.gapL),
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

/// The money split between the assets: the first share in ink.
class SplitBar extends StatelessWidget {
  const SplitBar({super.key, required this.scene, required this.height});

  final RiskScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final slices = scene.slices;
    final label = scene.unknownSplit
        ? 'Weights unknown'
        : slices.length > 4
        ? '${slices.length} equal shares'
        : [for (final s in slices) '${s.label} (${ev(s.weight)})'].join(', ');
    return Semantics(
      label: label,
      excludeSemantics: true,
      child: Container(
        height: height,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.chip,
          borderRadius: BorderRadius.circular(14),
        ),
        // Drawn over the shares so the outline stays even all round.
        foregroundDecoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.ink, width: 2),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final (i, s) in slices.indexed)
              Expanded(
                flex: max(1, (s.weight.value * 1000).round()),
                child: Container(
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  decoration: BoxDecoration(
                    color: s.filled ? p.ink : p.chip,
                    border: i == 0
                        ? null
                        : Border(left: BorderSide(color: p.ink, width: 2)),
                  ),
                  child: s.label.isEmpty
                      ? null
                      : FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            s.label,
                            style: lucidText(
                              size: 14,
                              weight: 700,
                              display: true,
                              color: s.filled ? p.onInk : p.ink,
                            ),
                          ),
                        ),
                ),
              ),
          ],
        ),
      ),
    );
  }
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

/// Volatility across, return up: the assets in ink, the fund in spark
/// orange, the risk-free rate on the left edge.
class RiskChart extends StatelessWidget {
  const RiskChart({super.key, required this.scene, required this.height});

  final RiskScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final parts = [
      if (scene.riskFree != null) 'risk-free ${pct(scene.riskFree!)}',
      for (final d in scene.dots)
        '${d.label}: vol ${pct(d.vol)}'
            '${d.ret == null ? ', return unknown' : ', return ${pct(d.ret!)}'}',
    ];
    return Semantics(
      label: 'Risk–return chart. ${parts.join('; ')}.',
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
            surface: p.surface,
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
    required this.surface,
  });

  final RiskScene scene;
  final Color ink, line, muted, spark, surface;

  @override
  void paint(Canvas canvas, Size size) {
    final dots = scene.dots;
    final rf = scene.riskFree?.value;
    final xMax = max(10.0, dots.map((d) => d.vol.value).reduce(max) * 1.2);
    final rets = [
      for (final d in dots)
        if (d.ret != null) d.ret!.value,
      ?rf,
    ];
    final yMax = max(5.0, (rets.isEmpty ? 5.0 : rets.reduce(max)) * 1.3);
    const left = 10.0, right = 10.0, top = 22.0, bottom = 20.0;
    double px(double v) => left + v / xMax * (size.width - left - right);
    double py(double r) =>
        size.height - bottom - r / yMax * (size.height - top - bottom);

    final axis = Paint()
      ..color = line
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, py(0)), Offset(size.width, py(0)), axis);
    canvas.drawLine(Offset(left, py(0)), Offset(left, 4), axis);
    _text(
      canvas,
      'volatility →',
      Offset(size.width, size.height - 14),
      muted,
      align: TextAlign.right,
    );
    _text(
      canvas,
      '↑ return',
      Offset(left + 6, 0),
      muted,
      align: TextAlign.left,
    );

    final inkLine = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;

    if (scene.frontier && dots.length == 2) {
      final a = dots[0], b = dots[1];
      final path = Path();
      for (var i = 0; i <= 50; i++) {
        final w = i / 50;
        final vol = sqrt(
          pow(w * a.vol.value, 2) + pow((1 - w) * b.vol.value, 2),
        );
        final ret = w * a.ret!.value + (1 - w) * b.ret!.value;
        i == 0 ? path.moveTo(px(vol), py(ret)) : path.lineTo(px(vol), py(ret));
      }
      canvas.drawPath(path, inkLine);
    }

    final fund = dots.where((d) => d.spark).firstOrNull;
    if (rf != null && fund?.ret != null) {
      _dashed(
        canvas,
        Offset(px(0), py(rf)),
        Offset(px(fund!.vol.value), py(fund.ret!.value)),
        Paint()
          ..color = ink
          ..strokeWidth = 2,
      );
    }
    if (rf != null) {
      final at = Offset(px(0), py(rf));
      canvas.drawCircle(at, 6, Paint()..color = surface);
      canvas.drawCircle(
        at,
        6,
        Paint()
          ..color = ink
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5,
      );
      _text(
        canvas,
        'risk-free ${pct(scene.riskFree!)}',
        Offset(left + 2, size.height - 14),
        muted,
        align: TextAlign.left,
      );
    }
    for (final d in dots) {
      final x = px(d.vol.value);
      if (d.ret == null) {
        _dashed(
          canvas,
          Offset(x, py(0)),
          Offset(x, top),
          Paint()
            ..color = spark
            ..strokeWidth = 2,
        );
        _text(canvas, '${d.label} ?', Offset(x, top - 18), ink, bold: true);
        continue;
      }
      final at = Offset(x, py(d.ret!.value));
      canvas.drawCircle(
        at,
        d.spark ? 8 : 6,
        Paint()..color = d.spark ? spark : ink,
      );
      if (d.spark) {
        _text(canvas, d.label, at - const Offset(0, 24), ink, bold: true);
      } else {
        final roomRight = at.dx + 40 < size.width;
        _text(
          canvas,
          d.label,
          at + Offset(roomRight ? 12 : -12, -8),
          ink,
          bold: true,
          align: roomRight ? TextAlign.left : TextAlign.right,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.scene != scene || old.ink != ink || old.spark != spark;
}

/// CAPM's line: the risk-free rate at beta 0, the market at beta 1, the
/// stock at its beta in spark orange.
class BetaLine extends StatelessWidget {
  const BetaLine({super.key, required this.scene, required this.height});

  final RiskScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label:
          'Beta line from the risk-free ${pct(scene.riskFree!)} at beta 0 '
          'through the market ${pct(scene.marketReturn!)} at beta 1; the '
          'stock sits at beta ${ev(scene.beta!)}.',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BetaPainter(
            scene: scene,
            ink: p.ink,
            line: p.lineStrong,
            muted: p.muted,
            spark: p.spark,
            surface: p.surface,
          ),
        ),
      ),
    );
  }
}

class _BetaPainter extends CustomPainter {
  _BetaPainter({
    required this.scene,
    required this.ink,
    required this.line,
    required this.muted,
    required this.spark,
    required this.surface,
  });

  final RiskScene scene;
  final Color ink, line, muted, spark, surface;

  @override
  void paint(Canvas canvas, Size size) {
    final rf = scene.riskFree!.value, rm = scene.marketReturn!.value;
    final b = scene.beta!.value;
    final xMax = max(2.0, b + 0.5);
    double ret(double beta) => rf + beta * (rm - rf);
    final yMax = ret(xMax) * 1.15;
    const left = 10.0, right = 10.0, top = 20.0, bottom = 20.0;
    double px(double v) => left + v / xMax * (size.width - left - right);
    double py(double r) =>
        size.height - bottom - r / yMax * (size.height - top - bottom);

    final axis = Paint()
      ..color = line
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, py(0)), Offset(size.width, py(0)), axis);
    canvas.drawLine(Offset(left, py(0)), Offset(left, 4), axis);
    _text(
      canvas,
      'beta →',
      Offset(size.width, size.height - 14),
      muted,
      align: TextAlign.right,
    );
    _text(
      canvas,
      '↑ return',
      Offset(left + 6, 0),
      muted,
      align: TextAlign.left,
    );

    canvas.drawLine(
      Offset(px(0), py(rf)),
      Offset(px(xMax), py(ret(xMax))),
      Paint()
        ..color = ink
        ..strokeWidth = 3,
    );
    // The market at beta 1.
    final m = Offset(px(1), py(rm));
    _dashed(
      canvas,
      Offset(m.dx, py(0)),
      m,
      Paint()
        ..color = line
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(m, 6, Paint()..color = ink);
    _text(
      canvas,
      'market',
      m + const Offset(-10, -22),
      ink,
      align: TextAlign.right,
    );
    _text(canvas, '1', Offset(m.dx, size.height - 14), muted);
    // The risk-free rate at beta 0.
    final f = Offset(px(0), py(rf));
    canvas.drawCircle(f, 6, Paint()..color = surface);
    canvas.drawCircle(
      f,
      6,
      Paint()
        ..color = ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5,
    );
    _text(
      canvas,
      'risk-free',
      Offset(left + 2, size.height - 14),
      muted,
      align: TextAlign.left,
    );
    // The stock at its beta, its return the unknown.
    final s = Offset(px(b), py(ret(b)));
    _dashed(
      canvas,
      Offset(s.dx, py(0)),
      s,
      Paint()
        ..color = spark
        ..strokeWidth = 2,
    );
    canvas.drawCircle(s, 8, Paint()..color = spark);
    _text(canvas, 'stock ?', s - const Offset(0, 24), ink, bold: true);
    _text(
      canvas,
      ev(scene.beta!),
      Offset(s.dx, size.height - 14),
      ink,
      bold: true,
    );
  }

  @override
  bool shouldRepaint(_BetaPainter old) =>
      old.scene != scene || old.ink != ink || old.spark != spark;
}

/// A normal curve of one day's gains and losses, the worst 5% or 1% in
/// spark orange.
class BellCurve extends StatelessWidget {
  const BellCurve({super.key, required this.scene, required this.height});

  final RiskScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final conf = scene.confidence!;
    return Semantics(
      label:
          'Bell curve of daily gains and losses, the worst ${100 - conf}% '
          'shaded beyond ${conf == 95 ? '1.65' : '2.33'} standard deviations.',
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _BellPainter(
            conf: conf,
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

class _BellPainter extends CustomPainter {
  _BellPainter({
    required this.conf,
    required this.ink,
    required this.line,
    required this.muted,
    required this.spark,
  });

  final int conf;
  final Color ink, line, muted, spark;

  @override
  void paint(Canvas canvas, Size size) {
    final cut = conf == 95 ? -1.65 : -2.33;
    const lo = -3.2, hi = 3.2, top = 8.0, bottom = 16.0;
    final base = size.height - bottom;
    double px(double z) => (z - lo) / (hi - lo) * size.width;
    double py(double z) => base - exp(-z * z / 2) * (base - top);

    final tail = Path()..moveTo(px(lo), base);
    final curve = Path()..moveTo(px(lo), py(lo));
    for (var i = 0; i <= 128; i++) {
      final z = lo + (hi - lo) * i / 128;
      curve.lineTo(px(z), py(z));
      if (z <= cut) tail.lineTo(px(z), py(z));
    }
    tail
      ..lineTo(px(cut), py(cut))
      ..lineTo(px(cut), base)
      ..close();
    canvas.drawPath(tail, Paint()..color = spark);
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
        ..color = line
        ..strokeWidth = 2,
    );
    _dashed(
      canvas,
      Offset(px(cut), base),
      Offset(px(cut), top + 4),
      Paint()
        ..color = ink
        ..strokeWidth = 1.5,
    );
    _text(
      canvas,
      '−${conf == 95 ? '1.65' : '2.33'}σ',
      Offset(px(cut), base + 2),
      muted,
    );
    _text(canvas, 'average', Offset(px(0), base + 2), muted);
    _text(
      canvas,
      'worst ${100 - conf}%',
      Offset(px(cut) - 6, (base + top) / 2 - 6),
      ink,
      bold: true,
      align: TextAlign.right,
    );
  }

  @override
  bool shouldRepaint(_BellPainter old) =>
      old.conf != conf || old.ink != ink || old.spark != spark;
}

/// Variances on the diagonal, covariance off it; "?" marks the unknown.
class CovGrid extends StatelessWidget {
  const CovGrid({super.key, required this.scene, required this.cell});

  final RiskScene scene;
  final double cell;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cells = scene.cells;
    Widget head(String t) => SizedBox(
      width: 28,
      child: Text(
        t,
        textAlign: TextAlign.center,
        style: lucidText(size: 13, weight: 700, color: p.muted),
      ),
    );
    Widget box(int i) {
      final unknown = cells[i] == '?';
      final diagonal = i == 0 || i == 3;
      return Expanded(
        child: Container(
          height: cell,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: unknown
                ? p.sparkTint
                : diagonal
                ? p.chip
                : p.surface,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: unknown ? p.spark : p.line,
              width: unknown ? 2 : 1.5,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Text(
                cells[i],
                style: lucidText(
                  size: 15,
                  weight: 700,
                  display: true,
                  color: unknown ? p.sparkText : p.ink,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Semantics(
      label:
          'Covariance grid. A with A ${cells[0]}, A with B ${cells[1]}, '
          'B with B ${cells[3]}.',
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 280),
        child: Column(
          children: [
            Row(
              children: [
                head(''),
                Expanded(child: Center(child: head('A'))),
                const SizedBox(width: 8),
                Expanded(child: Center(child: head('B'))),
              ],
            ),
            const SizedBox(height: 4),
            for (final r in [0, 1]) ...[
              if (r > 0) const SizedBox(height: 8),
              Row(
                children: [
                  head(r == 0 ? 'A' : 'B'),
                  box(r * 2),
                  const SizedBox(width: 8),
                  box(r * 2 + 1),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final RiskSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final picked = q.options[state.picked!];
    final right = picked == q.answer;
    // On small phones the working matters more than seeing the card again.
    final picture = d.compact ? null : _picture(q.scene, 84);

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
                size: 22,
                weight: 700,
                display: true,
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
        if (picture != null) ...[
          SizedBox(height: d.compact ? 10 : 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
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
                        q.scene.caption,
                        style: lucidText(size: 14, weight: 600, color: p.ink),
                      ),
                    ),
                    if (q.scene.visual == RiskVisual.bell)
                      Text(
                        'normal model',
                        style: lucidText(size: 12, color: p.muted),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                Center(child: picture),
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
