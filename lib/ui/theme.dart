import 'package:material_ui/material_ui.dart';

import 'lucid.dart';

/// Hand-built theme: no `ColorScheme.fromSeed`, so Material's tonal tints
/// (lavender containers, tinted surfaces) never appear. The goal is a look
/// that belongs to SmartX on both iOS and Android.
///
/// [compact] applies the compact density (see `density.dart`): smaller
/// titles and body text, shorter buttons. Touch targets stay ≥ 44.
ThemeData buildTheme(Brightness brightness, {bool compact = false}) {
  final dark = brightness == Brightness.dark;
  final c = compact;

  final ground = dark ? Lucid.nightGround : Lucid.ground;
  final surface = dark ? Lucid.nightSurface : Lucid.surface;
  final text = dark ? Lucid.nightText : Lucid.ink;
  final muted = dark ? Lucid.nightMuted : Lucid.muted;
  final line = dark ? Lucid.nightLine : Lucid.line;
  final raised = dark ? Lucid.nightRaised : Lucid.chip;

  final scheme = ColorScheme(
    brightness: brightness,
    // Actions: ink on light, near-white on dark.
    primary: text,
    onPrimary: dark ? Lucid.ink : Lucid.surface,
    primaryContainer: raised,
    onPrimaryContainer: text,
    secondary: Lucid.spark,
    onSecondary: Lucid.ink,
    secondaryContainer: Lucid.sparkTint,
    onSecondaryContainer: Lucid.sparkText,
    tertiary: Lucid.correct,
    onTertiary: Lucid.surface,
    error: Lucid.miss,
    onError: Lucid.surface,
    surface: surface,
    onSurface: text,
    onSurfaceVariant: muted,
    surfaceContainerLowest: surface,
    surfaceContainerLow: surface,
    surfaceContainer: surface,
    surfaceContainerHigh: raised,
    surfaceContainerHighest: raised,
    outline: line,
    outlineVariant: line,
    surfaceTint: Colors.transparent,
    shadow: Colors.black,
    inverseSurface: dark ? Lucid.surface : Lucid.ink,
    onInverseSurface: dark ? Lucid.ink : Lucid.surface,
  );

  final textTheme = TextTheme(
    displayLarge: lucidText(size: 56, weight: 700, display: true, color: text),
    displayMedium: lucidText(size: 40, weight: 700, display: true, color: text),
    // Screen titles ("Today"): 32 regular, 26 compact.
    displaySmall: lucidText(
      size: c ? 26 : 32,
      weight: 700,
      display: true,
      color: text,
    ),
    headlineMedium: lucidText(
      size: c ? 24 : 28,
      weight: 700,
      display: true,
      color: text,
    ),
    // Game screen titles ("What comes next?"): 26/600 per the In game
    // artboard, 21 compact.
    headlineSmall: lucidText(
      size: c ? 21 : 26,
      weight: 600,
      display: true,
      color: text,
    ),
    titleLarge: lucidText(
      size: c ? 18 : 20,
      weight: 700,
      display: true,
      color: text,
    ),
    titleMedium: lucidText(size: c ? 15 : 16, weight: 600, color: text),
    titleSmall: lucidText(size: c ? 13 : 14, weight: 600, color: text),
    bodyLarge: lucidText(size: c ? 15 : 16, color: text, height: 1.45),
    bodyMedium: lucidText(size: c ? 14 : 15, color: text, height: 1.45),
    bodySmall: lucidText(size: c ? 12 : 13, color: muted, height: 1.4),
    labelLarge: lucidText(size: 15, weight: 600, color: text),
    labelMedium: lucidText(size: 13, weight: 600, color: muted),
    labelSmall: lucidText(size: 12, weight: 500, color: muted),
  );

  final pill = WidgetStatePropertyAll<OutlinedBorder>(const StadiumBorder());

  return ThemeData(
    useMaterial3: true,
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: ground,
    canvasColor: ground,
    fontFamily: 'Inter',
    textTheme: textTheme,
    // Feedback comes from scale + haptics, not ink ripples.
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    appBarTheme: AppBarTheme(
      backgroundColor: ground,
      foregroundColor: text,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      titleTextStyle: lucidText(
        size: 20,
        weight: 700,
        display: true,
        color: text,
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: line),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        // Disabled = line fill + muted label (the "Check" button on the
        // Deduce artboard).
        backgroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? line : scheme.primary,
        ),
        foregroundColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled) ? muted : scheme.onPrimary,
        ),
        minimumSize: WidgetStatePropertyAll(Size(160, c ? 46 : 52)),
        shape: pill,
        textStyle: WidgetStatePropertyAll(
          lucidText(size: c ? 15 : 16, weight: 600),
        ),
        elevation: const WidgetStatePropertyAll(0),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(text),
        minimumSize: WidgetStatePropertyAll(Size(120, c ? 46 : 52)),
        shape: pill,
        side: WidgetStatePropertyAll(BorderSide(color: line, width: 1.5)),
        textStyle: WidgetStatePropertyAll(lucidText(size: 16, weight: 600)),
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        foregroundColor: WidgetStatePropertyAll(text),
        minimumSize: WidgetStatePropertyAll(Size(64, c ? 44 : 48)),
        shape: pill,
        textStyle: WidgetStatePropertyAll(lucidText(size: 15, weight: 600)),
      ),
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: line,
      linearMinHeight: 8,
      borderRadius: BorderRadius.circular(99),
    ),
    dividerTheme: DividerThemeData(color: line, thickness: 1, space: 1),
    // Page transitions stay on Flutter's platform defaults: the iOS slide
    // (with back-swipe) on iPhone, fade-forward on Android.
  );
}
