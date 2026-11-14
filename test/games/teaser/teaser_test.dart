import 'package:flutter_test/flutter_test.dart';
import 'package:smartx/games/teaser/teaser_book.dart';
import 'package:smartx/games/teaser/teasers.dart';

void main() {
  test('every teaser is complete', () {
    expect(teasers.length, greaterThanOrEqualTo(30));
    expect(teasers.map((t) => t.id).toSet(), hasLength(teasers.length));
    expect(teasers.map((t) => t.title).toSet(), hasLength(teasers.length));
    for (final t in teasers) {
      expect(t.difficulty, inInclusiveRange(1, 3), reason: t.id);
      expect(t.hints, hasLength(3), reason: t.id);
      expect(t.traps, hasLength(3), reason: t.id);
      final labels = {t.answer, ...t.traps.map((x) => x.label)};
      expect(labels, hasLength(4), reason: '${t.id}: answers must differ');
      expect(t.steps.length, inInclusiveRange(2, 4), reason: t.id);
      for (final text in [
        t.title,
        t.text,
        t.insight,
        ...t.hints,
        ...t.steps,
        ...t.traps.map((x) => x.why),
      ]) {
        expect(text.trim(), isNotEmpty, reason: t.id);
        expect(text, isNot(contains('  ')), reason: '${t.id}: "$text"');
      }
      for (final x in t.traps) {
        expect(t.feedbackFor(x.label), x.why);
      }
      expect(t.feedbackFor(t.answer), t.insight);
    }
  });

  test('every day has a teaser, and a month shows them all', () {
    final start = DateTime(2026, 11, 14);
    final month = {
      for (var i = 0; i < teasers.length; i++)
        TeaserBook.forDay(start.add(Duration(days: i))).id,
    };
    expect(month, hasLength(teasers.length));
    expect(
      TeaserBook.forDay(DateTime(2026, 11, 14, 8)).id,
      TeaserBook.forDay(DateTime(2026, 11, 14, 23, 59)).id,
    );
  });

  test('a bonus teaser is never the day\'s own', () {
    for (var d = 0; d < 60; d++) {
      final day = DateTime(2026, 3, 1).add(Duration(days: d));
      for (var n = 1; n <= 100; n++) {
        expect(TeaserBook.bonus(day, n).id, isNot(TeaserBook.forDay(day).id));
      }
    }
  });

  test('daylight saving doesn\'t skip or repeat a day', () {
    // Clocks change in late March and late October in much of Europe.
    for (final start in [DateTime(2026, 3, 27), DateTime(2026, 10, 23)]) {
      var last = TeaserBook.dayNumber(start);
      for (var i = 1; i < 6; i++) {
        final day = DateTime(start.year, start.month, start.day + i);
        expect(TeaserBook.dayNumber(day), last + 1);
        last++;
      }
    }
  });

  test('hints cost 30 points each, never below 20', () {
    final easy = teasers.firstWhere((t) => t.difficulty == 1);
    final hard = teasers.firstWhere((t) => t.difficulty == 3);
    expect(TeaserBook.pointsFor(easy, 0), 140);
    expect(TeaserBook.pointsFor(easy, 3), 50);
    expect(TeaserBook.pointsFor(hard, 0), 220);
    expect(TeaserBook.pointsFor(hard, 3), 130);
    expect(TeaserBook.pointsFor(easy, 10), 20);
  });
}
