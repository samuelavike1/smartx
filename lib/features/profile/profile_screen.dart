import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';

import '../../core/game/game_registry.dart';
import '../../core/skills/skill.dart';
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
