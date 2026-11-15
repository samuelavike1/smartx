import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'bell_puzzle.dart';
import 'spread_bell_game.dart';

@immutable
class BellSessionState {
  const BellSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.question,
    this.picked,
    this.lastPoints = 0,
    this.score = 0,
    this.correctCount = 0,
    this.combo = 0,
    this.finished = false,
    this.isNewBest = false,
    this.nearMiss,
    this.practice = false,
  });

  final int round;
  final int totalRounds;
  final int level;
  final int startLevel;
  final BellQuestion question;
  final int? picked;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final bool practice;

  bool get answered => picked != null;
  bool get lastCorrect => picked == question.answerIndex;

  BellSessionState copyWith({
    int? level,
    int? picked,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => BellSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    question: question,
    picked: picked ?? this.picked,
    lastPoints: lastPoints ?? this.lastPoints,
    score: score ?? this.score,
    correctCount: correctCount ?? this.correctCount,
    combo: combo ?? this.combo,
    finished: finished ?? this.finished,
    isNewBest: isNewBest ?? this.isNewBest,
    nearMiss: nearMiss != null ? nearMiss() : this.nearMiss,
    practice: practice,
  );
}

final bellSessionProvider =
    NotifierProvider.autoDispose<BellController, BellSessionState>(
      BellController.new,
    );

class BellController extends Notifier<BellSessionState> {
  static const int totalRounds = 8;

  final _generator = const BellGenerator();
  final _rng = Random();
  final _stopwatch = Stopwatch();
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  BellSessionState? _results;

  @override
  BellSessionState build() {
    final startLevel = ref
        .read(progressProvider)
        .forGame(SpreadBellGame.gameId)
        .level;
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    _stopwatch
      ..reset()
      ..start();
    return BellSessionState(
      round: 0,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: _engine.level,
      question: _newQuestion(_engine.level),
    );
  }

  BellQuestion _newQuestion(int level) =>
      _generator.generate(level: level, seed: _rng.nextInt(1 << 31));

  void select(int pick) {
    if (state.answered || state.finished) return;
    _stopwatch.stop();
    final q = state.question;
    final correct = pick == q.answerIndex;
    if (state.practice) {
      state = state.copyWith(picked: pick, lastPoints: 0);
      return;
    }
    // Thinking is the point: the speed bonus is spread over a minute.
    final points = correct
        ? pointsForCorrectAnswer(
            level: state.level,
            elapsed: _stopwatch.elapsed ~/ 6,
          )
        : 0;
    _engine.record(correct: correct);
    if (!correct) {
      _lastMiss = NearMiss(
        round: state.round + 1,
        level: state.level,
        reason: q.feedbackFor(q.options[pick]),
      );
    }
    state = state.copyWith(
      picked: pick,
      lastPoints: points,
      score: state.score + points,
      correctCount: state.correctCount + (correct ? 1 : 0),
      combo: correct ? state.combo + 1 : 0,
    );
  }

  Future<void> next() async {
    if (!state.answered || state.finished) return;
    if (state.practice) {
      state = _results!.copyWith(nearMiss: () => null);
      return;
    }
    final nextRound = state.round + 1;
    if (nextRound >= totalRounds) {
      await _finish();
      return;
    }
    state = BellSessionState(
      round: nextRound,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: state.startLevel,
      question: _newQuestion(_engine.level),
      score: state.score,
      correctCount: state.correctCount,
      combo: state.combo,
    );
    _stopwatch
      ..reset()
      ..start();
  }

  /// Plays one unscored question at the level of the last miss.
  void trySimilar() {
    final miss = state.nearMiss;
    if (!state.finished || miss == null) return;
    _results = state;
    state = BellSessionState(
      round: totalRounds - 1,
      totalRounds: totalRounds,
      level: miss.level,
      startLevel: state.startLevel,
      question: _newQuestion(miss.level),
      score: state.score,
      correctCount: state.correctCount,
      combo: state.combo,
      practice: true,
    );
  }

  Future<void> _finish() async {
    final progress = ref.read(progressProvider.notifier);
    final previousBest = ref
        .read(progressProvider)
        .forGame(SpreadBellGame.gameId)
        .bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: SpreadBellGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const SpreadBellGame().skills,
      ),
    );
  }
}
