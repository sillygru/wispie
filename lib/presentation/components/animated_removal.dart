import 'dart:async';

import 'package:flutter/material.dart';

import '../motion/motion_policy.dart';
import '../motion/motion_tokens.dart';

/// Lets a list row play an exit before the data behind it is deleted.
///
/// Call [AnimatedRemoval.run] with the row's id and the real delete; every
/// [RemovableEntry] with that id shrinks and fades out first, then the commit
/// runs and the row leaves the data for good. Rows that are not being removed
/// pay nothing.
class AnimatedRemoval {
  AnimatedRemoval._();

  static final ValueNotifier<Set<String>> removing =
      ValueNotifier<Set<String>>(<String>{});

  /// [exit] is how long the row gets to leave; pass the policy's duration so a
  /// reduced-motion run commits without waiting for an animation that is not
  /// playing.
  static Future<void> run(
    String id,
    FutureOr<void> Function() commit, {
    Duration exit = MotionTokens.slow,
  }) async {
    removing.value = {...removing.value, id};
    if (exit > Duration.zero) await Future<void>.delayed(exit);
    try {
      await commit();
    } finally {
      removing.value = {...removing.value}..remove(id);
    }
  }
}

class RemovableEntry extends StatefulWidget {
  final String id;
  final Widget child;

  const RemovableEntry({super.key, required this.id, required this.child});

  @override
  State<RemovableEntry> createState() => _RemovableEntryState();
}

class _RemovableEntryState extends State<RemovableEntry>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: MotionTokens.slow,
    value: 1,
  );
  late final Animation<double> _size = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.0, 0.7, curve: MotionTokens.inOutCurve),
  );
  late final Animation<double> _fade = CurvedAnimation(
    parent: _controller,
    curve: const Interval(0.45, 1.0, curve: MotionTokens.standardCurve),
  );
  late final Animation<double> _scale =
      Tween<double>(begin: 0.9, end: 1).animate(_fade);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _controller.duration = MotionPolicy.of(context).duration(MotionTokens.slow);
  }

  @override
  void initState() {
    super.initState();
    AnimatedRemoval.removing.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    AnimatedRemoval.removing.removeListener(_sync);
    _controller.dispose();
    super.dispose();
  }

  void _sync() {
    final bool leaving = AnimatedRemoval.removing.value.contains(widget.id);
    if (leaving &&
        _controller.value > 0 &&
        _controller.status != AnimationStatus.reverse) {
      _controller.reverse();
    } else if (!leaving && _controller.value < 1) {
      _controller.forward();
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizeTransition(
      sizeFactor: _size,
      alignment: Alignment.topCenter,
      child: FadeTransition(
        opacity: _fade,
        child: ScaleTransition(scale: _scale, child: widget.child),
      ),
    );
  }
}
