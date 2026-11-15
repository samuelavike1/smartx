import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:smartx/ui/widgets/math_text.dart';

void main() {
  test('plain text reads naturally', () {
    expect(mathPlain(r'\frac{1}{3}'), '1/3');
    expect(mathPlain(r'x^2 + 2x - 1'), 'x^2 + 2x − 1');
    expect(mathPlain(r'e^{2x}'), 'e^(2x)');
    expect(mathPlain(r'\sqrt{x+1}'), '√(x+1)');
    expect(mathPlain(r'a_1'), 'a_1');
    expect(mathPlain(r'\int_{0}^{1} x dx'), '∫_0^1  x dx');
    expect(mathPlain(r'\mat{1,2;3,4}'), '[1, 2; 3, 4]');
    expect(mathPlain(r'\det{a,b;c,d}'), 'det[a, b; c, d]');
    expect(mathPlain(r'\lim_{x \to 0} \frac{\sin x}{x}'), contains('lim'));
    expect(mathPlain(r'2\pi r'), '2π r');
    expect(mathPlain(r'\sin x'), 'sin x');
  });

  test('unknown commands stay visible', () {
    expect(mathPlain(r'\foo x'), r'\foo x');
  });

  testWidgets('every construct lays out without overflow', (tester) async {
    const samples = [
      r'\frac{1}{3}',
      r'3x^2 + 2x',
      r'e^{2x} \cdot \ln x',
      r'\sqrt{101} \approx 10.05',
      r'\int_{0}^{2} x^2 dx = \frac{8}{3}',
      r'\sum_{k=1}^{n} k = \frac{n(n+1)}{2}',
      r'\lim_{x \to 0} \frac{\sin x}{x} = 1',
      r'\mat{1,2;3,4}',
      r'\det{2,0,1;0,3,0;1,0,2}',
      r'\frac{d}{dx} (x^3) = 3x^2',
      r"x_{n+1} = x_n - \frac{f(x_n)}{f'(x_n)}",
    ];
    for (final s in samples) {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 320,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: MathText(s, size: 22),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull, reason: s);
      // Screen readers get the plain form.
      expect(find.bySemanticsLabel(mathPlain(s)), findsOneWidget, reason: s);
    }
  });
}
