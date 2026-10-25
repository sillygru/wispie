import 'package:flutter/material.dart';

import '../motion/motion.dart';
import '../tokens/app_tokens.dart';
import 'app_icon.dart';
import '../tokens/app_icons.dart';

/// A toggle icon that pops when tapped — a spring dip, then a bouncy settle —
/// with an accent ring that blooms outward the moment it becomes active.
///
/// The active state is owned by the caller (usually a provider); [onTap]
/// performs the toggle, and this widget animates in response to [isActive]
/// flipping. Because the pop is a spring, a second tap mid-pop bends from the
/// drawn scale instead of restarting the animation.
class PopIcon extends StatefulWidget {
  final bool isActive;
  final AppIconData activeIcon;
  final AppIconData inactiveIcon;

  /// Accent used for the active glyph and the bloom ring.
  final Color activeColor;
  final Color? inactiveColor;

  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  final double size;

  /// Overall tap target; defaults to [size] + breathing room.
  final double? hitSize;

  const PopIcon({
    super.key,
    required this.isActive,
    required this.onTap,
    this.activeIcon = AppIcons.favorite,
    this.inactiveIcon = AppIcons.favorite,
    required this.activeColor,
    this.inactiveColor,
    this.onLongPress,
    this.size = 28,
    this.hitSize,
  });

  @override
  State<PopIcon> createState() => _PopIconState();
}

// Two tickers: the scale spring and the ring bloom.
class _PopIconState extends State<PopIcon> with TickerProviderStateMixin {
  late final SpringMorph<double> _pop = SpringMorph<double>(
    vsync: this,
    lerp: (a, b, t) => a + (b - a) * t,
    initial: 1,
  );
  late final AnimationController _ring = AnimationController(
    vsync: this,
    duration: MotionTokens.long,
  );
  late final Animation<double> _ringScale = Tween<double>(
    begin: 0.35,
    end: 1.9,
  ).animate(
    CurvedAnimation(parent: _ring, curve: MotionTokens.emphasized),
  );
  late final Animation<double> _ringFade = Tween<double>(
    begin: 0.45,
    end: 0.0,
  ).animate(
    CurvedAnimation(parent: _ring, curve: const Interval(0.0, 0.65)),
  );

  @override
  void dispose() {
    _pop.dispose();
    _ring.dispose();
    super.dispose();
  }

  void _handleTap() {
    // Both directions pop; only turning on gets the ring.
    final bool activating = !widget.isActive;
    MotionHaptics.medium();
    widget.onTap();
    if (!mounted || MotionPolicy.read(context).reduceMotion) return;

    _pop.jumpTo(0.82);
    _pop.retarget(
      1.0,
      spring: activating ? MotionSprings.bouncy : MotionSprings.snappy,
    );
    if (activating) _ring.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final double hit = widget.hitSize ?? widget.size + 20;
    final Color inactive =
        widget.inactiveColor ?? AppTokens.fg(AppTokens.aSecondary);

    return InkResponse(
      radius: hit / 2,
      onTap: _handleTap,
      onLongPress: widget.onLongPress == null
          ? null
          : () {
              MotionHaptics.medium();
              widget.onLongPress!();
            },
      child: SizedBox(
        width: hit,
        height: hit,
        child: AnimatedBuilder(
          animation: Listenable.merge([_pop.progressListenable, _ring]),
          builder: (context, child) {
            return Stack(
              alignment: Alignment.center,
              children: [
                if (_ring.isAnimating && _ringFade.value > 0)
                  Transform.scale(
                    scale: _ringScale.value,
                    child: Container(
                      width: widget.size + 2,
                      height: widget.size + 2,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: widget.activeColor
                              .withValues(alpha: _ringFade.value),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                Transform.scale(scale: _pop.value, child: child),
              ],
            );
          },
          child: AppIcon(
            widget.isActive ? widget.activeIcon : widget.inactiveIcon,
            size: widget.size,
            color: widget.isActive ? widget.activeColor : inactive,
          ),
        ),
      ),
    );
  }
}
