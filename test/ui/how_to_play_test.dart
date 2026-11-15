import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_registry.dart';
import 'package:smartx/core/game/speed_game.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/games/ink_clash/ink_controller.dart';
import 'package:smartx/ui/widgets/how_to_play.dart';

import '../open_game.dart';
import '../test_prefs.dart';
import 'dark_mode_test.dart' show dayColours;

void main() {
  late ProviderContainer container;
  late SharedPreferences prefs;

  Future<void> pumpApp(
    WidgetTester tester, {
    Map<String, Object> saved = const {},
  }) async {
    SharedPreferences.setMockInitialValues(saved);
    prefs = await SharedPreferences.getInstance();
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

  Future<void> openGame(WidgetTester tester, String title) async {
    await openFromGames(tester, title);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  test('every game explains itself in three short steps', () {
    for (final g in gameRegistry) {
      final how = g.howTo;
      expect(how.steps, hasLength(3), reason: g.title);
      for (final s in how.steps) {
        expect(s.title, isNotEmpty);
        expect(s.title.length, lessThanOrEqualTo(42), reason: s.title);
        expect(s.text.length, lessThanOrEqualTo(110), reason: s.text);
        expect(s.text, matches(RegExp(r'[.…]$')), reason: s.text);
      }
      expect(how.levels, isNotEmpty);
    }
    // Games with a clock say so, so their ? waits for a break.
    final timed = {for (final g in gameRegistry) g.id: g.timed};
    expect(timed['ink_clash'], isTrue);
    expect(timed['arrow_focus'], isTrue);
    expect(timed['odds_on'], isFalse);
  });

  testWidgets('first open shows the rules before any clock starts', (
    tester,
  ) async {
    await pumpApp(tester);
    await openGame(tester, 'Ink Clash');
    await tester.pumpAndSettle();
    expect(find.text('HOW TO PLAY'), findsOneWidget);
    expect(find.text('1 · Look at the ink'), findsOneWidget);
    // Reading takes as long as it takes: no game, no clock underneath.
    await tester.pump(SpeedController.getReady * 3);
    expect(find.text('Get ready…'), findsNothing);
    expect(find.textContaining('Word 1 of'), findsNothing);
    expect(find.text('HOW TO PLAY'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('how-to-start')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Get ready…'), findsOneWidget);
    expect(prefs.getBool('howto.ink_clash.seen'), isTrue);

    // Leave and come back: straight into the game this time.
    await tester.tap(find.bySemanticsLabel('Quit game'));
    await tester.pumpAndSettle();
    await openGame(tester, 'Ink Clash');
    expect(find.text('HOW TO PLAY'), findsNothing);
    expect(find.text('Get ready…'), findsOneWidget);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'every game\'s rules page fits 360×640 (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(720, 1280);
        tester.view.devicePixelRatio = 2;
        addTearDown(tester.view.reset);
        if (dark) {
          tester.platformDispatcher.platformBrightnessTestValue =
              Brightness.dark;
          addTearDown(
            tester.platformDispatcher.clearPlatformBrightnessTestValue,
          );
        }
        await pumpApp(tester);
        for (final g in gameRegistry) {
          await openGame(tester, g.title);
          await tester.pumpAndSettle();
          // Any overflow fails the test on its own.
          expect(find.byType(HowToPage), findsOneWidget, reason: g.title);
          expect(find.text(g.howTo.steps.last.text), findsOneWidget);
          if (dark) {
            expect(dayColours(tester), isEmpty, reason: g.title);
          }
          await tester.tap(find.bySemanticsLabel('Close'));
          await tester.pumpAndSettle();
        }
      },
    );
  }

  testWidgets('? opens the rules any time in an untimed game', (tester) async {
    await pumpApp(tester, saved: rulesSeen());
    await openGame(tester, 'Odds On');
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('how-to-button')));
    await tester.pumpAndSettle();
    expect(find.text('1 · Picture the setup'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('how-to-close')));
    await tester.pumpAndSettle();
    expect(find.text('1 · Picture the setup'), findsNothing);
  });

  testWidgets('? waits for a break in a timed game', (tester) async {
    await pumpApp(tester, saved: rulesSeen());
    await openGame(tester, 'Ink Clash');
    await tester.pump(SpeedController.getReady);
    // Mid-block: dimmed, does nothing.
    await tester.tap(find.byKey(const ValueKey('how-to-button')));
    await tester.pump();
    expect(find.text('Got it'), findsNothing);
    expect(
      find.bySemanticsLabel('How to play, available between rounds'),
      findsOneWidget,
    );

    // Let the block run out, then it works.
    while (container.read(inkSessionProvider).phase == SpeedPhase.playing) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('how-to-button')));
    await tester.pumpAndSettle();
    expect(find.text('Got it'), findsOneWidget);
    expect(find.text('1 · Look at the ink'), findsOneWidget);
  });
}
