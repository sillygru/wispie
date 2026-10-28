// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/widgets.dart';

/// Pauses the animation inside [child] while the surface around it moves.
///
/// A transform is free; what it moves is not. Flutter re-rasterises a subtree
/// whose own tickers keep running, so a screen sliding under an opacity, a clip
/// or a translate pays for itself again on every frame of the slide — the
/// particle field, the waveform, the beat pulse, all of it drawn afresh.
/// Freezing the subtree turns the motion into a cached raster under a
/// transform, and everything resumes the moment the surface settles.
///
/// [animation] is the surface's own driver. [dragging] covers the frames where a
/// finger, not an animation, is moving it; the caller rebuilds when that flips.
class FreezeWhileMoving extends StatefulWidget {
  const FreezeWhileMoving({
    super.key,
    required this.animation,
    required this.child,
    this.dragging = false,
  });

  final Animation<double> animation;
  final bool dragging;
  final Widget child;

  @override
  State<FreezeWhileMoving> createState() => _FreezeWhileMovingState();
}

class _FreezeWhileMovingState extends State<FreezeWhileMoving> {
  @override
  void initState() {
    super.initState();
    widget.animation.addStatusListener(_onStatus);
  }

  @override
  void didUpdateWidget(covariant FreezeWhileMoving oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      oldWidget.animation.removeStatusListener(_onStatus);
      widget.animation.addStatusListener(_onStatus);
    }
  }

  @override
  void dispose() {
    widget.animation.removeStatusListener(_onStatus);
    super.dispose();
  }

  /// The tick that lands still reports an animating controller, so the frame
  /// that lets go of the freeze arrives here rather than on a tick.
  void _onStatus(AnimationStatus status) {
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      child: widget.child,
      builder: (context, child) => TickerMode(
        enabled: !(widget.dragging || widget.animation.isAnimating),
        child: child!,
      ),
    );
  }
}
