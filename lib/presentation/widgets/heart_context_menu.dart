import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../l10n/l10n.dart';
import '../../providers/providers.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import 'playlist_selector_dialog.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';

void showHeartContextMenu({
  required BuildContext context,
  required WidgetRef ref,
  required String songFilename,
  required String songTitle,
  Song? song,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    builder: (context) {
      return Consumer(
        builder: (context, ref, child) {
          final userData = ref.watch(userDataProvider);
          final isFavorite = userData.isFavorite(songFilename);
          final isSuggestLess = userData.isSuggestLess(songFilename);
          final playlists =
              userData.playlists.where((p) => !p.isRecommendation).toList();

          // Find the playlist this song was most recently added to
          Playlist? latestPlaylistWithSong;
          double latestAddedAt = -1;

          for (final pl in playlists) {
            for (final ps in pl.songs) {
              if (ps.songFilename == songFilename) {
                if (ps.addedAt > latestAddedAt) {
                  latestAddedAt = ps.addedAt;
                  latestPlaylistWithSong = pl;
                }
              }
            }
          }

          final l10n = context.l10n;

          return SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.of(context).size.height * 0.8,
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        songTitle,
                        style: Theme.of(context).textTheme.titleMedium,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const Divider(height: 1),
                    ListTile(
                      leading: AppIcon(
                        isFavorite ? AppIcons.favorite : AppIcons.favorite,
                        color: isFavorite ? Colors.red : null,
                      ),
                      title: Text(isFavorite
                          ? l10n.songMenuRemoveFavorite
                          : l10n.songMenuAddFavorite),
                      onTap: () {
                        ref
                            .read(userDataProvider.notifier)
                            .toggleFavorite(songFilename, remoteSong: song);
                        Navigator.pop(context);
                      },
                    ),
                    ListTile(
                      leading: const AppIcon(AppIcons.playlistAdd),
                      title: Text(l10n.songMenuAddToPlaylist),
                      onTap: () {
                        Navigator.pop(context);
                        _handleAddToPlaylist(context, ref, songFilename, song);
                      },
                    ),
                    ListTile(
                      leading: const AppIcon(AppIcons.playlistAdd),
                      title: Text(l10n.songMenuAddToNewPlaylist),
                      onTap: () {
                        Navigator.pop(context);
                        _showNewPlaylistDialog(
                            context, ref, songFilename, song);
                      },
                    ),
                    if (latestPlaylistWithSong != null)
                      ListTile(
                        leading: const AppIcon(AppIcons.playlistRemove,
                            color: Colors.red),
                        title: Text(
                            l10n.heartMenuRemoveFromPlaylist(
                                latestPlaylistWithSong.name),
                            style: const TextStyle(color: Colors.red)),
                        onTap: () {
                          Navigator.pop(context);
                          _handleRemoveFromPlaylist(context, ref, songFilename,
                              latestPlaylistWithSong!);
                        },
                      ),
                    ListTile(
                      leading: AppIcon(AppIcons.heartBroken,
                          color: isSuggestLess ? Colors.grey : null),
                      title: Text(isSuggestLess
                          ? l10n.songMenuSuggestMore
                          : l10n.songMenuSuggestLess),
                      onTap: () {
                        ref
                            .read(userDataProvider.notifier)
                            .toggleSuggestLess(songFilename);
                        Navigator.pop(context);
                      },
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      );
    },
  );
}

void _handleAddToPlaylist(
  BuildContext context,
  WidgetRef ref,
  String songFilename,
  Song? song,
) {
  if (song?.isRemote == true) {
    ref.read(userDataProvider.notifier).cacheRemoteSong(song!);
  }
  final playlists = ref
      .read(userDataProvider)
      .playlists
      .where((p) => !p.isRecommendation)
      .toList();
  final sorted = List.of(playlists)
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  if (sorted.isEmpty) {
    showPlaylistSelector(context, ref, songFilename);
  } else {
    final latest = sorted.first;
    // If already in latest, show picker immediately
    if (latest.songs.any((s) => s.songFilename == songFilename)) {
      showPlaylistSelector(context, ref, songFilename);
    } else {
      ref
          .read(userDataProvider.notifier)
          .addSongToPlaylist(latest.id, songFilename, remoteSong: song);
      appSnack(
        context,
        context.l10n.songAddedToPlaylist(latest.name),
        actionLabel: context.l10n.actionChange,
        // "Change" offers the full picker rather than moving it again: the song
        // may belong in several playlists.
        onAction: () => showPlaylistSelector(context, ref, songFilename),
      );
    }
  }
}

void _handleRemoveFromPlaylist(BuildContext context, WidgetRef ref,
    String songFilename, Playlist playlist) {
  ref
      .read(userDataProvider.notifier)
      .removeSongFromPlaylist(playlist.id, songFilename);
  appSnack(
    context,
    context.l10n.heartMenuRemovedFromPlaylist(playlist.name),
    actionLabel: context.l10n.actionChange,
    onAction: () => showPlaylistSelector(context, ref, songFilename),
  );
}

void _showNewPlaylistDialog(
  BuildContext context,
  WidgetRef ref,
  String songFilename,
  Song? song,
) {
  final l10n = context.l10n;
  final controller = TextEditingController();
  showDialog(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.playlistNewTitle),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: l10n.playlistNameHint),
        autofocus: true,
        onSubmitted: (value) {
          if (value.trim().isNotEmpty) {
            ref
                .read(userDataProvider.notifier)
                .createPlaylist(value.trim(), songFilename, song);
            Navigator.pop(dialogContext);
            appSnack(context, l10n.playlistCreated(value));
          }
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () {
            final name = controller.text.trim();
            if (name.isNotEmpty) {
              ref
                  .read(userDataProvider.notifier)
                  .createPlaylist(name, songFilename, song);
              Navigator.pop(dialogContext);
              appSnack(context, l10n.playlistCreated(name));
            }
          },
          child: Text(l10n.actionCreate),
        ),
      ],
    ),
  );
}
