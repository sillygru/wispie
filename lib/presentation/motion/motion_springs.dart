import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

/// The app's physical vocabulary. A spring is interruptible: retarget it
/// mid-flight and it bends from the current value and velocity.
abstract final class MotionSprings {
  /// Press feedback: barely any overshoot. The surface dips and returns.
  static const SpringDescription snappy = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 30,
  );

  /// Larger moving surfaces — cards, pills, sheets — where a hint of bounce
  /// reads as weight rather than nervousness.
  static const SpringDescription gentle = SpringDescription(
    mass: 1,
    stiffness: 340,
    damping: 24,
  );

  /// A deliberate pop, for confirmations and toggles.
  static const SpringDescription bouncy = SpringDescription(
    mass: 1,
    stiffness: 300,
    damping: 16,
  );

  /// Same stiffness, more damping: settles without crossing its target.
  static const SpringDescription settle = SpringDescription(
    mass: 1,
    stiffness: 520,
    damping: 46,
  );

  /// A large surface opening into a hard stop — a docked panel's travel ends at
  /// the window edge, so it cannot overshoot. Almost critically damped: it is
  /// still moving when it lands instead of crossing early and freezing against
  /// the edge for the rest of the spring.
  static const SpringDescription panel = SpringDescription(
    mass: 1,
    stiffness: 260,
    damping: 32,
  );

  /// A panel arriving where it still has room past its seat — the slide-in
  /// drawer, which is allowed to swell beyond its resting width. Lightly damped
  /// on purpose: it crests past the seat and relaxes back, so the open reads as
  /// elastic instead of the surface stopping dead.
  static const SpringDescription elastic = SpringDescription(
    mass: 1,
    stiffness: 220,
    damping: 19,
  );

  /// The drawer arriving at its resting width. Softer than [elastic] so the
  /// crest into the overshoot room is a visible swell rather than a few
  /// pixels, and it still settles without a wobble.
  static const SpringDescription drawerOpen = SpringDescription(
    mass: 1,
    stiffness: 250,
    damping: 16,
  );

  /// Critically damped: fastest approach that never overshoots.
  static final SpringDescription critical = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 520,
    ratio: 1,
  );

  /// Scroll settle. Ratio is kept above 1 so content never oscillates at rest.
  static final SpringDescription scroll = SpringDescription.withDampingRatio(
    mass: 0.5,
    stiffness: 100,
    ratio: 1.1,
  );

  static final SpringDescription scrollFast =
      SpringDescription.withDampingRatio(mass: 0.3, stiffness: 75, ratio: 1.3);

  /// Springs to [target] from the controller's current value and velocity.
  static void driveTo(
    AnimationController controller,
    double target, {
    SpringDescription spring = snappy,
    Tolerance tolerance = const Tolerance(distance: 0.001, velocity: 0.01),
  }) {
    controller.animateWith(
      SpringSimulation(
        spring,
        controller.value,
        target,
        controller.velocity,
        tolerance: tolerance,
      ),
    );
  }
}
