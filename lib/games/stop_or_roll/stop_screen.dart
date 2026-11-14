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
import '../better_bet/bet_puzzle.dart' show money;
import '../odds_on/odds_math.dart';
import 'stop_controller.dart';
import 'stop_or_roll_game.dart';
import 'stop_puzzle.dart';

// Built from the "Stop or Roll · decide" and "· your calls" artboards.

class StopScreen extends ConsumerWidget {
  const StopScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(stopSessionProvider);
    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const StopOrRollGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(stopSessionProvider),
                  onTrySimilar: ref
                      .read(stopSessionProvider.notifier)
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

  final StopSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final p = context.palette;
    final d = Dims.of(context);
    final c = ref.read(stopSessionProvider.notifier);
    final s = state;
    final g = s.game;

    void choose(Choice choice) {
      choice == Choice.keep ? c.keep() : c.roll();
      final now = ref.read(stopSessionProvider);
      if (now.answered) {
        now.lastCorrect
            ? HapticFeedback.lightImpact()
            : HapticFeedback.mediumImpact();
      } else {
        HapticFeedback.selectionClick();
      }
    }

    return GameLayout(
      header: [
        GameTopBar(
          filled: s.round + (s.answered ? 1 : 0),
          total: s.totalRounds,
          score: s.score,
          game: const StopOrRollGame(),
        ),
        SizedBox(height: d.compact ? 10 : 14),
        LevelComboRow(level: s.level, combo: s.combo, practice: s.practice),
      ],
      body: (context, _) => s.answered
          ? _Review(game: g)
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(height: d.gapM),
                Text(
                  g.setup.adding
                      ? 'Stop, or roll on?'
                      : 'Keep it, or roll again?',
                  textAlign: TextAlign.center,
                  style: lucidText(
                    size: d.compact ? 20 : 22,
                    weight: 600,
                    display: true,
                    color: scheme.onSurface,
                    height: 1.3,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  g.setup.rules,
                  textAlign: TextAlign.center,
                  style: lucidText(
                    size: d.body,
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
                SizedBox(height: d.gapL),
                Center(
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 420),
                    transitionBuilder: (child, a) => RotationTransition(
                      turns: Tween(begin: -0.25, end: 0.0).animate(
                        CurvedAnimation(parent: a, curve: Curves.easeOutBack),
                      ),
                      child: ScaleTransition(scale: a, child: child),
                    ),
                    child: _Roll(
                      key: ValueKey('roll-${g.shown}'),
                      dice: g.setup.dice,
                      value: g.face,
                      size: d.compact ? 96 : 120,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                // IntrinsicWidth keeps each pill hugging its text; in a
                // Wrap alone it would stretch to the full width.
                Wrap(
                  alignment: WrapAlignment.center,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    if (g.setup.adding)
                      IntrinsicWidth(
                        child: GamePill(
                          text: 'Total ${g.hold}',
                          background: p.ink,
                          foreground: p.onInk,
                        ),
                      ),
                    IntrinsicWidth(
                      child: GamePill(
                        text: 'Roll ${g.shown + 1} of ${g.setup.rolls}',
                        background: p.chip,
                        foreground: p.ink,
                      ),
                    ),
                    Text(
                      g.left == 1 ? '1 roll left' : '${g.left} rolls left',
                      style: lucidText(size: 13, weight: 600, color: p.muted),
                    ),
                  ],
                ),
                if (g.calls.isNotEmpty) ...[
                  SizedBox(height: d.gapM),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final call in g.calls)
                        _CallChip(
                          call: call,
                          dice: g.setup.dice,
                          adding: g.setup.adding,
                        ),
                    ],
                  ),
                ],
                SizedBox(height: d.gapM),
              ],
            ),
      dock: s.answered
          ? FeedbackSlot(
              child: FeedbackCard(
                correct: s.lastCorrect,
                points: s.lastPoints,
                explanation: g.feedback(),
                isLastRound: s.round + 1 >= s.totalRounds,
                onNext: c.next,
              ),
            )
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'A roll is worth the average of what you\'d end up with.',
                  textAlign: TextAlign.center,
                  style: lucidText(size: d.small, color: p.muted),
                ),
                SizedBox(height: d.gapS),
                SizedBox(
                  height: d.compact ? 52 : 60,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: _DockButton(
                          key: const ValueKey('stop-keep'),
                          label: g.keepLabel,
                          onTap: () => choose(Choice.keep),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: _DockButton(
                          key: const ValueKey('stop-roll'),
                          label: g.rollLabel,
                          onTap: () => choose(Choice.roll),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
  }
}

/// The roll on show: one die, or two dice and their total.
class _Roll extends StatelessWidget {
  const _Roll({
    super.key,
    required this.dice,
    required this.value,
    required this.size,
  });

  final Dice dice;
  final int value;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (!dice.pair) {
      return DieFace(value: value, sides: dice.sides, size: size, raised: true);
    }
    // Any split shows the same total; lead with the bigger die.
    final a = max(value - 6, (value + 1) ~/ 2);
    final b = value - a;
    final p = context.palette;
    return Semantics(
      label: 'Two dice: $a and $b, total $value',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          DieFace(value: a, sides: 6, size: size * 0.8, raised: true),
          const SizedBox(width: 12),
          DieFace(value: b, sides: 6, size: size * 0.8, raised: true),
          const SizedBox(width: 14),
          Text(
            '= $value',
            style: lucidText(
              size: 28,
              weight: 700,
              display: true,
              color: p.ink,
            ),
          ),
        ],
      ),
    );
  }
}

/// A die: pips for six-sided dice, the number for bigger ones.
class DieFace extends StatelessWidget {
  const DieFace({
    super.key,
    required this.value,
    required this.sides,
    required this.size,
    this.raised = false,
  });

  final int value;
  final int sides;
  final double size;
  final bool raised;

  static const _spots = {
    1: [(0.5, 0.5)],
    2: [(0.3, 0.3), (0.7, 0.7)],
    3: [(0.28, 0.28), (0.5, 0.5), (0.72, 0.72)],
    4: [(0.28, 0.28), (0.72, 0.28), (0.28, 0.72), (0.72, 0.72)],
    5: [(0.28, 0.28), (0.72, 0.28), (0.5, 0.5), (0.28, 0.72), (0.72, 0.72)],
    6: [
      (0.28, 0.25),
      (0.72, 0.25),
      (0.28, 0.5),
      (0.72, 0.5),
      (0.28, 0.75),
      (0.72, 0.75),
    ],
  };

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final pips = sides == 6 && value >= 1 && value <= 6;
    final pip = size * (size > 60 ? 0.17 : 0.18);
    return Semantics(
      label: '$value',
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(size * 0.24),
          border: Border.all(color: p.lineStrong, width: 1.5),
          boxShadow: raised
              ? [
                  BoxShadow(
                    color: p.shadow,
                    blurRadius: 28,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: pips
            ? Stack(
                children: [
                  for (final (x, y) in _spots[value]!)
                    Positioned(
                      left: x * size - pip / 2 - 1.5,
                      top: y * size - pip / 2 - 1.5,
                      child: Container(
                        width: pip,
                        height: pip,
                        decoration: BoxDecoration(
                          color: p.ink,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              )
            : Center(
                child: Text(
                  '$value',
                  style: lucidText(
                    size: size * 0.42,
                    weight: 700,
                    display: true,
                    color: p.ink,
                  ),
                ),
              ),
      ),
    );
  }
}

class _CallChip extends StatelessWidget {
  const _CallChip({
    required this.call,
    required this.dice,
    required this.adding,
  });

  final Call call;
  final Dice dice;
  final bool adding;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final verb = call.choice == Choice.keep
        ? (adding ? 'Stopped' : 'Kept')
        : (adding ? 'Rolled on' : 'Rolled again');
    return Semantics(
      label: '$verb on ${call.face}, ${call.right ? 'right' : 'wrong'}',
      excludeSemantics: true,
      child: Container(
        height: 40,
        padding: const EdgeInsets.fromLTRB(6, 0, 12, 0),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: p.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            DieFace(
              value: call.face,
              sides: dice.pair ? 0 : dice.sides,
              size: 28,
            ),
            const SizedBox(width: 8),
            Text(verb, style: lucidText(size: 14, weight: 600, color: p.ink)),
            const SizedBox(width: 8),
            Text(
              call.right ? '✓' : '✗',
              style: lucidText(
                size: 14,
                weight: 700,
                color: call.right ? p.correctText : p.missText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// After the game: what you keep, then each call with what a roll was worth.
class _Review extends StatelessWidget {
  const _Review({required this.game});

  final StopGame game;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final g = game;
    final adding = g.setup.adding;
    final slip = g.slip;
    final label = g.busted
        ? 'Bust'
        : (!adding && g.setup.cost == 0 ? 'You keep' : 'You win');
    final sides = g.setup.dice.pair ? 0 : g.setup.dice.sides;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: d.gapM),
        Semantics(
          label: '$label ${money(Frac(g.payout))}',
          excludeSemantics: true,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              DieFace(value: g.face, sides: sides, size: d.compact ? 60 : 72),
              const SizedBox(width: 14),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: lucidText(size: 13, weight: 600, color: p.muted),
                  ),
                  Text(
                    money(Frac(g.payout)),
                    style: lucidText(
                      size: 28,
                      weight: 700,
                      display: true,
                      color: p.ink,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: d.gapM),
        Text(
          'Your calls',
          style: lucidText(size: d.rowTitle, weight: 600, color: p.ink),
        ),
        for (final call in g.calls) ...[
          const SizedBox(height: 10),
          _CallRow(
            face: call.face,
            sides: sides,
            title: _title(call, adding),
            detail: _detail(call, adding),
            right: call.right,
            outlined: identical(call, slip),
          ),
        ],
        if (!g.stopped) ...[
          const SizedBox(height: 10),
          _CallRow(
            face: g.face,
            sides: sides,
            title: g.busted
                ? 'Bust: ${withArticle(g.face)} loses it all'
                : (adding ? 'Stopped, no rolls left' : 'Kept, no rolls left'),
            detail: g.busted ? 'You get nothing' : 'The last roll stands',
          ),
        ],
        SizedBox(height: d.gapM),
      ],
    );
  }

  static String _title(Call c, bool adding) {
    final left = c.left == 1 ? '1 roll left' : '${c.left} rolls left';
    if (adding) {
      return c.choice == Choice.keep
          ? 'Stopped at ${c.hold}, $left'
          : 'Rolled on at ${c.hold}, $left';
    }
    return c.choice == Choice.keep ? 'Kept, $left' : 'Rolled again, $left';
  }

  static String _detail(Call c, bool adding) {
    final worth = 'A roll was worth ${money(c.rollWorth)}';
    if (c.tie) {
      return '$worth, the same as ${adding ? 'stopping' : 'the ${c.face}'}';
    }
    if (c.right) return worth;
    if (c.best == Choice.keep) {
      return adding
          ? '$worth: stop at ${c.hold}'
          : '$worth: keep the ${c.face}';
    }
    return '$worth: roll again';
  }
}

class _CallRow extends StatelessWidget {
  const _CallRow({
    required this.face,
    required this.sides,
    required this.title,
    required this.detail,
    this.right,
    this.outlined = false,
  });

  final int face;
  final int sides;
  final String title;
  final String detail;
  final bool? right;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final wrong = right == false;
    return Semantics(
      label:
          '$title. $detail.${right == null ? '' : (right! ? ' Right.' : ' Wrong.')}',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: outlined ? p.miss : p.line,
            width: outlined ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            DieFace(value: face, sides: sides, size: 32),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: lucidText(
                      size: d.compact ? 14 : 15,
                      weight: 600,
                      color: p.ink,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: lucidText(
                      size: 13,
                      weight: wrong ? 600 : 400,
                      color: wrong ? p.missText : p.muted,
                    ),
                  ),
                ],
              ),
            ),
            if (right != null) ...[
              const SizedBox(width: 8),
              Container(
                width: 26,
                height: 26,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: right! ? p.correctTint : p.missTint,
                  shape: BoxShape.circle,
                ),
                child: Text(
                  right! ? '✓' : '✗',
                  style: lucidText(
                    size: 13,
                    weight: 700,
                    color: right! ? p.correctText : p.missText,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({super.key, required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    return PressScale(
      semanticLabel: label,
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(d.compact ? 16 : 18),
          border: Border.all(color: p.line, width: 1.5),
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Text(
              label,
              style: lucidText(size: d.rowTitle, weight: 600, color: p.ink),
            ),
          ),
        ),
      ),
    );
  }
}
