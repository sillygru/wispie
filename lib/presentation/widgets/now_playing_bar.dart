import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'album_art_image.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/settings_provider.dart';
import '../routes/player_route.dart';
import '../tokens/app_tokens.dart';
import '../utils/wide_layout.dart';
import 'audio_visualizer.dart';
import 'duration_display.dart' show DurationFormatter;
import '../components/app_icon.dart';
import '../components/bar_seek_track.dart';
import '../components/favorite_heart_button.dart';
import '../components/pressable.dart';
import '../components/track_swipe_switcher.dart';
import '../components/transport_controls.dart';
import '../tokens/app_icons.dart';

class NowPlayingBar extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry padding;
  final bool embedded;
  final bool compact;

  /// Full-width Spotify-style bar pinned to the window bottom, not a floating slab.
  final bool docked;

  /// Width of the fixed rail on the window's left. The desktop layout pads the
  /// transport by this much so the controls sit on the window's centre line.
  final double leadingInset;

  const NowPlayingBar({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 12),
    this.embedded = false,
    this.compact = false,
    this.docked = false,
    this.leadingInset = 0,
  });

  @override
  ConsumerState<NowPlayingBar> createState() => _NowPlayingBarState();
}

class _NowPlayingBarState extends ConsumerState<NowPlayingBar>
    with WidgetsBindingObserver {
  String? _lastSongId;
  bool _appActive = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appActive = WidgetsBinding.instance.lifecycleState == null ||
        WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final active = state == AppLifecycleState.resumed;
    if (_appActive != active) {
      setState(() {
        _appActive = active;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final audioManager = ref.watch(audioPlayerManagerProvider);
    final player = audioManager.player;
    final settings = ref.watch(settingsProvider);
    ref.watch(audioPlayerManagerProvider).currentSongNotifier;
    final isBarVisible = TickerMode.valuesOf(context).enabled &&
        (ModalRoute.of(context)?.isCurrent ?? true);
    final isDesktop =
        Platform.isMacOS || Platform.isWindows || Platform.isLinux;
    final isIPad =
        Platform.isIOS && MediaQuery.of(context).size.shortestSide >= 600;
    final isWide = WideLayout.isWide(context);
    final roomy =
        isWide && (isDesktop || isIPad) && !WideLayout.isCompact(context);

    return StreamBuilder<SequenceState?>(
      stream: player.sequenceStateStream,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) return const SizedBox.shrink();

        final metadata = state.currentSource?.tag as MediaItem?;
        if (metadata == null) return const SizedBox.shrink();

        if (metadata.id != _lastSongId) {
          _lastSongId = metadata.id;
        }

        final song = ref
            .watch(songsProvider)
            .asData
            ?.value
            .where((item) => item.filename == metadata.id)
            .firstOrNull;

        return Padding(
          padding: widget.padding,
          child: _NowPlayingContent(
            metadata: metadata,
            player: player,
            visualizerMode: settings.visualizerMode,
            isBarVisible: isBarVisible,
            appActive: _appActive,
            theme: theme,
            roomy: roomy,
            compact: widget.compact,
            embedded: widget.embedded,
            docked: widget.docked,
            leadingInset: widget.leadingInset,
            coverVersion: song?.mtime,
            scrubbable: isDesktop,
          ),
        );
      },
    );
  }
}

class _NowPlayingContent extends ConsumerWidget {
  final MediaItem metadata;
  final AudioPlayer player;
  final VisualizerMode visualizerMode;
  final bool isBarVisible;
  final bool appActive;
  final ThemeData theme;
  final bool roomy;
  final bool compact;
  final bool embedded;
  final bool docked;
  final double leadingInset;
  final Object? coverVersion;

  /// Desktop can aim at the hairline, so it seeks there.
  final bool scrubbable;

  const _NowPlayingContent({
    required this.metadata,
    required this.player,
    required this.visualizerMode,
    required this.isBarVisible,
    required this.appActive,
    required this.theme,
    required this.roomy,
    required this.compact,
    required this.embedded,
    required this.scrubbable,
    this.docked = false,
    this.leadingInset = 0,
    this.coverVersion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double barHeight = compact ? (roomy ? 72 : 60) : (roomy ? 78 : 64);
    final double imageSize = compact ? 38 : 44;
    final double titleSize = compact ? 14 : 15;
    final double artistSize = compact ? 11 : 12;
    final BorderRadius borderRadius =
        docked ? BorderRadius.zero : AppTokens.brLg;
    final Color accent = AppTokens.accentOf(context, ref);

    final bool desktopBar = scrubbable && !compact;
    final audioManager = ref.read(audioPlayerManagerProvider);
    final bool favorite =
        ref.watch(userDataProvider.select((d) => d.isFavorite(metadata.id)));

    final Widget volume = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        AppIcon(AppIcons.volumeDown, size: 18, color: AppTokens.fgTertiary),
        SizedBox(
          width: 100,
          child: ValueListenableBuilder<double>(
            valueListenable: audioManager.userVolumeNotifier,
            builder: (context, volume, _) {
              return Slider(
                value: volume,
                activeColor: theme.colorScheme.primary,
                onChanged: audioManager.setUserVolume,
              );
            },
          ),
        ),
        AppIcon(AppIcons.volumeUp, size: 18, color: AppTokens.fgTertiary),
      ],
    );

    final Widget favoriteButton = Tooltip(
      message: favorite ? 'Remove from favorites' : 'Add to favorites',
      child: FavoriteHeartButton(
        filename: metadata.id,
        title: metadata.title,
        accent: accent,
        inactiveColor: AppTokens.fgTertiary,
        iconSize: 20,
        boxSize: 36,
      ),
    );

    final Widget shuffle = ValueListenableBuilder<bool>(
      valueListenable: audioManager.shuffleNotifier,
      builder: (context, shuffling, _) => Tooltip(
        message: 'Shuffle',
        child: Pressable(
          onTap: audioManager.toggleShuffle,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AppIcon(
              AppIcons.shuffle,
              size: 20,
              color: shuffling ? accent : AppTokens.fgTertiary,
            ),
          ),
        ),
      ),
    );

    final Widget repeat = StreamBuilder<LoopMode>(
      stream: player.loopModeStream,
      initialData: player.loopMode,
      builder: (context, snapshot) => RepeatToggleButton(
        loopMode: snapshot.data ?? LoopMode.off,
        accent: accent,
        idleColor: AppTokens.fgTertiary,
        onChanged: player.setLoopMode,
      ),
    );

    final Widget transport = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (desktopBar) shuffle,
        Pressable(
          onTap: player.hasPrevious ? player.seekToPrevious : null,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AppIcon(
              AppIcons.skipPrevious,
              size: compact ? 22 : 28,
              color: Colors.white,
            ),
          ),
        ),
        ValueListenableBuilder<bool>(
          valueListenable: audioManager.playingNotifier,
          builder: (context, playing, _) => StreamBuilder<PlayerState>(
            stream: player.playerStateStream,
            builder: (context, snapshot) {
              final playerState = snapshot.data;
              final processingState = playerState?.processingState;

              if (processingState == ProcessingState.buffering) {
                return const Padding(
                  padding: EdgeInsets.all(8.0),
                  child: SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                );
              }

              // Solid accent disc: the one primary action gets
              // the one strong colour block in the bar.
              final double disc = compact ? 34 : 42;
              return Tooltip(
                message: playing ? 'Pause' : 'Play',
                child: Pressable(
                  onTap: () => audioManager.togglePlayPause(),
                  child: Container(
                    width: disc,
                    height: disc,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: accent,
                      shape: BoxShape.circle,
                    ),
                    child: PlayPauseMorphIcon(
                      playing: playing,
                      size: compact ? 18 : 22,
                      color: AppTokens.onAccent(accent),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        Pressable(
          onTap: player.hasNext ? player.seekToNext : null,
          onLongPressStart: (_) => audioManager.startFastForward(),
          onLongPressEnd: (_) => audioManager.stopFastForward(),
          onLongPressCancel: () => audioManager.stopFastForward(),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: AppIcon(
              AppIcons.skipNext,
              size: compact ? 22 : 28,
              color: Colors.white,
            ),
          ),
        ),
        if (desktopBar) repeat,
      ],
    );

    final Widget content = SizedBox(
      height: barHeight,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: compact ? 12 : 14,
            ),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context)
                        .push(PlayerPageRoute(songId: metadata.id)),
                    child: ClipRect(
                      child: TrackSwipeSwitcher<(MediaItem, Object?)>(
                        item: (metadata, coverVersion),
                        idOf: (m) => m.$1.id,
                        audioManager: ref.read(audioPlayerManagerProvider),
                        travel: 0.6,
                        fade: 1,
                        builder: (context, m, _) => Row(
                          children: [
                            Hero(
                              tag: 'now_playing_art_${m.$1.id}',
                              child: SizedBox(
                                width: imageSize,
                                height: imageSize,
                                child: ClipRRect(
                                  borderRadius: AppTokens.brSm,
                                  child: Stack(
                                    children: [
                                      AlbumArtImage(
                                        key: ValueKey(
                                            'now_playing_art_${m.$1.id}'),
                                        url: m.$1.artUri?.toString() ?? '',
                                        filename: m.$1.id,
                                        cacheVersion: m.$2,
                                        width: imageSize,
                                        height: imageSize,
                                        fit: BoxFit.cover,
                                      ),
                                      StreamBuilder<PlayerState>(
                                        stream: player.playerStateStream,
                                        builder: (context, snapshot) {
                                          final playing =
                                              snapshot.data?.playing ?? false;

                                          return Positioned.fill(
                                            child: PlayingVisualizerOverlay(
                                              playing: playing && isBarVisible,
                                              mode: visualizerMode,
                                              size: compact ? 18 : 22,
                                              scrim: Colors.black
                                                  .withValues(alpha: 0.28),
                                            ),
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            SizedBox(width: compact ? 10 : 12),
                            Expanded(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    m.$1.title,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTokens.rowTitle(context)
                                        .copyWith(fontSize: titleSize),
                                  ),
                                  Text(
                                    m.$1.artist ?? 'Unknown Artist',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: AppTokens.rowSubtitle(context)
                                        .copyWith(fontSize: artistSize),
                                  ),
                                  // Desktop has the width and the bar height
                                  // for it; the compact pill does not.
                                  if (desktopBar) ...[
                                    const SizedBox(height: 2),
                                    _BarElapsedTotal(
                                      player: player,
                                      fallbackDuration: m.$1.duration,
                                      live: isBarVisible && appActive,
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!desktopBar && !compact && roomy) ...[
                  volume,
                  const SizedBox(width: 12),
                ],
                if (desktopBar)
                  // The rail eats the bar's left edge, so the right cluster is
                  // padded by the same width to keep the transport on the
                  // window's centre line.
                  Expanded(
                    child: Center(
                      child: Padding(
                        padding: EdgeInsets.only(right: leadingInset),
                        child: transport,
                      ),
                    ),
                  )
                else
                  transport,
                if (desktopBar)
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (roomy) ...[
                            volume,
                            const SizedBox(width: 8),
                          ],
                          favoriteButton,
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
          Positioned(
            // Inset hairline track under the text instead of a full-width
            // strip, so the rounded corners never crop it.
            // Compact runs the line along the very bottom, inset past the
            // corner radius, so it never crowds the artwork above it.
            left: compact ? AppTokens.s5 : 14,
            right: compact ? AppTokens.s5 : (desktopBar ? 14 + 40 : 14),
            bottom: compact ? 3 : AppTokens.s1 + 2,
            // A taller band to hit, stopping short of the transport buttons above it.
            height: scrubbable ? AppTokens.s2 + 2 : null,
            child: BarSeekTrack(
              player: player,
              accent: accent,
              trackColor: Colors.white.withValues(alpha: 0.10),
              thickness: compact ? 2 : 3,
              interactive: scrubbable,
              live: isBarVisible && appActive,
            ),
          ),
        ],
      ),
    );

    if (embedded) {
      return ClipRRect(
        borderRadius: borderRadius,
        child: content,
      );
    }

    // The bar floats over scrolling content as an L2 slab. Opaque fill (never
    // glass — content must not show through) lifted one notch off the canvas,
    // and a soft floating shadow does the lifting.
    // A light accent wash ties the bar to the current cover palette.
    final Color fill = Color.alphaBlend(
      accent.withValues(alpha: 0.10),
      Color.alphaBlend(
        AppTokens.floatingFill,
        Theme.of(context).colorScheme.surface,
      ),
    );

    if (docked) {
      return DecoratedBox(
        decoration: BoxDecoration(color: fill),
        child: content,
      );
    }

    final Widget bar = ClipRRect(
      borderRadius: borderRadius,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: borderRadius,
        ),
        child: content,
      ),
    );

    // Shadow lives outside the clip so it is not cropped to the bar's corners.
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: borderRadius,
        boxShadow: AppTokens.shadowFloating,
      ),
      child: bar,
    );
  }
}

/// "1:24 / 4:07" — the third line of the docked desktop bar's song block.
///
/// Its own stateful widget on purpose: position ticks several times a second,
/// and rebuilding the whole bar for that would drag the volume slider and the
/// hero art through it too.
class _BarElapsedTotal extends StatefulWidget {
  final AudioPlayer player;

  /// Length to show until the player reports one of its own.
  final Duration? fallbackDuration;

  /// Off when the bar is off-screen or the window is in the background.
  final bool live;

  const _BarElapsedTotal({
    required this.player,
    this.fallbackDuration,
    this.live = true,
  });

  @override
  State<_BarElapsedTotal> createState() => _BarElapsedTotalState();
}

class _BarElapsedTotalState extends State<_BarElapsedTotal> {
  Duration _position = Duration.zero;
  Duration? _duration;
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration?>? _durationSub;

  @override
  void initState() {
    super.initState();
    _duration = widget.player.duration ?? widget.fallbackDuration;
    _listen();
  }

  @override
  void didUpdateWidget(_BarElapsedTotal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.live != widget.live) _listen();
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    super.dispose();
  }

  void _listen() {
    _positionSub?.cancel();
    _durationSub?.cancel();
    if (!widget.live) {
      _positionSub = null;
      _durationSub = null;
      return;
    }
    _positionSub = widget.player.positionStream.listen((p) {
      if (p == _position || !mounted) return;
      setState(() => _position = p);
    });
    _durationSub = widget.player.durationStream.listen((d) {
      if (!mounted) return;
      setState(() => _duration = d ?? widget.fallbackDuration);
    });
  }

  @override
  Widget build(BuildContext context) {
    final Duration? total = _duration;
    final bool known = total != null && total.inMilliseconds > 0;
    return Text(
      known
          // Zero reads as the start of the track, not as a missing length.
          ? '${_position <= Duration.zero ? '00:00' : DurationFormatter.format(_position)}'
              ' / ${DurationFormatter.format(total)}'
          : '--:--',
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: AppTokens.meta(context).copyWith(
        // Without tabular figures the label jitters sideways every second.
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}
