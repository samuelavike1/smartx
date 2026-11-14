import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/game_chrome.dart';
import '../../ui/widgets/press_scale.dart';
import '../../ui/widgets/session_results.dart';
import 'pattern_sequence_controller.dart';
import 'pattern_sequence_game.dart';
import 'sequence_puzzle.dart';
import 'widgets/token_tile.dart';
import '../../ui/palette.dart';

class PatternSequenceScreen extends ConsumerWidget {
  const PatternSequenceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(patternSessionProvider);

    return Scaffold(
      body: SafeArea(
        child: AnimatedSwitcher(
          duration: const Duration(milliseconds: 280),
          child: s.finished
              ? SessionResults(
                  key: const ValueKey('results'),
                  game: const PatternSequenceGame(),
                  score: s.score,
                  correct: s.correctCount,
                  total: s.totalRounds,
                  startLevel: s.startLevel,
                  level: s.level,
                  isNewBest: s.isNewBest,
                  nearMiss: s.nearMiss,
                  onPlayAgain: () => ref.invalidate(patternSessionProvider),
                  onTrySimilar: ref
                      .read(patternSessionProvider.notifier)
                      .trySimilar,
                )
              : _RoundView(key: ValueKey('round-${s.round}'), state: s),
        ),
      ),
    );
  }
}

class _RoundView extends ConsumerWidget {
  const _RoundView({super.key, required this.state});

  final PatternSessionState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final d = Dims.of(context);
    final controller = ref.read(patternSessionProvider.notifier);
    final puzzle = state.puzzle;

    void choose(int i) {
      controller.select(i);
      if (i == puzzle.answerIndex) {
        HapticFeedback.lightImpact();
      } else {
        HapticFeedback.mediumImpact();
      }
    }

    return GameLayout(
      header: [
        GameTopBar(
          filled: state.round + (state.answered ? 1 : 0),
          total: state.totalRounds,
          score: state.score,
          game: const PatternSequenceGame(),
        ),
        SizedBox(height: d.compact ? 10 : 14),
        LevelComboRow(
          level: state.level,
          combo: state.combo,
          practice: state.practice,
        ),
      ],
      body: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: d.gapM),
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
              for (final (i, token) in puzzle.visible.indexed)
                PopIn(
                  index: i,
                  child: TokenTile(token: token, size: d.tile),
                ),
              PopIn(
                index: puzzle.visible.length,
                child: TokenTile(
                  token: state.answered ? puzzle.answer : null,
                  size: d.tile,
                  borderColor: state.answered && state.lastCorrect
                      ? context.palette.correct
                      : scheme.primary,
                  background: state.answered && state.lastCorrect
                      ? context.palette.correctTint
                      : null,
                ),
              ),
            ],
          ),
          SizedBox(height: d.gapM),
        ],
      ),
      // Answer options (and then the feedback) in the thumb zone.
      dock: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              for (final (i, option) in puzzle.options.indexed) ...[
                if (i > 0) const SizedBox(width: 12),
                Expanded(
                  child: PatternOptionTile(
                    key: ValueKey('option-$i'),
                    token: option,
                    label: 'Option ${i + 1}',
                    isAnswer: i == puzzle.answerIndex,
                    selected: state.selectedIndex == i,
                    answered: state.answered,
                    onTap: state.answered ? null : () => choose(i),
                  ),
                ),
              ],
            ],
          ),
          if (state.answered) SizedBox(height: d.gapM),
          FeedbackSlot(
            child: state.answered
                ? FeedbackCard(
                    correct: state.lastCorrect,
                    points: state.lastPoints,
                    explanation: puzzle.explanation,
                    isLastRound: state.round + 1 >= state.totalRounds,
                    onNext: controller.next,
                  )
                : null,
          ),
        ],
      ),
    );
  }
}

/// An answer option: a token tile that marks right/wrong once answered.
/// Also used by the Quick feed's pattern cards.
class PatternOptionTile extends StatelessWidget {
  const PatternOptionTile({
    super.key,
    required this.token,
    required this.isAnswer,
    required this.selected,
    required this.answered,
    required this.onTap,
    this.label,
  });

  final PatternToken token;
  final bool isAnswer;
  final bool selected;
  final bool answered;
  final VoidCallback? onTap;

  /// Read by screen readers ("Option 2"), with "right" or "wrong" added
  /// once answered.
  final String? label;

  @override
  Widget build(BuildContext context) {
    final showCorrect = answered && isAnswer;
    final showMiss = answered && selected && !isAnswer;

    final tile = Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.center,
      children: [
        LayoutBuilder(
          builder: (context, c) => TokenTile(
            token: token,
            size: min(c.maxWidth, Dims.of(context).option),
            borderColor: showCorrect
                ? context.palette.correct
                : (showMiss ? context.palette.miss : null),
            background: showCorrect
                ? context.palette.correctTint
                : (showMiss ? context.palette.missTint : null),
          ),
        ),
        if (showCorrect || showMiss)
          Positioned(top: -8, right: -6, child: _Badge(correct: showCorrect)),
      ],
    );

    return AnimatedOpacity(
      duration: Lucid.pop,
      opacity: answered && !showCorrect && !showMiss ? 0.5 : 1,
      child: AnimatedScale(
        duration: Lucid.pop,
        curve: Curves.easeOutBack,
        scale: showCorrect ? 1.06 : 1,
        child: Shake(
          active: showMiss,
          child: PressScale(
            semanticLabel: label == null
                ? null
                : showCorrect
                ? '$label, right answer'
                : showMiss
                ? '$label, wrong'
                : label,
            onTap: onTap,
            child: tile,
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({required this.correct});

  final bool correct;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: correct ? context.palette.correct : context.palette.miss,
        shape: BoxShape.circle,
      ),
      child: Icon(
        correct ? Icons.check_rounded : Icons.close_rounded,
        size: 16,
        color: correct ? context.palette.onCorrect : context.palette.onMiss,
        semanticLabel: correct ? 'Correct answer' : 'Your answer',
      ),
    );
  }
}
