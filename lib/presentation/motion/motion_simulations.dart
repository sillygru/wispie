import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import 'motion_springs.dart';

/// Plays a fixed [curve] over [duration] as a [Simulation].
///
/// A route's transition is normally driven by a curve, but a transition that a
/// gesture can grab has to be a simulation: only then can the controller be
/// interrupted mid-flight and handed a new target. This bridges the two.
class CurveSimulation extends Simulation {
  CurveSimulation({
    required this.from,
    required this.to,
    required Duration duration,
    required this.curve,
  }) : _seconds = duration.inMicroseconds / Duration.microsecondsPerSecond;

  final double from;
  final double to;
  final Curve curve;
  final double _seconds;

  double _f(double time) =>
      _seconds <= 0 ? 1 : (time / _seconds).clamp(0.0, 1.0);

  @override
  double x(double time) => from + (to - from) * curve.transform(_f(time));

  @override
  double dx(double time) {
    if (_seconds <= 0 || time >= _seconds) return 0;
    const double h = 1e-3;
    return (x(time + h) - x(time)) / h;
  }

  @override
  bool isDone(double time) => time >= _seconds;
}

/// A no-bounce landing that ends the instant it reaches the target, instead of
/// creeping through the spring's long tail.
///
/// Full-screen surfaces have nowhere left to travel once they arrive, so an
/// overshoot or a lingering settle reads as a stutter. Closing aims just past
/// zero so the shape is already gone by the time the spring stops.
class LandingSimulation extends Simulation {
  LandingSimulation(
    double from,
    this._target,
    double velocity, {
    SpringDescription? spring,
    Duration limit = const Duration(milliseconds: 300),
    double pastTarget = 0.06,
  })  : _spring = SpringSimulation(
          spring ?? MotionSprings.critical,
          from,
          _target == 0 ? -pastTarget : _target,
          velocity,
          tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
        ),
        _limit = limit.inMicroseconds / Duration.microsecondsPerSecond;

  final double _target;
  final SpringSimulation _spring;
  final double _limit;

  @override
  double x(double time) => _spring.x(time).clamp(0.0, 1.0);

  @override
  double dx(double time) => _spring.dx(time);

  @override
  bool isDone(double time) {
    final x = _spring.x(time);
    return _spring.isDone(time) ||
        (_target == 0 ? x <= 0 : x >= 1) ||
        time >= _limit;
  }
}
