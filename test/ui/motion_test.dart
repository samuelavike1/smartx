import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartx/ui/motion.dart';
import 'package:smartx/ui/theme.dart';
import 'package:smartx/ui/widgets/game_chrome.dart';

Widget host(Widget child, {bool reduce = false}) => MaterialApp(
  theme: buildTheme(Brightness.light),
  home: MediaQuery(
    data: MediaQueryData(disableAnimations: reduce),
    child: Scaffold(body: child),
  ),
);

double opacityOf(WidgetTester tester, Finder f) => tester
    .widget<Opacity>(find.ancestor(of: f, matching: find.byType(Opacity)).first)
    .opacity;

void main() {
  testWidgets('list items fade in one after another', (tester) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            FadeSlideIn(index: 0, child: Text('first')),
            FadeSlideIn(index: 3, child: Text('fourth')),
          ],
        ),
      ),
    );
    expect(opacityOf(tester, find.text('first')), 0);
    await tester.pump(const Duration(milliseconds: 100));
    // The first is on its way while the fourth is still waiting.
    expect(opacityOf(tester, find.text('first')), greaterThan(0));
    expect(opacityOf(tester, find.text('fourth')), 0);
    await tester.pumpAndSettle();
    expect(opacityOf(tester, find.text('fourth')), 1);
  });

  testWidgets('reduced motion: items just appear, no confetti', (tester) async {
    await tester.pumpWidget(
      host(
        const Column(
          children: [
            FadeSlideIn(index: 0, child: Text('first')),
            SizedBox(height: 200, width: 200, child: ConfettiBurst()),
          ],
        ),
        reduce: true,
      ),
    );
    expect(
      find.ancestor(of: find.text('first'), matching: find.byType(Opacity)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: find.byType(ConfettiBurst),
        matching: find.byType(CustomPaint),
      ),
      findsNothing,
    );
  });

  testWidgets('confetti bursts, then clears', (tester) async {
    await tester.pumpWidget(
      host(const SizedBox(height: 300, width: 300, child: ConfettiBurst())),
    );
    expect(
      find.descendant(
        of: find.byType(ConfettiBurst),
        matching: find.byType(CustomPaint),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });

  testWidgets('a wrong answer shakes; with reduced motion it doesn\'t', (
    tester,
  ) async {
    for (final reduce in [false, true]) {
      await tester.pumpWidget(
        host(
          FeedbackCard(
            correct: false,
            points: 0,
            explanation: 'Because.',
            isLastRound: false,
            onNext: () {},
          ),
          reduce: reduce,
        ),
      );
      // A quarter of the way into the first swing, at its widest.
      await tester.pump(const Duration(milliseconds: 30));
      final moved = tester
          .widgetList<Transform>(
            find.ancestor(
              of: find.text('Not quite'),
              matching: find.byType(Transform),
            ),
          )
          .any((t) => t.transform.getTranslation().x.abs() > 0.5);
      expect(moved, !reduce, reason: 'reduce motion: $reduce');
      await tester.pumpAndSettle();
    }
  });
}
