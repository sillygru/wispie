import 'dart:io';
import 'package:flutter/material.dart';

import '../../domain/services/cover_path.dart';
import '../../models/song.dart';
import '../tokens/player_tokens.dart';
import '../widgets/album_art_image.dart' show StaticAlbumArtImage;

/// A square identity thumbnail for a queue: the first song's cover, so a saved
/// queue is recognisable at a glance. With no cover it falls back to a
/// deterministic gradient seeded from [seed], so the same queue keeps the same
/// colours between sessions.
class QueueCoverMosaic extends StatelessWidget {
  final List<Song> songs;
  final double size;
  final Color accent;

  /// Stable string (a snapshot id) used to pick the placeholder gradient.
  final String seed;

  const QueueCoverMosaic({
    super.key,
    required this.songs,
    required this.accent,
    required this.seed,
    this.size = 60,
  });

  /// Resolves a cover URL to a local path and checks the file exists.
  static bool _hasCover(String? url) {
    final path = CoverPath.toLocalPath(url);
    if (path == null) return false;
    try {
      return File(path).statSync().type != FileSystemEntityType.notFound;
    } on FileSystemException {
      return false;
    } on ArgumentError {
      // A stored path the platform rejects outright (embedded NUL, bad
      // encoding) is a missing cover, not a crash.
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final first = songs.isEmpty ? null : songs.first;

    return ClipRRect(
      borderRadius: PlayerTokens.brSm,
      child: SizedBox(
        width: size,
        height: size,
        child: first != null && _hasCover(first.coverUrl)
            ? StaticAlbumArtImage(
                url: first.coverUrl ?? '',
                filename: first.filename,
                width: size,
                height: size,
                fit: BoxFit.cover,
              )
            : _buildPlaceholder(),
      ),
    );
  }

  Widget _buildPlaceholder() {
    final hue = (seed.hashCode.abs() % 360).toDouble();
    final base = HSLColor.fromAHSL(1, hue, 0.34, 0.42).toColor();

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color.lerp(base, accent, 0.25)!.withValues(alpha: 0.85),
            base.withValues(alpha: 0.35),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.queue_music_rounded,
          size: size * 0.4,
          color: Colors.white.withValues(alpha: PlayerTokens.aSecondary),
        ),
      ),
    );
  }
}
