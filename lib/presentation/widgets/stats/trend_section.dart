import 'package:flutter/material.dart';

import '../../../domain/models/listening_insights.dart';
import '../../components/app_surface.dart';
import '../../tokens/app_tokens.dart';
import '../../utils/stats_format.dart';
import 'trend_chart.dart';

/// Listening time across the window, with a readout that follows the finger.
///
/// The readout defaults to the best point in the series rather than to "today":
/// resting on the peak answers a question, while resting on the last day
/// answers one nobody asked.
class TrendSection extends StatefulWidget {
  final ListeningInsights insights;
  final Color accent;

  const TrendSection({
    super.key,
    required this.insights,
    required this.accent,
  });

  @override
  State<TrendSection> createState() => _TrendSectionState();
}

class _TrendSectionState extends State<TrendSection> {
  int? _selected;

  @override
  Widget build(BuildContext context) {
    final points = widget.insights.trend;
    final readout = _selected != null && _selected! < points.length
        ? points[_selected!]
        : widget.insights.peakTrendPoint ?? points.last;

    return AppSurface(
      clipContent: true,
      padding: const EdgeInsets.fromLTRB(
        AppTokens.s4,
        AppTokens.s5,
        AppTokens.s4,
        AppTokens.s3,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  readout.caption,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTokens.cardTitle(context),
                ),
              ),
              const SizedBox(width: AppTokens.s2),
              Text(
                StatsFormat.duration(readout.listened),
                style: AppTokens.rowSubtitle(context)
                    .copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: AppTokens.s1),
          Text(
            readout.plays == 1 ? '1 play' : '${readout.plays} plays',
            style: AppTokens.meta(context),
          ),
          const SizedBox(height: AppTokens.s3),
          TrendChart(
            points: points,
            accent: widget.accent,
            selectedIndex: _selected,
            onSelect: (index) => setState(() => _selected = index),
          ),
        ],
      ),
    );
  }
}
