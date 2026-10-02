import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/artist_album_art_provider.dart';
import '../components/pressable.dart';
import '../tokens/app_tokens.dart';
import 'album_art_image.dart';
import 'collection_cover.dart';

/// Album picker for the grouped artist view: a horizontal carousel of cover
/// cards, always starting with "All songs", then one card per album.
///
/// Cards filter the song list below the carousel inline — the selected card
/// takes the accent wash over its cover and an accent title, the same active
/// treatment as a list row. Color blocking only: no outlines, no gradients.
class AlbumCardSelector extends ConsumerWidget {
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

  const AlbumCardSelector({
    super.key,
    required this.allSongs,
    required this.albums,
    required this.albumGroups,
    required this.selected,
    required this.artistName,
    required this.onSelected,
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
  Widget build(BuildContext context, WidgetRef ref) {
    final artState = ref.watch(artistAlbumArtProvider);
    final accent = AppTokens.accentOf(context, ref);

    return SizedBox(
      height: 182,
      child: ShaderMask(
        blendMode: BlendMode.dstIn,
        shaderCallback: _edgeFade,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: AppTokens.s4),
          itemCount: albums.length + 1,
          separatorBuilder: (_, __) => const SizedBox(width: AppTokens.s3),
          itemBuilder: (context, index) {
            if (index == 0) {
              return _AlbumCard(
                title: 'All songs',
                subtitle: _trackCount(allSongs.length),
                cover: CollectionCover(
                  songs: allSongs,
                ),
                isSelected: selected == null,
                accent: accent,
                onTap: () => onSelected(null),
              );
            }
            final album = albums[index - 1];
            final albumSongs = albumGroups[album] ?? const <Song>[];
            final cachedArt = artState.getAlbumArt(
              album,
              artistName: artistName,
            );
            // Width-only decode: giving cacheWidth and cacheHeight together
            // resizes to exactly those numbers and squashes non-square art.
            final Widget cover = (cachedArt != null && cachedArt.isNotEmpty)
                ? AlbumArtImage(
                    url: cachedArt,
                    width: _cardWidth,
                    height: _cardWidth,
                    fit: BoxFit.cover,
                    memCacheWidth: 310,
                    placeholder: CollectionCover(songs: albumSongs),
                  )
                : CollectionCover(songs: albumSongs);
            return _AlbumCard(
              title: album,
              subtitle: _trackCount(albumSongs.length),
              cover: cover,
              isSelected: selected == album,
              accent: accent,
              onTap: () => onSelected(album),
            );
          },
        ),
      ),
    );
  }

  static String _trackCount(int count) =>
      '$count track${count == 1 ? '' : 's'}';
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
      label: '$title, $subtitle',
      child: Pressable(
        pressedScale: 0.96,
        onTap: () {
          HapticFeedback.selectionClick();
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
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOut,
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
