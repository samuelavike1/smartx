import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/speed_widgets.dart';
import 'math_controller.dart';
import 'math_puzzle.dart';
import 'mental_math_game.dart';

// Built from the "Mental Math · play" and "Mental Math · review"
// artboards, on the shared timed-trials screen.

class MathScreen extends StatelessWidget {
  const MathScreen({super.key});

  @override
  Widget build(BuildContext context) =>
      SpeedGameScreen<MathBlock, MathTrial, int>(
        provider: mathSessionProvider,
        game: const MentalMathGame(),
        ui: mathUi,
      );
}

double _problemSize(BuildContext context) =>
    Dims.of(context).compact ? 44.0 : 52.0;

/// Mental Math's look: used by its screen and its Quick feed cards.
final mathUi = SpeedUi<MathBlock, MathTrial, int>(
  cue: (_) => const SpeedCue('WORK IT OUT'),
  stimulusHeight: (context) => _problemSize(context) * 1.4,
  stimulus: (context, _, t, _) {
    final size = _problemSize(context);
    return Semantics(
      label: t.spoken,
      liveRegion: true,
      excludeSemantics: true,
      // Long ones ("75% of 240") shrink rather than wrap.
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          t.text,
          maxLines: 1,
          style: lucidText(
            size: size,
            weight: 700,
            display: true,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ),
    );
  },
  hint: (_) => 'Estimate first, then check the last digit.',
  controls: (context, s, press) {
    final d = Dims.of(context);
    final t = s.trial;
    final options = t?.options ?? const <int>[];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: d.compact ? 3.0 : 2.6,
      children: [
        for (final value in options)
          SpeedButton(
            key: ValueKey('math-$value'),
            label: '$value',
            mark: s.markFor(value),
            onTap: () => press(value),
            child: Center(
              child: Text(
                '$value',
                style: lucidText(
                  size: d.compact ? 22 : 26,
                  weight: 700,
                  display: true,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ),
        // Keeps the dock's height steady between problems.
        if (options.isEmpty)
          for (var i = 0; i < 4; i++) const SizedBox.shrink(),
      ],
    );
  },
  review: SpeedReviewText(
    item: 'Problem',
    calm: 'Easy steps',
    conflict: 'Carries and hard facts',
    cost: (secs) => 'Carries and hard facts cost you $secs s a problem.',
    noCost: 'Carries and hard facts didn\'t slow you down. Sharp.',
  ),
);
