import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'path_finder_game.dart';
import 'path_puzzle.dart';

@immutable
class PathSessionState {
  const PathSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.puzzle,
    required this.pos,
    this.hasKey = false,
    this.movesUsed = 0,
    this.trail = const [],
    this.lastSlide = const [],
    this.answered = false,
    this.won = false,
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
  final PathPuzzle puzzle;

  /// Where the piece is now.
  final int pos;
  final bool hasKey;
  final int movesUsed;

  /// Cells passed this attempt (drawn as faint dots).
  final List<int> trail;

  /// The last move: where it started, then every cell it passed (for the
  /// slide animation).
  final List<int> lastSlide;
  final bool answered;
  final bool won;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final bool practice;

  int get movesLeft => puzzle.moveLimit - movesUsed;
  bool get lastCorrect => answered && won;

  PathSessionState copyWith({
    int? level,
    int? pos,
    bool? hasKey,
    int? movesUsed,
    List<int>? trail,
    List<int>? lastSlide,
    bool? answered,
    bool? won,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => PathSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    puzzle: puzzle,
    pos: pos ?? this.pos,
    hasKey: hasKey ?? this.hasKey,
    movesUsed: movesUsed ?? this.movesUsed,
    trail: trail ?? this.trail,
    lastSlide: lastSlide ?? this.lastSlide,
    answered: answered ?? this.answered,
    won: won ?? this.won,
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

final pathSessionProvider =
    NotifierProvider.autoDispose<PathController, PathSessionState>(
      PathController.new,
    );

class PathController extends Notifier<PathSessionState> {
  static const int totalRounds = 5;

  final _generator = const PathGenerator();
  final _rng = Random();
  final _stopwatch = Stopwatch();
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  PathSessionState? _results;

  @override
  PathSessionState build() {
    final startLevel = ref
        .read(progressProvider)
        .forGame(PathFinderGame.gameId)
        .level;
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    _stopwatch
      ..reset()
      ..start();
    return _fresh(round: 0, startLevel: _engine.level);
  }

  PathSessionState _fresh({
    required int round,
    required int startLevel,
    int score = 0,
    int correctCount = 0,
    int combo = 0,
    int? level,
    bool practice = false,
  }) {
    final lvl = level ?? _engine.level;
    final puzzle = _generator.generate(level: lvl, seed: _rng.nextInt(1 << 31));
    return PathSessionState(
      round: round,
      totalRounds: totalRounds,
      level: lvl,
      startLevel: startLevel,
      puzzle: puzzle,
      pos: puzzle.start,
      score: score,
      correctCount: correctCount,
      combo: combo,
      practice: practice,
    );
  }

  /// Slides the piece. Returns false if nothing moved (blocked).
  bool move(Dir d) {
    if (state.answered || state.finished) return false;
    final r = state.puzzle.board.slide(state.pos, state.hasKey, d);
    if (!r.moved) return false;
    final used = state.movesUsed + 1;
    state = state.copyWith(
      pos: r.end,
      hasKey: r.hasKey,
      movesUsed: used,
      trail: [...state.trail, state.pos, ...r.path.take(r.path.length - 1)],
      lastSlide: [state.pos, ...r.path],
    );
    if (r.won) {
      _endRound(won: true);
    } else if (used >= state.puzzle.moveLimit) {
      _endRound(won: false);
    }
    return true;
  }

  /// Puts the piece back on its start square; moves reset.
  void restart() {
    if (state.answered || state.finished) return;
    state = state.copyWith(
      pos: state.puzzle.start,
      hasKey: false,
      movesUsed: 0,
      trail: const [],
      lastSlide: const [],
    );
  }

  void _endRound({required bool won}) {
    _stopwatch.stop();
    if (state.practice) {
      state = state.copyWith(answered: true, won: won, lastPoints: 0);
      return;
    }
    final points = won
        ? pointsForCorrectAnswer(
            level: state.level,
            elapsed: _stopwatch.elapsed,
          )
        : 0;
    _engine.record(correct: won);
    if (!won) {
      _lastMiss = NearMiss(
        round: state.round + 1,
        level: state.level,
        reason: 'Out of moves on a ${state.puzzle.shortest}-move board.',
      );
    }
    state = state.copyWith(
      answered: true,
      won: won,
      lastPoints: points,
      score: state.score + points,
      correctCount: state.correctCount + (won ? 1 : 0),
      combo: won ? state.combo + 1 : 0,
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
    state = _fresh(
      round: nextRound,
      startLevel: state.startLevel,
      score: state.score,
      correctCount: state.correctCount,
      combo: state.combo,
    );
    _stopwatch
      ..reset()
      ..start();
  }

  /// Plays one unscored board at the level of the last miss.
  void trySimilar() {
    final miss = state.nearMiss;
    if (!state.finished || miss == null) return;
    _results = state;
    state = _fresh(
      round: totalRounds - 1,
      startLevel: state.startLevel,
      score: state.score,
      correctCount: state.correctCount,
      combo: state.combo,
      level: miss.level,
      practice: true,
    );
  }

  Future<void> _finish() async {
    final progress = ref.read(progressProvider.notifier);
    final previousBest = ref
        .read(progressProvider)
        .forGame(PathFinderGame.gameId)
        .bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: PathFinderGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const PathFinderGame().skills,
      ),
    );
  }
}
