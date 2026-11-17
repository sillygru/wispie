import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../models/song.dart';
import '../../providers/artist_album_art_provider.dart';
import '../components/pressable.dart';
import '../motion/motion.dart';
import '../tokens/app_tokens.dart';
import 'album_art_image.dart';
import 'collection_cover.dart';

/// One album the catalogue named, drawn ahead of the locally grouped ones.
class OnlineAlbumCard {
  const OnlineAlbumCard({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.coverUrl,
  });

  final String id;
  final String title;
  final String subtitle;
  final String? coverUrl;
}

/// Album picker for the grouped artist view: a horizontal carousel of cover
/// cards, starting with the catalogue's own albums, then one card per album
/// found in the library.
///
/// Cards filter the song list below the carousel inline — the selected card
/// takes the accent wash over its cover and an accent title, the same active
/// treatment as a list row. Color blocking only: no outlines, no gradients.
class AlbumCardSelector extends ConsumerStatefulWidget {
  /// Every song by the artist, backing the "All songs" card.
  final List<Song> allSongs;

  /// Album display names in the order they should appear.
  final List<String> albums;

  /// Songs per album display name.
  final Map<String, List<Song>> albumGroups;

  /// Currently selected album, or null for "All songs".
  final String? selected;

  /// Artist scoping the cached album artwork lookups.
  final String artistName;

  final ValueChanged<String?> onSelected;

  /// Catalogue albums, shown before the library's own groupings.
  final List<OnlineAlbumCard> onlineAlbums;

  /// Opens one of [onlineAlbums]; the caller owns that navigation.
  final ValueChanged<OnlineAlbumCard>? onOnlineAlbumTap;

  const AlbumCardSelector({
    super.key,
    required this.allSongs,
    required this.albums,
    required this.albumGroups,
    required this.selected,
    required this.artistName,
    required this.onSelected,
    this.onlineAlbums = const [],
    this.onOnlineAlbumTap,
  });

  static const double _cardWidth = 124;

  /// Fades cards out at the window edges instead of a hard clip. The left
  /// fade fits inside the list's own s4 padding, so at rest nothing on the
  /// left is faded; it only appears once cards scroll beneath it.
  static Shader _edgeFade(Rect rect) {
    final double left = 14 / rect.width;
    final double right = 28 / rect.width;
    return LinearGradient(
      colors: const <Color>[
        Color(0x00000000),
        Color(0xFF000000),
        Color(0xFF000000),
        Color(0x00000000),
      ],
      stops: <double>[0.0, left, 1.0 - right, 1.0],
    ).createShader(rect);
  }

  @override
  ConsumerState<AlbumCardSelector> createState() => _AlbumCardSelectorState();
}

class _AlbumCardSelectorState extends ConsumerState<AlbumCardSelector> {
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// A mouse wheel only carries a vertical delta, and a horizontal list ignores
  /// it — so without this the carousel cannot be moved by a wheel at all.
  ///
  /// The event is claimed through the pointer-signal resolver so the page's own
  /// vertical scrollable does not also consume it.
  void _onPointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent || !_scroll.hasClients) return;
    final Offset delta = event.scrollDelta;
    final double step = delta.dx.abs() > delta.dy.abs() ? delta.dx : delta.dy;
    if (step == 0) return;

    GestureBinding.instance.pointerSignalResolver.register(event, (_) {
      if (!_scroll.hasClients) return;
      final position = _scroll.position;
      _scroll.jumpTo(
        (position.pixels + step).clamp(
          position.minScrollExtent,
          position.maxScrollExtent,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final artState = ref.watch(artistAlbumArtProvider);
    final accent = AppTokens.accentOf(context, ref);
    final online = widget.onlineAlbums;

    return SizedBox(
      height: 182,
      child: Listener(
        onPointerSignal: _onPointerSignal,
        // Desktop drag is off by default in Flutter, which left the carousel
        // looking like a static strip of covers on a mouse-driven machine.
        child: ScrollConfiguration(
          behavior: ScrollConfiguration.of(context).copyWith(
            scrollbars: false,
            dragDevices: const <PointerDeviceKind>{
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.trackpad,
              PointerDeviceKind.stylus,
              PointerDeviceKind.invertedStylus,
            },
          ),
          child: ShaderMask(
            blendMode: BlendMode.dstIn,
            shaderCallback: AlbumCardSelector._edgeFade,
            child: ListView.separated(
              controller: _scroll,
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
              itemCount: online.length + 1 + widget.albums.length,
              separatorBuilder: (_, __) => const SizedBox(width: AppTokens.s3),
              itemBuilder: (context, index) {
                if (index < online.length) {
                  return _buildOnlineCard(online[index], accent);
                }
                if (index == online.length) {
                  return _AlbumCard(
                    title: context.l10n.albumCardAllSongs,
                    subtitle:
                        context.l10n.libraryTrackCount(widget.allSongs.length),
                    cover: CollectionCover(songs: widget.allSongs),
                    isSelected: widget.selected == null,
                    accent: accent,
                    onTap: () => widget.onSelected(null),
                  );
                }

                final album = widget.albums[index - online.length - 1];
                final albumSongs = widget.albumGroups[album] ?? const <Song>[];
                final cachedArt = artState.getAlbumArt(
                  album,
                  artistName: widget.artistName,
                );
                // Width-only decode: giving cacheWidth and cacheHeight together
                // resizes to exactly those numbers and squashes non-square art.
                final Widget cover = (cachedArt != null && cachedArt.isNotEmpty)
                    ? AlbumArtImage(
                        url: cachedArt,
                        width: AlbumCardSelector._cardWidth,
                        height: AlbumCardSelector._cardWidth,
                        fit: BoxFit.cover,
                        memCacheWidth: 310,
                        placeholder: CollectionCover(songs: albumSongs),
                      )
                    : CollectionCover(songs: albumSongs);
                return _AlbumCard(
                  title: album,
                  subtitle: context.l10n.libraryTrackCount(albumSongs.length),
                  cover: cover,
                  isSelected: widget.selected == album,
                  accent: accent,
                  onTap: () => widget.onSelected(album),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildOnlineCard(OnlineAlbumCard album, Color accent) {
    return _AlbumCard(
      title: album.title,
      subtitle: album.subtitle,
      cover: AlbumArtImage(
        url: album.coverUrl ?? '',
        width: AlbumCardSelector._cardWidth,
        height: AlbumCardSelector._cardWidth,
        fit: BoxFit.cover,
        memCacheWidth: 310,
      ),
      isSelected: false,
      accent: accent,
      onTap: () => widget.onOnlineAlbumTap?.call(album),
    );
  }
}

class _AlbumCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget cover;
  final bool isSelected;
  final Color accent;
  final VoidCallback onTap;

  const _AlbumCard({
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.isSelected,
    required this.accent,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: isSelected,
      button: true,
      label: subtitle.isEmpty ? title : '$title, $subtitle',
      child: Pressable(
        pressedScale: 0.96,
        onTap: () {
          MotionHaptics.selection();
          onTap();
        },
        child: SizedBox(
          width: AlbumCardSelector._cardWidth,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: AlbumCardSelector._cardWidth,
                height: AlbumCardSelector._cardWidth,
                child: ClipRRect(
                  borderRadius: AppTokens.brSm,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      cover,
                      AnimatedOpacity(
                        opacity: isSelected ? 1 : 0,
                        duration: MotionTokens.fast,
                        curve: MotionTokens.standardCurve,
                        child: ColoredBox(
                          color: accent.withValues(alpha: 0.28),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: AppTokens.s2),
              Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTokens.cardTitle(context).copyWith(
                  fontSize: 13,
                  color: isSelected ? accent : null,
                  fontWeight: isSelected ? FontWeight.w700 : null,
                ),
              ),
              Text(
                subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTokens.meta(context).copyWith(
                  color: isSelected ? accent : AppTokens.fgTertiary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
