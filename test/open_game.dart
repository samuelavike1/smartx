import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartx/core/game/game_category.dart';
import 'package:smartx/features/games/games_screen.dart';
import 'package:smartx/features/games/group_screen.dart';

/// The group a game is listed under on the Games tab.
GameCategory groupOf(String title) => GameCategory.values.firstWhere(
  (c) => c.games.any((g) => g.title == title),
  orElse: () => throw StateError('$title is in no group'),
);

/// Games tab → the game's group → the game → Continue (or Play). Leaves the
/// game's page transition running, as a direct tap on a card used to, so
/// timed games can be pumped frame by frame from here.
Future<void> openFromGames(WidgetTester tester, String title) async {
  if (title == 'Teaser of the day') {
    // Its own card above the groups; it opens straight away.
    await _gamesTabTop(tester);
    await tester.tap(find.text('TEASER OF THE DAY'));
    await tester.pump();
    return;
  }
  await openGroup(tester, groupOf(title));
  final row = find.text(title);
  await tester.scrollUntilVisible(
    row,
    200,
    scrollable: find.descendant(
      of: find.byType(GroupScreen),
      matching: find.byType(Scrollable),
    ),
  );
  await tester.pumpAndSettle();
  await tester.tap(row);
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('sheet-continue')));
  await tester.pump();
}

/// Games tab → [group].
Future<void> openGroup(WidgetTester tester, GameCategory group) async {
  await _gamesTabTop(tester);
  final card = find.text(group.title);
  await tester.scrollUntilVisible(card, 200, scrollable: _hubList);
  await tester.pumpAndSettle();
  await tester.tap(card);
  await tester.pumpAndSettle();
}

final _hubList = find.descendant(
  of: find.byType(GamesScreen),
  matching: find.byType(Scrollable),
);

/// The Games tab, scrolled back to the top (it keeps its place between
/// visits, and cards above the fold don't count as on screen).
Future<void> _gamesTabTop(WidgetTester tester) async {
  await tester.tap(find.text('Games').last);
  await tester.pumpAndSettle();
  tester.state<ScrollableState>(_hubList).position.jumpTo(0);
  await tester.pumpAndSettle();
}
