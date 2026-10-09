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
import '../components/app_icon.dart';
import '../components/bar_seek_track.dart';
import '../components/pressable.dart';
import '../components/track_swipe_switcher.dart';
import '../components/transport_controls.dart';
import '../tokens/app_icons.dart';

class NowPlayingBar extends ConsumerStatefulWidget {
  final EdgeInsetsGeometry padding;
  final bool embedded;
  final bool compact;

  const NowPlayingBar({
    super.key,
    this.padding = const EdgeInsets.fromLTRB(12, 0, 12, 12),
    this.embedded = false,
    this.compact = false,
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

  void _openPlayer(BuildContext context, MediaItem metadata) {
    Navigator.of(context).push(PlayerPageRoute(songId: metadata.id));
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

        return GestureDetector(
          onTap: () => _openPlayer(context, metadata),
          child: Padding(
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
              coverVersion: song?.mtime,
              scrubbable: isDesktop,
            ),
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
    this.coverVersion,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final double barHeight = compact ? (roomy ? 72 : 60) : (roomy ? 78 : 64);
    final double imageSize = compact ? 38 : 44;
    final double titleSize = compact ? 14 : 15;
    final double artistSize = compact ? 11 : 12;
    final BorderRadius borderRadius = AppTokens.brLg;
    final Color accent = AppTokens.accentOf(context, ref);

    final Widget content = SizedBox(
      height: barHeight,
      child: Stack(
        children: [
          Padding(
            padding: EdgeInsets.symmetric(horizontal: compact ? 12 : 14),
            child: Row(
              children: [
                Expanded(
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
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                if (!compact && roomy) ...[
                  AppIcon(AppIcons.volumeDown,
                      size: 18, color: AppTokens.fgTertiary),
                  SizedBox(
                    width: 100,
                    child: StreamBuilder<double>(
                      stream: player.volumeStream,
                      builder: (context, snapshot) {
                        return Slider(
                          value: snapshot.data ?? 1.0,
                          activeColor: theme.colorScheme.primary,
                          onChanged: player.setVolume,
                        );
                      },
                    ),
                  ),
                  AppIcon(AppIcons.volumeUp,
                      size: 18, color: AppTokens.fgTertiary),
                  const SizedBox(width: 12),
                ],
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ValueListenableBuilder<bool>(
                      valueListenable:
                          ref.read(audioPlayerManagerProvider).playingNotifier,
                      builder: (context, playing, _) =>
                          StreamBuilder<PlayerState>(
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
                              onTap: () => ref
                                  .read(audioPlayerManagerProvider)
                                  .togglePlayPause(),
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
                      onLongPressStart: (_) => ref
                          .read(audioPlayerManagerProvider)
                          .startFastForward(),
                      onLongPressEnd: (_) => ref
                          .read(audioPlayerManagerProvider)
                          .stopFastForward(),
                      onLongPressCancel: () => ref
                          .read(audioPlayerManagerProvider)
                          .stopFastForward(),
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: AppIcon(
                          AppIcons.skipNext,
                          size: compact ? 22 : 28,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
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
            right: compact ? AppTokens.s5 : 14,
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
