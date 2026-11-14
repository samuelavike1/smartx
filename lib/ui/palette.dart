import 'package:material_ui/material_ui.dart';

/// Every colour a screen paints, by role, for light and night. Screens read
/// `context.palette` and never use raw colours, so dark mode follows
/// automatically. Values come from the "Night · colour roles and contrast"
/// artboard; `palette_test.dart` checks their contrast.
@immutable
class LucidPalette extends ThemeExtension<LucidPalette> {
  const LucidPalette({
    required this.ground,
    required this.surface,
    required this.chip,
    required this.line,
    required this.lineStrong,
    required this.ink,
    required this.onInk,
    required this.muted,
    required this.faint,
    required this.spark,
    required this.onSpark,
    required this.sparkTint,
    required this.sparkText,
    required this.sparkStrong,
    required this.correct,
    required this.onCorrect,
    required this.correctTint,
    required this.correctText,
    required this.miss,
    required this.onMiss,
    required this.missTint,
    required this.missText,
    required this.hero,
    required this.heroRow,
    required this.heroText,
    required this.heroQuiet,
    required this.heroLabel,
    required this.heroAccent,
    required this.onHeroAccent,
    required this.shadow,
  });

  /// Screen background.
  final Color ground;

  /// Cards and buttons.
  final Color surface;

  /// Chips, pills and raised rows.
  final Color chip;

  /// Borders and empty tracks.
  final Color line;

  /// Dashed outlines and empty spots that must stand out a little more.
  final Color lineStrong;

  /// Text, actions and selection. Inverts at night (near-white).
  final Color ink;

  /// Text and icons on an [ink] fill.
  final Color onInk;

  /// Secondary text.
  final Color muted;

  /// Inactive text (a bar that isn't ready yet).
  final Color faint;

  /// Brand, combo and rewards.
  final Color spark;

  /// Text on a [spark] fill (dark in both modes).
  final Color onSpark;
  final Color sparkTint;
  final Color sparkText;

  /// Brand icons and labels on plain backgrounds.
  final Color sparkStrong;

  /// Right answers: borders and icon circles.
  final Color correct;

  /// Icons drawn on a [correct] fill.
  final Color onCorrect;
  final Color correctTint;
  final Color correctText;

  /// Wrong answers: borders and icon circles.
  final Color miss;

  /// Icons drawn on a [miss] fill.
  final Color onMiss;
  final Color missTint;
  final Color missText;

  /// The workout card on Today.
  final Color hero;
  final Color heroRow;
  final Color heroText;
  final Color heroQuiet;
  final Color heroLabel;

  /// Light parts inside the workout card (the up-next row, Start button).
  final Color heroAccent;
  final Color onHeroAccent;

  /// Soft card shadows.
  final Color shadow;

  bool get isNight => ground.computeLuminance() < 0.2;

  static const light = LucidPalette(
    ground: Color(0xFFF6F5F1),
    surface: Color(0xFFFFFFFF),
    chip: Color(0xFFEDEBE4),
    line: Color(0xFFE4E2DA),
    lineStrong: Color(0xFFD9D6CC),
    ink: Color(0xFF16161D),
    onInk: Color(0xFFFFFFFF),
    muted: Color(0xFF5C5C6B),
    faint: Color(0xFF7A7987),
    spark: Color(0xFFFF8A3D),
    onSpark: Color(0xFF16161D),
    sparkTint: Color(0xFFFFE8D6),
    sparkText: Color(0xFF7A3410),
    sparkStrong: Color(0xFFB4501A),
    correct: Color(0xFF1F8A5B),
    onCorrect: Color(0xFFFFFFFF),
    correctTint: Color(0xFFEAF6EF),
    correctText: Color(0xFF17714A),
    miss: Color(0xFFD23F57),
    onMiss: Color(0xFFFFFFFF),
    missTint: Color(0xFFFCE9EC),
    missText: Color(0xFFB3304A),
    hero: Color(0xFF16161D),
    heroRow: Color(0xFF26252E),
    heroText: Color(0xFFFFFFFF),
    heroQuiet: Color(0xFFB9B8C2),
    heroLabel: Color(0xFFFFB27A),
    heroAccent: Color(0xFFFFFFFF),
    onHeroAccent: Color(0xFF16161D),
    shadow: Color(0x0F16161D),
  );

  static const night = LucidPalette(
    ground: Color(0xFF14131B),
    surface: Color(0xFF1E1C29),
    chip: Color(0xFF2A2836),
    line: Color(0xFF34313F),
    lineStrong: Color(0xFF4A4757),
    ink: Color(0xFFF3F2F7),
    onInk: Color(0xFF16161D),
    muted: Color(0xFFB4B1C4),
    faint: Color(0xFF8E8B9E),
    spark: Color(0xFFFF8A3D),
    onSpark: Color(0xFF16161D),
    sparkTint: Color(0xFF3D2817),
    sparkText: Color(0xFFFFB27A),
    sparkStrong: Color(0xFFFF9F5E),
    correct: Color(0xFF3DBE84),
    onCorrect: Color(0xFF14131B),
    correctTint: Color(0xFF173B2C),
    correctText: Color(0xFF7FE0B0),
    miss: Color(0xFFF0607A),
    onMiss: Color(0xFF14131B),
    missTint: Color(0xFF42202A),
    missText: Color(0xFFFF9AAC),
    hero: Color(0xFF26242F),
    heroRow: Color(0xFF34313F),
    heroText: Color(0xFFF3F2F7),
    heroQuiet: Color(0xFFB4B1C4),
    heroLabel: Color(0xFFFFB27A),
    heroAccent: Color(0xFFF3F2F7),
    onHeroAccent: Color(0xFF16161D),
    shadow: Color(0x66000000),
  );

  @override
  LucidPalette copyWith() => this;

  @override
  LucidPalette lerp(LucidPalette? other, double t) {
    if (other == null) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return LucidPalette(
      ground: c(ground, other.ground),
      surface: c(surface, other.surface),
      chip: c(chip, other.chip),
      line: c(line, other.line),
      lineStrong: c(lineStrong, other.lineStrong),
      ink: c(ink, other.ink),
      onInk: c(onInk, other.onInk),
      muted: c(muted, other.muted),
      faint: c(faint, other.faint),
      spark: c(spark, other.spark),
      onSpark: c(onSpark, other.onSpark),
      sparkTint: c(sparkTint, other.sparkTint),
      sparkText: c(sparkText, other.sparkText),
      sparkStrong: c(sparkStrong, other.sparkStrong),
      correct: c(correct, other.correct),
      onCorrect: c(onCorrect, other.onCorrect),
      correctTint: c(correctTint, other.correctTint),
      correctText: c(correctText, other.correctText),
      miss: c(miss, other.miss),
      onMiss: c(onMiss, other.onMiss),
      missTint: c(missTint, other.missTint),
      missText: c(missText, other.missText),
      hero: c(hero, other.hero),
      heroRow: c(heroRow, other.heroRow),
      heroText: c(heroText, other.heroText),
      heroQuiet: c(heroQuiet, other.heroQuiet),
      heroLabel: c(heroLabel, other.heroLabel),
      heroAccent: c(heroAccent, other.heroAccent),
      onHeroAccent: c(onHeroAccent, other.onHeroAccent),
      shadow: c(shadow, other.shadow),
    );
  }
}

extension LucidPaletteOf on BuildContext {
  /// The colour roles for the current light/dark mode.
  LucidPalette get palette =>
      Theme.of(this).extension<LucidPalette>() ?? LucidPalette.light;
}
