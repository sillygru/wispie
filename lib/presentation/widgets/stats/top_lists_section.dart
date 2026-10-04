import 'package:flutter/material.dart';

import '../../../domain/models/listening_insights.dart';
import '../../components/app_surface.dart';
import '../../tokens/app_tokens.dart';
import '../album_art_image.dart';
import 'ranked_row.dart';

/// The most-played artists, albums and tracks in the window.
///
/// Three blocks rather than one tabbed panel: at five rows each the whole
/// thing is shorter than a screen, and making the user tap to see their top
/// artist would be a strange thing to insist on.
class TopListsSection extends StatelessWidget {
  final ListeningInsights insights;
  final Color accent;

  const TopListsSection({
    super.key,
    required this.insights,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _RankedBlock(
          label: 'TOP ARTISTS',
          entries: insights.topArtists,
          accent: accent,
        ),
        if (insights.topAlbums.isNotEmpty) ...[
          const SizedBox(height: AppTokens.s4),
          _RankedBlock(
            label: 'TOP ALBUMS',
            entries: insights.topAlbums,
            accent: accent,
          ),
        ],
        if (insights.topSongs.isNotEmpty) ...[
          const SizedBox(height: AppTokens.s4),
          _RankedBlock(
            label: 'TOP TRACKS',
            entries: insights.topSongs,
            accent: accent,
            leadingBuilder: (entry, _) => RankedArtwork(
              child: AlbumArtImage(
                url: entry.coverUrl ?? '',
                filename: entry.filename,
                width: RankedArtwork.size,
                height: RankedArtwork.size,
                fit: BoxFit.cover,
                memCacheWidth: (RankedArtwork.size * 4).toInt(),
                memCacheHeight: (RankedArtwork.size * 4).toInt(),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _RankedBlock extends StatelessWidget {
  final String label;
  final List<RankedName> entries;
  final Color accent;
  final Widget? Function(RankedName entry, int index)? leadingBuilder;

  const _RankedBlock({
    required this.label,
    required this.entries,
    required this.accent,
    this.leadingBuilder,
  });

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(
            left: AppTokens.s1,
            bottom: AppTokens.s2,
          ),
          child: Text(label, style: AppTokens.sectionLabel(context)),
        ),
        AppSurface(
          padding: const EdgeInsets.all(AppTokens.s2),
          child: RankedGroup(
            entries: entries,
            accent: accent,
            leadingBuilder: leadingBuilder,
          ),
        ),
      ],
    );
  }
}
