import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/profile/profile_screen.dart';
import 'package:smartx/ui/palette.dart';

import '../test_prefs.dart';

void main() {
  late SharedPreferences prefs;

  Future<void> start(WidgetTester tester) async {
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

  bool isNight(WidgetTester tester) =>
      Theme.of(tester.element(find.byType(Scaffold).first))
          .extension<LucidPalette>()!
          .isNight;

  Future<void> openProfile(WidgetTester tester) async {
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    // Appearance sits at the end of the page.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('theme-dark')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('Dark is chosen, saved, and kept after a restart', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(rulesSeen());
    prefs = await SharedPreferences.getInstance();
    await start(tester);
    expect(isNight(tester), isFalse);
    await openProfile(tester);
    expect(find.text('System follows your phone\'s setting.'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('theme-dark')));
    await tester.pumpAndSettle();
    expect(isNight(tester), isTrue);
    expect(
      find.text('Dark is true black: kind to OLED screens and batteries.'),
      findsOneWidget,
    );
    expect(prefs.getString('appearance.theme'), 'dark');

    // A fresh start on a phone set to light still opens dark.
    await tester.pumpWidget(const SizedBox());
    await start(tester);
    expect(isNight(tester), isTrue);
  });

  testWidgets('System follows the phone; Light overrides it', (tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    SharedPreferences.setMockInitialValues(rulesSeen());
    prefs = await SharedPreferences.getInstance();
    await start(tester);
    expect(isNight(tester), isTrue);
    await openProfile(tester);
    await tester.tap(find.byKey(const ValueKey('theme-light')));
    await tester.pumpAndSettle();
    expect(isNight(tester), isFalse);
    await tester.tap(find.byKey(const ValueKey('theme-system')));
    await tester.pumpAndSettle();
    expect(isNight(tester), isTrue);
    expect(prefs.getString('appearance.theme'), 'system');
  });
}
