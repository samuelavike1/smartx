import 'package:material_ui/material_ui.dart';

/// Shape that marks a skill everywhere it appears, so skills never depend on
/// colour alone.
enum SkillMarker { square, circle, triangle, diamond, ring, plus }

/// Cognitive skills that games can train. Every game tags itself with the
/// skills it exercises; finished sessions award XP to those skills.
///
/// Skill colours appear only next to skills (markers, bars, tiles), never as
/// action or feedback colours.
enum Skill {
  logic('Logic', 'Logic', Color(0xFF2563EB), SkillMarker.square),
  patternRecognition(
    'Pattern recognition',
    'Pattern',
    Color(0xFF0F8B8D),
    SkillMarker.circle,
  ),
  attention('Attention', 'Focus', Color(0xFFEAB308), SkillMarker.triangle),
  problemSolving(
    'Problem solving',
    'Solve',
    Color(0xFFB83280),
    SkillMarker.diamond,
  ),
  memory('Memory', 'Memory', Color(0xFF8B5CF6), SkillMarker.ring),

  /// The quant track (Odds On and the games after it): probability,
  /// counting and mental arithmetic. Dark lime: the one hue left between
  /// Focus yellow and the correct-answer green.
  numbers('Numbers', 'Numbers', Color(0xFF4D7C0F), SkillMarker.plus);

  const Skill(this.label, this.shortLabel, this.color, this.marker);

  final String label;
  final String shortLabel;
  final Color color;
  final SkillMarker marker;
}
