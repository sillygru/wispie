import 'dart:ui';

import 'package:flutter/material.dart';

/// Glass helpers for the cover-gradient screens.
///
/// New variants only — the existing mini player, nav bar and glass surfaces
/// are untouched so the legacy design cannot drift.
class GlassCircleButton extends StatelessWidget {
  final Widget icon;
  final VoidCallback? onPressed;
  final String? tooltip;

  const GlassCircleButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    final Widget button = ClipOval(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.38),
          ),
          child: IconButton(
            onPressed: onPressed,
            icon: icon,
            padding: EdgeInsets.zero,
            color: Colors.white,
          ),
        ),
      ),
    );
    if (tooltip == null || tooltip!.isEmpty) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// Floating glass pill used only inside the gradient detail screen to wrap
/// the existing mini player / bottom navigation without editing them.
class GlassPill extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const GlassPill({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.fromLTRB(12, 0, 12, 12),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: Colors.black.withValues(alpha: 0.42),
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
