import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../tokens/player_tokens.dart';
import '../motion/motion.dart';

/// Pane switcher: plain labels sitting directly on the backdrop with a sliding
/// underline. No container, no border — the labels are there so the panes are
/// discoverable, not to be a piece of furniture in their own right.
///
/// The underline is driven by a *fractional* position so it tracks a swipe
/// continuously instead of jumping once the page settles.
class PlayerSegmentedPill extends StatelessWidget {
  final List<String> labels;

  /// Continuous position in segment units — 0.0 is the first label, 1.0 the
  /// second, 0.5 exactly between them.
  final ValueListenable<double> position;
  final ValueChanged<int> onSelected;
  final Color accent;
  final bool compact;

  /// Set when the labels sit directly on artwork rather than the dark
  /// backdrop: inactive labels get more weight plus a soft shadow.
  final bool overCover;

  static const List<Shadow> _legibilityShadows = [
    Shadow(color: Color(0x99000000), blurRadius: 8),
    Shadow(color: Color(0x66000000), blurRadius: 2, offset: Offset(0, 1)),
  ];

  const PlayerSegmentedPill({
    super.key,
    required this.labels,
    required this.position,
    required this.onSelected,
    required this.accent,
    this.compact = false,
    this.overCover = false,
  });

  @override
  Widget build(BuildContext context) {
    final fontSize = compact ? 11.5 : 13.0;
    final height = compact ? 26.0 : 30.0;

    return PlayerRouteEntrance(
      child: SizedBox(
        height: height,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final segmentWidth = constraints.maxWidth / labels.length;

            return ValueListenableBuilder<double>(
              valueListenable: position,
              builder: (context, value, _) {
                final clamped =
                    value.clamp(0.0, (labels.length - 1).toDouble());

                return Stack(
                  children: [
                    Row(
                      children: List.generate(labels.length, (index) {
                        // Full strength when the underline is centred here,
                        // fading as it slides away.
                        final emphasis =
                            1.0 - (clamped - index).abs().clamp(0.0, 1.0);

                        return Expanded(
                          child: GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: () {
                              MotionHaptics.selection();
                              onSelected(index);
                            },
                            child: Center(
                              child: Text(
                                labels[index],
                                style: TextStyle(
                                  fontSize: fontSize,
                                  letterSpacing: 0.3,
                                  fontWeight: FontWeight.lerp(
                                    FontWeight.w500,
                                    FontWeight.w700,
                                    emphasis,
                                  ),
                                  color: Color.lerp(
                                    Colors.white.withValues(
                                        alpha: overCover
                                            ? PlayerTokens.aSecondary
                                            : PlayerTokens.aTertiary),
                                    accent,
                                    emphasis,
                                  ),
                                  shadows:
                                      overCover ? _legibilityShadows : null,
                                ),
                              ),
                            ),
                          ),
                        );
                      }),
                    ),
                    Positioned(
                      left: clamped * segmentWidth + segmentWidth / 2 - 9,
                      bottom: 0,
                      child: Container(
                        width: 18,
                        height: 2.5,
                        decoration: BoxDecoration(
                          color: accent,
                          borderRadius: PlayerTokens.brPill,
                        ),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Holds the pill back while the player sheet opens, then lifts it in once the
/// sheet is mostly up. Otherwise it sits at the top of the sheet and is on
/// screen from the first frame, right where the mini player is.
class PlayerRouteEntrance extends StatelessWidget {
  final Widget child;

  const PlayerRouteEntrance({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final Animation<double>? route = ModalRoute.of(context)?.animation;
    if (route == null) return child;
    return AnimatedBuilder(
      animation: route,
      child: child,
      builder: (context, child) {
        final double t =
            PlayerTokens.cStandard.transform(route.value.clamp(0.0, 1.0));
        // Same structure at every value so the pill never remounts.
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, (1 - t) * PlayerTokens.s3),
            child: Transform.scale(scale: 0.94 + 0.06 * t, child: child),
          ),
        );
      },
    );
  }
}
