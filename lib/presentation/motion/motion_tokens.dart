import 'package:flutter/animation.dart';

/// Every duration and curve the app animates with. Retuning one rung retunes
/// everything built on it; no feature writes a raw `Duration`.
abstract final class MotionTokens {
  // ------------------------------------------------------------------ timing
  static const Duration instant = Duration.zero;

  /// A tick of feedback: icon crossfades, hover states.
  static const Duration micro = Duration(milliseconds: 120);

  /// The shortest transition a user is meant to notice.
  static const Duration fast = Duration(milliseconds: 180);

  /// Small state changes: chip selection, toolbar swaps.
  static const Duration short = Duration(milliseconds: 200);

  /// Default for a surface that appears or rearranges itself.
  static const Duration base = Duration(milliseconds: 260);

  static const Duration medium = Duration(milliseconds: 300);

  /// Page, drawer and list-item entrances.
  static const Duration standard = Duration(milliseconds: 400);

  /// A long settle, still short enough not to feel sluggish.
  static const Duration slow = Duration(milliseconds: 420);

  /// Track switches and other two-stage moves.
  static const Duration long = Duration(milliseconds: 600);

  /// Ambient loops, tooltips that linger, deliberate reveals.
  static const Duration linger = Duration(milliseconds: 800);

  static const Duration theme = Duration(milliseconds: 250);
  static const Duration entrance = Duration(milliseconds: 400);
  static const Duration entranceStep = Duration(milliseconds: 50);
  static const Duration entranceMaxDelay = Duration(milliseconds: 400);
  static const Duration exit = Duration(milliseconds: 220);
  static const Duration tooltipIn = Duration(milliseconds: 150);
  static const Duration tooltipOut = Duration(milliseconds: 75);

  // ------------------------------------------------------------------ curves
  /// Default motion: quick launch, soft landing.
  static const Curve standardCurve = Curves.easeOutCubic;

  /// A heavier landing than [standardCurve], for large surfaces.
  static const Curve emphasized = Curves.easeOutQuart;

  /// Opening and expanding: almost immediate, then decelerating.
  static const Curve enterCurve = Curves.fastEaseInToSlowEaseOut;

  /// Switching and settling: linear for the first stretch, then braking.
  static const Curve exitCurve = Curves.fastLinearToSlowEaseIn;

  /// The close overshoot: ends past its target so the surface reverses.
  static const Curve overshootCurve = Cubic(0.175, 0.885, 0.32, 1.125);

  /// A gentler overshoot for surfaces that are already large on screen.
  static const Curve softOvershootCurve = Cubic(0.150, 0.96, 0.28, 1.04);

  /// A small glyph popping into place.
  static const Curve popCurve = Cubic(0.34, 1.42, 0.64, 1.0);

  /// Material 3's emphasized pair, used when a move is the point of the screen.
  static const Curve emphasizedDecel = Cubic(0.05, 0.7, 0.1, 1.0);
  static const Curve emphasizedAccel = Cubic(0.3, 0.0, 0.8, 0.15);

  static const Curve linearCurve = Curves.linear;

  /// A symmetrical in-out, for loops and mirrored motion.
  static const Curve inOutCurve = Curves.easeInOutCubic;
}
