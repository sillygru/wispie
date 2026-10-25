import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import 'motion_policy.dart';
import 'motion_tokens.dart';

/// Makes [MotionEntrance] run once per id for the life of the list, so scrolling
/// back or a rebuild never replays the entrance.
class MotionEntranceLimiter extends StatefulWidget {
  const MotionEntranceLimiter({super.key, required this.child});

  final Widget child;

  @override
  State<MotionEntranceLimiter> createState() => _MotionEntranceLimiterState();
}

class _MotionEntranceLimiterState extends State<MotionEntranceLimiter> {
  final Set<Object> _seen = <Object>{};

  bool claim(Object id) {
    if (_seen.contains(id)) return false;
    _seen.add(id);
    return true;
  }

  void forget(Object id) => _seen.remove(id);

  void reset() => _seen.clear();

  @override
  Widget build(BuildContext context) {
    return MotionEntranceScope(claim: claim, child: widget.child);
  }
}

/// The limiter's lookup surface. Entrances claim themselves on first build.
class MotionEntranceScope extends InheritedWidget {
  const MotionEntranceScope({
    super.key,
    required this.claim,
    required super.child,
  });

  final bool Function(Object id) claim;

  static MotionEntranceScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionEntranceScope>();

  @override
  bool updateShouldNotify(MotionEntranceScope oldWidget) => false;
}

/// Marks a drag proxy so it never picks up an entrance: the proxy is rebuilt on
/// every move and would flicker under the finger.
class MotionReorderProxyScope extends InheritedWidget {
  const MotionReorderProxyScope({
    super.key,
    required super.child,
  });

  static bool isWithin(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MotionReorderProxyScope>() !=
      null;

  @override
  bool updateShouldNotify(MotionReorderProxyScope oldWidget) => false;
}

/// One item's entrance: a short rise and fade, staggered by index. Static when
/// already seen, inside a reorder proxy, or under reduced motion.
class MotionEntrance extends StatefulWidget {
  const MotionEntrance({
    super.key,
    required this.id,
    required this.index,
    required this.child,
    this.duration = MotionTokens.entrance,
    this.offset = 24,
    this.enabled = true,
  });

  /// Stable within the limiter — an index is enough for a static list.
  final Object id;

  /// Position in the list, used for the stagger.
  final int index;

  final Widget child;
  final Duration duration;

  /// Vertical travel in logical pixels, applied from below as the item fades in.
  final double offset;

  final bool enabled;

  @override
  State<MotionEntrance> createState() => _MotionEntranceState();
}

class _MotionEntranceState extends State<MotionEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: MotionTokens.standardCurve,
  );

  bool _decided = false;
  Timer? _delay;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_decided) return;
    _decided = true;

    final MotionPolicy policy = MotionPolicy.of(context);
    final bool skipProxy = MotionReorderProxyScope.isWithin(context);
    final bool claimed =
        MotionEntranceScope.maybeOf(context)?.claim(widget.id) ?? true;

    if (!widget.enabled || skipProxy || policy.reduceMotion || !claimed) {
      _controller.value = 1;
      return;
    }

    _controller.value = 0;
    final Duration delay = policy.stagger(widget.index);
    if (delay <= Duration.zero) {
      _controller.forward();
    } else {
      _delay = Timer(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _curve,
      child: widget.child,
      builder: (context, child) {
        final double t = _curve.value;
        if (t >= 1) return child!;
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, widget.offset * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }
}

/// Grid entrance duration: a row's items split one beat between them, so a
/// dense grid is not slow just because it has many columns.
Duration motionGridEntranceDuration(int countPerRow) {
  final int columns = math.max(1, countPerRow);
  final int ms = (MotionTokens.entrance.inMilliseconds / columns)
      .clamp(100, MotionTokens.entrance.inMilliseconds)
      .round();
  return Duration(milliseconds: ms);
}

/// Stagger step for a grid, matched to the shorter row duration.
Duration motionGridEntranceStep(int countPerRow) {
  final int columns = math.max(1, countPerRow);
  return Duration(
    milliseconds:
        (motionGridEntranceDuration(countPerRow).inMilliseconds / columns)
            .clamp(16, 60)
            .round(),
  );
}
