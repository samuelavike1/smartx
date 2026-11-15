import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/games/bond_desk/bond_controller.dart';

import '../../open_game.dart';
import '../../test_prefs.dart';
import '../../ui/dark_mode_test.dart' show dayColours;

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> extra = const {},
    bool dark = false,
  }) async {
    if (dark) {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    }
    SharedPreferences.setMockInitialValues(rulesSeen(extra));
    final prefs = await SharedPreferences.getInstance();
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

  Future<void> openBond(WidgetTester tester) async {
    await openFromGames(tester, 'Bond Desk');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    final f = find.byKey(ValueKey(key)).hitTestable();
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(f.first);
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, {required bool right}) async {
    final q = container.read(bondSessionProvider).question;
    final i = right ? q.answerIndex : (q.answerIndex + 1) % 4;
    await tapKey(tester, 'bond-$i');
    expect(find.text('Working it out'), findsOneWidget);
    expect(find.text(q.feedbackFor(q.options[i])), findsOneWidget);
    for (final s in q.steps) {
      expect(find.text(s), findsOneWidget);
    }
    final next = find.byType(FilledButton);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  test('Bond Desk sits in the Markets group, after Options Desk', () {
    expect(GameCategory.markets.gameIds, ['options_desk', 'bond_desk']);
    expect(GameCategory.markets.games.last.title, 'Bond Desk');
  });

  testWidgets('a full Bond Desk session through the Games tab', (tester) async {
    await pumpApp(tester);
    await openBond(tester);
    for (var r = 0; r < BondController.totalRounds; r++) {
      await answer(tester, right: true);
    }
    expect(find.text('8 of 8 correct · new personal best'), findsOneWidget);
    final progress = container.read(progressProvider);
    expect(progress.xpFor(Skill.numbers), 80);
    expect(progress.xpFor(Skill.problemSolving), 40);
    expect(progress.forGame('bond_desk').sessions, 1);
  });

  testWidgets('a miss is offered again as one practice round', (tester) async {
    await pumpApp(tester);
    await openBond(tester);
    for (var r = 0; r < BondController.totalRounds; r++) {
      await answer(tester, right: r != 3);
    }
    expect(find.text('7 of 8 correct · new personal best'), findsOneWidget);
    await tapKey(tester, 'try-similar');
    expect(container.read(bondSessionProvider).practice, isTrue);
    await answer(tester, right: true);
    expect(find.textContaining('of 8 correct'), findsOneWidget);
  });

  for (final level in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
    testWidgets('Bond Desk at level $level fits a 360×640 phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpApp(tester, extra: {'game.bond_desk.level': level});
      await openBond(tester);
      // Wrong picks show the longest review; any overflow fails the test.
      for (var r = 0; r < 4; r++) {
        await answer(tester, right: false);
      }
    });
  }

  for (final level in [3, 7, 9]) {
    testWidgets('Bond Desk at level $level and its reviews are dark', (
      tester,
    ) async {
      await pumpApp(tester, extra: {'game.bond_desk.level': level}, dark: true);
      await openBond(tester);
      final c = container.read(bondSessionProvider.notifier);
      for (var r = 0; r < 3; r++) {
        expect(dayColours(tester), isEmpty, reason: 'question, level $level');
        final q = container.read(bondSessionProvider).question;
        c.select(r.isEven ? (q.answerIndex + 1) % 4 : q.answerIndex);
        await tester.pumpAndSettle();
        expect(dayColours(tester), isEmpty, reason: 'review, level $level');
        await c.next();
        await tester.pumpAndSettle();
      }
    });
  }
}
