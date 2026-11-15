import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/games/vol_lab/vol_controller.dart';
import 'package:smartx/games/vol_lab/vol_screen.dart';
import 'package:smartx/ui/widgets/math_text.dart';

import '../../open_game.dart';
import '../../test_prefs.dart';
import '../../ui/dark_mode_test.dart' show dayColours;

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(
    WidgetTester tester, [
    Map<String, Object> extra = const {},
  ]) async {
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

  Future<void> openVol(WidgetTester tester) async {
    await openFromGames(tester, 'Vol Lab');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, {required bool right}) async {
    final q = container.read(volSessionProvider).question;
    // The card: its chips, its maths read out as plain text, the question.
    for (final chip in q.scene.chips) {
      expect(find.text(chip), findsOneWidget);
    }
    for (final line in q.scene.lines) {
      expect(find.bySemanticsLabel(mathPlain(line)), findsWidgets);
    }
    expect(find.text(q.question), findsOneWidget);
    final onCard = q.scene.pictureOnCard && q.scene.picture != null;
    expect(find.byType(VolChart), onCard ? findsOne : findsNothing);
    final i = right ? q.answerIndex : (q.answerIndex + 1) % 4;
    final option = find.byKey(ValueKey('vol-$i'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('Working it out'), findsOneWidget);
    expect(find.text(q.feedbackFor(q.options[i])), findsOneWidget);
    for (final step in q.steps) {
      expect(find.text(step.text), findsWidgets);
      if (step.math case final m?) {
        expect(find.bySemanticsLabel(mathPlain(m)), findsWidgets);
      }
    }
    // The picture comes back on the review, with its title.
    final pic = q.scene.picture;
    if (pic != null) expect(find.text(pic.title), findsOneWidget);
    expect(find.byType(VolChart), pic == null ? findsNothing : findsOne);
    final next = find.byType(FilledButton);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  test('listed in Markets', () {
    expect(GameCategory.markets.gameIds, contains('vol_lab'));
  });

  testWidgets('a full Vol Lab session: every answer right', (tester) async {
    await pumpApp(tester);
    await openVol(tester);
    for (var r = 0; r < VolController.totalRounds; r++) {
      await answer(tester, right: true);
    }
    expect(find.text('8 of 8 correct · new personal best'), findsOneWidget);
    final progress = container.read(progressProvider);
    expect(progress.xpFor(Skill.numbers), 80);
    expect(progress.xpFor(Skill.problemSolving), 40);
    expect(progress.forGame('vol_lab').sessions, 1);
  });

  testWidgets('a wrong pick offers a similar one afterwards', (tester) async {
    await pumpApp(tester, {'game.vol_lab.level': 6});
    await openVol(tester);
    for (var r = 0; r < VolController.totalRounds; r++) {
      await answer(tester, right: r != 3);
    }
    final similar = find.byKey(const ValueKey('try-similar'));
    await tester.ensureVisible(similar);
    await tester.pumpAndSettle();
    await tester.tap(similar);
    await tester.pumpAndSettle();
    expect(container.read(volSessionProvider).practice, isTrue);
    await answer(tester, right: true);
    expect(container.read(volSessionProvider).finished, isTrue);
  });

  for (var level = 1; level <= 10; level++) {
    testWidgets('Vol Lab at level $level fits a 360×640 phone', (tester) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpApp(tester, {'game.vol_lab.level': level});
      await openVol(tester);
      // Wrong picks show the longest review; any overflow fails the test.
      for (var r = 0; r < 4; r++) {
        await answer(tester, right: false);
      }
    });
  }

  for (final level in [1, 6, 9]) {
    testWidgets('Vol Lab at level $level and its reviews are dark', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, {'game.vol_lab.level': level});
      await openFromGames(tester, 'Vol Lab');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final c = container.read(volSessionProvider.notifier);
      for (var r = 0; r < 3; r++) {
        expect(dayColours(tester), isEmpty, reason: 'question at $level');
        final q = container.read(volSessionProvider).question;
        c.select(r.isEven ? q.answerIndex : (q.answerIndex + 1) % 4);
        await tester.pumpAndSettle();
        expect(dayColours(tester), isEmpty, reason: 'review at $level');
        await c.next();
        await tester.pumpAndSettle();
      }
    });
  }
}
