import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../services/library_logic.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import 'album_art_image.dart';

/// The fallback cover for an album, artist, playlist or folder.
class CollectionCover extends StatefulWidget {
  final List<Song> songs;
  final double size;

  /// Optional live counts, falling back to each song's `playCount` snapshot.
  final Map<String, int>? playCounts;

  const CollectionCover({
    super.key,
    required this.songs,
    this.size = AppTokens.artSize,
    this.playCounts,
  });

  @override
  State<CollectionCover> createState() => _CollectionCoverState();
}

class _CollectionCoverState extends State<CollectionCover> {
  String? _cover;

  @override
  void initState() {
    super.initState();
    _selectCover();
  }

  @override
  void didUpdateWidget(covariant CollectionCover oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.songs, widget.songs) ||
        !identical(oldWidget.playCounts, widget.playCounts)) {
      _selectCover();
    }
  }

  void _selectCover() {
    _cover = LibraryLogic.pickCoverSong(
      widget.songs,
      playCounts: widget.playCounts,
    )?.coverUrl?.trim();
  }

  @override
  Widget build(BuildContext context) {
    final cover = _cover;

    if (cover == null || cover.isEmpty) {
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

    final size = widget.size.isFinite ? widget.size : null;
    final memCache = size == null ? null : (size * 2).toInt();

    return ClipRRect(
      borderRadius: AppTokens.brSm,
      child: AlbumArtImage(
        url: cover,
        width: size,
        height: size,
        fit: BoxFit.cover,
        memCacheWidth: memCache,
        memCacheHeight: memCache,
      ),
    );
  }
}
