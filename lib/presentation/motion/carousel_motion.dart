import 'motion_math.dart';

/// The three items a swipe carousel draws: the one leaving, the one in the
/// middle, and the one arriving.
class CarouselIndices {
  const CarouselIndices({
    required this.previous,
    required this.current,
    required this.next,
  });

  final int previous;
  final int current;
  final int next;

  @override
  bool operator ==(Object other) =>
      other is CarouselIndices &&
      other.previous == previous &&
      other.current == current &&
      other.next == next;

  @override
  int get hashCode => Object.hash(previous, current, next);
}

/// Holds neighbour indices steady while a switch is in flight. Reading the real
/// index mid-switch changes the slot under the finger for a frame; freeze until
/// the new index is confirmed.
class CarouselWindow {
  CarouselIndices? _frozen;

  bool get isFrozen => _frozen != null;

  CarouselIndices? get frozen => _frozen;

  /// Neighborhood around [current], clamped at the ends.
  static CarouselIndices around(int current, int length) {
    if (length <= 0) {
      return const CarouselIndices(previous: 0, current: 0, next: 0);
    }
    final int safe = current.clamp(0, length - 1);
    return CarouselIndices(
      previous: (safe - 1).clamp(0, length - 1),
      current: safe,
      next: (safe + 1).clamp(0, length - 1),
    );
  }

  CarouselIndices resolve(int current, int length) =>
      _frozen ?? around(current, length);

  void freeze(int current, int length) {
    _frozen = around(current, length);
  }

  /// Replaces the frozen window, e.g. when the real index lands while a second
  /// swipe is already running.
  void freezeTo(CarouselIndices indices) {
    _frozen = indices;
  }

  void release() {
    _frozen = null;
  }
}

/// `1` for next, `-1` for previous, null to spring back. A quick flick wins
/// without distance; a slow drag wins without speed.
int? decideCarouselSwipe({
  required double progress,
  required double velocity,
  required double extent,
  required bool canGoNext,
  required bool canGoPrevious,
  double commitRatio = 0.28,
  double flingVelocityRatio = 1.1,
  double minFlingVelocity = 700,
  double maxFlingVelocity = 1100,
}) {
  if (progress == 0) return null;
  final double fling = (extent * flingVelocityRatio)
      .clamp(minFlingVelocity, maxFlingVelocity)
      .toDouble();
  final int direction = progress < 0 ? 1 : -1;
  final bool flick = velocity.abs() >= fling && velocity.sign == progress.sign;
  final bool far = progress.abs() >= commitRatio;
  if (!flick && !far) return null;
  if (direction > 0 && !canGoNext) return null;
  if (direction < 0 && !canGoPrevious) return null;
  return direction;
}

/// Travel for one carousel slot. A [parallax] above 1 makes the incoming slot
/// move faster than the finger, so the outgoing card reads as further away.
double carouselSlotTravel({
  required double progress,
  required double width,
  required int direction,
  double parallax = 1,
}) {
  final double p = clamp01(progress.abs());
  return direction * width * p * parallax;
}
