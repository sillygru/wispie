import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/player_tokens.dart';

class SwipeAction {
  final IconData icon;
  final String label;
  final Color color;

  const SwipeAction({
    required this.icon,
    required this.label,
    required this.color,
  });
}

/// Horizontal swipe-to-act row. The action slab grows with the uncovered strip,
/// deepens in colour as the drag nears the commit point and goes fully solid
/// (with a haptic tick and a sprung glyph) the moment it is crossed.
class SwipeActionRow extends StatefulWidget {
  final Key dismissKey;
  final Widget child;
  final SwipeAction startAction;
  final SwipeAction endAction;
  final DismissDirectionCallback onDismissed;

  /// Applied outside the swipe so the action slab lines up with the row.
  final EdgeInsetsGeometry padding;

  static const double threshold = 0.4;

  const SwipeActionRow({
    super.key,
    required this.dismissKey,
    required this.child,
    required this.startAction,
    required this.endAction,
    required this.onDismissed,
    this.padding = EdgeInsets.zero,
  });

  @override
  State<SwipeActionRow> createState() => _SwipeActionRowState();
}

class _SwipeActionRowState extends State<SwipeActionRow> {
  final ValueNotifier<double> _progress = ValueNotifier<double>(0);
  final ValueNotifier<bool> _reached = ValueNotifier<bool>(false);

  @override
  void dispose() {
    _progress.dispose();
    _reached.dispose();
    super.dispose();
  }

  void _onUpdate(DismissUpdateDetails d) {
    _progress.value = d.progress;
    if (d.reached != _reached.value) {
      _reached.value = d.reached;
      d.reached
          ? HapticFeedback.mediumImpact()
          : HapticFeedback.selectionClick();
    }
  }

  Widget _background(SwipeAction action, bool fromStart) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return ValueListenableBuilder<bool>(
          valueListenable: _reached,
          builder: (context, reached, _) {
            return TweenAnimationBuilder<double>(
              tween: Tween<double>(end: reached ? 1 : 0),
              duration: PlayerTokens.dFast,
              curve: PlayerTokens.cStandard,
              builder: (context, solid, _) => ValueListenableBuilder<double>(
                valueListenable: _progress,
                builder: (context, p, _) {
                  final double approach =
                      (p / SwipeActionRow.threshold).clamp(0.0, 1.0);
                  // The slab hugs the uncovered strip with a small gap so it
                  // reads as its own block beside the row, not a stripe
                  // peeking out from underneath it.
                  final double width =
                      (p * constraints.maxWidth - PlayerTokens.s2)
                          .clamp(0.0, constraints.maxWidth);
                  final bool showLabel = width > PlayerTokens.s6 * 3;
                  return Align(
                    alignment: fromStart
                        ? Alignment.centerLeft
                        : Alignment.centerRight,
                    child: Container(
                      width: width,
                      height: constraints.maxHeight,
                      decoration: BoxDecoration(
                        borderRadius: PlayerTokens.brMd,
                        color: Color.lerp(
                          Color.lerp(
                            action.color.withValues(alpha: 0.22),
                            action.color.withValues(alpha: 0.6),
                            approach,
                          ),
                          action.color,
                          solid,
                        ),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: OverflowBox(
                        maxWidth: double.infinity,
                        child: Opacity(
                          opacity: (approach * 2).clamp(0.0, 1.0),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              AnimatedScale(
                                scale: reached ? 1.15 : 0.7 + 0.3 * approach,
                                duration: PlayerTokens.dBase,
                                curve: PlayerTokens.cSpring,
                                child: Icon(
                                  action.icon,
                                  size: 22,
                                  color: Colors.white,
                                ),
                              ),
                              AnimatedSize(
                                duration: PlayerTokens.dBase,
                                curve: PlayerTokens.cEmphasizedDecel,
                                child: showLabel
                                    ? Padding(
                                        padding: const EdgeInsets.only(
                                          left: PlayerTokens.s2,
                                        ),
                                        child: Text(
                                          action.label,
                                          maxLines: 1,
                                          softWrap: false,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w700,
                                            color: Colors.white,
                                          ),
                                        ),
                                      )
                                    : const SizedBox.shrink(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      // Clipping keeps the sliding row inside the list gutter so it slips
      // under the edge instead of hanging off the pane.
      child: ClipRRect(
        borderRadius: PlayerTokens.brMd,
        child: Dismissible(
          key: widget.dismissKey,
          direction: DismissDirection.horizontal,
          dismissThresholds: const {
            DismissDirection.startToEnd: SwipeActionRow.threshold,
            DismissDirection.endToStart: SwipeActionRow.threshold,
          },
          movementDuration: PlayerTokens.dBase,
          resizeDuration: PlayerTokens.dBase,
          onUpdate: _onUpdate,
          background: _background(widget.startAction, true),
          secondaryBackground: _background(widget.endAction, false),
          onDismissed: widget.onDismissed,
          child: ValueListenableBuilder<double>(
            valueListenable: _progress,
            child: widget.child,
            builder: (context, p, child) {
              final double lift =
                  (p / SwipeActionRow.threshold).clamp(0.0, 1.0);
              // The dragged row gains a solid card fill so it reads as one
              // object sliding over the action, not loose text drifting.
              return DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: PlayerTokens.brMd,
                  color: Colors.white.withValues(
                    alpha: PlayerTokens.glassFillAlpha * 0.5 * lift,
                  ),
                ),
                child: child,
              );
            },
          ),
        ),
      ),
    );
  }
}
