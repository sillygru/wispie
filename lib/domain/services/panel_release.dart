// SPDX-License-Identifier: GPL-3.0-only
import 'dart:math' as math;

/// The physics of letting go of the player panel.
///
/// Kept free of Flutter on purpose: the decision a release makes is the part
/// that was wrong (a panel on its way down could not be caught, and a throw was
/// told to replay a fixed curve), so it has to be exercisable without an engine.
abstract final class PanelRelease {
  /// Travel past [low] / [high] that the surface gives to a finger, in the same
  /// units as the position. Pull is damped, never free, and eases into the
  /// limit: the finger keeps moving, the surface gives less and less.
  static double resist(
    double raw, {
    required double low,
    required double high,
    required double room,
  }) {
    if (raw >= low && raw <= high) return raw;
    final double excess = raw < low ? low - raw : raw - high;
    final double give = room * (1 - math.exp(-excess / room));
    return raw < low ? low - give : high + give;
  }

  /// Whether releasing here finishes the close.
  ///
  /// [velocity] is in px/s from the finger, positive downward; [anchor] is where
  /// the surface was picked up and [current] where it was let go, both as panel
  /// progress. [travel] converts between the two.
  static bool closes({
    required double anchor,
    required double current,
    required double travel,
    required double velocity,
    required double flingVelocity,
    required double actuation,
  }) {
    final double travelled = (current - anchor) * travel;
    // A flick decides on its own, whatever it crossed on the way. This is what
    // lets a fast upward swipe catch a closing panel and bring it back.
    if (velocity.abs() >= flingVelocity) return velocity > 0;
    if (travelled < -actuation) return true;
    if (travelled > actuation) return false;
    // Nothing decisive: the nearer end wins, which lets a panel caught halfway
    // down finish the drop it was already making.
    return current < 0.5;
  }

  /// A release speed in panel progress per second. The finger's dy is positive
  /// downward and progress is positive upward, so the sign flips.
  static double momentum({
    required double velocity,
    required double travel,
  }) {
    if (travel <= 0) return 0;
    return -velocity / travel;
  }
}
