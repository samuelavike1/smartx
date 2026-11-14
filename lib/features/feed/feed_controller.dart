import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/storage/progress.dart';
import 'feed_plan.dart';

@immutable
class FeedState {
  const FeedState({
    required this.cards,
    this.index = 0,
    this.results = const [],
    this.combo = 0,
    this.bestCombo = 0,
    this.summary,
  });

  final List<FeedCardSpec> cards;
  final int index;
  final List<FeedCardResult> results;
  final int combo;
  final int bestCombo;

  /// Set once the last card is done and the player moves on.
  final FeedSummary? summary;

  FeedCardSpec get card => cards[index];

  /// The current card has been played; the player can move on.
  bool get cardDone => results.length > index;
  FeedCardResult? get result => cardDone ? results[index] : null;
  bool get isLast => index + 1 >= cards.length;
  FeedCardSpec? get nextCard => isLast ? null : cards[index + 1];

  /// Cards finished, for the progress bar.
  int get done => results.length;

  FeedState copyWith({
    int? index,
    List<FeedCardResult>? results,
    int? combo,
    int? bestCombo,
    FeedSummary? summary,
  }) => FeedState(
    cards: cards,
    index: index ?? this.index,
    results: results ?? this.results,
    combo: combo ?? this.combo,
    bestCombo: bestCombo ?? this.bestCombo,
    summary: summary ?? this.summary,
  );
}

final feedProvider = NotifierProvider.autoDispose<FeedController, FeedState>(
  FeedController.new,
);

class FeedController extends Notifier<FeedState> {
  final _clock = Stopwatch();

  /// Seed for the card plan; tests set it for a known run.
  @visibleForTesting
  static int? seed;

  @override
  FeedState build() {
    final progress = ref.read(progressProvider);
    _clock
      ..reset()
      ..start();
    return FeedState(
      cards: planFeed(
        levelFor: (k) => progress.forGame(k.gameId).level,
        seed: seed ?? Random().nextInt(1 << 31),
      ),
    );
  }

  /// Records the current card's result. XP for a right card is saved at
  /// once, so leaving the feed early keeps what was earned.
  void cardFinished(FeedCardResult result) {
    if (state.cardDone || state.summary != null) return;
    final combo = result.right ? state.combo + 1 : 0;
    state = state.copyWith(
      results: [...state.results, result],
      combo: combo,
      bestCombo: max(state.bestCombo, combo),
    );
    if (result.right) {
      ref.read(progressProvider.notifier).addXp({
        result.kind.skill: FeedRules.xpPerCard,
      });
    }
  }

  /// Moves to the next card, or to the summary after the last one.
  Future<void> next() async {
    if (!state.cardDone || state.summary != null) return;
    if (!state.isLast) {
      state = state.copyWith(index: state.index + 1);
      return;
    }
    _clock.stop();
    final repo = ref.read(progressRepositoryProvider);
    final summary = summarizeFeed(
      state.results,
      lastPercent: repo.feedAccuracy,
      bestCombo: state.bestCombo,
      time: _clock.elapsed,
    );
    state = state.copyWith(summary: summary);
    for (final line in summary.lines) {
      await repo.saveFeedAccuracy(line.skill, line.percent);
    }
  }
}
