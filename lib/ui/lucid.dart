import 'package:material_ui/material_ui.dart';

/// Lucid design tokens ("Ink first"). Each colour has exactly one job:
/// ink = actions and selection, spark = brand and rewards, correct / miss =
/// answer feedback. Skill colours live on [Skill] and appear only next to
/// skills. Puzzles keep their own content colours.
abstract final class Lucid {
  // Light
  static const ground = Color(0xFFF6F5F1);
  static const surface = Color(0xFFFFFFFF);
  static const ink = Color(0xFF16161D);
  static const muted = Color(0xFF5C5C6B);
  static const line = Color(0xFFE4E2DA);
  static const chip = Color(0xFFEDEBE4);

  // Brand / rewards
  static const spark = Color(0xFFFF8A3D);
  static const sparkTint = Color(0xFFFFE8D6);
  static const sparkText = Color(0xFF7A3410);

  // Feedback (always paired with an icon)
  static const correct = Color(0xFF1F8A5B);
  static const correctTint = Color(0xFFEAF6EF);
  static const correctText = Color(0xFF17714A);
  static const miss = Color(0xFFD23F57);
  static const missTint = Color(0xFFFCE9EC);

  // Dark
  static const nightGround = Color(0xFF14131B);
  static const nightSurface = Color(0xFF1E1C29);
  static const nightRaised = Color(0xFF2A2836);
  static const nightLine = Color(0xFF34313F);
  static const nightText = Color(0xFFF3F2F7);
  static const nightMuted = Color(0xFFB4B1C4);

  // Shape
  static const double radiusS = 12;
  static const double radiusM = 16;
  static const double radiusL = 24;

  // Motion (see the design canvas notes)
  static const tap = Duration(milliseconds: 120);
  static const pop = Duration(milliseconds: 240);
  static const shake = Duration(milliseconds: 360);
  static const slide = Duration(milliseconds: 260);
}

/// Text or icon colour for a solid [fill] (a skill-coloured tile): white on
/// dark fills, ink on light ones such as the Focus yellow, so it always
/// reads, in both light and dark mode.
Color onFill(Color fill) =>
    fill.computeLuminance() > 0.3 ? Lucid.ink : const Color(0xFFFFFFFF);

/// Text in Lucid's two families. Both fonts are variable, so the weight is
/// sent as a `wght` variation as well as a [FontWeight].
TextStyle lucidText({
  double size = 16,
  int weight = 400,
  bool display = false,
  Color? color,
  double? height,
  double? letterSpacing,
}) {
  return TextStyle(
    fontFamily: display ? 'SpaceGrotesk' : 'Inter',
    fontSize: size,
    fontWeight: _fontWeight(weight),
    fontVariations: [FontVariation('wght', weight.toDouble())],
    color: color,
    height: height,
    letterSpacing: letterSpacing ?? (display ? -0.02 * size : null),
  );
}

FontWeight _fontWeight(int weight) =>
    FontWeight.values[(weight ~/ 100 - 1).clamp(
      0,
      FontWeight.values.length - 1,
    )];

extension LucidTextStyle on TextStyle {
  /// Changes weight on a variable font (sets both weight and `wght`).
  TextStyle weight(int w) => copyWith(
    fontWeight: _fontWeight(w),
    fontVariations: [FontVariation('wght', w.toDouble())],
  );
}

/// Section label: small, uppercase, tracked. Pass `Dims.of(context).label`
/// as [size] so it follows the density.
TextStyle lucidLabel(Color color, {double size = 13}) => lucidText(
  size: size,
  weight: 600,
  color: color,
  letterSpacing: size * 0.08,
);
