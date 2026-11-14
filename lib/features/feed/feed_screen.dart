import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/skill_marker.dart';
import 'feed_cards.dart';
import 'feed_controller.dart';
import 'feed_plan.dart';
import '../../ui/palette.dart';

// Built from the "Quick feed · card", "· card done" and "· summary"
// artboards. No autoplay: the player moves on with a swipe up (or a tap on
// the bar) once a card is played, and the feed ends on a summary.

class FeedScreen extends ConsumerWidget {
  const FeedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(feedProvider);
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 280),
        child: s.summary != null
            ? SafeArea(
                key: const ValueKey('summary'),
                child: _Summary(summary: s.summary!),
              )
            : _Feed(state: s),
      ),
    );
  }
}

class _Feed extends ConsumerStatefulWidget {
  const _Feed({required this.state});

  final FeedState state;

  @override
  ConsumerState<_Feed> createState() => _FeedState();
}

class _FeedState extends ConsumerState<_Feed> {
  double _drag = 0;

  static const _swipeDistance = 60.0;
  static const _swipeSpeed = 250.0;

  void _next() => ref.read(feedProvider.notifier).next();

  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final d = Dims.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final controller = ref.read(feedProvider.notifier);

    return SafeArea(
      bottom: false,
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, d.topPad, 16, 0),
            child: _Header(state: s),
          ),
          SizedBox(height: d.compact ? 12 : 16),
          Expanded(
            // Swipe up anywhere on the card once it's played.
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onVerticalDragStart: s.cardDone ? (_) => _drag = 0 : null,
              onVerticalDragUpdate: s.cardDone
                  ? (e) => _drag += e.delta.dy
                  : null,
              onVerticalDragEnd: s.cardDone
                  ? (e) {
                      final v = e.velocity.pixelsPerSecond.dy;
                      if (_drag < -_swipeDistance || v < -_swipeSpeed) _next();
                    }
                  : null,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 320),
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                // New card rises from below; the old one leaves upwards and
                // takes no taps on the way out.
                transitionBuilder: (child, a) {
                  final incoming = child.key == ValueKey(s.index);
                  return SlideTransition(
                    position: Tween(
                      begin: Offset(0, incoming ? 1 : -1),
                      end: Offset.zero,
                    ).animate(a),
                    child: incoming ? child : IgnorePointer(child: child),
                  );
                },
                child: KeyedSubtree(
                  key: ValueKey(s.index),
                  child: feedCardFor(s.card, onDone: controller.cardFinished),
                ),
              ),
            ),
          ),
          SizedBox(height: d.compact ? 8 : 10),
          _NextBar(state: s, bottom: bottom, onTap: _next),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.state});

  final FeedState state;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final s = state;
    final total = s.cards.length;
    return Row(
      children: [
        PressScale(
          semanticLabel: 'Close feed',
          onTap: () => context.pop(),
          child: Container(
            width: d.control,
            height: d.control,
            decoration: BoxDecoration(
              color: scheme.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: scheme.outlineVariant),
            ),
            child: Icon(Icons.close_rounded, size: 20, color: scheme.onSurface),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Quick feed',
                      style: lucidText(
                        size: d.small + 1,
                        weight: 600,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                  Text(
                    '${s.index + 1} of $total',
                    style: lucidText(
                      size: d.small + 1,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Semantics(
                label: '${s.done} of $total cards played',
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(end: s.done / total),
                    duration: Lucid.pop,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: context.palette.spark,
                      backgroundColor: scheme.outlineVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (s.combo >= 2) ...[
          const SizedBox(width: 12),
          GamePill(
            text: '×${s.combo}',
            background: context.palette.spark,
            foreground: context.palette.onSpark,
          ),
        ],
      ],
    );
  }
}

/// Grey "Next: …" while a card is in play; ink "Swipe up" once it's done.
class _NextBar extends StatelessWidget {
  const _NextBar({
    required this.state,
    required this.bottom,
    required this.onTap,
  });

  final FeedState state;
  final double bottom;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final d = Dims.of(context);
    final s = state;
    final ready = s.cardDone;
    final what = s.nextCard == null ? 'your summary' : s.nextCard!.kind.title;
    final text = ready
        ? (s.isLast ? 'Swipe up · See your summary' : 'Swipe up · Next: $what')
        : (s.isLast ? 'Then: your summary' : 'Next: $what');

    final bar = AnimatedContainer(
      duration: Lucid.pop,
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: EdgeInsets.only(bottom: bottom),
      height: (d.compact ? 46 : 52) + bottom,
      decoration: BoxDecoration(
        color: ready ? context.palette.ink : context.palette.chip,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (ready) ...[
            Icon(
              Icons.keyboard_arrow_up_rounded,
              size: 20,
              color: context.palette.onInk,
            ),
            const SizedBox(width: 6),
          ],
          Text(
            text,
            style: lucidText(
              size: d.small + 1,
              weight: ready ? 600 : 500,
              color: ready ? context.palette.onInk : context.palette.faint,
            ),
          ),
        ],
      ),
    );
    if (!ready) return ExcludeSemantics(child: bar);
    return PressScale(
      key: const ValueKey('feed-next'),
      semanticLabel: s.isLast ? 'See your summary' : 'Next card: $what',
      onTap: onTap,
      child: bar,
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({required this.summary});

  final FeedSummary summary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final s = summary;
    final minutes = s.time.inSeconds / 60;
    final time = minutes < 1
        ? 'under a minute'
        : 'about ${minutes.round()} min';

    Widget box(String label, String value) => Expanded(
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 16,
          vertical: d.compact ? 10 : 14,
        ),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: lucidText(size: d.small, color: scheme.onSurfaceVariant),
            ),
            Text(
              value,
              style: lucidText(
                size: d.compact ? 20 : 22,
                weight: 700,
                display: true,
                color: scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, d.topPad, 16, 0),
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(height: d.gapL),
                  Text(
                    'QUICK FEED DONE',
                    textAlign: TextAlign.center,
                    style: lucidLabel(
                      context.palette.sparkStrong,
                      size: d.label,
                    ),
                  ),
                  SizedBox(height: d.gapS),
                  Semantics(
                    label: '${s.right} of ${s.cards} cards right',
                    excludeSemantics: true,
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: '${s.right}'),
                          TextSpan(
                            text: ' / ${s.cards}',
                            style: lucidText(
                              size: d.compact ? 24 : 28,
                              weight: 700,
                              display: true,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                      textAlign: TextAlign.center,
                      style: lucidText(
                        size: d.compact ? 46 : 56,
                        weight: 700,
                        display: true,
                        color: scheme.onSurface,
                        height: 1,
                      ),
                    ),
                  ),
                  SizedBox(height: d.gapS),
                  Text(
                    'cards right · $time',
                    textAlign: TextAlign.center,
                    style: lucidText(
                      size: d.body,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  SizedBox(height: d.gapL),
                  Container(
                    padding: EdgeInsets.all(d.compact ? 14 : 16),
                    decoration: BoxDecoration(
                      color: scheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'How you did',
                          style: lucidText(
                            size: d.rowTitle,
                            weight: 600,
                            color: scheme.onSurface,
                          ),
                        ),
                        for (final (i, line) in s.lines.indexed) ...[
                          if (i > 0)
                            Divider(
                              height: 1,
                              color: scheme.surfaceContainerHigh,
                            ),
                          Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: d.compact ? 10 : 12,
                            ),
                            child: _SkillLine(line: line),
                          ),
                        ],
                      ],
                    ),
                  ),
                  SizedBox(height: d.gapM),
                  Row(
                    children: [
                      box('Best combo', '×${s.bestCombo}'),
                      const SizedBox(width: 12),
                      box('XP earned', '+${s.xp}'),
                    ],
                  ),
                  SizedBox(height: d.gapL),
                  Text(
                    'A good place to stop. A fresh feed is waiting on Today '
                    'whenever you want one.',
                    textAlign: TextAlign.center,
                    style: lucidText(
                      size: d.small + 1,
                      color: scheme.onSurfaceVariant,
                      height: 1.45,
                    ),
                  ),
                  SizedBox(height: d.gapM),
                ],
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(top: d.gapS, bottom: d.compact ? 12 : 20),
            child: SizedBox(
              width: double.infinity,
              height: d.button,
              child: FilledButton(
                onPressed: () => context.pop(),
                child: const Text('Done'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SkillLine extends StatelessWidget {
  const _SkillLine({required this.line});

  final FeedSkillLine line;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final l = line;
    final unit = l.skill == FeedKind.pattern.skill ? 'sequences' : 'answers';
    final change = l.change;
    final (changeText, changeColor) = switch (change) {
      null => ('first feed', scheme.onSurfaceVariant),
      0 => ('same as last feed', scheme.onSurfaceVariant),
      > 0 => ('▲ $change vs last feed', context.palette.correctText),
      _ => ('▼ ${-change} vs last feed', context.palette.missText),
    };
    return Semantics(
      label:
          '${l.skill.shortLabel}: ${l.percent} percent, ${l.correct} of '
          '${l.total} $unit right, '
          '${change == null ? 'first feed' : changeText.replaceAll('▲', 'up').replaceAll('▼', 'down')}',
      excludeSemantics: true,
      child: Row(
        children: [
          SkillMarkerIcon(l.skill, size: 14),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.skill.shortLabel,
                  style: lucidText(
                    size: d.body,
                    weight: 600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  '${l.correct} of ${l.total} $unit right',
                  style: lucidText(
                    size: d.small,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${l.percent}%',
                style: lucidText(
                  size: 20,
                  weight: 700,
                  display: true,
                  color: scheme.onSurface,
                ),
              ),
              Text(
                changeText,
                style: lucidText(size: 12, weight: 600, color: changeColor),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
