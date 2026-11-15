import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/core/game/game_definition.dart';
import 'package:smartx/core/game/game_registry.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/games/game_start_sheet.dart';
import 'package:smartx/features/games/games_screen.dart';
import 'package:smartx/features/games/group_screen.dart';
import 'package:smartx/games/odds_on/odds_controller.dart';

import '../open_game.dart';
import '../test_prefs.dart';
import '../ui/dark_mode_test.dart' show dayColours;

void main() {
  late ProviderContainer container;
  late SharedPreferences prefs;

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
    bool compact = false,
    bool dark = false,
  }) async {
    if (compact) {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }
    if (dark) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }
    SharedPreferences.setMockInitialValues(rulesSeen(saved));
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(ProgressRepository(prefs)),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SmartXApp()),
    );
    await tester.pumpAndSettle();
  }

  /// Odds On on level 5, having reached 7 before starting over once.
  const oddsOnLv5 = <String, Object>{
    'game.odds_on.level': 5,
    'game.odds_on.peak': 7,
    'game.odds_on.sessions': 6,
    'game.odds_on.best': 1140,
    'game.odds_on.lastDay': '2026-11-10',
  };

  test('every game but the teaser is in exactly one group', () {
    final listed = [for (final c in GameCategory.values) ...c.gameIds];
    expect(listed.toSet(), hasLength(listed.length), reason: 'a duplicate');
    for (final g in gameRegistry) {
      expect(
        listed.contains(g.id),
        g.id != 'teaser',
        reason: '${g.id} grouping',
      );
    }
    for (final c in GameCategory.values) {
      expect(c.games, hasLength(c.gameIds.length), reason: 'unknown id');
    }
  });

  test('the highest level survives a start over and old saves', () async {
    SharedPreferences.setMockInitialValues({'game.count_it.level': 4});
    final p = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(ProgressRepository(p)),
      ],
    );
    addTearDown(c.dispose);
    // Saved before groups: no peak stored, so the level is the peak.
    expect(c.read(progressProvider).forGame('count_it').peakLevel, 4);

    await c.read(progressProvider.notifier).startOver('count_it');
    var g = c.read(progressProvider).forGame('count_it');
    expect((g.level, g.peakLevel), (1, 4));
    expect(p.getInt('game.count_it.level'), 1);
    expect(p.getInt('game.count_it.peak'), 4);

    await c
        .read(progressProvider.notifier)
        .recordSession(
          const GameResult(
            gameId: 'count_it',
            score: 300,
            correct: 8,
            total: 8,
            endLevel: 2,
            skills: [Skill.numbers, Skill.logic],
          ),
        );
    g = c.read(progressProvider).forGame('count_it');
    expect((g.level, g.peakLevel, g.bestScore), (2, 4, 300));
  });

  test('last played reads as a day, not a date string', () {
    final now = DateTime(2026, 11, 15, 20);
    expect(lastPlayed(null, now), '—');
    expect(lastPlayed('2026-11-15', now), 'Today');
    expect(lastPlayed('2026-11-14', now), 'Yesterday');
    expect(lastPlayed('2026-11-10', now), '5 days ago');
    expect(lastPlayed('2026-10-02', now), '2 Oct');
  });

  testWidgets('the Games tab: the teaser, then five groups with progress', (
    tester,
  ) async {
    await pumpApp(tester, saved: oddsOnLv5);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    expect(find.text('TEASER OF THE DAY'), findsOneWidget);
    expect(find.text('Pick a group, then a game.'), findsOneWidget);
    // Only played games count: Odds On's highest level, 7.
    expect(find.text('7 / 170 levels', findRichText: true), findsOneWidget);
    for (final c in GameCategory.values) {
      await tester.scrollUntilVisible(
        find.text(c.title),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text(c.blurb), findsOneWidget);
    }
    expect(find.text('1 of 4 played'), findsOneWidget);
  });

  testWidgets('Continue starts at the saved level', (tester) async {
    await pumpApp(tester, saved: oddsOnLv5);
    await openGroup(tester, GameCategory.numbers);
    expect(find.text('Numbers & Odds'), findsOneWidget);
    expect(find.text('7 / 40 levels', findRichText: true), findsOneWidget);
    expect(find.textContaining('Lv 5', findRichText: true), findsOneWidget);
    expect(find.textContaining('top 7', findRichText: true), findsOneWidget);
    expect(find.text('New'), findsNWidgets(3));

    await tester.tap(find.text('Odds On'));
    await tester.pumpAndSettle();
    expect(find.text('Level 5 of 10'), findsOneWidget);
    expect(find.text('Highest: 7'), findsOneWidget);
    expect(find.text('1140'), findsOneWidget);
    expect(find.text('Continue at level 5'), findsOneWidget);
    expect(find.text('Start over from level 1'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sheet-continue')));
    await tester.pumpAndSettle();
    expect(container.read(oddsSessionProvider).level, 5);
  });

  testWidgets('Start over asks first, then plays from level 1', (tester) async {
    await pumpApp(tester, saved: oddsOnLv5);
    await openGroup(tester, GameCategory.numbers);
    await tester.tap(find.text('Odds On'));
    await tester.pumpAndSettle();

    // Cancel keeps everything.
    await tester.tap(find.byKey(const ValueKey('sheet-start-over')));
    await tester.pumpAndSettle();
    expect(find.text('Start Odds On over?'), findsOneWidget);
    expect(
      find.text('Your best score, XP and highest level (7) stay.'),
      findsOneWidget,
    );
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(container.read(progressProvider).forGame('odds_on').level, 5);
    expect(find.text('Continue at level 5'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('sheet-start-over')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-start-over')));
    await tester.pumpAndSettle();
    final g = container.read(progressProvider).forGame('odds_on');
    expect((g.level, g.peakLevel, g.bestScore, g.sessions), (1, 7, 1140, 6));
    expect(prefs.getInt('game.odds_on.level'), 1);
    expect(container.read(oddsSessionProvider).level, 1);
  });

  testWidgets('a game never played offers just Play', (tester) async {
    await pumpApp(tester);
    await openGroup(tester, GameCategory.markets);
    await tester.tap(find.text('Options Desk'));
    await tester.pumpAndSettle();
    expect(find.text('Play'), findsOneWidget);
    expect(find.byKey(const ValueKey('sheet-start-over')), findsNothing);
    expect(find.text('Highest: 1'), findsNothing);
    expect(find.text('What an option pays.'), findsOneWidget);
  });

  testWidgets('re-tapping Games goes back to the groups', (tester) async {
    await pumpApp(tester);
    await openGroup(tester, GameCategory.logic);
    expect(find.byType(GroupScreen), findsOneWidget);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    expect(find.byType(GroupScreen), findsNothing);
    expect(find.byType(GamesScreen), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'every group and its sheets fit 360×640 (${dark ? 'dark' : 'light'})',
      (tester) async {
        // Long numbers everywhere, so the tightest layout is the one tested.
        final saved = <String, Object>{
          for (final g in gameRegistry) ...{
            'game.${g.id}.level': 9,
            'game.${g.id}.peak': 10,
            'game.${g.id}.sessions': 120,
            'game.${g.id}.best': 12840,
            'game.${g.id}.lastDay': '2026-01-03',
          },
        };
        await pumpApp(tester, saved: saved, compact: true, dark: dark);
        for (final c in GameCategory.values) {
          await openGroup(tester, c);
          if (dark) expect(dayColours(tester), isEmpty, reason: c.title);
          for (final g in c.games) {
            final row = find.text(g.title);
            await tester.scrollUntilVisible(
              row,
              200,
              scrollable: find.descendant(
                of: find.byType(GroupScreen),
                matching: find.byType(Scrollable),
              ),
            );
            await tester.pumpAndSettle();
            await tester.tap(row);
            await tester.pumpAndSettle();
            // Any overflow fails the test on its own.
            expect(find.text('Continue at level 9'), findsOneWidget);
            if (dark) expect(dayColours(tester), isEmpty, reason: g.title);
            await tester.tap(find.byKey(const ValueKey('sheet-start-over')));
            await tester.pumpAndSettle();
            expect(find.text('Start ${g.title} over?'), findsOneWidget);
            await tester.tap(find.text('Cancel'));
            await tester.pumpAndSettle();
            Navigator.of(tester.element(find.byType(GameStartSheet))).pop();
            await tester.pumpAndSettle();
          }
        }
      },
    );
  }
}
