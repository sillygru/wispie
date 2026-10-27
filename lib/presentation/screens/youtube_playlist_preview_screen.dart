// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/models/youtube_playlist_link.dart';
import '../../domain/services/youtube_library.dart';
import '../../l10n/l10n.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../providers/youtube_account_provider.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../components/app_list_row.dart';
import '../components/app_screen_header.dart';
import '../components/ambient_scaffold.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../utils/youtube_error_message.dart';
import '../utils/youtube_account_error_message.dart';
import '../widgets/album_art_image.dart';

/// A YouTube playlist's tracks, before it is imported.
///
/// The point of the screen is to let the user see what they would be importing
/// and play any of it right away. Import stays available in the header, and
/// becomes a sync once the playlist is linked to a local one.
class YouTubePlaylistPreviewScreen extends ConsumerStatefulWidget {
  final YouTubeAccountPlaylist playlist;

  const YouTubePlaylistPreviewScreen({super.key, required this.playlist});

  @override
  ConsumerState<YouTubePlaylistPreviewScreen> createState() =>
      _YouTubePlaylistPreviewScreenState();
}

class _YouTubePlaylistPreviewScreenState
    extends ConsumerState<YouTubePlaylistPreviewScreen> {
  bool _busy = false;

  String get _title => widget.playlist.isLikedVideos
      ? context.l10n.youtubeAccountLikedVideos
      : widget.playlist.title;

  Future<void> _import(YouTubePlaylistLink? link) async {
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      final notifier = ref.read(youtubeAccountProvider.notifier);
      final summary = link == null
          ? await notifier.importPlaylist(
              widget.playlist,
              localName: _title,
            )
          : await notifier.syncPlaylist(link);
      if (!mounted) return;
      if (summary.created) {
        appSnack(
          context,
          l10n.youtubeAccountImportDone(summary.added, summary.playlistName),
          tone: AppTone.success,
        );
      } else if (summary.added == 0) {
        appSnack(
            context, l10n.youtubeAccountSyncUpToDate(summary.playlistName));
      } else {
        appSnack(
          context,
          l10n.youtubeAccountSyncDone(summary.added, summary.playlistName),
          tone: AppTone.success,
        );
      }
    } on Object catch (error) {
      if (!mounted) return;
      appSnack(
        context,
        YouTubeAccountErrorMessage.forError(error, l10n),
        tone: AppTone.danger,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _playAll(List<Song> songs) async {
    if (songs.isEmpty) return;
    try {
      final manager = ref.read(audioPlayerManagerProvider);
      for (final song in songs) {
        await ref.read(userDataProvider.notifier).cacheRemoteSong(song);
      }
      await manager.playSong(songs.first, contextQueue: songs);
    } on Object catch (error) {
      if (!mounted) return;
      appSnack(
        context,
        YouTubeErrorMessage.forError(error, context.l10n),
        tone: AppTone.danger,
      );
    }
  }

  Future<void> _play(Song song, List<Song> queue) async {
    try {
      await ref.read(userDataProvider.notifier).cacheRemoteSong(song);
      await ref
          .read(audioPlayerManagerProvider)
          .playSong(song, contextQueue: queue);
    } on Object catch (error) {
      if (!mounted) return;
      appSnack(
        context,
        YouTubeErrorMessage.forError(error, context.l10n),
        tone: AppTone.danger,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tracks = ref.watch(youtubePlaylistTracksProvider(widget.playlist.id));
    final links = ref.watch(youtubePlaylistLinksProvider).asData?.value ??
        const <String, YouTubePlaylistLink>{};
    final link = links.values
        .where((candidate) => candidate.remotePlaylistId == widget.playlist.id)
        .firstOrNull;

    return AmbientScaffold(
      appBar: AppTopBar(
        title: _title,
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: AppTokens.s3),
              child: Center(
                child: SizedBox(
                  width: AppTokens.iconSm,
                  height: AppTokens.iconSm,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            TextButton(
              onPressed: () => _import(link),
              child: Text(
                link == null
                    ? l10n.youtubeAccountImport
                    : l10n.youtubeAccountSync,
              ),
            ),
        ],
      ),
      body: tracks.when(
        loading: () => Center(
          child: Semantics(
            label: l10n.youtubeAccountLoading,
            child: const CircularProgressIndicator(),
          ),
        ),
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTokens.s5),
            child: Text(
              YouTubeAccountErrorMessage.forError(error, l10n),
              textAlign: TextAlign.center,
              style: AppTokens.rowSubtitle(context),
            ),
          ),
        ),
        data: (items) {
          if (items.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(AppTokens.s5),
                child: Text(
                  l10n.youtubePreviewEmpty,
                  textAlign: TextAlign.center,
                  style: AppTokens.rowSubtitle(context),
                ),
              ),
            );
          }
          final songs = [
            for (final item in items)
              Song.youtube(
                videoId: item.videoId,
                title: item.title,
                artist: item.artist,
                coverUrl: youtubeThumbnailUrl(item.videoId),
                duration: item.duration,
              ),
          ];
          return ListView.builder(
            padding: const EdgeInsets.only(bottom: AppTokens.scrollBottomInset),
            itemCount: songs.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppTokens.s4,
                    AppTokens.s2,
                    AppTokens.s4,
                    AppTokens.s3,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.youtubeAccountPlaylistTracks(songs.length),
                        style: AppTokens.rowSubtitle(context),
                      ),
                      const SizedBox(height: AppTokens.s2),
                      FilledButton.icon(
                        onPressed: () => _playAll(songs),
                        icon: const AppIcon(AppIcons.play),
                        label: Text(l10n.youtubePreviewPlayAll),
                      ),
                    ],
                  ),
                );
              }
              final song = songs[index - 1];
              return AppListRow(
                key: ValueKey('youtube-preview-${song.filename}'),
                tall: true,
                title: song.title,
                titleMaxLines: 1,
                subtitle:
                    song.artist.isEmpty ? l10n.metaUnknownArtist : song.artist,
                subtitleMaxLines: 1,
                onTap: () => _play(song, songs),
                leading: AlbumArtImage(
                  url: song.coverUrl ?? '',
                  width: 48,
                  height: 48,
                  borderRadius: AppTokens.rSm,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
