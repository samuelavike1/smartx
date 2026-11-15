import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'egg_drop_game.dart';
import 'egg_puzzle.dart';

@immutable
class EggSessionState {
  const EggSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.puzzle,
    this.selected,
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
  final EggPuzzle puzzle;

  /// The floor picked for the next drop.
  final int? selected;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final bool practice;

  /// The round is over (settled, or out of eggs or drops).
  bool get answered => puzzle.over;
  bool get lastCorrect => puzzle.won;

  EggSessionState copyWith({
    int? level,
    EggPuzzle? puzzle,
    int? Function()? selected,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => EggSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    puzzle: puzzle ?? this.puzzle,
    selected: selected != null ? selected() : this.selected,
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

final eggSessionProvider =
    NotifierProvider.autoDispose<EggController, EggSessionState>(
      EggController.new,
    );

class EggController extends Notifier<EggSessionState> {
  /// Each round takes several drops, so a session is six rounds.
  static const int totalRounds = 6;

  /// Fixes the puzzles in tests.
  @visibleForTesting
  static int? seed;

  late Random _rng;
  final _stopwatch = Stopwatch();
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  EggSessionState? _results;

  @override
  EggSessionState build() {
    final startLevel = ref
        .read(progressProvider)
        .forGame(EggDropGame.gameId)
        .level;
    _rng = Random(seed);
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    _stopwatch
      ..reset()
      ..start();
    return EggSessionState(
      round: 0,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: _engine.level,
      puzzle: _newPuzzle(_engine.level),
    );
  }

  EggPuzzle _newPuzzle(int level) =>
      EggPuzzle.generate(level: level, seed: _rng.nextInt(1 << 31));

  /// Picks a floor for the next drop, or unpicks it.
  void tapFloor(int floor) {
    final s = state;
    if (s.answered || s.finished || !s.puzzle.canDrop(floor)) return;
    state = s.copyWith(selected: () => s.selected == floor ? null : floor);
  }

  /// Drops an egg from the picked floor; the round ends once the floor is
  /// settled or the eggs or drops run out.
  void drop() {
    final s = state;
    final floor = s.selected;
    if (s.answered || s.finished || floor == null) return;
    final puzzle = s.puzzle.drop(floor);
    if (!puzzle.over) {
      state = s.copyWith(puzzle: puzzle, selected: () => null);
      return;
    }
    _stopwatch.stop();
    final correct = puzzle.won;
    if (s.practice) {
      state = s.copyWith(puzzle: puzzle, selected: () => null, lastPoints: 0);
      return;
    }
    // Planning is the point: the speed bonus is spread over two minutes.
    final points = correct
        ? pointsForCorrectAnswer(
            level: s.level,
            elapsed: _stopwatch.elapsed ~/ 12,
          )
        : 0;
    _engine.record(correct: correct);
    if (!correct) {
      _lastMiss = NearMiss(
        round: s.round + 1,
        level: s.level,
        reason: puzzle.feedback,
      );
    }
    state = s.copyWith(
      puzzle: puzzle,
      selected: () => null,
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
    state = EggSessionState(
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

  /// Plays one unscored round at the level of the last miss.
  void trySimilar() {
    final miss = state.nearMiss;
    if (!state.finished || miss == null) return;
    _results = state;
    state = EggSessionState(
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
        .forGame(EggDropGame.gameId)
        .bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: EggDropGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const EggDropGame().skills,
      ),
    );
  }
}
