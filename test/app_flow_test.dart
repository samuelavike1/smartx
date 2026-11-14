import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/speed_game.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/games/games_screen.dart';
import 'package:smartx/games/arrow_focus/arrow_controller.dart';
import 'package:smartx/games/arrow_focus/arrow_puzzle.dart';
import 'package:smartx/games/deduce/deduce_controller.dart';
import 'package:smartx/games/echo_back/echo_controller.dart';
import 'package:smartx/games/echo_back/echo_puzzle.dart';
import 'package:smartx/games/grid_recall/grid_recall_controller.dart';
import 'package:smartx/games/ink_clash/ink_controller.dart';
import 'package:smartx/games/odd_one_out/odd_controller.dart';
import 'package:smartx/games/odds_on/odds_controller.dart';
import 'package:smartx/games/path_finder/path_controller.dart';
import 'package:smartx/games/path_finder/path_puzzle.dart';
import 'package:smartx/games/pattern_sequence/pattern_sequence_controller.dart';
import 'package:smartx/ui/widgets/glass_nav_bar.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
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

  testWidgets('Today tab shows the next game and the glass tab bar', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.byType(GlassNavBar), findsOneWidget);
    expect(find.byKey(const ValueKey('start-training')), findsOneWidget);
    expect(find.text('Pattern Sequence'), findsWidgets);
  });

  testWidgets('tabs switch screens', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Skills').last);
    await tester.pumpAndSettle();
    expect(find.text('Every 100 XP is a new skill level.'), findsOneWidget);

    await tester.tap(find.text('Profile').last);
    await tester.pumpAndSettle();
    expect(find.text('Sessions played'), findsOneWidget);
  });

  testWidgets('a full session can be played and is saved', (tester) async {
    await pumpApp(tester);
    await tester.tap(find.byKey(const ValueKey('start-training')));
    await tester.pumpAndSettle();
    expect(find.text('What comes next?'), findsOneWidget);
    // Games run full screen: no tab bar.
    expect(find.byType(GlassNavBar), findsNothing);

    for (var round = 0; round < PatternSessionController.totalRounds; round++) {
      final answer = container.read(patternSessionProvider).puzzle.answerIndex;
      await tester.tap(find.byKey(ValueKey('option-$answer')));
      await tester.pumpAndSettle();
      expect(find.text('Correct!'), findsOneWidget);

      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.tap(next);
      await tester.pumpAndSettle();
    }

    // Results, per the artboard: workout progress, accuracy + best, the way on.
    expect(find.text('WORKOUT · GAME 1 OF 3 DONE'), findsOneWidget);
    expect(find.text('10 of 10 correct · new personal best'), findsOneWidget);
    expect(find.text('Skill XP earned'), findsOneWidget);
    expect(find.text('+100 XP'), findsOneWidget); // main skill
    expect(find.text('+50 XP'), findsNWidgets(2)); // the other two
    expect(find.text('Next game: Grid Recall'), findsOneWidget);
    expect(find.byKey(const ValueKey('try-similar')), findsNothing);
    expect(container.read(patternSessionProvider).combo, 10);

    final saved = container.read(progressProvider).forGame('pattern_sequence');
    expect(saved.sessions, 1);
    expect(saved.level, greaterThan(1));
    expect(saved.bestScore, greaterThan(0));
  });

  testWidgets('a full Grid Recall session can be played from the Games tab', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Grid Recall'));
    await tester.pumpAndSettle();
    expect(find.text('Watch the cells'), findsOneWidget);

    for (var round = 0; round < GridRecallController.totalRounds; round++) {
      final puzzle = container.read(gridSessionProvider).puzzle;
      // Cells can't be tapped while the pattern is showing.
      await tester.tap(find.byKey(ValueKey('cell-${puzzle.cells.first}')));
      expect(container.read(gridSessionProvider).taps, isEmpty);

      await tester.pump(
        puzzle.memorizeDuration + const Duration(milliseconds: 50),
      );
      await tester.pumpAndSettle();
      expect(container.read(gridSessionProvider).phase, GridPhase.recall);

      for (final cell in puzzle.cells) {
        await tester.tap(find.byKey(ValueKey('cell-$cell')));
        await tester.pump();
      }
      await tester.pumpAndSettle();
      expect(find.text('Correct!'), findsOneWidget);

      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }

    expect(find.text('WORKOUT · GAME 1 OF 3 DONE'), findsOneWidget);
    expect(find.text('8 of 8 correct · new personal best'), findsOneWidget);
    final saved = container.read(progressProvider).forGame('grid_recall');
    expect(saved.sessions, 1);
    expect(container.read(progressProvider).xpFor(Skill.memory), 80);
  });

  testWidgets('a full Deduce session: place shapes, check, see review', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deduce'));
    await tester.pumpAndSettle();
    expect(find.text('Who goes where?'), findsOneWidget);

    for (var round = 0; round < DeduceController.totalRounds; round++) {
      final puzzle = container.read(deduceSessionProvider).puzzle;

      // Check stays disabled until every spot is filled.
      final check = find.byKey(const ValueKey('check'));
      await tester.ensureVisible(check);
      await tester.pumpAndSettle();
      expect(tester.widget<FilledButton>(check).onPressed, isNull);

      for (final (i, item) in puzzle.solution.indexed) {
        final tray = find.byKey(ValueKey('tray-${item.name}'));
        await tester.ensureVisible(tray);
        await tester.pumpAndSettle();
        await tester.tap(tray);
        await tester.pump();
        await tester.tap(find.byKey(ValueKey('slot-$i')));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(check);
      await tester.pumpAndSettle();
      await tester.tap(check);
      await tester.pumpAndSettle();
      expect(find.text('Correct!'), findsOneWidget);
      expect(find.text('YOUR ANSWER'), findsOneWidget);
      expect(find.text('SOLUTION'), findsNothing);

      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }

    expect(find.text('WORKOUT · GAME 1 OF 3 DONE'), findsOneWidget);
    expect(find.text('5 of 5 correct · new personal best'), findsOneWidget);
    expect(container.read(progressProvider).forGame('deduce').sessions, 1);
    expect(container.read(progressProvider).xpFor(Skill.logic), 50);
  });

  testWidgets('a full Path Finder session: slide with the arrow buttons', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    final card = find.text('Path Finder');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pumpAndSettle();
    expect(find.text('Reach the flag'), findsOneWidget);

    for (var round = 0; round < PathController.totalRounds; round++) {
      final puzzle = container.read(pathSessionProvider).puzzle;
      expect(
        find.textContaining(
          '${puzzle.moveLimit} of ${puzzle.moveLimit} moves left',
        ),
        findsOneWidget,
      );
      for (final d in puzzle.solution) {
        final button = find.byKey(ValueKey('move-${d.word}'));
        await tester.ensureVisible(button);
        await tester.pumpAndSettle();
        await tester.tap(button);
        await tester.pumpAndSettle();
      }
      expect(container.read(pathSessionProvider).won, isTrue);
      expect(find.text('Correct!'), findsOneWidget);
      expect(find.textContaining('Shortest route'), findsOneWidget);

      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('5 of 5 correct · new personal best'), findsOneWidget);
    expect(container.read(progressProvider).xpFor(Skill.problemSolving), 50);
  });

  testWidgets('a full Echo Back session: tap Match on every real match', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    final card = find.text('Echo Back');
    await tester.ensureVisible(card);
    await tester.pumpAndSettle();
    await tester.tap(card);
    // The pushed route builds on the next frame.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Get ready…'), findsOneWidget);

    for (var block = 0; block < EchoController.totalRounds; block++) {
      await tester.pump(EchoController.getReady);
      var s = container.read(echoSessionProvider);
      expect(s.phase, EchoPhase.playing);
      final match = find.byKey(const ValueKey('echo-square'));

      while (s.phase == EchoPhase.playing) {
        if (s.block.isTarget(s.step, EchoChannel.square)) {
          await tester.tap(match);
          await tester.pump(const Duration(milliseconds: 160));
          expect(container.read(echoSessionProvider).lastTap?.correct, isTrue);
        }
        await tester.pump(s.block.interval);
        s = container.read(echoSessionProvider);
      }
      await tester.pumpAndSettle();
      expect(s.result!.passed, isTrue);
      expect(s.result!.falseTaps, isEmpty);
      expect(find.textContaining('with no false taps'), findsOneWidget);

      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    expect(find.text('4 of 4 correct · new personal best'), findsOneWidget);
    expect(container.read(progressProvider).xpFor(Skill.memory), 40);
  });

  testWidgets('a full Ink Clash session: always tap the right colour', (
    tester,
  ) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    // The Games list builds cards lazily: scroll until this one exists.
    final card = find.text('Ink Clash');
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.descendant(
        of: find.byType(GamesScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Get ready…'), findsOneWidget);

    for (var block = 0; block < SpeedController.totalRounds; block++) {
      await tester.pump(SpeedController.getReady);
      var s = container.read(inkSessionProvider);
      while (s.phase == SpeedPhase.playing) {
        if (s.flash == null) {
          final key = find.byKey(ValueKey('ink-${s.trial!.answer.name}'));
          await tester.tap(key);
          await tester.pump();
          expect(container.read(inkSessionProvider).flash?.correct, isTrue);
        }
        await tester.pump(SpeedController.flashFor);
        s = container.read(inkSessionProvider);
      }
      await tester.pumpAndSettle();
      expect(s.result!.right, 12);
      expect(find.textContaining('All 12 right.'), findsOneWidget);
      expect(find.text('Your speed'), findsOneWidget);

      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();
    expect(find.text('3 of 3 correct · new personal best'), findsOneWidget);
    expect(container.read(progressProvider).xpFor(Skill.attention), 30);
  });

  Future<void> openArrowFocus(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    final card = find.text('Arrow Focus');
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.descendant(
        of: find.byType(GamesScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Get ready…'), findsOneWidget);
  }

  testWidgets('a full Arrow Focus session: always tap the middle arrow', (
    tester,
  ) async {
    await openArrowFocus(tester);
    for (var block = 0; block < SpeedController.totalRounds; block++) {
      await tester.pump(SpeedController.getReady);
      var s = container.read(arrowSessionProvider);
      expect(find.text('FOLLOW THE MIDDLE'), findsOneWidget);
      while (s.phase == SpeedPhase.playing) {
        if (s.flash == null) {
          final key = find.byKey(ValueKey('arrow-${s.trial!.answer.name}'));
          await tester.tap(key);
          await tester.pump();
          expect(container.read(arrowSessionProvider).flash?.correct, isTrue);
        }
        await tester.pump(SpeedController.flashFor);
        s = container.read(arrowSessionProvider);
      }
      await tester.pumpAndSettle();
      expect(s.result!.right, 12);
      expect(find.textContaining('All 12 right.'), findsOneWidget);
      expect(find.text('Arrows disagreed'), findsOneWidget);

      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();
    expect(find.text('3 of 3 correct · new personal best'), findsOneWidget);
    expect(container.read(progressProvider).xpFor(Skill.attention), 30);
  });

  testWidgets('Arrow Focus: a swipe answers the row', (tester) async {
    await openArrowFocus(tester);
    await tester.pump(SpeedController.getReady);
    final s = container.read(arrowSessionProvider);
    final answer = s.trial!.answer;
    final wrong = answer == ArrowDir.left ? ArrowDir.right : ArrowDir.left;
    final travel = wrong == ArrowDir.left
        ? const Offset(-120, 0)
        : const Offset(120, 0);
    await tester.flingFrom(const Offset(200, 400), travel, 1500);
    await tester.pump();
    final flash = container.read(arrowSessionProvider).flash;
    expect(flash?.tapped, wrong);
    expect(flash?.correct, isFalse);

    // A short drag is not a swipe.
    await tester.pump(SpeedController.flashFor);
    await tester.dragFrom(const Offset(200, 400), const Offset(12, 0));
    await tester.pump();
    expect(container.read(arrowSessionProvider).flash, isNull);
    expect(container.read(arrowSessionProvider).answers, hasLength(1));
  });

  Future<void> openOddOneOut(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    final card = find.text('Odd One Out');
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.descendant(
        of: find.byType(GamesScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Get ready…'), findsOneWidget);
  }

  testWidgets('a full Odd One Out session: always tap the odd tile', (
    tester,
  ) async {
    await openOddOneOut(tester);
    for (var block = 0; block < SpeedController.totalRounds; block++) {
      await tester.pump(SpeedController.getReady);
      var s = container.read(oddSessionProvider);
      expect(find.text('TAP THE ODD ONE'), findsOneWidget);
      while (s.phase == SpeedPhase.playing) {
        if (s.flash == null) {
          // The outgoing grid is still on screen for a moment, but only the
          // current one takes taps.
          final key = find
              .byKey(ValueKey('odd-${s.trial!.answer}'))
              .hitTestable();
          await tester.tap(key);
          await tester.pump();
          expect(container.read(oddSessionProvider).flash?.correct, isTrue);
        }
        await tester.pump(SpeedController.flashFor);
        s = container.read(oddSessionProvider);
      }
      await tester.pumpAndSettle();
      expect(s.result!.right, 12);
      expect(find.textContaining('All 12 right.'), findsOneWidget);
      expect(find.text('Odd shape, turn or size'), findsOneWidget);
      expect(find.text('The odd one'), findsNothing);

      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }
    await tester.pumpAndSettle();
    expect(find.text('3 of 3 correct · new personal best'), findsOneWidget);
    expect(container.read(progressProvider).xpFor(Skill.attention), 30);
    expect(
      container.read(progressProvider).xpFor(Skill.patternRecognition),
      15,
    );
  });

  testWidgets('Odd One Out: a wrong tap is shown, then the missed grid', (
    tester,
  ) async {
    await openOddOneOut(tester);
    await tester.pump(SpeedController.getReady);
    var s = container.read(oddSessionProvider);
    final missedGrid = s.trial!;
    final wrong = (missedGrid.odd + 1) % missedGrid.tiles.length;
    await tester.tap(find.byKey(ValueKey('odd-$wrong')).hitTestable());
    await tester.pump();
    s = container.read(oddSessionProvider);
    expect(s.markFor(wrong), SpeedMark.wrong);
    expect(s.markFor(missedGrid.odd), SpeedMark.answer);

    // Let every other grid run out of time.
    while (container.read(oddSessionProvider).phase == SpeedPhase.playing) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    expect(find.text('Grid 1'), findsOneWidget);
    expect(find.text('The odd one'), findsOneWidget);
    expect(find.text('Your tap'), findsOneWidget);
    expect(find.textContaining('Grid 1: the odd one was in'), findsOneWidget);
  });

  Future<void> openOddsOn(WidgetTester tester) async {
    await pumpApp(tester);
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    final card = find.text('Odds On');
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.descendant(
        of: find.byType(GamesScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pump();
    await tester.pumpAndSettle();
  }

  testWidgets('a full Odds On session: always pick the right probability', (
    tester,
  ) async {
    await openOddsOn(tester);
    for (var r = 0; r < OddsController.totalRounds; r++) {
      final q = container.read(oddsSessionProvider).question;
      expect(find.text(q.question), findsOneWidget);
      final option = find.byKey(ValueKey('odds-${q.answerIndex}'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(find.text('Working it out'), findsOneWidget);
      expect(find.text(q.insight), findsOneWidget);

      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.text('8 of 8 correct · new personal best'), findsOneWidget);
    final progress = container.read(progressProvider);
    expect(progress.xpFor(Skill.problemSolving), 80);
    expect(progress.xpFor(Skill.logic), 40);
  });

  testWidgets('Odds On: a wrong pick shows both answers and the slip', (
    tester,
  ) async {
    await openOddsOn(tester);
    final q = container.read(oddsSessionProvider).question;
    final wrong = (q.answerIndex + 1) % q.options.length;
    await tester.tap(find.byKey(ValueKey('odds-$wrong')));
    await tester.pumpAndSettle();
    expect(find.text('Working it out'), findsOneWidget);
    expect(find.textContaining('Your answer'), findsOneWidget);
    expect(find.textContaining('Right ·'), findsOneWidget);
    expect(find.text(q.feedbackFor(q.options[wrong])), findsOneWidget);
    for (final step in q.steps) {
      expect(find.text(step), findsOneWidget);
    }
  });

  testWidgets('Odds On at level 9 fits a 360×640 phone, question and review', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(720, 1280);
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({'game.odds_on.level': 9});
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
    // Open it the way a player would, with the app's compact theme.
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    final card = find.text('Odds On');
    await tester.scrollUntilVisible(
      card,
      200,
      scrollable: find.descendant(
        of: find.byType(GamesScreen),
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(card);
    await tester.pump();
    await tester.pumpAndSettle();
    expect(container.read(oddsSessionProvider).question.level, 9);
    // Wrong answers show the longest review (the level drops as it should).
    for (var r = 0; r < OddsController.totalRounds; r++) {
      final q = container.read(oddsSessionProvider).question;
      final wrong = (q.answerIndex + 1) % q.options.length;
      final option = find.byKey(ValueKey('odds-$wrong'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expect(find.text('Working it out'), findsOneWidget);
      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    // Any overflow above would have failed the test.
    expect(find.textContaining('0 of 8 correct'), findsOneWidget);
  });

  test('restart puts the piece back and resets moves', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(ProgressRepository(prefs)),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(pathSessionProvider, (_, _) {});
    addTearDown(sub.close);
    final ctrl = c.read(pathSessionProvider.notifier);
    final s0 = c.read(pathSessionProvider);

    // Make any real move (the first that isn't blocked).
    for (final d in Dir.values) {
      if (ctrl.move(d)) break;
    }
    final s1 = c.read(pathSessionProvider);
    expect(s1.movesUsed, 1);

    ctrl.restart();
    final s2 = c.read(pathSessionProvider);
    expect(s2.pos, s0.puzzle.start);
    expect(s2.movesUsed, 0);
    expect(s2.trail, isEmpty);
  });

  test('a miss is offered as one unscored practice round', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(ProgressRepository(prefs)),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(patternSessionProvider, (_, _) {});
    addTearDown(sub.close);
    final ctrl = c.read(patternSessionProvider.notifier);

    for (var r = 0; r < PatternSessionController.totalRounds; r++) {
      final s = c.read(patternSessionProvider);
      final answer = s.puzzle.answerIndex;
      ctrl.select(r == 2 ? (answer + 1) % s.puzzle.options.length : answer);
      await ctrl.next();
    }
    final results = c.read(patternSessionProvider);
    expect(results.finished, isTrue);
    expect(results.nearMiss?.round, 3);
    expect(results.correctCount, 9);

    ctrl.trySimilar();
    final practice = c.read(patternSessionProvider);
    expect(practice.practice, isTrue);
    expect(practice.finished, isFalse);
    expect(practice.level, results.nearMiss!.level);

    ctrl.select(practice.puzzle.answerIndex);
    expect(
      c.read(patternSessionProvider).score,
      results.score,
      reason: 'practice is not scored',
    );
    await ctrl.next();

    final back = c.read(patternSessionProvider);
    expect(back.finished, isTrue);
    expect(back.nearMiss, isNull, reason: 'one practice round only');
    expect(back.score, results.score);
    expect(c.read(progressProvider).forGame('pattern_sequence').sessions, 1);
  });

  test('tapping a filled spot sends its shape back; picking swaps', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final c = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(ProgressRepository(prefs)),
      ],
    );
    addTearDown(c.dispose);
    final sub = c.listen(deduceSessionProvider, (_, _) {});
    addTearDown(sub.close);
    final ctrl = c.read(deduceSessionProvider.notifier);
    final first = c.read(deduceSessionProvider).puzzle.tray.first;
    final second = c.read(deduceSessionProvider).puzzle.tray[1];

    ctrl.pick(first);
    ctrl.tapSpot(0);
    expect(c.read(deduceSessionProvider).placed.first, first);
    expect(c.read(deduceSessionProvider).tray, isNot(contains(first)));

    ctrl.pick(second);
    ctrl.tapSpot(0); // replaces: first goes back to the tray
    expect(c.read(deduceSessionProvider).placed.first, second);
    expect(c.read(deduceSessionProvider).tray, contains(first));

    ctrl.tapSpot(0); // nothing picked: send it back
    expect(c.read(deduceSessionProvider).placed.first, isNull);
  });
}
