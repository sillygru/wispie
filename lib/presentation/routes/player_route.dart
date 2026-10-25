import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';
import '../widgets/collection_accent_scope.dart';
import '../screens/unified_player_screen.dart';
import 'player_sheet_origin.dart';
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

  /// Drives every release of the sheet. Its generation tokens make a settle
  /// that a newer grab overtook a no-op, so completion effects cannot fire twice.
  late final SnapEngine _snap = SnapEngine(controller!);
  // Tracks whether nav.didStartUserGesture() was actually called, so the stop
  // call stays balanced when a grab happens mid-open and no gesture was started.
  bool _gestureHeld = false;

  // The user-gesture claim lets the cover Hero flight
  // follow the finger, but it also makes the framework ignore pointers on
  // the page. This flag swaps in a catch-all detector so a settling sheet
  // can still be grabbed back.
  final ValueNotifier<bool> _catchable = ValueNotifier(false);

  final MotionDragTracker _dragTracker = MotionDragTracker();
  bool _ignoreCurrentPointer = false;

  // Distance the sheet's top edge travels: from the mini player's top edge
  // (or the screen's bottom edge without one) up to the top of the screen.
  // Captured by the transition each frame so a drag tracks the finger 1:1.
  double? _travel;

  // The route this player was pushed over; its mini player is the origin.
  Route<dynamic>? _below;

  static PlayerPageRoute? _active;

  /// Vertical offset of the sheet at progress [p], for whichever player route
  /// is currently on screen. The cover flight rides this so it lands with the
  /// sheet instead of racing ahead of it.
  static double sheetOffsetAt(double p) {
    final double? travel = _active?._travel;
    if (travel == null) return 0;
    return (1 - p.clamp(0.0, 1.0)) * travel;
  }

  /// Rect tween for the cover shared between the mini player and the player.
  /// Both sides must use it: a push builds the tween from the player's Hero,
  /// a pop from the mini player's.
  static Tween<Rect?> coverRectTween(Rect? begin, Rect? end) =>
      _SheetRideTween(begin: begin, end: end, closing: _isClosing(begin, end));

  /// Same as [coverRectTween] for the play/skip controls.
  static Tween<Rect?> transportRectTween(Rect? begin, Rect? end) =>
      _SheetRideTween(
        begin: begin,
        end: end,
        closing: _isClosing(begin, end),
        hold: true,
      );

  static bool _isClosing(Rect? begin, Rect? end) {
    final route = _active;
    if (route != null) return route._closing;
    // No live route to ask: the player side is the larger rect.
    return begin != null &&
        end != null &&
        begin.width * begin.height > end.width * end.height;
  }

  // Which way the current flights run. Set before the framework starts them,
  // which is when the rect tweens capture it.
  bool _closing = false;

  void dismissDragStart() {
    final c = controller;
    final nav = navigator;
    if (c == null || nav == null || _dragging || _ignoreCurrentPointer) return;
    if (_settling) {
      _settling = false;
      _snap.cancel();
    } else {
      if (!isCurrent) return;
      // Grabbed mid-open: the controller value is what is drawn, so the
      // sheet simply stops under the finger.
      if (c.isAnimating) c.stop();
      _closing = true;
      // Hero flights only accept a user gesture once the route has fully
      // opened; starting one mid-open trips Hero's reverse-status assertion.
      if (animation?.status == AnimationStatus.completed) {
        nav.didStartUserGesture();
        _gestureHeld = true;
      }
    }
    _dragging = true;
  }

  void dismissDragUpdate(double dy, double height) {
    final c = controller;
    if (!_dragging || c == null) return;
    final double travel = _travel ?? height;
    if (travel <= 0) return;
    c.value = c.value - dy / travel;
  }

  /// [velocity] is px/s, positive downward.
  void dismissDragEnd(double velocity, double height) {
    final c = controller;
    if (!_dragging || c == null) return;
    _dragging = false;
    final double travel = _travel ?? height;
    final trackedVelocity = _dragTracker.velocity.dy;
    final effectiveVelocity =
        trackedVelocity.isFinite && trackedVelocity.abs() > 1
            ? trackedVelocity
            : velocity;
    _dragTracker.reset();
    // Thresholds scale with the travel the sheet actually has on this screen,
    // so the same flick does not close it on a phone and fail on a tablet.
    final tuning = SnapTuning.forExtent(
      travel,
      flingRatio: 0.62,
      commitRatio: 0.6,
    );
    final bool stayOpen = tuning.advances(
      progress: c.value,
      // Positive velocity moves toward progress 1; a downward drag closes.
      velocity: -effectiveVelocity,
      extent: travel,
    );
    final v = travel > 0 ? effectiveVelocity / travel : 0.0;
    _settle(stayOpen ? 1 : 0, -v);
  }

  void dismissDragCancel() {
    if (!_dragging) return;
    _dragging = false;
    _dragTracker.reset();
    _settle(1, 0);
  }

  // Popped only once landed, so a late grab can still pull it back.
  void _settle(double target, double velocity) {
    _settling = true;
    _catchable.value = true;
    _snap.drive(
      LandingSimulation(controller!.value, target, velocity),
      onSettled: () {
        _settling = false;
        final nav = navigator;
        if (target == 0 && nav != null && isActive) nav.pop();
        if (target == 1) _catchable.value = false;
        // After the pop: Hero flights finish against the landed animation.
        if (_gestureHeld) {
          _gestureHeld = false;
          nav?.didStopUserGesture();
        }
      },
    );
  }

  @override
  void dispose() {
    if (_active == this) _active = null;
    _catchable.dispose();
    super.dispose();
  }

  @override
  void didChangePrevious(Route<dynamic>? previousRoute) {
    super.didChangePrevious(previousRoute);
    _below = previousRoute;
  }

  // The open/close curves live in the controller itself rather than in a
  // CurvedAnimation on top, so the sheet, the cover flight and a finger that
  // grabs the sheet mid-flight all read the same value.
  @override
  Simulation? createSimulation({required bool forward}) {
    final double from = controller?.value ?? (forward ? 0 : 1);
    final double to = forward ? 1 : 0;
    _closing = !forward;
    final Duration full =
        forward ? PlayerTokens.dRouteIn : PlayerTokens.dRouteOut;
    return CurveSimulation(
      from: from,
      to: to,
      duration: full * (to - from).abs(),
      curve: forward ? PlayerTokens.cRouteIn : PlayerTokens.cRouteOut,
    );
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
    _active = this;
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
        transitionAnimation: animation,
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
    // The sheet grows out of the mini player: it starts as the bar's own rect
    // and corners, rises with its top edge, widens to the screen and squares
    // off, and lands back into the bar the same way. The page is never faded
    // as a whole, so the transport and everything else stay visibly attached
    // to the sheet for the full flight instead of vanishing ahead of it.
    final Widget stack = AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final Size size = MediaQuery.sizeOf(context);
        final RenderObject? overlayBox =
            navigator?.overlay?.context.findRenderObject();
        final origin = PlayerSheetOrigin.resolve(
          _below,
          overlayBox is RenderBox ? overlayBox : null,
        );
        final Rect from =
            origin?.rect ?? Rect.fromLTWH(0, size.height, size.width, 0);
        final double fromRadius = origin?.radius ?? PlayerTokens.rSheetFlight;
        // A mini player scrolled into an odd spot must not shrink the travel
        // to a twitch.
        _travel = from.top.clamp(size.height * 0.4, size.height);

        final double p = animation.value.clamp(0.0, 1.0);
        final double w = PlayerTokens.coverFlight(p);
        final double left = from.left.clamp(0.0, size.width) * (1 - w);
        final double right =
            (size.width - from.right).clamp(0.0, size.width) * (1 - w);
        final double radius = fromRadius * (1 - w);
        // Only the very start is faded: the bar underneath stays visible as
        // the sheet emerges from it, and shows again as the sheet lands.
        final double shell =
            Curves.easeOut.transform((p / 0.14).clamp(0.0, 1.0));

        return Stack(
          children: [
            IgnorePointer(
              child: ColoredBox(
                color: Colors.black.withValues(alpha: 0.5 * p),
                child: const SizedBox.expand(),
              ),
            ),
            // Structure stays fixed (only clip mode and values change) so the
            // player subtree is never remounted when the animation settles.
            Transform.translate(
              offset: Offset(0, (1 - p) * _travel!),
              child: Opacity(
                opacity: shell,
                child: ClipRRect(
                  clipBehavior: p >= 1 ? Clip.none : Clip.antiAlias,
                  clipper: _SheetClipper(
                    left: left,
                    right: right,
                    radius: radius,
                  ),
                  child: child,
                ),
              ),
            ),
          ],
        );
      },
    );
    return ValueListenableBuilder<bool>(
      valueListenable: _catchable,
      child: stack,
      builder: (context, catchable, stack) {
        final double height = MediaQuery.sizeOf(context).height;
        return Listener(
          behavior: HitTestBehavior.translucent,
          onPointerDown: (event) {
            _ignoreCurrentPointer = event.position.dy >=
                MediaQuery.sizeOf(context).height -
                    PlayerTokens.sheetGestureDeadSpace;
            if (!_ignoreCurrentPointer) _dragTracker.start(event);
          },
          onPointerMove: (event) {
            if (!_ignoreCurrentPointer) _dragTracker.add(event);
          },
          child: GestureDetector(
            behavior: HitTestBehavior.translucent,
            onVerticalDragStart: catchable ? (_) => dismissDragStart() : null,
            onVerticalDragUpdate:
                catchable ? (d) => dismissDragUpdate(d.delta.dy, height) : null,
            onVerticalDragEnd: catchable
                ? (d) => dismissDragEnd(d.primaryVelocity ?? 0, height)
                : null,
            onVerticalDragCancel: catchable ? dismissDragCancel : null,
            child: stack,
          ),
        );
      },
    );
  }

  @override
  Widget buildModalBarrier() {
    return const SizedBox.shrink();
  }
}

class _SheetClipper extends CustomClipper<RRect> {
  const _SheetClipper({
    required this.left,
    required this.right,
    required this.radius,
  });

  final double left;
  final double right;
  final double radius;

  @override
  RRect getClip(Size size) => RRect.fromLTRBR(
        left,
        0,
        size.width - right,
        size.height,
        Radius.circular(radius),
      );

  @override
  bool shouldReclip(_SheetClipper old) =>
      old.left != left || old.right != right || old.radius != radius;
}

/// Mini <-> player flight that heads for the element's slot *in the moving
/// sheet* rather than its landed spot, so it stays attached to the sheet and
/// lands with it instead of arriving early.
class _SheetRideTween extends Tween<Rect?> {
  _SheetRideTween(
      {super.begin, super.end, required this.closing, this.hold = false});

  /// Direction captured when the flight starts: on close, [begin] is the
  /// player side and the tween runs against sheet progress.
  final bool closing;

  /// Keeps the element from dipping below where the mini player draws it.
  /// Transport controls sit at the bottom of the player, so their slot starts
  /// off screen; holding lets them wait in the bar until the sheet arrives.
  final bool hold;

  @override
  Rect? lerp(double t) {
    final Rect? a = begin;
    final Rect? b = end;
    if (a == null || b == null) return Rect.lerp(a, b, t);
    final Rect mini = closing ? b : a;
    final Rect full = closing ? a : b;
    final double p = closing ? 1 - t : t;
    final Rect slot = full.shift(Offset(0, PlayerPageRoute.sheetOffsetAt(p)));
    final Rect r = Rect.lerp(mini, slot, PlayerTokens.coverFlight(p))!;
    if (!hold) return r;
    // Releases the hold in step with sheet progress, so the element is at the
    // mini player's height at the start and exactly on its slot at the end.
    final double dip = r.center.dy - mini.center.dy;
    return dip > 0 ? r.shift(Offset(0, -dip * (1 - p))) : r;
  }
}

/// The dock-side end of the cover flight when it is the collapsed ball.
///
/// The player's flight shuttle draws its own cover, so it cannot see the
/// ball's circular clip or paused dimming. It reads them from here so the
/// flight lands on the exact shape and opacity the ball shows.
class CoverFlightEnd extends StatelessWidget {
  final double opacity;
  final Widget child;

  const CoverFlightEnd({super.key, required this.opacity, required this.child});

  /// The ball end of a cover flight, or null when the dock end is the bar.
  static CoverFlightEnd? of(
    HeroFlightDirection direction,
    BuildContext fromCtx,
    BuildContext toCtx,
  ) {
    final Widget dock = ((direction == HeroFlightDirection.push
            ? fromCtx.widget
            : toCtx.widget) as Hero)
        .child;
    return dock is CoverFlightEnd ? dock : null;
  }

  /// Clips [child] for flight progress [t] (0 = dock, 1 = player): toward the
  /// ball's dimmed circle when [ball] is set, else the bar's small radius.
  static Widget clip({
    required CoverFlightEnd? ball,
    required double t,
    required double landedRadius,
    required Widget child,
  }) {
    if (ball == null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(
          PlayerTokens.flightRadius(t, landedRadius),
        ),
        child: child,
      );
    }
    final double k = PlayerTokens.coverFlight(t.clamp(0.0, 1.0));
    return Opacity(
      opacity: ball.opacity + (1 - ball.opacity) * k,
      child: LayoutBuilder(
        builder: (context, box) {
          final double circle = box.biggest.shortestSide / 2;
          return ClipRRect(
            borderRadius: BorderRadius.circular(
              circle + (landedRadius - circle) * k,
            ),
            child: child,
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedOpacity(
        opacity: opacity,
        duration: PlayerTokens.dBase,
        curve: PlayerTokens.cStandard,
        child: child,
      );
}
