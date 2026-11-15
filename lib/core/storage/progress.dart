import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../game/game_definition.dart';
import '../game/game_registry.dart';
import '../skills/skill.dart';

/// Calendar day as `YYYY-MM-DD` in local time, used for "played today".
String dayKey(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

@immutable
class GameProgress {
  const GameProgress({
    this.level = 1,
    int? peakLevel,
    this.bestScore = 0,
    this.sessions = 0,
    this.lastPlayedDay,
    this.lastScore = 0,
  }) : peakLevel = peakLevel ?? level;

  /// The level the next session starts at.
  final int level;

  /// The highest level ever reached. Starting over keeps it.
  final int peakLevel;
  final int bestScore;
  final int sessions;

  /// [dayKey] of the last finished session, or null if never played.
  final String? lastPlayedDay;

  /// Score of the last finished session.
  final int lastScore;

  bool playedOn(DateTime day) => lastPlayedDay == dayKey(day);

  /// Levels counted toward a group's progress: the highest level reached,
  /// or none for a game never played.
  int get levelsReached => sessions == 0 ? 0 : peakLevel;
}

@immutable
class ProgressSnapshot {
  const ProgressSnapshot({required this.games, required this.skillXp});

  final Map<String, GameProgress> games;
  final Map<Skill, int> skillXp;

  GameProgress forGame(String id) => games[id] ?? const GameProgress();
  int xpFor(Skill skill) => skillXp[skill] ?? 0;
}

/// Local persistence for progress. Kept behind this class so it can later be
/// swapped for SQLite (Drift) or synced to a backend without touching UI.
class ProgressRepository {
  ProgressRepository(this._prefs);

  final SharedPreferences _prefs;

  ProgressSnapshot load(Iterable<String> gameIds) {
    return ProgressSnapshot(
      games: {
        for (final id in gameIds)
          id: GameProgress(
            level: _prefs.getInt('game.$id.level') ?? 1,
            // Saved since groups came in; before that, the level is the peak.
            peakLevel: max(
              _prefs.getInt('game.$id.peak') ?? 1,
              _prefs.getInt('game.$id.level') ?? 1,
            ),
            bestScore: _prefs.getInt('game.$id.best') ?? 0,
            sessions: _prefs.getInt('game.$id.sessions') ?? 0,
            lastPlayedDay: _prefs.getString('game.$id.lastDay'),
            lastScore: _prefs.getInt('game.$id.lastScore') ?? 0,
          ),
      },
      skillXp: {
        for (final skill in Skill.values)
          skill: _prefs.getInt('skill.${skill.name}.xp') ?? 0,
      },
    );
  }

  Future<void> saveGame(String id, GameProgress p) async {
    await _prefs.setInt('game.$id.level', p.level);
    await _prefs.setInt('game.$id.peak', p.peakLevel);
    await _prefs.setInt('game.$id.best', p.bestScore);
    await _prefs.setInt('game.$id.sessions', p.sessions);
    await _prefs.setInt('game.$id.lastScore', p.lastScore);
    if (p.lastPlayedDay != null) {
      await _prefs.setString('game.$id.lastDay', p.lastPlayedDay!);
    }
  }

  Future<void> saveSkillXp(Skill skill, int xp) =>
      _prefs.setInt('skill.${skill.name}.xp', xp);

  /// The game's How to play page has been shown (and Start tapped).
  bool howToSeen(String gameId) =>
      _prefs.getBool('howto.$gameId.seen') ?? false;

  Future<void> markHowToSeen(String gameId) =>
      _prefs.setBool('howto.$gameId.seen', true);

  /// Percent right for [skill] in the last finished Quick feed, if any.
  int? feedAccuracy(Skill skill) => _prefs.getInt('feed.${skill.name}.pct');

  Future<void> saveFeedAccuracy(Skill skill, int percent) =>
      _prefs.setInt('feed.${skill.name}.pct', percent);

  /// 'system', 'light' or 'dark' (null until chosen).
  String? get themeMode => _prefs.getString('appearance.theme');

  Future<void> saveThemeMode(String mode) =>
      _prefs.setString('appearance.theme', mode);
}

/// Overridden in `main()` once SharedPreferences is loaded.
final progressRepositoryProvider = Provider<ProgressRepository>(
  (ref) => throw UnimplementedError('Override progressRepositoryProvider'),
);

final progressProvider = NotifierProvider<ProgressNotifier, ProgressSnapshot>(
  ProgressNotifier.new,
);

class ProgressNotifier extends Notifier<ProgressSnapshot> {
  @override
  ProgressSnapshot build() =>
      ref.read(progressRepositoryProvider).load(gameRegistry.map((g) => g.id));

  Future<void> recordSession(GameResult result) async {
    final repo = ref.read(progressRepositoryProvider);
    final previous = state.forGame(result.gameId);
    final updatedGame = GameProgress(
      level: result.endLevel,
      peakLevel: max(previous.peakLevel, result.endLevel),
      bestScore: max(previous.bestScore, result.score),
      sessions: previous.sessions + 1,
      lastPlayedDay: dayKey(DateTime.now()),
      lastScore: result.score,
    );
    final updatedXp = {...state.skillXp};
    for (final skill in result.skills) {
      updatedXp[skill] = (updatedXp[skill] ?? 0) + result.xpFor(skill);
    }

    state = ProgressSnapshot(
      games: {...state.games, result.gameId: updatedGame},
      skillXp: updatedXp,
    );

    await repo.saveGame(result.gameId, updatedGame);
    for (final skill in result.skills) {
      await repo.saveSkillXp(skill, updatedXp[skill]!);
    }
  }

  /// Start over: the next session of [gameId] is at level 1. Best score,
  /// sessions, highest level and XP all stay.
  Future<void> startOver(String gameId) async {
    final p = state.forGame(gameId);
    final updated = GameProgress(
      level: 1,
      peakLevel: p.peakLevel,
      bestScore: p.bestScore,
      sessions: p.sessions,
      lastPlayedDay: p.lastPlayedDay,
      lastScore: p.lastScore,
    );
    state = ProgressSnapshot(
      games: {...state.games, gameId: updated},
      skillXp: state.skillXp,
    );
    await ref.read(progressRepositoryProvider).saveGame(gameId, updated);
  }

  /// Adds XP earned outside a game session (the Quick feed). Game levels,
  /// best scores and "played today" are left alone.
  Future<void> addXp(Map<Skill, int> xp) async {
    final repo = ref.read(progressRepositoryProvider);
    final updated = {...state.skillXp};
    xp.forEach((skill, n) => updated[skill] = (updated[skill] ?? 0) + n);
    state = ProgressSnapshot(games: state.games, skillXp: updated);
    for (final skill in xp.keys) {
      await repo.saveSkillXp(skill, updated[skill]!);
    }
  }
}
