import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';
import '../../ui/lucid.dart';
import '../../ui/palette.dart';

import '../../core/game/game_registry.dart';
import '../../core/skills/skill.dart';
import '../../core/storage/appearance.dart';
import '../../core/storage/progress.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final d = Dims.of(context);

    final sessions = gameRegistry
        .map((g) => progress.forGame(g.id).sessions)
        .fold<int>(0, (a, b) => a + b);
    final totalXp = Skill.values
        .map(progress.xpFor)
        .fold<int>(0, (a, b) => a + b);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: EdgeInsets.fromLTRB(
          d.compact ? 16 : 20,
          d.compact ? 8 : 20,
          d.compact ? 16 : 20,
          bottom + 24,
        ),
        children: [
          Text('Profile', style: theme.textTheme.displaySmall),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _Stat(value: '$sessions', label: 'Sessions played'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _Stat(value: '$totalXp', label: 'Total XP'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const _AppearanceCard(),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Personal bests', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  for (final g in gameRegistry)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              g.title,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            progress.forGame(g.id).bestScore == 0
                                ? '—'
                                : '${progress.forGame(g.id).bestScore}',
                            style: theme.textTheme.titleSmall,
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
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
    final theme = Theme.of(context);
    final mode = ref.watch(appearanceProvider);
    final line = switch (mode) {
      ThemeMode.system => 'System follows your phone\'s setting.',
      ThemeMode.light => 'Light, whatever your phone is set to.',
      ThemeMode.dark =>
        'Dark is true black: kind to OLED screens and batteries.',
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Appearance', style: theme.textTheme.titleMedium),
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
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(value, style: theme.textTheme.headlineMedium),
            const SizedBox(height: 2),
            Text(label, style: theme.textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
