import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/speed_game.dart';
import '../../games/arrow_focus/arrow_puzzle.dart';
import '../../games/arrow_focus/arrow_screen.dart';
import '../../games/ink_clash/ink_puzzle.dart';
import '../../games/ink_clash/ink_screen.dart';
import '../../games/odd_one_out/odd_puzzle.dart';
import '../../games/odd_one_out/odd_screen.dart';
import '../../games/pattern_sequence/pattern_sequence_screen.dart';
import '../../games/pattern_sequence/sequence_generator.dart';
import '../../games/pattern_sequence/sequence_puzzle.dart';
import '../../games/pattern_sequence/widgets/token_tile.dart';
import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/skill_marker.dart';
import '../../ui/widgets/speed_widgets.dart';
import 'feed_plan.dart';

// Cards of the Quick feed, built from the "Quick feed · card" and
// "· card done" artboards. Speed cards use each game's own look (SpeedUi).

/// Builds the card for [spec]; [onDone] fires once, when it has been played.
Widget feedCardFor(
  FeedCardSpec spec, {
  required void Function(FeedCardResult result) onDone,
}) {
  switch (spec.kind) {
    case FeedKind.ink:
      final b = const InkGenerator().generate(
        level: spec.level,
        seed: spec.seed,
      );
      return SpeedFeedCard<InkBlock, InkTrial, InkColour>(
        kind: spec.kind,
        ui: inkUi,
        block: b.withTrials(burstOf(b.trials)),
        onDone: onDone,
      );
    case FeedKind.arrow:
      final b = const ArrowGenerator().generate(
        level: spec.level,
        seed: spec.seed,
      );
      return SpeedFeedCard<ArrowBlock, ArrowTrial, ArrowDir>(
        kind: spec.kind,
        ui: arrowUi,
        block: b.withTrials(burstOf(b.trials)),
        onDone: onDone,
      );
    case FeedKind.odd:
      final b = const OddGenerator().generate(
        level: spec.level,
        seed: spec.seed,
      );
      return SpeedFeedCard<OddBlock, OddTrial, int>(
        kind: spec.kind,
        ui: oddUi,
        block: b.withTrials(burstOf(b.trials)),
        onDone: onDone,
      );
    case FeedKind.pattern:
      return PatternFeedCard(spec: spec, onDone: onDone);
  }
}

/// The white card: game and skill on top, progress dots, then [child].
class FeedCardFrame extends StatelessWidget {
  const FeedCardFrame({
    super.key,
    required this.kind,
    required this.child,
    this.dots,
  });

  final FeedKind kind;
  final Widget child;

  /// Per answer: true right, false wrong, null not yet; [current] marks the
  /// one in play.
  final ({List<bool?> marks, int current})? dots;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final dots = this.dots;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12),
      padding: EdgeInsets.fromLTRB(
        16,
        d.compact ? 14 : 20,
        16,
        d.compact ? 14 : 20,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(d.compact ? 24 : 28),
        border: Border.all(color: scheme.outlineVariant),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0F16161D),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              SkillMarkerIcon(kind.skill, size: 12),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '${kind.title} · ${kind.skill.shortLabel}'.toUpperCase(),
                  overflow: TextOverflow.ellipsis,
                  style: lucidLabel(scheme.onSurfaceVariant, size: d.label),
                ),
              ),
              if (dots != null)
                Semantics(
                  label:
                      '${dots.marks.where((m) => m == true).length} of '
                      '${dots.marks.length} right so far',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      for (final (i, m) in dots.marks.indexed) ...[
                        if (i > 0) const SizedBox(width: 6),
                        AnimatedContainer(
                          duration: Lucid.tap,
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: switch (m) {
                              true => Lucid.correct,
                              false => Lucid.miss,
                              null when i == dots.current => Lucid.ink,
                              null => scheme.outlineVariant,
                            },
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
            ],
          ),
          SizedBox(height: d.gapM),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A played card: ✓ or ✕, the headline, one line of explanation, XP.
class FeedCardResultView extends StatelessWidget {
  const FeedCardResultView({
    super.key,
    required this.right,
    required this.headline,
    required this.detail,
    required this.skillName,
  });

  final bool right;
  final String headline;
  final String detail;
  final String skillName;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final size = d.compact ? 60.0 : 72.0;
    return Semantics(
      liveRegion: true,
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: size,
                height: size,
                decoration: BoxDecoration(
                  color: right ? Lucid.correct : Lucid.miss,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  right ? Icons.check_rounded : Icons.close_rounded,
                  size: size * 0.54,
                  color: Colors.white,
                ),
              ),
              SizedBox(height: d.gapM),
              Text(
                headline,
                textAlign: TextAlign.center,
                style: lucidText(
                  size: d.compact ? 24 : 28,
                  weight: 700,
                  display: true,
                  color: scheme.onSurface,
                ),
              ),
              SizedBox(height: d.gapS),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 300),
                child: Text(
                  detail,
                  textAlign: TextAlign.center,
                  style: lucidText(
                    size: d.body,
                    color: scheme.onSurfaceVariant,
                    height: 1.45,
                  ),
                ),
              ),
              if (right) ...[
                SizedBox(height: d.gapM),
                Container(
                  height: 30,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: Lucid.correctTint,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Center(
                    widthFactor: 1,
                    child: Text(
                      '+${FeedRules.xpPerCard} $skillName XP',
                      style: lucidText(
                        size: 13,
                        weight: 700,
                        color: Lucid.correctText,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A burst of answers from a speed game, with that game's own controls.
class SpeedFeedCard<B extends SpeedBlock<T, A>, T extends SpeedTrial<A>, A>
    extends StatefulWidget {
  const SpeedFeedCard({
    super.key,
    required this.kind,
    required this.ui,
    required this.block,
    required this.onDone,
  });

  final FeedKind kind;
  final SpeedUi<B, T, A> ui;
  final B block;
  final void Function(FeedCardResult result) onDone;

  @override
  State<SpeedFeedCard<B, T, A>> createState() => _SpeedFeedCardState<B, T, A>();
}

class _SpeedFeedCardState<
  B extends SpeedBlock<T, A>,
  T extends SpeedTrial<A>,
  A
>
    extends State<SpeedFeedCard<B, T, A>> {
  late final TrialRun<A> _run;
  Timer? _ready;
  SpeedPhase _phase = SpeedPhase.ready;
  SpeedResult? _result;

  @override
  void initState() {
    super.initState();
    _run = TrialRun<A>(
      answers: [for (final t in widget.block.trials) t.answer],
      limit: widget.block.limit,
      onChange: () {
        if (mounted) setState(() {});
      },
      onDone: _finish,
    );
    _ready = Timer(FeedRules.getReady, () {
      if (!mounted) return;
      setState(() => _phase = SpeedPhase.playing);
      _run.start();
    });
  }

  @override
  void dispose() {
    _ready?.cancel();
    _run.cancel();
    super.dispose();
  }

  void _finish() {
    if (!mounted) return;
    final b = widget.block;
    final r = b.evaluate(_run.given);
    setState(() {
      _phase = SpeedPhase.review;
      _result = r;
    });
    widget.onDone(
      FeedCardResult(
        kind: widget.kind,
        correct: r.right,
        total: b.length,
        right: r.right >= FeedRules.burstPass,
        detail: b.mistake(r, _run.given),
      ),
    );
  }

  void _press(A option) => speedHaptic(_run.answer(option));

  SpeedSessionState<B, T, A> get _state => SpeedSessionState<B, T, A>(
    round: 0,
    totalRounds: 1,
    level: widget.block.level,
    startLevel: widget.block.level,
    block: widget.block,
    phase: _phase,
    index: _run.index,
    answers: List.unmodifiable(_run.given),
    flash: _run.flash,
    result: _result,
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final ui = widget.ui;
    final b = widget.block;
    final s = _state;
    final t = s.trial;
    final dots = (
      marks: [
        for (var i = 0; i < b.length; i++)
          i < _run.given.length
              ? _run.given[i].tapped == b.trials[i].answer
              : null,
      ],
      current: _phase == SpeedPhase.playing ? _run.index : -1,
    );

    if (_phase == SpeedPhase.review) {
      final r = _result!;
      return FeedCardFrame(
        kind: widget.kind,
        dots: dots,
        child: FeedCardResultView(
          right: r.right >= FeedRules.burstPass,
          headline: '${r.right} of ${b.length} right',
          detail: b.mistake(r, _run.given),
          skillName: widget.kind.skill.shortLabel,
        ),
      );
    }

    final cue = ui.cue(s);
    Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedSwitcher(
                duration: Lucid.tap * 2,
                child: SpeedCuePill(key: ValueKey(cue.text), cue: cue),
              ),
              SizedBox(height: d.gapL),
              Flexible(
                child: Center(
                  child: _phase == SpeedPhase.ready
                      ? Text(
                          'Get ready…',
                          style: lucidText(
                            size: d.body,
                            color: scheme.onSurfaceVariant,
                          ),
                        )
                      : SpeedStimulusSwitcher(
                          index: _run.index,
                          child: t == null
                              ? null
                              : ui.stimulus(context, s, t, _press),
                        ),
                ),
              ),
              SizedBox(height: d.gapM),
              SpeedTimerBar(
                running: _run.timing,
                index: _run.index,
                limit: b.limit,
              ),
            ],
          ),
        ),
        SizedBox(height: d.gapS),
        Text(
          ui.hint(s),
          textAlign: TextAlign.center,
          style: lucidText(size: d.small, color: scheme.onSurfaceVariant),
        ),
        if (ui.controls case final controls?) ...[
          SizedBox(height: d.gapS),
          controls(context, s, _press),
        ],
      ],
    );
    final swipe = ui.swipe;
    if (swipe != null) {
      content = SwipeArea(
        onSwipe: (travel) {
          final option = swipe(_state, travel);
          if (option != null) _press(option);
        },
        child: content,
      );
    }
    return FeedCardFrame(kind: widget.kind, dots: dots, child: content);
  }
}

/// One Pattern Sequence puzzle: pick what comes next.
class PatternFeedCard extends StatefulWidget {
  const PatternFeedCard({super.key, required this.spec, required this.onDone});

  final FeedCardSpec spec;
  final void Function(FeedCardResult result) onDone;

  @override
  State<PatternFeedCard> createState() => _PatternFeedCardState();
}

class _PatternFeedCardState extends State<PatternFeedCard> {
  late final SequencePuzzle _puzzle = const SequenceGenerator().generate(
    level: widget.spec.level,
    seed: widget.spec.seed,
  );
  int? _picked;
  bool _showResult = false;
  Timer? _timer;

  /// How long the marked options show before the result.
  static const _settle = Duration(milliseconds: 700);

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _choose(int i) {
    if (_picked != null) return;
    final right = i == _puzzle.answerIndex;
    right ? HapticFeedback.lightImpact() : HapticFeedback.mediumImpact();
    setState(() => _picked = i);
    _timer = Timer(_settle, () {
      if (!mounted) return;
      setState(() => _showResult = true);
      widget.onDone(
        FeedCardResult(
          kind: FeedKind.pattern,
          correct: right ? 1 : 0,
          total: 1,
          right: right,
          detail: _puzzle.explanation,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final p = _puzzle;
    final answered = _picked != null;
    final right = _picked == p.answerIndex;

    if (_showResult) {
      return FeedCardFrame(
        kind: FeedKind.pattern,
        child: FeedCardResultView(
          right: right,
          headline: right ? 'Right' : 'Not quite',
          detail: p.explanation,
          skillName: FeedKind.pattern.skill.shortLabel,
        ),
      );
    }

    final tile = d.compact ? d.tile * 0.86 : d.tile;
    return FeedCardFrame(
      kind: FeedKind.pattern,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'What comes next?',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall,
                    ),
                    SizedBox(height: d.gapL),
                    Wrap(
                      alignment: WrapAlignment.center,
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final token in p.visible)
                          TokenTile(token: token, size: tile),
                        TokenTile(
                          token: answered ? p.answer : null,
                          size: tile,
                          borderColor: answered && right
                              ? Lucid.correct
                              : scheme.primary,
                          background: answered && right
                              ? Lucid.correctTint
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: d.gapM),
          Row(
            children: [
              for (final (i, option) in p.options.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: PatternOptionTile(
                    key: ValueKey('option-$i'),
                    token: option,
                    label: 'Option ${i + 1}',
                    isAnswer: i == p.answerIndex,
                    selected: _picked == i,
                    answered: answered,
                    onTap: answered ? null : () => _choose(i),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
