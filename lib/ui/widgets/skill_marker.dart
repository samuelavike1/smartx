import 'dart:math';

import 'package:material_ui/material_ui.dart';

import '../../core/skills/skill.dart';

/// The small coloured shape that identifies a skill. It always sits next to
/// the skill's name, so screen readers skip it (the name is read once).
class SkillMarkerIcon extends StatelessWidget {
  const SkillMarkerIcon(this.skill, {super.key, this.size = 12, this.color});

  final Skill skill;
  final double size;

  /// Overrides the skill colour (e.g. white on a coloured tile).
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CustomPaint(
          painter: _MarkerPainter(skill.marker, color ?? skill.color),
        ),
      ),
    );
  }
}

class _MarkerPainter extends CustomPainter {
  _MarkerPainter(this.marker, this.color);

  final SkillMarker marker;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.shortestSide;
    final c = size.center(Offset.zero);
    final fill = Paint()..color = color;

    switch (marker) {
      case SkillMarker.square:
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromCenter(center: c, width: s, height: s),
            Radius.circular(s * 0.22),
          ),
          fill,
        );
      case SkillMarker.circle:
        canvas.drawCircle(c, s / 2, fill);
      case SkillMarker.triangle:
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - s / 2)
            ..lineTo(c.dx + s / 2, c.dy + s / 2)
            ..lineTo(c.dx - s / 2, c.dy + s / 2)
            ..close(),
          fill,
        );
      case SkillMarker.diamond:
        final r = s / 2;
        canvas.drawPath(
          Path()
            ..moveTo(c.dx, c.dy - r)
            ..lineTo(c.dx + r * cos(0), c.dy)
            ..lineTo(c.dx, c.dy + r)
            ..lineTo(c.dx - r, c.dy)
            ..close(),
          fill,
        );
      case SkillMarker.ring:
        final stroke = s * 0.25;
        canvas.drawCircle(
          c,
          (s - stroke) / 2,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke,
        );
    }
  }

  @override
  bool shouldRepaint(_MarkerPainter old) =>
      old.marker != marker || old.color != color;
}
