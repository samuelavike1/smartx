import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'stop_or_roll_game.dart';
import 'stop_puzzle.dart';

@immutable
class StopSessionState {
  const StopSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.game,
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
  final StopGame game;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final bool practice;

  bool get answered => game.over;
  bool get lastCorrect => game.over && game.allRight;

  StopSessionState copyWith({
    int? level,
    StopGame? game,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => StopSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    game: game ?? this.game,
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

final stopSessionProvider =
    NotifierProvider.autoDispose<StopController, StopSessionState>(
      StopController.new,
    );

class StopController extends Notifier<StopSessionState> {
  static const int totalRounds = 8;

  /// Fixes the games in tests.
  @visibleForTesting
  static int? seed;

  late Random _rng;
  final _stopwatch = Stopwatch();
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  StopSessionState? _results;

  @override
  StopSessionState build() {
    final startLevel = ref
        .read(progressProvider)
        .forGame(StopOrRollGame.gameId)
        .level;
    _rng = Random(seed);
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    _stopwatch
      ..reset()
      ..start();
    return StopSessionState(
      round: 0,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: _engine.level,
      game: _newGame(_engine.level),
    );
  }

  StopGame _newGame(int level) =>
      StopGame.generate(level: level, seed: _rng.nextInt(1 << 31));

  void keep() => _choose(Choice.keep);
  void roll() => _choose(Choice.roll);

  void _choose(Choice c) {
    final s = state;
    if (s.answered || s.finished) return;
    final game = s.game.choose(c);
    if (!game.over) {
      state = s.copyWith(game: game);
      return;
    }
    _stopwatch.stop();
    final correct = game.allRight;
    if (s.practice) {
      state = s.copyWith(game: game, lastPoints: 0);
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
        reason: game.feedback(),
      );
    }
    state = s.copyWith(
      game: game,
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
    state = StopSessionState(
      round: nextRound,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: state.startLevel,
      game: _newGame(_engine.level),
      score: state.score,
      correctCount: state.correctCount,
      combo: state.combo,
    );
    _stopwatch
      ..reset()
      ..start();
  }

  /// Plays one unscored game at the level of the last miss.
  void trySimilar() {
    final miss = state.nearMiss;
    if (!state.finished || miss == null) return;
    _results = state;
    state = StopSessionState(
      round: totalRounds - 1,
      totalRounds: totalRounds,
      level: miss.level,
      startLevel: state.startLevel,
      game: _newGame(miss.level),
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
        .forGame(StopOrRollGame.gameId)
        .bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: StopOrRollGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const StopOrRollGame().skills,
      ),
    );
  }
}
