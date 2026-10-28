// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../domain/models/youtube_playlist_link.dart';
import '../domain/services/youtube_library.dart';
import '../domain/services/youtube_music_feed.dart';
import '../models/playlist.dart';
import '../models/song.dart';
import '../services/database_service.dart';
import '../domain/services/taste_model.dart';
import '../services/online_music_service.dart';
import '../services/youtube_account_service.dart';
import '../services/youtube_feed_cache.dart';
import 'providers.dart';
import 'settings_provider.dart';

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
  if (!ref.watch(settingsProvider.select((s) => s.youtubeEnabled))) {
    return const [];
  }
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
///
/// Empty while the catalogue is off: a link badge and a "sync now" action would
/// be the only trace of a feature the user disabled.
final youtubePlaylistLinksProvider =
    FutureProvider<Map<String, YouTubePlaylistLink>>((ref) async {
  if (!ref.watch(settingsProvider.select((s) => s.youtubeEnabled))) {
    return const {};
  }
  final links = await DatabaseService.instance.getYouTubePlaylistLinks();
  return {for (final link in links) link.localPlaylistId: link};
});

/// The feed on the YouTube tab: music from the catalogue, ranked by what this
/// device actually plays.
///
/// Two pools feed it. The library pool is a music-catalogue search per strongest
/// artist, so it always follows the listening history. The account pool is the
/// signed-in YouTube Music home, which is music-only by construction. Neither
/// pool is a www.youtube.com feed: that home page follows watch history and
/// subscriptions, which is how the tab ended up full of trailers and gameplay
/// the moment anyone signed in.
///
/// Everything goes through [rankYouTubeMusicFeed], where the local taste profile
/// outweighs the account's shelves, so the account can widen the feed but never
/// steer it.
///
/// The ranked result is cached on disk and painted first, so opening the tab is
/// instant on every launch after the first. The refresh then runs behind the
/// list; nothing on screen is cleared while it does, and a play — which bumps a
/// play count and a remote-song row — no longer rebuilds the feed at all.
final youtubeForYouTracksProvider =
    AsyncNotifierProvider<YouTubeFeedNotifier, List<OnlineTrack>>(
  YouTubeFeedNotifier.new,
);

/// Builds, caches and refreshes the feed on the YouTube tab.
class YouTubeFeedNotifier extends AsyncNotifier<List<OnlineTrack>> {
  /// A snapshot older than this is refreshed behind the list already shown.
  static const Duration refreshAfter = Duration(minutes: 30);

  /// Searches per feed. Each is a round trip, issued alongside the home page.
  static const int _seedArtists = 4;

  /// YouTube answers a burst less kindly than a trickle, so the pools share a
  /// small budget instead of firing all at once.
  static const int _maxConcurrentPools = 3;

  Future<void>? _inFlight;
  bool _disposed = false;

  @override
  Future<List<OnlineTrack>> build() async {
    ref.onDispose(() => _disposed = true);
    if (!ref.watch(settingsProvider.select((s) => s.youtubeEnabled))) {
      return const [];
    }
    await ref.watch(youtubeAccountProvider.future);
    // Dependency only, not an await: a cached feed can paint before the library
    // has finished loading, and this is what still rebuilds it after a rescan.
    ref.watch(songsProvider);

    // The snapshot is read before the taste model is consulted on purpose: the
    // model needs play events and an isolate, and the tab should not wait for
    // any of that to show the feed it showed last time.
    final cached = await YouTubeFeedCache.instance.read();
    if (cached != null) {
      unawaited(_refreshIfStale(cached));
      return cached.tracks;
    }
    final songs = await ref.read(songsProvider.future);
    return _fetch(await _readInputs(songs));
  }

  /// Rebuilds the feed from the network. Never clears what is on screen: a
  /// failed refresh leaves the previous feed in place.
  Future<void> refresh() async {
    final inputs = await _readInputs(await ref.read(songsProvider.future));
    await _refresh(inputs);
  }

  Future<void> _refreshIfStale(YouTubeFeedSnapshot cached) async {
    try {
      final inputs = await _readInputs(await ref.read(songsProvider.future));
      if (cached.signature != inputs.signature || cached.age > refreshAfter) {
        await _refresh(inputs);
      }
    } on Object catch (error) {
      debugPrint('YouTube feed refresh check: $error');
    }
  }

  Future<void> _refresh(_FeedInputs inputs) {
    return _inFlight ??= () async {
      try {
        final tracks = await _fetch(inputs);
        if (!_disposed) state = AsyncData(tracks);
      } on Object catch (error) {
        debugPrint('YouTube feed refresh: $error');
      } finally {
        _inFlight = null;
      }
    }();
  }

  Future<List<OnlineTrack>> _fetch(_FeedInputs inputs) async {
    final taste = inputs.taste;
    final api = YouTubeAccountService.instance.libraryApi();
    Object? firstError;

    Future<List<YouTubePlaylistItem>> pool(
      Future<List<YouTubePlaylistItem>> Function() run,
    ) async {
      try {
        return await run();
      } on Object catch (error) {
        firstError ??= error;
        _logFeedError(error);
        return const [];
      }
    }

    // The music home answers with or without an account; signed in it follows
    // the account's own music history, signed out it is charts and popular
    // picks. Each seeded artist returns only songs and music videos, so the
    // pool cannot produce a trailer.
    final pools = <Future<List<YouTubePlaylistItem>> Function()>[
      () => pool(() => api.musicHomeFeed(maxPages: 2)),
      for (final artist in taste.topArtists.take(_seedArtists))
        () => pool(() => api.musicSearch(artist, artistHint: artist)),
    ];
    final results = await _runPools(pools);

    final candidates = <YouTubeFeedCandidate>[
      for (final item in results.first)
        YouTubeFeedCandidate(
          item: normalizeMusicTrack(item),
          source: YouTubeFeedSource.accountFeed,
        ),
      for (final items in results.skip(1))
        for (final item in items)
          YouTubeFeedCandidate(
            item: normalizeMusicTrack(item),
            source: YouTubeFeedSource.libraryArtist,
          ),
    ];

    final failure = firstError;
    if (candidates.isEmpty && failure != null) throw failure;

    final ranked = rankYouTubeMusicFeed(taste: taste, candidates: candidates);
    final tracks = List<OnlineTrack>.unmodifiable([
      for (final item in ranked)
        OnlineTrack(
          id: item.videoId,
          title: item.title,
          artist: item.artist,
          coverUrl: item.thumbnailUrl ?? youtubeThumbnailUrl(item.videoId),
          duration: item.duration,
        ),
    ]);

    await YouTubeFeedCache.instance.write(
      YouTubeFeedSnapshot(
        tracks: tracks,
        signature: inputs.signature,
        fetchedAt: DateTime.now(),
      ),
    );
    return tracks;
  }

  /// Runs [tasks] with at most [_maxConcurrentPools] in flight, keeping their
  /// order so the ranker's tie-breaks stay stable between refreshes.
  Future<List<List<YouTubePlaylistItem>>> _runPools(
    List<Future<List<YouTubePlaylistItem>> Function()> tasks,
  ) async {
    final results = List<List<YouTubePlaylistItem>?>.filled(tasks.length, null);
    var next = 0;

    Future<void> worker() async {
      while (next < tasks.length) {
        final index = next++;
        results[index] = await tasks[index]();
      }
    }

    final workers = math.min(_maxConcurrentPools, tasks.length);
    await Future.wait([for (var i = 0; i < workers; i++) worker()]);
    return [for (final result in results) result ?? const []];
  }

  /// Everything the feed is built from, plus a coarse signature of it.
  Future<_FeedInputs> _readInputs(List<Song> songs) async {
    final userData = ref.read(userDataProvider);
    final lastPlayed = await ref.read(lastPlayedTimestampsProvider.future);
    // A taste model that is not ready yet is not a feed failure: the library
    // channel below still describes the listener.
    TasteSnapshot? smart;
    try {
      smart = await ref.read(tasteSnapshotProvider.future);
    } on Object catch (error) {
      debugPrint('YouTube feed: no taste snapshot yet: $error');
    }
    final nowSec = DateTime.now().millisecondsSinceEpoch / 1000.0;

    double? ageDaysOf(String filename) {
      final at = lastPlayed[filename];
      if (at == null || at <= 0) return null;
      return ((nowSec - at) / 86400.0).clamp(0.0, 3650.0);
    }

    final signals = <YouTubeTasteSignal>[
      for (final song in songs)
        YouTubeTasteSignal(
          artist: song.artist,
          title: song.title,
          playCount: song.playCount,
          favorite: userData.isFavorite(song.filename),
          videoId: _videoIdOf(song.filename),
          ageDays: ageDaysOf(song.filename),
        ),
      // Saved remote tracks are listening history too, and their ids keep the
      // feed from suggesting a song the listener already keeps.
      for (final song in userData.remoteSongs.values)
        YouTubeTasteSignal(
          artist: song.artist,
          title: song.title,
          playCount: song.playCount,
          videoId: _videoIdOf(song.filename),
          ageDays: ageDaysOf(song.filename),
        ),
    ];

    // The smart-shuffle model already weighs the last month above the long run,
    // so an artist abandoned months ago arrives here weak instead of carrying a
    // lifetime play count into the four seed slots.
    final artistTaste = <String, double>{};
    if (smart != null) {
      for (final entry in smart.artists.entries) {
        final key = artistKey(entry.key);
        if (key.isEmpty) continue;
        final mass = entry.value.trendMass +
            entry.value.longMass * kYouTubeLongTasteShare;
        if (mass <= 0) continue;
        artistTaste.update(key, (value) => value + mass, ifAbsent: () => mass);
      }
    }

    final taste = buildYouTubeTasteProfile(signals, artistTaste: artistTaste);
    final signedIn =
        ref.read(youtubeAccountProvider).asData?.value.signedIn ?? false;

    // Deliberately coarse: a play bumps a play count and can add a streamed row
    // on the very next tap, and neither may invalidate the feed the listener is
    // reading. Only a different library, account or set of seed artists does.
    final signature = [
      signedIn ? 'in' : 'out',
      songs.length,
      ...taste.topArtists,
    ].join('|');

    return _FeedInputs(taste: taste, signature: signature);
  }
}

class _FeedInputs {
  final YouTubeTasteProfile taste;
  final String signature;

  const _FeedInputs({required this.taste, required this.signature});
}

/// A failed pool is logged, never escalated: the music client works without a
/// session, so a rejected request says nothing about the stored cookies, and
/// invalidating the account from here would rebuild this provider into the same
/// failure.
void _logFeedError(Object error) => debugPrint('YouTube feed: $error');

String? _videoIdOf(String filename) {
  if (!filename.startsWith(Song.youtubePrefix)) return null;
  final id = filename.substring(Song.youtubePrefix.length);
  return id.isEmpty ? null : id;
}

/// Tracks of one account playlist (or the liked-videos list), for the preview
/// screen. Cached by the library, so opening a playlist twice is instant.
final youtubePlaylistTracksProvider =
    FutureProvider.family<List<YouTubePlaylistItem>, String>(
  (ref, playlistId) async {
    if (!ref.watch(settingsProvider.select((s) => s.youtubeEnabled))) {
      return const [];
    }
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
