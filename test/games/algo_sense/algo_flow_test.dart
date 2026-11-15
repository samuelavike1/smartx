import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/games/algo_sense/algo_controller.dart';
import 'package:smartx/games/algo_sense/algo_puzzle.dart';
import 'package:smartx/games/algo_sense/algo_screen.dart';
import 'package:smartx/ui/theme.dart';
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

  Future<void> openAlgo(WidgetTester tester) async {
    await openFromGames(tester, 'Algo Sense');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> answer(WidgetTester tester, {required bool right}) async {
    final q = container.read(algoSessionProvider).question;
    // The card: its maths, code and picture.
    for (final l in q.scene.lines) {
      expect(find.bySemanticsLabel(mathPlain(l)), findsWidgets);
    }
    expect(
      find.byType(AlgoCode),
      q.scene.code.isEmpty ? findsNothing : findsOne,
    );
    final onCard = q.scene.pictureOnCard && q.scene.picture != null;
    expect(find.byType(AlgoPictureView), onCard ? findsOne : findsNothing);
    final i = right ? q.answerIndex : (q.answerIndex + 1) % 4;
    final option = find.byKey(ValueKey('algo-$i'));
    await tester.ensureVisible(option);
    await tester.pumpAndSettle();
    await tester.tap(option);
    await tester.pumpAndSettle();
    // The review: tiles, the picture filled in, three steps, the slip.
    expect(find.text('Working it out'), findsOneWidget);
    expect(find.text(q.feedbackFor(q.options[i])), findsOneWidget);
    for (final step in q.steps) {
      expect(find.text(step), findsOneWidget);
    }
    expect(find.text(right ? 'Your answer · right' : 'Right'), findsOneWidget);
    final pic = q.scene.picture;
    if (pic != null) expect(find.text(pic.title), findsOneWidget);
    expect(find.byType(AlgoPictureView), pic == null ? findsNothing : findsOne);
    final next = find.byType(FilledButton);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  test('listed last in Logic & Puzzles', () {
    expect(GameCategory.logic.gameIds, contains('algo_sense'));
    expect(GameCategory.logic.gameIds.last, 'algo_sense');
  });

  testWidgets('a full Algo Sense session: every answer right', (tester) async {
    await pumpApp(tester);
    await openAlgo(tester);
    for (var r = 0; r < AlgoController.totalRounds; r++) {
      await answer(tester, right: true);
    }
    expect(find.text('8 of 8 correct · new personal best'), findsOneWidget);
    final progress = container.read(progressProvider);
    expect(progress.xpFor(Skill.logic), 80);
    expect(progress.xpFor(Skill.problemSolving), 40);
    expect(progress.forGame('algo_sense').sessions, 1);
  });

  testWidgets('a wrong pick offers a similar one afterwards', (tester) async {
    await pumpApp(tester, {'game.algo_sense.level': 4});
    await openAlgo(tester);
    for (var r = 0; r < AlgoController.totalRounds; r++) {
      await answer(tester, right: r != 3);
    }
    final similar = find.byKey(const ValueKey('try-similar'));
    await tester.ensureVisible(similar);
    await tester.pumpAndSettle();
    await tester.tap(similar);
    await tester.pumpAndSettle();
    expect(container.read(algoSessionProvider).practice, isTrue);
    await answer(tester, right: true);
    expect(container.read(algoSessionProvider).finished, isTrue);
  });

  for (var level = 1; level <= 10; level++) {
    testWidgets('Algo Sense at level $level fits a 360×640 phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      await pumpApp(tester, {'game.algo_sense.level': level});
      await openAlgo(tester);
      // Wrong picks show the longest review; any overflow fails the test.
      for (var r = 0; r < 5; r++) {
        await answer(tester, right: false);
      }
    });
  }

  for (final level in [1, 5, 8]) {
    testWidgets('Algo Sense at level $level and its reviews are dark', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, {'game.algo_sense.level': level});
      await openFromGames(tester, 'Algo Sense');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();
      final c = container.read(algoSessionProvider.notifier);
      for (var r = 0; r < 3; r++) {
        expect(dayColours(tester), isEmpty, reason: 'question at $level');
        final q = container.read(algoSessionProvider).question;
        c.select(r.isEven ? q.answerIndex : (q.answerIndex + 1) % 4);
        await tester.pumpAndSettle();
        expect(dayColours(tester), isEmpty, reason: 'review at $level');
        await c.next();
        await tester.pumpAndSettle();
      }
    });
  }

  // A session only meets a few random questions; these walk many of them,
  // every kind and every picture, on the question and on the review.
  testWidgets('every level\'s questions and reviews fit a 360×640 phone', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    const gen = AlgoGenerator();
    final pictures = <Type>{};
    final kinds = <AlgoKind>{};
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 40; seed++) {
        final q = gen.generate(level: level, seed: seed);
        kinds.add(q.kind);
        if (q.scene.picture case final pic?) pictures.add(pic.runtimeType);
        for (final pick in [null, (q.answerIndex + 1) % 4]) {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                algoSessionProvider.overrideWith(() => _Fixed(q, pick)),
              ],
              child: MaterialApp(
                theme: buildTheme(Brightness.light, compact: true),
                home: const AlgoScreen(),
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
          if (pick == null) continue;
          final why = 'level $level seed $seed';
          for (final step in q.steps) {
            expect(find.text(step), findsOneWidget, reason: '$why: $step');
          }
          expect(
            find.text(q.feedbackFor(q.options[pick])),
            findsOneWidget,
            reason: why,
          );
          if (q.scene.picture case final pic?) {
            expect(find.text(pic.title), findsOneWidget, reason: why);
          }
        }
      }
    }
    expect(kinds, AlgoKind.values.toSet());
    expect(pictures, hasLength(14));
  });

  testWidgets('every level\'s questions and reviews are dark', (tester) async {
    const gen = AlgoGenerator();
    for (var level = 1; level <= 10; level++) {
      for (var seed = 0; seed < 8; seed++) {
        final q = gen.generate(level: level, seed: seed);
        for (final pick in [null, (q.answerIndex + 1) % 4]) {
          await tester.pumpWidget(
            ProviderScope(
              key: UniqueKey(),
              overrides: [
                algoSessionProvider.overrideWith(() => _Fixed(q, pick)),
              ],
              child: MaterialApp(
                theme: buildTheme(Brightness.dark),
                home: const AlgoScreen(),
              ),
            ),
          );
          await tester.pump();
          expect(dayColours(tester), isEmpty, reason: 'level $level $seed');
        }
      }
    }
  });
}

/// Shows one chosen question (and, with [pick], its review).
class _Fixed extends AlgoController {
  _Fixed(this.q, this.pick);

  final AlgoQuestion q;
  final int? pick;

  @override
  AlgoSessionState build() => AlgoSessionState(
    round: 0,
    totalRounds: AlgoController.totalRounds,
    level: q.level,
    startLevel: q.level,
    question: q,
    picked: pick,
  );
}
