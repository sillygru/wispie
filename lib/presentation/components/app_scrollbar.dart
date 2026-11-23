import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show PathMetric;

import 'package:flutter/gestures.dart' show DragStartBehavior;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../motion/motion_policy.dart';
import '../tokens/player_tokens.dart';

class AppScrollbar extends StatefulWidget {
  const AppScrollbar({
    super.key,
    required this.child,
    this.controller,
    this.displayCorners = BorderRadius.zero,
    this.cornerRadiusOverride,
  });

  final Widget child;
  final ScrollController? controller;
  final BorderRadius displayCorners;
  final double? cornerRadiusOverride;

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar>
    with TickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(vsync: this);
  late final AnimationController _edgePull = AnimationController(
    vsync: this,
    lowerBound: -1,
    value: 0,
  );
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  late final Listenable _repaint = Listenable.merge([
    _revision,
    _fade,
    _edgePull,
  ]);
  ScrollMetrics? _metrics;
  BuildContext? _scrollContext;
  _ThumbGeometry? _geometry;
  ({ScrollPosition position, double anchor})? _drag;
  double _rejectedPull = 0;
  Timer? _idle;
  MotionPolicy _motion = MotionPolicy.full;

  @override
  void dispose() {
    _idle?.cancel();
    _fade.dispose();
    _edgePull.dispose();
    _revision.dispose();
    super.dispose();
  }

  void _show(ScrollMetrics metrics) {
    _idle?.cancel();
    if (metrics.maxScrollExtent <= metrics.minScrollExtent ||
        _fade.status == AnimationStatus.forward ||
        _fade.value == 1) {
      return;
    }
    _fade.animateTo(
      1,
      duration: _motion.duration(PlayerTokens.dScrollbarFadeIn),
      curve: PlayerTokens.cStandard,
    );
  }

  void _settle() {
    _rejectedPull = 0;
    if (_edgePull.value != 0) {
      _edgePull.animateTo(
        0,
        duration: _motion.duration(PlayerTokens.dScrollbarRelease),
        curve: PlayerTokens.cStandard,
      );
    }
    _idle?.cancel();
    _idle = Timer(PlayerTokens.dScrollbarIdle, () {
      _fade.animateBack(
        0,
        duration: _motion.duration(PlayerTokens.dScrollbarFadeOut),
        curve: PlayerTokens.cStandard,
      );
    });
  }

  ScrollPosition? _currentPosition() {
    final positions = widget.controller?.positions;
    final source = _scrollContext;
    if (source != null && source.mounted) {
      final position = Scrollable.maybeOf(source)?.position;
      if (position != null &&
          (positions == null || positions.contains(position))) {
        return position;
      }
    }
    return positions?.length == 1 ? positions!.single : null;
  }

  void _grab(DragDownDetails details) {
    final position = _currentPosition();
    final geometry = _geometry;
    if (position == null ||
        !position.hasPixels ||
        !position.hasContentDimensions ||
        position.minScrollExtent >= position.maxScrollExtent ||
        geometry == null ||
        geometry.travel <= 0) {
      return;
    }
    final pixels = position.pixels
        .clamp(position.minScrollExtent, position.maxScrollExtent)
        .toDouble();
    final progress = (pixels - position.minScrollExtent) /
        (position.maxScrollExtent - position.minScrollExtent);
    final leading =
        position.axisDirection == AxisDirection.up ? 1 - progress : progress;
    setState(() {
      _drag = (
        position: position,
        anchor: geometry.distanceForY(details.localPosition.dy) -
            leading * geometry.travel,
      );
    });
    _idle?.cancel();
    _fade.value = 1;
    _edgePull.value = 0;
    position.jumpTo(pixels);
  }

  void _move(DragUpdateDetails details) {
    final drag = _drag;
    final geometry = _geometry;
    if (drag == null || geometry == null || geometry.travel <= 0) return;

    final position = drag.position;
    if (widget.controller?.positions.contains(position) == false) {
      _release();
      return;
    }

    final requested =
        geometry.distanceForY(details.localPosition.dy) - drag.anchor;
    final clamped = requested.clamp(0.0, geometry.travel);
    final progress = clamped / geometry.travel;
    final scrollProgress =
        position.axisDirection == AxisDirection.up ? 1 - progress : progress;
    final pixels = position.minScrollExtent +
        scrollProgress * (position.maxScrollExtent - position.minScrollExtent);
    if (position.pixels != pixels) position.jumpTo(pixels);
    final pull = requested - clamped;
    _edgePull.value =
        pull / (pull.abs() + PlayerTokens.scrollbarPullResistance);
  }

  void _release() {
    if (_drag == null) return;
    setState(() => _drag = null);
    _settle();
  }

  void _updateMetrics(ScrollMetrics metrics) {
    _metrics = metrics;
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revision.value++;
      });
    } else {
      _revision.value++;
    }
  }

  bool _onNotification(Notification notification) {
    if (notification is ScrollMetricsNotification) {
      if (notification.depth == 0 &&
          notification.metrics.axis == Axis.vertical) {
        _scrollContext = notification.context;
        _updateMetrics(notification.metrics);
      }
      return false;
    }
    if (notification is! ScrollNotification ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }

    _scrollContext = notification.context;
    final metrics = notification.metrics;
    _updateMetrics(metrics);
    if (_drag != null) return false;
    if (notification is ScrollEndNotification) {
      _settle();
    } else if (notification is ScrollUpdateNotification ||
        notification is OverscrollNotification ||
        notification is ScrollStartNotification) {
      // Bouncing physics move past the extent, while clamping reports the
      // rejected part of the gesture separately.
      _rejectedPull = notification is OverscrollNotification
          ? _rejectedPull + notification.overscroll
          : 0;
      final beyondExtent = metrics.pixels -
          metrics.pixels
              .clamp(metrics.minScrollExtent, metrics.maxScrollExtent);
      final pull = beyondExtent + _rejectedPull;
      _edgePull.value =
          pull / (pull.abs() + PlayerTokens.scrollbarPullResistance);
      _show(metrics);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    _motion = MotionPolicy.of(context);
    final view = View.of(context);
    final colors = Theme.of(context).colorScheme;
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: Stack(
        fit: StackFit.passthrough,
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned.fill(
            child: MouseRegion(
              opaque: false,
              hitTestBehavior: HitTestBehavior.deferToChild,
              cursor: _drag == null
                  ? SystemMouseCursors.grab
                  : SystemMouseCursors.grabbing,
              child: GestureDetector(
                behavior: HitTestBehavior.deferToChild,
                excludeFromSemantics: true,
                dragStartBehavior: DragStartBehavior.down,
                onPanDown: _grab,
                onPanUpdate: _move,
                onPanEnd: (_) => _release(),
                onPanCancel: _release,
                child: RepaintBoundary(
                  child: CustomPaint(
                    painter: _ThumbPainter(
                      state: this,
                      color: colors.onSurface,
                      activeColor: colors.primary,
                      held: _drag != null,
                      rtl: Directionality.of(context) == TextDirection.rtl,
                      displayCorners: widget.displayCorners,
                      cornerRadiusOverride: widget.cornerRadiusOverride,
                      viewSize: view.physicalSize / view.devicePixelRatio,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paint and pointer input use the same distance along the curved track.
class _ThumbGeometry {
  const _ThumbGeometry({
    required this.track,
    required this.start,
    required this.length,
    required this.travel,
    required this.hitBounds,
    required this.mirrorWidth,
  });

  final PathMetric track;
  final double start;
  final double length;
  final double travel;
  final Rect hitBounds;
  final double? mirrorWidth;

  double distanceForY(double y) {
    final top = track.getTangentForOffset(0)!.position.dy;
    final bottom = track.getTangentForOffset(track.length)!.position.dy;
    if (y <= top) return y - top;
    if (y >= bottom) return track.length + y - bottom;

    var low = 0.0;
    var high = track.length;
    while (high - low > 0.25) {
      final middle = (low + high) / 2;
      final position = track.getTangentForOffset(middle)!.position;
      if (position.dy < y) {
        low = middle;
      } else {
        high = middle;
      }
    }
    return (low + high) / 2;
  }

  bool hits(Offset offset) {
    final width = mirrorWidth;
    final point = width == null ? offset : Offset(width - offset.dx, offset.dy);
    if (!hitBounds.contains(point)) return false;
    final along = distanceForY(point.dy).clamp(start, start + length);
    final center = track.getTangentForOffset(along)!.position;
    return (center - point).distanceSquared <=
        PlayerTokens.scrollbarHitRadius * PlayerTokens.scrollbarHitRadius;
  }
}

class _ThumbPainter extends CustomPainter {
  _ThumbPainter({
    required this.state,
    required this.color,
    required this.activeColor,
    required this.held,
    required this.rtl,
    required this.displayCorners,
    required this.cornerRadiusOverride,
    required this.viewSize,
  }) : super(repaint: state._repaint);

  final _AppScrollbarState state;
  final Color color;
  final Color activeColor;
  final bool held;
  final bool rtl;
  final BorderRadius displayCorners;
  final double? cornerRadiusOverride;
  final Size viewSize;
  final Paint _paint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;

  @override
  bool hitTest(Offset position) => state._geometry?.hits(position) ?? false;

  @override
  void paint(Canvas canvas, Size size) {
    state._geometry = null;
    final visibility = state._fade.value;
    final metrics = state._metrics;
    if (visibility <= 0.001 || metrics == null) return;
    final extent = metrics.maxScrollExtent - metrics.minScrollExtent;
    final viewport = metrics.viewportDimension;
    final top = PlayerTokens.scrollbarTrackInset;
    final bottom = size.height - top;
    if (extent <= 0 ||
        !extent.isFinite ||
        viewport <= 0 ||
        bottom <= top ||
        size.width <=
            PlayerTokens.scrollbarInset + PlayerTokens.scrollbarHeldThickness) {
      return;
    }

    final reversed = metrics.axisDirection == AxisDirection.up;
    final progress =
        ((metrics.pixels - metrics.minScrollExtent) / extent).clamp(0.0, 1.0);
    final pull = state._edgePull.value;
    final width = held
        ? PlayerTokens.scrollbarHeldThickness
        : PlayerTokens.scrollbarThicknessIdle +
            (PlayerTokens.scrollbarThickness -
                    PlayerTokens.scrollbarThicknessIdle) *
                visibility;
    final x = size.width -
        PlayerTokens.scrollbarInset -
        PlayerTokens.scrollbarHeldThickness / 2;

    final track = _track(size, x, top, bottom).computeMetrics().first;
    final restingLength = math
        .max(PlayerTokens.scrollbarMinLength,
            track.length * viewport / (extent + viewport))
        .clamp(0.0, track.length);
    final length =
        restingLength * (1 - PlayerTokens.scrollbarMaxContraction * pull.abs());
    final start =
        (reversed ? 1 - progress : progress) * (track.length - length);
    final thumb = track.extractPath(start, start + length);
    if (visibility >= PlayerTokens.scrollbarHitVisibility &&
        restingLength < track.length) {
      state._geometry = _ThumbGeometry(
        track: track,
        start: start,
        length: length,
        travel: track.length - restingLength,
        hitBounds: thumb.getBounds().inflate(PlayerTokens.scrollbarHitRadius),
        mirrorWidth: rtl ? size.width : null,
      );
    }

    final fill = held ? activeColor : color;
    _paint
      ..strokeWidth = width
      ..color = fill.withValues(
        alpha: held ? visibility : PlayerTokens.scrollbarMaxAlpha * visibility,
      );
    canvas.save();
    if (rtl) {
      canvas.translate(size.width, 0);
      canvas.scale(-1, 1);
    }
    canvas.drawPath(thumb, _paint);
    canvas.restore();
  }

  Path _track(Size size, double x, double top, double bottom) {
    final override = cornerRadiusOverride;
    final path = Path();
    double sideGap = 0;
    double topGap = 0;
    double bottomGap = 0;
    double topRadius = override ??
        (rtl ? displayCorners.topLeft.x : displayCorners.topRight.x);
    double bottomRadius = override ??
        (rtl ? displayCorners.bottomLeft.x : displayCorners.bottomRight.x);
    if (override == null && (topRadius > 0 || bottomRadius > 0)) {
      final box = state.context.findRenderObject() as RenderBox;
      final origin = box.localToGlobal(Offset.zero);
      sideGap = rtl ? origin.dx : viewSize.width - origin.dx - size.width;
      if (sideGap.abs() <= PlayerTokens.scrollbarEdgeTolerance) {
        topGap = origin.dy;
        bottomGap = viewSize.height - origin.dy - size.height;
      } else {
        topRadius = bottomRadius = 0;
      }
    }

    final inset = size.width - x + sideGap;
    final maxRadius = math.max(0.0, math.min(x, (bottom - top) / 2));
    final upperArc = (topRadius - inset).clamp(0.0, maxRadius);
    final lowerArc = (bottomRadius - inset).clamp(0.0, maxRadius);
    final midpoint = (top + bottom) / 2;
    final upperCenter = (topRadius - topGap).clamp(top, midpoint);
    final lowerCenter =
        (size.height - bottomRadius + bottomGap).clamp(midpoint, bottom);
    if (upperArc > 0 && upperCenter > top) {
      final sweep = math.asin(math.min(1.0, (upperCenter - top) / upperArc));
      path.arcTo(
        Rect.fromCircle(
            center: Offset(x - upperArc, upperCenter), radius: upperArc),
        -sweep,
        sweep,
        true,
      );
    } else {
      path.moveTo(x, top);
    }

    if (lowerArc > 0 && lowerCenter < bottom) {
      final sweep = math.asin(math.min(1.0, (bottom - lowerCenter) / lowerArc));
      path.arcTo(
        Rect.fromCircle(
            center: Offset(x - lowerArc, lowerCenter), radius: lowerArc),
        0,
        sweep,
        false,
      );
    } else {
      path.lineTo(x, bottom);
    }
    return path;
  }

  @override
  bool shouldRepaint(_ThumbPainter oldDelegate) =>
      oldDelegate.color != color ||
      oldDelegate.activeColor != activeColor ||
      oldDelegate.held != held ||
      oldDelegate.rtl != rtl ||
      oldDelegate.displayCorners != displayCorners ||
      oldDelegate.cornerRadiusOverride != cornerRadiusOverride ||
      oldDelegate.viewSize != viewSize;
}
