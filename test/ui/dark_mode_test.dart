import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_registry.dart';
import 'package:smartx/core/game/speed_game.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/feed/feed_controller.dart';
import 'package:smartx/features/feed/feed_plan.dart';
import 'package:smartx/features/games/games_screen.dart';
import 'package:smartx/games/ink_clash/ink_controller.dart';
import 'package:smartx/games/ink_clash/ink_puzzle.dart';
import 'package:smartx/games/odds_on/odds_controller.dart';
import 'package:smartx/games/scale_sleuth/scale_controller.dart';
import 'package:smartx/games/stop_or_roll/stop_controller.dart';

import '../test_prefs.dart';

/// Fills and borders that only belong to light mode. If one shows up in
/// dark mode, a screen is painting a raw colour instead of a palette role.
const _dayOnly = {
  0xFFFFFFFF, // surface
  0xFFF6F5F1, // ground
  0xFFEDEBE4, // chip
  0xFFE4E2DA, // line
  0xFFD9D6CC, // lineStrong
  0xFFEAF6EF, // correctTint
  0xFFFCE9EC, // missTint
  0xFFFFE8D6, // sparkTint
};

void expectNoDayColours(WidgetTester tester, String where) {
  expect(dayColours(tester), isEmpty, reason: 'Day colours on $where');
}

/// Every day-only fill or border on screen.
Set<String> dayColours(WidgetTester tester) {
  final leaks = <String>{};
  void check(Color? c, Widget w) {
    if (c != null && _dayOnly.contains(c.toARGB32())) {
      leaks.add('${w.runtimeType}: 0x${c.toARGB32().toRadixString(16)}');
    }
  }

  for (final w in tester.allWidgets) {
    Decoration? decoration;
    if (w is Container) decoration = w.decoration;
    if (w is AnimatedContainer) decoration = w.decoration;
    if (w is DecoratedBox) decoration = w.decoration;
    if (w is ColoredBox) check(w.color, w);
    if (decoration is BoxDecoration) {
      check(decoration.color, w);
      final border = decoration.border;
      if (border is Border) check(border.top.color, w);
    }
  }
  return leaks;
}

void main() {
  late ProviderContainer container;

  Future<void> pumpDark(WidgetTester tester) async {
    tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
    addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
    SharedPreferences.setMockInitialValues(rulesSeen());
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

  Future<void> openGame(WidgetTester tester, String title) async {
    await tester.tap(find.text('Games').last);
    await tester.pumpAndSettle();
    final card = find.text(title);
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
  }

  testWidgets('control: the check does find day colours in light mode', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues(rulesSeen());
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
    // Light mode legitimately uses them, so a working check must see them.
    expect(dayColours(tester), isNotEmpty);
  });

  testWidgets('every tab is dark, with no day colours', (tester) async {
    await pumpDark(tester);
    expect(
      Theme.of(tester.element(find.text('Today').first)).brightness,
      Brightness.dark,
    );
    expectNoDayColours(tester, 'Today');
    for (final tab in ['Games', 'Skills', 'Profile']) {
      await tester.tap(find.text(tab).last);
      await tester.pumpAndSettle();
      expectNoDayColours(tester, tab);
    }
  });

  testWidgets('every game opens dark, with no day colours', (tester) async {
    await pumpDark(tester);
    for (final game in gameRegistry) {
      await openGame(tester, game.title);
      // Past any "get ready" pause, into play.
      await tester.pump(const Duration(milliseconds: 1500));
      expectNoDayColours(tester, game.title);
      await tester.tap(find.bySemanticsLabel('Quit game'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }
  });

  testWidgets('Odds On review and results are dark', (tester) async {
    await pumpDark(tester);
    await openGame(tester, 'Odds On');
    await tester.pumpAndSettle();
    for (var r = 0; r < OddsController.totalRounds; r++) {
      final q = container.read(oddsSessionProvider).question;
      // Alternate wrong and right, so both reviews get checked.
      final pick = r.isEven ? (q.answerIndex + 1) % 4 : q.answerIndex;
      final option = find.byKey(ValueKey('odds-$pick'));
      await tester.ensureVisible(option);
      await tester.tap(option);
      await tester.pumpAndSettle();
      expectNoDayColours(tester, 'Odds On review');
      final next = find.byType(FilledButton);
      await tester.ensureVisible(next);
      await tester.pumpAndSettle();
      await tester.tap(next);
      await tester.pumpAndSettle();
    }
    expect(find.textContaining('of 8 correct'), findsOneWidget);
    expectNoDayColours(tester, 'results');
  });

  testWidgets('Scale Sleuth weighing and review are dark', (tester) async {
    await pumpDark(tester);
    await openGame(tester, 'Scale Sleuth');
    await tester.pumpAndSettle();
    final c = container.read(scaleSessionProvider.notifier);
    c.tapCoin(1);
    c.choosePan(Pan.right);
    c.tapCoin(2);
    await tester.pumpAndSettle();
    expectNoDayColours(tester, 'Scale Sleuth loaded');
    c.weigh();
    c.tapCoin(3);
    await tester.pumpAndSettle();
    expectNoDayColours(tester, 'Scale Sleuth weighed');
    c.startNaming();
    c.tapCoin(3);
    c.name();
    await tester.pumpAndSettle();
    expectNoDayColours(tester, 'Scale Sleuth review');
  });

  testWidgets('Stop or Roll calls and review are dark', (tester) async {
    await pumpDark(tester);
    await openGame(tester, 'Stop or Roll');
    await tester.pumpAndSettle();
    final c = container.read(stopSessionProvider.notifier);
    c.roll();
    await tester.pumpAndSettle();
    expectNoDayColours(tester, 'Stop or Roll with a call');
    while (!container.read(stopSessionProvider).answered) {
      c.roll();
    }
    await tester.pumpAndSettle();
    expectNoDayColours(tester, 'Stop or Roll review');
  });

  testWidgets('an Ink Clash block and its review are dark', (tester) async {
    await pumpDark(tester);
    await openGame(tester, 'Ink Clash');
    await tester.pump(SpeedController.getReady);
    var s = container.read(inkSessionProvider);
    var first = true;
    while (s.phase == SpeedPhase.playing) {
      if (s.flash == null) {
        // Wrong on the first word so a rose flash gets checked too.
        final answer = s.trial!.answer;
        final pick = first
            ? InkColour.values.firstWhere((c) => c != answer)
            : answer;
        await tester.tap(find.byKey(ValueKey('ink-${pick.name}')));
        await tester.pump();
        expectNoDayColours(tester, 'Ink Clash flash');
        first = false;
      }
      await tester.pump(SpeedController.flashFor);
      s = container.read(inkSessionProvider);
    }
    await tester.pumpAndSettle();
    expectNoDayColours(tester, 'Ink Clash review');
  });

  testWidgets('a Quick feed card, played and done, is dark', (tester) async {
    // A fixed run of cards, so the test doesn't depend on which comes first.
    FeedController.seed = 7;
    addTearDown(() => FeedController.seed = null);
    await pumpDark(tester);
    await tester.tap(find.byKey(const ValueKey('open-feed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expectNoDayColours(tester, 'feed card');
    // Let the card play out (speed cards time out; tap a pattern option).
    // Long enough for the slowest card (5 timed-out grids at 4 s each).
    for (var i = 0; i < 80; i++) {
      final option = find.byKey(const ValueKey('option-0'));
      if (option.evaluate().isNotEmpty) {
        await tester.tap(option);
      }
      await tester.pump(const Duration(milliseconds: 500));
      if (find.byKey(const ValueKey('feed-next')).evaluate().isNotEmpty) break;
    }
    expect(find.byKey(const ValueKey('feed-next')), findsOneWidget);
    expectNoDayColours(tester, 'played feed card');
    expect(FeedRules.cards, 20);
  });
}
