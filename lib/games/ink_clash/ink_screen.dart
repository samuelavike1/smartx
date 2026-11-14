import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/speed_widgets.dart';
import 'ink_clash_game.dart';
import 'ink_controller.dart';
import 'ink_puzzle.dart';

// Built from the "Ink Clash · play" and "Ink Clash · review" artboards, on
// the shared timed-trials screen.

class InkScreen extends StatelessWidget {
  const InkScreen({super.key});

  static double _wordSize(BuildContext context) =>
      Dims.of(context).compact ? 52.0 : 64.0;

  @override
  Widget build(BuildContext context) {
    return SpeedGameScreen<InkBlock, InkTrial, InkColour>(
      provider: inkSessionProvider,
      game: const InkClashGame(),
      // The cue: INK (filled pill) or WORD (outlined), so a flip is obvious.
      cue: (s) {
        final rule = s.trial?.rule ?? InkRule.ink;
        return SpeedCue('TAP THE ${rule.cue}', outlined: rule == InkRule.word);
      },
      stimulusHeight: (context) => _wordSize(context) * 1.3,
      stimulus: (context, _, t, _) {
        final size = _wordSize(context);
        return Semantics(
          label:
              'The word ${t.word.word}, written in ${t.ink.label.toLowerCase()} ink',
          liveRegion: true,
          excludeSemantics: true,
          child: Text(
            t.word.word,
            style: lucidText(
              size: size,
              weight: 700,
              display: true,
              color: t.ink.color,
              letterSpacing: size * 0.02,
            ),
          ),
        );
      },
      hint: (s) => s.block.flips
          ? 'Follow the cue: tap the ink, or tap the word.'
          : 'Tap the colour of the ink, not the word.',
      controls: (context, s, press) {
        final d = Dims.of(context);
        return GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: d.compact ? 3.4 : 2.9,
          children: [
            for (final colour in InkColour.values)
              SpeedButton(
                key: ValueKey('ink-${colour.name}'),
                label: colour.label,
                mark: s.markFor(colour),
                onTap: () => press(colour),
                child: _ColourLabel(colour),
              ),
          ],
        );
      },
      review: SpeedReviewText(
        item: 'Word',
        calm: 'Matching words',
        conflict: 'Clashing words',
        cost: (secs) => 'The clash cost you $secs s a word.',
        noCost: 'Clashing words didn\'t slow you down. Sharp focus.',
      ),
    );
  }
}

class _ColourLabel extends StatelessWidget {
  const _ColourLabel(this.colour);

  final InkColour colour;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            color: colour.color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Text(
          colour.label,
          style: lucidText(
            size: d.rowTitle,
            weight: 600,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
      ],
    );
  }
}
