import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../domain/models/online_search_result.dart';
import '../../l10n/app_localizations.dart';
import '../../models/song.dart';
import '../../providers/providers.dart';
import '../../services/library_logic.dart';
import '../../services/online_metadata_service.dart';
import '../components/app_feedback.dart';
import '../components/app_icon.dart';
import '../tokens/app_icons.dart';
import '../tokens/app_tokens.dart';
import '../routes/app_page_route.dart';
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
}) {
  final l10n = AppLocalizations.of(host);
  final wasFavorite = ref.read(userDataProvider).isFavorite(filename);
  ref.read(userDataProvider.notifier).toggleFavorite(filename);
  if (!showFeedback || !host.mounted) return;
  ScaffoldMessenger.of(host).showSnackBar(
    SnackBar(
      content: Text(
        wasFavorite
            ? l10n.songFavoriteRemoved(title)
            : l10n.songFavoriteAdded(title),
      ),
      duration: const Duration(seconds: 1),
    ),
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
  ScaffoldMessenger.of(host).showSnackBar(
    SnackBar(
      content: Text(
        wasSuggestLess
            ? l10n.songWillSuggestMore(title)
            : l10n.songWillSuggestLess(title),
      ),
      duration: const Duration(seconds: 1),
    ),
  );
}

void songActionPlayNext(BuildContext host, WidgetRef ref, Song song) {
  final l10n = AppLocalizations.of(host);
  ref.read(audioPlayerManagerProvider).playNext(song);
  if (!host.mounted) return;
  ScaffoldMessenger.of(host).showSnackBar(
    SnackBar(
      content: Text(l10n.songAddedToNextUp(song.title)),
      duration: const Duration(seconds: 1),
    ),
  );
}

void songActionShare(BuildContext host, Song song) {
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
void songActionAddToPlaylist(
  BuildContext host,
  WidgetRef ref,
  String filename,
) {
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

  ref.read(userDataProvider.notifier).addSongToPlaylist(latest.id, filename);
  if (!host.mounted) return;
  final l10n = AppLocalizations.of(host);
  ScaffoldMessenger.of(host).showSnackBar(
    SnackBar(
      content: Text(l10n.songAddedToPlaylist(latest.name)),
      action: SnackBarAction(
        label: l10n.actionChange,
        onPressed: () => showPlaylistSelector(host, ref, filename),
      ),
    ),
  );
}

void songActionAddToNewPlaylist(
  BuildContext host,
  WidgetRef ref,
  String filename,
) {
  final l10n = AppLocalizations.of(host);
  final controller = TextEditingController();

  void create(BuildContext dialogContext, String rawName) {
    final name = rawName.trim();
    if (name.isEmpty) return;
    ref.read(userDataProvider.notifier).createPlaylist(name, filename);
    Navigator.pop(dialogContext);
    if (!host.mounted) return;
    ScaffoldMessenger.of(
      host,
    ).showSnackBar(SnackBar(content: Text(l10n.playlistCreated(name))));
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

void songActionManagePlaylists(
  BuildContext host,
  WidgetRef ref,
  String filename,
) {
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
  ScaffoldMessenger.of(host).showSnackBar(
    SnackBar(
      content: Text(l10n.songRemovedFromPlaylist(title)),
      action: SnackBarAction(
        label: l10n.actionChange,
        onPressed: () => showPlaylistSelector(host, ref, filename),
      ),
    ),
  );
}

void songActionEditMetadata(BuildContext host, Song song) {
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
  final l10n = AppLocalizations.of(host);
  final rootPath = await ref.read(storageServiceProvider).getMusicFolderPath();
  if (rootPath == null || !host.mounted) return;

  final targetPath = await showFolderPicker(host, rootPath);
  if (targetPath == null) return;

  try {
    await ref.read(songsProvider.notifier).moveSong(song, targetPath);
    if (!host.mounted) return;
    ScaffoldMessenger.of(host).showSnackBar(
      SnackBar(content: Text(l10n.songMovedTo(song.title, targetPath))),
    );
  } catch (e) {
    if (!host.mounted) return;
    ScaffoldMessenger.of(
      host,
    ).showSnackBar(SnackBar(content: Text(l10n.songMoveError('$e'))));
  }
}

Future<void> songActionHide(BuildContext host, WidgetRef ref, Song song) async {
  final l10n = AppLocalizations.of(host);
  await ref.read(songsProvider.notifier).hideSong(song);
  if (!host.mounted) return;
  ScaffoldMessenger.of(
    host,
  ).showSnackBar(
      SnackBar(content: Text(l10n.songRemovedFromLibrary(song.title))));
}

Future<void> songActionDelete(
  BuildContext host,
  WidgetRef ref,
  Song song,
) async {
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
    ScaffoldMessenger.of(
      host,
    ).showSnackBar(SnackBar(content: Text(l10n.songDeleted(song.title))));
  } catch (e) {
    if (!host.mounted) return;
    ScaffoldMessenger.of(
      host,
    ).showSnackBar(SnackBar(content: Text(l10n.songDeleteError('$e'))));
  }
}

/// Opens the album this song belongs to. No-op when the library has not
/// finished loading, since there is nothing to filter yet.
void songActionGoToAlbum(BuildContext host, WidgetRef ref, Song song) {
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

/// Opens the specified artist screen. Filters all library songs where this artist is featured.
void songActionGoToArtistByName(
  BuildContext host,
  WidgetRef ref,
  String artistName,
) {
  final songs = ref.read(songsProvider).value;
  if (songs == null) return;

  final cleanTarget = artistName.trim().toLowerCase();
  if (cleanTarget.isEmpty) return;

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
    if (fallbackSongs.isEmpty) return;
    host.pushApp(
      SongListScreen(
        title: artistName,
        songs: fallbackSongs,
        isArtist: true,
        artistName: artistName,
      ),
    );
    return;
  }

  host.pushApp(
    SongListScreen(
      title: artistName,
      songs: artistSongs,
      isArtist: true,
      artistName: artistName,
    ),
  );
}

/// Opens the artist this song belongs to. No-op when the library has not
/// finished loading, since there is nothing to filter yet.
void songActionGoToArtist(BuildContext host, WidgetRef ref, Song song) {
  final artists = LibraryLogic.splitArtistNames(song.artist);
  final targetArtist = artists.isNotEmpty ? artists.first : song.artist;
  songActionGoToArtistByName(host, ref, targetArtist);
}

Future<void> songActionFetchMissingCover(
  BuildContext host,
  WidgetRef ref,
  Song song,
) async {
  final l10n = AppLocalizations.of(host);
  ScaffoldMessenger.of(host).showSnackBar(
    SnackBar(
      content: Text(l10n.coverSearching),
      duration: Duration(seconds: 2),
    ),
  );

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
      ScaffoldMessenger.of(host).showSnackBar(
        SnackBar(content: Text(l10n.coverNoneFound)),
      );
      return;
    }

    final localPath = await onlineService.downloadAndCacheCover(
      coverUrl,
      song.filename,
    );

    if (localPath != null && host.mounted) {
      await ref.read(songsProvider.notifier).updateSongCover(song, localPath);
      if (!host.mounted) return;
      ScaffoldMessenger.of(host).showSnackBar(
        SnackBar(
          content: Text(l10n.coverUpdated(song.title, '$source')),
        ),
      );
    } else if (host.mounted) {
      ScaffoldMessenger.of(host).showSnackBar(
        SnackBar(content: Text(l10n.coverDownloadFailed)),
      );
    }
  } catch (e) {
    if (!host.mounted) return;
    ScaffoldMessenger.of(
      host,
    ).showSnackBar(SnackBar(content: Text(l10n.coverFetchError('$e'))));
  }
}

class _MetadataUpdateRecord {
  final Song originalSong;
  final String newTitle;
  final String newArtist;
  final String newAlbum;
  final String? newCoverPath;
  final String source;

  _MetadataUpdateRecord({
    required this.originalSong,
    required this.newTitle,
    required this.newArtist,
    required this.newAlbum,
    this.newCoverPath,
    this.source = '',
  });
}

class _MetadataFetchProgress {
  final int total;
  final int processed;
  final int updated;
  final int notFound;
  final int skipped;
  final String currentSong;

  const _MetadataFetchProgress({
    required this.total,
    this.processed = 0,
    this.updated = 0,
    this.notFound = 0,
    this.skipped = 0,
    this.currentSong = '',
  });

  _MetadataFetchProgress copyWith({
    int? total,
    int? processed,
    int? updated,
    int? notFound,
    int? skipped,
    String? currentSong,
  }) {
    return _MetadataFetchProgress(
      total: total ?? this.total,
      processed: processed ?? this.processed,
      updated: updated ?? this.updated,
      notFound: notFound ?? this.notFound,
      skipped: skipped ?? this.skipped,
      currentSong: currentSong ?? this.currentSong,
    );
  }

  double get progress => total > 0 ? processed / total : 0.0;
}

Future<void> _showMetadataResultsDialog(
  BuildContext context,
  WidgetRef ref,
  List<_MetadataUpdateRecord> updatedRecords,
  List<Song> notFoundSongs,
  int skippedCount,
) async {
  if (updatedRecords.isEmpty && notFoundSongs.isEmpty) return;
  final l10n = AppLocalizations.of(context);

  // Use a mutable list so per-song undo can remove items
  final remaining = List<_MetadataUpdateRecord>.from(updatedRecords);

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Row(
              children: [
                const AppIcon(AppIcons.manageSearch, size: 22),
                const SizedBox(width: 10),
                Expanded(child: Text(l10n.metaResultsTitle)),
              ],
            ),
            content: SizedBox(
              width: double.maxFinite,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 480),
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppTokens.surface(1),
                          borderRadius: AppTokens.brMd,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            _statChip(
                              AppIcons.checkCircle,
                              AppTokens.success,
                              '${remaining.length}',
                              l10n.metaStatUpdated,
                            ),
                            _statChip(
                              AppIcons.searchOff,
                              AppTokens.fgSecondary,
                              '${notFoundSongs.length}',
                              l10n.metaStatNotFound,
                            ),
                            if (skippedCount > 0)
                              _statChip(
                                AppIcons.close,
                                AppTokens.fgTertiary,
                                '$skippedCount',
                                l10n.metaStatSkipped,
                              ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (remaining.isNotEmpty) ...[
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              l10n.metaStatUpdated,
                              style: AppTokens.rowTitle(context).copyWith(
                                fontWeight: FontWeight.bold,
                                color: AppTokens.success,
                              ),
                            ),
                            TextButton.icon(
                              icon: const AppIcon(AppIcons.restore, size: 14),
                              label: Text(l10n.metaUndoAll),
                              style: TextButton.styleFrom(
                                foregroundColor: AppTokens.danger,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 0,
                                ),
                                minimumSize: Size.zero,
                                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ),
                              onPressed: () async {
                                Navigator.pop(dialogContext);
                                for (final rec in remaining) {
                                  await ref
                                      .read(songsProvider.notifier)
                                      .updateSongMetadata(
                                        rec.originalSong,
                                        rec.originalSong.title,
                                        rec.originalSong.artist,
                                        rec.originalSong.album,
                                      );
                                  if (rec.originalSong.coverUrl !=
                                      rec.newCoverPath) {
                                    await ref
                                        .read(songsProvider.notifier)
                                        .updateSongCover(
                                          rec.originalSong,
                                          rec.originalSong.coverUrl,
                                        );
                                  }
                                }
                                if (context.mounted) {
                                  appSnack(
                                    context,
                                    l10n.metaRevertedCount(remaining.length),
                                  );
                                }
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...remaining.take(20).map(
                              (rec) => Padding(
                                padding: const EdgeInsets.only(bottom: 4.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: AppIcon(
                                        AppIcons.checkCircle,
                                        color: AppTokens.success,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            rec.newTitle.isNotEmpty
                                                ? rec.newTitle
                                                : rec.originalSong.filename,
                                            style: AppTokens.rowTitle(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            '${rec.newArtist.isNotEmpty ? rec.newArtist : '?'} — ${rec.newAlbum.isNotEmpty ? rec.newAlbum : '?'}',
                                            style: AppTokens.rowSubtitle(
                                              context,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (rec.source.isNotEmpty)
                                            Text(
                                              l10n.metaViaSource(rec.source),
                                              style: AppTokens.meta(context)
                                                  .copyWith(
                                                color: AppTokens.fgTertiary,
                                                fontSize: 11,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                    SizedBox(
                                      width: 32,
                                      height: 32,
                                      child: IconButton(
                                        icon: const AppIcon(
                                          AppIcons.restore,
                                          size: 14,
                                        ),
                                        padding: EdgeInsets.zero,
                                        tooltip: l10n.metaUndoSong,
                                        color: AppTokens.fgTertiary,
                                        onPressed: () async {
                                          await ref
                                              .read(songsProvider.notifier)
                                              .updateSongMetadata(
                                                rec.originalSong,
                                                rec.originalSong.title,
                                                rec.originalSong.artist,
                                                rec.originalSong.album,
                                              );
                                          if (rec.originalSong.coverUrl !=
                                              rec.newCoverPath) {
                                            await ref
                                                .read(songsProvider.notifier)
                                                .updateSongCover(
                                                  rec.originalSong,
                                                  rec.originalSong.coverUrl,
                                                );
                                          }
                                          remaining.remove(rec);
                                          setDialogState(() {});
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        if (remaining.length > 20) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.metaMoreItems(remaining.length - 20),
                            style: AppTokens.meta(context).copyWith(
                              color: AppTokens.fgTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                        if (notFoundSongs.isNotEmpty) const Divider(height: 24),
                      ],
                      if (notFoundSongs.isNotEmpty) ...[
                        Text(
                          l10n.metaCouldNotFind,
                          style: AppTokens.rowTitle(context).copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppTokens.fgSecondary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        ...notFoundSongs.take(15).map(
                              (song) => Padding(
                                padding: const EdgeInsets.only(bottom: 8.0),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(top: 2.0),
                                      child: AppIcon(
                                        AppIcons.searchOff,
                                        color: AppTokens.fgSecondary,
                                        size: 16,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            song.title.isEmpty
                                                ? song.filename
                                                : song.title,
                                            style: AppTokens.rowTitle(context),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          Text(
                                            song.artist.isEmpty
                                                ? l10n.metaUnknownArtist
                                                : song.artist,
                                            style: AppTokens.rowSubtitle(
                                              context,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                        if (notFoundSongs.length > 15) ...[
                          const SizedBox(height: 4),
                          Text(
                            l10n.metaMoreItems(notFoundSongs.length - 15),
                            style: AppTokens.meta(context).copyWith(
                              color: AppTokens.fgTertiary,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
              ),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: Text(l10n.actionDone),
              ),
            ],
          );
        },
      );
    },
  );
}

Widget _statChip(AppIconData icon, Color color, String value, String label) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      AppIcon(icon, color: color, size: 18),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 18,
          color: color,
        ),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 11, color: color.withValues(alpha: 0.7)),
      ),
    ],
  );
}

Future<void> songActionFetchMissingMetadata(
  BuildContext host,
  WidgetRef ref,
  Song song,
) async {
  return songActionFetchMissingMetadataForList(host, ref, [song]);
}

/// Shared mutable state for the metadata fetch progress dialog.
/// Written by the fetch loop, read by the dialog's ListenableBuilder.
class _MetadataFetchDialogState extends ChangeNotifier {
  _MetadataFetchProgress progress;
  bool cancelled = false;

  _MetadataFetchDialogState({_MetadataFetchProgress? progress})
      : progress = progress ?? _MetadataFetchProgress(total: 0);

  void updateProgress(_MetadataFetchProgress newProgress) {
    progress = newProgress;
    notifyListeners();
  }

  void cancel() {
    cancelled = true;
    notifyListeners();
  }
}

/// Shows a live progress dialog for the metadata fetch operation.
/// Returns a ChangeNotifier so the caller can update progress and cancel.
_MetadataFetchDialogState _showMetadataProgressDialog(
  BuildContext host,
  int total,
) {
  final l10n = AppLocalizations.of(host);
  final state = _MetadataFetchDialogState(
    progress: _MetadataFetchProgress(total: total),
  );

  showDialog<void>(
    context: host,
    barrierDismissible: false,
    builder: (dialogContext) {
      return PopScope(
        canPop: false,
        child: ListenableBuilder(
          listenable: state,
          builder: (context, _) {
            final p = state.progress;
            final theme = Theme.of(context);

            return AlertDialog(
              title: Row(
                children: [
                  AppIcon(AppIcons.manageSearch, size: 22),
                  SizedBox(width: 10),
                  Expanded(child: Text(l10n.metaFetchingTitle)),
                ],
              ),
              content: SizedBox(
                width: 320,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LinearProgressIndicator(
                      value: p.progress,
                      backgroundColor:
                          theme.colorScheme.surfaceContainerHighest,
                      borderRadius: AppTokens.brPill,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '${p.processed} / ${p.total}',
                          style: AppTokens.rowTitle(
                            context,
                          ).copyWith(fontWeight: FontWeight.bold),
                        ),
                        Text(
                          '${(p.progress * 100).round()}%',
                          style: AppTokens.meta(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _miniStat(
                            l10n.metaStatUpdated, p.updated, AppTokens.success),
                        const SizedBox(width: 16),
                        _miniStat(
                          l10n.metaStatNotFound,
                          p.notFound,
                          AppTokens.fgSecondary,
                        ),
                        if (p.skipped > 0) ...[
                          const SizedBox(width: 16),
                          _miniStat(l10n.metaStatSkipped, p.skipped,
                              AppTokens.fgTertiary),
                        ],
                      ],
                    ),
                    if (p.currentSong.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        p.currentSong,
                        style: AppTokens.meta(
                          context,
                        ).copyWith(color: AppTokens.fgTertiary),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: () {
                          state.cancel();
                          Navigator.pop(dialogContext);
                        },
                        icon: const AppIcon(AppIcons.close, size: 16),
                        label: Text(l10n.actionCancel),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
    },
  );

  return state;
}

Widget _miniStat(String label, int value, Color color) {
  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Text(
        '$value',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: color,
        ),
      ),
      Text(
        label,
        style: TextStyle(fontSize: 10, color: color.withValues(alpha: 0.7)),
      ),
    ],
  );
}

/// Result of searching a single song online.
/// Not an update record because we don't write to DB until after the search
/// finishes, so we can batch the writes.
class _SongSearchOutcome {
  final Song song;
  final String? newTitle;
  final String? newArtist;
  final String? newAlbum;
  final String? newCoverPath;
  final String source;
  final bool notFound;

  const _SongSearchOutcome({
    required this.song,
    this.newTitle,
    this.newArtist,
    this.newAlbum,
    this.newCoverPath,
    this.source = '',
    this.notFound = false,
  });

  bool get hasChanges =>
      newTitle != null ||
      newArtist != null ||
      newAlbum != null ||
      newCoverPath != null;
}

/// Searches a single song online (parallel deezer + itunes) and returns the
/// outcome without writing to the database yet. This lets callers run many
/// searches concurrently, then batch writes.
Future<_SongSearchOutcome> _searchSingleSong(
  Song song,
  OnlineMetadataService onlineService,
) async {
  try {
    final results = await onlineService.searchParallelForSong(song).timeout(
          const Duration(seconds: 15),
          onTimeout: () => <OnlineSearchResult>[],
        );

    if (results.isEmpty) {
      return _SongSearchOutcome(song: song, notFound: true);
    }

    final match = results.first;

    final newTitle =
        OnlineMetadataService.cleanTag(song.title) == null ? match.title : null;
    final newArtist = OnlineMetadataService.cleanTag(song.artist) == null
        ? match.artist
        : null;
    final newAlbum =
        OnlineMetadataService.cleanTag(song.album) == null ? match.album : null;

    String? newCoverPath;
    if (song.coverUrl == null || song.coverUrl!.isEmpty) {
      String? coverUrl;
      final cleanArtist = OnlineMetadataService.cleanTag(song.artist);
      final cleanAlbum = OnlineMetadataService.cleanTag(song.album);
      if (cleanArtist != null && cleanAlbum != null) {
        coverUrl = await onlineService.searchAlbumImage(
          cleanAlbum,
          artistName: cleanArtist,
        );
      }
      if ((coverUrl == null || coverUrl.isEmpty) &&
          match.coverUrl != null &&
          match.coverUrl!.isNotEmpty) {
        coverUrl = match.coverUrl;
      }
      if (coverUrl != null && coverUrl.isNotEmpty) {
        newCoverPath = await onlineService
            .downloadAndCacheCover(coverUrl, song.filename)
            .timeout(const Duration(seconds: 10), onTimeout: () => null);
      }
    }

    final hasChanges = newTitle != null ||
        newArtist != null ||
        newAlbum != null ||
        (newCoverPath != null && newCoverPath != song.coverUrl);

    if (!hasChanges) {
      return _SongSearchOutcome(song: song, notFound: true);
    }

    return _SongSearchOutcome(
      song: song,
      newTitle: newTitle,
      newArtist: newArtist,
      newAlbum: newAlbum,
      newCoverPath: newCoverPath,
      source: match.source,
    );
  } catch (_) {
    return _SongSearchOutcome(song: song, notFound: true);
  }
}

/// How many songs to search in parallel per batch.
const _batchConcurrency = 6;

Future<void> songActionFetchMissingMetadataForList(
  BuildContext host,
  WidgetRef ref,
  List<Song> songs,
) async {
  if (songs.isEmpty) return;
  final l10n = AppLocalizations.of(host);

  // Pre-filter: only process songs with truly missing metadata
  final targetSongs = songs
      .where(
        (s) =>
            OnlineMetadataService.cleanTag(s.artist) == null ||
            OnlineMetadataService.cleanTag(s.album) == null ||
            OnlineMetadataService.cleanTag(s.title) == null,
      )
      .toList();

  final skippedCount = songs.length - targetSongs.length;

  if (targetSongs.isEmpty) {
    if (host.mounted) {
      appSnack(
        host,
        skippedCount > 0
            ? l10n.metaAllHaveMetadata(skippedCount)
            : l10n.metaNoMissingMetadata,
        tone: AppTone.success,
      );
    }
    return;
  }

  // Show progress dialog
  final dialogState = _showMetadataProgressDialog(host, targetSongs.length);

  // Small delay to let the dialog render
  await Future.delayed(const Duration(milliseconds: 100));

  final onlineService = OnlineMetadataService.instance;
  final updatedRecords = <_MetadataUpdateRecord>[];
  final notFoundSongs = <Song>[];

  int processed = 0;

  // Process in batches of concurrent searches
  for (int batchStart = 0;
      batchStart < targetSongs.length && !dialogState.cancelled;
      batchStart += _batchConcurrency) {
    final batchEnd = (batchStart + _batchConcurrency).clamp(
      0,
      targetSongs.length,
    );
    final batch = targetSongs.sublist(batchStart, batchEnd);

    // Show pre-search progress
    final batchNum = batchStart ~/ _batchConcurrency + 1;
    dialogState.updateProgress(
      dialogState.progress.copyWith(
        processed: processed,
        currentSong: l10n.metaSearchingBatch(batchNum),
      ),
    );

    // Run all searches in this batch concurrently
    final outcomes = await Future.wait(
      batch.map((song) => _searchSingleSong(song, onlineService)),
    );

    if (dialogState.cancelled) break;

    // Apply DB writes sequentially (SQLite on a single connection)
    for (final outcome in outcomes) {
      if (dialogState.cancelled) break;

      if (outcome.hasChanges) {
        final song = outcome.song;
        final title = outcome.newTitle ?? song.title;
        final artist = outcome.newArtist ?? song.artist;
        final album = outcome.newAlbum ?? song.album;

        if (outcome.newTitle != null ||
            outcome.newArtist != null ||
            outcome.newAlbum != null) {
          await ref
              .read(songsProvider.notifier)
              .updateSongMetadata(song, title, artist, album);
        }
        if (outcome.newCoverPath != null &&
            outcome.newCoverPath != song.coverUrl) {
          await ref
              .read(songsProvider.notifier)
              .updateSongCover(song, outcome.newCoverPath);
        }

        updatedRecords.add(
          _MetadataUpdateRecord(
            originalSong: song,
            newTitle: title,
            newArtist: artist,
            newAlbum: album,
            newCoverPath: outcome.newCoverPath,
            source: outcome.source,
          ),
        );
        dialogState.updateProgress(
          dialogState.progress.copyWith(
            updated: dialogState.progress.updated + 1,
          ),
        );
      } else if (outcome.notFound) {
        notFoundSongs.add(outcome.song);
        dialogState.updateProgress(
          dialogState.progress.copyWith(
            notFound: dialogState.progress.notFound + 1,
          ),
        );
      }
    }

    processed = batchEnd;
    dialogState.updateProgress(
      dialogState.progress.copyWith(processed: processed, currentSong: ''),
    );
  }

  dialogState.updateProgress(
    dialogState.progress.copyWith(
      processed: targetSongs.length,
      currentSong: '',
    ),
  );

  // Close the progress dialog
  if (host.mounted && Navigator.of(host, rootNavigator: true).canPop()) {
    Navigator.of(host, rootNavigator: true).pop();
  }

  // Wait for dialog to close
  await Future.delayed(const Duration(milliseconds: 200));

  if (!host.mounted) return;

  if (dialogState.cancelled) {
    appSnack(
      host,
      l10n.metaCancelledSummary(updatedRecords.length, notFoundSongs.length),
      tone: AppTone.warning,
    );
    // Still show partial results if there were updates
    if (updatedRecords.isNotEmpty) {
      await _showMetadataResultsDialog(
        host,
        ref,
        updatedRecords,
        notFoundSongs,
        skippedCount,
      );
    }
    return;
  }

  await _showMetadataResultsDialog(
    host,
    ref,
    updatedRecords,
    notFoundSongs,
    skippedCount,
  );
}
