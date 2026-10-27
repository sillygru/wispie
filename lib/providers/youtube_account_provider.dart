// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/youtube_playlist_link.dart';
import '../domain/services/youtube_library.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/database_service.dart';
import '../services/online_music_service.dart';
import '../services/youtube_account_service.dart';
import '../services/youtube_service.dart';
import 'providers.dart';

/// Signed-in state of the YouTube account.
class YouTubeAccountNotifier extends AsyncNotifier<YouTubeAccountSnapshot> {
  @override
  Future<YouTubeAccountSnapshot> build() {
    return YouTubeAccountService.instance.load();
  }

  YouTubeAccountService get _service => YouTubeAccountService.instance;

  /// Accepts cookies harvested from a WebView login or pasted from a browser.
  ///
  /// Throws a [YouTubeLibraryException] with [YouTubeLibraryErrorKind.unauthorized]
  /// when the jar does not sign a real youtube.com request.
  Future<void> signIn(Map<String, String> cookies) async {
    await _service.signIn(cookies);
    state = AsyncData(_service.snapshot);
    ref.invalidate(youtubeAccountPlaylistsProvider);
  }

  Future<void> signOut() async {
    await _service.signOut();
    state = AsyncData(_service.snapshot);
    ref.invalidate(youtubeAccountPlaylistsProvider);
  }

  /// Refreshes the channel name and avatar; a failure keeps the old one.
  Future<void> refreshProfile() async {
    try {
      await _service.fetchProfile();
    } on Object catch (error) {
      debugPrint('YouTube: could not load the account profile: $error');
      return;
    }
    state = AsyncData(_service.snapshot);
  }

  // ---------------------------------------------------------------------
  // Playlist import
  // ---------------------------------------------------------------------

  /// Brings the account's [remote] playlist into the local playlist collection.
  ///
  /// Importing the same playlist twice syncs instead of duplicating: the link
  /// table decides, so a user who taps Import again after adding tracks on
  /// YouTube gets the new ones.
  Future<YouTubePlaylistSyncSummary> importPlaylist(
    YouTubeAccountPlaylist remote, {
    String? localName,
    int maxNewItems = 1000,
  }) async {
    final api = _service.libraryApi();
    final items = await _fetchItems(api, remote);

    final links = await DatabaseService.instance.getYouTubePlaylistLinks();
    final existingLink =
        links.where((link) => link.remotePlaylistId == remote.id).firstOrNull;
    if (existingLink != null) {
      final localExists = ref
          .read(userDataProvider)
          .playlists
          .any((playlist) => playlist.id == existingLink.localPlaylistId);
      if (localExists) {
        return _sync(
          existingLink,
          items: items,
          remoteItemCount: remote.itemCount,
        );
      }
      // The local playlist was deleted; the link is stale.
      await DatabaseService.instance
          .deleteYouTubePlaylistLink(existingLink.remotePlaylistId);
    }

    final name = (localName ?? remote.title).trim();
    final plan = planPlaylistImport(
      remoteItems: items,
      localVideoIds: const {},
      maxNewItems: maxNewItems,
    );
    final songs = [for (final item in plan.toAdd) _songFor(item)];

    if (songs.isEmpty) {
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.notFound,
        'The playlist has no playable tracks.',
      );
    }

    final userData = ref.read(userDataProvider.notifier);
    await userData.cacheRemoteSongs(songs);

    // Spacing the timestamps keeps remote order when playlists are read back
    // (they sort on added_at) without needing a second ordering column.
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    final playlist = Playlist(
      id: const Uuid().v4(),
      name: name,
      createdAt: now,
      updatedAt: now,
      songs: [
        for (var i = 0; i < songs.length; i++)
          PlaylistSong(
            songFilename: songs[i].filename,
            addedAt: now + i * 0.001,
          ),
      ],
    );
    await DatabaseService.instance.savePlaylist(playlist);
    await DatabaseService.instance.upsertYouTubePlaylistLink(
      YouTubePlaylistLink(
        remotePlaylistId: remote.id,
        localPlaylistId: playlist.id,
        remoteTitle: name,
        lastSyncedAt: now,
        itemCount: items.length,
      ),
    );

    await userData.refresh();
    ref.invalidate(youtubePlaylistLinksProvider);
    return YouTubePlaylistSyncSummary(
      playlistName: name,
      added: songs.length,
      skippedForLimit: plan.skippedForLimit,
      created: true,
    );
  }

  /// Adds tracks that appeared on YouTube since the last sync. Never removes.
  Future<YouTubePlaylistSyncSummary> syncPlaylist(
    YouTubePlaylistLink link,
  ) async {
    final api = _service.libraryApi();
    final items = await _fetchLinkItems(api, link);
    return _sync(link, items: items);
  }

  Future<List<YouTubePlaylistSyncSummary>> syncAll() async {
    final links = await DatabaseService.instance.getYouTubePlaylistLinks();
    final summaries = <YouTubePlaylistSyncSummary>[];
    for (final link in links) {
      try {
        summaries.add(await syncPlaylist(link));
      } on Object catch (error) {
        debugPrint('YouTube: sync failed for ${link.remotePlaylistId}: $error');
        summaries.add(
          YouTubePlaylistSyncSummary(
            playlistName: link.remoteTitle,
            added: 0,
            failed: true,
          ),
        );
      }
    }
    ref.invalidate(youtubePlaylistLinksProvider);
    return summaries;
  }

  Future<YouTubePlaylistSyncSummary> _sync(
    YouTubePlaylistLink link, {
    List<YouTubePlaylistItem>? items,
    int? remoteItemCount,
  }) async {
    final fetched = items ?? await _fetchLinkItems(_service.libraryApi(), link);

    final userData = ref.read(userDataProvider.notifier);
    final local = ref
        .read(userDataProvider)
        .playlists
        .where((playlist) => playlist.id == link.localPlaylistId)
        .firstOrNull;
    if (local == null) {
      await DatabaseService.instance
          .deleteYouTubePlaylistLink(link.remotePlaylistId);
      ref.invalidate(youtubePlaylistLinksProvider);
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.notFound,
        'The local playlist no longer exists.',
      );
    }

    final localIds = {
      for (final entry in local.songs)
        if (_videoIdOf(entry.songFilename) case final id?) id,
    };
    final plan = planPlaylistImport(
      remoteItems: fetched,
      localVideoIds: localIds,
    );

    if (plan.toAdd.isNotEmpty) {
      final songs = [for (final item in plan.toAdd) _songFor(item)];
      await userData.cacheRemoteSongs(songs);
      await userData.bulkAddSongsToPlaylist(
        local.id,
        [for (final song in songs) song.filename],
      );
    }

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
    await DatabaseService.instance.upsertYouTubePlaylistLink(
      link.copyWith(
        lastSyncedAt: now,
        itemCount: remoteItemCount ?? fetched.length,
      ),
    );
    ref.invalidate(youtubePlaylistLinksProvider);

    return YouTubePlaylistSyncSummary(
      playlistName: local.name,
      added: plan.toAdd.length,
      alreadyPresent: plan.alreadyLocal.length,
      skippedForLimit: plan.skippedForLimit,
    );
  }

  Future<List<YouTubePlaylistItem>> _fetchItems(
    YouTubeLibraryApi api,
    YouTubeAccountPlaylist remote,
  ) async {
    try {
      return remote.isLikedVideos
          ? await api.likedVideos()
          : await api.playlistItems(remote.id);
    } on Object catch (error) {
      _noteFailure(error);
      rethrow;
    }
  }

  Future<List<YouTubePlaylistItem>> _fetchLinkItems(
    YouTubeLibraryApi api,
    YouTubePlaylistLink link,
  ) async {
    try {
      return link.remotePlaylistId == kLikedVideosPlaylistId
          ? await api.likedVideos()
          : await api.playlistItems(link.remotePlaylistId);
    } on Object catch (error) {
      _noteFailure(error);
      rethrow;
    }
  }

  /// A rejected session is an account problem, not a request problem: drop the
  /// dead cookies so the screen stops offering Import buttons that cannot work.
  void _noteFailure(Object error) {
    if (error is YouTubeLibraryException &&
        error.kind == YouTubeLibraryErrorKind.unauthorized) {
      unawaited(_service.forgetSession().then((_) {
        state = AsyncData(_service.snapshot);
      }));
    }
  }

  static Song _songFor(YouTubePlaylistItem item) {
    return Song.youtube(
      videoId: item.videoId,
      title: item.title,
      artist: item.artist,
      coverUrl: youtubeThumbnailUrl(item.videoId),
      duration: item.duration,
    );
  }

  static String? _videoIdOf(String filename) {
    if (!filename.startsWith(Song.youtubePrefix)) return null;
    final id = filename.substring(Song.youtubePrefix.length);
    return id.isEmpty ? null : id;
  }
}

/// What one import or sync changed, so the screen can report it honestly.
class YouTubePlaylistSyncSummary {
  final String playlistName;
  final int added;
  final int alreadyPresent;
  final int skippedForLimit;
  final bool created;
  final bool failed;

  const YouTubePlaylistSyncSummary({
    required this.playlistName,
    this.added = 0,
    this.alreadyPresent = 0,
    this.skippedForLimit = 0,
    this.created = false,
    this.failed = false,
  });
}

final youtubeAccountProvider =
    AsyncNotifierProvider<YouTubeAccountNotifier, YouTubeAccountSnapshot>(
  YouTubeAccountNotifier.new,
);

/// The account's playlists plus the synthetic liked-videos entry.
final youtubeAccountPlaylistsProvider =
    FutureProvider<List<YouTubeAccountPlaylist>>((ref) async {
  final account = await ref.watch(youtubeAccountProvider.future);
  if (!account.signedIn) return const [];
  try {
    return await YouTubeAccountService.instance.libraryApi().playlists();
  } on YouTubeLibraryException catch (error) {
    if (error.kind == YouTubeLibraryErrorKind.unauthorized) {
      // Reloading the account re-reads the service, which has already dropped
      // the dead tokens; the screen then offers sign-in instead of a retry loop.
      ref.invalidate(youtubeAccountProvider);
    }
    rethrow;
  }
});

/// Local playlists that mirror an account playlist, keyed by local id.
final youtubePlaylistLinksProvider =
    FutureProvider<Map<String, YouTubePlaylistLink>>((ref) async {
  final links = await DatabaseService.instance.getYouTubePlaylistLinks();
  return {for (final link in links) link.localPlaylistId: link};
});

/// The signed-in home feed: YouTube's own recommendations for this account.
final youtubeHomeTracksProvider =
    FutureProvider<List<OnlineTrack>>((ref) async {
  final account = await ref.watch(youtubeAccountProvider.future);
  if (!account.signedIn) return const [];
  try {
    final items = await YouTubeAccountService.instance.libraryApi().homeFeed();
    return List<OnlineTrack>.unmodifiable(
      items.map(
        (item) => OnlineTrack(
          id: item.videoId,
          title: item.title,
          artist: item.artist,
          coverUrl: item.thumbnailUrl,
          duration: item.duration,
        ),
      ),
    );
  } on YouTubeLibraryException catch (error) {
    if (error.kind == YouTubeLibraryErrorKind.unauthorized) {
      ref.invalidate(youtubeAccountProvider);
    }
    rethrow;
  }
});

/// YouTube results for the artists this device plays most.
///
/// Works without an account, which is what keeps the tab useful before sign-in
/// and for people who never sign in at all.
final youtubeArtistTracksProvider =
    FutureProvider<List<OnlineTrack>>((ref) async {
  final songs = ref.watch(songsProvider).asData?.value ?? const <Song>[];
  if (songs.isEmpty) return const [];

  // Ranked on the library snapshot only: live play counts change constantly
  // and would re-run four searches while the user is playing something.
  final scores = <String, double>{};
  for (final song in songs) {
    final artist = song.artist.trim();
    if (artist.isEmpty) continue;
    scores[artist] = (scores[artist] ?? 0) + song.playCount + 1;
  }
  if (scores.isEmpty) return const [];
  final artists = (scores.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(4)
      .map((entry) => entry.key);

  final seen = <String>{};
  final tracks = <OnlineTrack>[];
  for (final artist in artists) {
    if (tracks.length >= 12) break;
    List<YouTubeVideo> videos;
    try {
      videos = await YouTubeService.instance.search(artist, limit: 4);
    } on Object {
      // One artist the catalogue refuses must not empty the whole rail.
      continue;
    }
    for (final video in videos) {
      if (!seen.add(video.id)) continue;
      tracks.add(
        OnlineTrack(
          id: video.id,
          title: video.title,
          artist: video.artist,
          coverUrl: video.thumbnailUrl,
          duration: video.duration,
        ),
      );
      if (tracks.length >= 12) break;
    }
  }
  return List<OnlineTrack>.unmodifiable(tracks);
});

/// Tracks of one account playlist (or the liked-videos list), for the preview
/// screen. Cached by the library, so opening a playlist twice is instant.
final youtubePlaylistTracksProvider =
    FutureProvider.family<List<YouTubePlaylistItem>, String>(
  (ref, playlistId) async {
    final account = await ref.watch(youtubeAccountProvider.future);
    if (!account.signedIn) return const [];
    final api = YouTubeAccountService.instance.libraryApi();
    try {
      return playlistId == kLikedVideosPlaylistId
          ? await api.likedVideos()
          : await api.playlistItems(playlistId);
    } on YouTubeLibraryException catch (error) {
      if (error.kind == YouTubeLibraryErrorKind.unauthorized) {
        ref.invalidate(youtubeAccountProvider);
      }
      rethrow;
    }
  },
);

/// Playlists hidden from the YouTube tab's rail.
///
/// Watch later is hidden on first run: it collects one-off videos rather than
/// music, and it is the playlist most likely to be noise on a music screen. The
/// filter sheet can bring it (or anything else) back.
class YouTubeHiddenPlaylistsNotifier extends AsyncNotifier<List<String>> {
  static const String prefsKey = 'youtube_hidden_playlists';
  static const List<String> defaults = ['WL'];

  @override
  Future<List<String>> build() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getStringList(prefsKey) ?? defaults;
  }

  Future<void> setHidden(String playlistId, bool hidden) async {
    final current = [...(state.value ?? defaults)];
    if (hidden) {
      if (!current.contains(playlistId)) current.add(playlistId);
    } else {
      current.remove(playlistId);
    }
    await _save(current);
  }

  Future<void> clear() => _save(const []);

  Future<void> _save(List<String> hidden) async {
    state = AsyncData(hidden);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(prefsKey, hidden);
  }
}

final youtubeHiddenPlaylistsProvider =
    AsyncNotifierProvider<YouTubeHiddenPlaylistsNotifier, List<String>>(
  YouTubeHiddenPlaylistsNotifier.new,
);
