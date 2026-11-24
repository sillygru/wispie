import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';

import '../../l10n/l10n.dart';
import '../motion/motion_haptics.dart';
import '../motion/motion_physics.dart';
import '../motion/motion_policy.dart';
import '../motion/motion_springs.dart';
import '../motion/motion_tokens.dart';
import '../tokens/app_tokens.dart';

enum _Phase { pull, refresh, retract }

/// Pushes the page down to reveal a refresh panel at its leading edge.
///
/// Use the builder's physics on the page's primary vertical scrollable.
class AppPullToRefresh extends StatefulWidget {
  const AppPullToRefresh({
    super.key,
    required this.onRefresh,
    required this.builder,
  });

  final RefreshCallback onRefresh;
  final Widget Function(ScrollPhysics physics) builder;

  @override
  State<AppPullToRefresh> createState() => _AppPullToRefreshState();
}

class _AppPullToRefreshState extends State<AppPullToRefresh>
    with TickerProviderStateMixin {
  late final AnimationController _pull = AnimationController(
    vsync: this,
    upperBound: 1 + AppTokens.refreshOvershoot,
  );
  late final AnimationController _wave = AnimationController(
    vsync: this,
    duration: MotionTokens.linger,
  );
  late final _RefreshScrollPhysics _physics = _RefreshScrollPhysics(
    consumeLeadingDrag: _consumeLeadingDrag,
    parent: const AlwaysScrollableScrollPhysics(),
  );
  _Phase _phase = _Phase.pull;
  bool _tracking = false;
  double _progress = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateWave(MotionPolicy.of(context));
  }

  @override
  void dispose() {
    _wave.dispose();
    _pull.dispose();
    super.dispose();
  }

  void _updateWave(MotionPolicy motion) {
    if (_phase == _Phase.refresh && motion.animates) {
      if (!_wave.isAnimating) _wave.repeat();
    } else {
      _wave.reset();
    }
  }

  void _settle(double target, MotionPolicy motion) {
    if (motion.animates) {
      _pull.animateWith(
        ScrollSpringSimulation(
          target == 0 ? MotionSprings.settle : MotionSprings.elastic,
          _pull.value,
          target,
          _pull.velocity,
          tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
        ),
      );
    } else {
      _pull.value = target;
    }
  }

  void _trackProgress(double progress) {
    final wasArmed = _progress >= 1;
    _progress = math.max(0, progress);
    if (!wasArmed && progress >= 1) MotionHaptics.selection();

    // Past the release point, the same extra pull buys less travel.
    final excess = math.max(0.0, _progress - 1) * AppTokens.refreshOverpull;
    final room = AppTokens.refreshOvershoot;
    _pull.value = math.min(_progress, 1) + room * excess / (room + excess);
  }

  void _endPull() {
    _tracking = false;
    if (_progress >= 1) {
      unawaited(_refresh());
    } else {
      _settle(0, MotionPolicy.read(context));
    }
  }

  bool _onScroll(ScrollNotification notification) {
    if (notification.depth != 0 ||
        notification.metrics.axisDirection != AxisDirection.down ||
        _phase == _Phase.refresh) {
      return false;
    }

    switch (notification) {
      case ScrollStartNotification(
            :final dragDetails,
            metrics: final metrics,
          )
          when dragDetails != null && metrics.extentBefore == 0:
        _tracking = true;
        // A new pull can catch the surface on its way back.
        _progress = _pull.value < 1 ? _pull.value : 0;
        if (_progress > 0) _pull.stop();
        if (_phase != _Phase.pull) setState(() => _phase = _Phase.pull);
      case ScrollUpdateNotification(dragDetails: null) when _tracking:
        _endPull();
      case ScrollEndNotification() when _tracking:
        _endPull();
      default:
        break;
    }
    return false;
  }

  double _consumeLeadingDrag(double delta) {
    if (!_tracking) return delta;
    final distance = _progress * AppTokens.refreshTrigger + delta;
    _trackProgress(distance / AppTokens.refreshTrigger);
    return math.min(0, distance);
  }

  Future<void> _refresh() async {
    if (_phase == _Phase.refresh) return;
    _tracking = false;
    final motion = MotionPolicy.read(context);
    setState(() => _phase = _Phase.refresh);
    _settle(1, motion);
    _updateWave(motion);

    try {
      await Future.wait([
        Future<void>.sync(widget.onRefresh),
        if (motion.animates) Future<void>.delayed(MotionTokens.base),
      ]);
    } finally {
      if (mounted) {
        final motion = MotionPolicy.read(context);
        setState(() => _phase = _Phase.retract);
        _updateWave(motion);
        _settle(0, motion);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      customSemanticsActions: {
        if (_phase != _Phase.refresh)
          CustomSemanticsAction(label: l10n.actionRefresh): () =>
              unawaited(_refresh()),
      },
      child: Listener(
        onPointerCancel: (_) {
          if (!_tracking) return;
          _tracking = false;
          _settle(0, MotionPolicy.read(context));
        },
        child: NotificationListener<ScrollNotification>(
          onNotification: _onScroll,
          child: AnimatedBuilder(
            animation: _pull,
            child: NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (notification) {
                if (notification.depth == 0 && notification.leading) {
                  notification.disallowIndicator();
                }
                return false;
              },
              child: RepaintBoundary(child: widget.builder(_physics)),
            ),
            builder: (context, page) {
              final progress = _pull.value;
              final extent = AppTokens.refreshRestExtent * progress;
              final radius = AppTokens.rLg * progress.clamp(0.0, 1.0);
              return ClipRect(
                child: Stack(
                  fit: StackFit.passthrough,
                  children: [
                    if (extent > 0)
                      Positioned(
                        top: 0,
                        left: 0,
                        right: 0,
                        height: extent + radius,
                        child: IgnorePointer(
                          child: ClipPath(
                            clipper: _RefreshRevealClipper(extent, radius),
                            child: _RefreshPanel(
                              extent: extent,
                              progress: progress,
                              phase: _phase,
                              wave: _wave,
                            ),
                          ),
                        ),
                      ),
                    Transform.translate(
                      offset: Offset(0, extent),
                      child: ClipRRect(
                        clipBehavior: extent > 0 ? Clip.antiAlias : Clip.none,
                        borderRadius: BorderRadius.vertical(
                          top: Radius.circular(radius),
                        ),
                        child: page,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _RefreshScrollPhysics extends MotionScrollPhysics {
  const _RefreshScrollPhysics({
    required this.consumeLeadingDrag,
    super.parent,
  });

  final double Function(double delta) consumeLeadingDrag;

  @override
  _RefreshScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      _RefreshScrollPhysics(
        consumeLeadingDrag: consumeLeadingDrag,
        parent: buildParent(ancestor),
      );

  @override
  double applyPhysicsToUserOffset(ScrollMetrics position, double offset) {
    if (position.pixels == position.minScrollExtent) {
      // Give the revealed panel the return drag before scrolling the list.
      offset = consumeLeadingDrag(offset);
    }
    return offset == 0 ? 0 : super.applyPhysicsToUserOffset(position, offset);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    if (value < position.minScrollExtent && value < position.pixels) {
      return value - math.min(position.pixels, position.minScrollExtent);
    }
    return super.applyBoundaryConditions(position, value);
  }
}

class _RefreshPanel extends StatelessWidget {
  const _RefreshPanel({
    required this.extent,
    required this.progress,
    required this.phase,
    required this.wave,
  });

  final double extent;
  final double progress;
  final _Phase phase;
  final Animation<double> wave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final surface = Color.alphaBlend(
      AppTokens.surface(1),
      theme.scaffoldBackgroundColor,
    );
    final armed = progress >= 1;
    final loading = phase != _Phase.pull;
    final label = loading
        ? l10n.refreshLoading
        : armed
            ? l10n.refreshRelease
            : l10n.refreshPull;

    return ColoredBox(
      color: surface,
      child: Stack(
        children: [
          Positioned(
            // Match the sidebar's half-speed reveal while the page moves away.
            top: (extent - AppTokens.refreshRestExtent) / 2,
            left: AppTokens.s4,
            right: AppTokens.s4,
            height: AppTokens.refreshRestExtent,
            child: Semantics(
              hidden: extent < AppTokens.s6,
              liveRegion: armed || loading,
              label: label,
              excludeSemantics: true,
              child: Opacity(
                opacity: ((extent - AppTokens.s6) / AppTokens.s5).clamp(0, 1),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    RepaintBoundary(
                      child: CustomPaint(
                        size: const Size(
                          AppTokens.refreshWaveWidth,
                          AppTokens.s6,
                        ),
                        painter: _RefreshWave(
                          accent: colors.primary,
                          track: colors.onSurface.withValues(
                            alpha: AppTokens.refreshTrackAlpha,
                          ),
                          progress: progress.clamp(0, 1),
                          loading: phase == _Phase.refresh,
                          wave: wave,
                        ),
                      ),
                    ),
                    const SizedBox(height: AppTokens.s2),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.meta(context).copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RefreshRevealClipper extends CustomClipper<Path> {
  const _RefreshRevealClipper(this.extent, this.radius);

  final double extent;
  final double radius;

  @override
  Path getClip(Size size) => Path()
    ..lineTo(size.width, 0)
    ..lineTo(size.width, extent + radius)
    ..arcToPoint(
      Offset(size.width - radius, extent),
      radius: Radius.circular(radius),
      clockwise: false,
    )
    ..lineTo(radius, extent)
    ..arcToPoint(
      Offset(0, extent + radius),
      radius: Radius.circular(radius),
      clockwise: false,
    )
    ..close();

  @override
  bool shouldReclip(_RefreshRevealClipper oldClipper) =>
      extent != oldClipper.extent || radius != oldClipper.radius;
}

class _RefreshWave extends CustomPainter {
  _RefreshWave({
    required this.accent,
    required this.track,
    required this.progress,
    required this.loading,
    required this.wave,
  }) : super(repaint: wave);

  static const _levels = [0.30, 0.54, 0.72, 1.0, 0.76, 0.50, 0.34];
  final Color accent;
  final Color track;
  final double progress;
  final bool loading;
  final Animation<double> wave;

  @override
  void paint(Canvas canvas, Size size) {
    final trackPaint = Paint()..color = track;
    final accentPaint = Paint()..color = accent;
    final step = size.width / _levels.length;
    final barWidth = step / 2;
    final radius = Radius.circular(barWidth / 2);
    for (var index = 0; index < _levels.length; index++) {
      final height = size.height * _levels[index];
      final bar = Rect.fromCenter(
        center: Offset(step * (index + 0.5), size.height / 2),
        width: barWidth,
        height: height,
      );
      if (!loading) {
        canvas.drawRRect(RRect.fromRectAndRadius(bar, radius), trackPaint);
      }

      final fill = loading
          ? 0.74 + 0.26 * math.sin(math.pi * (2 * wave.value - index / 3))
          : (progress * _levels.length - index).clamp(0.0, 1.0);
      if (fill == 0) continue;
      final filledBar = loading
          ? Rect.fromCenter(
              center: bar.center,
              width: bar.width,
              height: bar.height * fill,
            )
          : Rect.fromLTRB(
              bar.left,
              bar.bottom - bar.height * fill,
              bar.right,
              bar.bottom,
            );
      canvas.drawRRect(RRect.fromRectAndRadius(filledBar, radius), accentPaint);
    }
  }

  @override
  bool shouldRepaint(_RefreshWave oldDelegate) =>
      accent != oldDelegate.accent ||
      track != oldDelegate.track ||
      progress != oldDelegate.progress ||
      loading != oldDelegate.loading ||
      wave != oldDelegate.wave;
}
