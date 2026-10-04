import 'package:flutter/material.dart';

import '../../components/app_icon.dart';
import '../../tokens/app_icons.dart';
import '../../tokens/app_tokens.dart';

/// A labelled share, drawn as a meter: a recessed track with an accent fill.
///
/// Fills from the left as the data loads rather than snapping in — a number
/// that grows into place reads as a measurement being taken, which is what it
/// is, and it costs one implicit animation.
class ShareMeter extends StatelessWidget {
  final String label;
  final String value;

  /// 0..1. Values outside the range are clamped rather than rejected: an
  /// over-100% ratio should still render as a full meter.
  final double share;
  final Color accent;

  /// Overrides the fill for figures that are not "more is better" — a skip
  /// rate fills in warning, not in the accent.
  final Color? fill;
  final AppIconData? icon;

  const ShareMeter({
    super.key,
    required this.label,
    required this.value,
    required this.share,
    required this.accent,
    this.fill,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (icon != null) ...[
              AppIcon(icon!, size: AppTokens.iconSm, color: accent),
              const SizedBox(width: AppTokens.s2),
            ],
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTokens.rowTitle(context),
              ),
            ),
            const SizedBox(width: AppTokens.s2),
            Text(value, style: AppTokens.meta(context)),
          ],
        ),
        const SizedBox(height: AppTokens.s2),
        _MeterTrack(share: share, accent: fill ?? accent),
      ],
    );
  }
}

class _MeterTrack extends StatelessWidget {
  final double share;
  final Color accent;

  const _MeterTrack({required this.share, required this.accent});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: share.clamp(0.0, 1.0)),
          duration: AppTokens.dSlow,
          curve: AppTokens.cStandard,
          builder: (context, value, _) {
            return SizedBox(
              height: AppTokens.chartBarHeight,
              child: Stack(
                children: [
                  // A well, not a surface: a track is something the fill sits
                  // *inside*, so it recedes.
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppTokens.wellFill,
                        borderRadius: AppTokens.brPill,
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    bottom: 0,
                    width: constraints.maxWidth * value,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: accent,
                        borderRadius: AppTokens.brPill,
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

/// A small, quiet change indicator — "+18%" against the previous window, or
/// nothing at all when there is no baseline.
class TrendBadge extends StatelessWidget {
  final String? text;
  final Color accent;

  /// Rises when the change is positive, falls when it is negative.
  final bool rising;
  final bool flat;

  const TrendBadge({
    super.key,
    required this.text,
    required this.accent,
    this.rising = true,
    this.flat = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text == null) return const SizedBox.shrink();

    final tone = flat
        ? AppTokens.fg(AppTokens.aTertiary)
        : rising
            ? AppTokens.success
            : AppTokens.warning;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTokens.s2,
        vertical: AppTokens.s1,
      ),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: AppTokens.accentWashAlpha),
        borderRadius: AppTokens.brPill,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // No glyph when nothing moved: an arrow beside "same as before"
          // would claim a direction that did not happen.
          if (!flat) ...[
            AppIcon(
              rising ? AppIcons.arrowUp : AppIcons.arrowDown,
              size: AppTokens.iconSm,
              color: tone,
            ),
            const SizedBox(width: AppTokens.s1),
          ],
          Text(text!, style: AppTokens.meta(context).copyWith(color: tone)),
        ],
      ),
    );
  }
}
