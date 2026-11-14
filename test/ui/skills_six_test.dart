import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/game_registry.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/games/games_screen.dart';
import 'package:smartx/ui/lucid.dart';
import 'package:smartx/ui/palette.dart';

import 'dark_mode_test.dart' show dayColours;

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  return (max(la, lb) + 0.05) / (min(la, lb) + 0.05);
}

void main() {
  test('six skills, each with its own shape and colour', () {
    expect(Skill.values, hasLength(6));
    expect({for (final s in Skill.values) s.marker}, hasLength(6));
    expect({for (final s in Skill.values) s.color}, hasLength(6));
    expect(Skill.numbers.marker, SkillMarker.plus);
  });

  test('Numbers reads on both grounds and carries white text', () {
    final c = Skill.numbers.color;
    expect(_contrast(c, LucidPalette.light.ground), greaterThanOrEqualTo(3));
    expect(_contrast(c, LucidPalette.night.ground), greaterThanOrEqualTo(3));
    expect(onFill(c), const Color(0xFFFFFFFF));
    expect(_contrast(onFill(c), c), greaterThanOrEqualTo(4.5));
  });

  test('Odds On trains Numbers first, then Logic', () {
    final odds = gameRegistry.firstWhere((g) => g.id == 'odds_on');
    expect(odds.skills, [Skill.numbers, Skill.logic]);
  });

  for (final dark in [false, true]) {
    testWidgets('six skills fit a 360×640 phone (${dark ? 'dark' : 'light'})', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(720, 1280);
      tester.view.devicePixelRatio = 2;
      addTearDown(tester.view.reset);
      if (dark) {
        tester.platformDispatcher.platformBrightnessTestValue = Brightness.dark;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      }
      SharedPreferences.setMockInitialValues({'skill.numbers.xp': 40});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          progressRepositoryProvider.overrideWithValue(
            ProgressRepository(prefs),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const SmartXApp(),
        ),
      );
      await tester.pumpAndSettle();

      // Today's skill card: all six labels, no overflow (that would fail).
      await tester.scrollUntilVisible(find.text('Your skills'), 200);
      await tester.pumpAndSettle();
      for (final s in Skill.values) {
        expect(find.text(s.shortLabel), findsWidgets, reason: s.name);
      }
      if (dark) expect(dayColours(tester), isEmpty);

      // Skills tab lists Numbers with its XP.
      await tester.tap(find.text('Skills').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('40 XP'), 200);
      expect(find.text('Numbers'), findsOneWidget);

      // The Odds On card shows its new skill.
      await tester.tap(find.text('Games').last);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Odds On'),
        200,
        scrollable: find.descendant(
          of: find.byType(GamesScreen),
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Numbers'), findsWidgets);
    });
  }
}
