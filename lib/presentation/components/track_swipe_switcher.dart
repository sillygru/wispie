import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/audio_player_manager.dart';
import '../motion/motion.dart';
import '../tokens/player_tokens.dart';

/// Carousel-style track change: the outgoing item slides off in the skip
/// direction while the new one slides in behind it on a spring, the way a
/// swipe would move them, instead of crossfading in place.
///
/// [builder] gets `current: false` for the outgoing copy so callers can drop
/// anything that must exist once (GlobalKeys, video surfaces).
class TrackSwipeSwitcher<T> extends StatefulWidget {
  final T item;
  final String Function(T item) idOf;
  final Widget Function(BuildContext context, T item, bool current) builder;

  /// Used to tell next from previous when no explicit [hint] was given.
  final AudioPlayerManager? audioManager;

  /// Distance travelled, as a fraction of this widget's width.
  final double travel;

  /// How much the outgoing copy fades (0 none, 1 fully) and the incoming one
  /// fades in.
  final double fade;
  final ValueChanged<int>? onSwipe;
  final bool Function(int direction)? canSwipe;

  /// When false the stack still animates track changes but installs no drag
  /// recognizer, so horizontal swipes reach the pane pager behind it.
  final bool swipeEnabled;

  const TrackSwipeSwitcher({
    super.key,
    required this.item,
    required this.idOf,
    required this.builder,
    this.audioManager,
    this.travel = 1.0,
    this.fade = 0.4,
    this.onSwipe,
    this.canSwipe,
    this.swipeEnabled = true,
  });

  static int? _hintDir;
  static DateTime? _hintAt;

  /// Records the direction of a user skip (+1 next, -1 previous) so the next
  /// track change slides the right way even across repeat-all wraps.
  static void hint(int direction) {
    _hintDir = direction;
    _hintAt = DateTime.now();
  }

  @override
  State<TrackSwipeSwitcher<T>> createState() => _TrackSwipeSwitcherState<T>();
}

class _TrackSwipeSwitcherState<T> extends State<TrackSwipeSwitcher<T>>
    with TickerProviderStateMixin {
  static final SpringDescription _dragSpring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 320, ratio: 0.88);

  late final AnimationController _c =
      AnimationController.unbounded(vsync: this, value: 1)
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && _previous != null) {
            setState(() => _previous = null);
          }
        });

  /// Continuous finger position, -1 previous … 0 current … 1 next.
  late final AnimationController _drag =
      AnimationController.unbounded(vsync: this, value: 0);

  late final SnapEngine _snap = SnapEngine(_drag);

  late T _current = widget.item;
  T? _previous;
  int _dir = 1;
  int? _pendingSwipe;
  int _swipeGeneration = 0;
  double _width = 1;
  Timer? _pendingTimeout;
  bool _reduceMotion = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduceMotion = MotionPolicy.of(context).reduceMotion;
  }

  @override
  void didUpdateWidget(covariant TrackSwipeSwitcher<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final String newId = widget.idOf(widget.item);
    final String oldId = widget.idOf(_current);
    if (newId == oldId) {
      _current = widget.item;
      return;
    }
    _dir = _directionFor(oldId, newId);
    _previous = _current;
    _current = widget.item;
    _pendingSwipe = null;
    _swipeGeneration++;
    _pendingTimeout?.cancel();
    _pendingTimeout = null;
    _snap.cancel();
    _drag.value = 0;
    _c.value = 0;
    _c.animateTo(
      1,
      duration: _reduceMotion ? Duration.zero : PlayerTokens.dTrackSwitch,
      curve: PlayerTokens.cTrackSwitch,
    );
  }

  int _directionFor(String oldId, String newId) {
    final DateTime? at = TrackSwipeSwitcher._hintAt;
    final int? hinted = TrackSwipeSwitcher._hintDir;
    if (hinted != null &&
        at != null &&
        DateTime.now().difference(at) < const Duration(milliseconds: 1500)) {
      return hinted;
    }
    final queue = widget.audioManager?.queueNotifier.value;
    if (queue == null) return 1;
    final int o = queue.indexWhere((q) => q.song.filename == oldId);
    final int n = queue.indexWhere((q) => q.song.filename == newId);
    if (o < 0 || n < 0) return 1;
    return n >= o ? 1 : -1;
  }

  @override
  void dispose() {
    _pendingTimeout?.cancel();
    _drag.dispose();
    _c.dispose();
    super.dispose();
  }

  void _onDragStart(MotionDragStart _) {
    // A new touch owns the motion: freeze any settle where it is, so the drag
    // starts from what is drawn rather than from the old target.
    _swipeGeneration++;
    _pendingSwipe = null;
    _pendingTimeout?.cancel();
    _pendingTimeout = null;
    _snap.cancel();
  }

  void _onDragUpdate(double delta) {
    if (_width <= 0) return;
    _drag.value = (_drag.value + delta / _width).clamp(-1.0, 1.0);
  }

  void _onDragEnd(MotionDragEnd end) {
    final double x = _drag.value;
    if (x == 0) return;
    final int? direction = decideCarouselSwipe(
      progress: x,
      velocity: end.velocity.dx,
      extent: _width,
      canGoNext: widget.canSwipe?.call(1) ?? true,
      canGoPrevious: widget.canSwipe?.call(-1) ?? true,
    );
    if (direction == null) {
      _springHome();
      return;
    }
    _commit(direction);
  }

  void _onDragCancel() => _springHome();

  void _springHome() {
    if (_reduceMotion) {
      _snap.jumpTo(0);
    } else {
      _snap.springTo(0, spring: _dragSpring);
    }
  }

  Future<void> _commit(int direction) async {
    final int generation = ++_swipeGeneration;
    _pendingSwipe = direction;
    await _snap.snapTo(
      -direction.toDouble(),
      duration: _reduceMotion ? Duration.zero : MotionTokens.fast,
      curve: MotionTokens.exitCurve,
    );
    if (!mounted ||
        generation != _swipeGeneration ||
        _pendingSwipe != direction) {
      return;
    }
    widget.onSwipe!(direction);
    _pendingTimeout?.cancel();
    // If the player never reports the new track, spring the stack back rather
    // than leaving it parked off-centre.
    _pendingTimeout = Timer(PlayerTokens.dTrackSwitchTimeout, () {
      if (!mounted ||
          generation != _swipeGeneration ||
          _pendingSwipe != direction) {
        return;
      }
      _pendingSwipe = null;
      _springHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    final T? previous = _previous;
    final double stackWidth = _width * widget.travel;

    // Children are built once per item change; only the transforms tick.
    final stack = Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        if (previous != null)
          KeyedSubtree(
            key: ValueKey<String>('out_${widget.idOf(previous)}'),
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _c,
                child: RepaintBoundary(
                  child: widget.builder(context, previous, false),
                ),
                builder: (context, child) {
                  final double t = _c.value.clamp(0.0, 1.0);
                  return Transform.translate(
                    offset: Offset(
                      carouselSlotTravel(
                        progress: t,
                        width: stackWidth,
                        direction: -_dir,
                      ),
                      0,
                    ),
                    child: Opacity(
                      opacity: (1 - widget.fade * t).clamp(0.0, 1.0),
                      child: Transform.scale(
                        scale: 1 - 0.08 * t,
                        child: child,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        KeyedSubtree(
          key: ValueKey<String>('in_${widget.idOf(_current)}'),
          child: AnimatedBuilder(
            animation: _c,
            child: RepaintBoundary(
              child: widget.builder(context, _current, true),
            ),
            builder: (context, child) {
              final double t = _c.value.clamp(0.0, 1.0);
              return Transform.translate(
                offset: Offset(
                  // The arriving copy travels a little further than the finger,
                  // which gives the outgoing one depth behind it.
                  carouselSlotTravel(
                    progress: 1 - t,
                    width: stackWidth,
                    direction: _dir,
                    parallax: 1.15,
                  ),
                  0,
                ),
                child: Opacity(
                  opacity: (1 - widget.fade * (1 - t)).clamp(0.0, 1.0),
                  child: Transform.scale(
                    scale: 0.96 + 0.04 * t,
                    child: child,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );

    if (widget.onSwipe == null || !widget.swipeEnabled) return stack;

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return MotionDragArea(
          axis: Axis.horizontal,
          onStart: _onDragStart,
          onUpdate: _onDragUpdate,
          onEnd: _onDragEnd,
          onCancel: _onDragCancel,
          child: AnimatedBuilder(
            animation: _drag,
            child: stack,
            builder: (context, child) => Transform.translate(
              offset: Offset(_drag.value * _width, 0),
              child: child,
            ),
          ),
        );
      },
    );
  }
}
