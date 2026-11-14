import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/skills/skill.dart';
import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/dashed_outline.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'path_controller.dart';
import 'path_finder_game.dart';
import 'path_puzzle.dart';
import '../../ui/palette.dart';

// Built from the "Path Finder · play" and "Path Finder · review" artboards.

/// Board colours by day and night. At night walls turn lighter than the
/// board (dark walls would vanish on a dark ground) and the tints darken.
({Color wall, Color exitTint, Color gateTint, Color gateEdge, Color keyInk})
_board(bool night) => night
    ? (
        wall: const Color(0xFF6B6880),
        exitTint: const Color(0xFF3E2034),
        gateTint: const Color(0xFF3A3013),
        gateEdge: const Color(0xFFE8B92E),
        keyInk: const Color(0xFFF2C14E),
      )
    : (
        wall: const Color(0xFF2E2D38),
        exitTint: const Color(0xFFFBEAF3),
        gateTint: const Color(0xFFFFF7E0),
        gateEdge: const Color(0xFFD9A200),
        keyInk: const Color(0xFF9A6B00),
      );
final _piece = Skill.problemSolving.color;

class PathFinderScreen extends ConsumerWidget {
  const PathFinderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(pathSessionProvider);

    ref.listen(pathSessionProvider, (prev, next) {
      if (prev?.answered == false && next.answered) {
        next.won ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
      }
    });

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const PathFinderGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(pathSessionProvider),
                  onTrySimilar: ref
                      .read(pathSessionProvider.notifier)
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

  final PathSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final c = ref.read(pathSessionProvider.notifier);
    final p = state.puzzle;

    void go(Dir d) {
      if (c.move(d)) HapticFeedback.selectionClick();
    }

    // The board is sized from the whole screen (not the body), so it keeps
    // its size when the feedback card replaces the arrows in the dock.
    return LayoutBuilder(
      builder: (context, viewport) => GameLayout(
        header: [
          GameTopBar(
            filled: state.round + (state.answered ? 1 : 0),
            total: state.totalRounds,
            score: state.score,
            game: const PathFinderGame(),
          ),
          SizedBox(height: d.compact ? 10 : 14),
          LevelComboRow(
            level: state.level,
            combo: state.combo,
            practice: state.practice,
          ),
        ],
        body: (context, _) => Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(height: d.gapM),
            Text(
              'Reach the flag',
              textAlign: TextAlign.center,
              style: theme.textTheme.headlineSmall,
            ),
            if (!state.answered) ...[
              SizedBox(height: d.compact ? 2 : 4),
              Text.rich(
                TextSpan(
                  style: lucidText(
                    size: d.small + 1,
                    color: scheme.onSurfaceVariant,
                  ),
                  children: [
                    TextSpan(
                      text: '${state.movesLeft} of ${p.moveLimit}',
                      style: lucidText(
                        size: d.small + 1,
                        weight: 700,
                        color: scheme.onSurface,
                      ),
                    ),
                    const TextSpan(text: ' moves left'),
                    if (p.board.hasKey && state.hasKey)
                      const TextSpan(text: ' · key found'),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
            SizedBox(height: d.gapL),
            _Board(
              state: state,
              onSwipe: go,
              availableHeight: viewport.maxHeight,
            ),
            SizedBox(height: d.gapM),
          ],
        ),
        // Arrows + hint while playing, the feedback card after: thumb zone.
        dock: !state.answered
            ? Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      for (final (dir, icon) in const [
                        (Dir.left, Icons.arrow_back_rounded),
                        (Dir.up, Icons.arrow_upward_rounded),
                        (Dir.down, Icons.arrow_downward_rounded),
                        (Dir.right, Icons.arrow_forward_rounded),
                      ]) ...[
                        PressScale(
                          key: ValueKey('move-${dir.word}'),
                          semanticLabel: 'Slide ${dir.word}',
                          onTap: () => go(dir),
                          child: Container(
                            width: d.control,
                            height: d.control,
                            decoration: BoxDecoration(
                              color: scheme.surface,
                              borderRadius: BorderRadius.circular(
                                d.compact ? 14 : Lucid.radiusM,
                              ),
                              border: Border.all(color: scheme.outlineVariant),
                            ),
                            child: Icon(
                              icon,
                              size: d.compact ? 20 : 22,
                              color: scheme.onSurface,
                            ),
                          ),
                        ),
                        SizedBox(width: d.compact ? 10 : 12),
                      ],
                      PressScale(
                        key: const ValueKey('restart'),
                        semanticLabel: 'Restart board',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          c.restart();
                        },
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            DashedOutline(
                              size: d.control,
                              radius: d.compact ? 14 : 16,
                              color: context.palette.lineStrong,
                              strokeWidth: 1.5,
                            ),
                            Icon(
                              Icons.restart_alt_rounded,
                              size: d.compact ? 20 : 22,
                              color: scheme.onSurfaceVariant,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: d.compact ? 8 : 12),
                  Text(
                    'Swipe or tap an arrow. The piece slides until something stops it.',
                    textAlign: TextAlign.center,
                    style: lucidText(
                      size: d.small,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              )
            : FeedbackSlot(
                child: FeedbackCard(
                  correct: state.won,
                  points: state.lastPoints,
                  explanation: p.explain(
                    won: state.won,
                    movesUsed: state.movesUsed,
                  ),
                  isLastRound: state.round + 1 >= state.totalRounds,
                  onNext: c.next,
                ),
              ),
      ),
    );
  }
}

class _Board extends StatefulWidget {
  const _Board({
    required this.state,
    required this.onSwipe,
    required this.availableHeight,
  });

  final PathSessionState state;
  final ValueChanged<Dir> onSwipe;

  /// Height of the game screen's body, used to keep the arrows on screen.
  final double availableHeight;

  @override
  State<_Board> createState() => _BoardState();
}

class _BoardState extends State<_Board> {
  Offset _drag = Offset.zero;

  void _end() {
    final d = _drag;
    _drag = Offset.zero;
    if (widget.state.answered || d.distance < 24) return;
    widget.onSwipe(
      d.dx.abs() > d.dy.abs()
          ? (d.dx > 0 ? Dir.right : Dir.left)
          : (d.dy > 0 ? Dir.down : Dir.up),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final p = s.puzzle;
    final n = p.size;
    final marks = s.answered ? p.routeMarks() : const <int, int>{};
    final trail = s.answered ? const <int>{} : s.trail.toSet();

    return LayoutBuilder(
      builder: (context, cons) {
        // As on the artboard (344) where there is room; smaller on short
        // phones so the arrows and the hint stay on screen (the rest of the
        // play screen takes ~330 px).
        final side = min(
          cons.maxWidth,
          min(
            344.0,
            max(220.0, widget.availableHeight - Dims.of(context).pathChrome),
          ),
        );
        const pad = 6.0, gap = 4.0;
        final cell = (side - 2 * pad - gap * (n - 1)) / n;
        Offset at(int i) =>
            Offset(pad + (i % n) * (cell + gap), pad + (i ~/ n) * (cell + gap));
        Offset along(List<int> path, double t) {
          final i = t.floor().clamp(0, path.length - 1);
          final j = min(i + 1, path.length - 1);
          return Offset.lerp(at(path[i]), at(path[j]), t - i)!;
        }

        final path = s.lastSlide.isEmpty ? [s.pos] : s.lastSlide;

        return Center(
          child: GestureDetector(
            onVerticalDragUpdate: (d) => _drag += d.delta,
            onVerticalDragEnd: (_) => _end(),
            onHorizontalDragUpdate: (d) => _drag += d.delta,
            onHorizontalDragEnd: (_) => _end(),
            child: Semantics(
              label: 'Board, $n by $n. ${s.movesLeft} moves left.',
              child: Container(
                width: side,
                height: side,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Stack(
                  children: [
                    for (var i = 0; i < n * n; i++)
                      Positioned(
                        left: at(i).dx,
                        top: at(i).dy,
                        child: _CellView(
                          key: ValueKey('pcell-$i'),
                          cell: p.board.cells[i],
                          size: cell,
                          hasKey: s.hasKey,
                          trail: trail.contains(i) && i != s.pos,
                          mark: marks[i],
                          isStart: s.answered && i == p.start,
                        ),
                      ),
                    if (s.answered && !s.won)
                      Positioned(
                        left: at(s.pos).dx,
                        top: at(s.pos).dy,
                        child: Opacity(
                          opacity: 0.45,
                          child: _PieceView(size: cell),
                        ),
                      )
                    else if (!s.answered || s.won)
                      TweenAnimationBuilder<double>(
                        key: ValueKey(
                          'slide-${s.movesUsed}-${s.lastSlide.length}',
                        ),
                        tween: Tween(
                          begin: 0,
                          end: (path.length - 1).toDouble(),
                        ),
                        duration: Duration(
                          milliseconds: 60 + 55 * (path.length - 1),
                        ),
                        curve: Curves.easeOutCubic,
                        builder: (_, t, child) {
                          final o = along(path, t);
                          return Positioned(
                            left: o.dx,
                            top: o.dy,
                            child: child!,
                          );
                        },
                        child: _PieceView(size: cell),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _PieceView extends StatelessWidget {
  const _PieceView({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return SizedBox.square(
      dimension: size,
      child: Center(
        child: Container(
          width: size * 0.58,
          height: size * 0.58,
          decoration: BoxDecoration(
            color: _piece,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _piece.withValues(alpha: 0.35),
                blurRadius: 8,
                offset: const Offset(0, 3),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CellView extends StatelessWidget {
  const _CellView({
    super.key,
    required this.cell,
    required this.size,
    required this.hasKey,
    required this.trail,
    required this.mark,
    required this.isStart,
  });

  final Cell cell;
  final double size;
  final bool hasKey;
  final bool trail;

  /// Review: move number where a move stops, 0 where the route passes.
  final int? mark;
  final bool isStart;

  @override
  Widget build(BuildContext context) {
    final icon = size * 0.5;
    final b = _board(context.palette.isNight);
    var bg = context.palette.surface;
    Border? border;
    Widget? content;

    switch (cell) {
      case Cell.wall:
        bg = b.wall;
      case Cell.exit:
        bg = b.exitTint;
        border = Border.all(color: _piece, width: 2);
        content = Icon(
          Icons.flag_outlined,
          size: icon,
          color: _piece,
          semanticLabel: 'Flag',
        );
      case Cell.key:
        if (!hasKey) {
          content = Icon(
            Icons.key_rounded,
            size: icon,
            color: b.keyInk,
            semanticLabel: 'Key',
          );
        }
      case Cell.gate:
        if (hasKey) {
          content = Icon(
            Icons.lock_open_rounded,
            size: icon * 0.85,
            color: b.gateEdge.withValues(alpha: 0.6),
            semanticLabel: 'Open gate',
          );
        } else {
          bg = b.gateTint;
          border = Border.all(color: b.gateEdge, width: 2);
          content = Icon(
            Icons.lock_rounded,
            size: icon * 0.85,
            color: b.keyInk,
            semanticLabel: 'Locked gate',
          );
        }
      case Cell.arrowUp || Cell.arrowDown || Cell.arrowLeft || Cell.arrowRight:
        bg = context.palette.chip;
        content = Icon(
          switch (cell.arrow!) {
            Dir.up => Icons.arrow_upward_rounded,
            Dir.down => Icons.arrow_downward_rounded,
            Dir.left => Icons.arrow_back_rounded,
            Dir.right => Icons.arrow_forward_rounded,
          },
          size: icon,
          color: context.palette.ink,
          semanticLabel: 'Arrow ${cell.arrow!.word}',
        );
      case Cell.floor:
        break;
    }

    // Overlays: the route in review, the trail while playing.
    Widget? overlay;
    if (mark != null && mark! > 0) {
      overlay = Container(
        width: 24,
        height: 24,
        alignment: Alignment.center,
        decoration: BoxDecoration(color: _piece, shape: BoxShape.circle),
        child: Text(
          '$mark',
          style: lucidText(size: 13, weight: 700, color: Colors.white),
        ),
      );
    } else if (mark == 0) {
      overlay = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(color: _piece, shape: BoxShape.circle),
      );
    } else if (isStart) {
      overlay = Container(
        width: 14,
        height: 14,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: _piece, width: 2.5),
        ),
      );
    } else if (trail) {
      overlay = Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: _piece.withValues(alpha: 0.3),
          shape: BoxShape.circle,
        ),
      );
    }

    return AnimatedContainer(
      duration: Lucid.pop,
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(min(10, size * 0.2)),
        border: border,
      ),
      child: overlay != null && content != null && cell != Cell.exit
          ? Stack(alignment: Alignment.center, children: [content, overlay])
          : (overlay ?? content),
    );
  }
}
