import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/game/game_definition.dart';
import '../../core/storage/progress.dart';
import 'teaser_book.dart';
import 'teaser_game.dart';
import 'teasers.dart';

@immutable
class TeaserSessionState {
  const TeaserSessionState({
    required this.teaser,
    required this.day,
    required this.bonus,
    required this.options,
    required this.level,
    this.hints = 0,
    this.picked,
    this.points = 0,
    this.finished = false,
    this.isNewBest = false,
  });

  final Teaser teaser;
  final DateTime day;

  /// Played again on a day whose teaser is done.
  final bool bonus;
  final List<String> options;
  final int level;

  /// Hints shown so far.
  final int hints;
  final int? picked;
  final int points;
  final bool finished;
  final bool isNewBest;

  bool get answered => picked != null;
  bool get correct => answered && options[picked!] == teaser.answer;
  int get answerIndex => options.indexOf(teaser.answer);

  TeaserSessionState copyWith({
    int? hints,
    int? picked,
    int? points,
    bool? finished,
    bool? isNewBest,
  }) => TeaserSessionState(
    teaser: teaser,
    day: day,
    bonus: bonus,
    options: options,
    level: level,
    hints: hints ?? this.hints,
    picked: picked ?? this.picked,
    points: points ?? this.points,
    finished: finished ?? this.finished,
    isNewBest: isNewBest ?? this.isNewBest,
  );
}

final teaserSessionProvider =
    NotifierProvider.autoDispose<TeaserController, TeaserSessionState>(
      TeaserController.new,
    );

class TeaserController extends Notifier<TeaserSessionState> {
  /// Fixes the day in tests.
  @visibleForTesting
  static DateTime? today;

  @override
  TeaserSessionState build() {
    final day = today ?? DateTime.now();
    final progress = ref.read(progressProvider).forGame(TeaserGame.gameId);
    final bonus = progress.playedOn(day);
    final teaser = bonus
        ? TeaserBook.bonus(day, max(1, progress.sessions))
        : TeaserBook.forDay(day);
    final options = [teaser.answer, ...teaser.traps.map((t) => t.label)]
      ..shuffle(Random(TeaserBook.dayNumber(day) * 31 + progress.sessions));
    return TeaserSessionState(
      teaser: teaser,
      day: day,
      bonus: bonus,
      options: options,
      level: progress.level,
    );
  }

  void showHint() {
    final s = state;
    if (s.answered || s.hints >= s.teaser.hints.length) return;
    state = s.copyWith(hints: s.hints + 1);
  }

  void select(int i) {
    final s = state;
    if (s.answered) return;
    final right = s.options[i] == s.teaser.answer;
    state = s.copyWith(
      picked: i,
      points: right ? TeaserBook.pointsFor(s.teaser, s.hints) : 0,
    );
  }

  Future<void> next() async {
    final s = state;
    if (!s.answered || s.finished) return;
    final previousBest = ref
        .read(progressProvider)
        .forGame(TeaserGame.gameId)
        .bestScore;
    state = s.copyWith(finished: true, isNewBest: s.points > previousBest);
    await ref
        .read(progressProvider.notifier)
        .recordSession(
          GameResult(
            gameId: TeaserGame.gameId,
            score: s.points,
            correct: s.correct ? 1 : 0,
            total: 1,
            endLevel: s.level,
            skills: const TeaserGame().skills,
          ),
        );
  }
}
