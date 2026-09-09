import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';
import '../providers/artist_album_art_provider.dart';
import '../providers/providers.dart';
import 'library_logic.dart';
import 'music_utils_api_client.dart';
import 'online_metadata_service.dart';

/// Outcome of resolving artwork for one artist/album key.
enum _FetchOutcome {
  success,
  notFound,
  transient,
  abandoned,
}

/// A downloaded cover waiting to be saved through the provider.
typedef _ArtistSave = ({
  String artist,
  String localPath,
  String imageUrl,
  String source,
});

/// A downloaded cover waiting to be saved through the provider.
typedef _AlbumSave = ({
  String album,
  String artist,
  String localPath,
  String imageUrl,
  String source,
});

/// Artists/albums still missing art, most-tracks-first.
typedef MissingArt = ({
  List<String> artists,
  List<Map<String, String>> albums,
});

/// Progress callback: [done] of [total] keys resolved.
typedef ArtFetchProgress = void Function(int done, int total);

/// Outcome of one [PassiveArtFetcherService.runArtBurst] run.
typedef ArtBurstResult = ({
  int fetchedArtists,
  int fetchedAlbums,
  List<String> failedItems,
  bool cancelled,
  bool offline,
});

/// Passively fetches missing artist and album artwork while the app is foregrounded.
///
/// Strategy: on every app open, burst-fetch everything missing through the
/// high-limit music-utils API (20 concurrent lookups), because that service
/// allows ~200 requests/second. The slow direct providers (Deezer, iTunes,
/// Last.fm scrapes) stay out of the burst; manual artwork search still uses
/// them on demand.
///
/// Each key gets up to 3 attempts with a 5 second gap, and no network request
/// fires while the app is backgrounded. A definitive "no results"
/// (404/empty) is persisted with a timestamp and skipped by automatic
/// fetching afterwards; transient failures (timeout, 5xx, offline, download
/// errors) are only remembered for the current launch and retried on the
/// next app open. Manual artwork search bypasses the skip list entirely.
///
/// Attempt bookkeeping:
/// * `_noResultArtists/_noResultAlbums` — persisted 404 skips with the time
///   of the last failed lookup. Survive restarts.
/// * `_triedThisLaunchArtists/_triedThisLaunchAlbums` — transient failures
///   already retried 3 times this launch. Never persisted.
class PassiveArtFetcherService with WidgetsBindingObserver {
  static final PassiveArtFetcherService instance =
      PassiveArtFetcherService._internal();

  PassiveArtFetcherService._internal();

  factory PassiveArtFetcherService() => instance;

  /// Persisted 404 skips (JSON map key -> ISO timestamp).
  static const String _noResultArtistsKey = 'art_fetch_noresult_artists_v2';
  static const String _noResultAlbumsKey = 'art_fetch_noresult_albums_v2';

  /// Legacy keys from the once-per-day regime. Their lists mixed transient
  /// failures with real misses, so they are dropped once: transient items are
  /// correctly retried, true 404s re-persist after one burst.
  static const String _legacyAttemptedArtistsKey =
      'art_fetch_attempted_artists';
  static const String _legacyAttemptedAlbumsKey = 'art_fetch_attempted_albums';
  static const String _legacyLibraryScanDateKey = 'art_fetch_library_scan_date';

  /// music-utils allows ~200 req/s; 20 concurrent lookups stay far below it
  /// while finishing a large library in roughly a minute.
  static const int _burstConcurrency = 20;

  /// Downloads decode images, so they run under a tighter pool than lookups.
  static const int _downloadConcurrency = 8;

  static const int _maxAttempts = 3;
  static const Duration _retryDelay = Duration(seconds: 5);

  /// After this many consecutive transient failures the sweep probes the
  /// API host before deciding it is offline. The probe (a raw socket
  /// connect) is the only thing allowed to declare offline: server-side
  /// 5xx/429, bad JSON and dead cover CDN URLs all look like "transient"
  /// otherwise, and must only fail their own key, never the whole run.
  static const int _offlineBreakerThreshold = 10;
  static const Duration _offlineCooldown = Duration(minutes: 5);
  static const Duration _probeTimeout = Duration(seconds: 5);

  dynamic _containerRef;
  bool _isForegrounded = true;
  bool _isRunning = false;

  /// Passive sweep backoff only. Explicit user runs (driven mode) always
  /// bypass it: a tap means "try the network now".
  DateTime? _offlineBackoffUntil;
  Future<bool>? _probeInFlight;

  @visibleForTesting
  Future<bool> Function()? probeOverrideForTest;

  final Map<String, DateTime> _noResultArtists = {};
  final Map<String, DateTime> _noResultAlbums = {};
  final Set<String> _triedThisLaunchArtists = {};
  final Set<String> _triedThisLaunchAlbums = {};
  final Set<String> _inFlightArtists = {};
  final Set<String> _inFlightAlbums = {};

  final List<String> _priorityArtistQueue = [];
  final List<Map<String, String>> _priorityAlbumQueue = [];

  Timer? _persistTimer;
  Future<void>? _flushInFlight;
  bool _persistDirty = false;

  void init(dynamic ref) {
    _containerRef = ref;
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initNoResultsThenStart());
  }

  Future<void> _initNoResultsThenStart() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _noResultArtists
        ..clear()
        ..addAll(_decodeNoResults(prefs.getString(_noResultArtistsKey)));
      _noResultAlbums
        ..clear()
        ..addAll(_decodeNoResults(prefs.getString(_noResultAlbumsKey)));
      await prefs.remove(_legacyAttemptedArtistsKey);
      await prefs.remove(_legacyAttemptedAlbumsKey);
      await prefs.remove(_legacyLibraryScanDateKey);
    } catch (e) {
      debugPrint('PassiveArtFetcher: no-result cache load failed: $e');
    }
    start();
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _isRunning = false;
    unawaited(_flushPersist());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _isForegrounded = (state == AppLifecycleState.resumed);
    if (_isForegrounded) {
      start();
    } else {
      unawaited(_flushPersist());
    }
  }

  /// Session-only: remembers [artist] so nothing re-searches it this launch.
  /// Also clears a stale 404 record, e.g. after a manual set succeeded.
  void markArtistAttempted(String artist) {
    final lower = artist.trim().toLowerCase();
    if (lower.isEmpty) return;
    _triedThisLaunchArtists.add(lower);
    if (_noResultArtists.remove(lower) != null) _schedulePersist();
  }

  /// Session-only: remembers this album so nothing re-searches it this launch.
  void markAlbumAttempted(String album, String? artist) {
    final key = _albumKey(album, artist);
    if (key.isEmpty) return;
    _triedThisLaunchAlbums.add(key);
    if (_noResultAlbums.remove(key) != null) _schedulePersist();
  }

  /// Lifts a persisted 404 for [artist] so a future sweep can try again.
  /// Called when the user removes art or the cached file went stale.
  void forgetArtistAttempt(String artist) {
    final lower = artist.trim().toLowerCase();
    if (lower.isEmpty) return;
    _triedThisLaunchArtists.remove(lower);
    if (_noResultArtists.remove(lower) != null) _schedulePersist();
  }

  /// Lifts a persisted 404 for this album, mirroring [forgetArtistAttempt].
  void forgetAlbumAttempt(String album, String? artist) {
    final key = _albumKey(album, artist);
    if (key.isEmpty) return;
    _triedThisLaunchAlbums.remove(key);
    if (_noResultAlbums.remove(key) != null) _schedulePersist();
  }

  /// Drops every recorded 404 so the next sweep treats the whole library as
  /// unfetched again. Called when the user wipes all art. Also lifts any
  /// offline backoff: an explicit wipe followed by a fetch is the user
  /// saying "try the network now", so stale backoff must not poison it.
  Future<void> clearAttempted() async {
    _noResultArtists.clear();
    _noResultAlbums.clear();
    _triedThisLaunchArtists.clear();
    _triedThisLaunchAlbums.clear();
    _offlineBackoffUntil = null;
    _probeInFlight = null;
    _persistTimer?.cancel();
    _persistTimer = null;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_noResultArtistsKey);
      await prefs.remove(_noResultAlbumsKey);
      await prefs.remove(_legacyAttemptedArtistsKey);
      await prefs.remove(_legacyAttemptedAlbumsKey);
      await prefs.remove(_legacyLibraryScanDateKey);
    } catch (e) {
      debugPrint('PassiveArtFetcher: clearAttempted failed: $e');
    }
  }

  @visibleForTesting
  bool isArtistSkipped(String artist) {
    return _noResultArtists.containsKey(artist.trim().toLowerCase());
  }

  @visibleForTesting
  bool isAlbumSkipped(String album, String? artist) {
    final key = _albumKey(album, artist);
    return key.isNotEmpty && _noResultAlbums.containsKey(key);
  }

  @visibleForTesting
  void recordArtistNoResultForTest(String artist, DateTime at) {
    final lower = artist.trim().toLowerCase();
    if (lower.isEmpty) return;
    _noResultArtists[lower] = at;
    _schedulePersist();
  }

  @visibleForTesting
  void recordAlbumNoResultForTest(String album, String? artist, DateTime at) {
    final key = _albumKey(album, artist);
    if (key.isEmpty) return;
    _noResultAlbums[key] = at;
    _schedulePersist();
  }

  @visibleForTesting
  Future<void> flushPersistForTest() => _flushPersist();

  @visibleForTesting
  void setOfflineBackoffForTest(DateTime? until) {
    _offlineBackoffUntil = until;
  }

  @visibleForTesting
  bool get isBackingOffForTest =>
      _offlineBackoffUntil != null &&
      DateTime.now().isBefore(_offlineBackoffUntil!);

  @visibleForTesting
  Future<bool> isApiReachableForTest() => _isApiReachable();

  @visibleForTesting
  Future<bool> confirmApiReachableForTest() => _confirmApiReachable();

  void fetchArtistArtIfNeeded(String artist) {
    final clean = OnlineMetadataService.cleanTag(artist);
    if (clean == null) return;
    final lower = clean.toLowerCase();
    if (_noResultArtists.containsKey(lower)) return;
    if (_triedThisLaunchArtists.contains(lower)) return;
    if (_inFlightArtists.contains(lower)) return;

    final ref = _containerRef;
    if (ref != null) {
      final artState = ref.read(artistAlbumArtProvider);
      if (artState.getArtistArt(clean) != null) return;
    }

    if (!_priorityArtistQueue.contains(clean)) {
      _priorityArtistQueue.insert(0, clean);
    }
    start();
  }

  void fetchAlbumArtIfNeeded(String album, String? artist) {
    final cleanAlbum = OnlineMetadataService.cleanTag(album);
    if (cleanAlbum == null) return;
    final cleanArtist = OnlineMetadataService.cleanTag(artist);
    final key = _albumKey(cleanAlbum, cleanArtist);
    if (_noResultAlbums.containsKey(key)) return;
    if (_triedThisLaunchAlbums.contains(key)) return;
    if (_inFlightAlbums.contains(key)) return;

    final ref = _containerRef;
    if (ref != null) {
      final artState = ref.read(artistAlbumArtProvider);
      if (artState.getAlbumArt(cleanAlbum, artistName: cleanArtist) != null) {
        return;
      }
    }

    final item = {'album': cleanAlbum, 'artist': cleanArtist ?? ''};
    if (!_priorityAlbumQueue.any(
      (m) => m['album'] == cleanAlbum && m['artist'] == (cleanArtist ?? ''),
    )) {
      _priorityAlbumQueue.insert(0, item);
    }
    start();
  }

  void start() {
    if (_isRunning || Platform.environment.containsKey('FLUTTER_TEST')) return;
    _isRunning = true;
    unawaited(_runPassiveLoop());
  }

  void _schedulePersist() {
    _persistDirty = true;
    if (_persistTimer != null) return;
    _persistTimer = Timer(const Duration(seconds: 3), () {
      _persistTimer = null;
      unawaited(_flushPersist());
    });
  }

  Future<void> _flushPersist() {
    final inFlight = _flushInFlight ??= _doFlushPersist().whenComplete(
      () => _flushInFlight = null,
    );
    return inFlight;
  }

  Future<void> _doFlushPersist() async {
    if (!_persistDirty) return;
    _persistDirty = false;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(
        _noResultArtistsKey,
        jsonEncode(
          _noResultArtists.map((k, v) => MapEntry(k, v.toIso8601String())),
        ),
      );
      await prefs.setString(
        _noResultAlbumsKey,
        jsonEncode(
          _noResultAlbums.map((k, v) => MapEntry(k, v.toIso8601String())),
        ),
      );
    } catch (e) {
      _persistDirty = true;
      debugPrint('PassiveArtFetcher: persist failed: $e');
    }
  }

  static Map<String, DateTime> _decodeNoResults(String? raw) {
    if (raw == null || raw.isEmpty) return {};
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map<String, Object?>) return {};
      final out = <String, DateTime>{};
      for (final entry in decoded.entries) {
        final value = entry.value;
        if (value is String) {
          final at = DateTime.tryParse(value);
          if (at != null) out[entry.key] = at;
        }
      }
      return out;
    } on FormatException catch (e) {
      debugPrint('PassiveArtFetcher: ignoring corrupt no-result cache: $e');
      return {};
    }
  }

  static String _albumKey(String album, String? artist) {
    final cleanAlbum = album.trim().toLowerCase();
    if (cleanAlbum.isEmpty) return '';
    final cleanArtist = artist?.trim().toLowerCase() ?? '';
    if (cleanArtist.isEmpty) return cleanAlbum;
    return '$cleanArtist|$cleanAlbum';
  }

  Future<void> _runPassiveLoop() async {
    while (_isRunning && _isForegrounded) {
      try {
        final ref = _containerRef;
        if (ref == null) break;

        await _drainPriorityQueues();
        if (_isRunning && _isForegrounded) {
          await _sweepLibraryBurst();
        }
      } catch (e) {
        debugPrint('PassiveArtFetcherService error: $e');
      }

      await Future.delayed(const Duration(seconds: 15));
    }
    _isRunning = false;
  }

  /// Immediate fetches for artists/albums the user actually opened. These
  /// bypass neither the art-exists check nor the 404 skip list: only fresh
  /// keys are queued (see fetch*IfNeeded).
  Future<void> _drainPriorityQueues() async {
    while (_priorityArtistQueue.isNotEmpty && _isRunning && _isForegrounded) {
      final artist = _priorityArtistQueue.removeAt(0);
      final lower = artist.toLowerCase();
      if (_inFlightArtists.contains(lower)) continue;
      _inFlightArtists.add(lower);
      try {
        final resolved = await _resolveArtistArt(artist);
        await _applyArtistResolution(artist, resolved);
      } finally {
        _inFlightArtists.remove(lower);
      }
      await Future.delayed(const Duration(milliseconds: 350));
    }

    while (_priorityAlbumQueue.isNotEmpty && _isRunning && _isForegrounded) {
      final item = _priorityAlbumQueue.removeAt(0);
      final album = item['album']!;
      final artist = item['artist']!;
      final key = _albumKey(album, artist.isEmpty ? null : artist);
      if (key.isEmpty || _inFlightAlbums.contains(key)) continue;
      _inFlightAlbums.add(key);
      try {
        final resolved = await _resolveAlbumArt(album, artist);
        await _applyAlbumResolution(album, artist, resolved);
      } finally {
        _inFlightAlbums.remove(key);
      }
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Sorts keys in place by track count (most tracks first), name on ties.
  @visibleForTesting
  static void sortKeysByCount(List<String> keys, Map<String, int> counts) {
    keys.sort((a, b) {
      final byCount = (counts[b] ?? 0).compareTo(counts[a] ?? 0);
      if (byCount != 0) return byCount;
      return a.compareTo(b);
    });
  }

  /// Collects artists/albums still missing art, most-tracks-first.
  MissingArt _collectMissingSorted(
    List<Song> songs,
    ArtistAlbumArtState artState,
  ) {
    final artistCounts = <String, int>{};
    final artistDisplay = <String, String>{};
    for (final song in songs) {
      final split = LibraryLogic.splitArtistNames(song.artist);
      final names = split.isEmpty ? [song.artist] : split;
      for (final name in names) {
        final clean = OnlineMetadataService.cleanTag(name);
        if (clean == null) continue;
        final lower = clean.toLowerCase();
        artistCounts[lower] = (artistCounts[lower] ?? 0) + 1;
        artistDisplay.putIfAbsent(lower, () => clean);
      }
    }

    final albumCounts = <String, int>{};
    final albumDisplay = <String, Map<String, String>>{};
    final albumHasLocalCover = <String, bool>{};
    for (final song in songs) {
      final album = OnlineMetadataService.cleanTag(song.album);
      if (album == null) continue;
      final artist = OnlineMetadataService.cleanTag(song.artist);
      final key = _albumKey(album, artist);
      albumCounts[key] = (albumCounts[key] ?? 0) + 1;
      albumDisplay.putIfAbsent(
        key,
        () => {'album': album, 'artist': artist ?? ''},
      );
      if (song.coverUrl != null && song.coverUrl!.trim().isNotEmpty) {
        albumHasLocalCover[key] = true;
      }
    }

    final artistKeys = artistCounts.keys.where((lower) {
      if (_noResultArtists.containsKey(lower)) return false;
      if (_triedThisLaunchArtists.contains(lower)) return false;
      if (_inFlightArtists.contains(lower)) return false;
      if (artState.getArtistArt(artistDisplay[lower]) != null) return false;
      return true;
    }).toList();
    sortKeysByCount(artistKeys, artistCounts);

    final albumKeys = albumCounts.keys.where((key) {
      if (_noResultAlbums.containsKey(key)) return false;
      if (_triedThisLaunchAlbums.contains(key)) return false;
      if (_inFlightAlbums.contains(key)) return false;
      // Albums with an embedded/local cover already show real art.
      if (albumHasLocalCover[key] == true) return false;
      final item = albumDisplay[key]!;
      final itemArtist = item['artist']!;
      if (artState.getAlbumArt(
            item['album'],
            artistName: itemArtist.isEmpty ? null : itemArtist,
          ) !=
          null) {
        return false;
      }
      return true;
    }).toList();
    sortKeysByCount(albumKeys, albumCounts);

    return (
      artists: [for (final key in artistKeys) artistDisplay[key]!],
      albums: [for (final key in albumKeys) albumDisplay[key]!],
    );
  }

  /// Runs one burst over everything missing, most-tracks-first.
  ///
  /// Loop mode (from [_sweepLibraryBurst]) abandons work when backgrounded;
  /// driven mode (indexer op) waits out backgrounding and only stops on
  /// [isCancelled]. Progress callbacks fire with totals up front, then per
  /// resolved key.
  Future<ArtBurstResult> runArtBurst({
    bool driven = false,
    ArtFetchProgress? onArtistProgress,
    ArtFetchProgress? onAlbumProgress,
    bool Function()? isCancelled,
  }) async {
    bool cancelled() => isCancelled?.call() ?? false;
    bool shouldContinue() {
      if (!_isForegrounded) return false;
      if (cancelled()) return false;
      if (!driven && !_isRunning) return false;
      return true;
    }

    ArtBurstResult finish({
      required int fetchedArtists,
      required int fetchedAlbums,
      required List<String> failedItems,
      required bool offline,
    }) {
      return (
        fetchedArtists: fetchedArtists,
        fetchedAlbums: fetchedAlbums,
        failedItems: failedItems,
        cancelled: cancelled(),
        offline: offline,
      );
    }

    final ref = _containerRef;
    if (ref == null) {
      return finish(
        fetchedArtists: 0,
        fetchedAlbums: 0,
        failedItems: const [],
        offline: false,
      );
    }
    if (_offlineBackoffUntil != null &&
        DateTime.now().isBefore(_offlineBackoffUntil!)) {
      if (driven) {
        // Explicit user action always tries the network; a stale passive
        // backoff must never make a manual fetch report offline.
        _offlineBackoffUntil = null;
      } else {
        return finish(
          fetchedArtists: 0,
          fetchedAlbums: 0,
          failedItems: const [],
          offline: true,
        );
      }
    }
    final List<Song> songs = ref.read(songsProvider).value ?? const <Song>[];
    if (songs.isEmpty) {
      return finish(
        fetchedArtists: 0,
        fetchedAlbums: 0,
        failedItems: const [],
        offline: false,
      );
    }
    final artState = ref.read(artistAlbumArtProvider);
    final missing = _collectMissingSorted(songs, artState);
    onArtistProgress?.call(0, missing.artists.length);
    onAlbumProgress?.call(0, missing.albums.length);
    if (missing.artists.isEmpty && missing.albums.isEmpty) {
      return finish(
        fetchedArtists: 0,
        fetchedAlbums: 0,
        failedItems: const [],
        offline: false,
      );
    }

    var consecutiveTransient = 0;
    bool offlineAbort = false;

    // Counts transient keys. Only a successful socket probe to the API host
    // may set [offlineAbort]: completion order under 20-way concurrency
    // makes "consecutive" meaningless on its own, and server-side failures
    // must never abort the run. Fail-open: any doubt means keep going.
    Future<void> noteOutcome(_FetchOutcome outcome) async {
      if (outcome == _FetchOutcome.transient) {
        consecutiveTransient++;
        if (consecutiveTransient >= _offlineBreakerThreshold && !offlineAbort) {
          final reachable = await _confirmApiReachable();
          if (!reachable) {
            offlineAbort = true;
          } else {
            consecutiveTransient = 0;
          }
        }
      } else if (outcome == _FetchOutcome.success ||
          outcome == _FetchOutcome.notFound) {
        consecutiveTransient = 0;
      }
    }

    var fetchedArtists = 0;
    var fetchedAlbums = 0;
    final failedItems = <String>[];

    // Artists first: biggest collections resolve first.
    var artistDone = 0;
    final artistSaves = <_ArtistSave>[];
    await _runConcurrent(
      missing.artists.map((artist) {
        return () async {
          if (offlineAbort) return;
          final lower = artist.toLowerCase();
          _inFlightArtists.add(lower);
          try {
            final resolved = await _resolveArtistArt(
              artist,
              shouldContinue: shouldContinue,
              waitForForeground: driven,
              isCancelled: cancelled,
            );
            await noteOutcome(resolved.outcome);
            if (resolved.outcome == _FetchOutcome.success &&
                resolved.artistSave != null) {
              artistSaves.add(resolved.artistSave!);
            } else {
              if (resolved.outcome == _FetchOutcome.transient) {
                failedItems.add(artist);
              }
              await _applyArtistResolution(artist, resolved);
            }
          } finally {
            _inFlightArtists.remove(lower);
            artistDone++;
            onArtistProgress?.call(artistDone, missing.artists.length);
          }
        };
      }).toList(),
      _burstConcurrency,
      shouldContinue: shouldContinue,
      waitForForeground: driven,
      isCancelled: cancelled,
    );

    final notifier = ref.read(artistAlbumArtProvider.notifier);
    for (final save in artistSaves) {
      if (offlineAbort) break;
      if (!await _proceed(
        shouldContinue: shouldContinue,
        isCancelled: cancelled,
        waitForForeground: driven,
      )) {
        break;
      }
      if (ref.read(artistAlbumArtProvider).getArtistArt(save.artist) != null) {
        continue;
      }
      try {
        await notifier.setArtistArt(
          artistName: save.artist,
          localPath: save.localPath,
          imageUrl: save.imageUrl,
          source: save.source,
        );
        fetchedArtists++;
      } catch (e) {
        debugPrint('PassiveArtFetcher: save artist art failed: $e');
      }
    }

    if (offlineAbort) {
      _noteOfflineAbort(true);
      return finish(
        fetchedArtists: fetchedArtists,
        fetchedAlbums: fetchedAlbums,
        failedItems: failedItems,
        offline: true,
      );
    }
    if (!await _proceed(
      shouldContinue: shouldContinue,
      isCancelled: cancelled,
      waitForForeground: driven,
    )) {
      return finish(
        fetchedArtists: fetchedArtists,
        fetchedAlbums: fetchedAlbums,
        failedItems: failedItems,
        offline: false,
      );
    }

    var albumDone = 0;
    final albumSaves = <_AlbumSave>[];
    await _runConcurrent(
      missing.albums.map((item) {
        return () async {
          if (offlineAbort) return;
          final album = item['album']!;
          final artist = item['artist']!;
          final key = _albumKey(album, artist.isEmpty ? null : artist);
          _inFlightAlbums.add(key);
          try {
            final resolved = await _resolveAlbumArt(
              album,
              artist,
              shouldContinue: shouldContinue,
              waitForForeground: driven,
              isCancelled: cancelled,
            );
            await noteOutcome(resolved.outcome);
            if (resolved.outcome == _FetchOutcome.success &&
                resolved.albumSave != null) {
              albumSaves.add(resolved.albumSave!);
            } else {
              if (resolved.outcome == _FetchOutcome.transient) {
                failedItems.add(
                  artist.isEmpty ? album : '$album ($artist)',
                );
              }
              await _applyAlbumResolution(album, artist, resolved);
            }
          } finally {
            _inFlightAlbums.remove(key);
            albumDone++;
            onAlbumProgress?.call(albumDone, missing.albums.length);
          }
        };
      }).toList(),
      _burstConcurrency,
      shouldContinue: shouldContinue,
      waitForForeground: driven,
      isCancelled: cancelled,
    );

    for (final save in albumSaves) {
      if (offlineAbort) break;
      if (!await _proceed(
        shouldContinue: shouldContinue,
        isCancelled: cancelled,
        waitForForeground: driven,
      )) {
        break;
      }
      final existing = ref.read(artistAlbumArtProvider).getAlbumArt(
            save.album,
            artistName: save.artist.isEmpty ? null : save.artist,
          );
      if (existing != null) continue;
      try {
        await notifier.setAlbumArt(
          albumKey:
              save.artist.isEmpty ? save.album : '${save.artist}|${save.album}',
          albumName: save.album,
          artistName: save.artist.isEmpty ? null : save.artist,
          localPath: save.localPath,
          imageUrl: save.imageUrl,
          source: save.source,
        );
        fetchedAlbums++;
      } catch (e) {
        debugPrint('PassiveArtFetcher: save album art failed: $e');
      }
    }

    _noteOfflineAbort(offlineAbort);
    return finish(
      fetchedArtists: fetchedArtists,
      fetchedAlbums: fetchedAlbums,
      failedItems: failedItems,
      offline: offlineAbort,
    );
  }

  /// True when work may proceed. Driven mode waits out backgrounding (cancel
  /// still aborts); loop mode returns false immediately.
  Future<bool> _proceed({
    required bool Function() shouldContinue,
    required bool Function() isCancelled,
    required bool waitForForeground,
  }) async {
    if (shouldContinue()) return true;
    if (!waitForForeground || isCancelled()) return false;
    while (!shouldContinue()) {
      if (isCancelled()) return false;
      await Future.delayed(const Duration(milliseconds: 500));
    }
    return true;
  }

  /// Gap between attempts. Driven mode counts foreground time only, so the
  /// 5s retry gap from the spec holds even across backgrounding.
  Future<void> _retryWait({
    required bool waitForForeground,
    required bool Function() isCancelled,
  }) async {
    if (!waitForForeground) {
      await Future.delayed(_retryDelay);
      return;
    }
    var waited = Duration.zero;
    const step = Duration(milliseconds: 250);
    while (waited < _retryDelay) {
      if (isCancelled()) return;
      await Future.delayed(step);
      if (_isForegrounded) waited += step;
    }
  }

  /// Burst sweep over everything missing. Runs on every app open (and picks
  /// up library changes on later loop iterations); keys already resolved,
  /// skipped as 404, or exhausted as transient this launch are filtered out.
  Future<void> _sweepLibraryBurst() async {
    await runArtBurst();
  }

  void _noteOfflineAbort(bool offlineAbort) {
    if (!offlineAbort) return;
    _offlineBackoffUntil = DateTime.now().add(_offlineCooldown);
    debugPrint(
      'PassiveArtFetcher: backing off sweep for ${_offlineCooldown.inMinutes}m '
      'after probe-confirmed connectivity loss',
    );
  }

  /// Shared probe future so 20 concurrent workers hitting the breaker at
  /// once trigger a single socket connect instead of 20.
  Future<bool> _confirmApiReachable() {
    final inFlight = _probeInFlight;
    if (inFlight != null) return inFlight;
    final future = _isApiReachable().whenComplete(() => _probeInFlight = null);
    _probeInFlight = future;
    return future;
  }

  /// True when the API host is reachable. A raw socket connect is used on
  /// purpose: any HTTP response (even 500) proves the device is online, so
  /// only socket/timeout failures count as offline. Fail-open: unexpected
  /// results assume online so server errors never abort a run.
  Future<bool> _isApiReachable() async {
    final probe = probeOverrideForTest;
    if (probe != null) return probe();
    try {
      final uri = Uri.parse(MusicUtilsApiClient.instance.baseUrl);
      final host = uri.host;
      if (host.isEmpty) return true;
      final port = uri.hasPort ? uri.port : (uri.scheme == 'https' ? 443 : 80);
      final socket = await Socket.connect(host, port, timeout: _probeTimeout);
      socket.destroy();
      return true;
    } on SocketException catch (e) {
      debugPrint('PassiveArtFetcher: connectivity probe socket error: $e');
      return false;
    } on TimeoutException catch (e) {
      debugPrint('PassiveArtFetcher: connectivity probe timeout: $e');
      return false;
    } on HandshakeException catch (e) {
      debugPrint('PassiveArtFetcher: connectivity probe TLS error: $e');
      return false;
    } on ArgumentError catch (e) {
      debugPrint('PassiveArtFetcher: connectivity probe bad URL: $e');
      return true;
    }
  }

  Future<void> _runConcurrent(
    List<Future<void> Function()> jobs,
    int maxConcurrent, {
    bool Function()? shouldContinue,
    bool waitForForeground = false,
    bool Function()? isCancelled,
  }) async {
    if (jobs.isEmpty) return;
    bool cont() => shouldContinue?.call() ?? (_isRunning && _isForegrounded);
    bool canc() => isCancelled?.call() ?? false;
    var index = 0;
    Future<void> worker() async {
      while (true) {
        if (!await _proceed(
          shouldContinue: cont,
          isCancelled: canc,
          waitForForeground: waitForForeground,
        )) {
          return;
        }
        final i = index++;
        if (i >= jobs.length) return;
        try {
          await jobs[i]();
        } catch (e) {
          debugPrint('PassiveArtFetcher: burst job failed: $e');
        }
      }
    }

    final workers = maxConcurrent < jobs.length ? maxConcurrent : jobs.length;
    await Future.wait(List.generate(workers, (_) => worker()));
  }

  Future<void> _applyArtistResolution(
    String artist,
    ({_FetchOutcome outcome, _ArtistSave? artistSave}) resolved,
  ) async {
    final lower = artist.toLowerCase();
    switch (resolved.outcome) {
      case _FetchOutcome.success:
        final save = resolved.artistSave;
        if (save == null) return;
        final ref = _containerRef;
        if (ref == null) return;
        try {
          if (ref.read(artistAlbumArtProvider).getArtistArt(artist) != null) {
            return;
          }
          await ref.read(artistAlbumArtProvider.notifier).setArtistArt(
                artistName: save.artist,
                localPath: save.localPath,
                imageUrl: save.imageUrl,
                source: save.source,
              );
        } catch (e) {
          debugPrint('PassiveArtFetcher: save artist art failed: $e');
        }
      case _FetchOutcome.notFound:
        _noResultArtists[lower] = DateTime.now();
        _triedThisLaunchArtists.add(lower);
        _schedulePersist();
      case _FetchOutcome.transient:
        _triedThisLaunchArtists.add(lower);
      case _FetchOutcome.abandoned:
        break;
    }
  }

  Future<void> _applyAlbumResolution(
    String album,
    String artist,
    ({_FetchOutcome outcome, _AlbumSave? albumSave}) resolved,
  ) async {
    final key = _albumKey(album, artist.isEmpty ? null : artist);
    if (key.isEmpty) return;
    switch (resolved.outcome) {
      case _FetchOutcome.success:
        final save = resolved.albumSave;
        if (save == null) return;
        final ref = _containerRef;
        if (ref == null) return;
        try {
          final existing = ref.read(artistAlbumArtProvider).getAlbumArt(
                album,
                artistName: artist.isEmpty ? null : artist,
              );
          if (existing != null) return;
          await ref.read(artistAlbumArtProvider.notifier).setAlbumArt(
                albumKey: artist.isEmpty ? album : '$artist|$album',
                albumName: save.album,
                artistName: save.artist.isEmpty ? null : save.artist,
                localPath: save.localPath,
                imageUrl: save.imageUrl,
                source: save.source,
              );
        } catch (e) {
          debugPrint('PassiveArtFetcher: save album art failed: $e');
        }
      case _FetchOutcome.notFound:
        _noResultAlbums[key] = DateTime.now();
        _triedThisLaunchAlbums.add(key);
        _schedulePersist();
      case _FetchOutcome.transient:
        _triedThisLaunchAlbums.add(key);
      case _FetchOutcome.abandoned:
        break;
    }
  }

  /// Resolves one artist through music-utils (burst-safe) with up to 3
  /// foreground-only attempts. Download failures count as transient: the key
  /// is retried next launch instead of being remembered as a miss.
  Future<({_FetchOutcome outcome, _ArtistSave? artistSave})> _resolveArtistArt(
    String artist, {
    bool Function()? shouldContinue,
    bool waitForForeground = false,
    bool Function()? isCancelled,
  }) async {
    bool cont() => shouldContinue?.call() ?? (_isRunning && _isForegrounded);
    bool canc() => isCancelled?.call() ?? false;
    final ref = _containerRef;
    if (ref == null) {
      return (outcome: _FetchOutcome.abandoned, artistSave: null);
    }
    final onlineService = OnlineMetadataService.instance;

    if (ref.read(artistAlbumArtProvider).getArtistArt(artist) != null) {
      return (outcome: _FetchOutcome.success, artistSave: null);
    }

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      if (!await _proceed(
        shouldContinue: cont,
        isCancelled: canc,
        waitForForeground: waitForForeground,
      )) {
        return (outcome: _FetchOutcome.abandoned, artistSave: null);
      }
      CoverLookupResult lookup;
      try {
        lookup = await onlineService.searchArtistCandidatesUnified(artist);
      } on SocketException catch (e) {
        debugPrint('PassiveArtFetcher: artist lookup socket error: $e');
        lookup = const CoverLookupResult([], CoverLookupOutcome.transient);
      } on TimeoutException catch (e) {
        debugPrint('PassiveArtFetcher: artist lookup timeout: $e');
        lookup = const CoverLookupResult([], CoverLookupOutcome.transient);
      } on HttpException catch (e) {
        debugPrint('PassiveArtFetcher: artist lookup http error: $e');
        lookup = const CoverLookupResult([], CoverLookupOutcome.transient);
      } on FormatException catch (e) {
        debugPrint('PassiveArtFetcher: artist lookup format error: $e');
        lookup = const CoverLookupResult([], CoverLookupOutcome.transient);
      }

      if (lookup.outcome == CoverLookupOutcome.found) {
        for (final candidate in lookup.candidates.take(2)) {
          final imageUrl = candidate['url'];
          if (imageUrl == null || imageUrl.isEmpty) continue;
          final localPath =
              await _downloadCover(imageUrl, 'artist_$artist', cont);
          if (localPath == null || localPath.isEmpty) continue;
          if (ref.read(artistAlbumArtProvider).getArtistArt(artist) != null) {
            return (outcome: _FetchOutcome.success, artistSave: null);
          }
          return (
            outcome: _FetchOutcome.success,
            artistSave: (
              artist: artist,
              localPath: localPath,
              imageUrl: imageUrl,
              source: candidate['source'] ?? 'online',
            ),
          );
        }
      } else if (lookup.outcome == CoverLookupOutcome.notFound) {
        if (attempt >= _maxAttempts) {
          return (outcome: _FetchOutcome.notFound, artistSave: null);
        }
      } else {
        if (attempt >= _maxAttempts) {
          return (outcome: _FetchOutcome.transient, artistSave: null);
        }
      }

      if (attempt < _maxAttempts) {
        await _retryWait(
          waitForForeground: waitForForeground,
          isCancelled: canc,
        );
      }
    }
    return (outcome: _FetchOutcome.transient, artistSave: null);
  }

  /// Resolves one album, mirroring [_resolveArtistArt].
  Future<({_FetchOutcome outcome, _AlbumSave? albumSave})> _resolveAlbumArt(
    String album,
    String artist, {
    bool Function()? shouldContinue,
    bool waitForForeground = false,
    bool Function()? isCancelled,
  }) async {
    bool cont() => shouldContinue?.call() ?? (_isRunning && _isForegrounded);
    bool canc() => isCancelled?.call() ?? false;
    final ref = _containerRef;
    if (ref == null) return (outcome: _FetchOutcome.abandoned, albumSave: null);
    final onlineService = OnlineMetadataService.instance;
    final artistName = artist.isEmpty ? null : artist;

    if (ref
            .read(artistAlbumArtProvider)
            .getAlbumArt(album, artistName: artistName) !=
        null) {
      return (outcome: _FetchOutcome.success, albumSave: null);
    }

    final saveKey = artist.isNotEmpty ? '$artist|$album' : album;

    for (var attempt = 1; attempt <= _maxAttempts; attempt++) {
      if (!await _proceed(
        shouldContinue: cont,
        isCancelled: canc,
        waitForForeground: waitForForeground,
      )) {
        return (outcome: _FetchOutcome.abandoned, albumSave: null);
      }
      CoverLookupResult lookup;
      try {
        lookup = await onlineService.searchAlbumCandidatesUnified(
          album,
          artistName: artistName,
        );
      } on SocketException catch (e) {
        debugPrint('PassiveArtFetcher: album lookup socket error: $e');
        lookup = const CoverLookupResult([], CoverLookupOutcome.transient);
      } on TimeoutException catch (e) {
        debugPrint('PassiveArtFetcher: album lookup timeout: $e');
        lookup = const CoverLookupResult([], CoverLookupOutcome.transient);
      } on HttpException catch (e) {
        debugPrint('PassiveArtFetcher: album lookup http error: $e');
        lookup = const CoverLookupResult([], CoverLookupOutcome.transient);
      } on FormatException catch (e) {
        debugPrint('PassiveArtFetcher: album lookup format error: $e');
        lookup = const CoverLookupResult([], CoverLookupOutcome.transient);
      }

      if (lookup.outcome == CoverLookupOutcome.found) {
        for (final candidate in lookup.candidates.take(2)) {
          final imageUrl = candidate['url'];
          if (imageUrl == null || imageUrl.isEmpty) continue;
          final localPath =
              await _downloadCover(imageUrl, 'album_$saveKey', cont);
          if (localPath == null || localPath.isEmpty) continue;
          if (ref
                  .read(artistAlbumArtProvider)
                  .getAlbumArt(album, artistName: artistName) !=
              null) {
            return (outcome: _FetchOutcome.success, albumSave: null);
          }
          return (
            outcome: _FetchOutcome.success,
            albumSave: (
              album: album,
              artist: artist,
              localPath: localPath,
              imageUrl: imageUrl,
              source: candidate['source'] ?? 'online',
            ),
          );
        }
      } else if (lookup.outcome == CoverLookupOutcome.notFound) {
        if (attempt >= _maxAttempts) {
          return (outcome: _FetchOutcome.notFound, albumSave: null);
        }
      } else {
        if (attempt >= _maxAttempts) {
          return (outcome: _FetchOutcome.transient, albumSave: null);
        }
      }

      if (attempt < _maxAttempts) {
        await _retryWait(
          waitForForeground: waitForForeground,
          isCancelled: canc,
        );
      }
    }
    return (outcome: _FetchOutcome.transient, albumSave: null);
  }

  final List<Completer<void>> _downloadWaiters = [];
  int _activeDownloads = 0;

  /// Bounds concurrent image downloads/decodes; lookups stay on the wide pool.
  Future<String?> _downloadCover(
    String imageUrl,
    String keyName,
    bool Function() shouldContinue,
  ) async {
    while (_activeDownloads >= _downloadConcurrency) {
      if (!shouldContinue()) return null;
      final waiter = Completer<void>();
      _downloadWaiters.add(waiter);
      try {
        await waiter.future.timeout(const Duration(seconds: 5));
      } on TimeoutException catch (_) {
        _downloadWaiters.remove(waiter);
      }
    }
    if (!shouldContinue()) return null;
    _activeDownloads++;
    try {
      return await OnlineMetadataService.instance.downloadAndCacheCover(
        imageUrl,
        keyName,
      );
    } catch (e) {
      debugPrint('PassiveArtFetcher: download failed: $e');
      return null;
    } finally {
      _activeDownloads--;
      if (_downloadWaiters.isNotEmpty) {
        final next = _downloadWaiters.removeAt(0);
        if (!next.isCompleted) next.complete();
      }
    }
  }
}
