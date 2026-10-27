import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import 'album_art_image.dart';

/// Cover for a collection of songs — an album, an artist, a playlist or a
/// folder — used whenever no custom artwork has been set for that collection.
///
/// Artwork comes from the collection's own songs, most-played first, and one to
/// four covers are composed into a mosaic. This works for streamed tracks too:
/// their covers are URLs, not files, so a YouTube playlist still gets a cover
/// instead of a placeholder glyph.
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

  /// Up to four distinct covers, ordered by how much the collection is played.
  List<String> _covers() {
    final ranked = [...songs];
    ranked.sort((a, b) {
      final aPlays = playCounts?[a.filename] ?? a.playCount;
      final bPlays = playCounts?[b.filename] ?? b.playCount;
      return bPlays.compareTo(aPlays);
    });
    final seen = <String>{};
    final covers = <String>[];
    for (final song in ranked) {
      final cover = song.coverUrl?.trim() ?? '';
      if (cover.isEmpty) continue;
      if (!seen.add(cover)) continue;
      covers.add(cover);
      if (covers.length == 4) break;
    }
    return covers;
  }

  @override
  Widget build(BuildContext context) {
    final covers = _covers();

    if (covers.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: AppTokens.surface(2),
          borderRadius: AppTokens.brSm,
        ),
        child: AppIcon(
          AppIcons.musicNote,
          size: size * 0.5,
          color: AppTokens.fgTertiary,
        ),
      );
    }

    // Callers inside an unbounded box (grid cells) pass an infinite size, and
    // memCacheWidth cannot be derived from one.
    final int? memCache = size.isFinite ? (size * 2).toInt() : null;

    return ClipRRect(
      borderRadius: AppTokens.brSm,
      child: SizedBox(
        width: size.isFinite ? size : null,
        height: size.isFinite ? size : null,
        child: covers.length == 1
            ? _tile(covers[0], memCache)
            : _mosaic(covers, memCache),
      ),
    );
  }

  Widget _tile(String url, int? memCache) {
    return AlbumArtImage(
      url: url,
      width: size.isFinite ? size : null,
      height: size.isFinite ? size : null,
      fit: BoxFit.cover,
      memCacheWidth: memCache,
      memCacheHeight: memCache,
    );
  }

  Widget _mosaic(List<String> covers, int? memCache) {
    Widget cell(String url) => Expanded(
          child: AlbumArtImage(
            url: url,
            fit: BoxFit.cover,
            memCacheWidth: memCache,
          ),
        );

    if (covers.length == 2) {
      return Column(
        children: [cell(covers[0]), cell(covers[1])],
      );
    }

    final quad = [...covers];
    while (quad.length < 4) {
      quad.add(covers[quad.length % covers.length]);
    }
    return Column(
      children: [
        Expanded(
          child: Row(
            children: [cell(quad[0]), cell(quad[1])],
          ),
        ),
        Expanded(
          child: Row(
            children: [cell(quad[2]), cell(quad[3])],
          ),
        ),
      ],
    );
  }
}
