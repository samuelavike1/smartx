import 'package:material_ui/material_ui.dart';

/// Size tokens for the two densities on the "Density · regular vs compact"
/// artboard. Regular matches the 390×844 artboards; compact applies on small
/// phones (shorter than 700 or narrower than 375 logical px).
///
/// Touch targets never go below 44 in either density.
@immutable
class Dims {
  const Dims._({
    required this.compact,
    required this.screenTitle,
    required this.score,
    required this.button,
    required this.pill,
    required this.pillText,
    required this.label,
    required this.body,
    required this.small,
    required this.rowTitle,
    required this.control,
    required this.tile,
    required this.option,
    required this.spot,
    required this.tray,
    required this.gapXL,
    required this.gapL,
    required this.gapM,
    required this.gapS,
    required this.cardPad,
    required this.rowPad,
    required this.rowCircle,
    required this.navHeight,
    required this.skillBars,
    required this.freeTile,
    required this.topPad,
    required this.pathChrome,
  });

  static const regular = Dims._(
    compact: false,
    screenTitle: 32,
    score: 56,
    button: 52,
    pill: 30,
    pillText: 13,
    label: 13,
    body: 15,
    small: 13,
    rowTitle: 16,
    control: 56,
    tile: 48,
    option: 80,
    spot: 72,
    tray: 56,
    gapXL: 28,
    gapL: 20,
    gapM: 16,
    gapS: 12,
    cardPad: 20,
    rowPad: 12,
    rowCircle: 32,
    navHeight: 56,
    skillBars: 72,
    freeTile: 96,
    topPad: 12,
    pathChrome: 330,
  );

  static const compactDims = Dims._(
    compact: true,
    screenTitle: 26,
    score: 44,
    button: 46,
    pill: 26,
    pillText: 12,
    label: 12,
    body: 14,
    small: 12,
    rowTitle: 15,
    control: 48,
    tile: 40,
    option: 64,
    spot: 60,
    tray: 48,
    gapXL: 16,
    gapL: 14,
    gapM: 12,
    gapS: 8,
    cardPad: 16,
    rowPad: 10,
    rowCircle: 28,
    navHeight: 50,
    skillBars: 56,
    freeTile: 80,
    topPad: 8,
    // Measured on the CS50C: the hint wraps to two lines at 12 px.
    pathChrome: 292,
  );

  final bool compact;

  /// "Today", "Games"… (game titles come from the theme's headlineSmall).
  final double screenTitle;

  /// Results score.
  final double score;
  final double button;
  final double pill;
  final double pillText;

  /// Uppercase section labels.
  final double label;
  final double body;
  final double small;

  /// Titles inside list rows (workout games).
  final double rowTitle;

  /// Square control buttons (Path Finder arrows).
  final double control;

  /// Pattern Sequence sequence tiles.
  final double tile;

  /// Largest answer option tile.
  final double option;

  /// Deduce spots.
  final double spot;

  /// Deduce tray shapes.
  final double tray;
  final double gapXL;
  final double gapL;
  final double gapM;
  final double gapS;
  final double cardPad;
  final double rowPad;
  final double rowCircle;

  /// Floating tab bar height.
  final double navHeight;

  /// Height of the skill bars on Today.
  final double skillBars;

  /// Free-play tile height on Today.
  final double freeTile;

  /// Space above the first item of a screen.
  final double topPad;

  /// Vertical space the Path Finder screen needs besides the board.
  final double pathChrome;

  static bool isCompactSize(Size s) => s.height < 700 || s.width < 375;

  static Dims forSize(Size s) => isCompactSize(s) ? compactDims : regular;

  static Dims of(BuildContext context) => forSize(MediaQuery.sizeOf(context));
}
