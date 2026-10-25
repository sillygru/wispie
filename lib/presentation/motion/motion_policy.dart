import 'package:flutter/widgets.dart';

import 'motion_tokens.dart';

/// One answer to "how long should this take?" and "may this run at all?".
/// Reduced motion never disables an interaction, only its visual transition.
class MotionPolicy {
  const MotionPolicy({this.reduceMotion = false});

  /// The platform setting, or an explicit app/test override.
  final bool reduceMotion;

  /// Everything animates.
  static const MotionPolicy full = MotionPolicy();

  /// Nothing does. Useful in tests and in a preview harness.
  static const MotionPolicy reduced = MotionPolicy(reduceMotion: true);

  /// For code that runs above the app's [MediaQuery] — the root theme tween,
  /// mainly. Prefer [of] everywhere else.
  factory MotionPolicy.fromPlatform() {
    final features =
        WidgetsBinding.instance.platformDispatcher.accessibilityFeatures;
    return MotionPolicy(reduceMotion: features.disableAnimations);
  }

  static MotionPolicy of(BuildContext context) {
    final override =
        context.dependOnInheritedWidgetOfExactType<MotionScope>()?.policy;
    if (override != null) return override;
    return MotionPolicy(
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
  }

  /// A one-shot read, for callbacks that run outside build.
  static MotionPolicy read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<MotionScope>();
    if (scope != null) return scope.policy;
    return MotionPolicy(
      reduceMotion: MediaQuery.maybeDisableAnimationsOf(context) ?? false,
    );
  }

  static bool isReduced(BuildContext context) => read(context).reduceMotion;

  bool get animates => !reduceMotion;

  /// [duration], or zero when motion is reduced.
  Duration duration(Duration duration) =>
      reduceMotion ? Duration.zero : duration;

  /// Stagger delay for [index], capped so a long list's last row does not wait.
  Duration stagger(
    int index, {
    Duration step = MotionTokens.entranceStep,
    Duration cap = MotionTokens.entranceMaxDelay,
  }) {
    if (reduceMotion || index <= 0) return Duration.zero;
    final delay = step * index;
    return delay > cap ? cap : delay;
  }

  /// Curves are left alone; a reduced run lasts zero time anyway.
  Curve curve(Curve curve) => curve;

  /// Delays an entrance; resolves immediately under reduced motion.
  Future<void> wait(Duration delay) {
    if (reduceMotion || delay <= Duration.zero) {
      return Future<void>.value();
    }
    return Future<void>.delayed(delay);
  }
}

/// Applies a [MotionPolicy] to a subtree, overriding the platform flag without
/// touching a single animation call site.
class MotionScope extends InheritedWidget {
  const MotionScope({
    super.key,
    required this.policy,
    required super.child,
  });

  final MotionPolicy policy;

  static MotionPolicy? maybePolicyOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionScope>()?.policy;

  @override
  bool updateShouldNotify(MotionScope oldWidget) =>
      oldWidget.policy.reduceMotion != policy.reduceMotion;
}
