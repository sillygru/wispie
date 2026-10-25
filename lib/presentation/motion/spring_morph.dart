import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import 'motion_springs.dart';

/// A value that can be retargeted mid-flight: the new spring starts from the
/// drawn value and its velocity, so a quick second press never snaps back.
class SpringMorph<T> {
  SpringMorph({
    required TickerProvider vsync,
    required this.lerp,
    required T initial,
    SpringDescription spring = MotionSprings.gentle,
  })  : _spring = spring,
        from = initial,
        to = initial,
        _controller = AnimationController.unbounded(vsync: vsync, value: 1);

  /// Blends two states; must tolerate progress outside 0..1 for overshoot.
  final T Function(T a, T b, double t) lerp;

  T from;
  T to;
  SpringDescription _spring;

  final AnimationController _controller;

  Animation<double> get progressListenable => _controller;
  double get progress => _controller.value;

  /// The value as currently drawn, including any overshoot of the spring.
  T get value => lerp(from, to, _controller.value);

  bool get isSettled => !_controller.isAnimating;

  /// Retargets from the current drawn value.
  void retarget(T target, {SpringDescription? spring}) {
    final T origin = value;
    final double velocity = _controller.velocity;
    _spring = spring ?? _spring;
    from = origin;
    to = target;
    _controller.value = 0;
    _controller.animateWith(
      SpringSimulation(_spring, 0, 1, velocity),
    );
  }

  /// Jumps without motion. Use for the first build, and under reduced motion.
  void jumpTo(T target) {
    _controller.stop();
    from = target;
    to = target;
    _controller.value = 1;
  }

  void addListener(VoidCallback listener) => _controller.addListener(listener);

  void removeListener(VoidCallback listener) =>
      _controller.removeListener(listener);

  void dispose() => _controller.dispose();
}
