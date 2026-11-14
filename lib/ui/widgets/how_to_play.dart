import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/storage/progress.dart';
import '../density.dart';
import '../lucid.dart';
import '../palette.dart';
import 'press_scale.dart';

// Built from the "How to play · first time", "· ? sheet" and "· night"
// artboards.

/// Shows [game]'s rules before its first session; afterwards goes straight
/// to the game. The game (and any clock in it) only starts after Start.
class HowToGate extends ConsumerStatefulWidget {
  const HowToGate({super.key, required this.game});

  final GameDefinition game;

  @override
  ConsumerState<HowToGate> createState() => _HowToGateState();
}

class _HowToGateState extends ConsumerState<HowToGate> {
  late bool _seen = ref
      .read(progressRepositoryProvider)
      .howToSeen(widget.game.id);

  Future<void> _start() async {
    setState(() => _seen = true);
    await ref.read(progressRepositoryProvider).markHowToSeen(widget.game.id);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 280),
      child: _seen
          ? KeyedSubtree(
              key: const ValueKey('game'),
              child: widget.game.buildScreen(),
            )
          : HowToPage(
              key: const ValueKey('how-to'),
              game: widget.game,
              onStart: _start,
            ),
    );
  }
}

/// The full page shown the first time a game is opened.
class HowToPage extends StatelessWidget {
  const HowToPage({super.key, required this.game, required this.onStart});

  final GameDefinition game;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, d.topPad, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: PressScale(
                  semanticLabel: 'Close',
                  onTap: () => context.pop(),
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Icon(
                      Icons.close_rounded,
                      size: 20,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(top: d.gapS),
                  child: HowToBody(game: game, cards: true),
                ),
              ),
              Padding(
                padding: EdgeInsets.only(
                  top: d.gapS,
                  bottom: d.compact ? 12 : 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: d.button,
                      child: FilledButton(
                        key: const ValueKey('how-to-start'),
                        onPressed: onStart,
                        child: const Text('Start'),
                      ),
                    ),
                    SizedBox(height: d.gapS),
                    Text(
                      'Shown once. Tap ? in the game to see it again.',
                      textAlign: TextAlign.center,
                      style: lucidText(
                        size: d.small,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Opens [game]'s rules as a bottom sheet (the ? button).
Future<void> showHowToSheet(BuildContext context, GameDefinition game) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      final d = Dims.of(context);
      return Semantics(
        label: 'How to play ${game.title}',
        container: true,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(20, 12, 20, d.compact ? 16 : 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: context.palette.line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
              ),
              SizedBox(height: d.gapM),
              HowToBody(game: game, cards: false),
              SizedBox(height: d.gapL),
              SizedBox(
                height: d.button,
                child: FilledButton(
                  key: const ValueKey('how-to-close'),
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Got it'),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

/// Title, the three steps and what changes with level. [cards] puts each
/// step on its own card (full page); the sheet lists them plainly.
class HowToBody extends StatelessWidget {
  const HowToBody({super.key, required this.game, required this.cards});

  final GameDefinition game;
  final bool cards;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final p = context.palette;
    final how = game.howTo;
    final skill = game.skills.first;
    final tile = d.compact ? 48.0 : 56.0;

    Widget step(int i, HowToStep s) {
      final row = Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: cards ? 40 : 36,
            height: cards ? 40 : 36,
            decoration: BoxDecoration(
              color: p.chip,
              borderRadius: BorderRadius.circular(cards ? 12 : 11),
            ),
            child: Icon(s.icon, size: 22, color: p.ink),
          ),
          SizedBox(width: d.compact ? 12 : 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${i + 1} · ${s.title}',
                  style: lucidText(
                    size: d.rowTitle,
                    weight: 600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  s.text,
                  style: lucidText(
                    size: d.body,
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      );
      if (!cards) return row;
      return Container(
        padding: EdgeInsets.all(d.compact ? 12 : 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: row,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (cards) ...[
              Container(
                width: tile,
                height: tile,
                decoration: BoxDecoration(
                  color: skill.color,
                  borderRadius: BorderRadius.circular(Lucid.radiusM),
                ),
                child: Icon(
                  game.icon,
                  size: tile * 0.5,
                  color: onFill(skill.color),
                ),
              ),
              SizedBox(width: d.compact ? 12 : 14),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'HOW TO PLAY',
                    style: lucidLabel(scheme.onSurfaceVariant, size: d.label),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    game.title,
                    style: lucidText(
                      size: cards
                          ? (d.compact ? 24 : 28)
                          : (d.compact ? 21 : 24),
                      weight: 700,
                      display: true,
                      color: scheme.onSurface,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (cards) ...[
          SizedBox(height: d.gapS),
          Text(
            '${game.tagline} Trains ${skill.shortLabel}.',
            style: lucidText(size: d.body, color: scheme.onSurfaceVariant),
          ),
        ],
        SizedBox(height: d.gapM),
        for (final (i, s) in how.steps.indexed) ...[
          if (i > 0) SizedBox(height: cards ? (d.compact ? 8 : 12) : d.gapM),
          step(i, s),
        ],
        SizedBox(height: d.gapM),
        Container(
          padding: EdgeInsets.symmetric(
            horizontal: d.compact ? 12 : 14,
            vertical: d.compact ? 10 : 12,
          ),
          decoration: BoxDecoration(
            color: p.chip,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Text.rich(
            TextSpan(
              style: lucidText(
                size: d.small + 1,
                color: scheme.onSurface,
                height: 1.45,
              ),
              children: [
                TextSpan(
                  text: 'As you improve: ',
                  style: lucidText(
                    size: d.small + 1,
                    weight: 700,
                    color: scheme.onSurface,
                  ),
                ),
                TextSpan(text: how.levels),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// The ? in a game's top bar. While a timed game's clock runs it is dimmed
/// and does nothing, so opening the rules never costs a timed answer.
class HowToButton extends StatelessWidget {
  const HowToButton({super.key, required this.game, required this.ready});

  final GameDefinition game;
  final bool ready;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AnimatedOpacity(
      duration: Lucid.tap,
      opacity: ready ? 1 : 0.35,
      child: PressScale(
        key: const ValueKey('how-to-button'),
        semanticLabel: ready
            ? 'How to play'
            : 'How to play, available between rounds',
        onTap: ready ? () => showHowToSheet(context, game) : null,
        // 44 touch target around a 36 circle.
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.surface,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.onSurface, width: 1.5),
              ),
              child: Text(
                '?',
                style: lucidText(
                  size: 16,
                  weight: 700,
                  display: true,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
