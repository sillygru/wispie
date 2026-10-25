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

/// Drag surface: raw listener for velocity, gesture detector for the drag, and
/// the bottom-edge and disabled guards. Callers decide what the drag means.
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
    this.dragStartBehavior = DragStartBehavior.down,
    this.behavior = HitTestBehavior.translucent,
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

  /// `down` reports the position where the finger landed, not where the drag
  /// was recognised, which is what an edge test needs.
  final DragStartBehavior dragStartBehavior;

  final HitTestBehavior behavior;

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
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: _onPointerDown,
      onPointerMove: _onPointerMove,
      child: GestureDetector(
        behavior: widget.behavior,
        dragStartBehavior: widget.dragStartBehavior,
        onVerticalDragStart: _isVertical && widget.enabled ? _start : null,
        onVerticalDragUpdate: _isVertical && widget.enabled ? _update : null,
        onVerticalDragEnd: _isVertical && widget.enabled ? _end : null,
        onVerticalDragCancel: _isVertical && widget.enabled ? _cancel : null,
        onHorizontalDragStart: !_isVertical && widget.enabled ? _start : null,
        onHorizontalDragUpdate: !_isVertical && widget.enabled ? _update : null,
        onHorizontalDragEnd: !_isVertical && widget.enabled ? _end : null,
        onHorizontalDragCancel: !_isVertical && widget.enabled ? _cancel : null,
        child: widget.child,
      ),
    );
  }
}
