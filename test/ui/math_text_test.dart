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
    expect(mathPlain(r'\max_{s \le 4} W_s'), 'max_(s ≤ 4) W_s');
    expect(mathPlain(r'\min_{t} X_t'), 'min_t X_t');
    expect(mathPlain(r'P(\tau_{3} < \tau_{-2})'), 'P(τ_3 < τ_(−2))');
    expect(mathPlain(r'W_t \sim N(0, t)'), 'W_t ∼ N(0, t)');
    expect(
      mathPlain(r'\tau_{x} = \text{first time W reaches }x'),
      'τ_x = first time W reaches x',
    );
  });

  testWidgets('\\text keeps its words and spaces together', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: MathText(r'\tau = \text{first time at } a')),
      ),
    );
    expect(find.text('first time at '), findsOneWidget);
  });

  testWidgets('a minus after ∼ is a sign', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: MathText(r'X \sim -Y'))),
    );
    expect(find.text(' − '), findsNothing);
    expect(find.text('−'), findsOneWidget);
    expect(find.text(' ∼ '), findsOneWidget);
  });

  testWidgets('a leading minus is a sign; between terms, an operator', (
    tester,
  ) async {
    Future<void> show(String s) =>
        tester.pumpWidget(MaterialApp(home: Scaffold(body: MathText(s))));
    const binary = ' − ';
    // Signs: at the start of a row or matrix cell, after = or (, in a power.
    for (final s in [
      '-3',
      r'\mat{-1,2;3,-4}',
      r'x = -2',
      r'A^{-1}',
      r'(-x)',
      r'-\frac{2}{3}',
    ]) {
      await show(s);
      expect(find.text('−'), findsWidgets, reason: s);
      expect(find.text(binary), findsNothing, reason: s);
    }
    // Operators: between two terms.
    for (final s in ['a - b', '2c_1 - c_2', 'ad - bc']) {
      await show(s);
      expect(find.text(binary), findsOneWidget, reason: s);
      expect(find.text('−'), findsNothing, reason: s);
    }
    // Screen readers read it the same either way.
    expect(mathPlain(r'\mat{-1,2;3,-4}'), '[−1, 2; 3, −4]');
    expect(mathPlain('a - b'), 'a − b');
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
