import 'package:flutter/material.dart';
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

  @override
  bool get opaque => false;

  @override
  bool get barrierDismissible => true;

  @override
  Color get barrierColor => Colors.transparent;

  @override
  String get barrierLabel => 'Dismiss player';

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
    return UnifiedPlayerScreen(
      initialPane: initialPane,
      queueShowsHistory: queueShowsHistory,
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
    final fade = CurvedAnimation(
      parent: animation,
      curve: const Interval(0.0, 0.45, curve: Curves.easeOut),
      reverseCurve: const Interval(0.35, 1.0, curve: Curves.easeIn),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(primary);

    return Stack(
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
              final double radius = (1 - t) * PlayerTokens.rLg;
              // Structure stays fixed (only clip mode changes) so the player
              // subtree is never remounted when the animation settles.
              return ClipRRect(
                clipBehavior: radius < 0.5 ? Clip.none : Clip.antiAlias,
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(radius),
                ),
                child: Transform.scale(
                  scale: 0.94 + 0.06 * t,
                  alignment: Alignment.bottomCenter,
                  child: child,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  @override
  Widget buildModalBarrier() {
    return const SizedBox.shrink();
  }
}
