import 'package:flutter/material.dart';

import '../components/app_scrollbar.dart';
import 'scroll_physics_modified.dart';

/// The app's one scroll feel: our physics, and our scrollbar on every list.
class MotionScrollBehavior extends MaterialScrollBehavior {
  const MotionScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const MotionScrollPhysics();

  @override
  Widget buildScrollbar(
    BuildContext context,
    Widget child,
    ScrollableDetails details,
  ) {
    // Only columns scroll here; a carousel's bar would be a stripe on a row.
    if (details.direction == AxisDirection.left ||
        details.direction == AxisDirection.right) {
      return child;
    }
    return AppScrollbar(child: child);
  }
}

/// Short name used by every list in the app; carries the reference app's
/// constant-deceleration fling and carried momentum.
class MotionScrollPhysics extends MotionBouncingPhysics {
  const MotionScrollPhysics({super.parent, super.decelerationRate});
}
