import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../routes/player_route.dart';
import '../tokens/app_tokens.dart';
import '../tokens/player_tokens.dart';
import '../widgets/album_art_image.dart';
import '../widgets/audio_visualizer.dart';
import 'app_icon.dart';
import 'app_nav_bar.dart';
import 'bar_seek_track.dart';
import 'pressable.dart';
import 'transport_controls.dart';
import 'track_swipe_switcher.dart';
import '../tokens/app_icons.dart';

/// Floating bottom chrome for narrow windows: one navigation pill with the mini
/// player resting above it. Scrolling down morphs the mini player into a cover
/// ball beside the pill; scrolling up grows it back.
///
/// The dock owns the whole gesture. [FloatingDockState.handleScroll] is fed
/// every scroll notification from the pages: each delta scrubs the morph
/// directly (wheel, trackpad, drag and fling alike), and once the scroll has
/// been quiet for a moment a spring takes it to the nearest end. The settle is
/// timer-driven rather than waiting on a ScrollEnd event, so the dock can
/// never be left parked halfway.
class FloatingDock extends StatefulWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<AppNavItem> items;

  /// When false the dock stays expanded and ignores scrolling.
  final bool autoCollapse;

  static const double pillHeight = 60;

  static const double miniHeight = 64;

  /// Where the compact bar draws its artwork, so the travelling cover can
  /// start exactly on top of it.
  static const double barArtInset = 10;
  static const double barArtSize = 44;
  static const double ballArtInset = 4;

  /// Scroll distance that commits the morph. Scrolling is measured first and the
  /// dock only moves once this much travel has built up in one direction, then
  /// springs to the new end. Expanding is deliberately quicker: reaching back
  /// for the player should not take much scrolling.
  static const double collapseDistance = 56;
  static const double expandDistance = 28;

  /// Quiet time after which a sub-threshold scroll is forgotten.
  static const Duration settleDelay = Duration(milliseconds: 160);

  const FloatingDock({
    super.key,
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.autoCollapse,
  });

  static final SpringDescription _spring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 300, ratio: 0.92);

  @override
  State<FloatingDock> createState() => FloatingDockState();
}

class FloatingDockState extends State<FloatingDock>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController.unbounded(vsync: this, value: 0);
  Timer? _settle;

  /// Direction of the most recent scroll movement: true = downward.
  bool _down = false;

  /// Travel accumulated in the current direction since the dock last moved.
  double _pending = 0;

  void handleScroll(ScrollNotification n) {
    if (!widget.autoCollapse) return;
    if (n.metrics.axis != Axis.vertical) return;

    if (n.metrics.pixels <= n.metrics.minScrollExtent) {
      _pending = 0;
      _springTo(0);
      return;
    }
    if (n is! ScrollUpdateNotification) return;
    // Overscroll bounce at the bottom edge is not intent.
    if (n.metrics.pixels >= n.metrics.maxScrollExtent) return;
    final double delta = n.scrollDelta ?? 0;
    if (delta == 0) return;

    final bool down = delta > 0;
    if (down != _down) {
      _down = down;
      _pending = 0;
    }
    _pending += delta.abs();

    _settle?.cancel();
    _settle = Timer(FloatingDock.settleDelay, () => _pending = 0);

    final double threshold =
        down ? FloatingDock.collapseDistance : FloatingDock.expandDistance;
    if (_pending >= threshold) {
      _pending = 0;
      _springTo(down ? 1 : 0);
    }
  }

  void _springTo(double target) {
    if (_c.value == target && !_c.isAnimating) return;
    _c.animateWith(
      SpringSimulation(FloatingDock._spring, _c.value, target, _c.velocity),
    );
  }

  @override
  void didUpdateWidget(covariant FloatingDock oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.autoCollapse) _springTo(0);
  }

  @override
  void dispose() {
    _settle?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) => _DockBody(
        selectedIndex: widget.selectedIndex,
        onSelected: widget.onSelected,
        items: widget.items,
        collapse: _c.value,
      ),
    );
  }
}

class _DockBody extends ConsumerWidget {
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final List<AppNavItem> items;
  final double collapse;

  const _DockBody({
    required this.selectedIndex,
    required this.onSelected,
    required this.items,
    required this.collapse,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    const double pillHeight = FloatingDock.pillHeight;
    const double miniHeight = FloatingDock.miniHeight;
    final accent = AppTokens.accentOf(context, ref);
    final manager = ref.watch(audioPlayerManagerProvider);
    final double bottomInset = MediaQuery.paddingOf(context).bottom;
    // Same side gutter as the page content, so the dock lines up with the
    // list above it instead of running wider than everything else.
    final double gutter = AppTokens.s5;
    final double gap = AppTokens.s2;
    final double pillBottom = bottomInset > 0 ? bottomInset : AppTokens.s4;
    final Color canvas = Theme.of(context).colorScheme.surface;
    final Color fill = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      Color.alphaBlend(
        AppTokens.floatingFill,
        Theme.of(context).colorScheme.surface,
      ),
    );

    return ValueListenableBuilder<Song?>(
      valueListenable: manager.currentSongNotifier,
      builder: (context, song, _) {
        final bool hasSong = song != null;
        final double c = hasSong ? collapse : 0.0;
        final double height = pillBottom +
            pillHeight +
            (hasSong ? (gap + miniHeight) * (1 - c) : 0);

        return LayoutBuilder(
          builder: (context, constraints) {
            final double w = constraints.maxWidth;
            // Every axis reads the same spring value. The spring already
            // supplies the easing, and a second curve on one axis made the bar
            // travel on a different clock than its own height and width, which
            // is what read as wrong. The value is deliberately not clamped: the
            // overshoot is what makes a spring feel physical, and clamping it
            // stops the bar dead.
            final double cx = c;
            final double cy = c;
            final double cp = ((c - 0.15) / 0.85).clamp(0.0, 1.0);
            final double pillWidth =
                w - 2 * gutter - (hasSong ? (pillHeight + gap) * cp : 0);

            // Mini player rect, lerped between the bar above the pill and the
            // ball beside it.
            final Rect expanded = Rect.fromLTWH(
              gutter,
              0,
              w - 2 * gutter,
              miniHeight,
            );
            final Rect ball = Rect.fromLTWH(
              w - gutter - pillHeight,
              height - pillBottom - pillHeight,
              pillHeight,
              pillHeight,
            );
            final Rect mini = Rect.fromLTRB(
              ui.lerpDouble(expanded.left, ball.left, cx)!,
              ui.lerpDouble(expanded.top, ball.top, cy)!,
              ui.lerpDouble(expanded.right, ball.right, cx)!,
              ui.lerpDouble(expanded.bottom, ball.bottom, cy)!,
            );
            // Corners round toward a full capsule quickly so the shrinking bar
            // never reads as a squashed ellipse.
            final double radius = math.min(
              mini.height / 2,
              ui.lerpDouble(
                  AppTokens.rLg, mini.height / 2, cy.clamp(0.0, 1.0))!,
            );

            return SizedBox(
              height: height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  // Legibility scrim: rows fade out behind the dock instead of
                  // peeking through the gaps between its pieces.
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 0,
                    top: -AppTokens.s6,
                    child: IgnorePointer(
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: <Color>[
                              for (var i = 0; i <= 5; i++)
                                canvas.withValues(
                                  alpha: 0.92 * Curves.easeOut.transform(i / 5),
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: gutter,
                    bottom: pillBottom,
                    width: pillWidth,
                    height: pillHeight,
                    child: _NavPill(
                      items: items,
                      selectedIndex: selectedIndex,
                      onSelected: onSelected,
                      accent: accent,
                      fill: fill,
                    ),
                  ),
                  if (hasSong)
                    Positioned.fromRect(
                      rect: mini,
                      child: _MorphingMini(
                        song: song,
                        collapse: c,
                        radius: radius,
                        expandedWidth: expanded.width,
                        fill: fill,
                        accent: accent,
                      ),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _NavPill extends StatelessWidget {
  final List<AppNavItem> items;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final Color accent;
  final Color fill;

  const _NavPill({
    required this.items,
    required this.selectedIndex,
    required this.onSelected,
    required this.accent,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: fill,
        borderRadius: AppTokens.brPill,
        boxShadow: AppTokens.shadowFloating,
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final double inset = AppTokens.s1 + 2;
          final double segment =
              (constraints.maxWidth - 2 * inset) / items.length;
          return Stack(
            children: [
              // One indicator slides between destinations instead of each
              // tab fading its own highlight in and out.
              AnimatedPositioned(
                duration: AppTokens.dBase,
                curve: AppTokens.cEmphasized,
                left: inset + segment * selectedIndex,
                top: inset,
                bottom: inset,
                width: segment,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: AppTokens.accentWashAlpha),
                    borderRadius: AppTokens.brPill,
                  ),
                ),
              ),
              Padding(
                padding: EdgeInsets.symmetric(horizontal: inset),
                child: Row(
                  children: [
                    for (var i = 0; i < items.length; i++)
                      Expanded(
                        child: Semantics(
                          button: true,
                          selected: i == selectedIndex,
                          label: items[i].label,
                          child: Pressable(
                            haptic: PressHaptic.selection,
                            spring: AppTokens.springSnappy,
                            onTap: () => onSelected(i),
                            child: _PillDestination(
                              item: items[i],
                              selected: i == selectedIndex,
                              accent: accent,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PillDestination extends StatelessWidget {
  final AppNavItem item;
  final bool selected;
  final Color accent;

  const _PillDestination({
    required this.item,
    required this.selected,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final Color color = selected ? accent : AppTokens.fg(AppTokens.aTertiary);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        AnimatedScale(
          scale: selected ? 1.08 : 1.0,
          duration: AppTokens.dBase,
          curve: AppTokens.cEmphasized,
          child: AppIcon(
            selected ? item.selectedIcon : item.icon,
            size: AppTokens.iconMd,
            color: color,
            strokeWidth:
                selected ? AppTokens.iconStrokeEmphasis : AppTokens.iconStroke,
          ),
        ),
        const SizedBox(height: 2),
        AnimatedDefaultTextStyle(
          duration: AppTokens.dFast,
          curve: AppTokens.cStandard,
          style: AppTokens.meta(context).copyWith(
            color: color,
            fontSize: 11.5,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
          child: Text(item.label, maxLines: 1, overflow: TextOverflow.fade),
        ),
      ],
    );
  }
}

/// The mini player while it morphs. The full bar keeps its expanded width and
/// is clipped by the shrinking capsule (nothing reflows), fading out early.
/// The cover is lifted out as its own layer that travels from the bar's art
/// slot into the ball, so the eye follows one object instead of watching two
/// crossfade.
class _MorphingMini extends ConsumerWidget {
  final Song song;
  final double collapse;
  final double radius;
  final double expandedWidth;
  final Color fill;
  final Color accent;

  const _MorphingMini({
    required this.song,
    required this.collapse,
    required this.radius,
    required this.expandedWidth,
    required this.fill,
    required this.accent,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final manager = ref.watch(audioPlayerManagerProvider);
    final visualizerMode =
        ref.watch(settingsProvider.select((s) => s.visualizerMode));
    final bool spinArtwork =
        ref.watch(settingsProvider.select((s) => s.spinArtworkWhilePlaying));
    final double barOpacity =
        1 - Curves.easeOut.transform((collapse / 0.3).clamp(0.0, 1.0));
    // Last third of the morph: the circle has formed, so the layers that only
    // make sense on the ball (progress ring, bars, spin) come up here rather
    // than appearing on the bar and travelling with it.
    final double ballOpacity = ((collapse - 0.7) / 0.3).clamp(0.0, 1.0);
    final BorderRadius br = BorderRadius.circular(radius);

    return LayoutBuilder(
      builder: (context, constraints) {
        final Size size = constraints.biggest;
        final double t = collapse;
        final double tRadius = t.clamp(0.0, 1.0);
        final Rect barArt = Rect.fromLTWH(
          FloatingDock.barArtInset,
          (size.height - FloatingDock.barArtSize) / 2,
          FloatingDock.barArtSize,
          FloatingDock.barArtSize,
        );
        final double ballSide =
            size.shortestSide - 2 * FloatingDock.ballArtInset;
        final Rect ballArt = Rect.fromLTWH(
          (size.width - ballSide) / 2,
          (size.height - ballSide) / 2,
          ballSide,
          ballSide,
        );
        final Rect art = Rect.lerp(barArt, ballArt, t)!;
        final double artRadius =
            ui.lerpDouble(AppTokens.rSm, art.shortestSide / 2, tRadius)!;

        return Pressable(
          onTap: collapse > 0.5
              ? () => Navigator.of(context)
                  .push(PlayerPageRoute(songId: song.filename))
              : null,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: br,
              boxShadow: AppTokens.shadowFloating,
            ),
            child: ClipRRect(
              borderRadius: br,
              child: ColoredBox(
                color: fill,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    if (barOpacity > 0)
                      IgnorePointer(
                        ignoring: collapse > 0.05,
                        child: Opacity(
                          opacity: barOpacity,
                          child: OverflowBox(
                            alignment: Alignment.centerLeft,
                            minWidth: expandedWidth,
                            maxWidth: expandedWidth,
                            minHeight: FloatingDock.miniHeight,
                            maxHeight: FloatingDock.miniHeight,
                            child: _DockMiniBar(song: song, accent: accent),
                          ),
                        ),
                      ),
                    // At rest the bar paints its own cover (with the playing
                    // visualizer), so the travelling copy only exists in motion.
                    if (collapse > 0.001)
                      Positioned.fromRect(
                        rect: art,
                        child: ValueListenableBuilder<bool>(
                          valueListenable: manager.playingNotifier,
                          builder: (context, playing, _) => AnimatedOpacity(
                            // Paused reads as a dimmed cover, not a new icon.
                            opacity: playing || collapse < 0.7 ? 1 : 0.55,
                            duration: AppTokens.dBase,
                            curve: AppTokens.cStandard,
                            child: _heroIfOwner(
                              // Only one Hero per tag may exist on the route: the
                              // bar owns it until it has faded out, then the
                              // travelling cover takes over so opening the player
                              // from the ball still flies the artwork.
                              owns: barOpacity <= 0,
                              tag: PlayerTokens.coverHeroTag(song.filename),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(artRadius),
                                child: Stack(
                                  fit: StackFit.expand,
                                  children: [
                                    _SpinArtwork(
                                      enabled: spinArtwork &&
                                          playing &&
                                          ballOpacity > 0,
                                      child: AlbumArtImage(
                                        url: song.coverUrl ?? '',
                                        filename: song.filename,
                                        cacheVersion: song.mtime,
                                        width: FloatingDock.pillHeight,
                                        height: FloatingDock.pillHeight,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                    // The ball has room for the track's own bars,
                                    // so the same signal the expanded bar gives
                                    // survives the collapse.
                                    if (ballOpacity > 0)
                                      Opacity(
                                        opacity: ballOpacity,
                                        child: PlayingVisualizerOverlay(
                                          playing: playing,
                                          mode: visualizerMode,
                                          size: 20,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    if (ballOpacity > 0)
                      IgnorePointer(
                        child: Opacity(
                          opacity: ballOpacity,
                          child: _ProgressRing(accent: accent),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// The expanded mini player. The whole surface opens the player; a horizontal
/// swipe drags the track info with the finger and, past the threshold, flings
/// it off and skips, with the new track sliding in from the opposite side.
class _DockMiniBar extends ConsumerStatefulWidget {
  final Song song;
  final Color accent;

  const _DockMiniBar({required this.song, required this.accent});

  @override
  ConsumerState<_DockMiniBar> createState() => _DockMiniBarState();
}

class _DockMiniBarState extends ConsumerState<_DockMiniBar>
    with SingleTickerProviderStateMixin {
  static final SpringDescription _spring =
      SpringDescription.withDampingRatio(mass: 1, stiffness: 320, ratio: 0.88);

  /// Horizontal offset of the track info, in logical pixels.
  late final AnimationController _x =
      AnimationController.unbounded(vsync: this, value: 0);

  /// +1 after a swipe to next, -1 to previous, until the song changes.
  int _pending = 0;
  Timer? _pendingTimeout;
  double _width = 1;

  @override
  void didUpdateWidget(covariant _DockMiniBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.song.filename == widget.song.filename) return;
    // Swipe-driven skips enter from the side opposite the fling; anything
    // else (skip button, auto-advance) enters from the right like a next.
    final int dir = _pending != 0 ? _pending : 1;
    _pending = 0;
    _pendingTimeout?.cancel();
    _x.value = dir * _width * 0.45;
    _x.animateWith(SpringSimulation(_spring, _x.value, 0, 0));
  }

  @override
  void dispose() {
    _pendingTimeout?.cancel();
    _x.dispose();
    super.dispose();
  }

  void _onDragUpdate(DragUpdateDetails d) {
    final player = ref.read(audioPlayerManagerProvider).player;
    final double next = _x.value + d.delta.dx;
    final bool blocked =
        (next < 0 && !player.hasNext) || (next > 0 && !player.hasPrevious);
    // Rubber-band when there is nothing to skip to.
    _x.value = _x.value + d.delta.dx * (blocked ? 0.25 : 1);
  }

  void _onDragEnd(DragEndDetails d) {
    final player = ref.read(audioPlayerManagerProvider).player;
    final double v = d.primaryVelocity ?? 0;
    final double x = _x.value;
    final bool fling = v.abs() > 500 && v.sign == x.sign;
    final bool far = x.abs() > _width * 0.28;
    final int dir = x < 0 ? 1 : -1;
    final bool can = dir > 0 ? player.hasNext : player.hasPrevious;
    if ((fling || far) && can && x != 0) {
      _pending = dir;
      _x
          .animateTo(
        -dir * _width,
        duration: AppTokens.dFast,
        curve: Curves.easeIn,
      )
          .whenComplete(() {
        if (!mounted) return;
        TrackSwipeSwitcher.hint(dir);
        dir > 0 ? player.seekToNext() : player.seekToPrevious();
        // If the skip never lands (end of queue race), come back home.
        _pendingTimeout?.cancel();
        _pendingTimeout = Timer(const Duration(milliseconds: 700), () {
          if (!mounted || _pending == 0) return;
          _pending = 0;
          _x.animateWith(SpringSimulation(_spring, _x.value, 0, 0));
        });
      });
      return;
    }
    _x.animateWith(SpringSimulation(_spring, x, 0, v));
  }

  @override
  Widget build(BuildContext context) {
    final manager = ref.watch(audioPlayerManagerProvider);
    final player = manager.player;
    final Song song = widget.song;
    final Color accent = widget.accent;
    // A mouse can aim at the hairline; a finger cannot.
    final TargetPlatform platform = Theme.of(context).platform;
    final bool desktop = platform == TargetPlatform.macOS ||
        platform == TargetPlatform.windows ||
        platform == TargetPlatform.linux;
    const double inset = FloatingDock.barArtInset;
    const double art = FloatingDock.barArtSize;
    // Right edge the transport controls claim. The track column and the
    // progress hairline both stop short of it so neither runs under the
    // buttons on a narrow phone.
    const double transportInset = 100;

    return LayoutBuilder(
      builder: (context, constraints) {
        _width = constraints.maxWidth;
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context)
              .push(PlayerPageRoute(songId: song.filename)),
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Stack(
            children: [
              Positioned.fill(
                right: transportInset,
                child: ClipRect(
                  child: AnimatedBuilder(
                    animation: _x,
                    builder: (context, child) {
                      final double k =
                          (_x.value.abs() / (_width * 0.6)).clamp(0.0, 1.0);
                      return Opacity(
                        opacity: 1 - k,
                        child: Transform.translate(
                          offset: Offset(_x.value, 0),
                          child: child,
                        ),
                      );
                    },
                    child: Row(
                      children: [
                        const SizedBox(width: inset),
                        Hero(
                          tag: PlayerTokens.coverHeroTag(song.filename),
                          child: ClipRRect(
                            borderRadius: AppTokens.brSm,
                            child: SizedBox(
                              width: art,
                              height: art,
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  AlbumArtImage(
                                    url: song.coverUrl ?? '',
                                    filename: song.filename,
                                    cacheVersion: song.mtime,
                                    width: art,
                                    height: art,
                                    fit: BoxFit.cover,
                                  ),
                                  ValueListenableBuilder<bool>(
                                    valueListenable: manager.playingNotifier,
                                    builder: (context, playing, _) =>
                                        PlayingVisualizerOverlay(
                                      playing: playing,
                                      mode: ref.watch(
                                        settingsProvider.select(
                                          (s) => s.visualizerMode,
                                        ),
                                      ),
                                      size: 18,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: AppTokens.s3),
                        Expanded(
                          child: MediaQuery(
                            // The card is a fixed 64 high, so two stacked
                            // lines stop fitting once the system font grows;
                            // the same 1.25 ceiling the cards use keeps them
                            // inside it.
                            data: MediaQuery.of(context).copyWith(
                              textScaler: MediaQuery.textScalerOf(context)
                                  .clamp(maxScaleFactor: 1.25),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  song.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTokens.rowTitle(context).copyWith(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 1),
                                Text(
                                  song.artist,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: AppTokens.rowSubtitle(context)
                                      .copyWith(fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                right: AppTokens.s2,
                top: 0,
                bottom: 0,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable: manager.playingNotifier,
                      builder: (context, playing, _) => Tooltip(
                        message: playing ? 'Pause' : 'Play',
                        child: Pressable(
                          onTap: manager.togglePlayPause,
                          child: Container(
                            width: 40,
                            height: 40,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: accent,
                              shape: BoxShape.circle,
                            ),
                            child: PlayPauseMorphIcon(
                              playing: playing,
                              size: 20,
                              color: AppTokens.onAccent(accent),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppTokens.s1),
                    Tooltip(
                      message: 'Next',
                      child: Pressable(
                        onTap: () {
                          TrackSwipeSwitcher.hint(1);
                          player.seekToNext();
                        },
                        child: const Padding(
                          padding: EdgeInsets.all(AppTokens.s2),
                          child: AppIcon(
                            AppIcons.skipNext,
                            size: 22,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              // Progress hairline aligned with the text column, inside the
              // card rather than on its rounded edge. It stops at the same
              // inset as that column, or on a narrow phone it runs underneath
              // the transport buttons.
              Positioned(
                left: inset + art + AppTokens.s3,
                right: transportInset,
                bottom: AppTokens.s1 + 1,
                height: desktop ? AppTokens.s2 : 2,
                child: BarSeekTrack(
                  player: player,
                  accent: accent,
                  trackColor: Colors.white.withValues(alpha: 0.10),
                  interactive: desktop,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

Widget _heroIfOwner({
  required bool owns,
  required String tag,
  required Widget child,
}) =>
    owns ? Hero(tag: tag, child: child) : child;

/// One slow revolution while [enabled].
///
/// The collapsed ball is a still circle with a progress ring, so on its own it
/// barely says anything is playing. The turn is slow enough to read as a record
/// rather than a spinner, and the ticker is torn down the moment it is not
/// wanted — a paused ball costs nothing.
class _SpinArtwork extends StatefulWidget {
  static const Duration revolution = Duration(seconds: 45);

  final bool enabled;
  final Widget child;

  const _SpinArtwork({required this.enabled, required this.child});

  @override
  State<_SpinArtwork> createState() => _SpinArtworkState();
}

class _SpinArtworkState extends State<_SpinArtwork>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: _SpinArtwork.revolution,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(_SpinArtwork oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.enabled != widget.enabled) _sync();
  }

  void _sync() {
    // Stopping rather than resetting leaves the controller where it was, so a
    // paused ball resumes mid-turn instead of snapping back to upright.
    final bool on = widget.enabled &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (on && !_c.isAnimating) {
      _c.repeat();
    } else if (!on && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Isolated so the turn is a compositor transform on a cached layer rather
    // than a raster every frame, next to a progress ring that repaints too.
    return RepaintBoundary(
      child: RotationTransition(turns: _c, child: widget.child),
    );
  }
}

class _ProgressRing extends ConsumerWidget {
  final Color accent;

  const _ProgressRing({required this.accent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final player = ref.watch(audioPlayerManagerProvider).player;
    return RepaintBoundary(
      child: StreamBuilder<Duration>(
        stream: player.positionStream,
        initialData: player.position,
        builder: (context, snapshot) {
          final total = player.duration ?? Duration.zero;
          final double p = total.inMilliseconds > 0
              ? (snapshot.data ?? Duration.zero).inMilliseconds /
                  total.inMilliseconds
              : 0.0;
          return CustomPaint(
            painter: _RingPainter(progress: p.clamp(0.0, 1.0), color: accent),
          );
        },
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  final double progress;
  final Color color;

  const _RingPainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    // Sits in the gutter between the cover and the capsule edge.
    const double stroke = 2;
    final Rect rect =
        (Offset.zero & size).deflate(FloatingDock.ballArtInset / 2);
    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = Colors.white.withValues(alpha: 0.12);
    canvas.drawArc(rect, 0, math.pi * 2, false, track);
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * progress,
      false,
      track
        ..color = color
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color;
}
