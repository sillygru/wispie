import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/player_tokens.dart';

/// Single seam for wide-window (tablet/desktop landscape) layouts.
///
/// Phones stay portrait-locked at the OS level, so this intentionally keys off
/// window size rather than device orientation. A narrow desktop window keeps
/// the phone layout; a wide tablet window gets the desktop layout.
class WideLayout {
  const WideLayout._();

  /// Minimum window width that earns the desktop arrangement.
  static const double breakpoint = 800;

  /// Width below which the phone layout runs with compact affordances.
  ///
  /// The phone layout is the *fallback* for narrow desktop windows, but it
  /// carries roomy desktop extras (volume slider, tall bar) that squeeze the
  /// title and action rows once the window approaches phone width. Under this
  /// seam those extras drop out and fixed sizes step down.
  static const double compactBreakpoint = 480;

  /// Ratio of window width the slide-in drawer occupies before clamping.
  static const double drawerRatio = 0.48;

  /// Narrowest readable drawer. The raw ratio lands at 172px on a 360px
  /// window, which is too tight for the drawer's own text scale.
  static const double minDrawerWidth = 240;

  /// Maximum content width for centered reading columns on wide windows.
  static const double maxContentWidth = 1800;

  /// Maximum width for narrow reading columns (settings, profile).
  static const double maxNarrowWidth = 1040;

  /// Fixed width of the player's left (cover) column on wide windows.
  static const double playerSideWidth = 440;

  /// Maximum drawer width on wide windows, so a 0.48 ratio never covers half
  /// a desktop window.
  static const double maxDrawerWidth = 360;

  /// Headroom past fully open. The sheet swells a visible amount past its
  /// resting width instead of stopping dead at the screen edge, and the open
  /// settle is allowed to crest into this room before relaxing back.
  static const double drawerOvershoot = 0.2;

  /// Left-edge strip whose swipe belongs to the drawer, not to whatever
  /// horizontal scroller happens to sit under the finger.
  static const double drawerEdgeWidth = 28;

  /// How far the sheet swells to the **right** past its resting open width, for a
  /// progress past 1.
  ///
  /// The drawn sheet's left edge sits on the window edge, so it cannot grow
  /// leftward without either leaving the screen or shoving the content along
  /// with it. The swell is therefore one edge only: the panel's trailing edge
  /// moves out over the background while everything else holds still.
  static double drawerStretch(
    double drawerWidth,
    double overshootPastOpen,
  ) {
    final limit = drawerOvershoot;
    final t = (overshootPastOpen / limit).clamp(0.0, 1.0);
    // Ease the swell: it comes on quickly as the sheet leaves its resting size
    // and softens into the cap, so pushing further gives back less with each
    // pixel instead of growing at one rate all the way to a hard stop.
    return drawerWidth * Curves.easeOutCubic.transform(t) * limit;
  }

  /// Extra drag resistance past fully open. It ramps from none at the resting
  /// edge to this at the cap, so the overshoot comes alive as you push into it
  /// rather than the sheet stopping dead.
  static const double drawerOvershootMaxResistance = 0.6;

  /// Fraction of a drag that survives at [value]. 1 inside the resting range,
  /// easing down to `1 - drawerOvershootMaxResistance` at either cap, so the
  /// overshoot gets progressively heavier instead of hitting a wall.
  static double drawerOvershootDragScale(double value) {
    final double past = value >= 1
        ? (value - 1) / drawerOvershoot
        : (value <= 0 ? -value / drawerOvershoot : 0.0);
    return 1 -
        drawerOvershootMaxResistance *
            Curves.easeOutCubic.transform(
              past.clamp(0.0, 1.0),
            );
  }

  /// Fraction of the rest-state swell that reaches the content, so the buttons
  /// drift out with the panel without taking part in the settle's overshoot.
  /// Kept low — this is a lean into the swell, not a slide.
  static const double drawerContentDrift = 0.28;

  /// Extra left/right growth in logical pixels that holds at rest, for a
  /// progress past 1. The settle spring rides above this into the rest of
  /// [drawerOvershoot], so the elastic crest never drags the content with it.
  static double drawerStretchAtRest(double drawerWidth, double pastOpen) =>
      drawerStretch(drawerWidth, pastOpen.clamp(0.0, 1.0) / 3);

  /// Maximum bottom-sheet width on wide windows, so sheets read as dialogs.
  static const double maxSheetWidth = 560;

  static bool isWide(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return size.width >= breakpoint && size.width > size.height;
  }

  static bool isWideSize(Size size) {
    return size.width >= breakpoint && size.width > size.height;
  }

  static bool isPortrait(Size size) => size.height >= size.width;

  static bool isCompact(BuildContext context) =>
      isCompactSize(MediaQuery.sizeOf(context));

  static bool isCompactSize(Size size) =>
      size.width < compactBreakpoint || isPortrait(size);

  /// Width of the slide-in drawer for a window of [windowWidth]. One formula
  /// shared by the drawer panel, the slide animation and the edge-drag math so
  /// they can never disagree about where the drawer's edge is.
  static double drawerWidth(double windowWidth) {
    final floor = math.min(minDrawerWidth, windowWidth * 0.8);
    return (windowWidth * drawerRatio).clamp(floor, maxDrawerWidth);
  }

  /// Grid columns that grow with width, clamped to a readable range.
  static int gridColumns(BuildContext context, {int base = 2}) {
    if (!isWide(context)) return base;
    final width = MediaQuery.sizeOf(context).width;
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

/// Horizontal padding shared by a screen's info block and its controls.
class ContentGutter extends StatelessWidget {
  final Widget child;

  const ContentGutter({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final double side = WideLayoutGutter.of(context);
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: side),
      child: child,
    );
  }
}

/// Content side padding by window width.
///
/// Separate from [WideLayout]'s breakpoints: this keys on how much room text
/// needs (380/600), not on the phone-vs-desktop chrome seam (480/800).
class WideLayoutGutter {
  static double of(BuildContext context) {
    final double width = MediaQuery.sizeOf(context).width;
    // Narrow phones get tighter gutters; desktop keeps breathing room.
    if (width < 380) return PlayerTokens.s3;
    if (width < 600) return PlayerTokens.s5;
    return PlayerTokens.s6;
  }
}
