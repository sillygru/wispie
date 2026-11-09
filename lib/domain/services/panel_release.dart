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

/// A velocity-seeded settle with an optional springy stop at the dock.
final class PanelSpring {
  PanelSpring({
    required this.from,
    required this.to,
    required this.velocity,
    bool released = true,
    double reboundRoom = 0,
  }) {
    final double distance = (to - from).abs();
    final double toward = (to - from).sign;
    final double approach = math.max(0, velocity * toward);
    final double response =
        released ? 12 + 14 * (1 - math.exp(-approach / 2)) : 23;
    _rate = response + 6 * (1 - (distance / 0.6).clamp(0.0, 1.0));
    final bool rebounds = reboundRoom > 0 && to == 0 && from > to;
    final double impact =
        rebounds ? math.max(0.26, approach / (approach + 1.6)) : 0;
    _rest = to + (to - from) * (0.035 + 0.15 * impact);
    _displacement = from - _rest;
    _coefficient = velocity + _rate * _displacement;
    _reboundRoom = reboundRoom;
    _contactTime = rebounds ? _findContact() : null;
    _contactSpeed = rebounds ? _approachSpeed(_contactTime!) : 0;
  }

  final double from;
  final double to;
  final double velocity;
  late final double _rate;
  late final double _rest;
  late final double _displacement;
  late final double _coefficient;
  late final double _reboundRoom;
  late final double? _contactTime;
  late final double _contactSpeed;

  static const double _reboundFrequency = 24;
  static const double _reboundDecay = 13;
  static const double _reboundSeconds = math.pi / _reboundFrequency;

  double _position(double time) =>
      _rest + (_displacement + _coefficient * time) * math.exp(-_rate * time);

  bool _hasLanded(double position) =>
      from == to || (to - position) * (to - from) <= 0;

  double _findContact() {
    double before = 0;
    double after = 1;
    while (!_hasLanded(_position(after))) {
      after *= 2;
    }
    for (int i = 0; i < 32; i++) {
      final double middle = (before + after) / 2;
      if (_hasLanded(_position(middle))) {
        after = middle;
      } else {
        before = middle;
      }
    }
    return after;
  }

  double _approachSpeed(double time) =>
      (velocity - _rate * _coefficient * time) * math.exp(-_rate * time);

  // A damped contact response starts with the incoming speed, then the dock
  // gives once and returns to its seat. The same clock drives both phases.
  ({double position, double speed}) _recoil(double time) {
    final double angle = _reboundFrequency * time;
    final double decay = math.exp(-_reboundDecay * time);
    final double wave = math.sin(angle);
    final double raw = _contactSpeed * decay * wave / _reboundFrequency;
    final double compression = math.exp(raw / _reboundRoom);
    return (
      position: _reboundRoom * (compression - 1),
      speed: compression *
          _contactSpeed *
          decay *
          (math.cos(angle) - _reboundDecay / _reboundFrequency * wave),
    );
  }

  bool isDone(double time) {
    final double? contact = _contactTime;
    return contact == null
        ? _hasLanded(_position(time))
        : time >= contact + _reboundSeconds;
  }

  double positionAt(double time) {
    if (time == 0) return from;
    if (isDone(time)) return to;
    final double? contact = _contactTime;
    return contact != null && time >= contact
        ? _recoil(time - contact).position
        : _position(time);
  }

  double velocityAt(double time) {
    if (isDone(time)) return 0;
    final double? contact = _contactTime;
    return contact != null && time >= contact
        ? _recoil(time - contact).speed
        : _approachSpeed(time);
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
