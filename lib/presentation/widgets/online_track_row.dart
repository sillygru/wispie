// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/l10n.dart';
import '../../providers/providers.dart';
import '../../services/online_music_service.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_list_row.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/youtube_error_message.dart';
import 'album_art_image.dart';
import 'duration_display.dart';
import 'song_options_menu.dart';

/// One YouTube track, the way every online surface draws it.
///
/// The search list, an album, a playlist and an artist page all show the same
/// row: artwork, title, `Artist · 36M plays · 4:11`, favorite and options.
class OnlineTrackRow extends ConsumerWidget {
  final OnlineTrack track;

  /// What playing this row queues: the list it was tapped in.
  final List<OnlineTrack> queue;

  const OnlineTrackRow({
    super.key,
    required this.track,
    required this.queue,
  });

  static String subtitleOf(BuildContext context, OnlineTrack track) => [
        track.artist.isEmpty ? context.l10n.metaUnknownArtist : track.artist,
        if (track.viewCountText != null) track.viewCountText!,
        if (track.duration != null) DurationFormatter.format(track.duration),
      ].join(' · ');

  static Future<void> play(
    BuildContext context,
    WidgetRef ref,
    OnlineTrack track,
    List<OnlineTrack> queue,
  ) async {
    final song = track.toSong();
    try {
      await ref.read(userDataProvider.notifier).cacheRemoteSong(song);
      await ref.read(audioPlayerManagerProvider).playSong(
            song,
            contextQueue: queue.map((item) => item.toSong()).toList(),
          );
    } on Object catch (error) {
      if (!context.mounted) return;
      appSnack(
        context,
        YouTubeErrorMessage.forError(error, context.l10n),
        tone: AppTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = track.toSong();
    final isFavorite = ref.watch(
      userDataProvider.select((state) => state.isFavorite(song.filename)),
    );
    return AppListRow(
      tall: true,
      title: track.title,
      titleMaxLines: 1,
      subtitle: subtitleOf(context, track),
      subtitleMaxLines: 1,
      onTap: () => play(context, ref, track, queue),
      leading: AlbumArtImage(
        url: track.coverUrl ?? '',
        width: 52,
        height: 52,
        borderRadius: AppTokens.rSm,
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: isFavorite
                ? context.l10n.songMenuRemoveFavorite
                : context.l10n.songMenuAddFavorite,
            onPressed: () => ref
                .read(userDataProvider.notifier)
                .toggleFavorite(song.filename, remoteSong: song),
            icon: AppIcon(
              AppIcons.favorite,
              size: AppTokens.iconMd,
              color: isFavorite ? AppTokens.danger : null,
            ),
          ),
          IconButton(
            tooltip: context.l10n.songMenuTitle,
            onPressed: () => showSongOptionsMenu(
              context,
              ref,
              song.filename,
              song.title,
              song: song,
            ),
            icon: const AppIcon(AppIcons.moreVert, size: AppTokens.iconMd),
          ),
        ],
      ),
    );
  }
}
