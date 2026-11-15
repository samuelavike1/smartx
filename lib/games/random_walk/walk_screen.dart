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
import '../expect_it/expect_puzzle.dart' show about;
import '../odds_on/odds_math.dart';
import 'random_walk_game.dart';
import 'walk_controller.dart';
import 'walk_puzzle.dart';

// Built from the "Random Walk · fair walk", "· the cliff" and "· review"
// artboards.

class WalkScreen extends ConsumerWidget {
  const WalkScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(walkSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const RandomWalkGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(walkSessionProvider),
                  onTrySimilar: ref
                      .read(walkSessionProvider.notifier)
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

  final WalkSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(walkSessionProvider.notifier);
    final q = state.question;

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    Widget option(int i) {
      final text = q.options[i];
      // Money already says "about"; plain fractions get it underneath.
      final near = text.startsWith('about') || text.startsWith('\$')
          ? null
          : about(q.optionValues[i]);
      return PressScale(
        key: ValueKey('walk-$i'),
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
          game: const RandomWalkGame(),
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

  final WalkQuestion question;

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
            horizontal: 12,
          ),
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: [
              _Chips(chips: q.scene.chips),
              SizedBox(height: d.compact ? 6 : 10),
              WalkTrack(scene: q.scene, height: d.compact ? 92 : 108),
              const SizedBox(height: 8),
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

/// The numbered track: where the walk starts (spark orange), its step
/// chances, and what stops it.
class WalkTrack extends StatelessWidget {
  const WalkTrack({super.key, required this.scene, required this.height});

  final WalkScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _TrackPainter(
          scene: scene,
          ink: p.ink,
          muted: p.muted,
          rule: p.lineStrong,
          spark: p.spark,
        ),
      ),
    );
  }
}

TextPainter _text(String s, TextStyle style) => TextPainter(
  text: TextSpan(text: s, style: style),
  textDirection: TextDirection.ltr,
)..layout();

class _TrackPainter extends CustomPainter {
  _TrackPainter({
    required this.scene,
    required this.ink,
    required this.muted,
    required this.rule,
    required this.spark,
  });

  final WalkScene scene;
  final Color ink, muted, rule, spark;

  @override
  void paint(Canvas canvas, Size size) {
    final s = scene;
    final left = 22.0 + (s.openLeft ? 14 : 0);
    final right = size.width - 22 - (s.openRight ? 14 : 0) - (s.flag ? 12 : 0);
    final y = size.height * 0.62;
    final count = s.hi - s.lo;
    final gap = (right - left) / count;
    double xOf(int k) => left + (k - s.lo) * gap;

    final line = Paint()
      ..color = rule
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(Offset(left, y), Offset(right, y), line);

    final small = lucidText(size: 11, weight: 500, color: muted);
    void label(String t, double x, double cy, TextStyle style) {
      final tp = _text(t, style);
      tp.paint(canvas, Offset(x - tp.width / 2, cy - tp.height / 2));
    }

    if (s.openLeft) label('…', left - 14, y, small);
    if (s.openRight) label('…', right + 14, y, small);

    // Numbers: all of them on short tracks; ends, start and every fifth
    // on long ones.
    for (var k = s.lo; k <= s.hi; k++) {
      final x = xOf(k);
      canvas.drawCircle(Offset(x, y), 4.5, Paint()..color = rule);
      final show =
          count <= 10 || k == s.lo || k == s.hi || k == s.start || k % 5 == 0;
      if (show) {
        label(s.money ? '\$$k' : '$k', x, y + 20, small);
      }
    }

    // What stops the walk.
    if (s.broke) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(center: Offset(xOf(s.lo), y), width: 16, height: 16),
          const Radius.circular(4),
        ),
        Paint()..color = ink,
      );
    }
    if (s.cliff) {
      final x = xOf(s.lo) - 10;
      final pen = Paint()
        ..color = ink
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(x, y - 12), Offset(x, y + 14), pen);
      for (var i = 0; i < 4; i++) {
        final hy = y - 8 + i * 7.0;
        canvas.drawLine(Offset(x - 6, hy + 4), Offset(x, hy), pen);
      }
    }
    if (s.flag) {
      final x = xOf(s.hi);
      final pen = Paint()
        ..color = ink
        ..strokeWidth = 2.5;
      canvas.drawLine(Offset(x, y), Offset(x, y - 30), pen);
      final flag = Path()
        ..moveTo(x, y - 30)
        ..lineTo(x + 16, y - 30)
        ..lineTo(x + 11, y - 25)
        ..lineTo(x + 16, y - 20)
        ..lineTo(x, y - 20)
        ..close();
      canvas.drawPath(flag, Paint()..color = ink);
    }

    // The walker and its step chances.
    final tx = xOf(s.start);
    canvas.drawCircle(Offset(tx, y), 10, Paint()..color = spark);
    final arrow = lucidText(size: 13, weight: 700, display: true, color: ink);
    final ay = y - 30;
    final leftText = '← ${WalkGenerator.chance(s.down)}';
    final rightText = '${WalkGenerator.chance(s.up)} →';
    final lw = _text(leftText, arrow).width;
    final rw = _text(rightText, arrow).width;
    // Keep both arrows on the card and clear of the flag.
    final lx = max(lw / 2, tx - 30);
    final rx = min(size.width - rw / 2 - (s.flag ? 22 : 0), tx + 30);
    label(leftText, lx, ay, arrow);
    label(rightText, rx, ay, arrow);
    if (s.stay > Frac.zero) {
      label('stay ${WalkGenerator.chance(s.stay)}', tx, ay - 18, small);
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) =>
      old.scene != scene || old.ink != ink || old.spark != spark;
}

/// One possible walk with the question's rules, drawn over time.
class WalkPathChart extends StatelessWidget {
  const WalkPathChart({super.key, required this.scene, required this.seed});

  final WalkScene scene;
  final int seed;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final path = scene.sample(Random(seed));
    final end = path.last;
    final steps = path.length - 1;
    final unit = scene.money ? '\$' : '';
    final String result;
    if (scene.fixedSteps != null) {
      result = 'ended at $unit$end';
    } else if (scene.flag && end >= scene.hi) {
      result = 'reached $unit${scene.hi}';
    } else if (scene.cliff && end <= scene.lo) {
      result = 'stepped off';
    } else if (scene.broke && end <= scene.lo) {
      result = scene.money ? 'went broke' : 'reached 0';
    } else {
      result = 'still going';
    }
    return Container(
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
                  'One possible walk',
                  style: lucidText(size: 14, weight: 600, color: p.ink),
                ),
              ),
              Text(
                '$steps steps · $result',
                style: lucidText(size: 12, color: p.muted),
              ),
            ],
          ),
          const SizedBox(height: 6),
          SizedBox(
            height: 84,
            child: CustomPaint(
              painter: _PathPainter(
                scene: scene,
                path: path,
                ink: p.ink,
                muted: p.muted,
                spark: p.spark,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PathPainter extends CustomPainter {
  _PathPainter({
    required this.scene,
    required this.path,
    required this.ink,
    required this.muted,
    required this.spark,
  });

  final WalkScene scene;
  final List<int> path;
  final Color ink, muted, spark;

  @override
  void paint(Canvas canvas, Size size) {
    var top = path.reduce(max);
    var bottom = path.reduce(min);
    if (scene.flag) top = max(top, scene.hi);
    if (scene.stopsAtLo) bottom = min(bottom, scene.lo);
    if (top == bottom) top++;
    const pad = 6.0;
    final h = size.height - 2 * pad;
    final w = size.width - 30;
    double yOf(int v) => pad + (top - v) / (top - bottom) * h;
    double xOf(int t) => path.length == 1 ? 0 : t / (path.length - 1) * w;

    final small = lucidText(size: 10, color: muted);
    void tag(String t, double y) {
      final tp = _text(t, small);
      tp.paint(canvas, Offset(size.width - tp.width, y - tp.height / 2));
    }

    final rule = Paint()
      ..color = ink
      ..strokeWidth = 2;
    final unit = scene.money ? '\$' : '';
    if (scene.flag) {
      final y = yOf(scene.hi);
      for (var x = 0.0; x < w; x += 8) {
        canvas.drawLine(Offset(x, y), Offset(min(x + 4, w), y), rule);
      }
      tag('$unit${scene.hi}', y);
    }
    if (scene.stopsAtLo) {
      final y = yOf(scene.lo);
      canvas.drawLine(Offset(0, y), Offset(w, y), rule);
      tag(scene.cliff ? 'edge' : '$unit${scene.lo}', y);
    }
    if (!scene.flag && !scene.stopsAtLo) {
      tag('$unit${scene.start}', yOf(scene.start));
    }

    final line = Path()..moveTo(xOf(0), yOf(path.first));
    for (var t = 1; t < path.length; t++) {
      line.lineTo(xOf(t), yOf(path[t]));
    }
    canvas.drawPath(
      line,
      Paint()
        ..color = spark
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(
      Offset(xOf(path.length - 1), yOf(path.last)),
      4.5,
      Paint()..color = spark,
    );
  }

  @override
  bool shouldRepaint(_PathPainter old) =>
      old.path != path || old.ink != ink || old.spark != spark;
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final WalkSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final pick = state.picked!;
    final picked = q.options[pick];
    final right = picked == q.answer;

    Widget tile(String value, Frac v, String label, bool good) {
      final near = value.startsWith('about') || value.startsWith('\$')
          ? null
          : about(v);
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

    final mine = tile(picked, q.optionValues[pick], 'Your answer', false);
    final best = tile(
      q.answer,
      q.answerValue,
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
        SizedBox(height: d.gapM),
        WalkPathChart(scene: q.scene, seed: q.seed),
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
