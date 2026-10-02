import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../services/library_logic.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import 'album_art_image.dart';

/// Cover for a collection of songs — an album, an artist, a playlist or a
/// folder — used whenever no custom artwork has been set for that collection.
///
/// The most-listened song represents the group, so a heavily replayed album
/// leads with its signature track instead of an arbitrary scan-order file.
/// Falls back to a folder glyph when nothing in the collection has a cover.
class CollectionCover extends StatelessWidget {
  final List<Song> songs;
  final double size;

  /// Optional live counts, falling back to each song's `playCount` snapshot.
  final Map<String, int>? playCounts;

  const CollectionCover({
    super.key,
    required this.songs,
    this.size = 48,
    this.playCounts,
  });

  @override
  Widget build(BuildContext context) {
    final song = LibraryLogic.pickCoverSong(songs, playCounts: playCounts);

    if (song == null) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTokens.warning.withValues(alpha: 0.2),
          borderRadius: AppTokens.brSm,
        ),
        child: AppIcon(
          AppIcons.folder,
          size: size * 0.6,
          color: AppTokens.warning,
        ),
      );
    }

    // Callers inside an unbounded box (grid cells) pass an infinite size, and
    // memCacheWidth cannot be derived from one.
    final int? memCache = size.isFinite ? (size * 4).toInt() : null;

    return ClipRRect(
      borderRadius: AppTokens.brSm,
      child: AlbumArtImage(
        url: song.coverUrl ?? '',
        filename: song.filename,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: memCache,
        memCacheHeight: memCache,
      ),
    );
  }
}
