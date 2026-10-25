import 'package:flutter/services.dart';

/// One switch for every vibration the motion layer emits. Haptics belong on
/// threshold crossings, not on every release.
abstract final class MotionHaptics {
  /// Set from settings; when false every call is a no-op.
  static bool enabled = true;

  static void selection() {
    if (!enabled) return;
    HapticFeedback.selectionClick();
  }

  static void light() {
    if (!enabled) return;
    HapticFeedback.lightImpact();
  }

  static void medium() {
    if (!enabled) return;
    HapticFeedback.mediumImpact();
  }

  static void heavy() {
    if (!enabled) return;
    HapticFeedback.heavyImpact();
  }
}
