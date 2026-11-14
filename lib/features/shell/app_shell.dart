import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../ui/widgets/glass_nav_bar.dart';

/// The four main tabs under the floating glass bar. Games, results and the
/// feed are pushed above this shell, so the bar is hidden while playing.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.shell});

  final StatefulNavigationShell shell;

  static const items = [
    GlassNavItem(label: 'Today', icon: Icons.wb_sunny_outlined),
    GlassNavItem(label: 'Games', icon: Icons.grid_view_rounded),
    GlassNavItem(label: 'Skills', icon: Icons.insights_rounded),
    GlassNavItem(label: 'Profile', icon: Icons.person_outline_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Content scrolls under the frosted bar.
      extendBody: true,
      body: shell,
      bottomNavigationBar: GlassNavBar(
        items: items,
        currentIndex: shell.currentIndex,
        onTap: (i) =>
            shell.goBranch(i, initialLocation: i == shell.currentIndex),
      ),
    );
  }
}
