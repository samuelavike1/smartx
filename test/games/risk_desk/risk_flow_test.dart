import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/games/risk_desk/risk_controller.dart';
import 'package:smartx/games/risk_desk/risk_puzzle.dart';

import '../../open_game.dart';
import '../../test_prefs.dart';
import '../../ui/dark_mode_test.dart' show dayColours;

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> extra = const {},
    bool dark = false,
    bool small = false,
  }) async {
    if (small) {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
    }
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

  Future<void> openRisk(WidgetTester tester) async {
    await openFromGames(tester, 'Risk Desk');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)).hitTestable().first);
    await tester.pumpAndSettle();
  }

  Future<RiskQuestion> answer(
    WidgetTester tester, {
    required bool right,
  }) async {
    final q = container.read(riskSessionProvider).question;
    expect(find.text(q.question), findsOneWidget);
    expect(find.text(q.hint), findsOneWidget);
    final i = right ? q.answerIndex : (q.answerIndex + 1) % 4;
    await tapKey(tester, 'risk-$i');
    expect(find.text('Working it out'), findsOneWidget);
    expect(find.text(q.feedbackFor(q.options[i])), findsOneWidget);
    for (final s in q.steps) {
      expect(find.text(s), findsOneWidget);
    }
    if (!right) {
      expect(find.text('Your answer'), findsOneWidget);
      expect(find.text('Right'), findsOneWidget);
    }
    final next = find.byType(FilledButton);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
    return q;
  }

  test('Risk Desk is in the Markets group', () {
    expect(groupOf('Risk Desk'), GameCategory.markets);
    expect(GameCategory.markets.gameIds.last, 'risk_desk');
  });

  testWidgets('a full Risk Desk session: every answer right', (tester) async {
    await pumpApp(tester);
    await openRisk(tester);
    for (var r = 0; r < RiskController.totalRounds; r++) {
      await answer(tester, right: true);
    }
    expect(find.text('8 of 8 correct · new personal best'), findsOneWidget);
    final progress = container.read(progressProvider);
    expect(progress.xpFor(Skill.numbers), 80);
    expect(progress.xpFor(Skill.problemSolving), 40);
  });

  testWidgets('a wrong pick, then "Try a similar one" plays unscored', (
    tester,
  ) async {
    await pumpApp(tester, extra: {'game.risk_desk.level': 6});
    await openRisk(tester);
    for (var r = 0; r < RiskController.totalRounds; r++) {
      await answer(tester, right: r != 3);
    }
    expect(find.text('7 of 8 correct · new personal best'), findsOneWidget);
    final similar = find.text('Try a similar one');
    await tester.ensureVisible(similar);
    await tester.pumpAndSettle();
    await tester.tap(similar);
    await tester.pumpAndSettle();
    final s = container.read(riskSessionProvider);
    expect(s.practice, isTrue);
    final before = s.score;
    await tapKey(tester, 'risk-${s.question.answerIndex}');
    expect(container.read(riskSessionProvider).score, before);
  });

  for (final level in [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
    testWidgets('Risk Desk at level $level fits a 360×640 phone', (
      tester,
    ) async {
      await pumpApp(
        tester,
        extra: {'game.risk_desk.level': level},
        small: true,
      );
      await openRisk(tester);
      // Wrong picks show the longest review; any overflow fails the test.
      for (var r = 0; r < 5; r++) {
        await answer(tester, right: false);
      }
    });
  }

  for (final level in [2, 4, 5, 7, 8, 10]) {
    testWidgets('Risk Desk at level $level and its reviews are dark', (
      tester,
    ) async {
      await pumpApp(tester, extra: {'game.risk_desk.level': level}, dark: true);
      await openFromGames(tester, 'Risk Desk');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final c = container.read(riskSessionProvider.notifier);
      for (var r = 0; r < 3; r++) {
        expect(dayColours(tester), isEmpty, reason: 'question, level $level');
        final q = container.read(riskSessionProvider).question;
        c.select(r.isEven ? (q.answerIndex + 1) % 4 : q.answerIndex);
        await tester.pumpAndSettle();
        expect(dayColours(tester), isEmpty, reason: 'review, level $level');
        await c.next();
        await tester.pumpAndSettle();
      }
    });
  }
}
