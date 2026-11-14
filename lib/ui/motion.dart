import 'dart:math';

import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'palette.dart';

// Motion from the "Proposal · motion" note. Everything here drops to plain
// fades (or nothing) when the phone asks for reduced motion.

/// True when the system asks for less motion.
bool reducedMotion(BuildContext context) =>
    MediaQuery.maybeDisableAnimationsOf(context) ?? false;

/// Screens outside the tab bar (a game, the feed) slide in a little from the
/// right while fading in; the screen underneath drifts left and fades.
Page<void> slidePage(GoRouterState state, Widget child) =>
    CustomTransitionPage<void>(
      key: state.pageKey,
      child: child,
      transitionDuration: const Duration(milliseconds: 280),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      transitionsBuilder: (context, animation, secondary, child) {
        final fadeIn = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOut,
        );
        if (reducedMotion(context)) {
          return FadeTransition(opacity: fadeIn, child: child);
        }
        final inCurve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        final outCurve = CurvedAnimation(
          parent: secondary,
          curve: Curves.easeOutCubic,
        );
        // Pushed over: drift left. Arriving: slide in from the right, fading.
        return SlideTransition(
          position: Tween(
            begin: Offset.zero,
            end: const Offset(-0.06, 0),
          ).animate(outCurve),
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0.08, 0),
              end: Offset.zero,
            ).animate(inCurve),
            child: FadeTransition(opacity: fadeIn, child: child),
          ),
        );
      },
    );

/// The tab screens, kept alive like an IndexedStack; the one that becomes
/// current fades in.
class FadeBranches extends StatelessWidget {
  const FadeBranches({super.key, required this.index, required this.children});

  final int index;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        for (final (i, child) in children.indexed)
          Offstage(
            offstage: i != index,
            child: TickerMode(
              enabled: i == index,
              child: _FadeWhenShown(shown: i == index, child: child),
            ),
          ),
      ],
    );
  }
}

class _FadeWhenShown extends StatefulWidget {
  const _FadeWhenShown({required this.shown, required this.child});

  final bool shown;
  final Widget child;

  @override
  State<_FadeWhenShown> createState() => _FadeWhenShownState();
}

class _FadeWhenShownState extends State<_FadeWhenShown>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
    value: 1,
  );

  @override
  void didUpdateWidget(_FadeWhenShown old) {
    super.didUpdateWidget(old);
    if (widget.shown && !old.shown && !reducedMotion(context)) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FadeTransition(
    opacity: CurvedAnimation(parent: _c, curve: Curves.easeOut),
    child: widget.child,
  );
}

/// Fades a list item in and lifts it 12 px, 40 ms after the one before.
/// Only the first few items animate; later ones are built while scrolling
/// and just appear.
class FadeSlideIn extends StatelessWidget {
  const FadeSlideIn({super.key, required this.index, required this.child});

  final int index;
  final Widget child;

  static const _firstFew = 7;

  @override
  Widget build(BuildContext context) {
    if (index >= _firstFew || reducedMotion(context)) return child;
    final delay = index * 40;
    final total = 280 + delay;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: total),
      curve: Interval(delay / total, 1, curve: Curves.easeOutCubic),
      builder: (_, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 12 * (1 - t)),
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A one-off burst of confetti for a level up or a new best (about 1.2 s).
/// Paints over its area without taking touches.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.seed = 7});

  final int seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..forward();

  late final List<_Bit> _bits = () {
    final rng = Random(widget.seed);
    return [
      for (var i = 0; i < 70; i++)
        _Bit(
          angle: -pi / 2 + (rng.nextDouble() - 0.5) * pi * 0.9,
          speed: 0.55 + rng.nextDouble() * 0.6,
          spin: (rng.nextDouble() - 0.5) * 14,
          size: 5 + rng.nextDouble() * 5,
          colour: rng.nextInt(5),
        ),
    ];
  }();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (reducedMotion(context)) return const SizedBox.shrink();
    final p = context.palette;
    final colours = [
      p.spark,
      p.correct,
      const Color(0xFF2563EB),
      const Color(0xFFDB2777),
      const Color(0xFFEAB308),
    ];
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_bits, _c.value, colours),
        ),
      ),
    );
  }
}

class _Bit {
  const _Bit({
    required this.angle,
    required this.speed,
    required this.spin,
    required this.size,
    required this.colour,
  });

  final double angle, speed, spin, size;
  final int colour;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.bits, this.t, this.colours);

  final List<_Bit> bits;
  final double t;
  final List<Color> colours;

  @override
  void paint(Canvas canvas, Size size) {
    if (t <= 0 || t >= 1) return;
    // Bursts from the score, near the top centre, then falls.
    final origin = Offset(size.width / 2, size.height * 0.16);
    final reach = size.width * 0.75;
    final fade = t < 0.75 ? 1.0 : (1 - t) / 0.25;
    for (final b in bits) {
      final pos =
          origin +
          Offset(cos(b.angle), sin(b.angle)) * (b.speed * reach * t) +
          Offset(0, 0.9 * reach * t * t);
      final paint = Paint()..color = colours[b.colour].withValues(alpha: fade);
      canvas.save();
      canvas.translate(pos.dx, pos.dy);
      canvas.rotate(b.spin * t);
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset.zero,
            width: b.size,
            height: b.size * 0.55,
          ),
          const Radius.circular(1.5),
        ),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}
