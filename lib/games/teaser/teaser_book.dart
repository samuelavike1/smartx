import 'dart:math';

import 'teasers.dart';

/// Which teaser plays when. Everyone gets the same teaser on the same day;
/// playing again that day gives a bonus one, never the day's own.
class TeaserBook {
  const TeaserBook._();

  /// A fixed shuffle, so neighbouring days don't follow the source order.
  static final List<Teaser> order = [...teasers]..shuffle(Random(2026));

  static final _epoch = DateTime.utc(2025);

  /// Days since 1 Jan 2025 by the calendar date, in UTC so daylight saving
  /// can't make a day 23 hours long.
  static int dayNumber(DateTime day) =>
      DateTime.utc(day.year, day.month, day.day).difference(_epoch).inDays;

  static Teaser forDay(DateTime day) => order[dayNumber(day) % order.length];

  /// The [n]th bonus teaser on [day] (n from 1).
  static Teaser bonus(DateTime day, int n) {
    final daily = dayNumber(day) % order.length;
    final step = 1 + (n - 1) % (order.length - 1);
    return order[(daily + step) % order.length];
  }

  static int pointsFor(Teaser t, int hints) =>
      max(20, 100 + 40 * t.difficulty - 30 * hints);
}
