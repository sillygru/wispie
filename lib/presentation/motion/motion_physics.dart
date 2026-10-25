import 'package:flutter/material.dart';

import 'scroll_physics_modified.dart';

/// The app's one scroll feel. Material's behaviour with our physics, so lists
/// still get the platform's scrollbars, glow suppression and drag devices.
class MotionScrollBehavior extends MaterialScrollBehavior {
  const MotionScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) =>
      const MotionScrollPhysics();
}

/// Short name used by every list in the app; carries the reference app's
/// constant-deceleration fling and carried momentum.
class MotionScrollPhysics extends MotionBouncingPhysics {
  const MotionScrollPhysics({super.parent, super.decelerationRate});
}
