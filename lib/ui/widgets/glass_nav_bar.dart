import 'dart:ui' show ImageFilter;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../density.dart';
import '../lucid.dart';
import '../palette.dart';

class GlassNavItem {
  const GlassNavItem({required this.label, required this.icon});

  final String label;
  final IconData icon;
}

/// Floating, frosted pill tab bar. The selected tab sits in a soft tinted
/// pill (not a solid fill) that slides between tabs.
///
/// Blur is the expensive part; [blur] can be turned off on low-end devices,
/// in which case the bar falls back to a near-solid surface.
class GlassNavBar extends StatelessWidget {
  const GlassNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.blur = true,
  });

  final List<GlassNavItem> items;
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool blur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = Dims.of(context);
    final dark = scheme.brightness == Brightness.dark;
    final tint = (dark ? Lucid.nightSurface : context.palette.surface)
        .withValues(alpha: blur ? 0.7 : 0.96);
    final n = items.length;

    Widget bar = Container(
      height: d.navHeight,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: tint,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: dark ? Lucid.nightLine : Colors.white.withValues(alpha: 0.9),
        ),
      ),
      child: Stack(
        children: [
          AnimatedAlign(
            duration: Lucid.slide,
            curve: Curves.easeOutCubic,
            alignment: Alignment(
              n == 1 ? 0 : -1 + 2 * currentIndex / (n - 1),
              0,
            ),
            child: FractionallySizedBox(
              widthFactor: 1 / n,
              heightFactor: 1,
              // Soft tinted pill, never a solid fill: the bar stays light.
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: dark ? 0.14 : 0.08),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
          Row(
            children: [
              for (var i = 0; i < n; i++)
                Expanded(
                  child: _Tab(
                    item: items[i],
                    selected: i == currentIndex,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      onTap(i);
                    },
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (blur) {
      bar = ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: bar,
        ),
      );
    }

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: dark ? 0.4 : 0.14),
                blurRadius: 32,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: bar,
        ),
      ),
    );
  }
}

class _Tab extends StatelessWidget {
  const _Tab({required this.item, required this.selected, required this.onTap});

  final GlassNavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = selected ? scheme.primary : scheme.onSurfaceVariant;
    final d = Dims.of(context);

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(item.icon, size: d.compact ? 18 : 20, color: color),
            const SizedBox(height: 1),
            AnimatedDefaultTextStyle(
              duration: Lucid.slide,
              style: lucidText(
                size: d.compact ? 10 : 11,
                weight: selected ? 600 : 500,
                color: color,
              ),
              child: Text(item.label),
            ),
          ],
        ),
      ),
    );
  }
}
