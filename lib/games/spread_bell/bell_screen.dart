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
import 'bell_controller.dart';
import 'bell_puzzle.dart';
import 'spread_bell_game.dart';

// Built from the "Spread & Bell · play", "· bars" and "· review" artboards.

class BellScreen extends ConsumerWidget {
  const BellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(bellSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const SpreadBellGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(bellSessionProvider),
                  onTrySimilar: ref
                      .read(bellSessionProvider.notifier)
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

  final BellSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(bellSessionProvider.notifier);
    final q = state.question;

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
        key: ValueKey('bell-$i'),
        semanticLabel: 'Answer $text',
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
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
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
          game: const SpreadBellGame(),
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

  final BellQuestion question;

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
              _Chips(chips: q.scene.chips),
              SizedBox(height: d.compact ? 10 : 12),
              BellSceneView(scene: q.scene),
              SizedBox(height: d.compact ? 10 : 12),
              Text(
                q.scene.caption.toUpperCase(),
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

/// The picture on the scene card: a dot strip, dice and coins, a bar chart,
/// a bell curve, two curves, or a scatter of X against Y.
class BellSceneView extends StatelessWidget {
  const BellSceneView({super.key, required this.scene});

  final BellScene scene;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final size = d.compact ? 34.0 : 40.0;
    final h = d.compact ? 96.0 : 112.0;

    Widget paint(CustomPainter painter, double height) => SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(painter: painter),
    );

    final colours = _Colours(
      ink: p.ink,
      muted: p.muted,
      spark: p.spark,
      rule: p.lineStrong,
    );

    switch (scene.visual) {
      case BellVisual.dice:
        if (scene.faces.isNotEmpty) {
          return Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [for (final f in scene.faces) _Die(size: size, face: f)],
          );
        }
        // A few pieces, the rest as "+n".
        int shown(int n, int cap) => n <= cap ? n : cap - 1;
        final dice = shown(scene.dice, scene.coins > 0 ? 3 : 5);
        final coins = shown(scene.coins, scene.dice > 0 ? 3 : 5);
        return Wrap(
          alignment: WrapAlignment.center,
          spacing: 8,
          runSpacing: 8,
          children: [
            for (var i = 0; i < dice; i++) _Die(size: size),
            if (scene.dice > dice) _More(scene.dice - dice, size: size),
            for (var i = 0; i < coins; i++) _Coin(size: size),
            if (scene.coins > coins) _More(scene.coins - coins, size: size),
          ],
        );
      case BellVisual.dots:
        return paint(_DotsPainter(scene, colours), d.compact ? 64 : 72);
      case BellVisual.bars:
        return paint(_BarsPainter(scene, colours), h);
      case BellVisual.bell:
        return BellCurve(scene: scene, height: h);
      case BellVisual.twoBells:
        return paint(_TwoBellsPainter(scene, colours), d.compact ? 84 : 96);
      case BellVisual.scatter:
        return paint(_ScatterPainter(scene, colours), h);
    }
  }
}

/// A bell curve with its shaded share, the mean and the SD ticks labelled.
class BellCurve extends StatelessWidget {
  const BellCurve({super.key, required this.scene, required this.height});

  final BellScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _BellPainter(
          scene,
          _Colours(
            ink: p.ink,
            muted: p.muted,
            spark: p.spark,
            rule: p.lineStrong,
          ),
        ),
      ),
    );
  }
}

class _Colours {
  const _Colours({
    required this.ink,
    required this.muted,
    required this.spark,
    required this.rule,
  });

  final Color ink, muted, spark, rule;

  @override
  bool operator ==(Object other) =>
      other is _Colours &&
      other.ink == ink &&
      other.muted == muted &&
      other.spark == spark &&
      other.rule == rule;

  @override
  int get hashCode => Object.hash(ink, muted, spark, rule);
}

TextPainter _text(String s, TextStyle style) => TextPainter(
  text: TextSpan(text: s, style: style),
  textDirection: TextDirection.ltr,
)..layout();

/// Draws [s] centred on x, its top at y (kept inside [width]).
void _label(
  Canvas canvas,
  String s,
  double x,
  double y,
  TextStyle style,
  double width,
) {
  final tp = _text(s, style);
  final left = (x - tp.width / 2)
      .clamp(0.0, max(0.0, width - tp.width))
      .toDouble();
  tp.paint(canvas, Offset(left, y));
}

double _gauss(double z) => exp(-z * z / 2);

class _BellPainter extends CustomPainter {
  _BellPainter(this.scene, this.c);

  final BellScene scene;
  final _Colours c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const top = 16.0;
    final base = size.height - 22;
    // ±3.6 SDs across the card.
    final unit = (w - 12) / 7.2;
    double xOf(double z) => w / 2 + z * unit;
    double yOf(double z) => base - (base - top) * _gauss(z);
    final small = lucidText(size: 10, color: c.muted);

    for (final (a, b) in scene.shade) {
      final lo = max(a, -3.6), hi = min(b, 3.6);
      if (hi <= lo) continue;
      final path = Path()..moveTo(xOf(lo), base);
      for (var i = 0; i <= 60; i++) {
        final z = lo + (hi - lo) * i / 60;
        path.lineTo(xOf(z), yOf(z));
      }
      path
        ..lineTo(xOf(hi), base)
        ..close();
      canvas.drawPath(path, Paint()..color = c.spark.withValues(alpha: 0.35));
    }

    final curve = Path();
    for (var i = 0; i <= 144; i++) {
      final z = -3.6 + 7.2 * i / 144;
      i == 0 ? curve.moveTo(xOf(z), yOf(z)) : curve.lineTo(xOf(z), yOf(z));
    }
    canvas.drawPath(
      curve,
      Paint()
        ..color = c.ink
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round,
    );
    canvas.drawLine(
      Offset(4, base),
      Offset(w - 4, base),
      Paint()
        ..color = c.rule
        ..strokeWidth = 2,
    );
    // The mean, dashed.
    final dash = Paint()
      ..color = c.muted
      ..strokeWidth = 1.5;
    for (var y = top; y < base; y += 6) {
      canvas.drawLine(Offset(w / 2, y), Offset(w / 2, min(y + 3, base)), dash);
    }
    for (var k = -3; k <= 3; k++) {
      final x = xOf(k.toDouble());
      canvas.drawLine(
        Offset(x, base),
        Offset(x, base + 5),
        Paint()
          ..color = c.muted
          ..strokeWidth = 1.5,
      );
      if (k + 3 < scene.ticks.length) {
        _label(canvas, scene.ticks[k + 3], x, base + 7, small, w);
      }
    }
    final mark = scene.markZ;
    if (mark != null) {
      final x = xOf(mark);
      canvas.drawLine(
        Offset(x, top - 4),
        Offset(x, base),
        Paint()
          ..color = c.spark
          ..strokeWidth = 2.5
          ..strokeCap = StrokeCap.round,
      );
      _label(
        canvas,
        scene.markLabel,
        x,
        -2,
        lucidText(size: 12, weight: 700, display: true, color: c.ink),
        w,
      );
    }
  }

  @override
  bool shouldRepaint(_BellPainter old) => old.scene != scene || old.c != c;
}

class _BarsPainter extends CustomPainter {
  _BarsPainter(this.scene, this.c);

  final BellScene scene;
  final _Colours c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const top = 18.0;
    final base = size.height - 20;
    final bars = scene.bars;
    final tallest = bars.fold(0.0, max);
    final slot = (w - 8) / bars.length;
    final gap = slot > 8 ? 3.0 : 1.0;
    final ink = Paint()..color = c.ink;
    for (final (i, b) in bars.indexed) {
      final x = 4 + i * slot;
      final h = tallest == 0 ? 0.0 : (base - top) * b / tallest;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(x + gap / 2, base - h, slot - gap, h),
          Radius.circular(min(3, (slot - gap) / 2)),
        ),
        ink,
      );
    }
    canvas.drawLine(
      Offset(2, base),
      Offset(w - 2, base),
      Paint()
        ..color = c.rule
        ..strokeWidth = 2,
    );
    final small = lucidText(size: 10, color: c.muted);
    double xOfValue(double v) =>
        4 + ((v - scene.barStart) / scene.barStep + 0.5) * slot;
    final last = scene.barStart + (bars.length - 1) * scene.barStep;
    _label(
      canvas,
      '${scene.barStart}',
      xOfValue(scene.barStart.toDouble()),
      base + 5,
      small,
      w,
    );
    _label(canvas, '$last', xOfValue(last.toDouble()), base + 5, small, w);

    final mx = xOfValue(scene.mean);
    final dash = Paint()
      ..color = c.spark
      ..strokeWidth = 2.5;
    for (var y = top - 6; y < base; y += 7) {
      canvas.drawLine(Offset(mx, y), Offset(mx, min(y + 4, base)), dash);
    }
    final m = scene.mean;
    final meanText = (m - m.round()).abs() < 1e-9
        ? '${m.round()}'
        : m.toStringAsFixed(1);
    final tp = _text(
      'mean $meanText',
      lucidText(size: 12, weight: 700, display: true, color: c.ink),
    );
    // To the right of the line, unless that runs off the card.
    final lx = mx + 6 + tp.width > w ? mx - 6 - tp.width : mx + 6;
    tp.paint(canvas, Offset(lx, 0));
  }

  @override
  bool shouldRepaint(_BarsPainter old) => old.scene != scene || old.c != c;
}

class _DotsPainter extends CustomPainter {
  _DotsPainter(this.scene, this.c);

  final BellScene scene;
  final _Colours c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final base = size.height - 20;
    final unit = (w - 24) / 10;
    double xOf(double v) => 12 + v * unit;
    canvas.drawLine(
      Offset(4, base),
      Offset(w - 4, base),
      Paint()
        ..color = c.rule
        ..strokeWidth = 2,
    );
    final small = lucidText(size: 10, color: c.muted);
    for (var v = 0; v <= 10; v++) {
      canvas.drawLine(
        Offset(xOf(v.toDouble()), base),
        Offset(xOf(v.toDouble()), base + 4),
        Paint()
          ..color = c.rule
          ..strokeWidth = 1.5,
      );
      _label(canvas, '$v', xOf(v.toDouble()), base + 6, small, w);
    }
    final mx = xOf(scene.mean);
    final dash = Paint()
      ..color = c.spark
      ..strokeWidth = 2.5;
    for (var y = 2.0; y < base; y += 7) {
      canvas.drawLine(Offset(mx, y), Offset(mx, min(y + 4, base)), dash);
    }
    final r = min(7.0, unit / 2 - 1);
    final seen = <int, int>{};
    for (final v in scene.values) {
      final stack = seen[v] = (seen[v] ?? 0) + 1;
      canvas.drawCircle(
        Offset(xOf(v.toDouble()), base - r - 2 - (stack - 1) * (2 * r + 2)),
        r,
        Paint()..color = c.ink,
      );
    }
  }

  @override
  bool shouldRepaint(_DotsPainter old) => old.scene != scene || old.c != c;
}

class _TwoBellsPainter extends CustomPainter {
  _TwoBellsPainter(this.scene, this.c);

  final BellScene scene;
  final _Colours c;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    const top = 18.0;
    final base = size.height - 4;
    final r = scene.ratio;
    // The wider curve fills the card; heights go as 1 ÷ SD.
    final wide = max(1.0, r);
    final unit = (w - 8) / (7.2 * wide);
    final sds = [1.0, r];
    final tall = max(1.0, 1 / r);
    final colours = [c.ink, c.spark];
    final labels = [scene.labels.$1, scene.labels.$2];
    final style = lucidText(size: 12, weight: 700, display: true, color: c.ink);
    canvas.drawLine(
      Offset(2, base),
      Offset(w - 2, base),
      Paint()
        ..color = c.rule
        ..strokeWidth = 2,
    );
    for (var j = 0; j < 2; j++) {
      final s = sds[j];
      final peak = (base - top) * (1 / s) / tall;
      final path = Path();
      for (var i = 0; i <= 144; i++) {
        final z = (-3.6 + 7.2 * i / 144) * wide;
        final x = w / 2 + z * unit;
        final y = base - peak * _gauss(z / s);
        i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colours[j]
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.5
          ..strokeJoin = StrokeJoin.round,
      );
      // The narrow curve is named over its peak, the wide one on its
      // right shoulder.
      final narrow = s == min(1.0, r);
      final tp = _text(labels[j], style);
      if (narrow) {
        tp.paint(
          canvas,
          Offset(w / 2 - tp.width / 2, base - peak - tp.height - 2),
        );
      } else {
        final x = w / 2 + 1.4 * s * unit;
        final y = base - peak * _gauss(1.4);
        tp.paint(canvas, Offset(min(w - tp.width, x + 4), y - tp.height - 2));
      }
    }
  }

  @override
  bool shouldRepaint(_TwoBellsPainter old) => old.scene != scene || old.c != c;
}

class _ScatterPainter extends CustomPainter {
  _ScatterPainter(this.scene, this.c);

  final BellScene scene;
  final _Colours c;

  @override
  void paint(Canvas canvas, Size size) {
    final h = size.height;
    final side = h - 8;
    final left = (size.width - side) / 2;
    final axis = Paint()
      ..color = c.rule
      ..strokeWidth = 2;
    canvas.drawLine(Offset(left, h - 4), Offset(left + side, h - 4), axis);
    canvas.drawLine(Offset(left, 4), Offset(left, h - 4), axis);
    final style = lucidText(size: 11, weight: 700, color: c.muted);
    _text('X', style).paint(canvas, Offset(left + side + 4, h - 16));
    _text('Y', style).paint(canvas, Offset(left - 12, 0));
    // The same points every time, leaning with the correlation.
    final rng = Random(7);
    double normal() {
      final u = 1 - rng.nextDouble();
      return sqrt(-2 * log(u)) * cos(2 * pi * rng.nextDouble());
    }

    final rho = scene.rho.clamp(-0.95, 0.95);
    final dot = Paint()..color = c.ink;
    for (var i = 0; i < 28; i++) {
      final a = normal(), b = normal();
      final x = a.clamp(-2.4, 2.4);
      final y = (rho * a + sqrt(1 - rho * rho) * b).clamp(-2.4, 2.4);
      canvas.drawCircle(
        Offset(left + side / 2 + x * side / 5.6, h / 2 - y * side / 5.6),
        3.5,
        dot,
      );
    }
  }

  @override
  bool shouldRepaint(_ScatterPainter old) => old.scene != scene || old.c != c;
}

class _Die extends StatelessWidget {
  const _Die({required this.size, this.face});

  final double size;

  /// Null: an unknown roll ("?").
  final int? face;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = face;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: p.ink, width: 2),
      ),
      child: Center(
        child: Text(
          f == null ? '?' : '$f',
          style: lucidText(
            size: size * 0.45,
            weight: 700,
            display: true,
            color: f == null ? p.muted : p.ink,
          ),
        ),
      ),
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.sparkTint,
        shape: BoxShape.circle,
        border: Border.all(color: p.ink, width: 2),
      ),
      child: Text(
        '?',
        style: lucidText(
          size: size * 0.42,
          weight: 700,
          display: true,
          color: p.sparkText,
        ),
      ),
    );
  }
}

class _More extends StatelessWidget {
  const _More(this.n, {required this.size});

  final int n;
  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      height: size,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: p.chip,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Center(
        widthFactor: 1,
        child: Text(
          '+$n',
          style: lucidText(size: 15, weight: 700, display: true, color: p.ink),
        ),
      ),
    );
  }
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final BellSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final pick = state.picked!;
    final picked = q.options[pick];
    final right = picked == q.answer;

    Widget tile(String value, String? near, String label, bool good) {
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
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                value,
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
    }

    final mine = tile(picked, q.notes[pick], 'Your answer', false);
    final best = tile(
      q.answer,
      q.answerNote,
      right ? 'Your answer · right' : 'Right',
      true,
    );

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
        if (q.scene.visual == BellVisual.bell) ...[
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
                        'The curve',
                        style: lucidText(size: 14, weight: 600, color: p.ink),
                      ),
                    ),
                    Flexible(
                      child: Text(
                        q.scene.note,
                        textAlign: TextAlign.right,
                        style: lucidText(size: 12, color: p.muted),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                BellCurve(scene: q.scene, height: d.compact ? 88 : 104),
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
