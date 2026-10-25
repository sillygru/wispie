import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/theme_provider.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';
import '../routes/player_sheet_origin.dart';
import 'player_morph.dart';
import '../screens/unified_player_screen.dart';
import '../tokens/player_tokens.dart';
import '../widgets/album_art_image.dart';
import '../widgets/collection_accent_scope.dart';

/// The player panel: a shell that owns exactly one value, running from 0 (the
/// dock's bar) to 1 (the full player).
///
/// Opening is not a route push. The player is mounted once inside the shell and
/// lives on top of it, so the transition is the same continuous motion a drag
/// produces: one controller, one travel distance, and every visual a function
/// of that value. That is what makes a flick, a grab mid-flight and a tap all
/// feel like the same object moving.
abstract final class PlayerPanel {
  static _PlayerPanelHostState? _host;
  static PlayerPanelController? _controller;

  /// Where the panel is, for chrome that lives outside it. The dock reads this
  /// to dip as the panel overshoots its way home.
  static final ValueNotifier<double> progress = ValueNotifier<double>(0);

  /// Whether the panel is meant to be open. One notifier shared by the
  /// controller, the back button and the host.
  static final ValueNotifier<bool> openState = ValueNotifier<bool>(false);

  static PlayerPanelController? get controller => _controller;

  static bool get isOpen => openState.value;

  /// True while the panel is on screen or moving, for chrome that has to stand
  /// aside (the dock's own bar visualizers, the system back button).
  static bool get isVisible =>
      _controller != null &&
      (openState.value || _controller!.progress.value > 0.001);

  /// Opens the panel. [from] lets a screen that is pushed above the shell hand
  /// back to it first: the panel belongs to the shell, so it cannot grow out of
  /// a bar that is not on screen.
  static void open({
    PlayerPane initialPane = PlayerPane.player,
    bool queueShowsHistory = false,
    BuildContext? from,
  }) {
    if (from != null) {
      final route = ModalRoute.of(from);
      final navigator = Navigator.maybeOf(from);
      if (route != null && !route.isFirst && navigator != null) {
        navigator.popUntil((r) => r.isFirst);
      }
    }
    _host?._open(
        initialPane: initialPane, queueShowsHistory: queueShowsHistory);
  }

  static void close() => _controller?.close();

  static void toggle() {
    if (isOpen) {
      close();
    } else {
      open();
    }
  }

  static void _attach(_PlayerPanelHostState host, PlayerPanelController panel) {
    _host = host;
    _controller = panel;
  }

  static void _detach(_PlayerPanelHostState host) {
    if (_host == host) {
      _host = null;
      _controller = null;
      progress.value = 0;
      openState.value = false;
    }
  }
}

/// Owns the progress value, the release decision and the travel the drag reads.
/// The host supplies the geometry and the flight; this class never looks at a
/// widget.
class PlayerPanelController {
  PlayerPanelController({required TickerProvider vsync}) {
    progress = AnimationController(
      vsync: vsync,
      lowerBound: -PlayerTokens.panelDip,
      upperBound: 1 + PlayerTokens.panelOvershoot,
    );
    snap = SnapEngine(progress);
  }

  late final AnimationController progress;
  late final SnapEngine snap;

  /// Measured by the host: the distance the top edge travels from the dock's
  /// bar to the top of the screen.
  double Function()? travelOf;

  /// Fired the moment a close begins, so the artwork can start its flight back
  /// into the bar with the surface.
  VoidCallback? onClosing;

  /// Fired when a move finishes. Superseded moves never report, so a grab that
  /// took over does not see the interrupted move "land".
  VoidCallback? onSettled;

  /// Fired before the first drag frame, so the artwork starts travelling with
  /// the finger instead of waiting for a release to begin its flight.
  VoidCallback? onGrabbed;

  bool get isOpen => PlayerPanel.openState.value;

  double get value => progress.value;

  bool _dragging = false;
  double _startValue = 0;
  double _travel = 1;

  /// Wall-clock until which a fresh grab must not reopen a just-closed panel.
  DateTime? _reopenBlockedUntil;

  bool get _reopenBlocked =>
      _reopenBlockedUntil != null &&
      DateTime.now().isBefore(_reopenBlockedUntil!);

  void open() {
    _reopenBlockedUntil = null;
    PlayerPanel.openState.value = true;
    // A fixed duration on purpose: the reference app never shortens a snap
    // because the surface is already part way there. Scaling it made a lane
    // change feel like a cut instead of a move.
    snap.snapTo(
      1,
      duration: PlayerTokens.dPanelOpen,
      curve: PlayerTokens.cPanelOpen,
      onSettled: () => onSettled?.call(),
    );
  }

  void close() {
    if (!isOpen && !progress.isAnimating && value <= 0) return;
    PlayerPanel.openState.value = false;
    _reopenBlockedUntil = DateTime.now().add(PlayerTokens.dPanelReopenGrace);
    onClosing?.call();
    snap.snapTo(
      0,
      duration: PlayerTokens.dPanelClose,
      curve: PlayerTokens.cPanelClose,
      onSettled: () => onSettled?.call(),
    );
  }

  void jumpOpen() {
    _reopenBlockedUntil = null;
    PlayerPanel.openState.value = true;
    snap.jumpTo(1);
  }

  void jumpClosed() {
    PlayerPanel.openState.value = false;
    snap.jumpTo(0);
  }

  void dragStart() {
    if (_dragging) return;
    // A bounce of the finger right after a flick-close must not catch the
    // settling sheet and open it again.
    if (_reopenBlocked) return;
    _dragging = true;
    onGrabbed?.call();
    // A grab always takes over from what is drawn, never from the target, so a
    // panel caught mid-flight continues under the finger instead of jumping.
    snap.cancel();
    _startValue = value;
    _travel = math.max(travelOf?.call() ?? 0, 1);
    PlayerPanel.openState.value = true;
  }

  /// [dy] is this event's vertical delta in logical pixels, positive downward.
  void dragUpdate(double dy) {
    if (!_dragging) return;
    final double next = value - dy / _travel;
    progress.value =
        next.clamp(-PlayerTokens.panelDip, 1 + PlayerTokens.panelOvershoot);
  }

  /// [velocity] is px/s, positive downward.
  void dragEnd({required double velocity}) {
    if (!_dragging) return;
    _dragging = false;
    final SnapTuning tuning = SnapTuning.forExtent(
      _travel,
      flingRatio: 0.62,
      commitRatio: 0.5,
    );
    final double travelled = (_startValue - value) * _travel;
    final bool towardBar =
        velocity > tuning.flingVelocity || travelled > tuning.actuation;
    final bool towardPlayer =
        -velocity > tuning.flingVelocity || travelled < -tuning.actuation;
    // Started from the bar's half: only a deliberate move up opens. Started
    // from the player: only a deliberate move down closes, otherwise the panel
    // returns home instead of dropping out from under a slight drag.
    final bool close = _startValue >= 0.5 ? towardBar : !towardPlayer;
    final double distance = travelled.abs();
    if (distance > tuning.actuation || velocity.abs() > tuning.flingVelocity) {
      MotionHaptics.light();
    }
    if (close) {
      this.close();
    } else {
      open();
    }
  }

  void dragCancel() {
    if (!_dragging) return;
    _dragging = false;
    open();
  }

  void dispose() {
    progress.dispose();
  }
}

/// How opaque the player's own artwork should be while a flight runs: 0 while
/// the shuttle carries the cover, 1 at both ends, so the hand-off is a crossfade
/// on aligned rects instead of a swap on one frame.
class PlayerCoverOpacity extends InheritedNotifier<ValueNotifier<double>> {
  const PlayerCoverOpacity({
    super.key,
    required ValueNotifier<double> opacity,
    required super.child,
  }) : super(notifier: opacity);

  static double coverOpacityOf(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<PlayerCoverOpacity>()
          ?.notifier
          ?.value ??
      1;
}

/// Boxes the panel measures to fly the cover. Widgets draw with these keys;
/// they carry no behaviour of their own.
abstract final class PlayerMorphTargets {
  static final GlobalKey cover = GlobalKey(debugLabel: 'player morph cover');
}

/// Mounts the player above the shell and animates it open and closed.
///
/// The surface grows out of the dock's bar: it starts as the bar's own rect and
/// corners, rises with its top edge, widens to the screen and squares off. The
/// cover rides from the bar's artwork slot to the player's cover on the same
/// value, so the eye follows one object instead of watching two cross-fade.
class PlayerPanelHost extends ConsumerStatefulWidget {
  const PlayerPanelHost({super.key});

  @override
  ConsumerState<PlayerPanelHost> createState() => _PlayerPanelHostState();
}

class _PlayerPanelHostState extends ConsumerState<PlayerPanelHost>
    with SingleTickerProviderStateMixin {
  late final PlayerPanelController _panel = PlayerPanelController(vsync: this);
  final GlobalKey _hostKey = GlobalKey(debugLabel: 'player panel');
  final GlobalKey _sheetKey = GlobalKey(debugLabel: 'player sheet');
  final ValueNotifier<bool> _flying = ValueNotifier(false);
  final ValueNotifier<double> _coverOpacity = ValueNotifier<double>(1);

  bool _mounted = false;
  PlayerPane _pane = PlayerPane.player;
  bool _queueHistory = false;

  Rect? _origin;
  double _originRadius = PlayerTokens.rSheetFlight;
  double _travel = 0;

  // Transport slots with both ends on screen. Rects are measured live on every
  // tick instead of captured once: the bar dips on the close overshoot and the
  // player's controls ride the sheet, so a rect captured at the start landed a
  // few pixels off on the last frame.
  final Set<PlayerMorphSlot> _morphSlots = <PlayerMorphSlot>{};

  @override
  void initState() {
    super.initState();
    PlayerPanel._attach(this, _panel);
    _panel
      ..travelOf = _measureTravel
      ..onClosing = _startFlight
      ..onGrabbed = _startFlight
      ..onSettled = _endFlight;
    _panel.progress.addListener(_onTick);
  }

  void _endFlight() {
    if (_flying.value) _flying.value = false;
    _morphSlots.clear();
    PlayerMorph.clear();
    if (_coverOpacity.value != 1) _coverOpacity.value = 1;
    if (PlayerMorph.strength.value != 0) PlayerMorph.strength.value = 0;
  }

  /// How much of the flight the shuttles own. It ramps from 0 at either rest
  /// state to 1 once the surface is clear of the bar, so the last frame blends
  /// into the real control instead of replacing it.
  static double _strengthAt(double p, bool flying) {
    if (!flying) return 0;
    return (math.min(p.clamp(0.0, 1.0), 1 - p.clamp(0.0, 1.0)) / 0.07)
        .clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _panel.progress.removeListener(_onTick);
    _flying.dispose();
    PlayerPanel._detach(this);
    _panel.dispose();
    super.dispose();
  }

  void _onTick() {
    final double v = _panel.value;
    final double strength = _strengthAt(v, _flying.value);
    final double opacity = 1 - strength;
    if (_coverOpacity.value != opacity) _coverOpacity.value = opacity;
    if (PlayerMorph.strength.value != strength) {
      PlayerMorph.strength.value = strength;
    }
    // Chrome outside the panel only reacts to the end of the close, where the
    // dock dips. Publishing every tick would rebuild the dock for the whole
    // flight for no visible reason.
    final double shared = v < 0.05 ? v : 0;
    if (PlayerPanel.progress.value != shared) {
      PlayerPanel.progress.value = shared;
    }
  }

  void _open({
    PlayerPane initialPane = PlayerPane.player,
    bool queueShowsHistory = false,
  }) {
    if (!mounted) return;
    final Song? song =
        ref.read(audioPlayerManagerProvider).currentSongNotifier.value;
    if (song == null) return;
    final bool relayout =
        !_mounted || initialPane != _pane || queueShowsHistory != _queueHistory;
    setState(() {
      _mounted = true;
      _pane = initialPane;
      _queueHistory = queueShowsHistory;
    });
    if (MotionPolicy.read(context).reduceMotion) {
      _endFlight();
      _panel.jumpOpen();
      return;
    }
    if (relayout) {
      // The player's cover has to be laid out before it can be flown to, so the
      // first frame mounts it and the motion starts on the next one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _startFlight();
        _panel.open();
      });
      return;
    }
    _startFlight();
    _panel.open();
  }

  double _measureTravel() {
    _measureOrigin();
    // The screen, not the host box: the host is offstage while the panel is
    // closed, and the travel is a property of the window anyway.
    final Size size = MediaQuery.sizeOf(context);
    final Rect bar = _origin ?? Rect.fromLTWH(0, size.height, size.width, 0);
    // A bar pushed into an odd spot must not shrink the travel to a twitch.
    _travel = bar.top.clamp(size.height * 0.4, size.height);
    return _travel;
  }

  void _measureOrigin() {
    final RenderBox? host =
        _hostKey.currentContext?.findRenderObject() as RenderBox?;
    final resolved = PlayerSheetOrigin.resolveIn(host);
    if (resolved == null) return;
    _origin = resolved.rect;
    _originRadius = resolved.radius;
  }

  /// Marks both ends of the flight. Nothing is captured here: the rects are
  /// read from the live render objects while it runs, so the flight lands
  /// exactly on whatever the two surfaces are drawing on its last frame.
  void _startFlight() {
    final RenderBox? host =
        _hostKey.currentContext?.findRenderObject() as RenderBox?;
    if (host == null) return;
    _measureTravel();
    _morphSlots
      ..clear()
      ..addAll(PlayerMorphSlot.values.where((slot) =>
          PlayerMorph.anchorOf(slot, PlayerMorphSurface.bar) != null &&
          PlayerMorph.anchorOf(slot, PlayerMorphSurface.panel) != null));
    // With no drawer or cover measured, the surface still animates and both
    // covers stay visible; hiding one without a shuttle would blank it.
    _flying.value =
        _liveCover(host) != null && PlayerSheetOrigin.artRectIn(host) != null;
    PlayerMorph.setFlying(_morphSlots);
  }

  /// The player's cover as drawn right now, plus the layout size its artwork is
  /// decoded at (which the beat transform does not change).
  ({Rect rect, Size size})? _liveCover(RenderBox host) {
    final RenderBox? cover = PlayerMorphTargets.cover.currentContext
        ?.findRenderObject() as RenderBox?;
    if (cover == null || !cover.attached || !cover.hasSize) return null;
    final Offset topLeft = host.globalToLocal(cover.localToGlobal(Offset.zero));
    return (rect: topLeft & cover.size, size: cover.size);
  }

  Widget _buildPlayer() {
    return Consumer(
      builder: (context, ref, child) {
        final themeState = ref.watch(themeProvider);
        final Color? accent = themeState.extractedColor;
        if (accent == null) {
          return Theme(data: AppTheme.getTheme(themeState), child: child!);
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
      child: PlayerCoverOpacity(
        opacity: _coverOpacity,
        child: UnifiedPlayerScreen(
          key: ValueKey<int>(_pane.index * 2 + (_queueHistory ? 1 : 0)),
          initialPane: _pane,
          queueShowsHistory: _queueHistory,
          transitionAnimation: _panel.progress,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!_mounted) return const SizedBox.shrink();
    final Widget player = RepaintBoundary(
      child: KeyedSubtree(key: _sheetKey, child: _buildPlayer()),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: PlayerPanel.openState,
      builder: (context, open, _) => PopScope(
        canPop: !open,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) PlayerPanel.close();
        },
        child: _buildSheet(context, player),
      ),
    );
  }

  Widget _buildSheet(BuildContext context, Widget player) {
    return Positioned.fill(
      key: _hostKey,
      child: AnimatedBuilder(
        animation: _panel.progress,
        child: player,
        builder: (context, child) {
          final double p = _panel.value;
          final double clamped = p.clamp(0.0, 1.0);
          final bool active = p > 0.0005 || _panel.progress.isAnimating;
          if (_travel <= 0) _measureTravel();
          final Size size = MediaQuery.sizeOf(context);
          final Rect from =
              _origin ?? Rect.fromLTWH(0, size.height, size.width, 0);
          // The surface starts as the bar and widens to the screen. Only the
          // first sliver is faded: the bar underneath stays visible as the
          // panel emerges from it, and comes back as the panel lands.
          final double widen = PlayerTokens.coverFlight(clamped);
          final double left = from.left.clamp(0.0, size.width) * (1 - widen);
          final double right =
              (size.width - from.right).clamp(0.0, size.width) * (1 - widen);
          final double radius = _originRadius * (1 - widen);
          final double shell =
              Curves.easeOut.transform((clamped / 0.10).clamp(0.0, 1.0));
          final double offset = (1 - clamped) * _travel;
          final double strength = _strengthAt(clamped, _flying.value);
          final RenderBox? host =
              _hostKey.currentContext?.findRenderObject() as RenderBox?;

          // Every end is read from the live box while the flight runs, so the
          // last frame lands on what the surfaces are actually drawing instead
          // of on where they were when it started.
          Rect? shuttle;
          Size? shuttleSize;
          if (strength > 0.001 && host != null) {
            final live = _liveCover(host);
            final Rect? barArt = PlayerSheetOrigin.artRectIn(host);
            if (live != null && barArt != null) {
              shuttle = Rect.lerp(barArt, live.rect, widen);
              shuttleSize = live.size;
            }
          }

          final List<Widget> transport = <Widget>[];
          if (strength > 0.001 && _morphSlots.isNotEmpty && host != null) {
            // The swap happens across the middle third, the way the route
            // flight used to do it: neither glyph ghosts for the whole move,
            // and neither is stretched out of proportion on the way.
            final double swap = ((clamped - 0.25) / 0.45).clamp(0.0, 1.0);
            for (final slot in _morphSlots) {
              final PlayerMorphAnchorState? bar =
                  PlayerMorph.anchorOf(slot, PlayerMorphSurface.bar);
              final PlayerMorphAnchorState? panel =
                  PlayerMorph.anchorOf(slot, PlayerMorphSurface.panel);
              if (bar == null || panel == null) continue;
              final Rect? from = bar.rectIn(host);
              final Rect? to = panel.rectIn(host);
              if (from == null || to == null) continue;
              final Rect plain = Rect.lerp(from, to, clamped)!;
              // The player's control rests lower than the bar's, so a plain
              // lerp would fly it down out of the screen first. Hold it at the
              // bar's height until the risen surface can carry it up.
              final double dip = plain.center.dy - from.center.dy;
              final Rect rect = dip > 0
                  ? plain.shift(Offset(0, -dip * (1 - clamped)))
                  : plain;
              transport.add(Positioned.fromRect(
                rect: rect,
                child: Opacity(
                  opacity: strength,
                  child: IgnorePointer(
                    child: Material(
                      type: MaterialType.transparency,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          Opacity(
                            opacity: 1 - swap,
                            child: FittedBox(child: bar.child),
                          ),
                          Opacity(
                            opacity: swap,
                            child: FittedBox(child: panel.child),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ));
            }
          }
          final Song? song =
              ref.read(audioPlayerManagerProvider).currentSongNotifier.value;

          return Offstage(
            offstage: !active,
            child: TickerMode(
              enabled: active,
              child: Stack(
                children: [
                  if (active)
                    IgnorePointer(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: 0.5 * clamped),
                        child: const SizedBox.expand(),
                      ),
                    ),
                  Transform.translate(
                    offset: Offset(0, offset),
                    child: Opacity(
                      opacity: shell,
                      child: ClipRRect(
                        clipBehavior: clamped >= 1 ? Clip.none : Clip.antiAlias,
                        clipper: _PanelClipper(
                          left: left,
                          right: right,
                          radius: radius,
                        ),
                        // Swallows anything the player itself leaves
                        // transparent, so a tap never lands on the page below.
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                  ...transport,
                  if (shuttle != null && song != null && shuttleSize != null)
                    Positioned.fromRect(
                      rect: shuttle,
                      child: Opacity(
                        opacity: strength,
                        child: IgnorePointer(
                          child: _CoverShuttle(
                            song: song,
                            progress: clamped,
                            settled: shuttleSize,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PanelClipper extends CustomClipper<RRect> {
  const _PanelClipper({
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
  bool shouldReclip(_PanelClipper old) =>
      old.left != left || old.right != right || old.radius != radius;
}

/// The artwork growing out of the bar's slot into the player's cover.
class _CoverShuttle extends StatelessWidget {
  const _CoverShuttle({
    required this.song,
    required this.progress,
    required this.settled,
  });

  final Song song;

  /// Panel progress: the corner radius follows it so the shuttle is the bar's
  /// rounded square at one end and the cover's large radius at the other.
  final double progress;

  /// The landed cover's size. The artwork is laid out at exactly this size and
  /// scaled into the flight, never re-laid out per frame: `AlbumArtImage`
  /// derives its decode size from the box it is given, so a box that changes
  /// every tick re-decodes the image every tick, which is the flicker.
  final Size settled;

  @override
  Widget build(BuildContext context) {
    final double k = PlayerTokens.coverFlight(progress);
    final double radius =
        PlayerTokens.rSm + (PlayerTokens.rLg - PlayerTokens.rSm) * k;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        // The landed cover carries this shadow. Fading it in with the flight
        // keeps it from popping on at the hand-off, which is the twitch that
        // was visible on the last frame.
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45 * k),
            blurRadius: 34,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: FittedBox(
          fit: BoxFit.fill,
          child: SizedBox(
            width: settled.width,
            height: settled.height,
            child: AlbumArtImage(
              url: song.coverUrl ?? '',
              filename: song.filename,
              cacheVersion: song.mtime,
              width: settled.width,
              height: settled.height,
              fit: BoxFit.cover,
              fadeDuration: Duration.zero,
              // Matches the pane's settled quality, so the hand-off does not
              // sharpen on one frame either.
              filterQuality: FilterQuality.high,
            ),
          ),
        ),
      ),
    );
  }
}
