import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/services/panel_release.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/theme_provider.dart';
import '../../services/display_refresh_service.dart';
import '../../theme/app_theme.dart';
import '../motion/motion.dart';
import '../routes/player_sheet_origin.dart';
import '../screens/unified_player_screen.dart';
import '../tokens/player_tokens.dart';
import '../widgets/collection_accent_scope.dart';
import 'player_morph.dart';

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

  /// Rubber-band travel below the seat, which the dock mirrors as a dip.
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

  static void close() => _host?._close();

  static void startMiniDrag(DragStartDetails details) =>
      _host?._startMiniDrag(details);

  static void updateDrag(DragUpdateDetails details) =>
      _controller?.dragUpdate(details);

  static void endDrag(DragEndDetails details) =>
      _controller?.dragEnd(velocity: details.primaryVelocity ?? 0);

  static void cancelDrag() => _controller?.dragCancel();

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
      value: 0,
      lowerBound: -PlayerTokens.panelRubberRoom,
      upperBound: 1 + PlayerTokens.panelRubberRoom,
    );
    _snap = SnapEngine(progress);
  }

  late final AnimationController progress;
  late final SnapEngine _snap;

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
  double get coverSpeed => _dragging ? _dragVelocity : progress.velocity;

  /// True while a finger owns the surface.
  bool get isDragging => _dragging;

  /// True while the surface is following a finger or settling from one.
  ///
  /// The host pauses the player's own animation for exactly this long. A frame
  /// of the flight is then a cached raster under a transform, instead of a new
  /// full-screen raster of the particle field, the waveform and the spinning
  /// backdrop on every one of those frames — all of it paid on top of moving
  /// the surface itself.
  bool get isMoving => _dragging || progress.isAnimating;

  bool _dragging = false;

  /// Travel distance in logical pixels, measured once per grab.
  double _travel = 1;

  /// Where the finger picked the surface up, kept only to tell a deliberate
  /// drag from a hold that went nowhere.
  double _dragAnchor = 0;
  double _rawDragAnchor = 0;
  double _pointerOriginY = 0;
  Duration? _lastDragTime;
  double _dragVelocity = 0;

  /// The accessibility policy lives above this controller, so the host hands it
  /// down rather than the controller reaching up for it.
  bool Function()? prefersInstant;

  void open() => _settleTo(1);

  void close() => _settleTo(0);

  void _settleTo(double target, {bool fromDrag = false}) {
    final bool open = target == 1;
    if (!fromDrag &&
        !_dragging &&
        open == isOpen &&
        (progress.isAnimating || value == target)) {
      return;
    }
    _dragging = false;
    PlayerPanel.openState.value = open;
    if (!open) onClosing?.call();
    DisplayRefreshService.instance.boost120();
    if (value == target || (prefersInstant?.call() ?? false)) {
      _snap.jumpTo(target);
      onSettled?.call();
      return;
    }
    unawaited(_snap.snapTo(
      target,
      duration: MotionTokens.medium,
      curve: open ? MotionTokens.enterCurve : MotionTokens.overshootCurve,
      onSettled: onSettled,
    ));
  }

  void dragStart(DragStartDetails details) {
    if (_dragging) return;
    _dragging = true;
    _pointerOriginY = details.globalPosition.dy;
    _lastDragTime = details.sourceTimeStamp;
    _dragVelocity = progress.velocity;
    _dragAnchor = value;
    _rawDragAnchor = PanelRelease.unresist(
      value,
      low: 0,
      high: 1,
      room: PlayerTokens.panelRubberRoom,
    );
    _snap.cancel();
    _travel = math.max(travelOf?.call() ?? 0, 1);
    onGrabbed?.call();
    DisplayRefreshService.instance.boost120();
  }

  /// Screen coordinates stay stable as the panel moves under the finger.
  void dragUpdate(DragUpdateDetails details) {
    if (!_dragging) return;
    final double next = PanelRelease.resist(
      _rawDragAnchor - (details.globalPosition.dy - _pointerOriginY) / _travel,
      low: 0,
      high: 1,
      room: PlayerTokens.panelRubberRoom,
    );
    final Duration? now = details.sourceTimeStamp;
    final Duration? before = _lastDragTime;
    if (now != null && before != null && now > before) {
      final int elapsed = (now - before).inMicroseconds;
      final double sampled =
          (next - value) * Duration.microsecondsPerSecond / elapsed;
      final double weight = elapsed /
          (elapsed + PlayerTokens.dCoverVelocityFilter.inMicroseconds);
      _dragVelocity += (sampled - _dragVelocity) * weight;
    }
    _lastDragTime = now;
    progress.value = next;
  }

  /// [velocity] is px/s, positive downward.
  void dragEnd({required double velocity}) {
    if (!_dragging) return;
    final bool close = PanelRelease.closes(
      anchor: _dragAnchor,
      current: value,
      travel: _travel,
      velocity: velocity,
      flingVelocity: PlayerTokens.panelFlingVelocity,
      actuation: PlayerTokens.panelActuation,
    );
    if (close == isOpen &&
        (value - _dragAnchor).abs() * _travel > PlayerTokens.panelActuation) {
      MotionHaptics.light();
    }
    _settleTo(close ? 0 : 1, fromDrag: true);
  }

  void dragCancel() {
    if (!_dragging) return;
    _settleTo(isOpen ? 1 : 0, fromDrag: true);
  }

  void dispose() {
    progress.dispose();
  }
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
  bool _mounted = false;
  bool _flying = false;
  int _openRequest = 0;

  /// Live only inside the window after a close lands, while an upward swipe can
  /// still pick the surface back up.
  Timer? _graceTimer;

  // A gesture that starts in time keeps its recognizer after the window ends.
  int? _catchPointer;

  bool get _inGrace => _graceTimer != null;

  PlayerPane _pane = PlayerPane.player;
  bool _queueHistory = false;

  Rect? _origin;
  double _originRadius = PlayerTokens.rSheetFlight;
  double _travel = 0;

  // Transport slots with both ends on screen. Rects are measured live on every
  // tick so the controls follow the sheet and the dock's own motion.
  final Set<PlayerMorphSlot> _morphSlots = <PlayerMorphSlot>{};

  @override
  void initState() {
    super.initState();
    PlayerPanel._attach(this, _panel);
    _panel
      ..travelOf = _travelForGrab
      ..onClosing = _startFlight
      ..onGrabbed = _onGrabbed
      ..onSettled = _onSettled
      ..prefersInstant = () => MotionPolicy.read(context).reduceMotion;
    _panel.progress.addListener(_onTick);
    _panel.progress.addStatusListener(_onAnimationStatus);
  }

  /// A settle keeps the player's own tickers off, and the tick that lands still
  /// reports an animating controller. This is the build that lets them go.
  void _onAnimationStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed ||
        status == AnimationStatus.dismissed) {
      if (mounted) setState(() {});
    }
  }

  void _endFlight() {
    _flying = false;
    _morphSlots.clear();
    PlayerMorph.clear();
    if (PlayerMorph.coverStrength.value != 0) {
      PlayerMorph.coverStrength.value = 0;
    }
    if (PlayerMorph.strength.value != 0) PlayerMorph.strength.value = 0;
  }

  void _onSettled() {
    _endFlight();
    if (!mounted) return;
    if (!PlayerPanel.openState.value) {
      _graceTimer?.cancel();
      _graceTimer = Timer(PlayerTokens.panelCloseGrace, () {
        if (mounted) setState(() => _graceTimer = null);
      });
    }
    setState(() {});
  }

  void _endGrace() {
    _graceTimer?.cancel();
    _graceTimer = null;
  }

  void _onGrabbed() {
    _openRequest++;
    _endGrace();
    _startFlight();
    setState(() {});
  }

  /// How much of the flight the shuttles own. It ramps from 0 at either rest
  /// state to 1 once the surface is clear of the bar, so the last frame blends
  /// into the real control instead of replacing it.
  static double _strengthAt(double p, bool flying) {
    if (!flying) return 0;
    // Wide enough for the shuttle handoff to read as a fade, not a ghost frame.
    return (math.min(p.clamp(0.0, 1.0), 1 - p.clamp(0.0, 1.0)) / 0.12)
        .clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _panel.progress.removeListener(_onTick);
    _panel.progress.removeStatusListener(_onAnimationStatus);
    if (_flying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!(PlayerPanel._host?._flying ?? false)) _endFlight();
      });
    }
    _graceTimer?.cancel();
    _graceTimer = null;
    PlayerPanel._detach(this);
    _panel.dispose();
    super.dispose();
  }

  void _onTick() {
    final double v = _panel.value;
    final double strength = _strengthAt(v, _flying);
    final double handoff = math
        .min(
          v / PlayerTokens.barCoverHandoff,
          (1 - v) / PlayerTokens.panelCoverHandoff,
        )
        .clamp(0.0, 1.0);
    final bool hasCover =
        _flying && handoff > 0 && _barCover() != null && _panelCover() != null;
    final double coverStrength =
        hasCover ? handoff * handoff * (3 - 2 * handoff) : 0;
    if (PlayerMorph.coverStrength.value != coverStrength) {
      PlayerMorph.coverStrength.value = coverStrength;
    }
    if (PlayerMorph.strength.value != strength) {
      PlayerMorph.strength.value = strength;
    }
    // The dock only reacts to rubber-band travel beyond its seat.
    final double shared = math.min(v, 0);
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
    final bool relayout = _sheetKey.currentContext == null ||
        initialPane != _pane ||
        queueShowsHistory != _queueHistory;
    final int request = ++_openRequest;
    _endGrace();
    setState(() {
      _mounted = true;
      _pane = initialPane;
      _queueHistory = queueShowsHistory;
    });
    if (MotionPolicy.read(context).reduceMotion) {
      _endFlight();
      _panel.open();
      return;
    }
    if (relayout) {
      // The player's cover has to be laid out before it can be flown to, so the
      // first frame mounts it and the motion starts on the next one.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || request != _openRequest) return;
        _beginOpen();
      });
      return;
    }
    _beginOpen();
  }

  void _startMiniDrag(DragStartDetails details) {
    final bool atRest = _panel.value <= 0 && !_panel.isMoving;
    final bool needsLayout =
        !_mounted || (atRest && (_pane != PlayerPane.player || _queueHistory));
    if (needsLayout) {
      setState(() {
        _mounted = true;
        _pane = PlayerPane.player;
        _queueHistory = false;
      });
    }
    _panel.dragStart(details);
    if (needsLayout && _flying) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_flying) return;
        _captureMorphSlots();
      });
    }
  }

  void _beginOpen() {
    if (_panel.value < 1 || _panel.isMoving) _startFlight();
    _panel.open();
  }

  void _close() {
    _openRequest++;
    _panel.close();
  }

  double _travelForGrab() => _flying ? _travel : _measureTravel();

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
    _origin = resolved?.rect;
    _originRadius = resolved?.radius ?? PlayerTokens.rSheetFlight;
  }

  // The grace window's own drag layer reports to the same controller the panes
  // use, so picking the surface back up after it lands and mid-flight are one
  // gesture as far as the panel is concerned.
  void _onDismissDragStart(DragStartDetails details) =>
      _panel.dragStart(details);

  void _onDismissDragUpdate(DragUpdateDetails details) =>
      _panel.dragUpdate(details);

  void _onDismissDragEnd(DragEndDetails details) =>
      _panel.dragEnd(velocity: details.primaryVelocity ?? 0);

  void _onDismissDragCancel() => _panel.dragCancel();

  void _startFlight() {
    if (_flying || MotionPolicy.read(context).reduceMotion) return;
    _measureTravel();
    _flying = true;
    _captureMorphSlots();
  }

  void _captureMorphSlots() {
    _morphSlots
      ..clear()
      ..addAll(PlayerMorphSlot.values.where((slot) =>
          PlayerMorph.anchorOf(slot, PlayerMorphSurface.bar) != null &&
          PlayerMorph.anchorOf(slot, PlayerMorphSurface.panel) != null));
    PlayerMorph.setFlying(_morphSlots);
  }

  PlayerCoverGeometry? _barCover() => PlayerCoverAnchor.measure(
        PlayerCoverAnchor.barKey,
        _hostKey.currentContext?.findRenderObject() as RenderBox?,
      );

  PlayerCoverGeometry? _panelCover() {
    final sheet = _sheetKey.currentContext?.findRenderObject() as RenderBox?;
    if (sheet == null || !sheet.hasSize) return null;
    final cover = PlayerCoverAnchor.measure(PlayerCoverAnchor.panelKey, sheet);
    if (cover == null ||
        !(Offset.zero & sheet.size).contains(cover.rect.center)) {
      return null;
    }
    return cover;
  }

  void _releaseCatchPointer(PointerEvent event) {
    if (mounted && event.pointer == _catchPointer) {
      setState(() => _catchPointer = null);
    }
  }

  Widget _buildPlayer() {
    return Consumer(
      builder: (context, ref, child) {
        final themeState = ref.watch(themeProvider);
        final Color? accent = themeState.trackColor;
        final Widget player = Theme(
          data: AppTheme.getPlayerTheme(themeState),
          child: child!,
        );
        // The playing cover wins here even while an album or artist page tints
        // everything behind the player.
        if (accent == null) return player;
        return CollectionAccentScope(
          accent: accent,
          isNeutral: themeState.isTrackNeutral,
          child: player,
        );
      },
      child: UnifiedPlayerScreen(
        key: ValueKey<int>(_pane.index * 2 + (_queueHistory ? 1 : 0)),
        initialPane: _pane,
        queueShowsHistory: _queueHistory,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      key: _hostKey,
      child: _mounted ? _buildPanel() : const SizedBox.shrink(),
    );
  }

  Widget _buildPanel() {
    final Widget player = RepaintBoundary(
      key: _sheetKey,
      child: _buildPlayer(),
    );
    return ValueListenableBuilder<bool>(
      valueListenable: PlayerPanel.openState,
      builder: (context, open, _) => PopScope(
        canPop: !open,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) PlayerPanel.close();
        },
        child: _buildSheet(player),
      ),
    );
  }

  Widget _buildSheet(Widget player) {
    return AnimatedBuilder(
      animation: _panel.progress,
      child: player,
      builder: (context, child) {
        final double p = _panel.value;
        final double clamped = p.clamp(0.0, 1.0);
        final bool open = PlayerPanel.isOpen;
        final bool catchDrag = _catchPointer != null ||
            (!_panel.isDragging && (_inGrace || _panel.progress.isAnimating));
        final bool active = p > 0.0005 || _panel.isDragging || catchDrag;
        if (_travel <= 0) _measureTravel();
        final Size size = MediaQuery.sizeOf(context);
        final Rect from =
            _origin ?? Rect.fromLTWH(0, size.height, size.width, 0);
        // The surface starts as the bar and widens to the screen. Only the
        // first sliver is faded: the bar underneath stays visible as the
        // panel emerges from it, and comes back as the panel lands.
        final double widen = PlayerTokens.cPanelWiden.transform(clamped);
        final double left = from.left.clamp(0.0, size.width) * (1 - widen);
        final double right =
            (size.width - from.right).clamp(0.0, size.width) * (1 - widen);
        final double radius = _originRadius * (1 - widen);
        // A fade over a wider slice of the travel, not a pop on frame two.
        final double shell = Curves.easeInOut.transform(
          (clamped / PlayerTokens.panelShellHandoff).clamp(0.0, 1.0),
        );
        final double offset = (1 - clamped) * _travel;
        final double strength = _strengthAt(clamped, _flying);
        final RenderBox? host =
            _hostKey.currentContext?.findRenderObject() as RenderBox?;

        final double coverStrength = PlayerMorph.coverStrength.value;
        final barCover = _flying ? _barCover() : null;
        // Read the destination in sheet coordinates. Its screen position
        // already includes the slide, which would pull the cover twice.
        final panelCover = _flying ? _panelCover() : null;

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
            final Rect rect =
                dip > 0 ? plain.shift(Offset(0, -dip * (1 - clamped))) : plain;
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
            // Chrome animates while the panel rests, and stops while it
            // moves. Everything it draws is already in place at both ends,
            // so a frozen subtree composites from one cached raster instead
            // of re-rasterising the whole screen for each frame of the
            // flight. It resumes the moment the surface settles.
            enabled:
                (clamped > 0.0005 || _panel.isDragging) && !_panel.isMoving,
            child: Stack(
              children: [
                if (active)
                  IgnorePointer(
                    child: ColoredBox(
                      color: Colors.black.withValues(alpha: 0.5 * clamped),
                      child: const SizedBox.expand(),
                    ),
                  ),
                IgnorePointer(
                  // Opacity doesn't affect hit testing. Give taps back
                  // as soon as the mini player starts to show through.
                  ignoring: (!open && shell < 1) || clamped == 0,
                  child: Transform.translate(
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
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          child: child,
                        ),
                      ),
                    ),
                  ),
                ),
                if (catchDrag)
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    top: math.min(
                      offset,
                      size.height * (1 - PlayerTokens.panelGraceZone),
                    ),
                    // Translucent and drag-only so the mini bar still gets taps.
                    child: IgnorePointer(
                      ignoring: _panel.isDragging,
                      child: Listener(
                        behavior: HitTestBehavior.translucent,
                        onPointerDown: (event) =>
                            _catchPointer ??= event.pointer,
                        onPointerUp: _releaseCatchPointer,
                        onPointerCancel: _releaseCatchPointer,
                        child: RawGestureDetector(
                          behavior: HitTestBehavior.translucent,
                          gestures: {
                            _PanelCatchRecognizer:
                                GestureRecognizerFactoryWithHandlers<
                                    _PanelCatchRecognizer>(
                              _PanelCatchRecognizer.new,
                              (recognizer) => recognizer
                                ..onlyUp = !open && p <= 0
                                ..onStart = _onDismissDragStart
                                ..onUpdate = _onDismissDragUpdate
                                ..onEnd = _onDismissDragEnd
                                ..onCancel = _onDismissDragCancel,
                            ),
                          },
                        ),
                      ),
                    ),
                  ),
                ...transport,
                if (barCover != null && panelCover != null && song != null)
                  PlayerCoverFlight(
                    song: song,
                    from: barCover,
                    to: panelCover,
                    progress: clamped,
                    speed: _panel.coverSpeed,
                    travel: _travel,
                    opacity: coverStrength,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// After landing, downward swipes belong to the page under the catch zone.
class _PanelCatchRecognizer extends VerticalDragGestureRecognizer {
  _PanelCatchRecognizer() {
    dragStartBehavior = DragStartBehavior.down;
    onlyAcceptDragOnThreshold = true;
  }

  bool onlyUp = false;
  double? _upwardStartY;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _upwardStartY = onlyUp ? event.position.dy : null;
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    final double? start = _upwardStartY;
    if (start != null && event is PointerMoveEvent) {
      final double dy = event.position.dy - start;
      final double slop = computeHitSlop(event.kind, gestureSettings);
      if (dy > slop) {
        resolve(GestureDisposition.rejected);
        stopTrackingPointer(event.pointer);
        return;
      }
      if (dy < -slop) _upwardStartY = null;
    }
    super.handleEvent(event);
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
