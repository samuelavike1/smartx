import 'package:material_ui/material_ui.dart';

import '../lucid.dart';

/// Shrinks its child slightly while pressed — Lucid's tap feedback in place
/// of Material ink ripples. Pass `onTap: null` to disable.
class PressScale extends StatefulWidget {
  const PressScale({
    super.key,
    required this.child,
    required this.onTap,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final String? semanticLabel;

  @override
  State<PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<PressScale> {
  bool _down = false;

  void _set(bool v) {
    if (widget.onTap != null && v != _down) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      // Own node, so screen readers (and tests) get this element's exact
      // bounds rather than its parent's.
      container: true,
      button: true,
      enabled: widget.onTap != null,
      label: widget.semanticLabel,
      // A given label replaces the child's text, so it isn't read twice.
      excludeSemantics: widget.semanticLabel != null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => _set(true),
        onTapUp: (_) => _set(false),
        onTapCancel: () => _set(false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _down ? 0.96 : 1,
          duration: Lucid.tap,
          curve: Curves.easeOut,
          child: widget.child,
        ),
      ),
    );
  }
}
