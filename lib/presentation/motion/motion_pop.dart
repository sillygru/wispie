import 'package:flutter/widgets.dart';

import 'motion_policy.dart';
import 'motion_springs.dart';

/// Pops its child with a spring whenever [trigger] changes.
///
/// A list that reorders — moving a row to the top, restoring a deleted row —
/// otherwise just teleports. A short scale pop is enough to tell the eye where
/// the row went, and because it is a spring it can be retriggered mid-pop.
class MotionPop extends StatefulWidget {
  const MotionPop({
    super.key,
    required this.trigger,
    required this.child,
    this.from = 0.92,
    this.spring = MotionSprings.bouncy,
  });

  /// Any value; a change starts a pop. Null never pops.
  final Object? trigger;

  final Widget child;

  /// Scale the pop starts from.
  final double from;

  final SpringDescription spring;

  @override
  State<MotionPop> createState() => _MotionPopState();
}

class _MotionPopState extends State<MotionPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController.unbounded(vsync: this, value: 1);

  Object? _playedFor;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MotionPolicy.of(context).reduceMotion;
    if (_reduceMotion) {
      _controller.stop();
      _controller.value = 1;
    }
    _maybePlay();
  }

  @override
  void didUpdateWidget(MotionPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.trigger, widget.trigger)) _maybePlay();
  }

  void _maybePlay() {
    final Object? trigger = widget.trigger;
    if (trigger == null || _reduceMotion) return;
    if (identical(trigger, _playedFor)) return;
    _playedFor = trigger;
    _controller.value = widget.from;
    MotionSprings.driveTo(_controller, 1, spring: widget.spring);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) =>
          Transform.scale(scale: _controller.value, child: child),
    );
  }
}
