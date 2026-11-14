import 'package:flutter/widgets.dart';

/// One step of a game's rules: an icon, a short title and one sentence.
@immutable
class HowToStep {
  const HowToStep(this.icon, this.title, this.text);

  final IconData icon;
  final String title;
  final String text;
}

/// A game's rules, shown the first time it's opened and from the ? button.
/// Kept to three steps of plain words, plus what changes as you level up.
@immutable
class HowToPlay {
  const HowToPlay({required this.steps, required this.levels});

  final List<HowToStep> steps;

  /// "As you improve: …", without that prefix.
  final String levels;
}
