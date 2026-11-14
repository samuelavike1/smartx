import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_registry.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/profile/profile_screen.dart';
import 'package:smartx/ui/density.dart';

import '../test_prefs.dart';

void main() {
  Future<void> openProfile(
    WidgetTester tester,
    Map<String, Object> saved, {
    bool dark = false,
  }) async {
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
    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
  }

  /// [n] games played, best scores 100, 200, … (the last one highest).
  Map<String, Object> played(int n) => {
    for (final (i, g) in gameRegistry.take(n).indexed) ...{
      'game.${g.id}.best': 100 * (i + 1),
      'game.${g.id}.sessions': i + 1,
      'game.${g.id}.level': 2,
    },
    'skill.logic.xp': 250,
    'skill.problemSolving.xp': 430,
  };

  testWidgets('before any play: level 1 and a nudge to play', (tester) async {
    await openProfile(tester, {});
    expect(find.text('Level 1'), findsOneWidget);
    expect(find.text('0 XP · 100 to level 2'), findsOneWidget);
    expect(find.text('Play a game to set your first best.'), findsOneWidget);
    expect(find.text('0 games'), findsOneWidget);
  });

  testWidgets('brain level, top skill, and bests highest first', (
    tester,
  ) async {
    await openProfile(tester, played(7));
    // 250 + 430 = 680 XP: level 7, 20 to go.
    expect(find.text('Level 7'), findsOneWidget);
    expect(find.text('680 XP · 20 to level 8'), findsOneWidget);
    expect(find.text('Solve'), findsWidgets);
    expect(find.text('7 games'), findsOneWidget);

    // Top five shown, the best first; then all seven.
    final best = gameRegistry[6], fifth = gameRegistry[2];
    final sixth = gameRegistry[1];
    expect(find.text(best.title), findsOneWidget);
    expect(find.text(fifth.title), findsOneWidget);
    expect(find.text(sixth.title), findsNothing);
    expect(
      tester.getTopLeft(find.text(best.title)).dy,
      lessThan(tester.getTopLeft(find.text(fifth.title)).dy),
    );
    final list = find
        .descendant(
          of: find.byType(ProfileScreen),
          matching: find.byType(Scrollable),
        )
        .first;
    await tester.scrollUntilVisible(
      find.text('Show all 7'),
      100,
      scrollable: list,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Show all 7'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text(sixth.title),
      100,
      scrollable: find
          .descendant(
            of: find.byType(ProfileScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    expect(find.text(sixth.title), findsOneWidget);
    expect(find.text('Level 2 · 2 sessions'), findsOneWidget);
  });

  testWidgets('Profile fits a 360×640 phone at night', (tester) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    await openProfile(tester, played(17), dark: true);
    await tester.ensureVisible(find.text('Show all 17'));
    await tester.tap(find.text('Show all 17'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('Appearance'));
    await tester.pumpAndSettle();
  });

  testWidgets('the tab bar is 56 high (50 on small phones)', (tester) async {
    await openProfile(tester, {});
    final bar = find.byWidgetPredicate(
      (w) =>
          w is Container && w.constraints?.maxHeight == Dims.regular.navHeight,
    );
    expect(Dims.regular.navHeight, 56);
    expect(Dims.compactDims.navHeight, 50);
    expect(bar, findsOneWidget);
  });
}
