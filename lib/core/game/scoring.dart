/// Points for one correct answer: harder levels are worth more, and quick
/// answers earn a bonus that fades out over ten seconds.
int pointsForCorrectAnswer({required int level, required Duration elapsed}) {
  final base = 50 + level * 10;
  final speedBonus = (30 - elapsed.inSeconds * 3).clamp(0, 30);
  return base + speedBonus;
}
