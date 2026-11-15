import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/games/group_screen.dart';
import 'package:smartx/features/today/today_screen.dart';

import '../test_prefs.dart';
import '../ui/dark_mode_test.dart' show dayColours;

void main() {
  Future<void> pumpApp(
    WidgetTester tester, {
    bool dark = false,
    Map<String, Object> saved = const {},
  }) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    if (dark) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }
    SharedPreferences.setMockInitialValues(rulesSeen(saved));
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
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

  final groups = [
    for (final c in GameCategory.values)
      if (c.games.isNotEmpty) c,
  ];

  Future<void> scrollToFreePlay(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.bySemanticsLabel('Open ${groups.last.title}'),
      300,
      scrollable: find
          .descendant(
            of: find.byType(TodayScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  for (final dark in [false, true]) {
    testWidgets('Free play is the teaser plus a card per group '
        '(360×640, ${dark ? 'dark' : 'light'})', (tester) async {
      await pumpApp(
        tester,
        dark: dark,
        saved: {'game.odds_on.sessions': 2, 'game.odds_on.level': 3},
      );
      await scrollToFreePlay(tester);
      // Any overflow fails the test on its own.
      expect(
        find.bySemanticsLabel('Play Teaser of the day', skipOffstage: false),
        findsWidgets,
      );
      for (final c in groups) {
        expect(
          find.bySemanticsLabel('Open ${c.title}', skipOffstage: false),
          findsOneWidget,
          reason: c.title,
        );
      }
      // Games are no longer listed one by one on Today.
      expect(find.bySemanticsLabel('Play Odds On'), findsNothing);
      expect(
        find.text(
          '${GameCategory.numbers.games.length} games · 1 played',
          skipOffstage: false,
        ),
        findsOneWidget,
      );
      if (dark) expect(dayColours(tester), isEmpty);
    });
  }

  testWidgets('a group card opens its games inside Today; Back returns', (
    tester,
  ) async {
    await pumpApp(tester);
    await scrollToFreePlay(tester);
    await tester.tap(find.bySemanticsLabel('Open Numbers & Odds'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupScreen), findsOneWidget);
    expect(find.text('Numbers & Odds'), findsOneWidget);
    expect(find.bySemanticsLabel('Play Odds On'), findsOneWidget);
    // Still the Today tab: its tab is selected, the bar is there.
    expect(find.text('Today'), findsWidgets);

    // A game opens the Continue / Play sheet, as on the Games tab.
    await tester.tap(find.bySemanticsLabel('Play Odds On'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('sheet-continue')), findsOneWidget);
    Navigator.of(tester.element(find.byKey(const ValueKey('sheet-continue'))))
        .pop();
    await tester.pumpAndSettle();

    await tester.tap(find.bySemanticsLabel('Back to Games'));
    await tester.pumpAndSettle();
    expect(find.byType(GroupScreen), findsNothing);
    expect(find.byType(TodayScreen), findsOneWidget);
  });
}
