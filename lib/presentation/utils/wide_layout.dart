import 'package:flutter/material.dart';

/// Single seam for wide-window (tablet/desktop landscape) layouts.
///
/// Phones stay portrait-locked at the OS level, so this intentionally keys off
/// window size rather than device orientation. A narrow desktop window keeps
/// the phone layout; a wide tablet window gets the desktop layout.
class WideLayout {
  const WideLayout._();

  /// Minimum window width that earns the desktop arrangement.
  static const double breakpoint = 800;

  /// Maximum content width for centered reading columns on wide windows.
  static const double maxContentWidth = 1100;

  /// Maximum width for narrow reading columns (settings, profile).
  static const double maxNarrowWidth = 800;

  /// Fixed width of the player's left (cover) column on wide windows.
  static const double playerSideWidth = 440;

  /// Maximum drawer width on wide windows, so a 0.48 ratio never covers half
  /// a desktop window.
  static const double maxDrawerWidth = 360;

  /// Maximum bottom-sheet width on wide windows, so sheets read as dialogs.
  static const double maxSheetWidth = 560;

  static bool isWide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= breakpoint && size.width > size.height;
  }

  static bool isWideSize(Size size) {
    return size.width >= breakpoint && size.width > size.height;
  }

  /// Grid columns that grow with width, clamped to a readable range.
  static int gridColumns(BuildContext context, {int base = 2}) {
    final width = MediaQuery.sizeOf(context).width;
    if (width < breakpoint) return base;
    final extra = ((width - breakpoint) / 300).floor();
    return (base + extra).clamp(base, 5);
  }
}

/// Centers [child] in a capped reading column on wide windows and leaves it
/// full-width on narrow ones. Pure layout, no state.
class WideContentCenter extends StatelessWidget {
  final Widget child;
  final double maxWidth;

  const WideContentCenter({
    super.key,
    required this.child,
    this.maxWidth = WideLayout.maxContentWidth,
  });

  @override
  Widget build(BuildContext context) {
    if (!WideLayout.isWide(context)) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
