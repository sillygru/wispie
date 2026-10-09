import 'package:flutter/material.dart';

import '../../../domain/models/listening_insights.dart';
import '../../components/app_surface.dart';
import '../../tokens/app_tokens.dart';
import '../../utils/stats_format.dart';
import 'bar_series_chart.dart';

/// When listening happens: by hour of the day and by day of the week.
///
/// Both charts encode time heard rather than play counts. A play is a weak
/// unit here — one skipped tap and one finished album would weigh the same —
/// whereas minutes is what the listener actually spent.
class RhythmSection extends StatefulWidget {
  final ListeningInsights insights;
  final Color accent;

  const RhythmSection({
    super.key,
    required this.insights,
    required this.accent,
  });

  @override
  State<RhythmSection> createState() => _RhythmSectionState();
}

class _RhythmSectionState extends State<RhythmSection> {
  int? _hour;
  int? _weekday;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _HistogramCard(
          title: 'BY HOUR',
          readout: _hourReadout(),
          chart: BarSeriesChart(
            values: [
              for (final bucket in widget.insights.byHour)
                bucket.listened.inMilliseconds.toDouble(),
            ],
            labels: [
              for (var hour = 0; hour < 24; hour++)
                hour % 6 == 0 ? StatsFormat.hourTick(hour) : '',
            ],
            peakIndex: widget.insights.peakHour,
            selectedIndex: _hour,
            accent: widget.accent,
            onSelect: (index) => setState(() => _hour = index),
          ),
        ),
        const SizedBox(height: AppTokens.s3),
        _HistogramCard(
          title: 'BY WEEKDAY',
          readout: _weekdayReadout(),
          chart: BarSeriesChart(
            values: [
              for (final bucket in widget.insights.byWeekday)
                bucket.listened.inMilliseconds.toDouble(),
            ],
            labels: const ['M', 'T', 'W', 'T', 'F', 'S', 'S'],
            peakIndex: widget.insights.peakWeekday,
            selectedIndex: _weekday,
            accent: widget.accent,
            height: 96,
            onSelect: (index) => setState(() => _weekday = index),
          ),
        ),
      ],
    );
  }

  /// Falls back to the busiest hour when nothing is selected, so the card
  /// always says something.
  String _hourReadout() {
    final buckets = widget.insights.byHour;
    final index = _hour ?? widget.insights.peakHour;
    if (index == null || index >= buckets.length) {
      return 'No listening recorded';
    }
    final bucket = buckets[index];
    return '${StatsFormat.hour(index)} · '
        '${StatsFormat.hoursMinutes(bucket.listened)} across ${bucket.plays} plays';
  }

  String _weekdayReadout() {
    final buckets = widget.insights.byWeekday;
    final index = _weekday ?? widget.insights.peakWeekday;
    if (index == null || index >= buckets.length) {
      return 'No listening recorded';
    }
    final bucket = buckets[index];
    return '${StatsFormat.weekday(index)} · '
        '${StatsFormat.hoursMinutes(bucket.listened)} across ${bucket.plays} plays';
  }
}

class _HistogramCard extends StatelessWidget {
  final String title;
  final String readout;
  final Widget chart;

  const _HistogramCard({
    required this.title,
    required this.readout,
    required this.chart,
  });

  @override
  Widget build(BuildContext context) {
    return AppSurface(
      clipContent: true,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s4,
        AppTokens.s4,
        AppTokens.s4,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(title, style: AppTokens.sectionLabel(context)),
              const Spacer(),
              Flexible(
                child: Text(
                  readout,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                  style: AppTokens.meta(context),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s3),
          chart,
        ],
      ),
    );
  }
}
