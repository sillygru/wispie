import 'package:flutter/material.dart';

import '../../../domain/models/listening_insights.dart';
import '../../../l10n/l10n.dart';
import '../../components/app_surface.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_tokens.dart';
import '../../utils/stats_format.dart';
import 'share_meter.dart';

/// Three ratios that characterise a listener rather than measure them: how much
/// of the library they have heard, how often they reach for a favourite, and
/// how quickly they skip.
///
/// Skips are the only figure here where less is better, so it fills in warning
/// instead of the accent — the one place on the screen where the colour
/// contradicts the bar next to it, which is exactly what makes it readable.
class TasteSection extends StatelessWidget {
  final ListeningInsights insights;
  final Color accent;

  const TasteSection({
    super.key,
    required this.insights,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSurface(
          clipContent: true,
          padding: const EdgeInsets.all(AppTokens.s5),
          child: Column(
            children: [
              ShareMeter(
                label: context.l10n.statsLibraryExplored,
                value: _exploredLabel(context.l10n),
                share: insights.exploredShare,
                accent: accent,
                icon: AppIcons.explore,
              ),
              const SizedBox(height: AppTokens.s5),
              ShareMeter(
                label: context.l10n.statsPlaysFavourites,
                value: StatsFormat.percent(insights.favoriteShare),
                share: insights.favoriteShare,
                accent: accent,
                icon: AppIcons.favorite,
              ),
              const SizedBox(height: AppTokens.s5),
              ShareMeter(
                label: context.l10n.statsPlaysSkipped,
                value: StatsFormat.percent(insights.skipRate),
                share: insights.skipRate,
                accent: accent,
                fill: AppTokens.warning,
                icon: AppIcons.skipNext,
              ),
            ],
          ),
        ),
        const SizedBox(height: AppTokens.s3),
        AppSurface(
          clipContent: true,
          padding: const EdgeInsets.symmetric(
            horizontal: AppTokens.s5,
            vertical: AppTokens.s4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _Fact(
                label: context.l10n.statsAvgPlay,
                value: StatsFormat.duration(
                  insights.averagePlay,
                  context.l10n,
                ),
              ),
              const SizedBox(height: AppTokens.s3),
              // The day's time and its plays belong on one line.
              _Fact(
                label: context.l10n.statsOnActiveDay,
                value: context.l10n.statsDayTotals(
                  StatsFormat.duration(
                    insights.averageDay,
                    context.l10n,
                  ),
                  context.l10n.statsPlaysCount(insights.averagePlaysPerDay),
                ),
              ),
              if (firstListen != null) ...[
                const SizedBox(height: AppTokens.s3),
                _Fact(
                  label: context.l10n.statsFirstListen,
                  value: firstListen!,
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Both counts, not just the percentage: "38%" of an unknown library size is
  /// a very different claim from "38%" of 4,000 tracks.
  String _exploredLabel(AppLocalizations l10n) {
    final share = StatsFormat.percent(insights.exploredShare);
    if (insights.librarySize == 0) return share;
    return l10n.statsShareOf(
      share,
      StatsFormat.compactCount(insights.librarySize),
    );
  }

  String? get firstListen => StatsFormat.firstListen(insights);
}

class _Fact extends StatelessWidget {
  final String label;
  final String value;

  const _Fact({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label, style: AppTokens.sectionLabel(context))),
        const SizedBox(width: AppTokens.s3),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.end,
            style: AppTokens.rowTitle(context),
          ),
        ),
      ],
    );
  }
}
