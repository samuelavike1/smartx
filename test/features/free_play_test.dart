import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/core/game/game_registry.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/today/today_screen.dart';

import '../test_prefs.dart';
import '../ui/dark_mode_test.dart' show dayColours;

void main() {
  for (final dark in [false, true]) {
    testWidgets('Free play lists every game once, by group '
        '(360×640, ${dark ? 'dark' : 'light'})', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      if (dark) {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      }
      SharedPreferences.setMockInitialValues(rulesSeen());
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            ProgressRepository(prefs),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SmartXApp(),
        ),
      );
      await tester.pumpAndSettle();

      final list = find.descendant(
        of: find.byType(TodayScreen),
        matching: find.byType(Scrollable),
      );
      // The last group's heading: everything above it is built by now.
      await tester.scrollUntilVisible(
        find.text(GameCategory.values.last.title),
        300,
        scrollable: list.first,
      );
      await tester.pumpAndSettle();
      // Any overflow fails the test on its own.

      expect(find.text('Daily'), findsOneWidget);
      for (final c in GameCategory.values) {
        if (c.games.isEmpty) continue;
        expect(
          find.text(c.title, skipOffstage: false),
          findsOneWidget,
          reason: c.title,
        );
      }
      for (final g in gameRegistry) {
        expect(
          find.bySemanticsLabel('Play ${g.title}', skipOffstage: false),
          findsOneWidget,
          reason: g.title,
        );
      }
      if (dark) expect(dayColours(tester), isEmpty);
    });
  }
}
