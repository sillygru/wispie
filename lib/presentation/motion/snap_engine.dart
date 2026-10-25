import 'package:flutter/animation.dart';
import 'package:flutter/physics.dart';

import 'motion_springs.dart';
import 'motion_tokens.dart';

/// Rest state of a released surface. Three zones cover open, closed and the
/// secondary state beyond open.
enum SnapTarget { first, middle, last }

/// Release thresholds for one surface. Build them from the measured travel, not
/// from fixed pixels: a 500 px/s flick is a nudge on a tablet.
class SnapTuning {
  const SnapTuning({
    required this.actuation,
    required this.flingVelocity,
    this.commitRatio = 0.5,
  });

  /// Minimum deliberate drag, in logical pixels.
  final double actuation;

  /// Speed at which a short flick wins over distance, in px/s.
  final double flingVelocity;

  /// Position at which a slow release commits, as a fraction of travel.
  final double commitRatio;

  factory SnapTuning.forExtent(
    double extent, {
    double actuationRatio = 0.12,
    double minActuation = 40,
    double maxActuation = 120,
    double flingRatio = 0.75,
    double minFling = 400,
    double maxFling = 1000,
    double commitRatio = 0.5,
  }) {
    final safeExtent = extent.isFinite && extent > 0 ? extent : 0.0;
    return SnapTuning(
      actuation:
          (safeExtent * actuationRatio).clamp(minActuation, maxActuation),
      flingVelocity:
          (safeExtent * flingRatio).clamp(minFling, maxFling).toDouble(),
      commitRatio: commitRatio,
    );
  }

  /// Two-state release: a flick wins outright, otherwise position decides.
  /// [velocity] is px/s, positive toward the second state.
  bool advances({
    required double progress,
    required double velocity,
    required double extent,
  }) {
    if (velocity.abs() >= flingVelocity) return velocity > 0;
    if (progress <= 0) return false;
    if (progress >= 1) return true;
    return progress >= commitRatio;
  }

  /// Three-state release, decided by the zone the drag started in. Offsets run
  /// 0 (first) to [extent] (middle); positive [velocity] points at the first.
  SnapTarget decide({
    required double startOffset,
    required double endOffset,
    required double velocity,
    required double extent,
  }) {
    final distance =
        startOffset - endOffset; // positive = toward the last state
    final towardFirst = velocity > flingVelocity || -distance > actuation;
    final towardLast = -velocity > flingVelocity || distance > actuation;

    if (startOffset > extent) {
      return towardFirst ? SnapTarget.middle : SnapTarget.last;
    }
    if (startOffset > extent / 2) {
      if (towardFirst) return SnapTarget.first;
      if (towardLast) return SnapTarget.last;
      return SnapTarget.middle;
    }
    return towardLast ? SnapTarget.middle : SnapTarget.first;
  }
}

/// Committed moves with generation tokens: a snap overtaken by a newer one never
/// runs its completion. Side effects belong in the start callback.
class SnapEngine {
  SnapEngine(this.controller);

  final AnimationController controller;
  int _generation = 0;

  int get generation => _generation;
  bool get isAnimating => controller.isAnimating;

  Future<void> snapTo(
    double target, {
    Duration duration = MotionTokens.medium,
    Curve curve = MotionTokens.standardCurve,
    VoidCallback? onStart,
    VoidCallback? onSettled,
  }) async {
    final generation = ++_generation;
    onStart?.call();
    if (duration <= Duration.zero) {
      controller.value = target;
    } else {
      await controller.animateTo(
        target,
        duration: duration,
        curve: curve,
      );
    }
    if (generation != _generation) return;
    onSettled?.call();
  }

  /// Settles on a spring, keeping the release momentum instead of replaying a
  /// fixed curve.
  Future<void> springTo(
    double target, {
    SpringDescription spring = MotionSprings.gentle,
    double? velocity,
    VoidCallback? onSettled,
  }) async {
    final generation = ++_generation;
    await controller.animateWith(
      SpringSimulation(
        spring,
        controller.value,
        target,
        velocity ?? controller.velocity,
      ),
    );
    if (generation != _generation) return;
    onSettled?.call();
  }

  /// Plays any simulation under the same generation guard. For settles shaped
  /// by a custom curve or a bounded overshoot rather than a plain spring.
  Future<void> drive(
    Simulation simulation, {
    VoidCallback? onSettled,
  }) async {
    final generation = ++_generation;
    await controller.animateWith(simulation);
    if (generation != _generation) return;
    onSettled?.call();
  }

  /// Freezes an in-flight move where it is; a new drag picks it up there.
  void cancel() {
    _generation++;
    controller.stop();
  }

  void jumpTo(double value) {
    _generation++;
    controller.value = value;
  }
}
