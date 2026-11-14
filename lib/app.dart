import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'core/game/game_registry.dart';
import 'features/feed/feed_screen.dart';
import 'features/games/games_screen.dart';
import 'features/profile/profile_screen.dart';
import 'features/shell/app_shell.dart';
import 'features/skills/skills_screen.dart';
import 'features/today/today_screen.dart';
import 'ui/density.dart';
import 'ui/theme.dart';

GoRouter buildRouter() => GoRouter(
  initialLocation: '/today',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (_, _, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/today', builder: (_, _) => const TodayScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/games', builder: (_, _) => const GamesScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/skills', builder: (_, _) => const SkillsScreen()),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(path: '/profile', builder: (_, _) => const ProfileScreen()),
          ],
        ),
      ],
    ),
    // Outside the shell: games and the feed run full screen, without the
    // tab bar.
    GoRoute(path: '/feed', builder: (_, _) => const FeedScreen()),
    GoRoute(
      path: '/game/:id',
      builder: (_, state) {
        final game = findGame(state.pathParameters['id']!);
        return game?.buildScreen() ??
            const Scaffold(body: Center(child: Text('Game not found')));
      },
    ),
  ],
);

class SmartXApp extends StatefulWidget {
  const SmartXApp({super.key});

  @override
  State<SmartXApp> createState() => _SmartXAppState();
}

class _SmartXAppState extends State<SmartXApp> {
  final _router = buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SmartX',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      routerConfig: _router,
      builder: (context, child) {
        final brightness = Theme.of(context).brightness;
        final dark = brightness == Brightness.dark;
        final dims = Dims.of(context);
        // Transparent system bars with icons that suit the theme.
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
                systemNavigationBarContrastEnforced: false,
              ),
          // Small phones get the compact density (see "Density" artboard).
          child: dims.compact
              ? Theme(
                  data: buildTheme(brightness, compact: true),
                  child: child!,
                )
              : child!,
        );
      },
    );
  }
}
