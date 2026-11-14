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
    ground: Color(0xFFEFEFF5),
    surface: Color(0xFFFFFFFF),
    chip: Color(0xFFE6E6EE),
    line: Color(0xFFE0E0E9),
    lineStrong: Color(0xFFCDCDD9),
    ink: Color(0xFF16161D),
    onInk: Color(0xFFFFFFFF),
    muted: Color(0xFF5C5C6B),
    faint: Color(0xFF6E6D7A),
    spark: Color(0xFFFF6A00),
    onSpark: Color(0xFF16161D),
    sparkTint: Color(0xFFFFD8B5),
    sparkText: Color(0xFF7C2D12),
    sparkStrong: Color(0xFFC2410C),
    correct: Color(0xFF16A34A),
    onCorrect: Color(0xFFFFFFFF),
    correctTint: Color(0xFFC8F4D6),
    correctText: Color(0xFF166534),
    miss: Color(0xFFE11D48),
    onMiss: Color(0xFFFFFFFF),
    missTint: Color(0xFFFFD3DC),
    missText: Color(0xFF9F1239),
    hero: Color(0xFF16161D),
    heroRow: Color(0xFF26252E),
    heroText: Color(0xFFFFFFFF),
    heroQuiet: Color(0xFFB9B8C2),
    heroLabel: Color(0xFFFF9A4D),
    heroAccent: Color(0xFFFFFFFF),
    onHeroAccent: Color(0xFF16161D),
    shadow: Color(0x0F16161D),
  );

  static const night = LucidPalette(
    // True black: OLED pixels switch off. Cards are drawn by hairline
    // borders, since shadows don't show on black.
    ground: Color(0xFF000000),
    surface: Color(0xFF101014),
    chip: Color(0xFF1C1C22),
    line: Color(0xFF26262E),
    lineStrong: Color(0xFF3F3F4A),
    ink: Color(0xFFF5F5F7),
    onInk: Color(0xFF000000),
    muted: Color(0xFFA8A8B3),
    faint: Color(0xFF7C7C88),
    spark: Color(0xFFFF7A1A),
    onSpark: Color(0xFF000000),
    sparkTint: Color(0xFF2E1600),
    sparkText: Color(0xFFFFA057),
    sparkStrong: Color(0xFFFF8C3A),
    correct: Color(0xFF22C55E),
    onCorrect: Color(0xFF000000),
    correctTint: Color(0xFF062E16),
    correctText: Color(0xFF4ADE80),
    miss: Color(0xFFFF3D63),
    onMiss: Color(0xFF000000),
    missTint: Color(0xFF33070F),
    missText: Color(0xFFFF7A92),
    hero: Color(0xFF101014),
    heroRow: Color(0xFF1C1C22),
    heroText: Color(0xFFF5F5F7),
    heroQuiet: Color(0xFFA8A8B3),
    heroLabel: Color(0xFFFFA057),
    heroAccent: Color(0xFFF5F5F7),
    onHeroAccent: Color(0xFF000000),
    shadow: Color(0x00000000),
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
