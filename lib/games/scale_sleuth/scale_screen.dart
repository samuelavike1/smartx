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
import 'scale_controller.dart';
import 'scale_puzzle.dart';
import 'scale_sleuth_game.dart';

// Built from the "Scale Sleuth · weigh" and "· worked answer" artboards.

class ScaleScreen extends ConsumerWidget {
  const ScaleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(scaleSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const ScaleSleuthGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(scaleSessionProvider),
                  onTrySimilar: ref
                      .read(scaleSessionProvider.notifier)
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

  final ScaleSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(scaleSessionProvider.notifier);
    final s = state;
    final q = s.puzzle;
    final slip = s.answered ? q.slip : null;

    void weigh() {
      HapticFeedback.selectionClick();
      c.weigh();
    }

    void name() {
      c.name();
      ref.read(scaleSessionProvider).lastCorrect
          ? HapticFeedback.lightImpact()
          : HapticFeedback.mediumImpact();
    }

    final hint = s.naming
        ? 'Tap the coin you think is fake.'
        : (s.left.isEmpty && s.right.isEmpty
              ? (q.log.isEmpty
                    ? 'Tap coins to load the ${s.pan.name} pan.'
                    : _clearedHint(q))
              : (s.left.length != s.right.length
                    ? 'Same number of coins on each side to weigh.'
                    : (s.weighed
                          ? 'Change the pans to weigh again.'
                          : _clearedHint(q))));

    return GameLayout(
      header: [
        GameTopBar(
          filled: s.round + (s.answered ? 1 : 0),
          total: s.totalRounds,
          score: s.score,
          game: const ScaleSleuthGame(),
        ),
        SizedBox(height: d.compact ? 10 : 14),
        LevelComboRow(level: s.level, combo: s.combo, practice: s.practice),
      ],
      body: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: d.gapM),
          if (!s.answered) ...[
            Text(
              'Find the fake coin',
              textAlign: TextAlign.center,
              style: lucidText(
                size: d.compact ? 20 : 22,
                weight: 600,
                display: true,
                color: scheme.onSurface,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              q.question,
              textAlign: TextAlign.center,
              style: lucidText(
                size: d.body,
                color: scheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 8),
            _WeighingsLeft(left: q.weighingsLeft, total: q.setup.weighings),
            SizedBox(height: d.gapM),
          ],
          _Balance(
            left: s.left,
            right: s.right,
            tilt: s.tilt,
            active: s.answered || s.naming ? null : s.pan,
            cleared: q.cleared,
            onPan: c.choosePan,
            small: s.answered,
          ),
          if (q.log.isNotEmpty) ...[
            SizedBox(height: d.gapM),
            for (final (i, w) in q.log.indexed) ...[
              if (i > 0) const SizedBox(height: 8),
              _LogRow(
                index: i + 1,
                weighing: w,
                slipNote: slip?.$1 == i + 1 ? q.slipNote(i + 1) : null,
              ),
            ],
          ],
          SizedBox(height: d.gapM),
          if (!s.answered && !s.naming) ...[
            _PanSwitch(
              pan: s.pan,
              onPan: c.choosePan,
              onClear: s.left.isEmpty && s.right.isEmpty ? null : c.clearPans,
            ),
            const SizedBox(height: 10),
          ],
          _Tray(state: s, onTap: c.tapCoin),
          SizedBox(height: d.gapM),
        ],
      ),
      dock: s.answered
          ? FeedbackSlot(
              child: FeedbackCard(
                correct: s.lastCorrect,
                points: s.lastPoints,
                explanation: q.feedbackFor(s.reveal!),
                isLastRound: s.round + 1 >= s.totalRounds,
                onNext: c.next,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  hint,
                  textAlign: TextAlign.center,
                  style: lucidText(size: d.small, color: p.muted),
                ),
                SizedBox(height: d.gapS),
                SizedBox(
                  height: d.compact ? 52 : 60,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: s.naming
                        ? [
                            if (q.weighingsLeft > 0) ...[
                              Expanded(
                                flex: 4,
                                child: _DockButton(
                                  key: const ValueKey('scale-keep'),
                                  label: 'Keep weighing',
                                  onTap: c.keepWeighing,
                                ),
                              ),
                              const SizedBox(width: 10),
                            ],
                            Expanded(
                              flex: 5,
                              child: _DockButton(
                                key: const ValueKey('scale-confirm'),
                                label: s.selected == null
                                    ? 'Name the fake'
                                    : 'Name coin ${s.selected}',
                                primary: true,
                                onTap: s.selected == null ? null : name,
                              ),
                            ),
                          ]
                        : [
                            Expanded(
                              flex: 4,
                              child: _DockButton(
                                key: const ValueKey('scale-name'),
                                label: 'Name the fake',
                                onTap: c.startNaming,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              flex: 5,
                              child: _DockButton(
                                key: const ValueKey('scale-weigh'),
                                label: s.canWeigh
                                    ? 'Weigh ${s.left.length} vs '
                                          '${s.right.length}'
                                    : 'Weigh',
                                primary: true,
                                onTap: s.canWeigh ? weigh : null,
                              ),
                            ),
                          ],
                  ),
                ),
              ],
            ),
    );
  }

  static String _clearedHint(ScalePuzzle q) {
    if (q.log.isEmpty) {
      return 'Each weighing has three results: left, right or level.';
    }
    return q.told
        ? 'Grey coins are proven real. They make good fillers.'
        : 'Grey: proven real. ▲ only heavier, ▼ only lighter.';
  }
}

class _WeighingsLeft extends StatelessWidget {
  const _WeighingsLeft({required this.left, required this.total});

  final int left;
  final int total;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Semantics(
      label: '$left of $total weighings left',
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Weighings left',
            style: lucidText(size: 13, weight: 600, color: p.muted),
          ),
          for (var i = 0; i < total; i++) ...[
            const SizedBox(width: 6),
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: i < left ? p.ink : null,
                border: i < left
                    ? null
                    : Border.all(color: p.lineStrong, width: 1.5),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// The balance: post, beam and two pans holding the coins on them. Tapping a
/// pan makes it the one coins go onto; the beam tips after a weighing.
class _Balance extends StatelessWidget {
  const _Balance({
    required this.left,
    required this.right,
    required this.tilt,
    required this.active,
    required this.cleared,
    required this.onPan,
    this.small = false,
  });

  final List<int> left;
  final List<int> right;
  final Tilt? tilt;
  final Pan? active;
  final bool Function(int) cleared;
  final void Function(Pan) onPan;

  /// The review's shorter balance, leaving room for the log and the tray.
  final bool small;

  static const _panW = 136.0;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final p = context.palette;
    final h = (d.compact ? 128.0 : 150.0) - (small ? 20 : 0);
    final beamY = d.compact || small ? 24.0 : 30.0;
    final mini = d.compact ? 22.0 : 24.0;
    final angle = switch (tilt) {
      Tilt.left => 0.14,
      Tilt.right => -0.14,
      _ => 0.0,
    };
    final reading = switch (tilt) {
      null => 'Not weighed yet',
      final t => t.label,
    };

    return Semantics(
      label: 'Balance. $reading.',
      child: SizedBox(
        height: h,
        child: LayoutBuilder(
          builder: (context, box) {
            final w = box.maxWidth;
            final arm = (w - _panW) / 2 - 6;
            return TweenAnimationBuilder<double>(
              tween: Tween(end: angle),
              duration: const Duration(milliseconds: 520),
              curve: Curves.easeOutBack,
              builder: (context, a, _) {
                final cx = w / 2;
                final hang = h - 34 - beamY;
                final lx = cx - arm * cos(a), ly = beamY + arm * sin(a) + hang;
                final rx = cx + arm * cos(a), ry = beamY - arm * sin(a) + hang;
                Widget pan(Pan side, List<int> coins, double x, double y) {
                  final on = active == side;
                  return Positioned(
                    left: x - _panW / 2,
                    width: _panW,
                    top: y - 64,
                    height: 76,
                    child: Semantics(
                      button: active != null,
                      selected: on,
                      label:
                          '${side == Pan.left ? 'Left' : 'Right'} pan, '
                          '${coins.isEmpty ? 'empty' : 'coins ${coins.join(', ')}'}',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: ValueKey('pan-${side.name}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: active == null ? null : () => onPan(side),
                        child: Align(
                          alignment: Alignment.bottomCenter,
                          child: Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              verticalDirection: VerticalDirection.up,
                              spacing: 3,
                              runSpacing: 3,
                              children: [
                                for (final c in coins)
                                  _MiniCoin(n: c, size: mini, real: cleared(c)),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                return Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _BalancePainter(
                          angle: a,
                          beamY: beamY,
                          arm: arm,
                          hang: hang,
                          panW: _panW,
                          ink: p.ink,
                          line: p.lineStrong,
                          surface: p.surface,
                          activeFill: p.sparkTint,
                          activeLine: p.spark,
                          active: active,
                        ),
                      ),
                    ),
                    pan(Pan.left, left, lx, ly),
                    pan(Pan.right, right, rx, ry),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _BalancePainter extends CustomPainter {
  _BalancePainter({
    required this.angle,
    required this.beamY,
    required this.arm,
    required this.hang,
    required this.panW,
    required this.ink,
    required this.line,
    required this.surface,
    required this.activeFill,
    required this.activeLine,
    required this.active,
  });

  final double angle, beamY, arm, hang, panW;
  final Color ink, line, surface, activeFill, activeLine;
  final Pan? active;

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final h = size.height;
    final heavy = Paint()
      ..color = ink
      ..strokeWidth = 6
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;
    canvas.drawLine(Offset(cx, beamY), Offset(cx, h - 12), heavy);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 40, h - 14, 80, 8),
        const Radius.circular(4),
      ),
      Paint()..color = ink,
    );
    final dx = arm * cos(angle), dy = arm * sin(angle);
    final le = Offset(cx - dx, beamY + dy), re = Offset(cx + dx, beamY - dy);
    final string = Paint()
      ..color = line
      ..strokeWidth = 1.5;
    for (final (end, side) in [(le, Pan.left), (re, Pan.right)]) {
      final y = end.dy + hang;
      final x = end.dx;
      canvas.drawLine(end, Offset(x - panW / 2 + 4, y), string);
      canvas.drawLine(end, Offset(x + panW / 2 - 4, y), string);
      final bowl = Path()
        ..moveTo(x - panW / 2, y)
        ..lineTo(x + panW / 2, y)
        ..arcToPoint(
          Offset(x + panW / 2 - 8, y + 10),
          radius: const Radius.circular(8),
        )
        ..lineTo(x - panW / 2 + 8, y + 10)
        ..arcToPoint(Offset(x - panW / 2, y), radius: const Radius.circular(8))
        ..close();
      final on = active == side;
      canvas.drawPath(bowl, Paint()..color = on ? activeFill : surface);
      canvas.drawPath(
        bowl,
        Paint()
          ..color = on ? activeLine : line
          ..style = PaintingStyle.stroke
          ..strokeWidth = on ? 2 : 1.5,
      );
    }
    canvas.drawLine(le, re, heavy);
    canvas.drawCircle(Offset(cx, beamY), 8, Paint()..color = ink);
  }

  @override
  bool shouldRepaint(_BalancePainter old) =>
      old.angle != angle ||
      old.active != active ||
      old.ink != ink ||
      old.arm != arm;
}

class _MiniCoin extends StatelessWidget {
  const _MiniCoin({required this.n, required this.size, required this.real});

  final int n;
  final double size;
  final bool real;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: real ? p.chip : p.surface,
        border: Border.all(color: p.lineStrong, width: 1.5),
      ),
      child: Text(
        '$n',
        style: lucidText(
          size: 12,
          weight: 600,
          display: true,
          color: real ? p.muted : p.ink,
        ),
      ),
    );
  }
}

class _LogRow extends StatelessWidget {
  const _LogRow({required this.index, required this.weighing, this.slipNote});

  final int index;
  final Weighing weighing;
  final String? slipNote;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final w = weighing;
    final text = lucidText(size: d.compact ? 13 : 14, color: p.ink);
    return Semantics(
      label:
          'Weighing $index: ${w.left.join(', ')} against '
          '${w.right.join(', ')}. ${w.tilt.label}.'
          '${slipNote == null ? '' : ' $slipNote.'}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: slipNote == null ? p.line : p.miss,
            width: slipNote == null ? 1 : 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 22,
                  height: 22,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.chip,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '$index',
                    style: lucidText(size: 12, weight: 700, color: p.ink),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      style: text,
                      children: [
                        TextSpan(text: w.left.join(' ')),
                        TextSpan(
                          text: ' vs ',
                          style: text.copyWith(color: p.faint),
                        ),
                        TextSpan(text: w.right.join(' ')),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  height: 26,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: p.chip,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    w.tilt.label,
                    style: lucidText(size: 13, weight: 600, color: p.ink),
                  ),
                ),
              ],
            ),
            if (slipNote != null)
              Padding(
                padding: const EdgeInsets.only(left: 32, top: 4),
                child: Text(
                  slipNote!,
                  style: lucidText(size: 13, weight: 600, color: p.missText),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PanSwitch extends StatelessWidget {
  const _PanSwitch({
    required this.pan,
    required this.onPan,
    required this.onClear,
  });

  final Pan pan;
  final void Function(Pan) onPan;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget option(Pan side, String label) {
      final on = pan == side;
      return Expanded(
        child: Semantics(
          button: true,
          selected: on,
          label: label,
          excludeSemantics: true,
          child: GestureDetector(
            key: ValueKey('switch-${side.name}'),
            behavior: HitTestBehavior.opaque,
            onTap: () => onPan(side),
            child: AnimatedContainer(
              duration: Lucid.tap,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: on ? p.surface : null,
                borderRadius: BorderRadius.circular(999),
                boxShadow: on
                    ? [
                        BoxShadow(
                          color: p.shadow,
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : null,
              ),
              child: Text(
                label,
                style: lucidText(
                  size: 14,
                  weight: 600,
                  color: on ? p.ink : p.muted,
                ),
              ),
            ),
          ),
        ),
      );
    }

    return Row(
      children: [
        Text(
          'Put coins on',
          style: lucidText(size: 13, weight: 600, color: p.muted),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Container(
            height: 36,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: p.chip,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                option(Pan.left, 'Left pan'),
                option(Pan.right, 'Right pan'),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        PressScale(
          key: const ValueKey('scale-clear'),
          semanticLabel: 'Clear the pans',
          onTap: onClear,
          child: Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.surface,
              shape: BoxShape.circle,
              border: Border.all(color: p.line),
            ),
            child: Icon(
              Icons.restart_alt_rounded,
              size: 20,
              color: onClear == null ? p.faint : p.ink,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tray extends StatelessWidget {
  const _Tray({required this.state, required this.onTap});

  final ScaleSessionState state;
  final void Function(int) onTap;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final n = state.puzzle.coins;
    final size = (d.compact ? 42.0 : 48.0) - (state.answered ? 4 : 0);
    return LayoutBuilder(
      builder: (context, box) {
        final full = n > 5;
        final gap = full
            ? ((box.maxWidth - 6 * size) / 5).floorToDouble()
            : 14.0;
        return Wrap(
          alignment: full ? WrapAlignment.start : WrapAlignment.center,
          spacing: gap,
          runSpacing: d.compact ? 10 : 12,
          children: [
            for (var c = 1; c <= n; c++)
              _Coin(n: c, size: size, state: state, onTap: () => onTap(c)),
          ],
        );
      },
    );
  }
}

class _Coin extends StatelessWidget {
  const _Coin({
    required this.n,
    required this.size,
    required this.state,
    required this.onTap,
  });

  final int n;
  final double size;
  final ScaleSessionState state;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final s = state;
    final q = s.puzzle;
    final r = s.reveal;
    final onPan = s.panOf(n);
    final real = q.cleared(n);
    final selected = s.naming && r == null && s.selected == n;
    final fake = r != null && r.fake == n;
    final wrong = r != null && !r.correct && r.named == n;
    final heavyOnly =
        q.suspects.heavy.contains(n) && !q.suspects.light.contains(n);
    final lightOnly =
        q.suspects.light.contains(n) && !q.suspects.heavy.contains(n);

    // Badge: the fake's way after the reveal; otherwise the only way a coin
    // can still be fake, when the player wasn't told.
    final String? badge = fake
        ? (r.heavier ? '▲' : '▼')
        : (r == null && !q.told && onPan == null && (heavyOnly || lightOnly)
              ? (heavyOnly ? '▲' : '▼')
              : null);

    final dashed = onPan != null && !selected && r == null;
    final (Color? bg, Color edge, double width, Color fg) = fake
        ? (p.correct, p.correct, 1.5, p.onCorrect)
        : wrong
        ? (p.missTint, p.miss, 2.5, p.missText)
        : selected
        ? (p.ink, p.ink, 1.5, p.onInk)
        : dashed
        ? (null, p.lineStrong, 1.5, p.faint)
        : real
        ? (p.chip, p.chip, 1.5, p.faint)
        : (p.surface, p.lineStrong, 1.5, p.ink);

    final where = switch (onPan) {
      Pan.left => ', on the left pan',
      Pan.right => ', on the right pan',
      null => '',
    };
    final label = [
      'Coin $n$where',
      if (fake) 'the fake, ${r.heavier ? 'heavier' : 'lighter'}',
      if (wrong) 'your pick',
      if (!fake && !wrong && real) 'proven real',
      if (badge != null && !fake)
        heavyOnly ? 'can only be heavier' : 'can only be lighter',
      if (selected) 'selected',
    ].join(', ');

    final face = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: bg,
        border: dashed ? null : Border.all(color: edge, width: width),
      ),
      child: Text(
        '$n',
        style: lucidText(
          size: size > 44 ? 17 : 16,
          weight: 600,
          display: true,
          color: fg,
        ),
      ),
    );

    return PressScale(
      key: ValueKey('coin-$n'),
      semanticLabel: label,
      onTap: r == null ? onTap : null,
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (dashed)
              CustomPaint(
                size: Size.square(size),
                painter: _DashedRing(color: edge),
              ),
            face,
            if (badge != null)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  width: 18,
                  height: 18,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: fake ? p.correct : p.ink,
                    border: Border.all(color: p.ground, width: 2),
                  ),
                  child: Text(
                    badge,
                    style: lucidText(
                      size: 8,
                      weight: 700,
                      color: fake ? p.onCorrect : p.onInk,
                      height: 1,
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

class _DashedRing extends CustomPainter {
  _DashedRing({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final r = size.width / 2 - 0.75;
    final rect = Rect.fromCircle(center: size.center(Offset.zero), radius: r);
    const dashes = 18;
    const sweep = 2 * pi / dashes;
    for (var i = 0; i < dashes; i++) {
      canvas.drawArc(rect, i * sweep, sweep * 0.55, false, paint);
    }
  }

  @override
  bool shouldRepaint(_DashedRing old) => old.color != color;
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    super.key,
    required this.label,
    required this.onTap,
    this.primary = false,
  });

  final String label;
  final VoidCallback? onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final enabled = onTap != null;
    final (bg, fg, edge) = !primary
        ? (p.surface, p.ink, p.line)
        : enabled
        ? (p.ink, p.onInk, p.ink)
        : (p.chip, p.faint, p.chip);
    return PressScale(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
          border: Border.all(color: edge, width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: lucidText(size: d.rowTitle, weight: 600, color: fg),
            ),
          ),
        ),
      ),
    );
  }
}
