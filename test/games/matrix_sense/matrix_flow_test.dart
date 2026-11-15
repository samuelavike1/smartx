import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/games/matrix_sense/matrix_controller.dart';
import 'package:smartx/games/matrix_sense/matrix_screen.dart';
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

  Future<void> openMatrix(WidgetTester tester) async {
    await openFromGames(tester, 'Matrix Sense');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, {required bool right}) async {
    final q = container.read(matrixSessionProvider).question;
    final i = right ? q.answerIndex : (q.answerIndex + 1) % 4;
    final option = find.byKey(ValueKey('matrix-$i'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('Working it out'), findsOneWidget);
    expect(find.text(q.feedbackFor(q.options[i])), findsOneWidget);
    for (final step in q.steps) {
      expect(find.text(step), findsOneWidget);
    }
    // The matrices again, and the picture where there is one.
    expect(find.bySemanticsLabel(mathPlain(q.scene.lines.first)), findsWidgets);
    final pic = q.scene.picture;
    if (pic != null) expect(find.text(pic.title), findsOneWidget);
    expect(find.byType(MatrixPlane), pic == null ? findsNothing : findsOne);
    final next = find.byType(FilledButton);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  test('listed last in Calculus & Matrices', () {
    expect(GameCategory.maths.gameIds.last, 'matrix_sense');
    expect(GameCategory.maths.games.last.title, 'Matrix Sense');
  });

  testWidgets('a full Matrix Sense session: every answer right', (
    tester,
  ) async {
    await pumpApp(tester);
    await openMatrix(tester);
    for (var r = 0; r < MatrixController.totalRounds; r++) {
      await answer(tester, right: true);
    }
    expect(find.text('8 of 8 correct · new personal best'), findsOneWidget);
    final progress = container.read(progressProvider);
    expect(progress.xpFor(Skill.numbers), 80);
    expect(progress.xpFor(Skill.logic), 40);
    expect(progress.forGame('matrix_sense').sessions, 1);
  });

  testWidgets('a wrong pick offers a similar one afterwards', (tester) async {
    await pumpApp(tester, {'game.matrix_sense.level': 4});
    await openMatrix(tester);
    for (var r = 0; r < MatrixController.totalRounds; r++) {
      await answer(tester, right: r != 3);
    }
    final similar = find.byKey(const ValueKey('try-similar'));
    await tester.ensureVisible(similar);
    await tester.pumpAndSettle();
    await tester.tap(similar);
    await tester.pumpAndSettle();
    expect(container.read(matrixSessionProvider).practice, isTrue);
    await answer(tester, right: true);
    expect(container.read(matrixSessionProvider).finished, isTrue);
  });

  for (var level = 1; level <= 10; level++) {
    testWidgets('Matrix Sense at level $level fits a 360×640 phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpApp(tester, {'game.matrix_sense.level': level});
      await openMatrix(tester);
      // Wrong picks show the longest review; any overflow fails the test.
      for (var r = 0; r < 4; r++) {
        await answer(tester, right: false);
      }
    });
  }

  for (final level in [1, 5, 9]) {
    testWidgets('Matrix Sense at level $level and its reviews are dark', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, {'game.matrix_sense.level': level});
      await openFromGames(tester, 'Matrix Sense');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final c = container.read(matrixSessionProvider.notifier);
      for (var r = 0; r < 3; r++) {
        expect(dayColours(tester), isEmpty, reason: 'question at $level');
        final q = container.read(matrixSessionProvider).question;
        c.select(r.isEven ? q.answerIndex : (q.answerIndex + 1) % 4);
        await tester.pumpAndSettle();
        expect(dayColours(tester), isEmpty, reason: 'review at $level');
        await c.next();
        await tester.pumpAndSettle();
      }
    });
  }
}
