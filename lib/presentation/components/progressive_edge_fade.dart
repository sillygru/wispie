import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Edge fade for scrolling panes.
///
/// Each edge fades in only while content is actually hidden past it, so the
/// first and last rows sit crisp at the extents. While the list is moving the
/// fades reach a little deeper, proportional to scroll speed, and relax back
/// once it settles. The fade never switches off mid-scroll, so content (and
/// auto-scrolled lyrics) never hard-cuts at an edge.
class ProgressiveEdgeFade extends StatefulWidget {
  const ProgressiveEdgeFade({
    super.key,
    required this.child,
    this.height = defaultHeight,
    this.topHeight = defaultTopHeight,
    this.motionStretch = 0.6,
  });

  static const double defaultHeight = 96;
  static const double defaultTopHeight = 56;

  final Widget child;
  final double height;
  final double topHeight;

  /// How much deeper (as a fraction of the base height) the fades reach at
  /// full scroll speed.
  final double motionStretch;

  @override
  State<ProgressiveEdgeFade> createState() => _ProgressiveEdgeFadeState();
}

class _ProgressiveEdgeFadeState extends State<ProgressiveEdgeFade>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _top = ValueNotifier<double>(0);
  final ValueNotifier<double> _bottom = ValueNotifier<double>(0);

  /// 0 = at rest, 1 = scrolling fast.
  late final AnimationController _motion = AnimationController(vsync: this);

  static const List<double> _ease = [0.0, 0.156, 0.5, 0.844, 1.0];

  @override
  void dispose() {
    _top.dispose();
    _bottom.dispose();
    _motion.dispose();
    super.dispose();
  }

  static double _strength(double hidden, double fade) {
    final t = (hidden / fade).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  void _set(ValueNotifier<double> n, double v) {
    if ((n.value - v).abs() < 0.004) return;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) n.value = v;
      });
    } else {
      n.value = v;
    }
  }

  void _trackMotion(ScrollUpdateNotification n) {
    final double speed = ((n.scrollDelta ?? 0).abs() / 24).clamp(0.0, 1.0);
    final double next = _motion.value + (speed - _motion.value) * 0.3;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      return;
    }
    _motion.value = next;
  }

  void _settle() {
    _motion.animateTo(
      0,
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
  }

  bool _onNotification(Notification n) {
    final ScrollMetrics? m = n is ScrollNotification
        ? n.metrics
        : n is ScrollMetricsNotification
            ? n.metrics
            : null;
    if (m == null || m.axis != Axis.vertical) return false;

    if (n is ScrollUpdateNotification) _trackMotion(n);
    if (n is ScrollEndNotification) _settle();

    _set(_top, _strength(m.pixels - m.minScrollExtent, widget.topHeight));
    _set(_bottom, _strength(m.maxScrollExtent - m.pixels, widget.height));
    return false;
  }

  Shader _mask(Rect rect) {
    final double stretch = 1 + widget.motionStretch * _motion.value;
    final t = _top.value, b = _bottom.value;
    final topFrac = (widget.topHeight * stretch / rect.height).clamp(0.0, 0.5);
    final botFrac = (widget.height * stretch / rect.height).clamp(0.0, 0.5);
    final last = _ease.length - 1;
    final colors = <Color>[];
    final stops = <double>[];
    for (var i = 0; i <= last; i++) {
      colors.add(Colors.black.withValues(alpha: 1 - t * (1 - _ease[i])));
      stops.add(topFrac * i / last);
    }
    for (var i = 0; i <= last; i++) {
      colors.add(Colors.black.withValues(alpha: 1 - b * (1 - _ease[last - i])));
      stops.add(1 - botFrac + botFrac * i / last);
    }
    return LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: colors,
      stops: stops,
    ).createShader(rect);
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: ListenableBuilder(
        listenable: Listenable.merge([_top, _bottom, _motion]),
        child: widget.child,
        builder: (context, child) => ShaderMask(
          blendMode: BlendMode.dstIn,
          shaderCallback: (rect) => _mask(rect),
          child: child,
        ),
      ),
    );
  }
}
