import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../widgets/collection_accent_scope.dart';
import '../screens/unified_player_screen.dart';
import '../tokens/player_tokens.dart';

class PlayerPageRoute extends PageRoute<void> {
  PlayerPageRoute({
    this.songId,
    this.initialPane = PlayerPane.player,
    this.queueShowsHistory = false,
  });

  /// Kept for callers that open the player for a specific track; the screen
  /// itself always follows whatever the player is currently playing.
  final String? songId;

  final PlayerPane initialPane;

  /// Opens the Queue pane on its History segment rather than Up Next.
  final bool queueShowsHistory;

  bool _dragging = false;
  bool _settling = false;

  // While the finger owns the sheet it tracks linearly instead of through
  // the open/close curves, so the sheet stays attached to the finger.
  bool _gestureDriven = false;

  // The user-gesture claim lets Hero flights (cover, transport buttons)
  // follow the finger, but it also makes the framework ignore pointers on
  // the page. This flag swaps in a catch-all detector so a settling sheet
  // can still be grabbed back.
  final ValueNotifier<bool> _catchable = ValueNotifier(false);

  void dismissDragStart() {
    final c = controller;
    final nav = navigator;
    if (c == null || nav == null || _dragging) return;
    if (_settling) {
      _settling = false;
      c.stop();
    } else {
      if (!isCurrent) return;
      if (c.isAnimating) {
        // Grabbed mid-open: continue from where the curved sheet is drawn.
        final shown = PlayerTokens.cEmphasizedDecel.transform(c.value);
        c.stop();
        c.value = _invertCurve(shown);
      }
      nav.didStartUserGesture();
    }
    _dragging = true;
    _gestureDriven = true;
  }

  static double _invertCurve(double y) {
    double lo = 0, hi = 1;
    for (var i = 0; i < 24; i++) {
      final mid = (lo + hi) / 2;
      if (PlayerTokens.cEmphasizedDecel.transform(mid) < y) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return (lo + hi) / 2;
  }

  void dismissDragUpdate(double dy, double height) {
    final c = controller;
    if (!_dragging || c == null || height <= 0) return;
    c.value = c.value - dy / height;
  }

  /// [velocity] is px/s, positive downward.
  void dismissDragEnd(double velocity, double height) {
    final c = controller;
    if (!_dragging || c == null) return;
    _dragging = false;
    final v = height > 0 ? velocity / height : 0.0;
    // Final flick direction wins, so down-then-quickly-up reopens.
    final close = v.abs() > 0.25 ? v > 0 : c.value < 0.6;
    _settle(close ? 0 : 1, -v);
  }

  void dismissDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _settle(1, 0);
  }

  // Popped only once landed, so a late grab can still pull it back.
  void _settle(double target, double velocity) {
    final c = controller!;
    _settling = true;
    _catchable.value = true;
    c.animateWith(_SnapSimulation(c.value, target, velocity)).then((_) {
      if (!_settling) return;
      _settling = false;
      final nav = navigator;
      if (target == 0 && nav != null && isActive) nav.pop();
      if (target == 1) {
        _gestureDriven = false;
        _catchable.value = false;
      }
      // After the pop: Hero flights finish against the landed animation.
      nav?.didStopUserGesture();
    });
  }

  @override
  void dispose() {
    _catchable.dispose();
    super.dispose();
  }

  @override
  bool get opaque => false;

  @override
  String? get barrierLabel => null;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  bool get maintainState => true;

  @override
  void install() {
    super.install();
    _catchable.value = true;
    animation!.addStatusListener((status) {
      if (status == AnimationStatus.completed && !_settling && !_dragging) {
        _catchable.value = false;
      }
    });
  }

  @override
  Duration get transitionDuration => PlayerTokens.dRouteIn;

  @override
  Duration get reverseTransitionDuration => PlayerTokens.dRouteOut;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    // Re-roots theme and accent on the playing track so an artist/album
    // override from the page underneath cannot leak into the player.
    return Consumer(
      builder: (context, ref, child) {
        final themeState = ref.watch(themeProvider);
        final accent = themeState.extractedColor;
        if (accent == null) {
          return Theme(
            data: AppTheme.getTheme(themeState),
            child: child!,
          );
        }
        return Theme(
          data: AppTheme.getPlayerTheme(themeState, accent),
          child: CollectionAccentScope(
            accent: accent,
            isNeutral: themeState.isNeutralCover,
            child: child!,
          ),
        );
      },
      child: UnifiedPlayerScreen(
        initialPane: initialPane,
        queueShowsHistory: queueShowsHistory,
      ),
    );
  }

  @override
  Widget buildTransitions(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    // Rises from the mini player's edge rather than fading in place: the
    // sheet travels most of the way fast and lands softly, so it reads as the
    // bar expanding instead of a page swap.
    final Animation<double> primary = _GestureAwareAnimation(
      CurvedAnimation(
        parent: animation,
        curve: PlayerTokens.cEmphasizedDecel,
        reverseCurve: Curves.linear,
      ),
      animation,
      () => _gestureDriven,
    );
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      reverseCurve: Curves.linear,
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 1),
      end: Offset.zero,
    ).animate(primary);

    final Widget stack = Stack(
      children: [
        FadeTransition(
          opacity: fade,
          child: Container(color: Colors.black.withValues(alpha: 0.46)),
        ),
        SlideTransition(
          position: slide,
          child: AnimatedBuilder(
            animation: primary,
            child: FadeTransition(opacity: fade, child: child),
            builder: (context, child) {
              final double t = primary.value.clamp(0.0, 1.0);
              final double radius =
                  PlayerTokens.flightRadius(t, 0, PlayerTokens.rSheetFlight);
              // Structure stays fixed (only clip mode changes) so the player
              // subtree is never remounted when the animation settles.
              return ClipRRect(
                clipBehavior: radius < 0.5 ? Clip.none : Clip.antiAlias,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius),
                ),
                child: child,
              );
            },
          ),
        ),
      ],
    );
    return ValueListenableBuilder<bool>(
      valueListenable: _catchable,
      child: stack,
      builder: (context, catchable, stack) {
        final double height = MediaQuery.sizeOf(context).height;
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onVerticalDragStart: catchable ? (_) => dismissDragStart() : null,
          onVerticalDragUpdate:
              catchable ? (d) => dismissDragUpdate(d.delta.dy, height) : null,
          onVerticalDragEnd: catchable
              ? (d) => dismissDragEnd(d.primaryVelocity ?? 0, height)
              : null,
          onVerticalDragCancel: catchable ? dismissDragCancel : null,
          child: stack,
        );
      },
    );
  }

  @override
  Widget buildModalBarrier() {
    return const SizedBox.shrink();
  }
}

/// Raw (linear) value while a drag owns the route, curved otherwise. Both
/// agree at 0 and 1, so switching never jumps.
class _GestureAwareAnimation extends Animation<double>
    with AnimationWithParentMixin<double> {
  _GestureAwareAnimation(this._curved, this.parent, this._linear);

  final Animation<double> _curved;
  final bool Function() _linear;

  @override
  final Animation<double> parent;

  @override
  double get value => _linear() ? parent.value : _curved.value;
}

/// Critically damped, no bounce; ends the moment it reaches or crosses the
/// target instead of creeping through a long tail.
class _SnapSimulation extends Simulation {
  _SnapSimulation(double from, this._target, double velocity)
      : _spring = SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: 420,
            ratio: 1,
          ),
          from,
          _target == 0 ? -0.06 : _target,
          velocity,
          tolerance: const Tolerance(distance: 0.001, velocity: 0.01),
        );

  final double _target;
  final SpringSimulation _spring;

  @override
  double x(double time) => _spring.x(time).clamp(0.0, 1.0);

  @override
  double dx(double time) => _spring.dx(time);

  @override
  bool isDone(double time) {
    final x = _spring.x(time);
    return _spring.isDone(time) || (_target == 0 ? x <= 0 : x >= 1);
  }
}
