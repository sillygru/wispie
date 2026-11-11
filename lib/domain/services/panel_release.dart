// SPDX-License-Identifier: GPL-3.0-only
import 'dart:math' as math;

/// Finger-space drag and release math for the player panel.
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

  /// Recovers the finger-space position when a grab interrupts a rubber band.
  static double unresist(
    double position, {
    required double low,
    required double high,
    required double room,
  }) {
    final double edge = position.clamp(low, high);
    final double excess = position - edge;
    if (excess == 0) return position;
    final double fraction = (1 - excess.abs() / room).clamp(1e-6, 1.0);
    return edge - excess.sign * room * math.log(fraction);
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
    if (velocity.abs() > flingVelocity) return velocity > 0;
    final double distance = (anchor - current) * travel;
    return anchor > 0.5 ? distance > actuation : distance >= -actuation;
  }
}

/// The cover rides with the sheet while its frame unfolds and seats itself.
abstract final class PanelCoverMotion {
  static ({
    double inset,
    double sideways,
    double width,
    double height,
    double tension,
  }) pose({
    required double progress,
    required double speed,
    required double travel,
    required double insetChange,
  }) {
    final double p = progress.clamp(0.0, 1.0);
    final double middle = p * (1 - p);
    final double curved = _smooth(p);
    // Limit how fast the cover changes its inset so it can never outrun the
    // sheet in one direction and backtrack in the middle of the stroke.
    final double grip = insetChange > 0
        ? (2 * (travel / insetChange - 1)).clamp(0.0, 0.9)
        : 0.9;
    return (
      inset: p + (curved - p) * grip,
      sideways: curved,
      width: _smooth(p - 0.17 * middle),
      height: _smooth(p + 0.17 * middle),
      tension: 16 * middle * middle * speed / (speed.abs() + 2.5),
    );
  }

  static double _smooth(double p) => p * p * (3 - 2 * p);
}
