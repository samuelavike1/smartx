import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/game/game_registry.dart';
import '../../core/skills/skill.dart';
import '../../core/storage/appearance.dart';
import '../../core/storage/progress.dart';
import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/motion.dart';
import '../../ui/palette.dart';
import '../../ui/widgets/skill_marker.dart';

// Built from the "Profile · redesign" artboards.

/// XP for one level, of the brain and of each skill.
const _xpPerLevel = 100;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final p = context.palette;
    final bottom = MediaQuery.paddingOf(context).bottom;
    final d = Dims.of(context);
    final side = d.compact ? 16.0 : 20.0;

    Widget heading(String title, String note) => Row(
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Expanded(
          child: Text(
            title,
            style: lucidText(size: 17, weight: 600, color: p.ink),
          ),
        ),
        Text(note, style: lucidText(size: 13, color: p.muted)),
      ],
    );

    final played =
        [
          for (final g in gameRegistry)
            if (progress.forGame(g.id).bestScore > 0) g,
        ]..sort(
          (a, b) => progress
              .forGame(b.id)
              .bestScore
              .compareTo(progress.forGame(a.id).bestScore),
        );

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          side,
          d.compact ? 8 : 20,
          side,
          bottom + 24,
        ),
        children: [
          Text(
            'Profile',
            style: lucidText(
              size: d.screenTitle,
              weight: 700,
              display: true,
              color: p.ink,
            ),
          ),
          SizedBox(height: d.gapM),
          FadeSlideIn(index: 0, child: _BrainCard(progress: progress)),
          SizedBox(height: d.gapL),
          heading('Skills', '$_xpPerLevel XP a level'),
          const SizedBox(height: 10),
          FadeSlideIn(index: 1, child: _SkillGrid(progress: progress)),
          SizedBox(height: d.gapL),
          heading(
            'Personal bests',
            played.length == 1 ? '1 game' : '${played.length} games',
          ),
          const SizedBox(height: 10),
          FadeSlideIn(
            index: 2,
            child: _Bests(games: played, progress: progress),
          ),
          SizedBox(height: d.gapL),
          const FadeSlideIn(index: 3, child: _AppearanceCard()),
        ],
      ),
    );
  }
}

/// Brain level, progress to the next, and three quick numbers.
class _BrainCard extends StatelessWidget {
  const _BrainCard({required this.progress});

  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final d = Dims.of(context);
    final xp = Skill.values.map(progress.xpFor).fold<int>(0, (a, b) => a + b);
    final level = xp ~/ _xpPerLevel + 1;
    final toNext = _xpPerLevel - xp % _xpPerLevel;
    final sessions = gameRegistry
        .map((g) => progress.forGame(g.id).sessions)
        .fold<int>(0, (a, b) => a + b);
    final tried = gameRegistry
        .where((g) => progress.forGame(g.id).sessions > 0)
        .length;
    final top = xp == 0
        ? null
        : Skill.values.reduce(
            (a, b) => progress.xpFor(b) > progress.xpFor(a) ? b : a,
          );

    Widget tile(Widget value, String label) => Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.heroRow,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(fit: BoxFit.scaleDown, child: value),
            Text(label, style: lucidText(size: 12, color: p.heroQuiet)),
          ],
        ),
      ),
    );
    final big = lucidText(
      size: 20,
      weight: 700,
      display: true,
      color: p.heroText,
    );

    return Semantics(
      label:
          'Brain level $level, $xp XP, $toNext to level ${level + 1}. '
          '$sessions sessions, $tried of ${gameRegistry.length} games tried'
          '${top == null ? '' : ', top skill ${top.label}'}.',
      excludeSemantics: true,
      child: Container(
        padding: EdgeInsets.all(d.compact ? 14 : 18),
        decoration: BoxDecoration(
          color: p.hero,
          borderRadius: BorderRadius.circular(24),
          border: p.isNight ? Border.all(color: p.line) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: p.spark,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Icon(
                    Icons.psychology_rounded,
                    size: 30,
                    color: p.onSpark,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'BRAIN LEVEL',
                        style: lucidLabel(p.heroLabel, size: 12),
                      ),
                      Text(
                        'Level $level',
                        style: lucidText(
                          size: 28,
                          weight: 700,
                          display: true,
                          color: p.heroText,
                          height: 1.1,
                        ),
                      ),
                      Text(
                        '${_thousands(xp)} XP · $toNext to level ${level + 1}',
                        style: lucidText(size: 13, color: p.heroQuiet),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (xp % _xpPerLevel) / _xpPerLevel),
                duration: Lucid.pop * 3,
                curve: Curves.easeOutCubic,
                builder: (_, v, _) => LinearProgressIndicator(
                  value: v,
                  minHeight: 8,
                  color: p.spark,
                  backgroundColor: p.heroRow,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                tile(Text('$sessions', style: big), 'Sessions'),
                const SizedBox(width: 8),
                tile(
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$tried'),
                        TextSpan(
                          text: '/${gameRegistry.length}',
                          style: lucidText(
                            size: 14,
                            weight: 600,
                            display: true,
                            color: p.heroQuiet,
                          ),
                        ),
                      ],
                    ),
                    style: big,
                  ),
                  'Games tried',
                ),
                const SizedBox(width: 8),
                tile(Text(top?.shortLabel ?? '—', style: big), 'Top skill'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _thousands(int n) {
  final s = '$n';
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

/// Six skills in a 2 × 3 grid: marker, name, level and a bar.
class _SkillGrid extends StatelessWidget {
  const _SkillGrid({required this.progress});

  final ProgressSnapshot progress;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    Widget cell(Skill s) {
      final xp = progress.xpFor(s);
      final level = xp ~/ _xpPerLevel + 1;
      return Expanded(
        child: Semantics(
          label: '${s.label}, level $level, $xp XP',
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: p.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    SkillMarkerIcon(s, size: 11),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        s.shortLabel,
                        overflow: TextOverflow.ellipsis,
                        style: lucidText(size: 14, weight: 600, color: p.ink),
                      ),
                    ),
                    Text(
                      'Lv $level',
                      style: lucidText(size: 12, weight: 700, color: p.muted),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: (xp % _xpPerLevel) / _xpPerLevel,
                    minHeight: 6,
                    color: s.color,
                    backgroundColor: p.chip,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final skills = Skill.values;
    return Column(
      children: [
        for (var r = 0; r < skills.length; r += 2) ...[
          if (r > 0) const SizedBox(height: 10),
          Row(
            children: [
              cell(skills[r]),
              const SizedBox(width: 10),
              if (r + 1 < skills.length)
                cell(skills[r + 1])
              else
                const Spacer(),
            ],
          ),
        ],
      ],
    );
  }
}

/// Games with a best, highest first: the top five, then "Show all".
class _Bests extends StatefulWidget {
  const _Bests({required this.games, required this.progress});

  final List<GameDefinition> games;
  final ProgressSnapshot progress;

  @override
  State<_Bests> createState() => _BestsState();
}

class _BestsState extends State<_Bests> {
  static const _first = 5;
  bool _all = false;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final games = widget.games;
    final shown = _all ? games : games.take(_first).toList();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: games.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Text(
                'Play a game to set your first best.',
                style: lucidText(size: 14, color: p.muted),
              ),
            )
          : AnimatedSize(
              duration: Lucid.pop,
              curve: Curves.easeOutCubic,
              alignment: Alignment.topCenter,
              child: Column(
                children: [
                  for (final (i, g) in shown.indexed)
                    _BestRow(
                      game: g,
                      progress: widget.progress.forGame(g.id),
                      divider: i > 0,
                    ),
                  if (games.length > _first)
                    TextButton(
                      key: const ValueKey('bests-toggle'),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _all = !_all);
                      },
                      child: Text(
                        _all ? 'Show fewer' : 'Show all ${games.length}',
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _BestRow extends StatelessWidget {
  const _BestRow({
    required this.game,
    required this.progress,
    required this.divider,
  });

  final GameDefinition game;
  final GameProgress progress;
  final bool divider;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    final colour = game.skills.first.color;
    final sessions = progress.sessions == 1
        ? '1 session'
        : '${progress.sessions} sessions';
    final detail = game.hasLevels
        ? 'Level ${progress.level} · $sessions'
        : sessions;
    return Semantics(
      label: '${game.title}: best ${progress.bestScore}. $detail.',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          border: divider ? Border(top: BorderSide(color: p.line)) : null,
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: colour,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(game.icon, size: 19, color: onFill(colour)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    game.title,
                    style: lucidText(size: 15, weight: 600, color: p.ink),
                  ),
                  Text(detail, style: lucidText(size: 12, color: p.muted)),
                ],
              ),
            ),
            Text(
              '${progress.bestScore}',
              style: lucidText(
                size: 18,
                weight: 700,
                display: true,
                color: p.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// System · Light · Dark. Built from the "Profile · Appearance" artboards.
class _AppearanceCard extends ConsumerWidget {
  const _AppearanceCard();

  static const _options = [
    (ThemeMode.system, 'System', Icons.smartphone_rounded),
    (ThemeMode.light, 'Light', Icons.light_mode_outlined),
    (ThemeMode.dark, 'Dark', Icons.dark_mode_outlined),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final mode = ref.watch(appearanceProvider);
    final line = switch (mode) {
      ThemeMode.system => 'System follows your phone\'s setting.',
      ThemeMode.light => 'Light, whatever your phone is set to.',
      ThemeMode.dark =>
        'Dark is true black: kind to OLED screens and batteries.',
    };
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Appearance',
            style: lucidText(size: 16, weight: 600, color: p.ink),
          ),
          const SizedBox(height: 2),
          Text(line, style: lucidText(size: 13, color: p.muted)),
          const SizedBox(height: 12),
          Container(
            height: 44,
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: p.chip,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                for (final (i, (m, label, icon)) in _options.indexed) ...[
                  if (i > 0) const SizedBox(width: 4),
                  Expanded(
                    child: Semantics(
                      button: true,
                      selected: m == mode,
                      label: '$label appearance',
                      excludeSemantics: true,
                      child: GestureDetector(
                        key: ValueKey('theme-${m.name}'),
                        behavior: HitTestBehavior.opaque,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          ref.read(appearanceProvider.notifier).choose(m);
                        },
                        child: AnimatedContainer(
                          duration: Lucid.pop,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: m == mode ? p.ink : null,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          // Scales down on narrow phones or big text.
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    icon,
                                    size: 18,
                                    color: m == mode ? p.onInk : p.muted,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    label,
                                    style: lucidText(
                                      size: 14,
                                      weight: 600,
                                      color: m == mode ? p.onInk : p.muted,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
