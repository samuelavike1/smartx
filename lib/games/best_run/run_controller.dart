import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'best_run_game.dart';
import 'run_puzzle.dart';

@immutable
class RunSessionState {
  const RunSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.puzzle,
    this.start,
    this.end,
    this.picking = false,
    this.locked = false,
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
  final RunPuzzle puzzle;

  /// First and last chosen day (bars), or buy and sell day (prices).
  final int? start;
  final int? end;

  /// Waiting for the second tap.
  final bool picking;
  final bool locked;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final bool practice;

  bool get answered => locked;
  bool get canLock => !locked && start != null && end != null;
  bool get lastCorrect => locked && puzzle.isBest(start!, end!);

  RunSessionState copyWith({
    int? level,
    int? Function()? start,
    int? Function()? end,
    bool? picking,
    bool? locked,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => RunSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    puzzle: puzzle,
    start: start != null ? start() : this.start,
    end: end != null ? end() : this.end,
    picking: picking ?? this.picking,
    locked: locked ?? this.locked,
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

final runSessionProvider =
    NotifierProvider.autoDispose<RunController, RunSessionState>(
      RunController.new,
    );

class RunController extends Notifier<RunSessionState> {
  static const int totalRounds = 8;

  /// Fixes the charts in tests.
  @visibleForTesting
  static int? seed;

  final _generator = const RunGenerator();
  late Random _rng;
  final _stopwatch = Stopwatch();
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  RunSessionState? _results;

  @override
  RunSessionState build() {
    final startLevel = ref
        .read(progressProvider)
        .forGame(BestRunGame.gameId)
        .level;
    _rng = Random(seed);
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    _stopwatch
      ..reset()
      ..start();
    return RunSessionState(
      round: 0,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: _engine.level,
      puzzle: _newPuzzle(_engine.level),
    );
  }

  RunPuzzle _newPuzzle(int level) =>
      _generator.generate(level: level, seed: _rng.nextInt(1 << 31));

  /// Bars: the first tap picks one day, the second stretches to it, a third
  /// starts over. Prices: the first tap buys, a later day sells; an earlier
  /// day moves the buy.
  void tapDay(int i) {
    final s = state;
    if (s.locked || s.finished) return;
    final first = s.start;
    if (first == null || !s.picking) {
      state = s.copyWith(
        start: () => i,
        end: () => s.puzzle.prices ? null : i,
        picking: true,
      );
      return;
    }
    if (s.puzzle.prices) {
      state = i > first
          ? s.copyWith(end: () => i, picking: false)
          : s.copyWith(start: () => i, end: () => null);
      return;
    }
    state = s.copyWith(
      start: () => min(first, i),
      end: () => max(first, i),
      picking: false,
    );
  }

  void lock() {
    final s = state;
    if (!s.canLock || s.finished) return;
    _stopwatch.stop();
    final correct = s.puzzle.isBest(s.start!, s.end!);
    if (s.practice) {
      state = s.copyWith(locked: true, lastPoints: 0);
      return;
    }
    // Thinking is the point: the speed bonus is spread over a minute.
    final points = correct
        ? pointsForCorrectAnswer(
            level: s.level,
            elapsed: _stopwatch.elapsed ~/ 6,
          )
        : 0;
    _engine.record(correct: correct);
    if (!correct) {
      _lastMiss = NearMiss(
        round: s.round + 1,
        level: s.level,
        reason: s.puzzle.feedbackFor(s.start!, s.end!),
      );
    }
    state = s.copyWith(
      locked: true,
      picking: false,
      lastPoints: points,
      score: s.score + points,
      correctCount: s.correctCount + (correct ? 1 : 0),
      combo: correct ? s.combo + 1 : 0,
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
    state = RunSessionState(
      round: nextRound,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: state.startLevel,
      puzzle: _newPuzzle(_engine.level),
      score: state.score,
      correctCount: state.correctCount,
      combo: state.combo,
    );
    _stopwatch
      ..reset()
      ..start();
  }

  /// Plays one unscored chart at the level of the last miss.
  void trySimilar() {
    final miss = state.nearMiss;
    if (!state.finished || miss == null) return;
    _results = state;
    state = RunSessionState(
      round: totalRounds - 1,
      totalRounds: totalRounds,
      level: miss.level,
      startLevel: state.startLevel,
      puzzle: _newPuzzle(miss.level),
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
        .forGame(BestRunGame.gameId)
        .bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: BestRunGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const BestRunGame().skills,
      ),
    );
  }
}
