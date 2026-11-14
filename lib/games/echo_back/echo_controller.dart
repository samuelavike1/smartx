import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/difficulty/difficulty_engine.dart';
import '../../core/game/game_definition.dart';
import '../../core/game/scoring.dart';
import '../../core/storage/progress.dart';
import 'echo_back_game.dart';
import 'echo_puzzle.dart';

enum EchoPhase { ready, playing, review }

/// The most recent tap, so the button can flash right or wrong.
@immutable
class EchoTap {
  const EchoTap(this.step, this.channel, this.correct);

  final int step;
  final EchoChannel channel;
  final bool correct;
}

@immutable
class EchoSessionState {
  const EchoSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.block,
    this.phase = EchoPhase.ready,
    this.step = -1,
    this.visible = false,
    this.squareTaps = const {},
    this.colourTaps = const {},
    this.lastTap,
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
  final EchoBlock block;
  final EchoPhase phase;

  /// Current step (−1 before the first).
  final int step;

  /// Whether the current item is lit.
  final bool visible;
  final Set<int> squareTaps;
  final Set<int> colourTaps;
  final EchoTap? lastTap;
  final EchoResult? result;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final bool practice;

  bool get answered => phase == EchoPhase.review;
  bool get lastCorrect => result?.passed ?? false;

  EchoSessionState copyWith({
    int? level,
    EchoPhase? phase,
    int? step,
    bool? visible,
    Set<int>? squareTaps,
    Set<int>? colourTaps,
    EchoTap? Function()? lastTap,
    EchoResult? result,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => EchoSessionState(
    round: round,
    totalRounds: totalRounds,
    level: level ?? this.level,
    startLevel: startLevel,
    block: block,
    phase: phase ?? this.phase,
    step: step ?? this.step,
    visible: visible ?? this.visible,
    squareTaps: squareTaps ?? this.squareTaps,
    colourTaps: colourTaps ?? this.colourTaps,
    lastTap: lastTap != null ? lastTap() : this.lastTap,
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

final echoSessionProvider =
    NotifierProvider.autoDispose<EchoController, EchoSessionState>(
      EchoController.new,
    );

class EchoController extends Notifier<EchoSessionState> {
  static const int totalRounds = 4;
  static const getReady = Duration(milliseconds: 1200);

  final _generator = const EchoGenerator();
  final _rng = Random();
  late DifficultyEngine _engine;
  Timer? _stepTimer;
  Timer? _hideTimer;
  NearMiss? _lastMiss;
  EchoSessionState? _results;

  @override
  EchoSessionState build() {
    ref.onDispose(_cancel);
    final startLevel = ref
        .read(progressProvider)
        .forGame(EchoBackGame.gameId)
        .level;
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    final s = _fresh(round: 0, startLevel: _engine.level);
    _scheduleStart();
    return s;
  }

  void _cancel() {
    _stepTimer?.cancel();
    _hideTimer?.cancel();
  }

  EchoSessionState _fresh({
    required int round,
    required int startLevel,
    int score = 0,
    int correctCount = 0,
    int combo = 0,
    int? level,
    bool practice = false,
  }) {
    final lvl = level ?? _engine.level;
    return EchoSessionState(
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
    _stepTimer = Timer(getReady, () {
      state = state.copyWith(phase: EchoPhase.playing);
      _show(0);
      _stepTimer = Timer.periodic(state.block.interval, (_) => _advance());
    });
  }

  void _show(int step) {
    state = state.copyWith(step: step, visible: true);
    _hideTimer?.cancel();
    _hideTimer = Timer(state.block.showFor, () {
      if (state.phase == EchoPhase.playing) {
        state = state.copyWith(visible: false);
      }
    });
  }

  void _advance() {
    final next = state.step + 1;
    if (next >= state.block.length) {
      _endBlock();
    } else {
      _show(next);
    }
  }

  /// Registers a tap for [channel] on the current step. Returns whether it
  /// was a real match, or null if the tap didn't count.
  bool? tap(EchoChannel channel) {
    if (state.phase != EchoPhase.playing || state.step < 0) return null;
    final square = channel == EchoChannel.square;
    final taps = square ? state.squareTaps : state.colourTaps;
    if (taps.contains(state.step)) return null;
    final correct = state.block.isTarget(state.step, channel);
    final updated = {...taps, state.step};
    state = state.copyWith(
      squareTaps: square ? updated : null,
      colourTaps: square ? null : updated,
      lastTap: () => EchoTap(state.step, channel, correct),
    );
    return correct;
  }

  void _endBlock() {
    _cancel();
    final result = state.block.evaluate(
      squareTaps: state.squareTaps,
      colourTaps: state.colourTaps,
    );
    if (state.practice) {
      state = state.copyWith(
        phase: EchoPhase.review,
        visible: false,
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
        reason: firstSentence(state.block.explain(result)),
      );
    }
    state = state.copyWith(
      phase: EchoPhase.review,
      visible: false,
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
        .forGame(EchoBackGame.gameId)
        .bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: EchoBackGame.gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: const EchoBackGame().skills,
      ),
    );
  }
}
