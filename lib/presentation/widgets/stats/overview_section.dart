import 'package:flutter/material.dart';

import '../../../domain/models/listening_insights.dart';
import '../../../l10n/l10n.dart';
import '../../components/app_surface.dart';
import '../../tokens/app_tokens.dart';
import '../../utils/stats_format.dart';
import 'share_meter.dart';

/// The headline block: how long, how often, and whether that is going up.
///
/// One hero number and four supporting metrics. The hero is the only thing on
/// the screen at [AppTokens.display] size, so it is unambiguous which figure
/// the screen is about.
class OverviewSection extends StatelessWidget {
  final ListeningInsights insights;
  final Color accent;

  const OverviewSection({
    super.key,
    required this.insights,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final change = insights.listenedTrend.change;
    final percent = StatsFormat.signedPercent(change, l10n);

    return AppSurface(
      clipContent: true,
      padding: const EdgeInsets.all(AppTokens.s5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.statsTimeListened,
                  style: AppTokens.sectionLabel(context),
                ),
              ),
              if (percent != null)
                TrendBadge(
                  text: percent,
                  accent: accent,
                  rising: (change ?? 0) >= 0,
                  flat: change == 0,
                ),
            ],
          ),
          const SizedBox(height: AppTokens.s2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              StatsFormat.duration(insights.listened, l10n),
              style: AppTokens.display(context),
            ),
          ),
          const SizedBox(height: AppTokens.s1),
          Text(
            l10n.statsRangeWithDays(insights.range.title, insights.activeDays),
            style: AppTokens.rowSubtitle(context),
          ),
          const SizedBox(height: AppTokens.s5),
          Row(
            children: [
              Expanded(
                child: _Metric(
                  label: l10n.statsPlays,
                  value: StatsFormat.compactCount(insights.plays),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: l10n.statsSkips,
                  value: StatsFormat.compactCount(insights.skips),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: l10n.statsTracks,
                  value: StatsFormat.compactCount(insights.uniqueSongs),
                ),
              ),
              Expanded(
                child: _Metric(
                  label: l10n.statsStreak,
                  value: '${insights.currentStreak}',
                  caption: l10n.statsStreakBest(insights.longestStreak),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A value with its label, and an optional caption for the qualifier that
/// would otherwise need a footnote ("best 14" under a streak count).
class _Metric extends StatelessWidget {
  final String label;
  final String value;
  final String? caption;

  const _Metric({
    required this.label,
    required this.value,
    this.caption,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTokens.stat(context),
        ),
        const SizedBox(height: 2),
        Text(label, style: AppTokens.sectionLabel(context)),
        if (caption != null) ...[
          const SizedBox(height: 2),
          Text(
            caption!,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTokens.meta(context),
          ),
        ],
      ],
    );
  }
}
