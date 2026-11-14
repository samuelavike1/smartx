import 'dart:math';

/// [count] options in ascending order, with the right answer at a random
/// position.
///
/// Sorted options are quick to scan, but if the wrong answers mostly sit on
/// one side of the right one, its position gives it away. So the position
/// is chosen first, uniformly; then wrong answers are taken for each side:
/// named mistakes from [preferred] first (they explain a wrong pick), then
/// near misses from [fillers] (in the caller's shuffled order). If one side
/// runs short, the other makes up the numbers.
List<T> balancedOptions<T>(
  T answer,
  Iterable<T> preferred,
  Iterable<T> fillers,
  Random rng, {
  required int Function(T a, T b) compare,
  int count = 4,
}) {
  final pool = [...preferred, ...fillers];
  final under = [
    for (final x in pool)
      if (compare(x, answer) < 0) x,
  ];
  final over = [
    for (final x in pool)
      if (compare(x, answer) > 0) x,
  ];
  final chosen = <T>[];
  bool isNew(T x) => !chosen.any((c) => compare(c, x) == 0);
  int take(List<T> from, int n) {
    var got = 0;
    for (final x in from) {
      if (got == n) break;
      if (isNew(x)) {
        chosen.add(x);
        got++;
      }
    }
    return got;
  }

  // How many wrong answers sit below the right one.
  final below = rng.nextInt(count);
  final gotBelow = take(under, below);
  final above = count - 1 - gotBelow;
  final gotAbove = take(over, above);
  if (gotAbove < above) take(under, above - gotAbove);

  return [answer, ...chosen]..sort(compare);
}
