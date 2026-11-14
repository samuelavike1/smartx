import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'deduce_game.dart';
import 'deduce_puzzle.dart';

@immutable
class DeduceSessionState {
  const DeduceSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.puzzle,
    required this.placed,
    this.selected,
    this.answered = false,
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
  final DeducePuzzle puzzle;

  /// What sits in each spot, left to right (null = empty).
  final List<DeduceItem?> placed;

  /// Shape picked from the tray, waiting for a spot.
  final DeduceItem? selected;
  final bool answered;
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

  /// Shapes not yet placed, in tray order.
  List<DeduceItem> get tray =>
      puzzle.tray.where((i) => !placed.contains(i)).toList();

  bool get complete => placed.every((p) => p != null);
  List<DeduceItem> get order => placed.cast<DeduceItem>();
  bool get lastCorrect => answered && puzzle.isSolution(placed);

  DeduceSessionState copyWith({
    int? level,
    List<DeduceItem?>? placed,
    DeduceItem? Function()? selected,
    bool? answered,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => DeduceSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    puzzle: puzzle,
    placed: placed ?? this.placed,
    selected: selected != null ? selected() : this.selected,
    answered: answered ?? this.answered,
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

final deduceSessionProvider =
    NotifierProvider.autoDispose<DeduceController, DeduceSessionState>(
      DeduceController.new,
    );

class DeduceController extends Notifier<DeduceSessionState> {
  static const int totalRounds = 5;

  final _generator = const DeduceGenerator();
  final _rng = Random();
  final _stopwatch = Stopwatch();
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  DeduceSessionState? _results;

  @override
  DeduceSessionState build() {
    final startLevel = ref
        .read(progressProvider)
        .forGame(DeduceGame.gameId)
        .level;
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    _stopwatch
      ..reset()
      ..start();
    return _fresh(round: 0, startLevel: _engine.level);
  }

  DeduceSessionState _fresh({
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
    return DeduceSessionState(
      round: round,
      totalRounds: totalRounds,
      level: lvl,
      startLevel: startLevel,
      puzzle: puzzle,
      placed: List.filled(puzzle.size, null),
      score: score,
      correctCount: correctCount,
      combo: combo,
      practice: practice,
    );
  }

  /// Picks a tray shape (tap again to put it down).
  void pick(DeduceItem item) {
    if (state.answered) return;
    state = state.copyWith(
      selected: () => state.selected == item ? null : item,
    );
  }

  /// With a shape picked: put it here (any shape already here goes back to
  /// the tray). Without: send this spot's shape back to the tray.
  void tapSpot(int i) {
    if (state.answered) return;
    final placed = [...state.placed];
    final picked = state.selected;
    if (picked != null) {
      placed[i] = picked;
      state = state.copyWith(placed: placed, selected: () => null);
    } else if (placed[i] != null) {
      placed[i] = null;
      state = state.copyWith(placed: placed);
    }
  }

  void check() {
    if (state.answered || !state.complete) return;
    _stopwatch.stop();
    final correct = state.puzzle.isSolution(state.placed);

    if (state.practice) {
      state = state.copyWith(
        answered: true,
        selected: () => null,
        lastPoints: 0,
      );
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
      final firstBroken = state.puzzle.brokenClues(state.order).first + 1;
      _lastMiss = NearMiss(
        round: state.round + 1,
        level: state.level,
        reason: 'Clue $firstBroken tripped you up.',
      );
    }
    state = state.copyWith(
      answered: true,
      selected: () => null,
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

  /// Plays one unscored round at the level of the last miss.
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
        .forGame(DeduceGame.gameId)
        .bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: DeduceGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const DeduceGame().skills,
      ),
    );
  }
}
