/// Pure functions for mapping one progress value onto layout. A gesture-driven
/// surface keeps one mutable number and derives everything else through these.
library;

import 'dart:math' as math;

/// Clamps to the 0..1 interval.
double clamp01(double value) => value < 0 ? 0 : (value > 1 ? 1 : value);

/// Linear interpolation, progress last so a layout expression reads in the
/// order a designer says it: "from a to b at t".
double lerpAt({required double a, required double b, required double t}) =>
    a + (b - a) * t;

/// Progress inside [start, end]: 0 before the segment, 1 after it.
double segment(double progress, double start, double end) {
  if (end == start) return progress >= end ? 1 : 0;
  return clamp01((progress - start) / (end - start));
}

/// Reflects values past [pivot] back toward it, so an overshoot reverses instead
/// of shrinking a surface below its collapsed bound.
double mirrorAbove(double progress, double pivot) =>
    progress > pivot ? 2 * pivot - progress : progress;

/// Bounce-safe progress for three rest states: raw going up, mirrored coming
/// down so layout never runs below the collapsed bound.
double bounceProgress(
  double progress, {
  required bool goingUp,
  required bool fromSecondary,
}) {
  if (goingUp) return progress;
  if (fromSecondary) return 1 - (progress - 1);
  return mirrorAbove(progress, 1);
}

/// A 0..1 eased ramp with zero slope at both ends.
double smoothstep(double t) {
  final clamped = clamp01(t);
  return clamped * clamped * (3 - 2 * clamped);
}

/// Frame-rate independent damped follow: the whole of the "magnetic" feel in
/// press and hover effects, with no state and no controller.
double damp(double current, double target, double tau, double dt) {
  if (tau <= 0) return target;
  return target + (current - target) * math.exp(-dt / tau);
}

/// A stable 0..1 pseudo-random for [index]; any frame recomputes the same value.
double stableNoise(int index) {
  var hash = index * 0x27d4eb2d;
  hash ^= hash >> 15;
  hash *= 0x85ebca6b;
  hash ^= hash >> 13;
  return (hash & 0xffff) / 0xffff;
}

/// Position of [value] inside [list], or -1.
int indexOfClamped(double value, List<double> list) {
  if (list.isEmpty) return -1;
  if (value <= list.first) return 0;
  if (value >= list.last) return list.length - 1;
  var low = 0;
  var high = list.length - 1;
  while (low <= high) {
    final mid = (low + high) >> 1;
    if (list[mid] <= value) {
      low = mid + 1;
    } else {
      high = mid - 1;
    }
  }
  return high;
}

/// Lets a carousel element reach the edge before the finger crosses the full
/// width.
double overshootTravel(double offset, double extent, {double factor = 1.25}) {
  if (extent <= 0) return 0;
  return (offset / extent * factor).clamp(-factor, factor);
}
