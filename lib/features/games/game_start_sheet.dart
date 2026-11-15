import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/game/game_definition.dart';
import '../../core/storage/progress.dart';
import '../../ui/lucid.dart';
import '../../ui/palette.dart';
import 'group_screen.dart';

/// Opens the sheet for [game]: its progress, then Continue or Start over.
/// The game itself opens from [context] once the sheet has closed.
Future<void> showGameStartSheet(
  BuildContext context,
  GameDefinition game,
) async {
  final p = context.palette;
  final start = await showModalBottomSheet<bool>(
    context: context,
    // Above the tab bar, which lives in the shell.
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: p.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (_) => GameStartSheet(game: game),
  );
  if (start == true && context.mounted) {
    await context.push('/game/${game.id}');
  }
}

/// Game sheet from the canvas ("Game · Continue or Start over"). Pops `true`
/// when the game should start.
class GameStartSheet extends ConsumerWidget {
  const GameStartSheet({super.key, required this.game});

  final GameDefinition game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = context.palette;
    final progress = ref.watch(progressProvider).forGame(game.id);
    final main = game.skills.first.color;
    final isNew = progress.sessions == 0;
    final bottom = MediaQuery.paddingOf(context).bottom;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.fromLTRB(20, 12, 20, bottom > 0 ? 12 : 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 5,
                decoration: BoxDecoration(
                  color: p.line,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: main,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(game.icon, color: onFill(main), size: 28),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        game.title,
                        style: lucidText(
                          size: 24,
                          weight: 700,
                          display: true,
                          color: p.ink,
                          height: 1.1,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        game.tagline,
                        style: lucidText(size: 13, color: p.muted),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: Text(
                    'Level ${progress.level} of ${LevelTrack.levels}',
                    style: lucidText(size: 15, weight: 600, color: p.ink),
                  ),
                ),
                if (!isNew)
                  Text(
                    'Highest: ${progress.peakLevel}',
                    style: lucidText(size: 13, color: p.muted),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            LevelTrack(
              level: isNew ? 0 : progress.level,
              peak: isNew ? 0 : progress.peakLevel,
              height: 10,
              gap: 4,
            ),
            const SizedBox(height: 8),
            Text(
              _sentence(game.levelHint(progress.level)),
              style: lucidText(size: 13, color: p.muted),
            ),
            if (!isNew) ...[
              const SizedBox(height: 16),
              Row(
                children: [
                  _Stat(value: '${progress.bestScore}', label: 'Best score'),
                  const SizedBox(width: 8),
                  _Stat(value: '${progress.sessions}', label: 'Sessions'),
                  const SizedBox(width: 8),
                  _Stat(
                    value: lastPlayed(progress.lastPlayedDay, DateTime.now()),
                    label: 'Last played',
                  ),
                ],
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              key: const ValueKey('sheet-continue'),
              onPressed: () => Navigator.of(context).pop(true),
              icon: const Icon(Icons.play_arrow_rounded),
              label: Text(
                isNew ? 'Play' : 'Continue at level ${progress.level}',
              ),
            ),
            if (!isNew && progress.level > 1) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                key: const ValueKey('sheet-start-over'),
                onPressed: () async {
                  final yes = await _confirmStartOver(context, game, progress);
                  if (yes != true || !context.mounted) return;
                  await ref.read(progressProvider.notifier).startOver(game.id);
                  if (context.mounted) Navigator.of(context).pop(true);
                },
                icon: const Icon(Icons.restart_alt_rounded),
                label: const Text('Start over from level 1'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// "pricing on a tree" → "Pricing on a tree."
String _sentence(String s) =>
    s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}.';

/// "Today", "Yesterday", "3 days ago", or the date for older days.
String lastPlayed(String? day, DateTime now) {
  if (day == null) return '—';
  final d = DateTime.tryParse(day);
  if (d == null) return '—';
  final today = DateTime(now.year, now.month, now.day);
  final ago = today.difference(DateTime(d.year, d.month, d.day)).inDays;
  if (ago <= 0) return 'Today';
  if (ago == 1) return 'Yesterday';
  if (ago < 7) return '$ago days ago';
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${d.day} ${months[d.month - 1]}';
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final p = context.palette;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: p.ground,
          borderRadius: BorderRadius.circular(14),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: lucidText(
                  size: 20,
                  weight: 700,
                  display: true,
                  color: p.ink,
                ),
              ),
            ),
            Text(label, style: lucidText(size: 12, color: p.muted)),
          ],
        ),
      ),
    );
  }
}

Future<bool?> _confirmStartOver(
  BuildContext context,
  GameDefinition game,
  GameProgress progress,
) {
  return showDialog<bool>(
    context: context,
    builder: (context) {
      final p = context.palette;
      Widget bullet(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('•  ', style: lucidText(size: 14, color: p.muted)),
            Expanded(
              child: Text(
                text,
                style: lucidText(size: 14, color: p.muted, height: 1.45),
              ),
            ),
          ],
        ),
      );
      return Dialog(
        backgroundColor: p.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: p.chip,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(Icons.restart_alt_rounded, color: p.ink),
              ),
              const SizedBox(height: 14),
              Text(
                'Start ${game.title} over?',
                style: lucidText(
                  size: 22,
                  weight: 700,
                  display: true,
                  color: p.ink,
                  height: 1.2,
                ),
              ),
              const SizedBox(height: 12),
              bullet('You\'ll play from level 1 again.'),
              bullet(
                'Your best score, XP and highest level '
                '(${progress.peakLevel}) stay.',
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: p.chip,
                        foregroundColor: p.ink,
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton(
                      key: const ValueKey('confirm-start-over'),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 48),
                      ),
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Start over'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}
