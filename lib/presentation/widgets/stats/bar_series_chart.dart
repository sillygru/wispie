import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../tokens/app_tokens.dart';

/// A column chart with a scrubbable selection.
///
/// One painter serves both histograms on the stats screen — 24 hours and 7
/// weekdays are the same picture at a different density, so a second painter
/// would only be a second set of numbers to keep in sync.
///
/// Solid fills throughout: the accent carries the bars that matter (the peak,
/// and whatever is being inspected), a flat tonal carries the rest. Colour is
/// used to say "look here", not to decorate.
class BarSeriesChart extends StatelessWidget {
  /// One value per column, in axis order.
  final List<double> values;

  /// Optional label per column. An empty string draws no tick, which is how the
  /// 24-hour axis stays readable at phone width.
  final List<String> labels;

  /// The tallest column — always drawn in the accent.
  final int? peakIndex;

  /// The column under the finger, if any.
  final int? selectedIndex;

  /// Fires with the column that was touched, or null when the touch landed
  /// outside the columns.
  final ValueChanged<int?> onSelect;

  final Color accent;

  /// Height of the plot area, excluding the label strip.
  final double height;

  const BarSeriesChart({
    super.key,
    required this.values,
    required this.onSelect,
    required this.accent,
    this.labels = const [],
    this.peakIndex,
    this.selectedIndex,
    this.height = 120,
  });

  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);

    final labelStyle = AppTokens.axisLabel(context);
    final hasLabels = labels.isNotEmpty && labels.any((l) => l.isNotEmpty);

    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final plotHeight = hasLabels ? height - _labelStrip : height;
        final count = values.length;

        int? indexFor(double dx) {
          final step = totalWidth / count;
          final index = (dx / step).floor();
          if (index < 0 || index >= count) return null;
          return index;
        }

        void report(Offset position) => onSelect(indexFor(position.dx));

        return SizedBox(
          height: height,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTapDown: (details) => report(details.localPosition),
            onTapUp: (_) => onSelect(null),
            onTapCancel: () => onSelect(null),
            onHorizontalDragStart: (details) => report(details.localPosition),
            onHorizontalDragUpdate: (details) => report(details.localPosition),
            onHorizontalDragEnd: (_) => onSelect(null),
            onHorizontalDragCancel: () => onSelect(null),
            child: RepaintBoundary(
              child: CustomPaint(
                size: Size(totalWidth, height),
                painter: _BarSeriesPainter(
                  values: values,
                  labels: labels,
                  peakIndex: peakIndex,
                  selectedIndex: selectedIndex,
                  plotHeight: plotHeight,
                  accent: accent,
                  restingColor: AppTokens.surface(2),
                  labelStyle: labelStyle,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  static const double _labelStrip = 18;
}

class _BarSeriesPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final int? peakIndex;
  final int? selectedIndex;
  final double plotHeight;
  final Color accent;
  final Color restingColor;
  final TextStyle labelStyle;

  _BarSeriesPainter({
    required this.values,
    required this.labels,
    required this.peakIndex,
    required this.selectedIndex,
    required this.plotHeight,
    required this.accent,
    required this.restingColor,
    required this.labelStyle,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final count = values.length;
    if (count == 0) return;

    final gap = AppTokens.chartPlotGap;
    final step = size.width / count;
    final barWidth = math.max(1.0, step - gap);
    final radius = Radius.circular(math.min(AppTokens.rSm, barWidth / 2));
    final maxValue = values.fold<double>(0, math.max);
    // A column with a value but no height would read as "no data"; floor it at
    // a hairline so a two-minute day is still visible against a 6-hour peak.
    const minBarHeight = 2.0;

    // Baseline: the only rule a chart needs. A grid would be furniture.
    final baseline = Paint()
      ..color = AppTokens.fg(AppTokens.chartBaselineAlpha)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, plotHeight - 0.5),
      Offset(size.width, plotHeight - 0.5),
      baseline,
    );

    final bars = Paint()..style = PaintingStyle.fill;
    for (var i = 0; i < count; i++) {
      final isActive = i == peakIndex || i == selectedIndex;
      final value = values[i];
      final barHeight = maxValue <= 0
          ? 0.0
          : math.max(
              minBarHeight,
              value / maxValue * (plotHeight - minBarHeight),
            );
      if (barHeight <= 0) continue;

      bars.color = isActive ? accent : restingColor;
      final left = i * step + gap / 2;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, plotHeight - barHeight, barWidth, barHeight),
          radius,
        ),
        bars,
      );
    }

    if (labels.isEmpty) return;

    // One label per column, thinned so ticks never collide: at ~40px of
    // breathing room each, a 24-hour axis keeps every sixth hour.
    final stride = math.max(1, (size.width / _labelSlot).ceil());
    for (var i = 0; i < labels.length && i < count; i++) {
      final label = labels[i];
      if (label.isEmpty || i % stride != 0) continue;
      final painter = TextPainter(
        text: TextSpan(text: label, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final centre = i * step + step / 2;
      painter.paint(
        canvas,
        Offset(
          (centre - painter.width / 2).clamp(0.0, size.width - painter.width),
          plotHeight + AppTokens.chartPlotGap,
        ),
      );
    }
  }

  static const double _labelSlot = 40;

  @override
  bool shouldRepaint(covariant _BarSeriesPainter old) =>
      old.values != values ||
      old.labels != labels ||
      old.peakIndex != peakIndex ||
      old.selectedIndex != selectedIndex ||
      old.plotHeight != plotHeight ||
      old.accent != accent;
}
