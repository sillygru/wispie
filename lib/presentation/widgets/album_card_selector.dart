import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/song.dart';
import '../../providers/artist_album_art_provider.dart';
import '../tokens/app_tokens.dart';
import 'folder_grid_image.dart';

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final artState = ref.watch(artistAlbumArtProvider);
    final accent = AppTokens.accentOf(context, ref);

    return SizedBox(
      height: 182,
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
              cover: FolderGridImage(
                songs: allSongs,
                isGridItem: true,
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
          final Widget cover = (cachedArt != null && cachedArt.isNotEmpty)
              ? Image.file(
                  File(cachedArt),
                  fit: BoxFit.cover,
                  width: _cardWidth,
                  height: _cardWidth,
                  cacheWidth: 310,
                  cacheHeight: 310,
                  errorBuilder: (_, __, ___) => FolderGridImage(
                    songs: albumSongs,
                    isGridItem: true,
                  ),
                )
              : FolderGridImage(songs: albumSongs, isGridItem: true);
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
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
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
                      if (isSelected)
                        DecoratedBox(
                          decoration: BoxDecoration(
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
