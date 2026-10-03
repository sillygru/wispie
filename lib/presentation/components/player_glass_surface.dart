import 'package:flutter/material.dart';

import '../tokens/player_tokens.dart';

/// The raised translucent container used by the unified player.
///
/// A solid translucent fill rather than a live blur: the backdrop behind these
/// surfaces is already a pre-blurred image, so a BackdropFilter paid a full
/// saveLayer + backdrop readback for no visible frost. Nothing else in the
/// player may build its own BackdropFilter box — routing raised surfaces
/// through here is what keeps them reading as the same material.
///
/// Built today only by the queue pane's undo bar, which floats over the
/// scrolling list and needs its own backing to stay readable.
class PlayerGlassSurface extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final bool strong;

  const PlayerGlassSurface({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(PlayerTokens.s4),
    this.borderRadius,
    this.strong = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? PlayerTokens.brLg;
    final fillAlpha = strong
        ? PlayerTokens.glassFillAlphaStrong
        : PlayerTokens.glassFillAlpha;

    // The fill is the material: a solid translucent block over the
    // pre-blurred backdrop, so no BackdropFilter is needed. Kept inside a
    // RepaintBoundary so the overlay composites without repainting the list
    // underneath.
    return ClipRRect(
      borderRadius: radius,
      child: RepaintBoundary(
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Color.alphaBlend(
              Colors.black.withValues(alpha: fillAlpha),
              Colors.white.withValues(alpha: fillAlpha * 0.12),
            ),
            borderRadius: radius,
          ),
          child: child,
        ),
      ),
    );
  }
}
