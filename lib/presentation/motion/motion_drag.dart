import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';

/// Raw pointer velocity tracker. Reading from a [Listener] means release speed
/// is known even when the drag was recognised late, which makes a flick land.
class MotionDragTracker {
  MotionDragTracker({this.kind = PointerDeviceKind.touch});

  final PointerDeviceKind kind;
  VelocityTracker _tracker = VelocityTracker.withKind(PointerDeviceKind.touch);
  Offset _downPosition = Offset.zero;
  Offset _lastPosition = Offset.zero;

  Offset get downPosition => _downPosition;
  Offset get lastPosition => _lastPosition;
  Offset get totalDelta => _lastPosition - _downPosition;

  void start(PointerDownEvent event) {
    _tracker = VelocityTracker.withKind(event.kind);
    _downPosition = event.position;
    _lastPosition = event.position;
    _tracker.addPosition(event.timeStamp, event.position);
  }

  void add(PointerMoveEvent event) {
    _lastPosition = event.position;
    _tracker.addPosition(event.timeStamp, event.position);
  }

  Offset get velocity => _tracker.getVelocity().pixelsPerSecond;

  double velocityAlong(Axis axis) =>
      axis == Axis.vertical ? velocity.dy : velocity.dx;

  /// Drops the history. Call on release so a later drag cannot inherit it.
  void reset() {
    _tracker = VelocityTracker.withKind(kind);
    _downPosition = Offset.zero;
    _lastPosition = Offset.zero;
  }
}

/// Where a drag began, for surfaces that only accept edge drags.
class MotionDragStart {
  const MotionDragStart(this.globalPosition);

  final Offset globalPosition;
}

/// Release details for [MotionDragArea].
class MotionDragEnd {
  const MotionDragEnd({
    required this.velocity,
    required this.delta,
  });

  /// px/s on both axes.
  final Offset velocity;

  /// Net movement since the pointer went down.
  final Offset delta;

  double velocityAlong(Axis axis) =>
      axis == Axis.vertical ? velocity.dy : velocity.dx;
}

/// Drag surface: raw listener for velocity, a gesture arena entry for the drag,
/// and the bottom-edge and disabled guards. Callers decide what the drag means.
///
/// When [axisLock] is true (the default), the recognizer rejects as soon as the
/// cross-axis wins the slop race so a vertical list under this surface keeps
/// scrolling instead of losing the arena to a no-op horizontal claim.
class MotionDragArea extends StatefulWidget {
  const MotionDragArea({
    super.key,
    required this.child,
    required this.axis,
    required this.onStart,
    required this.onUpdate,
    required this.onEnd,
    this.onCancel,
    this.enabled = true,
    this.ignoreBottomInset = 0,
    this.dragStartBehavior = DragStartBehavior.start,
    this.behavior = HitTestBehavior.translucent,
    this.axisLock = true,
    this.edgePriorityWidth = 0,
  });

  final Widget child;
  final Axis axis;
  final ValueChanged<MotionDragStart> onStart;

  /// Primary-axis delta in logical pixels for this event.
  final ValueChanged<double> onUpdate;
  final ValueChanged<MotionDragEnd> onEnd;
  final VoidCallback? onCancel;
  final bool enabled;

  /// Touches this close to the bottom edge belong to the system gesture.
  final double ignoreBottomInset;

  /// `start` waits for the drag threshold so a competing scroll can win cleanly.
  final DragStartBehavior dragStartBehavior;

  final HitTestBehavior behavior;

  /// Reject when the cross-axis outruns the primary axis past touch slop.
  final bool axisLock;

  /// Width of the left-edge strip, in logical pixels, where a horizontal drag
  /// is claimed a few pixels in instead of after full touch slop.
  ///
  /// A horizontal scroller in the content is deeper in the hit-test path, so it
  /// sees the movement first and takes the gesture the moment it crosses its
  /// own slop. Claiming early inside the edge strip is what makes an edge swipe
  /// open the drawer over a carousel rather than scrolling the carousel.
  final double edgePriorityWidth;

  @override
  State<MotionDragArea> createState() => _MotionDragAreaState();
}

class _MotionDragAreaState extends State<MotionDragArea> {
  final MotionDragTracker _tracker = MotionDragTracker();
  bool _ignorePointer = false;
  bool _dragging = false;

  bool get _isVertical => widget.axis == Axis.vertical;

  void _onPointerDown(PointerDownEvent event) {
    final double bottom = MediaQuery.maybeSizeOf(context)?.height ?? 0;
    _ignorePointer = widget.ignoreBottomInset > 0 &&
        bottom > 0 &&
        event.position.dy >= bottom - widget.ignoreBottomInset;
    if (_ignorePointer) return;
    _tracker.start(event);
  }

  void _onPointerMove(PointerMoveEvent event) {
    if (_ignorePointer) return;
    _tracker.add(event);
  }

  void _start(DragStartDetails details) {
    if (!widget.enabled || _ignorePointer) return;
    _dragging = true;
    widget.onStart(MotionDragStart(details.globalPosition));
  }

  void _update(DragUpdateDetails details) {
    if (!_dragging) return;
    final double delta = details.primaryDelta ?? 0;
    widget.onUpdate(delta);
  }

  void _end(DragEndDetails details) {
    if (!_dragging) return;
    _dragging = false;
    final double tracked = _tracker.velocityAlong(widget.axis);
    final double reported = details.primaryVelocity ?? 0;
    final double velocity =
        tracked.isFinite && tracked.abs() > 1 ? tracked : reported;
    widget.onEnd(
      MotionDragEnd(
        velocity: Offset(
          _isVertical ? 0 : velocity,
          _isVertical ? velocity : 0,
        ),
        delta: _tracker.totalDelta,
      ),
    );
    _tracker.reset();
  }

  void _cancel() {
    if (!_dragging) return;
    _dragging = false;
    widget.onCancel?.call();
    _tracker.reset();
  }

  @override
  void didUpdateWidget(MotionDragArea oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A recognizer dropped mid-gesture (axis or enabled changed) never reports
    // its end, which would leave the caller stuck in a dragging state forever.
    // Deferred: the callback usually rebuilds, and this runs mid-build.
    if (_dragging && (!widget.enabled || oldWidget.axis != widget.axis)) {
      _dragging = false;
      final cancel = widget.onCancel;
      if (cancel != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => cancel());
      }
    }
  }

  Map<Type, GestureRecognizerFactory> _buildRecognizers() {
    if (!widget.enabled) return const <Type, GestureRecognizerFactory>{};

    if (_isVertical) {
      return <Type, GestureRecognizerFactory>{
        _AxisLockedVerticalDragGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<
                _AxisLockedVerticalDragGestureRecognizer>(
          () => _AxisLockedVerticalDragGestureRecognizer(
            axisLock: widget.axisLock,
            debugOwner: this,
          ),
          (instance) {
            instance
              ..dragStartBehavior = widget.dragStartBehavior
              ..onStart = _start
              ..onUpdate = _update
              ..onEnd = _end
              ..onCancel = _cancel;
          },
        ),
      };
    }

    return <Type, GestureRecognizerFactory>{
      _AxisLockedHorizontalDragGestureRecognizer:
          GestureRecognizerFactoryWithHandlers<
              _AxisLockedHorizontalDragGestureRecognizer>(
        () => _AxisLockedHorizontalDragGestureRecognizer(
          axisLock: widget.axisLock,
          debugOwner: this,
          edgePriorityWidth: widget.edgePriorityWidth,
        ),
        (instance) {
          instance
            ..edgePriorityWidth = widget.edgePriorityWidth
            ..dragStartBehavior = widget.dragStartBehavior
            ..onStart = _start
            ..onUpdate = _update
            ..onEnd = _end
            ..onCancel = _cancel;
        },
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      child: RawGestureDetector(
        behavior: widget.behavior,
        gestures: _buildRecognizers(),
        child: widget.child,
      ),
    );
  }
}

/// [HorizontalDragGestureRecognizer] that leaves the arena when the finger
/// clearly means a vertical scroll, instead of claiming and no-opping.
class _AxisLockedHorizontalDragGestureRecognizer
    extends HorizontalDragGestureRecognizer {
  _AxisLockedHorizontalDragGestureRecognizer({
    required this.axisLock,
    required this.edgePriorityWidth,
    super.debugOwner,
  });

  final bool axisLock;
  double edgePriorityWidth;

  /// Enough to tell a swipe from a tap, early enough to beat a scroller's own
  /// slop.
  static const double _edgeSlop = 5;

  Offset _origin = Offset.zero;
  bool _decided = false;
  bool _startedInEdgeStrip = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origin = event.position;
    _decided = false;
    _startedInEdgeStrip =
        edgePriorityWidth > 0 && event.position.dx <= edgePriorityWidth;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (!_decided && event is PointerMoveEvent) {
      final Offset delta = event.position - _origin;
      final double dx = delta.dx.abs();
      final double dy = delta.dy.abs();
      final double slop = computeHitSlop(event.kind, gestureSettings);
      if (axisLock && dy > dx && dy > slop) {
        _decided = true;
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
      if (_startedInEdgeStrip && dx > dy && dx >= _edgeSlop) {
        // Claim it before the scroller under the content crosses its own slop
        // and takes the gesture, which left the drawer unopenable there.
        _decided = true;
        resolve(GestureDisposition.accepted);
      } else if (axisLock && dx > dy && dx > slop) {
        _decided = true;
      }
    }
    super.handleEvent(event);
  }

  @override
  String get debugDescription => 'axis-locked horizontal drag';
}

/// Vertical twin of [_AxisLockedHorizontalDragGestureRecognizer].
class _AxisLockedVerticalDragGestureRecognizer
    extends VerticalDragGestureRecognizer {
  _AxisLockedVerticalDragGestureRecognizer({
    required this.axisLock,
    super.debugOwner,
  });

  final bool axisLock;
  Offset _origin = Offset.zero;
  bool _decided = false;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _origin = event.position;
    _decided = false;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (axisLock && !_decided && event is PointerMoveEvent) {
      final Offset delta = event.position - _origin;
      final double dx = delta.dx.abs();
      final double dy = delta.dy.abs();
      final double slop = computeHitSlop(event.kind, gestureSettings);
      if (dx > dy && dx > slop) {
        _decided = true;
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
      if (dy > dx && dy > slop) {
        _decided = true;
      }
    }
    super.handleEvent(event);
  }

  @override
  String get debugDescription => 'axis-locked vertical drag';
}
