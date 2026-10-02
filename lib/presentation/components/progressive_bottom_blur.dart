import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Progressive blur + fade on the top and bottom edge of a scrolling pane.
///
/// Each edge's strength follows how much content is scrolled underneath it:
/// zero at the start/end of the list, easing (smoothstep) to full once a
/// fade-height of content is hidden. Nothing is timer-driven, so it tracks
/// drags, flings and lyric auto-scroll identically.
///
/// Cost model: the blur bands are only built while an edge is active, use
/// cached filters, and tiny sigmas are skipped. The content fade is a single
/// ShaderMask whose gradient is rebuilt from two doubles.
class ProgressiveBottomBlur extends StatefulWidget {
  const ProgressiveBottomBlur({
    super.key,
    required this.child,
    this.height = defaultHeight,
    this.topHeight = defaultTopHeight,
  });

  /// Bottom fade height. Also what panes use as their end spacer.
  static const double defaultHeight = 96;
  static const double defaultTopHeight = 56;

  final Widget child;
  final double height;
  final double topHeight;

  @override
  State<ProgressiveBottomBlur> createState() => _ProgressiveBottomBlurState();
}

class _ProgressiveBottomBlurState extends State<ProgressiveBottomBlur> {
  final ValueNotifier<double> _top = ValueNotifier<double>(0);
  final ValueNotifier<double> _bottom = ValueNotifier<double>(0);

  // Inverse smoothstep samples, 0 at the outer edge -> 1 at the inner edge.
  static const List<double> _ease = [0.0, 0.156, 0.5, 0.844, 1.0];

  @override
  void dispose() {
    _top.dispose();
    _bottom.dispose();
    super.dispose();
  }

  static double _strength(double hiddenPixels, double fade) {
    final t = (hiddenPixels / fade).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  void _set(ValueNotifier<double> notifier, double value) {
    if ((notifier.value - value).abs() < 0.004) return;
    // Metrics notifications can arrive mid-layout; never rebuild then.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) notifier.value = value;
      });
    } else {
      notifier.value = value;
    }
  }

  bool _onNotification(Notification n) {
    final ScrollMetrics? m = n is ScrollNotification
        ? n.metrics
        : n is ScrollMetricsNotification
            ? n.metrics
            : null;
    if (m == null || m.axis != Axis.vertical) return false;
    _set(_top, _strength(m.pixels - m.minScrollExtent, widget.topHeight));
    _set(_bottom, _strength(m.maxScrollExtent - m.pixels, widget.height));
    return false; // observe only
  }

  Shader _mask(Rect rect) {
    final t = _top.value;
    final b = _bottom.value;
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
      colors.add(
        Colors.black.withValues(alpha: 1 - b * (1 - _ease[last - i])),
      );
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
      child: Stack(
        fit: StackFit.expand,
        children: [
          ListenableBuilder(
            listenable: Listenable.merge([_top, _bottom]),
            child: widget.child,
            builder: (context, child) => ShaderMask(
              blendMode: BlendMode.dstIn,
              shaderCallback: _mask,
              child: child,
            ),
          ),
          _EdgeBlur(strength: _top, height: widget.topHeight, atTop: true),
          _EdgeBlur(strength: _bottom, height: widget.height, atTop: false),
        ],
      ),
    );
  }
}

class _EdgeBlur extends StatelessWidget {
  const _EdgeBlur({
    required this.strength,
    required this.height,
    required this.atTop,
  });

  final ValueListenable<double> strength;
  final double height;
  final bool atTop;

  // Per-layer sigma at full strength; layers compound toward the edge.
  static const List<double> _sigmas = [0.8, 1.2, 1.8, 2.6, 3.6];
  static const int _steps = 10;
  static const double _minSigma = 0.3;

  // [step][layer]; null = too weak to be worth a GPU pass.
  static final List<List<ImageFilter?>> _cache = List.generate(
    _steps + 1,
    (step) => [
      for (final s in _sigmas)
        s * step / _steps < _minSigma
            ? null
            : ImageFilter.blur(
                sigmaX: s * step / _steps,
                sigmaY: s * step / _steps,
              ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: strength,
      builder: (context, value, _) {
        final step = (value * _steps).round();
        if (step == 0) return const SizedBox.shrink();

        final filters = _cache[step];
        final bandHeight = height / _sigmas.length;

        return Align(
          alignment: atTop ? Alignment.topCenter : Alignment.bottomCenter,
          child: IgnorePointer(
            child: SizedBox(
              height: height,
              width: double.infinity,
              child: Stack(
                children: [
                  for (var i = 0; i < filters.length; i++)
                    if (filters[i] != null)
                      Positioned(
                        left: 0,
                        right: 0,
                        top: atTop ? 0 : null,
                        bottom: atTop ? null : 0,
                        height: bandHeight * (filters.length - i),
                        child: ClipRect(
                          child: BackdropFilter(
                            filter: filters[i]!,
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
