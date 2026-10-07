import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../tokens/app_tokens.dart';

/// Shell-tab visibility with motion. The incoming tab springs in from the side
/// it lives on (a hint of overshoot, interruptible mid-flight), the outgoing
/// one ducks out quickly toward the other side, and once hidden the tab goes
/// [Offstage] with tickers off exactly like a plain stack would.
class TabSwitchTransition extends StatefulWidget {
  final bool active;

  /// +1 when the newly selected tab sits to the right of the old one.
  final int direction;
  final Widget child;

  const TabSwitchTransition({
    super.key,
    required this.active,
    required this.direction,
    required this.child,
  });

  static final SpringDescription _spring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 420, ratio: 0.82);

  @override
  State<TabSwitchTransition> createState() => _TabSwitchTransitionState();
}

class _TabSwitchTransitionState extends State<TabSwitchTransition>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this, value: widget.active ? 1 : 0);
  late int _dir = widget.direction;

  @override
  void didUpdateWidget(covariant TabSwitchTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.active == widget.active) return;
    _dir = widget.direction;
    if (widget.active) {
      _c.animateWith(
        SpringSimulation(TabSwitchTransition._spring, _c.value, 1, _c.velocity),
      );
    } else {
      _c.animateTo(0, duration: AppTokens.dFast, curve: Curves.easeOutCubic);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      child: widget.child,
      builder: (context, child) {
        final double v = _c.value;
        final bool hidden = !widget.active && v <= 0.001;
        // Incoming enters from +dir; outgoing leaves toward -dir.
        final double side = widget.active ? _dir.toDouble() : -_dir.toDouble();
        final double t = v.clamp(0.0, 1.0);
        // Shared-axis handoff: the outgoing tab is gone by ~60% of its exit
        // and the incoming one only starts to show after the first quarter,
        // so the two pages never sit on top of each other as a muddy
        // double exposure.
        final double opacity = widget.active
            ? Curves.easeOut.transform(((t - 0.25) / 0.75).clamp(0.0, 1.0))
            : ((t - 0.4) / 0.6).clamp(0.0, 1.0);
        return Offstage(
          offstage: hidden,
          child: TickerMode(
            enabled: !hidden,
            child: IgnorePointer(
              ignoring: !widget.active,
              child: Opacity(
                opacity: opacity,
                // Fixed travel rather than a fraction of the width, so wide
                // windows do not throw the page a long way.
                child: Transform.translate(
                  offset: Offset((1 - v) * side * AppTokens.s6, 0),
                  child: Transform.scale(
                    scale: 0.98 + 0.02 * t,
                    child: child,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
