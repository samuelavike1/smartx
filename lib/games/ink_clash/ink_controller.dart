import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'ink_clash_game.dart';
import 'ink_puzzle.dart';

enum InkPhase { ready, playing, review }

/// The answer just given, shown briefly before the next word.
@immutable
class InkFlash {
  const InkFlash(this.index, this.tapped, this.correct);

  final int index;

  /// null = ran out of time.
  final InkColour? tapped;
  final bool correct;
}

@immutable
class InkSessionState {
  const InkSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.block,
    this.phase = InkPhase.ready,
    this.index = -1,
    this.answers = const [],
    this.flash,
    this.result,
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
  final InkBlock block;
  final InkPhase phase;

  /// Current word (−1 before the first).
  final int index;
  final List<InkAnswer> answers;
  final InkFlash? flash;
  final InkResult? result;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final bool practice;

  bool get answered => phase == InkPhase.review;
  bool get lastCorrect => result?.passed ?? false;
  InkTrial? get trial =>
      index >= 0 && index < block.length ? block.trials[index] : null;

  InkSessionState copyWith({
    int? level,
    InkPhase? phase,
    int? index,
    List<InkAnswer>? answers,
    InkFlash? Function()? flash,
    InkResult? result,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => InkSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    block: block,
    phase: phase ?? this.phase,
    index: index ?? this.index,
    answers: answers ?? this.answers,
    flash: flash != null ? flash() : this.flash,
    result: result ?? this.result,
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

final inkSessionProvider =
    NotifierProvider.autoDispose<InkController, InkSessionState>(
      InkController.new,
    );

class InkController extends Notifier<InkSessionState> {
  static const int totalRounds = 3;
  static const getReady = Duration(milliseconds: 1200);

  /// How long the right/wrong flash shows before the next word.
  static const flashFor = Duration(milliseconds: 260);

  final _generator = const InkGenerator();
  final _rng = Random();
  final _clock = Stopwatch();
  Timer? _timer;
  Timer? _deadline;
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  InkSessionState? _results;

  @override
  InkSessionState build() {
    ref.onDispose(_cancel);
    final startLevel = ref
        .read(progressProvider)
        .forGame(InkClashGame.gameId)
        .level;
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    final s = _fresh(round: 0, startLevel: _engine.level);
    _scheduleStart();
    return s;
  }

  void _cancel() {
    _timer?.cancel();
    _deadline?.cancel();
  }

  InkSessionState _fresh({
    required int round,
    required int startLevel,
    int score = 0,
    int correctCount = 0,
    int combo = 0,
    int? level,
    bool practice = false,
  }) {
    final lvl = level ?? _engine.level;
    return InkSessionState(
      round: round,
      totalRounds: totalRounds,
      level: lvl,
      startLevel: startLevel,
      block: _generator.generate(level: lvl, seed: _rng.nextInt(1 << 31)),
      score: score,
      correctCount: correctCount,
      combo: combo,
      practice: practice,
    );
  }

  void _scheduleStart() {
    _cancel();
    _timer = Timer(getReady, () {
      state = state.copyWith(phase: InkPhase.playing);
      _present(0);
    });
  }

  void _present(int i) {
    state = state.copyWith(index: i, flash: () => null);
    _clock
      ..reset()
      ..start();
    _deadline?.cancel();
    _deadline = Timer(state.block.limit, () => _record(null));
  }

  /// Answers the current word. Returns whether it was right, or null if the
  /// tap didn't count (between words, or before the start).
  bool? answer(InkColour colour) {
    if (state.phase != InkPhase.playing ||
        state.flash != null ||
        state.index < 0) {
      return null;
    }
    return _record(colour);
  }

  bool _record(InkColour? colour) {
    _deadline?.cancel();
    _clock.stop();
    final trial = state.trial!;
    final correct = colour == trial.answer;
    state = state.copyWith(
      answers: [...state.answers, InkAnswer(colour, _clock.elapsed)],
      flash: () => InkFlash(state.index, colour, correct),
    );
    _timer?.cancel();
    _timer = Timer(flashFor, () {
      final next = state.index + 1;
      next < state.block.length ? _present(next) : _endBlock();
    });
    return correct;
  }

  void _endBlock() {
    _cancel();
    final result = state.block.evaluate(state.answers);
    if (state.practice) {
      state = state.copyWith(
        phase: InkPhase.review,
        flash: () => null,
        result: result,
        lastPoints: 0,
      );
      return;
    }
    final passed = result.passed;
    final points = passed
        ? pointsForCorrectAnswer(level: state.level, elapsed: Duration.zero)
        : 0;
    _engine.record(correct: passed);
    if (!passed) {
      _lastMiss = NearMiss(
        round: state.round + 1,
        level: state.level,
        reason: firstSentence(state.block.explain(result, state.answers)),
      );
    }
    state = state.copyWith(
      phase: InkPhase.review,
      flash: () => null,
      result: result,
      lastPoints: points,
      score: state.score + points,
      correctCount: state.correctCount + (passed ? 1 : 0),
      combo: passed ? state.combo + 1 : 0,
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
    _scheduleStart();
  }

  /// Plays one unscored block at the level of the last miss.
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
    _scheduleStart();
  }

  Future<void> _finish() async {
    final progress = ref.read(progressProvider.notifier);
    final previousBest = ref
        .read(progressProvider)
        .forGame(InkClashGame.gameId)
        .bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: InkClashGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const InkClashGame().skills,
      ),
    );
  }
}
