import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/games/egg_drop/egg_controller.dart';
import 'package:smartx/games/egg_drop/egg_puzzle.dart';

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

  Future<void> openEggDrop(WidgetTester tester) async {
    await openFromGames(tester, 'Egg Drop');
    await tester.pump();
    await tester.pumpAndSettle();
  }

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(ValueKey(key)));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey(key)).hitTestable().first);
    await tester.pumpAndSettle();
  }

  EggPuzzle puzzle() => container.read(eggSessionProvider).puzzle;

  /// A drop that keeps the floor in reach, or (when [well] is false) the
  /// lowest floor still in play, which wastes drops.
  int pick(EggPuzzle p, {required bool well}) =>
      well ? keepInReach(p.lo, p.hi, p.eggsLeft, p.dropsLeft)! : p.lo + 1;

  /// Plays one round on screen, then taps Next.
  Future<void> playRound(WidgetTester tester, {required bool well}) async {
    while (!container.read(eggSessionProvider).answered) {
      final p = puzzle();
      expect(find.text('Find the highest safe floor'), findsOneWidget);
      expect(
        find.text('Highest safe floor: ${p.range}'.toUpperCase()),
        findsOneWidget,
      );
      final x = pick(p, well: well);
      await tapKey(tester, 'floor-$x');
      expect(find.text('Drop from floor $x'), findsOneWidget);
      await tapKey(tester, 'egg-drop');
    }
    final s = container.read(eggSessionProvider);
    expect(s.lastCorrect, well || s.puzzle.eggs == 1);
    expect(find.text('Working it out'), findsOneWidget);
    expect(find.text('Your drops'), findsOneWidget);
    if (!s.lastCorrect) {
      expect(find.textContaining('The slip:'), findsOneWidget);
      expect(find.text('Keeps it in reach'), findsOneWidget);
    }
    final next = find.byType(FilledButton);
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    await tester.tap(next);
    await tester.pumpAndSettle();
  }

  testWidgets('a full Egg Drop session: every round settled in time', (
    tester,
  ) async {
    EggController.seed = 11;
    addTearDown(() => EggController.seed = null);
    await pumpApp(tester);
    await openEggDrop(tester);
    for (var r = 0; r < EggController.totalRounds; r++) {
      await playRound(tester, well: true);
    }
    expect(find.text('6 of 6 correct · new personal best'), findsOneWidget);
    final progress = container.read(progressProvider);
    expect(progress.xpFor(Skill.problemSolving), 60);
    expect(progress.xpFor(Skill.logic), 30);
  });

  for (final level in [1, 3, 5, 6, 8, 9, 10]) {
    testWidgets('Egg Drop at level $level fits a 360×640 phone', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      EggController.seed = level;
      addTearDown(() => EggController.seed = null);
      await pumpApp(tester, {'game.egg_drop.level': level});
      await openEggDrop(tester);
      expect(container.read(eggSessionProvider).level, level);
      // The lowest floor every time uses every drop and gives the longest
      // review; any overflow fails the test.
      for (var r = 0; r < 2; r++) {
        await playRound(tester, well: false);
      }
    });
  }

  for (final level in [1, 6, 9]) {
    testWidgets('Egg Drop at level $level and its reviews are dark', (
      tester,
    ) async {
      tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      await pumpApp(tester, {'game.egg_drop.level': level});
      await openEggDrop(tester);
      final c = container.read(eggSessionProvider.notifier);
      for (var r = 0; r < 3; r++) {
        expect(dayColours(tester), isEmpty, reason: 'question');
        c.tapFloor(pick(puzzle(), well: true));
        c.drop();
        await tester.pumpAndSettle();
        if (!container.read(eggSessionProvider).answered) {
          c.tapFloor(puzzle().hi);
          await tester.pumpAndSettle();
          expect(dayColours(tester), isEmpty, reason: 'dropped and picked');
          c.tapFloor(puzzle().hi);
        }
        while (!container.read(eggSessionProvider).answered) {
          final p = puzzle();
          c.tapFloor(pick(p, well: r.isEven));
          c.drop();
        }
        await tester.pumpAndSettle();
        expect(dayColours(tester), isEmpty, reason: 'review');
        await c.next();
        await tester.pumpAndSettle();
      }
    });
  }
}
