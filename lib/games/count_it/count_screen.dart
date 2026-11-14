import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'count_controller.dart';
import 'count_it_game.dart';
import 'count_puzzle.dart';

// Built from the "Count It · question" and "· worked answer" artboards.

class CountScreen extends ConsumerWidget {
  const CountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(countSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const CountItGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(countSessionProvider),
                  onTrySimilar: ref
                      .read(countSessionProvider.notifier)
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

  final CountSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(countSessionProvider.notifier);
    final q = state.question;

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
          game: const CountItGame(),
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
                  'Count in steps. Ask: does order matter?',
                  textAlign: TextAlign.center,
                  style: lucidText(size: d.small, color: p.muted),
                ),
                SizedBox(height: d.gapS),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: d.compact ? 2.8 : 2.45,
                  children: [
                    for (final (i, option) in q.options.indexed)
                      PressScale(
                        key: ValueKey('count-$i'),
                        semanticLabel: 'Answer ${fmt(option)}',
                        onTap: () => choose(i),
                        child: Container(
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: p.surface,
                            borderRadius: BorderRadius.circular(
                              d.compact ? 16 : 18,
                            ),
                            border: Border.all(color: p.line, width: 1.5),
                          ),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Text(
                                fmt(option),
                                style: lucidText(
                                  size: d.compact ? 22 : 26,
                                  weight: 700,
                                  display: true,
                                  color: p.ink,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _Question extends StatelessWidget {
  const _Question({required this.question});

  final CountQuestion question;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        CountSceneCard(scene: question.scene),
        SizedBox(height: d.gapL),
        Text(
          question.question,
          textAlign: TextAlign.center,
          style: lucidText(
            size: d.compact ? 20 : 24,
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

/// After answering: the picture again (smaller), the question, your pick and
/// the right count, and three steps of working.
class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final CountSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final picked = q.options[state.picked!];
    final right = picked == q.answer;

    Widget tile(int value, String label, bool good) => Expanded(
      child: Container(
        height: d.compact ? 58 : 64,
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
                fmt(value),
                style: lucidText(
                  size: 22,
                  weight: 700,
                  display: true,
                  color: p.ink,
                ),
              ),
            ),
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
      ),
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        CountScenePicture(scene: q.scene, small: true),
        const SizedBox(height: 10),
        Text(
          q.question,
          textAlign: TextAlign.center,
          style: lucidText(size: d.body, color: p.muted, height: 1.45),
        ),
        SizedBox(height: d.gapM),
        Semantics(
          label: right
              ? 'Your answer ${fmt(picked)} is right'
              : 'Your answer ${fmt(picked)}. Right answer ${fmt(q.answer)}',
          excludeSemantics: true,
          child: Row(
            children: [
              if (!right) ...[
                tile(picked, 'Your answer', false),
                const SizedBox(width: 12),
              ],
              tile(q.answer, right ? 'Your answer · right' : 'Right', true),
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

/// The setup in a card, with its caption.
class CountSceneCard extends StatelessWidget {
  const CountSceneCard({super.key, required this.scene});

  final CountScene scene;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: d.compact ? 16 : 22,
        horizontal: 16,
      ),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: p.line),
      ),
      child: Column(
        children: [
          CountScenePicture(scene: scene),
          SizedBox(height: d.compact ? 10 : 14),
          Text(
            scene.caption.toUpperCase(),
            textAlign: TextAlign.center,
            style: lucidLabel(p.muted),
          ),
        ],
      ),
    );
  }
}

class CountScenePicture extends StatelessWidget {
  const CountScenePicture({super.key, required this.scene, this.small = false});

  final CountScene scene;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final s = scene;
    final k = small ? 0.66 : (d.compact ? 0.82 : 1.0);

    Widget circle(String label, {bool filled = false, double size = 36}) =>
        Container(
          width: size * k,
          height: size * k,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: filled ? p.ink : p.surface,
            border: Border.all(color: p.ink, width: 2),
          ),
          child: Text(
            label,
            style: lucidText(
              size: 14 * k,
              weight: 700,
              display: true,
              color: filled ? p.onInk : p.ink,
            ),
          ),
        );

    Widget box(String label, {double w = 34, double h = 34, double r = 10}) =>
        Container(
          width: w * k,
          height: h * k,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.surface,
            borderRadius: BorderRadius.circular(r),
            border: Border.all(color: p.ink, width: 2),
          ),
          child: Text(
            label,
            style: lucidText(
              size: (h > 40 ? 20 : 14) * k,
              weight: 700,
              display: true,
              color: p.ink,
            ),
          ),
        );

    final Widget picture = switch (s.type) {
      SceneType.people => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (i, l) in s.labels.indexed)
            circle(l, filled: s.marked.contains(i)),
        ],
      ),
      SceneType.tokens => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [for (final l in s.labels) box(l)],
      ),
      SceneType.tiles => Wrap(
        alignment: WrapAlignment.center,
        spacing: 8,
        runSpacing: 8,
        children: [for (final l in s.labels) box(l, w: 40, h: 44)],
      ),
      SceneType.code => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < s.a; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Container(
              width: 44 * k,
              height: 52 * k,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: p.chip,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '?',
                style: lucidText(
                  size: 22 * k,
                  weight: 700,
                  display: true,
                  color: p.faint,
                ),
              ),
            ),
          ],
        ],
      ),
      SceneType.grid => _StreetGrid(w: s.a, h: s.b, scale: k),
      SceneType.strip => Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 6,
        runSpacing: 6,
        children: [
          for (var i = 1; i <= 6; i++) box('$i', w: 32, h: 32, r: 8),
          Text('…', style: lucidText(size: 20, weight: 700, color: p.muted)),
          box('${s.a}', w: 44, h: 32, r: 8),
        ],
      ),
      SceneType.sweets => Column(
        children: [
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            runSpacing: 6,
            children: [
              for (var i = 0; i < s.a; i++)
                Container(
                  width: 18 * k,
                  height: 18 * k,
                  decoration: BoxDecoration(
                    color: p.spark,
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
          SizedBox(height: 12 * k),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [for (final l in s.labels) circle(l)],
          ),
        ],
      ),
    };

    return Semantics(
      label: s.caption,
      excludeSemantics: true,
      child: Center(child: picture),
    );
  }
}

/// Streets: [w] blocks across, [h] up, from A (bottom left) to B (top right).
class _StreetGrid extends StatelessWidget {
  const _StreetGrid({required this.w, required this.h, required this.scale});

  final int w;
  final int h;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final cell = (160 / w).clamp(28.0, 54.0) * scale;
    return SizedBox(
      width: cell * w + 24,
      height: cell * h + 24,
      child: CustomPaint(
        painter: _GridPainter(
          w: w,
          h: h,
          cell: cell,
          line: p.lineStrong,
          ink: p.ink,
          onInk: p.onInk,
          spark: p.spark,
          onSpark: p.onSpark,
        ),
      ),
    );
  }
}

class _GridPainter extends CustomPainter {
  _GridPainter({
    required this.w,
    required this.h,
    required this.cell,
    required this.line,
    required this.ink,
    required this.onInk,
    required this.spark,
    required this.onSpark,
  });

  final int w, h;
  final double cell;
  final Color line, ink, onInk, spark, onSpark;

  @override
  void paint(Canvas canvas, Size size) {
    const o = 12.0;
    final street = Paint()
      ..color = line
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    for (var y = 0; y <= h; y++) {
      canvas.drawLine(
        Offset(o, o + y * cell),
        Offset(o + w * cell, o + y * cell),
        street,
      );
    }
    for (var x = 0; x <= w; x++) {
      canvas.drawLine(
        Offset(o + x * cell, o),
        Offset(o + x * cell, o + h * cell),
        street,
      );
    }
    void dot(Offset c, Color fill, Color text, String label) {
      canvas.drawCircle(c, 10, Paint()..color = fill);
      final tp = TextPainter(
        text: TextSpan(
          text: label,
          style: lucidText(size: 11, weight: 700, display: true, color: text),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }

    dot(Offset(o, o + h * cell), ink, onInk, 'A');
    dot(Offset(o + w * cell, o), spark, onSpark, 'B');
  }

  @override
  bool shouldRepaint(_GridPainter old) =>
      old.w != w || old.h != h || old.cell != cell || old.ink != ink;
}
