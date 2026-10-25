import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import 'motion_springs.dart';

/// The app's one scroll feel: bouncing edges everywhere, so a list has no seam
/// where its content ends.
class MotionScrollBehavior extends MaterialScrollBehavior {
  const MotionScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const MotionScrollPhysics();
}

/// Bouncing physics with the shared spring and Material's fling floor, so a
/// small flick moves a long list without racing away.
class MotionScrollPhysics extends BouncingScrollPhysics {
  const MotionScrollPhysics({
    super.parent,
    super.decelerationRate,
  });

  @override
  MotionScrollPhysics applyTo(ScrollPhysics? ancestor) => MotionScrollPhysics(
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
}
