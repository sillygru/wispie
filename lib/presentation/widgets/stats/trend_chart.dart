import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../domain/models/listening_insights.dart';
import '../../tokens/app_tokens.dart';

/// Listening time across the selected window, as a filled area with a line on
/// top.
///
/// An area rather than bars because the x-axis is continuous time: a 30-day
/// window of daily bars puts a 2px gap between every pair of days, which reads
/// as noise instead of a trend. The fill is a flat wash — the line carries the
/// shape, the wash only separates it from the surface behind.
///
/// Drag anywhere on the plot to inspect a point; the parent renders the exact
/// numbers from [TrendPoint].
class TrendChart extends StatelessWidget {
  final List<TrendPoint> points;
  final Color accent;
  final int? selectedIndex;
  final ValueChanged<int?> onSelect;

  /// Height of the plot, excluding the tick strip.
  final double height;

  const TrendChart({
    super.key,
    required this.points,
    required this.accent,
    required this.onSelect,
    this.selectedIndex,
    this.height = 180,
  });

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) return const SizedBox.shrink();

    final labelStyle = AppTokens.axisLabel(context);

    return SizedBox(
      height: height,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final plotHeight = height - _tickStrip;

          int? indexFor(double dx) {
            final step = width / (points.length - 1);
            final raw = (dx / step).round().clamp(0, points.length - 1);
            return raw;
          }

          void report(Offset position) {
            // Ignore touches that land in the tick strip — scrubbing there
            // would jump the selection without any intent to read a value.
            if (position.dy > plotHeight) return;
            onSelect(indexFor(position.dx));
          }

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => report(details.localPosition),
            onTapUp: (_) => onSelect(null),
            onTapCancel: () => onSelect(null),
            onHorizontalDragStart: (d) => report(d.localPosition),
            onHorizontalDragUpdate: (d) => report(d.localPosition),
            onHorizontalDragEnd: (_) => onSelect(null),
            onHorizontalDragCancel: () => onSelect(null),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(width, height),
                painter: _TrendPainter(
                  points: points,
                  selectedIndex: selectedIndex,
                  plotHeight: plotHeight,
                  accent: accent,
                  labelStyle: labelStyle,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  static const double _tickStrip = 20;
}

class _TrendPainter extends CustomPainter {
  final List<TrendPoint> points;
  final int? selectedIndex;
  final double plotHeight;
  final Color accent;
  final TextStyle labelStyle;

  _TrendPainter({
    required this.points,
    required this.selectedIndex,
    required this.plotHeight,
    required this.accent,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final seconds = [
      for (final point in points) point.listened.inMilliseconds / 1000,
    ];
    final maxValue = seconds.fold<double>(0, math.max);

    final stepX = size.width / (points.length - 1);

    // An all-zero window draws as a flat line on the baseline: still a chart,
    // and it makes "no listening here" legible instead of blank.
    double yFor(int index) {
      if (maxValue <= 0) return plotHeight;
      final ratio = seconds[index] / maxValue;
      // Reserve the top of the plot so the peak never touches the edge.
      return plotHeight - ratio * (plotHeight - AppTokens.chartPlotGap * 2);
    }

    final line = Path();
    for (var i = 0; i < points.length; i++) {
      final x = i * stepX;
      final y = yFor(i);
      if (i == 0) {
        line.moveTo(x, y);
      } else {
        line.lineTo(x, y);
      }
    }

    final fill = Path.from(line)
      ..lineTo(size.width, plotHeight)
      ..lineTo(0, plotHeight)
      ..close();
    canvas.drawPath(
      fill,
      Paint()
        ..color = accent.withValues(alpha: AppTokens.chartAreaAlpha)
        ..style = PaintingStyle.fill,
    );

    canvas.drawLine(
      Offset(0, plotHeight - 0.5),
      Offset(size.width, plotHeight - 0.5),
      Paint()
        ..color = AppTokens.fg(AppTokens.chartBaselineAlpha)
        ..strokeWidth = 1,
    );

    canvas.drawPath(
      line,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = AppTokens.chartStroke
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round,
    );

    if (selectedIndex != null && selectedIndex! >= 0) {
      _paintSelection(canvas, size, stepX, yFor);
    }

    _paintTicks(canvas, size, stepX);
  }

  void _paintSelection(
    Canvas canvas,
    Size size,
    double stepX,
    double Function(int) yFor,
  ) {
    final index = selectedIndex!;
    if (index >= points.length) return;
    final x = index * stepX;
    final y = yFor(index);

    canvas.drawLine(
      Offset(x, 0),
      Offset(x, plotHeight),
      Paint()
        ..color = AppTokens.fg(AppTokens.chartBaselineAlpha)
        ..strokeWidth = 1,
    );

    // A halo of the surface colour behind the dot, so the marker reads on top
    // of a dense area fill instead of merging into it.
    canvas.drawCircle(
      Offset(x, y),
      AppTokens.chartMarkerHalo,
      Paint()..color = AppTokens.wellFill,
    );
    canvas.drawCircle(
      Offset(x, y),
      AppTokens.chartMarkerRadius,
      Paint()..color = accent,
    );
  }

  void _paintTicks(Canvas canvas, Size size, double stepX) {
    // One tick per label the series carries, thinned to fit — plus the final
    // point always gets one so the right edge of the window is dated.
    final slot = AppTokens.s4 + AppTokens.s5;
    final stride = math.max(1, (size.width / slot).ceil());
    for (var i = 0; i < points.length; i++) {
      final isLast = i == points.length - 1;
      if (!isLast && i % stride != 0) continue;
      final painter = TextPainter(
        text: TextSpan(text: points[i].label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final centre = i * stepX;
      painter.paint(
        canvas,
        Offset(
          (centre - painter.width / 2)
              .clamp(0.0, math.max(0.0, size.width - painter.width)),
          plotHeight + AppTokens.s1,
        ),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrendPainter old) =>
      old.points != points ||
      old.selectedIndex != selectedIndex ||
      old.plotHeight != plotHeight ||
      old.accent != accent;
}
