import 'dart:async';
import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Edge fade + progressive blur for scrolling panes.
/// The fade follows scroll position; the blur only shows once scrolling has
/// settled, so it costs no GPU while content is moving.
class ProgressiveBottomBlur extends StatefulWidget {
  const ProgressiveBottomBlur({
    super.key,
    required this.child,
    this.height = defaultHeight,
    this.topHeight = defaultTopHeight,
  });

  static const double defaultHeight = 96;
  static const double defaultTopHeight = 56;

  final Widget child;
  final double height;
  final double topHeight;

  @override
  State<ProgressiveBottomBlur> createState() => _ProgressiveBottomBlurState();
}

class _ProgressiveBottomBlurState extends State<ProgressiveBottomBlur>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<double> _top = ValueNotifier<double>(0);
  final ValueNotifier<double> _bottom = ValueNotifier<double>(0);

  /// 1 = blur visible (idle), 0 = hidden (scrolling).
  late final AnimationController _settle = AnimationController(
    vsync: this,
    value: 1,
    duration: const Duration(milliseconds: 220),
    reverseDuration: const Duration(milliseconds: 80),
  );
  Timer? _timer;

  static const List<double> _ease = [0.0, 0.156, 0.5, 0.844, 1.0];

  @override
  void dispose() {
    _timer?.cancel();
    _settle.dispose();
    _top.dispose();
    _bottom.dispose();
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

  bool _onNotification(Notification n) {
    final ScrollMetrics? m = n is ScrollNotification
        ? n.metrics
        : n is ScrollMetricsNotification
            ? n.metrics
            : null;
    if (m == null || m.axis != Axis.vertical) return false;

    if (n is ScrollStartNotification || n is ScrollUpdateNotification) {
      _timer?.cancel();
      _timer = null;
      if (_settle.value > 0 && _settle.status != AnimationStatus.reverse) {
        _settle.reverse();
      }
    } else if (n is ScrollEndNotification) {
      _timer?.cancel();
      _timer = Timer(const Duration(milliseconds: 160), () {
        if (mounted) _settle.forward();
      });
    }

    _set(_top, _strength(m.pixels - m.minScrollExtent, widget.topHeight));
    _set(_bottom, _strength(m.maxScrollExtent - m.pixels, widget.height));
    return false;
  }

  Shader _mask(Rect rect) {
    final t = _top.value, b = _bottom.value;
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
          _EdgeBlur(
              strength: _top,
              settle: _settle,
              height: widget.topHeight,
              atTop: true),
          _EdgeBlur(
              strength: _bottom,
              settle: _settle,
              height: widget.height,
              atTop: false),
        ],
      ),
    );
  }
}

class _EdgeBlur extends StatelessWidget {
  const _EdgeBlur({
    required this.strength,
    required this.settle,
    required this.height,
    required this.atTop,
  });

  final ValueListenable<double> strength;
  final Animation<double> settle;
  final double height;
  final bool atTop;

  static const List<double> _sigmas = [1.0, 2.2, 4.0];
  static const int _steps = 12;
  static final Map<int, List<ImageFilter?>> _cache = {};

  static List<ImageFilter?> _filters(int q) => _cache.putIfAbsent(q, () {
        final k = q / _steps;
        return [
          for (final s in _sigmas)
            s * k < 0.3 ? null : ImageFilter.blur(sigmaX: s * k, sigmaY: s * k),
        ];
      });

  @override
  Widget build(BuildContext context) {
    // No Opacity here: a BackdropFilter inside an Opacity layer blurs
    // nothing. The fade-in is done by ramping the sigma instead.
    return ListenableBuilder(
      listenable: Listenable.merge([strength, settle]),
      builder: (context, _) {
        final q = (strength.value * settle.value * _steps).round();
        if (q == 0) return const SizedBox.shrink();
        final filters = _filters(q);
        final band = height / _sigmas.length;
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
                        height: band * (filters.length - i),
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
