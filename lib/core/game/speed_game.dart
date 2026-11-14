import 'dart:async';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../difficulty/difficulty_engine.dart';
import '../skills/skill.dart';
import '../storage/progress.dart';
import 'game_definition.dart';
import 'scoring.dart';

// The timed-trials engine shared by the speed games (Ink Clash, Arrow
// Focus, …): a session is a few blocks of quick trials, each with a time
// limit. A trial is either calm (nothing pulls the wrong way) or in
// conflict (something does), so the review can show what the conflict cost.

/// One trial. [A] is the type of an answer (a colour, a direction, …).
abstract interface class SpeedTrial<A> {
  A get answer;

  /// Something on screen pulls towards a wrong answer.
  bool get conflict;
}

/// One answer: what was tapped (null = ran out of time) and how fast.
@immutable
class SpeedAnswer<A> {
  const SpeedAnswer(this.tapped, this.time);

  final A? tapped;
  final Duration time;
}

@immutable
class SpeedResult {
  const SpeedResult({
    required this.right,
    required this.correct,
    required this.calmAvg,
    required this.conflictAvg,
    required this.passMark,
  });

  final int right;

  /// Per trial: answered correctly?
  final List<bool> correct;

  /// Average time on correctly answered calm / conflict trials, in seconds
  /// (null when there were none).
  final double? calmAvg;
  final double? conflictAvg;

  final int passMark;

  bool get passed => right >= passMark;

  /// Extra seconds the conflict cost on average (null if not measurable).
  double? get conflictCost =>
      calmAvg == null || conflictAvg == null ? null : conflictAvg! - calmAvg!;

  /// Below this the cost is treated as none.
  static const double noticeable = 0.05;
}

/// A block of trials. Games subclass it to add the review wording.
abstract class SpeedBlock<T extends SpeedTrial<A>, A> {
  const SpeedBlock();

  int get level;
  int get seed;
  List<T> get trials;

  /// Time allowed per trial.
  Duration get limit;

  int get length => trials.length;

  /// A block passes at this many right.
  int get passMark => 10;

  /// The same block with other trials (e.g. a short burst for the Quick
  /// feed). Subclasses return their own type.
  SpeedBlock<T, A> withTrials(List<T> trials);

  SpeedResult evaluate(List<SpeedAnswer<A>> answers) {
    final correct = <bool>[];
    final calm = <double>[], conflict = <double>[];
    for (final (i, t) in trials.indexed) {
      final a = i < answers.length ? answers[i] : null;
      final ok = a?.tapped == t.answer;
      correct.add(ok);
      if (ok) {
        (t.conflict ? conflict : calm).add(a!.time.inMilliseconds / 1000);
      }
    }
    double? avg(List<double> xs) =>
        xs.isEmpty ? null : xs.reduce((a, b) => a + b) / xs.length;
    return SpeedResult(
      right: correct.where((c) => c).length,
      correct: correct,
      calmAvg: avg(calm),
      conflictAvg: avg(conflict),
      passMark: passMark,
    );
  }

  /// The first mistake explained (or that all were right). Shown on the
  /// feedback card; the speed card beside it shows the cost.
  String mistake(SpeedResult r, List<SpeedAnswer<A>> answers);

  /// Conflict trials in the plural, for the cost sentence ("Clashing words").
  String get conflictName;

  /// Said when the conflict cost nothing noticeable.
  String get noCostSentence;

  /// What the conflict cost, as a sentence ('' if not measurable).
  String costSentence(SpeedResult r) {
    final cost = r.conflictCost;
    if (cost == null) return '';
    return cost > SpeedResult.noticeable
        ? '$conflictName took ${cost.toStringAsFixed(2)} s longer.'
        : noCostSentence;
  }

  /// Full review text: the mistake, then what the conflict cost.
  String explain(SpeedResult r, List<SpeedAnswer<A>> answers) => [
    mistake(r, answers),
    costSentence(r),
  ].where((p) => p.isNotEmpty).join(' ');
}

enum SpeedPhase { ready, playing, review }

/// Runs trials one at a time: a deadline per trial (running out records no
/// answer), then a short right/wrong flash before the next. Shared by the
/// game sessions and the Quick feed's speed cards.
class TrialRun<A> {
  TrialRun({
    required this.answers,
    required this.limit,
    required this.onChange,
    required this.onDone,
    this.flashFor = SpeedController.flashFor,
  });

  /// The right answer for each trial, in order.
  final List<A> answers;
  final Duration limit;
  final Duration flashFor;

  /// Called after every change to [index], [given] or [flash].
  final void Function() onChange;

  /// Called once, after the last trial's flash.
  final void Function() onDone;

  /// Current trial (−1 before the start).
  int index = -1;
  final List<SpeedAnswer<A>> given = [];
  SpeedFlash<A>? flash;

  final _clock = Stopwatch();
  Timer? _deadline;
  Timer? _next;
  bool _over = false;

  bool get timing => !_over && index >= 0 && flash == null;
  bool get over => _over;

  void start() => _present(0);

  /// Answers the current trial. Returns whether it was right, or null if
  /// the answer didn't count (between trials, or after the end).
  bool? answer(A option) => timing ? _record(option) : null;

  void cancel() {
    _over = true;
    _deadline?.cancel();
    _next?.cancel();
  }

  void _present(int i) {
    index = i;
    flash = null;
    _clock
      ..reset()
      ..start();
    _deadline?.cancel();
    _deadline = Timer(limit, () => _record(null));
    onChange();
  }

  bool _record(A? option) {
    _deadline?.cancel();
    _clock.stop();
    final correct = option == answers[index];
    given.add(SpeedAnswer<A>(option, _clock.elapsed));
    flash = SpeedFlash<A>(index, option, correct);
    onChange();
    _next?.cancel();
    _next = Timer(flashFor, () {
      final n = index + 1;
      if (n < answers.length) {
        _present(n);
      } else {
        _over = true;
        onDone();
      }
    });
    return correct;
  }
}

/// The answer just given, shown briefly before the next trial.
@immutable
class SpeedFlash<A> {
  const SpeedFlash(this.index, this.tapped, this.correct);

  final int index;

  /// null = ran out of time.
  final A? tapped;
  final bool correct;
}

/// How an answer button should look right now.
enum SpeedMark { none, right, wrong, answer }

@immutable
class SpeedSessionState<
  B extends SpeedBlock<T, A>,
  T extends SpeedTrial<A>,
  A
> {
  const SpeedSessionState({
    required this.round,
    required this.totalRounds,
    required this.level,
    required this.startLevel,
    required this.block,
    this.phase = SpeedPhase.ready,
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
  final B block;
  final SpeedPhase phase;

  /// Current trial (−1 before the first).
  final int index;
  final List<SpeedAnswer<A>> answers;
  final SpeedFlash<A>? flash;
  final SpeedResult? result;
  final int lastPoints;
  final int score;
  final int correctCount;
  final int combo;
  final bool finished;
  final bool isNewBest;
  final NearMiss? nearMiss;
  final bool practice;

  bool get answered => phase == SpeedPhase.review;
  bool get lastCorrect => result?.passed ?? false;
  T? get trial =>
      index >= 0 && index < block.length ? block.trials[index] : null;

  /// The timer is running for the current trial.
  bool get timing => phase == SpeedPhase.playing && flash == null && index >= 0;

  /// How the button for [option] should look: the tapped one flashes green
  /// or rose, and after a miss the right one is outlined.
  SpeedMark markFor(A option) {
    final f = flash;
    if (f == null || f.index != index) return SpeedMark.none;
    if (f.tapped == option) {
      return f.correct ? SpeedMark.right : SpeedMark.wrong;
    }
    return trial?.answer == option ? SpeedMark.answer : SpeedMark.none;
  }

  SpeedSessionState<B, T, A> copyWith({
    int? level,
    SpeedPhase? phase,
    int? index,
    List<SpeedAnswer<A>>? answers,
    SpeedFlash<A>? Function()? flash,
    SpeedResult? result,
    int? lastPoints,
    int? score,
    int? correctCount,
    int? combo,
    bool? finished,
    bool? isNewBest,
    NearMiss? Function()? nearMiss,
  }) => SpeedSessionState(
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

/// Runs a session: get ready → trials (each with a deadline) → block review
/// → next block … → results. Games only say how to build a block.
abstract class SpeedController<
  B extends SpeedBlock<T, A>,
  T extends SpeedTrial<A>,
  A
>
    extends Notifier<SpeedSessionState<B, T, A>> {
  static const int totalRounds = 3;
  static const getReady = Duration(milliseconds: 1200);

  /// How long the right/wrong flash shows before the next trial.
  static const flashFor = Duration(milliseconds: 260);

  String get gameId;
  List<Skill> get skills;
  B generate({required int level, required int seed});

  final _rng = Random();
  Timer? _timer;
  TrialRun<A>? _run;
  late DifficultyEngine _engine;
  NearMiss? _lastMiss;
  SpeedSessionState<B, T, A>? _results;

  @override
  SpeedSessionState<B, T, A> build() {
    ref.onDispose(_cancel);
    final startLevel = ref.read(progressProvider).forGame(gameId).level;
    _engine = DifficultyEngine(level: startLevel);
    _lastMiss = null;
    final s = _fresh(round: 0, startLevel: _engine.level);
    _scheduleStart();
    return s;
  }

  void _cancel() {
    _timer?.cancel();
    _run?.cancel();
  }

  SpeedSessionState<B, T, A> _fresh({
    required int round,
    required int startLevel,
    int score = 0,
    int correctCount = 0,
    int combo = 0,
    int? level,
    bool practice = false,
  }) {
    final lvl = level ?? _engine.level;
    return SpeedSessionState(
      round: round,
      totalRounds: totalRounds,
      level: lvl,
      startLevel: startLevel,
      block: generate(level: lvl, seed: _rng.nextInt(1 << 31)),
      score: score,
      correctCount: correctCount,
      combo: combo,
      practice: practice,
    );
  }

  void _scheduleStart() {
    _cancel();
    _timer = Timer(getReady, () {
      state = state.copyWith(phase: SpeedPhase.playing);
      final run = TrialRun<A>(
        answers: [for (final t in state.block.trials) t.answer],
        limit: state.block.limit,
        onChange: () => _sync(_run!),
        onDone: _endBlock,
      );
      _run = run;
      run.start();
    });
  }

  void _sync(TrialRun<A> run) {
    state = state.copyWith(
      index: run.index,
      answers: List.unmodifiable(run.given),
      flash: () => run.flash,
    );
  }

  /// Answers the current trial. Returns whether it was right, or null if
  /// the answer didn't count (between trials, or before the start).
  bool? answer(A option) {
    if (!state.timing) return null;
    return _run?.answer(option);
  }

  void _endBlock() {
    _cancel();
    final result = state.block.evaluate(state.answers);
    if (state.practice) {
      state = state.copyWith(
        phase: SpeedPhase.review,
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
        reason: state.block.mistake(result, state.answers),
      );
    }
    state = state.copyWith(
      phase: SpeedPhase.review,
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
    final previousBest = ref.read(progressProvider).forGame(gameId).bestScore;
    state = state.copyWith(
      finished: true,
      level: _engine.level,
      isNewBest: state.score > previousBest,
      nearMiss: () => _lastMiss,
    );
    await progress.recordSession(
      GameResult(
        gameId: gameId,
        score: state.score,
        correct: state.correctCount,
        total: totalRounds,
        endLevel: _engine.level,
        skills: skills,
      ),
    );
  }
}
