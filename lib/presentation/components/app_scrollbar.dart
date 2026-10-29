import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../tokens/app_tokens.dart';
import '../tokens/player_tokens.dart';

/// A thin pill at the trailing edge that fades in as a list moves and out once
/// it settles.
///
/// Installed for every vertical scrollable by `MotionScrollBehavior`, so no
/// screen has to remember it.
class AppScrollbar extends StatefulWidget {
  const AppScrollbar({super.key, required this.child});

  final Widget child;

  @override
  State<AppScrollbar> createState() => _AppScrollbarState();
}

class _AppScrollbarState extends State<AppScrollbar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: PlayerTokens.dScrollbarFadeIn,
  );

  /// Metrics are read from notifications, so a list without a controller still
  /// gets a bar. The count is what tells the painter to redraw.
  final ValueNotifier<int> _revision = ValueNotifier<int>(0);
  late final Listenable _repaint = Listenable.merge([_revision, _fade]);
  ScrollMetrics? _metrics;
  Timer? _idle;

  @override
  void dispose() {
    _idle?.cancel();
    _fade.dispose();
    _revision.dispose();
    super.dispose();
  }

  bool get _scrolls {
    final metrics = _metrics;
    return metrics != null &&
        metrics.hasContentDimensions &&
        metrics.hasPixels &&
        metrics.maxScrollExtent - metrics.minScrollExtent > 0.5;
  }

  void _show() {
    _idle?.cancel();
    if (!_scrolls || _fade.status == AnimationStatus.forward) return;
    if (_fade.value < 1) {
      _fade.animateTo(
        1,
        duration: PlayerTokens.dScrollbarFadeIn,
        curve: PlayerTokens.cStandard,
      );
    }
  }

  void _settle() {
    _idle?.cancel();
    if (_fade.value == 0) return;
    _idle = Timer(PlayerTokens.dScrollbarIdle, () {
      if (!mounted) return;
      _fade.animateTo(
        0,
        duration: PlayerTokens.dScrollbarFadeOut,
        curve: PlayerTokens.cStandard,
      );
    });
  }

  void _updateMetrics(ScrollMetrics metrics) {
    _metrics = metrics;
    // A metrics notification arrives during layout, where a repaint cannot be
    // requested.
    if (SchedulerBinding.instance.schedulerPhase ==
        SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) _revision.value++;
      });
      return;
    }
    _revision.value++;
  }

  bool _onNotification(Notification notification) {
    if (notification is ScrollMetricsNotification) {
      if (notification.depth == 0 &&
          notification.metrics.axis == Axis.vertical) {
        _updateMetrics(notification.metrics);
      }
      return false;
    }
    if (notification is! ScrollNotification ||
        notification.depth != 0 ||
        notification.metrics.axis != Axis.vertical) {
      return false;
    }
    _updateMetrics(notification.metrics);
    if (notification is ScrollEndNotification) {
      _settle();
    } else {
      _show();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return NotificationListener<Notification>(
      onNotification: _onNotification,
      child: Stack(
        fit: StackFit.passthrough,
        // Nothing here overflows, and a clip would cut the overscroll effect.
        clipBehavior: Clip.none,
        children: [
          widget.child,
          Positioned.fill(
            child: IgnorePointer(
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _ThumbPainter(
                    metricsOf: () => _metrics,
                    fade: _fade,
                    color: AppTokens.fgPrimary,
                    textDirection: Directionality.of(context),
                    repaint: _repaint,
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

class _ThumbPainter extends CustomPainter {
  _ThumbPainter({
    required this.metricsOf,
    required this.fade,
    required this.color,
    required this.textDirection,
    required Listenable repaint,
  }) : super(repaint: repaint);

  final ScrollMetrics? Function() metricsOf;
  final Animation<double> fade;
  final Color color;
  final TextDirection textDirection;
  final Paint _paint = Paint();

  @override
  void paint(Canvas canvas, Size size) {
    final double visibility = fade.value;
    final ScrollMetrics? metrics = metricsOf();
    if (visibility <= 0.001 || metrics == null) return;
    if (!metrics.hasContentDimensions || !metrics.hasPixels) return;

    final double extent = metrics.maxScrollExtent - metrics.minScrollExtent;
    final double viewport = metrics.viewportDimension;
    final double track = size.height - PlayerTokens.scrollbarTrackInset * 2;
    if (extent <= 0.5 || viewport <= 0 || track <= 0) return;

    final double share = viewport / (extent + viewport);
    final double length = math
        .max(PlayerTokens.scrollbarMinLength, track * share)
        .clamp(0.0, track)
        .toDouble();
    final double progress =
        ((metrics.pixels - metrics.minScrollExtent) / extent)
            .clamp(0.0, 1.0)
            .toDouble();
    final double top =
        PlayerTokens.scrollbarTrackInset + progress * (track - length);
    // It swells as it arrives, so the fade reads as weight, not a switch.
    final double width = PlayerTokens.scrollbarThicknessIdle +
        (PlayerTokens.scrollbarThickness -
                PlayerTokens.scrollbarThicknessIdle) *
            visibility;
    final double left = textDirection == TextDirection.rtl
        ? PlayerTokens.scrollbarInset
        : size.width - width - PlayerTokens.scrollbarInset;

    _paint.color = color.withValues(
      alpha: PlayerTokens.scrollbarMaxAlpha * visibility,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(left, top, width, length),
        Radius.circular(width / 2),
      ),
      _paint,
    );
  }

  // Metrics and fade drive repaints through `repaint:` above.
  @override
  bool shouldRepaint(_ThumbPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.textDirection != textDirection;
}
