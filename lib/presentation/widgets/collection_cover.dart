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
class CollectionCover extends StatefulWidget {
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
  State<CollectionCover> createState() => _CollectionCoverState();
}

class _CollectionCoverState extends State<CollectionCover> {
  late List<String> _covers;

  @override
  void initState() {
    super.initState();
    _covers = _selectCovers();
  }

  @override
  void didUpdateWidget(covariant CollectionCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.songs, widget.songs) ||
        !identical(oldWidget.playCounts, widget.playCounts)) {
      _covers = _selectCovers();
    }
  }

  /// Up to four distinct covers, ordered by how much the collection is played.
  List<String> _selectCovers() {
    final bestPlaysByCover = <String, int>{};
    var streamed = widget.songs.isNotEmpty;
    for (final song in widget.songs) {
      if (!song.isRemote) streamed = false;
      final cover = song.coverUrl?.trim() ?? '';
      if (cover.isEmpty) continue;
      final plays = widget.playCounts?[song.filename] ?? song.playCount;
      final current = bestPlaysByCover[cover];
      if (current == null || plays > current) {
        bestPlaysByCover[cover] = plays;
      }
    }

    final rankedCovers = <({String cover, int plays})>[];
    for (final entry in bestPlaysByCover.entries) {
      final candidate = (cover: entry.key, plays: entry.value);
      var index = 0;
      while (index < rankedCovers.length &&
          rankedCovers[index].plays >= candidate.plays) {
        index++;
      }
      if (index < 4) {
        rankedCovers.insert(index, candidate);
        if (rankedCovers.length > 4) rankedCovers.removeLast();
      }
    }

    // A streamed collection shows the first song's art: a mosaic of unrelated
    // catalogue stills reads as a collage of different albums.
    return rankedCovers
        .take(streamed ? 1 : 4)
        .map((candidate) => candidate.cover)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final covers = _covers;

    if (covers.isEmpty) {
      return Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(
          color: AppTokens.surface(2),
          borderRadius: AppTokens.brSm,
        ),
        child: AppIcon(
          AppIcons.musicNote,
          size: widget.size * 0.5,
          color: AppTokens.fgTertiary,
        ),
      );
    }

    // Callers inside an unbounded box (grid cells) pass an infinite size, and
    // memCacheWidth cannot be derived from one.
    final int? memCache =
        widget.size.isFinite ? (widget.size * 2).toInt() : null;

    return ClipRRect(
      borderRadius: AppTokens.brSm,
      child: SizedBox(
        width: widget.size.isFinite ? widget.size : null,
        height: widget.size.isFinite ? widget.size : null,
        child: covers.length == 1
            ? _tile(covers[0], memCache)
            : _mosaic(covers, memCache),
      ),
    );
  }

  Widget _tile(String url, int? memCache) {
    return AlbumArtImage(
      url: url,
      width: widget.size.isFinite ? widget.size : null,
      height: widget.size.isFinite ? widget.size : null,
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
