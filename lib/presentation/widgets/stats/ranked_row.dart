import 'package:flutter/material.dart';

import '../../../domain/models/listening_insights.dart';
import '../../components/app_list_row.dart';
import '../../components/pressable.dart';
import '../../tokens/app_tokens.dart';
import '../../utils/stats_format.dart';

/// A row in a "top artists / albums / songs" list.
///
/// The bar is the row's own background: a solid accent wash filling from the
/// left in proportion to the leader, so the list reads as a bar chart without
/// a chart anywhere. The accent stays on the rank number instead of the title,
/// which keeps a long artist name the loudest thing in the row.
class RankedRow extends StatelessWidget {
  final RankedName entry;
  final int rank;

  /// 0..1 relative to the top entry.
  final double share;
  final Color accent;

  /// Optional artwork or glyph in the leading slot.
  final Widget? leading;
  final VoidCallback? onTap;

  const RankedRow({
    super.key,
    required this.entry,
    required this.rank,
    required this.share,
    required this.accent,
    this.leading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isPodium = rank <= 3;

    return Pressable(
      onTap: onTap,
      haptic: PressHaptic.selection,
      child: Stack(
        children: [
          Positioned.fill(
            child: Align(
              alignment: Alignment.centerLeft,
              child: FractionallySizedBox(
                widthFactor: share.clamp(0.0, 1.0),
                heightFactor: 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: AppTokens.accentWashAlpha),
                    borderRadius: AppTokens.brMd,
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppTokens.s3,
              vertical: AppTokens.s2,
            ),
            child: Row(
              children: [
                SizedBox(
                  width: AppTokens.s5,
                  child: Text(
                    '$rank',
                    style: AppTokens.meta(context).copyWith(
                      color: isPodium ? accent : AppTokens.fgTertiary,
                      fontWeight: isPodium ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                if (leading != null) ...[
                  const SizedBox(width: AppTokens.s2),
                  leading!,
                ],
                const SizedBox(width: AppTokens.s3),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.rowTitle(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _subtitle(context),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTokens.meta(context),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: AppTokens.s3),
                Text(
                  '${entry.plays}',
                  style: AppTokens.meta(context)
                      .copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle(BuildContext context) {
    final parts = <String>[
      if (entry.detail != null) entry.detail!,
      if (entry.listened > Duration.zero) StatsFormat.duration(entry.listened),
    ];
    return parts.isEmpty ? '${entry.plays} plays' : parts.join(' · ');
  }
}

/// A "top artists" / "top albums" list: rows stacked in one shared surface, the
/// leader's share setting every bar.
class RankedGroup extends StatelessWidget {
  final List<RankedName> entries;
  final Color accent;
  final int maxRows;

  /// Builds the leading slot for one entry — artwork for songs, nothing for
  /// names that have no image of their own here.
  final Widget? Function(RankedName entry, int index)? leadingBuilder;
  final void Function(RankedName entry)? onTap;

  const RankedGroup({
    super.key,
    required this.entries,
    required this.accent,
    this.maxRows = 5,
    this.leadingBuilder,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final visible = entries.take(maxRows).toList(growable: false);
    final leaderPlays = visible.first.plays;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, entry) in visible.indexed)
          Builder(
            builder: (context) {
              return Padding(
                padding: EdgeInsets.only(
                  top: index == 0 ? 0 : AppTokens.chartPlotGap,
                ),
                child: RankedRow(
                  entry: entry,
                  rank: index + 1,
                  share: leaderPlays <= 0 ? 0.0 : entry.plays / leaderPlays,
                  accent: accent,
                  leading: leadingBuilder?.call(entry, index),
                  onTap: onTap == null ? null : () => onTap!(entry),
                ),
              );
            },
          ),
      ],
    );
  }
}

/// Small artwork slot for a ranked song, sized down from [AppTokens.artSize] so
/// five rows still fit on a phone screen.
class RankedArtwork extends StatelessWidget {
  final Widget child;
  static const double size = AppTokens.artSize - AppTokens.s1;

  const RankedArtwork({super.key, required this.child});

  @override
  Widget build(BuildContext context) => AppRowArt(size: size, child: child);
}
