import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/games/calc_sprint/calc_controller.dart';
import 'package:smartx/games/calc_sprint/calc_puzzle.dart';
import 'package:smartx/games/calc_sprint/calc_screen.dart';
import 'package:smartx/ui/theme.dart';
import 'package:smartx/ui/widgets/math_text.dart';

import '../../open_game.dart';
import '../../test_prefs.dart';
import '../../ui/dark_mode_test.dart' show dayColours;

/// Shows one chosen question (and, with [pick], its review).
class _Fixed extends CalcController {
  _Fixed(this.q, this.pick);

  final CalcQuestion q;
  final int? pick;

  @override
  CalcSessionState build() => CalcSessionState(
    round: 0,
    totalRounds: CalcController.totalRounds,
    level: q.level,
    startLevel: q.level,
    question: q,
    picked: pick,
  );
}

void main() {
  // A session only meets a few random questions; this walks many of them
  // (the questions and wrong-pick reviews) on the smallest phone.
  testWidgets('every level\'s questions and reviews fit a 360×640 phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const gen = CalcGenerator();
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 40; seed++) {
        final q = gen.generate(level: level, seed: seed);
        for (final pick in [null, (q.answerIndex + 1) % 4]) {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                calcSessionProvider.overrideWith(() => _Fixed(q, pick)),
              ],
              child: MaterialApp(
                theme: buildTheme(Brightness.light, compact: true),
                home: const CalcScreen(),
              ),
            ),
          );
          await tester.pump();
          expect(
            tester.takeException(),
            isNull,
            reason:
                'level $level seed $seed ${pick == null ? 'question' : 'review'}',
          );
        }
      }
    }
  });

  testWidgets('every level\'s questions and reviews are dark', (tester) async {
    const gen = CalcGenerator();
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 8; seed++) {
        final q = gen.generate(level: level, seed: seed);
        for (final pick in [null, (q.answerIndex + 1) % 4]) {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                calcSessionProvider.overrideWith(() => _Fixed(q, pick)),
              ],
              child: MaterialApp(
                theme: buildTheme(Brightness.dark),
                home: const CalcScreen(),
              ),
            ),
          );
          await tester.pump();
          expect(dayColours(tester), isEmpty, reason: 'level $level $seed');
        }
      }
    }
  });

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

  Future<void> openCalc(WidgetTester tester) async {
    await openFromGames(tester, 'Calc Sprint');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, {required bool right}) async {
    final q = container.read(calcSessionProvider).question;
    // The card's maths is on screen, read out as plain text.
    expect(find.bySemanticsLabel(mathPlain(q.card)), findsWidgets);
    expect(find.text(q.question), findsOneWidget);
    final i = right ? q.answerIndex : (q.answerIndex + 1) % 4;
    final option = find.byKey(ValueKey('calc-$i'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
    expect(find.text('Working it out'), findsOneWidget);
    expect(find.text(q.feedbackFor(q.options[i])), findsOneWidget);
    for (final step in q.steps) {
      expect(find.text(step.text), findsWidgets);
    }
    expect(
      find.text('The graph'),
      q.reviewGraph != null ? findsOneWidget : findsNothing,
    );
    final next = find.byType(FilledButton);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  test('listed last in Calculus & Matrices', () {
    expect(GameCategory.maths.gameIds.last, 'calc_sprint');
    expect(GameCategory.maths.games.last.title, 'Calc Sprint');
  });

  testWidgets('a full Calc Sprint session: every answer right', (tester) async {
    await pumpApp(tester);
    await openCalc(tester);
    for (var r = 0; r < CalcController.totalRounds; r++) {
      await answer(tester, right: true);
    }
    expect(find.text('8 of 8 correct · new personal best'), findsOneWidget);
    final progress = container.read(progressProvider);
    expect(progress.xpFor(Skill.numbers), 80);
    expect(progress.xpFor(Skill.problemSolving), 40);
    expect(progress.forGame('calc_sprint').sessions, 1);
  });

  testWidgets('a wrong pick offers a similar one afterwards', (tester) async {
    await pumpApp(tester, {'game.calc_sprint.level': 4});
    await openCalc(tester);
    for (var r = 0; r < CalcController.totalRounds; r++) {
      await answer(tester, right: r != 3);
    }
    final similar = find.byKey(const ValueKey('try-similar'));
    await tester.ensureVisible(similar);
    await tester.pumpAndSettle();
    await tester.tap(similar);
    await tester.pumpAndSettle();
    expect(container.read(calcSessionProvider).practice, isTrue);
    await answer(tester, right: true);
    expect(container.read(calcSessionProvider).finished, isTrue);
  });

  for (var level = 1; level <= 10; level++) {
    testWidgets('Calc Sprint at level $level fits a 360×640 phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpApp(tester, {'game.calc_sprint.level': level});
      await openCalc(tester);
      // Wrong picks show the longest review; any overflow fails the test.
      for (var r = 0; r < 5; r++) {
        await answer(tester, right: false);
      }
    });
  }

  for (final level in [1, 4, 7, 9]) {
    testWidgets('Calc Sprint at level $level and its reviews are dark', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, {'game.calc_sprint.level': level});
      await openFromGames(tester, 'Calc Sprint');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final c = container.read(calcSessionProvider.notifier);
      for (var r = 0; r < 3; r++) {
        expect(dayColours(tester), isEmpty, reason: 'question at $level');
        final q = container.read(calcSessionProvider).question;
        c.select(r.isEven ? q.answerIndex : (q.answerIndex + 1) % 4);
        await tester.pumpAndSettle();
        expect(dayColours(tester), isEmpty, reason: 'review at $level');
        await c.next();
        await tester.pumpAndSettle();
      }
    });
  }
}
