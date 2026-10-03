import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Edge fade for scrolling panes.
///
/// Position-based near the scroll extents, and direction-aware: scrolling
/// down fades the effect out, scrolling up fades it back in. Driven directly
/// by scroll delta, so it is always in sync with your finger.
class ProgressiveBottomBlur extends StatefulWidget {
  const ProgressiveBottomBlur({
    super.key,
    required this.child,
    this.height = defaultHeight,
    this.topHeight = defaultTopHeight,
    this.travel = 80,
    this.minStrength = 0,
  });

  static const double defaultHeight = 96;
  static const double defaultTopHeight = 56;

  final Widget child;
  final double height;
  final double topHeight;

  /// Pixels of scrolling to go from fully shown to fully hidden.
  final double travel;

  /// Lowest strength the effect fades to (0 = gone, 1 = never hides).
  final double minStrength;

  @override
  State<ProgressiveBottomBlur> createState() => _ProgressiveBottomBlurState();
}

class _ProgressiveBottomBlurState extends State<ProgressiveBottomBlur> {
  final ValueNotifier<double> _top = ValueNotifier<double>(0);
  final ValueNotifier<double> _bottom = ValueNotifier<double>(0);

  /// 1 = effect shown, 0 = hidden.
  final ValueNotifier<double> _vis = ValueNotifier<double>(1);

  static const List<double> _ease = [0.0, 0.156, 0.5, 0.844, 1.0];

  @override
  void dispose() {
    _top.dispose();
    _bottom.dispose();
    _vis.dispose();
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

  void _trackDirection(ScrollUpdateNotification n, ScrollMetrics m) {
    final dy = n.scrollDelta ?? 0;
    final overscrolled =
        m.pixels < m.minScrollExtent || m.pixels > m.maxScrollExtent;
    if (dy == 0 || overscrolled) return;

    var v = _vis.value - dy / widget.travel;
    if (m.pixels - m.minScrollExtent < 1) v = 1; // fully shown at the top
    _set(_vis, v.clamp(0.0, 1.0));
  }

  bool _onNotification(Notification n) {
    final ScrollMetrics? m = n is ScrollNotification
        ? n.metrics
        : n is ScrollMetricsNotification
            ? n.metrics
            : null;
    if (m == null || m.axis != Axis.vertical) return false;

    if (n is ScrollUpdateNotification) _trackDirection(n, m);

    _set(_top, _strength(m.pixels - m.minScrollExtent, widget.topHeight));
    _set(_bottom, _strength(m.maxScrollExtent - m.pixels, widget.height));
    return false;
  }

  Shader _mask(Rect rect) {
    final v = widget.minStrength + (1 - widget.minStrength) * _vis.value;
    final t = _top.value * v, b = _bottom.value * v;
    final topFrac = (widget.topHeight / rect.height).clamp(0.0, 0.5);
    final botFrac = (widget.height / rect.height).clamp(0.0, 0.5);
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
        listenable: Listenable.merge([_top, _bottom, _vis]),
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
