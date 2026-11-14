import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/game/speed_game.dart';
import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/speed_widgets.dart';
import 'odd_controller.dart';
import 'odd_one_out_game.dart';
import 'odd_puzzle.dart';

// Built from the "Odd One Out · play" and "Odd One Out · review" artboards,
// on the shared timed-trials screen. The grid is the answer: no dock
// buttons.

class OddScreen extends StatelessWidget {
  const OddScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      SpeedGameScreen<OddBlock, OddTrial, int>(
        provider: oddSessionProvider,
        game: const OddOneOutGame(),
        ui: oddUi,
      );
}

/// Largest grid side for the screen (the game screen's fixed height).
double _gridCap(BuildContext context) {
  final cap = Dims.of(context).compact ? 288.0 : 356.0;
  return min(MediaQuery.sizeOf(context).width - 32, cap);
}

/// Odd One Out's look: used by its screen and its Quick feed cards. The
/// grid fits the space it's given (a full screen or a feed card).
final oddUi = SpeedUi<OddBlock, OddTrial, int>(
  cue: (_) => const SpeedCue('TAP THE ODD ONE'),
  stimulusHeight: _gridCap,
  stimulus: (context, s, t, press) => LayoutBuilder(
    builder: (context, c) => _Grid(
      trial: t,
      size: [_gridCap(context), c.maxWidth, c.maxHeight].reduce(min),
      markFor: s.markFor,
      onTap: press,
    ),
  ),
  hint: (s) =>
      'Tap the one tile that\'s different: ${oddWays(s.block.features)}.',
  review: SpeedReviewText(
    item: 'Grid',
    calm: 'Odd colour',
    conflict: 'Odd shape, turn or size',
    cost: (secs) => 'Searching cost you $secs s a grid.',
    noCost: 'Searching didn\'t slow you down. Sharp eyes.',
  ),
  reviewExtra: (context, s) {
    final first = s.block.firstMiss(s.result!);
    if (first < 0) return null;
    final a = first < s.answers.length ? s.answers[first] : null;
    return _MissedGrid(
      number: first + 1,
      trial: s.block.trials[first],
      tapped: a?.tapped,
    );
  },
);

double _gap(int side, bool compact) => switch (side) {
  <= 4 => compact ? 10 : 12,
  _ => compact ? 6 : 8,
};

class _Grid extends StatelessWidget {
  const _Grid({
    required this.trial,
    required this.size,
    required this.markFor,
    required this.onTap,
  });

  final OddTrial trial;
  final double size;
  final SpeedMark Function(int index) markFor;
  final void Function(int index) onTap;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final side = trial.side;
    final gap = _gap(side, d.compact);
    final tile = (size - gap * (side - 1)) / side;
    return Semantics(
      label: '$side by $side grid of tiles',
      container: true,
      child: SizedBox.square(
        dimension: size,
        child: Column(
          children: [
            for (var r = 0; r < side; r++) ...[
              if (r > 0) SizedBox(height: gap),
              Row(
                children: [
                  for (var c = 0; c < side; c++) ...[
                    if (c > 0) SizedBox(width: gap),
                    SizedBox.square(
                      dimension: tile,
                      child: _tile(r * side + c, tile),
                    ),
                  ],
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _tile(int i, double tile) {
    final t = trial.tiles[i];
    return SpeedButton(
      key: ValueKey('odd-$i'),
      label:
          '${trial.place(i)[0].toUpperCase()}${trial.place(i).substring(1)}: '
          '${t.description}',
      mark: markFor(i),
      radius: tile > 64 ? 16 : 12,
      onTap: () => onTap(i),
      child: Center(child: OddGlyph(t, size: tile * 0.5)),
    );
  }
}

/// One tile's shape, painted in its colour, turn and size.
class OddGlyph extends StatelessWidget {
  const OddGlyph(this.tile, {super.key, required this.size});

  final OddTile tile;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _GlyphPainter(tile)),
  );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.tile);

  final OddTile tile;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide * tile.scale;
    final c = size.center(Offset.zero);
    final paint = Paint()..color = tile.tint.color;
    switch (tile.shape) {
      case OddShape.circle:
        canvas.drawCircle(c, s / 2, paint);
      case OddShape.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: s * 0.9, height: s * 0.9),
            Radius.circular(s * 0.14),
          ),
          paint,
        );
      case OddShape.triangle:
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(tile.turn * pi / 2);
        // Pointing up; rounded corners via a thick stroke of the same colour.
        final h = s * 0.82;
        final path = Path()
          ..moveTo(0, -h / 2)
          ..lineTo(s / 2 * 0.95, h / 2)
          ..lineTo(-s / 2 * 0.95, h / 2)
          ..close();
        canvas.drawPath(path, paint);
        canvas.drawPath(
          path,
          Paint()
            ..color = tile.tint.color
            ..style = PaintingStyle.stroke
            ..strokeWidth = s * 0.08
            ..strokeJoin = StrokeJoin.round,
        );
        canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) =>
      old.tile.shape != tile.shape ||
      old.tile.tint != tile.tint ||
      old.tile.turn != tile.turn ||
      old.tile.scale != tile.scale;
}

/// The first missed grid in small: the odd one green, the tapped tile rose.
class _MissedGrid extends StatelessWidget {
  const _MissedGrid({
    required this.number,
    required this.trial,
    required this.tapped,
  });

  final int number;
  final OddTrial trial;
  final int? tapped;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final side = trial.side;
    final mini = d.compact ? 100.0 : 114.0;
    final gap = side <= 4 ? 5.0 : 4.0;
    final tile = (mini - gap * (side - 1)) / side;

    Widget cell(int i) {
      final (bg, edge, width) = i == trial.odd
          ? (Lucid.correctTint, Lucid.correct, 2.0)
          : i == tapped
          ? (Lucid.missTint, Lucid.miss, 2.0)
          : (scheme.surface, scheme.outlineVariant, 1.0);
      return Container(
        width: tile,
        height: tile,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: edge, width: width),
        ),
        alignment: Alignment.center,
        child: OddGlyph(trial.tiles[i], size: tile * 0.5),
      );
    }

    Widget key(Color fill, Color edge, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 14,
          height: 14,
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: edge, width: 2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          text,
          style: lucidText(size: d.small, color: scheme.onSurface),
        ),
      ],
    );

    final tappedText = tapped == null
        ? ' The time ran out.'
        : ' You tapped ${trial.place(tapped!)}.';
    return Semantics(
      label:
          'Grid $number: the odd one was ${trial.place(trial.odd)}.$tappedText',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var r = 0; r < side; r++) ...[
                  if (r > 0) SizedBox(height: gap),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var c = 0; c < side; c++) ...[
                        if (c > 0) SizedBox(width: gap),
                        cell(r * side + c),
                      ],
                    ],
                  ),
                ],
              ],
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Grid $number',
                    style: lucidText(
                      size: d.rowTitle - 1,
                      weight: 600,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 6),
                  key(Lucid.correctTint, Lucid.correct, 'The odd one'),
                  const SizedBox(height: 6),
                  tapped == null
                      ? Text(
                          'Ran out of time',
                          style: lucidText(
                            size: d.small,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : key(Lucid.missTint, Lucid.miss, 'Your tap'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
