import 'package:flutter/material.dart';

import '../../../domain/models/listening_insights.dart';
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
                label: 'Library explored',
                value: _exploredLabel(),
                share: insights.exploredShare,
                accent: accent,
                icon: AppIcons.explore,
              ),
              const SizedBox(height: AppTokens.s5),
              ShareMeter(
                label: 'Plays that were favourites',
                value: StatsFormat.percent(insights.favoriteShare),
                share: insights.favoriteShare,
                accent: accent,
                icon: AppIcons.favorite,
              ),
              const SizedBox(height: AppTokens.s5),
              ShareMeter(
                label: 'Plays skipped',
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
                label: 'AVERAGE PLAY',
                value: StatsFormat.duration(insights.averagePlay),
              ),
              const SizedBox(height: AppTokens.s3),
              _Fact(
                label: 'ON AN ACTIVE DAY',
                value: StatsFormat.duration(insights.averageDay),
              ),
              const SizedBox(height: AppTokens.s3),
              _Fact(
                label: 'PLAYS PER ACTIVE DAY',
                value: '${insights.averagePlaysPerDay}',
              ),
              if (firstListen != null) ...[
                const SizedBox(height: AppTokens.s3),
                _Fact(label: 'FIRST LISTEN', value: firstListen!),
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Both counts, not just the percentage: "38%" of an unknown library size is
  /// a very different claim from "38%" of 4,000 tracks.
  String _exploredLabel() {
    final share = StatsFormat.percent(insights.exploredShare);
    if (insights.librarySize == 0) return share;
    return '$share of ${StatsFormat.compactCount(insights.librarySize)}';
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
