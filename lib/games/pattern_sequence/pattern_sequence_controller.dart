import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'pattern_sequence_game.dart';
import 'sequence_generator.dart';
import 'sequence_puzzle.dart';

@immutable
class PatternSessionState {
  const PatternSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.puzzle,
    this.selectedIndex,
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
  final SequencePuzzle puzzle;
  final int? selectedIndex;
  final int lastPoints;
  final int score;
  final int correctCount;

  /// Correct answers in a row; resets on a miss.
  final int combo;
  final bool finished;
  final bool isNewBest;

  /// Most recent wrong round, offered as "Try a similar one" on results.
  final NearMiss? nearMiss;

  /// A practice round from the results screen: not scored.
  final bool practice;

  bool get answered => selectedIndex != null;
  bool get lastCorrect => selectedIndex == puzzle.answerIndex;

  PatternSessionState copyWith({
    int? level,
    int? selectedIndex,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => PatternSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    puzzle: puzzle,
    selectedIndex: selectedIndex ?? this.selectedIndex,
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

/// One session = [totalRounds] puzzles. Auto-disposed when the screen closes,
/// so every visit starts a fresh session from the saved level.
final patternSessionProvider =
    NotifierProvider.autoDispose<PatternSessionController, PatternSessionState>(
      PatternSessionController.new,
    );

class PatternSessionController extends Notifier<PatternSessionState> {
  static const int totalRounds = 10;

  final _generator = const SequenceGenerator();
  final _rng = Random();
  final _stopwatch = Stopwatch();
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  PatternSessionState? _results;

  @override
  PatternSessionState build() {
    final startLevel = ref
        .read(progressProvider)
        .forGame(PatternSequenceGame.gameId)
        .level;
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    _stopwatch
      ..reset()
      ..start();
    return PatternSessionState(
      round: 0,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: _engine.level,
      puzzle: _newPuzzle(_engine.level),
    );
  }

  SequencePuzzle _newPuzzle(int level) =>
      _generator.generate(level: level, seed: _rng.nextInt(1 << 31));

  void select(int index) {
    if (state.answered || state.finished) return;
    _stopwatch.stop();
    final correct = index == state.puzzle.answerIndex;

    if (state.practice) {
      state = state.copyWith(selectedIndex: index, lastPoints: 0);
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
        reason: firstSentence(state.puzzle.explanation),
      );
    }

    state = state.copyWith(
      selectedIndex: index,
      lastPoints: points,
      score: state.score + points,
      correctCount: state.correctCount + (correct ? 1 : 0),
      combo: correct ? state.combo + 1 : 0,
    );
  }

  Future<void> next() async {
    if (!state.answered || state.finished) return;

    if (state.practice) {
      // One practice round only: back to results without the offer.
      state = _results!.copyWith(nearMiss: () => null);
      return;
    }

    final nextRound = state.round + 1;
    if (nextRound >= totalRounds) {
      await _finish();
      return;
    }

    state = PatternSessionState(
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
    state = PatternSessionState(
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
        .forGame(PatternSequenceGame.gameId)
        .bestScore;

    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );

    await progress.recordSession(
      GameResult(
        gameId: PatternSequenceGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const PatternSequenceGame().skills,
      ),
    );
  }
}
