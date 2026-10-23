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

  // While the finger owns the sheet it tracks 1:1 (linear), never through
  // the open/close curves, so slow drags feel physically attached.
  bool _gestureDriven = false;

  void dismissDragStart() {
    final c = controller;
    if (c == null || _dragging) return;
    if (_settling) {
      // Re-grabbing a running settle keeps the existing gesture claim.
      _settling = false;
      c.stop();
    } else {
      if (c.isAnimating || !isCurrent) return;
      navigator?.didStartUserGesture();
    }
    _dragging = true;
    _gestureDriven = true;
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
    final close = v.abs() > 0.3 ? v > 0 : c.value < 0.6;
    _settle(close ? 0 : 1, -v);
  }

  void dismissDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _settle(1, 0);
  }

  // Popped only once landed closed, so a late grab can still pull it back.
  void _settle(double target, double velocity) {
    final c = controller!;
    _settling = true;
    c.animateWith(_SnapSimulation(c.value, target, velocity)).then((_) {
      if (!_settling) return;
      _settling = false;
      final nav = navigator;
      nav?.didStopUserGesture();
      if (target == 0) {
        if (nav != null && isActive) nav.removeRoute(this);
      } else {
        _gestureDriven = false;
      }
    });
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
    final primary = CurvedAnimation(
      parent: animation,
      curve: PlayerTokens.cEmphasizedDecel,
      reverseCurve: PlayerTokens.cEmphasizedAccel,
    );
    // Content only melts into the mini player over the last stretch.
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.3, curve: Curves.easeOut),
    );

    return Stack(
      children: [
        FadeTransition(
          opacity: animation,
          child: Container(color: Colors.black.withValues(alpha: 0.46)),
        ),
        AnimatedBuilder(
          animation: primary,
          child: FadeTransition(opacity: fade, child: child),
          builder: (context, child) {
            final double t = (_gestureDriven ? animation.value : primary.value)
                .clamp(0.0, 1.0);
            final double radius = (1 - t) * PlayerTokens.rLg;
            // Structure stays fixed (only clip mode changes) so the player
            // subtree is never remounted when the animation settles.
            return FractionalTranslation(
              translation: Offset(0, 1 - t),
              child: ClipRRect(
                clipBehavior: radius < 0.5 ? Clip.none : Clip.antiAlias,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius),
                ),
                child: child,
              ),
            );
          },
        ),
      ],
    );
  }

  @override
  Widget buildModalBarrier() {
    return const SizedBox.shrink();
  }
}

/// Critically damped, no bounce. A close aims slightly past 0 and ends on
/// crossing it, so the sheet lands with intent instead of creeping in; any
/// overshoot past either end finishes immediately.
class _SnapSimulation extends Simulation {
  _SnapSimulation(double from, this._target, double velocity)
      : _spring = SpringSimulation(
          SpringDescription.withDampingRatio(
            mass: 1,
            stiffness: 520,
            ratio: 1,
          ),
          from,
          _target == 0 ? -0.08 : _target,
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
