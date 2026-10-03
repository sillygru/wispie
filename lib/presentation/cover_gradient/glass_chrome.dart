import 'package:flutter/material.dart';

/// Solid helpers for the cover-gradient screens.
///
/// Same shape and fill as the old frosted variants, without the live blur:
/// the backdrop behind them is already a blurred image, so each BackdropFilter
/// paid a saveLayer plus backdrop readback for no visible difference.
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
    final Widget button = Container(
      width: 40,
      height: 40,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Color(0x61000000),
      ),
      child: IconButton(
        onPressed: onPressed,
        icon: icon,
        padding: EdgeInsets.zero,
        color: Colors.white,
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
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: Colors.black.withValues(alpha: 0.42),
        ),
        child: child,
      ),
    );
  }
}
