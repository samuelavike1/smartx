import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'grid_puzzle.dart';
import 'grid_recall_game.dart';

enum GridPhase { memorize, recall, review }

@immutable
class GridSessionState {
  const GridSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.puzzle,
    this.phase = GridPhase.memorize,
    this.flashIndex,
    this.taps = const [],
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
  final GridPuzzle puzzle;
  final GridPhase phase;

  /// Ordered puzzles: index into `puzzle.cells` currently flashing.
  final int? flashIndex;

  /// Cells the player has tapped, in tap order.
  final List<int> taps;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;

  /// Most recent wrong round, offered as "Try a similar one" on results.
  final NearMiss? nearMiss;

  /// A practice round from the results screen: not scored.
  final bool practice;

  bool get answered => phase == GridPhase.review;
  bool get lastCorrect => answered && puzzle.isCorrect(taps);

  GridSessionState copyWith({
    int? level,
    GridPhase? phase,
    int? Function()? flashIndex,
    List<int>? taps,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => GridSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    puzzle: puzzle,
    phase: phase ?? this.phase,
    flashIndex: flashIndex != null ? flashIndex() : this.flashIndex,
    taps: taps ?? this.taps,
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

final gridSessionProvider =
    NotifierProvider.autoDispose<GridRecallController, GridSessionState>(
      GridRecallController.new,
    );

class GridRecallController extends Notifier<GridSessionState> {
  static const int totalRounds = 8;

  final _generator = const GridRecallGenerator();
  final _rng = Random();
  final _stopwatch = Stopwatch();
  late DifficultyEngine _engine;
  Timer? _timer;
  NearMiss? _lastMiss;
  GridSessionState? _results;

  @override
  GridSessionState build() {
    ref.onDispose(() => _timer?.cancel());
    final startLevel = ref
        .read(progressProvider)
        .forGame(GridRecallGame.gameId)
        .level;
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    final s = GridSessionState(
      round: 0,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: _engine.level,
      puzzle: _newPuzzle(_engine.level),
    );
    _startMemorize(s.puzzle);
    return s;
  }

  GridPuzzle _newPuzzle(int level) =>
      _generator.generate(level: level, seed: _rng.nextInt(1 << 31));

  /// Shows the pattern, then hands over to the player.
  void _startMemorize(GridPuzzle puzzle) {
    _timer?.cancel();
    if (!puzzle.ordered) {
      _timer = Timer(puzzle.memorizeDuration, _startRecall);
      return;
    }
    var i = 0;
    _timer = Timer.periodic(GridPuzzle.flashStep, (t) {
      if (i < puzzle.cells.length) {
        state = state.copyWith(flashIndex: () => i);
        i++;
      } else {
        t.cancel();
        _startRecall();
      }
    });
  }

  void _startRecall() {
    state = state.copyWith(phase: GridPhase.recall, flashIndex: () => null);
    _stopwatch
      ..reset()
      ..start();
  }

  /// Taps a cell during recall. In free-order puzzles a second tap undoes it.
  void tap(int cell) {
    if (state.phase != GridPhase.recall) return;
    final taps = [...state.taps];
    if (taps.contains(cell)) {
      if (state.puzzle.ordered) return;
      taps.remove(cell);
    } else {
      taps.add(cell);
    }
    state = state.copyWith(taps: taps);
    if (taps.length == state.puzzle.cells.length) _evaluate();
  }

  void _evaluate() {
    _stopwatch.stop();
    final correct = state.puzzle.isCorrect(state.taps);

    if (state.practice) {
      state = state.copyWith(phase: GridPhase.review, lastPoints: 0);
      return;
    }

    final points = correct
        ? pointsForCorrectAnswer(
            level: state.level,
            elapsed: _stopwatch.elapsed,
          )
        : 0;
    _engine.record(correct: correct);
    if (!correct) {
      _lastMiss = NearMiss(
        round: state.round + 1,
        level: state.level,
        reason: firstSentence(state.puzzle.explain(state.taps)),
      );
    }
    state = state.copyWith(
      phase: GridPhase.review,
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

    final puzzle = _newPuzzle(_engine.level);
    state = GridSessionState(
      round: nextRound,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: state.startLevel,
      puzzle: puzzle,
      score: state.score,
      correctCount: state.correctCount,
      combo: state.combo,
    );
    _startMemorize(puzzle);
  }

  /// Plays one unscored round at the level of the last miss.
  void trySimilar() {
    final miss = state.nearMiss;
    if (!state.finished || miss == null) return;
    _results = state;
    final puzzle = _newPuzzle(miss.level);
    state = GridSessionState(
      round: totalRounds - 1,
      totalRounds: totalRounds,
      level: miss.level,
      startLevel: state.startLevel,
      puzzle: puzzle,
      score: state.score,
      correctCount: state.correctCount,
      combo: state.combo,
      practice: true,
    );
    _startMemorize(puzzle);
  }

  Future<void> _finish() async {
    final progress = ref.read(progressProvider.notifier);
    final previousBest = ref
        .read(progressProvider)
        .forGame(GridRecallGame.gameId)
        .bestScore;

    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );

    await progress.recordSession(
      GameResult(
        gameId: GridRecallGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const GridRecallGame().skills,
      ),
    );
  }
}
