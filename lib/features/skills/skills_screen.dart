import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/density.dart';

import '../../core/skills/skill.dart';
import '../../core/storage/progress.dart';
import '../../ui/lucid.dart';
import '../../ui/widgets/skill_marker.dart';

/// Each skill levels up every [xpPerLevel] XP earned across all games.
const int xpPerLevel = 100;

class SkillsScreen extends ConsumerWidget {
  const SkillsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;
    final d = Dims.of(context);

    // Highlight the weakest skill so the next step is obvious.
    final weakest = Skill.values.reduce(
      (a, b) => progress.xpFor(b) < progress.xpFor(a) ? b : a,
    );
    final anyXp = Skill.values.any((s) => progress.xpFor(s) > 0);

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
          Text('Skills', style: theme.textTheme.displaySmall),
          const SizedBox(height: 4),
          Text(
            'Every 100 XP is a new skill level.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 20),
          Card(
            clipBehavior: Clip.antiAlias,
            child: Column(
              children: [
                for (final (i, skill) in Skill.values.indexed) ...[
                  if (i > 0) const Divider(),
                  _SkillRow(
                    skill: skill,
                    xp: progress.xpFor(skill),
                    highlight: anyXp && skill == weakest,
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

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.skill,
    required this.xp,
    required this.highlight,
  });

  final Skill skill;
  final int xp;
  final bool highlight;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final level = xp ~/ xpPerLevel + 1;

    return Container(
      color: highlight ? skill.color.withValues(alpha: 0.08) : null,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          SkillMarkerIcon(skill, size: 12),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        skill.label,
                        style: theme.textTheme.titleSmall,
                      ),
                    ),
                    Text('Lv $level', style: theme.textTheme.labelMedium),
                  ],
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: (xp % xpPerLevel) / xpPerLevel),
                    duration: Lucid.pop * 2,
                    curve: Curves.easeOutCubic,
                    builder: (_, v, _) => LinearProgressIndicator(
                      value: v,
                      minHeight: 6,
                      color: skill.color,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  highlight ? '$xp XP · your weakest skill' : '$xp XP',
                  style: theme.textTheme.labelSmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
