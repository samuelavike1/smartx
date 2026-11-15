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
import '../odds_on/odds_math.dart';
import 'expect_controller.dart';
import 'expect_it_game.dart';
import 'expect_puzzle.dart';

// Built from the "Expect It · dice", "· stick" and "· review" artboards.

class ExpectScreen extends ConsumerWidget {
  const ExpectScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(expSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const ExpectItGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(expSessionProvider),
                  onTrySimilar: ref
                      .read(expSessionProvider.notifier)
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

  final ExpSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(expSessionProvider.notifier);
    final q = state.question;

    void choose(int i) {
      c.select(i);
      i == q.answerIndex
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    Widget option(int i) {
      final text = q.options[i];
      final near = about(q.optionValues[i]);
      return PressScale(
        key: ValueKey('exp-$i'),
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
          game: const ExpectItGame(),
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

  final ExpQuestion question;

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
              SizedBox(height: d.compact ? 12 : 14),
              ExpSceneView(scene: q.scene),
              const SizedBox(height: 12),
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

/// The picture on the scene card: dice, faces, coins, hats, cards or a
/// stick.
class ExpSceneView extends StatelessWidget {
  const ExpSceneView({super.key, required this.scene});

  final ExpScene scene;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final size = d.compact ? 34.0 : 40.0;

    Widget row(List<Widget> items) => Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: items,
    );

    List<Widget> some(int count, Widget Function() one, {int most = 4}) => [
      for (var i = 0; i < min(count, count > most ? most - 1 : most); i++)
        one(),
      if (count > most) _More(count - (most - 1), size: size),
    ];

    switch (scene.visual) {
      case ExpVisual.dice:
        return row(some(scene.count, () => _Die(size: size)));
      case ExpVisual.faces:
        return row([
          for (final f in scene.faces)
            _Die(size: size, face: f, pips: scene.pips),
        ]);
      case ExpVisual.coins:
        return row(some(scene.count, () => _Coin(size: size), most: 6));
      case ExpVisual.diceCoins:
        return row([
          ...some(scene.count, () => _Die(size: size), most: 3),
          ...some(scene.coins, () => _Coin(size: size), most: 3),
        ]);
      case ExpVisual.hats:
        return row(some(scene.count, () => _Person(size: size), most: 6));
      case ExpVisual.cards:
        return row([
          for (var i = 0; i < scene.count; i++) _CardBack(size: size),
        ]);
      case ExpVisual.stick:
        return StickView(scene: scene, height: d.compact ? 80 : 92);
    }
  }
}

class _Die extends StatelessWidget {
  const _Die({required this.size, this.face, this.pips = false});

  final double size;

  /// Null: an unknown roll ("?").
  final int? face;
  final bool pips;

  static const _spots = {
    1: [(1, 1)],
    2: [(0, 0), (2, 2)],
    3: [(0, 0), (1, 1), (2, 2)],
    4: [(0, 0), (2, 0), (0, 2), (2, 2)],
    5: [(0, 0), (2, 0), (1, 1), (0, 2), (2, 2)],
    6: [(0, 0), (2, 0), (0, 1), (2, 1), (0, 2), (2, 2)],
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final f = face;
    final dot = size * 0.17;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: p.ink, width: 2),
      ),
      child: f != null && pips
          ? Padding(
              padding: EdgeInsets.all(size * 0.14),
              child: Stack(
                children: [
                  for (final (x, y) in _spots[f]!)
                    Align(
                      alignment: Alignment(x - 1.0, y - 1.0),
                      child: Container(
                        width: dot,
                        height: dot,
                        decoration: BoxDecoration(
                          color: p.ink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            )
          : Center(
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

class _Person extends StatelessWidget {
  const _Person({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: p.chip, shape: BoxShape.circle),
      child: Icon(Icons.person_rounded, color: p.ink, size: size * 0.62),
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size * 0.78,
      height: size * 1.1,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: p.ink,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: p.spark, width: 1.5),
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
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: p.chip,
        borderRadius: BorderRadius.circular(size * 0.25),
      ),
      child: Text(
        '+$n',
        style: lucidText(size: 15, weight: 700, display: true, color: p.ink),
      ),
    );
  }
}

/// A stick with its length marked, and either one break or a few random
/// points (spark orange, unknown).
class StickView extends StatelessWidget {
  const StickView({super.key, required this.scene, required this.height});

  final ExpScene scene;
  final double height;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _StickPainter(
          scene: scene,
          ink: p.ink,
          muted: p.muted,
          spark: p.spark,
          onSpark: p.onSpark,
          rule: p.lineStrong,
        ),
      ),
    );
  }
}

class _StickPainter extends CustomPainter {
  _StickPainter({
    required this.scene,
    required this.ink,
    required this.muted,
    required this.spark,
    required this.onSpark,
    required this.rule,
  });

  final ExpScene scene;
  final Color ink, muted, spark, onSpark, rule;

  /// Where the unknown points are drawn: spread out, never on the ends.
  static const _spots = [0.32, 0.68, 0.18, 0.84, 0.5];

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 8.0;
    final left = pad;
    final right = size.width - pad;
    final barY = size.height * 0.5;
    const barH = 12.0;

    void label(String text, Offset at, TextAlign align, {bool bold = false}) {
      final tp = TextPainter(
        text: TextSpan(
          text: text,
          style: lucidText(
            size: 11,
            weight: bold ? 700 : 500,
            display: bold,
            color: bold ? onSpark : muted,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final dx = switch (align) {
        TextAlign.center => at.dx - tp.width / 2,
        TextAlign.right => at.dx - tp.width,
        _ => at.dx,
      };
      tp.paint(canvas, Offset(dx, at.dy - tp.height / 2));
    }

    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTRB(left, barY - barH / 2, right, barY + barH / 2),
        const Radius.circular(barH / 2),
      ),
      Paint()..color = ink,
    );
    label('0', Offset(left, size.height - 8), TextAlign.left);
    label(
      '${scene.length} cm',
      Offset(right, size.height - 8),
      TextAlign.right,
    );

    final n = scene.breakStick ? 1 : scene.points;
    for (var i = 0; i < n; i++) {
      final x = left + (right - left) * _spots[i % _spots.length];
      final mark = Paint()
        ..color = spark
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round;
      if (scene.breakStick) {
        canvas.drawLine(Offset(x, barY - barH), Offset(x, barY + barH), mark);
      }
      final dotY = barY - barH - 9;
      canvas.drawCircle(
        Offset(x, scene.breakStick ? dotY : barY),
        scene.breakStick ? 9 : 7,
        Paint()..color = spark,
      );
      if (scene.breakStick) {
        label('?', Offset(x, dotY), TextAlign.center, bold: true);
      }
    }
  }

  @override
  bool shouldRepaint(_StickPainter old) =>
      old.scene != scene || old.ink != ink || old.spark != spark;
}

class _Worked extends StatelessWidget {
  const _Worked({required this.state});

  final ExpSessionState state;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final q = state.question;
    final pick = state.picked!;
    final picked = q.options[pick];
    final right = picked == q.answer;

    Widget tile(String value, Frac v, String label, bool good) {
      final near = about(v);
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
