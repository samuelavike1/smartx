import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'scale_puzzle.dart';
import 'scale_sleuth_game.dart';

enum Pan { left, right }

@immutable
class ScaleSessionState {
  const ScaleSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.puzzle,
    this.left = const [],
    this.right = const [],
    this.pan = Pan.left,
    this.weighed = false,
    this.naming = false,
    this.selected,
    this.reveal,
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
  final ScalePuzzle puzzle;

  /// Coins on each pan, in the order they were put there.
  final List<int> left;
  final List<int> right;

  /// The pan that tapped coins go onto.
  final Pan pan;

  /// The pans hold exactly what was last weighed, so the beam shows its tilt.
  final bool weighed;

  final bool naming;
  final int? selected;
  final ScaleReveal? reveal;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final bool practice;

  bool get answered => reveal != null;
  bool get lastCorrect => reveal?.correct ?? false;
  bool get canWeigh =>
      !answered &&
      !weighed &&
      puzzle.weighingsLeft > 0 &&
      left.isNotEmpty &&
      left.length == right.length;

  /// What the beam shows: the last result while the pans are untouched.
  Tilt? get tilt => weighed ? puzzle.log.last.tilt : null;

  Pan? panOf(int coin) => left.contains(coin)
      ? Pan.left
      : (right.contains(coin) ? Pan.right : null);

  ScaleSessionState copyWith({
    int? level,
    ScalePuzzle? puzzle,
    List<int>? left,
    List<int>? right,
    Pan? pan,
    bool? weighed,
    bool? naming,
    int? Function()? selected,
    ScaleReveal? reveal,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => ScaleSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    puzzle: puzzle ?? this.puzzle,
    left: left ?? this.left,
    right: right ?? this.right,
    pan: pan ?? this.pan,
    weighed: weighed ?? this.weighed,
    naming: naming ?? this.naming,
    selected: selected != null ? selected() : this.selected,
    reveal: reveal ?? this.reveal,
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

final scaleSessionProvider =
    NotifierProvider.autoDispose<ScaleController, ScaleSessionState>(
      ScaleController.new,
    );

class ScaleController extends Notifier<ScaleSessionState> {
  static const int totalRounds = 6;

  /// Fixes the puzzles in tests.
  @visibleForTesting
  static int? seed;

  late Random _rng;
  final _stopwatch = Stopwatch();
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  ScaleSessionState? _results;

  @override
  ScaleSessionState build() {
    final startLevel = ref
        .read(progressProvider)
        .forGame(ScaleSleuthGame.gameId)
        .level;
    _rng = Random(seed);
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    _stopwatch
      ..reset()
      ..start();
    return ScaleSessionState(
      round: 0,
      totalRounds: totalRounds,
      level: _engine.level,
      startLevel: _engine.level,
      puzzle: _newPuzzle(_engine.level),
    );
  }

  ScalePuzzle _newPuzzle(int level) =>
      ScalePuzzle.generate(level: level, seed: _rng.nextInt(1 << 31));

  /// Puts a coin on the chosen pan, or takes it off the pan it's on. While
  /// naming, picks the coin instead.
  void tapCoin(int coin) {
    final s = state;
    if (s.answered || s.finished) return;
    if (s.naming) {
      state = s.copyWith(selected: () => s.selected == coin ? null : coin);
      return;
    }
    final on = s.panOf(coin);
    if (on != null) {
      state = s.copyWith(
        left: [...s.left.where((c) => c != coin)],
        right: [...s.right.where((c) => c != coin)],
        weighed: false,
      );
    } else {
      state = s.pan == Pan.left
          ? s.copyWith(left: [...s.left, coin], weighed: false)
          : s.copyWith(right: [...s.right, coin], weighed: false);
    }
  }

  void choosePan(Pan pan) {
    if (state.answered || state.naming) return;
    state = state.copyWith(pan: pan);
  }

  void clearPans() {
    if (state.answered) return;
    state = state.copyWith(left: const [], right: const [], weighed: false);
  }

  void weigh() {
    final s = state;
    if (!s.canWeigh) return;
    final puzzle = s.puzzle.weigh(s.left, s.right);
    state = s.copyWith(
      puzzle: puzzle,
      weighed: true,
      // Out of weighings: time to name it.
      naming: puzzle.weighingsLeft == 0,
    );
  }

  void startNaming() {
    if (state.answered) return;
    state = state.copyWith(naming: true);
  }

  void keepWeighing() {
    final s = state;
    if (s.answered || s.puzzle.weighingsLeft == 0) return;
    state = s.copyWith(naming: false, selected: () => null);
  }

  void name() {
    final s = state;
    final coin = s.selected;
    if (s.answered || s.finished || coin == null) return;
    _stopwatch.stop();
    final reveal = s.puzzle.name(coin);
    final correct = reveal.correct;
    if (s.practice) {
      state = s.copyWith(reveal: reveal, lastPoints: 0);
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
        reason: s.puzzle.feedbackFor(reveal),
      );
    }
    state = s.copyWith(
      reveal: reveal,
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
    state = ScaleSessionState(
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

  /// Plays one unscored puzzle at the level of the last miss.
  void trySimilar() {
    final miss = state.nearMiss;
    if (!state.finished || miss == null) return;
    _results = state;
    state = ScaleSessionState(
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
        .forGame(ScaleSleuthGame.gameId)
        .bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: ScaleSleuthGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const ScaleSleuthGame().skills,
      ),
    );
  }
}
