import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

import 'motion_springs.dart';

/// Bouncing physics in the reference app's shape: a constant-deceleration fling
/// that stops where you expect, momentum carried between nested scrollables,
/// and a spring return at the edges.
///
/// The framework's friction-based fling slows asymptotically, which reads as a
/// long soft slide; constant deceleration makes a flick land, which is what the
/// rest of the app's springs are tuned against.
class MotionBouncingPhysics extends BouncingScrollPhysics {
  const MotionBouncingPhysics({
    super.parent,
    super.decelerationRate = ScrollDecelerationRate.fast,
  });

  /// Reference momentum carry: `0.000816 * |v|^1.967`, capped so a fast hand-off
  /// cannot fling the outer list into the next screen.
  static const double _carryFactor = 0.000816;
  static const double _carryExponent = 1.967;
  static const double _carryCap = 40000;

  @override
  MotionBouncingPhysics applyTo(ScrollPhysics? ancestor) =>
      MotionBouncingPhysics(
        parent: buildParent(ancestor),
        decelerationRate: decelerationRate,
      );

  @override
  SpringDescription get spring => MotionSprings.scroll;

  @override
  double get minFlingVelocity => kMinFlingVelocity;

  /// Below the framework's 3.5 so a scroll starts as soon as the finger intends
  /// it.
  @override
  double get dragStartDistanceMotionThreshold => 3.0;

  @override
  double carriedMomentum(double existingVelocity) {
    if (existingVelocity == 0) return 0;
    final double magnitude =
        math.pow(existingVelocity.abs(), _carryExponent).toDouble();
    return existingVelocity.sign *
        math.min(_carryFactor * magnitude, _carryCap);
  }
}
