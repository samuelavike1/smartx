import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../sequence_puzzle.dart';

/// Colour-blind-friendlier palette; shapes and counts also carry meaning, so
/// colour is never the only cue.
const List<Color> tokenPalette = [
  Color(0xFFE53935), // red
  Color(0xFF1E88E5), // blue
  Color(0xFF43A047), // green
  Color(0xFFFDD835), // yellow
  Color(0xFF8E24AA), // purple
  Color(0xFFFB8C00), // orange
];

class TokenTile extends StatelessWidget {
  const TokenTile({
    super.key,
    required this.token,
    this.size = 56,
    this.borderColor,
    this.background,
  });

  final PatternToken? token;
  final double size;
  final Color? borderColor;
  final Color? background;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? scheme.surface,
        borderRadius: BorderRadius.circular(size * 0.24),
        border: Border.all(
          color: borderColor ?? scheme.outlineVariant,
          width: borderColor == null ? 1 : 2.5,
        ),
      ),
      child: token == null
          ? Center(
              child: Text(
                '?',
                style: TextStyle(
                  fontSize: size * 0.45,
                  fontWeight: FontWeight.w700,
                  color: scheme.primary,
                ),
              ),
            )
          : CustomPaint(
              painter: TokenPainter(
                token: token!,
                color: tokenPalette[token!.color],
                outline: scheme.onSurface.withValues(alpha: 0.35),
              ),
            ),
    );
  }
}

class TokenPainter extends CustomPainter {
  TokenPainter({
    required this.token,
    required this.color,
    required this.outline,
  });

  final PatternToken token;
  final Color color;
  final Color outline;

  static const _layouts = <List<Offset>>[
    [Offset(0.5, 0.5)],
    [Offset(0.3, 0.5), Offset(0.7, 0.5)],
    [Offset(0.5, 0.29), Offset(0.29, 0.7), Offset(0.71, 0.7)],
    [Offset(0.3, 0.3), Offset(0.7, 0.3), Offset(0.3, 0.7), Offset(0.7, 0.7)],
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final positions = _layouts[token.count];
    final radius = size.shortestSide * (positions.length == 1 ? 0.3 : 0.16);
    final fill = Paint()..color = color;
    final stroke = Paint()
      ..color = outline
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;

    for (final p in positions) {
      final center = Offset(p.dx * size.width, p.dy * size.height);
      final path = _shapePath(TokenShape.values[token.shape], center, radius);
      canvas
        ..drawPath(path, fill)
        ..drawPath(path, stroke);
    }
  }

  static Path _shapePath(TokenShape shape, Offset c, double r) =>
      switch (shape) {
        TokenShape.circle =>
          Path()..addOval(Rect.fromCircle(center: c, radius: r)),
        TokenShape.square =>
          Path()..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromCircle(center: c, radius: r * 0.85),
              Radius.circular(r * 0.2),
            ),
          ),
        TokenShape.triangle => _polygon(c, r, 3),
        TokenShape.diamond => _polygon(c, r, 4),
        TokenShape.hexagon => _polygon(c, r, 6, startAngle: 0),
        TokenShape.star => _star(c, r),
      };

  static Path _polygon(
    Offset c,
    double r,
    int sides, {
    double startAngle = -pi / 2,
  }) {
    final path = Path();
    for (var i = 0; i < sides; i++) {
      final a = startAngle + 2 * pi * i / sides;
      final point = c + Offset(cos(a), sin(a)) * r;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  static Path _star(Offset c, double r) {
    final path = Path();
    for (var i = 0; i < 10; i++) {
      final a = -pi / 2 + pi * i / 5;
      final radius = i.isEven ? r : r * 0.45;
      final point = c + Offset(cos(a), sin(a)) * radius;
      i == 0
          ? path.moveTo(point.dx, point.dy)
          : path.lineTo(point.dx, point.dy);
    }
    return path..close();
  }

  @override
  bool shouldRepaint(TokenPainter old) =>
      old.token != token || old.color != color || old.outline != outline;
}
