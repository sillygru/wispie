import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';

import '../../services/audio_player_manager.dart';
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
  late final AnimationController _drag =
      AnimationController.unbounded(vsync: this, value: 0);
  late T _current = widget.item;
  T? _previous;
  int _dir = 1;
  int? _pendingSwipe;
  int _swipeGeneration = 0;
  double _width = 1;
  Timer? _pendingTimeout;

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
    _drag.stop();
    _drag.value = 0;
    _c.value = 0;
    _c.animateTo(
      1,
      duration: PlayerTokens.dTrackSwitch,
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

  void _onHorizontalDragStart(DragStartDetails details) {
    if (widget.onSwipe == null) return;
    _swipeGeneration++;
    _pendingSwipe = null;
    _pendingTimeout?.cancel();
    _drag.stop();
  }

  void _onHorizontalDragUpdate(DragUpdateDetails details) {
    if (widget.onSwipe == null || _width <= 0) return;
    final next = (_drag.value + details.delta.dx / _width).clamp(-1.0, 1.0);
    _drag.value = next;
  }

  void _onHorizontalDragEnd(DragEndDetails details) {
    if (widget.onSwipe == null) return;
    final x = _drag.value;
    if (x == 0) return;
    final rawVelocity = details.primaryVelocity ?? 0;
    final velocity = rawVelocity / _width;
    final direction = x < 0 ? 1 : -1;
    final fling = rawVelocity.abs() > 1000 && rawVelocity.sign == x.sign;
    final far = x.abs() > 0.28;
    final canSwipe = widget.canSwipe?.call(direction) ?? true;
    if ((fling || far) && canSwipe) {
      final generation = ++_swipeGeneration;
      _pendingSwipe = direction;
      _drag
          .animateTo(
        -direction.toDouble(),
        duration: PlayerTokens.dFast,
        curve: Curves.easeIn,
      )
          .whenComplete(() {
        if (!mounted ||
            generation != _swipeGeneration ||
            _pendingSwipe != direction) {
          return;
        }
        widget.onSwipe!(direction);
        _pendingTimeout?.cancel();
        _pendingTimeout = Timer(PlayerTokens.dTrackSwitchTimeout, () {
          if (!mounted ||
              generation != _swipeGeneration ||
              _pendingSwipe != direction) {
            return;
          }
          _pendingSwipe = null;
          _drag.animateWith(
            SpringSimulation(_dragSpring, _drag.value, 0, 0),
          );
        });
      });
      return;
    }
    _drag.animateWith(SpringSimulation(_dragSpring, x, 0, velocity));
  }

  @override
  Widget build(BuildContext context) {
    final T? previous = _previous;
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
                  final double t = _c.value;
                  final double k = t.clamp(0.0, 1.0);
                  return FractionalTranslation(
                    translation: Offset(-_dir * widget.travel * t, 0),
                    child: Opacity(
                      opacity: (1 - widget.fade * k).clamp(0.0, 1.0),
                      child: Transform.scale(scale: 1 - 0.08 * k, child: child),
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
              final double t = _c.value;
              final double k = t.clamp(0.0, 1.0);
              return FractionalTranslation(
                translation: Offset(_dir * widget.travel * (1 - t), 0),
                child: Opacity(
                  opacity: (1 - widget.fade * (1 - k)).clamp(0.0, 1.0),
                  child: child,
                ),
              );
            },
          ),
        ),
      ],
    );
    if (widget.onSwipe == null) return stack;
    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: _onHorizontalDragStart,
          onHorizontalDragUpdate: _onHorizontalDragUpdate,
          onHorizontalDragEnd: _onHorizontalDragEnd,
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
