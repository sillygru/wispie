import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../l10n/app_localizations.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../services/library_logic.dart';
import '../../services/youtube_service.dart';
import '../../services/online_metadata_service.dart';
import '../components/app_feedback.dart';
import '../utils/youtube_error_message.dart';
import '../routes/app_page_route.dart';
import '../routes/online_navigation.dart';
import '../screens/edit_metadata_screen.dart';
import '../screens/song_list_screen.dart';
import '../widgets/folder_picker.dart';
import '../widgets/playlist_selector_dialog.dart';

/// Shared song actions, used by two surfaces: the full options menu
/// (`song_options_menu.dart`) and the player's configurable quick action bar
/// (`quick_action_bar.dart`).
///
/// These are deliberately free functions with no opinion about the widget that
/// triggered them — callers dismiss their own popup/sheet first, then invoke.
/// [host] must be a context that outlives that dismissal (the screen behind the
/// menu, not the menu itself), since these show snackbars and push routes.

/// Set [showFeedback] to false where the control itself already shows the new
/// state — a heart that fills in says everything a snackbar would.
void songActionToggleFavorite(
  BuildContext host,
  WidgetRef ref,
  String filename,
  String title, {
  bool showFeedback = true,
  Song? song,
}) {
  final l10n = AppLocalizations.of(host);
  final wasFavorite = ref.read(userDataProvider).isFavorite(filename);
  ref
      .read(userDataProvider.notifier)
      .toggleFavorite(filename, remoteSong: song);
  if (!showFeedback || !host.mounted) return;
  appSnack(
    host,
    wasFavorite
        ? l10n.songFavoriteRemoved(title)
        : l10n.songFavoriteAdded(title),
    duration: const Duration(seconds: 2),
  );
}

/// Saves a streamed track to the library, or drops it out again. One path for
/// every surface, so the feed, a YouTube playlist and the player's menu cannot
/// disagree about what "in the library" means.
Future<void> songActionToggleRemoteLibrary(
  BuildContext host,
  WidgetRef ref,
  Song song,
) async {
  final l10n = AppLocalizations.of(host);
  final notifier = ref.read(userDataProvider.notifier);
  final wasInLibrary =
      ref.read(userDataProvider).isInRemoteLibrary(song.filename);
  if (wasInLibrary) {
    await notifier.removeSongFromLibrary(song.filename);
  } else if (!await notifier.addSongToLibrary(song)) {
    if (!host.mounted) return;
    appSnack(
      host,
      l10n.onlineLibraryAddFailed(song.title),
      tone: AppTone.danger,
    );
    return;
  }
  if (!host.mounted) return;
  appSnack(
    host,
    wasInLibrary
        ? l10n.onlineLibraryRemoved(song.title)
        : l10n.onlineLibraryAdded(song.title),
    tone: wasInLibrary ? AppTone.neutral : AppTone.success,
  );
}

void songActionToggleSuggestLess(
  BuildContext host,
  WidgetRef ref,
  String filename,
  String title,
) {
  final l10n = AppLocalizations.of(host);
  final wasSuggestLess = ref.read(userDataProvider).isSuggestLess(filename);
  ref.read(userDataProvider.notifier).toggleSuggestLess(filename);
  if (!host.mounted) return;
  appSnack(
    host,
    wasSuggestLess
        ? l10n.songWillSuggestMore(title)
        : l10n.songWillSuggestLess(title),
    duration: const Duration(seconds: 2),
  );
}

Future<void> songActionPlayNext(
  BuildContext host,
  WidgetRef ref,
  Song song,
) async {
  final l10n = AppLocalizations.of(host);
  try {
    // A streamed track has to be in the user-data db before it can be queued.
    await ref.read(userDataProvider.notifier).cacheRemoteSong(song);
    await ref.read(audioPlayerManagerProvider).playNext(song);
  } on YouTubeApiException catch (error) {
    if (!host.mounted) return;
    _showOnlinePlaybackError(host, error);
    return;
  }
  if (!host.mounted) return;
  appSnack(host, l10n.songAddedToNextUp(song.title),
      duration: const Duration(seconds: 2));
}

void songActionShare(BuildContext host, Song song) {
  if (!song.isLocal) return;
  SharePlus.instance.share(
    ShareParams(
      files: [XFile(song.url)],
      text: AppLocalizations.of(host).songShareText(song.title, song.artist),
    ),
  );
}

/// Adds to the most recently updated playlist directly, offering a "Change"
/// escape hatch — falling back to the full selector when that would be
/// ambiguous (no playlists, or the song is already in the latest one).
void _showOnlinePlaybackError(BuildContext host, Object error) {
  if (!host.mounted) return;
  appSnack(
    host,
    YouTubeErrorMessage.forError(error, AppLocalizations.of(host)),
    tone: AppTone.danger,
  );
}

void songActionAddToPlaylist(BuildContext host, WidgetRef ref, String filename,
    {Song? song}) {
  if (song?.isRemote == true) {
    ref.read(userDataProvider.notifier).cacheRemoteSong(song!);
  }
  final playlists = ref
      .read(userDataProvider)
      .playlists
      .where((p) => !p.isRecommendation)
      .toList()
    ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));

  if (playlists.isEmpty) {
    showPlaylistSelector(host, ref, filename);
    return;
  }

  final latest = playlists.first;
  if (latest.songs.any((s) => s.songFilename == filename)) {
    showPlaylistSelector(host, ref, filename);
    return;
  }

  ref
      .read(userDataProvider.notifier)
      .addSongToPlaylist(latest.id, filename, remoteSong: song);
  if (!host.mounted) return;
  final l10n = AppLocalizations.of(host);
  appSnack(
    host,
    l10n.songAddedToPlaylist(latest.name),
    actionLabel: l10n.actionChange,
    onAction: () => showPlaylistSelector(host, ref, filename),
  );
}

void songActionAddToNewPlaylist(
    BuildContext host, WidgetRef ref, String filename,
    {Song? song}) {
  if (song?.isRemote == true) {
    ref.read(userDataProvider.notifier).cacheRemoteSong(song!);
  }
  final l10n = AppLocalizations.of(host);
  final controller = TextEditingController();

  void create(BuildContext dialogContext, String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return;
    ref.read(userDataProvider.notifier).createPlaylist(name, filename, song);
    Navigator.pop(dialogContext);
    if (!host.mounted) return;
    appSnack(host, l10n.playlistCreated(name));
  }

  showDialog<void>(
    context: host,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.playlistNewTitle),
      content: TextField(
        controller: controller,
        decoration: InputDecoration(hintText: l10n.playlistNameHint),
        autofocus: true,
        onSubmitted: (value) => create(dialogContext, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(l10n.actionCancel),
        ),
        TextButton(
          onPressed: () => create(dialogContext, controller.text),
          child: Text(l10n.actionCreate),
        ),
      ],
    ),
  );
}

Future<void> songActionManagePlaylists(
  BuildContext host,
  WidgetRef ref,
  String filename, {
  Song? song,
}) async {
  // A streamed track needs its metadata on file before a playlist can show it.
  if (song?.isRemote == true) {
    await ref.read(userDataProvider.notifier).cacheRemoteSong(song!);
  }
  if (!host.mounted) return;
  showPlaylistSelector(host, ref, filename);
}

void songActionRemoveFromPlaylist(
  BuildContext host,
  WidgetRef ref,
  String playlistId,
  String filename,
  String title,
) {
  final l10n = AppLocalizations.of(host);
  ref
      .read(userDataProvider.notifier)
      .removeSongFromPlaylist(playlistId, filename);
  if (!host.mounted) return;
  appSnack(
    host,
    l10n.songRemovedFromPlaylist(title),
    actionLabel: l10n.actionChange,
    onAction: () => showPlaylistSelector(host, ref, filename),
  );
}

void songActionEditMetadata(BuildContext host, Song song) {
  if (!song.isLocal) return;
  Navigator.push(
    host,
    MaterialPageRoute(builder: (_) => EditMetadataScreen(song: song)),
  );
}

Future<void> songActionMoveToFolder(
  BuildContext host,
  WidgetRef ref,
  Song song,
) async {
  if (!song.isLocal) return;
  final l10n = AppLocalizations.of(host);
  final rootPath = await ref.read(storageServiceProvider).getMusicFolderPath();
  if (rootPath == null || !host.mounted) return;

  final targetPath = await showFolderPicker(host, rootPath);
  if (targetPath == null) return;

  try {
    await ref.read(songsProvider.notifier).moveSong(song, targetPath);
    if (!host.mounted) return;
    appSnack(host, l10n.songMovedTo(song.title, targetPath));
  } catch (e) {
    if (!host.mounted) return;
    appSnack(host, l10n.songMoveError('$e'), tone: AppTone.danger);
  }
}

Future<void> songActionHide(BuildContext host, WidgetRef ref, Song song) async {
  if (!song.isLocal) return;
  final l10n = AppLocalizations.of(host);
  await ref.read(songsProvider.notifier).hideSong(song);
  if (!host.mounted) return;
  appSnack(host, l10n.songRemovedFromLibrary(song.title));
}

Future<void> songActionDelete(
  BuildContext host,
  WidgetRef ref,
  Song song,
) async {
  if (!song.isLocal) return;
  if (!host.mounted) return;
  final l10n = AppLocalizations.of(host);

  final confirm = await showDialog<bool>(
        context: host,
        builder: (dialogContext) => AlertDialog(
          title: Text(l10n.songDeleteTitle),
          content: Text(l10n.songDeleteConfirm(song.title)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: Text(l10n.actionCancel),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: Text(l10n.actionDeletePermanently),
            ),
          ],
        ),
      ) ??
      false;

  if (!confirm) return;

  try {
    await ref.read(songsProvider.notifier).deleteSongFile(song);
    if (!host.mounted) return;
    appSnack(host, l10n.songDeleted(song.title));
  } catch (e) {
    if (!host.mounted) return;
    appSnack(host, l10n.songDeleteError('$e'), tone: AppTone.danger);
  }
}

/// Opens the album this song belongs to. A streamed track has no library rows,
/// so its album opens on YouTube instead.
void songActionGoToAlbum(BuildContext host, WidgetRef ref, Song song) {
  if (song.isRemote && song.album.trim().isNotEmpty) {
    unawaited(_openRemoteAlbum(host, song.album, song.artist));
    return;
  }

  final songs = ref.read(songsProvider).value;
  if (songs == null) return;

  final albumSongs = songs.where((s) => s.album == song.album).toList();
  if (albumSongs.isEmpty) return;

  host.pushApp(
    SongListScreen(
      title: song.album,
      songs: albumSongs,
      isAlbum: true,
      albumName: song.album,
      artistName: song.artist,
    ),
  );
}

Future<void> _openRemoteAlbum(
  BuildContext host,
  String albumName,
  String artistName,
) async {
  if (await openOnlineAlbumByName(host, albumName, artistName: artistName)) {
    return;
  }
  if (!host.mounted) return;
  appSnack(host, AppLocalizations.of(host).onlineAlbumNotFound);
}

/// Opens the specified artist screen. A streamed track's artist is a YouTube
/// channel, so those try the channel page before the library.
void songActionGoToArtistByName(
  BuildContext host,
  WidgetRef ref,
  String artistName, {
  bool remote = false,
}) {
  final target = artistName.trim();
  if (target.isEmpty) return;
  if (remote) {
    unawaited(_openArtistRemoteThenLocal(host, ref, target));
    return;
  }
  _openLocalArtist(host, ref, target);
}

Future<void> _openArtistRemoteThenLocal(
  BuildContext host,
  WidgetRef ref,
  String artistName,
) async {
  if (await openOnlineArtistByName(host, artistName)) return;
  if (!host.mounted) return;
  if (_openLocalArtist(host, ref, artistName)) return;
  appSnack(host, AppLocalizations.of(host).onlineArtistNotFound);
}

bool _openLocalArtist(BuildContext host, WidgetRef ref, String artistName) {
  final songs = ref.read(songsProvider).value;
  if (songs == null) return false;

  final cleanTarget = artistName.trim().toLowerCase();
  if (cleanTarget.isEmpty) return false;

  final artistSongs = songs.where((s) {
    final parsed = LibraryLogic.splitArtistNames(s.artist);
    if (parsed.isEmpty) {
      return s.artist.trim().toLowerCase() == cleanTarget;
    }
    return parsed.any((a) => a.trim().toLowerCase() == cleanTarget);
  }).toList();

  if (artistSongs.isEmpty) {
    final fallbackSongs = songs
        .where((s) => s.artist.toLowerCase().contains(cleanTarget))
        .toList();
    if (fallbackSongs.isEmpty) return false;
    host.pushApp(
      SongListScreen(
        title: artistName,
        songs: fallbackSongs,
        isArtist: true,
        artistName: artistName,
      ),
    );
    return true;
  }

  host.pushApp(
    SongListScreen(
      title: artistName,
      songs: artistSongs,
      isArtist: true,
      artistName: artistName,
    ),
  );
  return true;
}

/// Opens the artist this song belongs to. No-op when the library has not
/// finished loading, since there is nothing to filter yet.
void songActionGoToArtist(BuildContext host, WidgetRef ref, Song song) {
  final artists = LibraryLogic.splitArtistNames(song.artist);
  final targetArtist = artists.isNotEmpty ? artists.first : song.artist;
  songActionGoToArtistByName(host, ref, targetArtist, remote: song.isRemote);
}

Future<void> songActionFetchMissingCover(
  BuildContext host,
  WidgetRef ref,
  Song song,
) async {
  final l10n = AppLocalizations.of(host);
  appSnack(host, l10n.coverSearching, duration: const Duration(seconds: 2));

  try {
    final onlineService = OnlineMetadataService.instance;

    String? coverUrl;
    String? source;
    final cleanArtist = OnlineMetadataService.cleanTag(song.artist);
    final cleanAlbum = OnlineMetadataService.cleanTag(song.album);
    if (cleanArtist != null && cleanAlbum != null) {
      final candidates = await onlineService.searchAlbumImageCandidates(
        cleanAlbum,
        artistName: cleanArtist,
      );
      if (candidates.isNotEmpty) {
        coverUrl = candidates.first['url'];
        source = candidates.first['source'];
      }
    }

    if (coverUrl == null || coverUrl.isEmpty) {
      final results = await onlineService.searchParallelForSong(song);
      for (final res in results) {
        if (res.coverUrl != null && res.coverUrl!.isNotEmpty) {
          coverUrl = res.coverUrl;
          source = res.source;
          break;
        }
      }
    }

    if (coverUrl == null || coverUrl.isEmpty) {
      if (!host.mounted) return;
      appSnack(host, l10n.coverNoneFound, tone: AppTone.warning);
      return;
    }

    final localPath = await onlineService.downloadAndCacheCover(
      coverUrl,
      song.filename,
    );

    if (localPath != null && host.mounted) {
      await ref.read(songsProvider.notifier).updateSongCover(song, localPath);
      if (!host.mounted) return;
      appSnack(
        host,
        l10n.coverUpdated(song.title, '$source'),
        tone: AppTone.success,
      );
    } else if (host.mounted) {
      appSnack(host, l10n.coverDownloadFailed, tone: AppTone.danger);
    }
  } catch (e) {
    if (!host.mounted) return;
    appSnack(host, l10n.coverFetchError('$e'), tone: AppTone.danger);
  }
}
