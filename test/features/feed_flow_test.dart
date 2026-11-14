import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smartx/app.dart';
import 'package:smartx/core/game/speed_game.dart';
import 'package:smartx/core/skills/skill.dart';
import 'package:smartx/core/storage/progress.dart';
import 'package:smartx/features/feed/feed_cards.dart';
import 'package:smartx/features/feed/feed_controller.dart';
import 'package:smartx/features/feed/feed_plan.dart';
import 'package:smartx/features/feed/feed_screen.dart';
import 'package:smartx/features/today/today_screen.dart';
import 'package:smartx/games/arrow_focus/arrow_puzzle.dart';
import 'package:smartx/games/ink_clash/ink_puzzle.dart';
import 'package:smartx/games/pattern_sequence/sequence_generator.dart';

void main() {
  late ProviderContainer container;

  Future<void> openFeed(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        progressRepositoryProvider.overrideWithValue(ProgressRepository(prefs)),
      ],
    );
    addTearDown(container.dispose);
    FeedController.seed = 7;
    addTearDown(() => FeedController.seed = null);
    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const SmartXApp()),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('open-feed')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  /// The key of the control that gives [answer] in a speed card.
  Key keyFor(Object? answer) => switch (answer) {
    final InkColour c => ValueKey('ink-${c.name}'),
    final ArrowDir d => ValueKey('arrow-${d.name}'),
    final int i => ValueKey('odd-$i'),
    _ => throw ArgumentError(answer),
  };

  /// Plays the card on screen; [rightUpTo] answers right, the rest wrong.
  Future<void> playCard(WidgetTester tester, {int rightUpTo = 99}) async {
    final card = tester.widget(
      find.byWidgetPredicate((w) => w is SpeedFeedCard || w is PatternFeedCard),
    );
    if (card is PatternFeedCard) {
      // Puzzles come from a seed, so the test can rebuild the card's one.
      final puzzle = const SequenceGenerator().generate(
        level: card.spec.level,
        seed: card.spec.seed,
      );
      final answer = puzzle.answerIndex;
      final choice = rightUpTo > 0
          ? answer
          : (answer + 1) % puzzle.options.length;
      await tester.tap(find.byKey(ValueKey('option-$choice')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 750));
      return;
    }
    final speed = card as SpeedFeedCard;
    await tester.pump(FeedRules.getReady);
    for (final (i, t) in speed.block.trials.indexed) {
      final answer = t.answer;
      if (i < rightUpTo) {
        await tester.tap(find.byKey(keyFor(answer)).hitTestable());
      } // else: let it time out
      await tester.pump();
      if (i >= rightUpTo) await tester.pump(speed.block.limit);
      await tester.pump(SpeedController.flashFor);
    }
    await tester.pump();
  }

  testWidgets('Today opens the feed; a full run ends on the summary', (
    tester,
  ) async {
    await openFeed(tester);
    expect(
      find.descendant(
        of: find.byType(FeedScreen),
        matching: find.text('Quick feed'),
      ),
      findsOneWidget,
    );
    expect(find.text('1 of 20'), findsOneWidget);

    for (var c = 0; c < FeedRules.cards; c++) {
      // The next bar only works once the card is played.
      expect(find.byKey(const ValueKey('feed-next')), findsNothing);
      await playCard(tester);
      final s = container.read(feedProvider);
      expect(s.cardDone, isTrue, reason: 'card ${c + 1}');
      expect(s.result!.right, isTrue);
      await tester.tap(find.byKey(const ValueKey('feed-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();

    expect(find.text('QUICK FEED DONE'), findsOneWidget);
    expect(find.bySemanticsLabel('20 of 20 cards right'), findsOneWidget);
    expect(find.text('75 of 75 answers right'), findsOneWidget);
    expect(find.text('5 of 5 sequences right'), findsOneWidget);
    expect(find.text('first feed'), findsNWidgets(2));
    expect(find.text('×20'), findsOneWidget);
    expect(find.text('+100'), findsOneWidget);

    final progress = container.read(progressProvider);
    expect(progress.xpFor(Skill.attention), 75);
    expect(progress.xpFor(Skill.patternRecognition), 25);
    // The feed never touches game levels or "played today".
    expect(progress.forGame('ink_clash').sessions, 0);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
    expect(find.byType(TodayScreen), findsOneWidget);
  });

  testWidgets('swipe up moves on, but only after the card is played', (
    tester,
  ) async {
    await openFeed(tester);
    final card = find.byWidgetPredicate(
      (w) => w is SpeedFeedCard || w is PatternFeedCard,
    );
    await tester.drag(card, const Offset(0, -300));
    await tester.pump();
    expect(container.read(feedProvider).index, 0, reason: 'not played yet');

    await playCard(tester, rightUpTo: 0);
    final s = container.read(feedProvider);
    expect(s.result!.right, isFalse);
    expect(s.combo, 0);
    expect(
      find.text('Not quite').evaluate().isNotEmpty ||
          find.textContaining('of 5 right').evaluate().isNotEmpty,
      isTrue,
    );

    await tester.fling(card, const Offset(0, -300), 1200);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(container.read(feedProvider).index, 1);
    expect(find.text('2 of 20'), findsOneWidget);
  });
}
