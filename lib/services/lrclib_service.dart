import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../domain/models/lrclib_result.dart';
import '../domain/models/rich_lyrics.dart';
import '../domain/services/lrclib_match.dart';
import '../domain/services/lrclib_query.dart';
import '../models/song.dart';
import 'cache_service.dart';
import 'music_utils_api_client.dart';

/// Lyrics client with music-utils as the primary API and direct LRCLIB as a
/// fallback.
class LrclibService {
  static const String _host = 'lrclib.net';
  static const Duration _timeout = Duration(seconds: 8);

  static String? _userAgent;
  final MusicUtilsApiClient _musicUtils = MusicUtilsApiClient.instance;

  static const _placeholderTags = {
    'unknown title',
    'unknown artist',
    'unknown album',
  };

  static String? cleanTag(String? value) {
    final v = value?.trim() ?? '';
    if (v.isEmpty || _placeholderTags.contains(v.toLowerCase())) return null;
    return v;
  }

  Future<List<LrclibResult>> findFor(
    Song song, {
    String? titleOverride,
    String? artistOverride,
    bool preferPlain = false,
  }) async {
    final artist = cleanTag(artistOverride ?? song.artist) ?? '';
    final album = cleanTag(song.album);
    final rawTitle = cleanTag(titleOverride ?? song.title) ?? '';
    final title = cleanSearchTitle(rawTitle, artist: artist);
    if (title.isEmpty && artist.isEmpty) return const [];

    final exactFuture = getExact(
      trackName: title,
      artistName: artist,
      albumName: album,
      duration: song.duration,
    );
    final searchFuture = search(trackName: title, artistName: artist);
    final exact = await exactFuture;
    var found = await searchFuture;
    if (found.isEmpty) {
      found = await searchFreeText(
        [title, artist].where((s) => s.isNotEmpty).join(' '),
      );
    }

    final merged = <int, LrclibResult>{};
    if (exact != null) merged[exact.id] = exact;
    for (final result in found) {
      merged.putIfAbsent(result.id, () => result);
    }

    return rankLrclibResults(
      merged.values.toList(),
      song,
      preferPlain: preferPlain,
    );
  }

  Map<String, String> _getParams({
    required String trackName,
    required String artistName,
    String? albumName,
    Duration? duration,
    String? videoId,
  }) {
    return {
      'track_name': trackName,
      'artist_name': artistName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
      if (duration != null) 'duration': '${duration.inSeconds}',
      if (videoId != null && videoId.isNotEmpty) 'video_id': videoId,
      'include_rich_sync': 'true',
      'sync_type': 'richsync',
    };
  }

  /// music-utils `/api/lyrics/get`, with direct LRCLIB fallback.
  ///
  /// A [videoId] pins the exact recording, which matters for streamed tracks:
  /// their artist tag is often the channel name ("Dan Music" for an Eminem
  /// upload), so the tag-based lookup alone misses. The lookup is repeated
  /// without the id when the service has nothing for it.
  Future<LrclibResult?> getExact({
    required String trackName,
    required String artistName,
    String? albumName,
    Duration? duration,
    String? videoId,
  }) async {
    if (trackName.isEmpty || artistName.isEmpty) return null;

    if (videoId != null && videoId.isNotEmpty) {
      final byVideo = _resultFromObject(
        await _musicUtils.getJson(
          '/lyrics/get',
          _getParams(
            trackName: trackName,
            artistName: artistName,
            albumName: albumName,
            duration: duration,
            videoId: videoId,
          ),
        ),
      );
      if (byVideo != null) return byVideo;
    }

    final unified = await _musicUtils.getJson(
      '/lyrics/get',
      _getParams(
        trackName: trackName,
        artistName: artistName,
        albumName: albumName,
        duration: duration,
      ),
    );
    final unifiedResult = _resultFromObject(unified);
    if (unifiedResult != null) return unifiedResult;

    return _getExactDirect(
      trackName: trackName,
      artistName: artistName,
      albumName: albumName,
      duration: duration,
    );
  }

  /// Lyrics this app already chose for [song], or null.
  ///
  /// Streamed tracks have no file to write tags into, so the chosen lyrics are
  /// kept in the cache directory instead. Keyed on the filename, which is the
  /// durable identity of a remote track.
  Future<String?> cachedForSong(Song song) async {
    try {
      final file = await _cacheFileFor(song);
      if (!await file.exists()) return null;
      final text = await file.readAsString();
      return text.trim().isEmpty ? null : text;
    } on Object {
      return null;
    }
  }

  /// Persists chosen lyrics for a streamed track.
  Future<void> saveForSong(Song song, String lyrics) async {
    final file = await _cacheFileFor(song);
    await file.parent.create(recursive: true);
    await file.writeAsString(lyrics);
  }

  Future<File> _cacheFileFor(Song song) async {
    final digest = sha1.convert(utf8.encode(song.filename)).toString();
    final base = await CacheService.instance.getV3File('lyrics_cache');
    return File(p.join(base.parent.path, 'lyrics_cache', 'remote_$digest.lrc'));
  }

  /// Best online lyrics for a streamed track, which has no file to read them
  /// from.
  ///
  /// The chain narrows from exact to loose because a catalogue track's tags are
  /// frequently the uploader's, not the release's. A video-id hit is not
  /// automatically the winner: it is often a transcript with no timings, which
  /// would throw away the synced view, so a timed record from a later tier
  /// outranks it and the untimed hit is only the last resort.
  Future<LrclibResult?> fetchForSong(Song song) async {
    final rawTitle = cleanTag(song.title);
    final artistName = cleanTag(song.artist);
    if (rawTitle == null) return null;
    final trackName = cleanSearchTitle(rawTitle, artist: artistName ?? '');
    if (trackName.isEmpty) return null;

    bool timed(LrclibResult? result) =>
        result != null && (result.hasSynced || result.hasRichSync);

    LrclibResult? videoResult;
    final videoId = song.isYoutube ? song.remoteId : null;
    if (videoId != null && videoId.isNotEmpty && artistName != null) {
      videoResult = _resultFromObject(
        await _musicUtils.getJson(
          '/lyrics/get',
          _getParams(
            trackName: trackName,
            artistName: artistName,
            albumName: cleanTag(song.album),
            duration: song.duration,
            videoId: videoId,
          ),
        ),
      );
      if (timed(videoResult)) return videoResult;
    }

    final byTags = artistName == null
        ? null
        : await getExact(
            trackName: trackName,
            artistName: artistName,
            albumName: cleanTag(song.album),
            duration: song.duration,
          );
    if (timed(byTags)) return byTags;

    final found = await searchFreeText(trackName);
    if (found.isNotEmpty) {
      final ranked = rankLrclibResults(found, song);
      final synced = ranked.where((r) => r.hasSynced || r.hasRichSync);
      if (synced.isNotEmpty) return synced.first;
      if (ranked.isNotEmpty) return ranked.first;
    }

    return videoResult ?? byTags;
  }

  /// Fetches the optional word/syllable payload without replacing local lyrics.
  /// A missing rich result is normal: callers should keep line-synced lyrics.
  Future<RichLyrics?> getRichSync(Song song) {
    // Every lyrics view builds its own service, so the cache is static: the
    // sidebar and the player screen must agree, and a transient failure in one
    // must not leave the other showing "no lyrics".
    final key = song.filename;
    final cached = _richSyncCache[key];
    if (cached != null) return cached;
    final future = _fetchRichSync(song);
    _richSyncCache[key] = future;
    future.then((value) {
      if (value == null) _richSyncCache.remove(key);
    }, onError: (_) {
      _richSyncCache.remove(key);
    });
    return future;
  }

  static final Map<String, Future<RichLyrics?>> _richSyncCache = {};

  Future<RichLyrics?> _fetchRichSync(Song song) async {
    final trackName = cleanTag(song.title);
    final artistName = cleanTag(song.artist);
    if (trackName == null || artistName == null) return null;

    final params = _getParams(
      trackName: cleanSearchTitle(trackName, artist: artistName),
      artistName: artistName,
      albumName: cleanTag(song.album),
      duration: song.duration,
    );
    final videoId = song.isYoutube ? song.remoteId : null;
    if (videoId != null && videoId.isNotEmpty) {
      final byVideo = _resultFromObject(
        await _musicUtils.getJson(
          '/lyrics/get',
          {...params, 'video_id': videoId},
        ),
      );
      if (byVideo?.richLyrics != null) return byVideo!.richLyrics;
    }

    final decoded = await _musicUtils.getJson('/lyrics/get', params);
    final result = _resultFromObject(decoded);
    return result?.richLyrics;
  }

  /// music-utils `/api/lyrics/search`, with direct LRCLIB fallback.
  Future<List<LrclibResult>> search({
    required String trackName,
    String? artistName,
    String? albumName,
  }) async {
    if (trackName.isEmpty) return const [];

    final unified = await _musicUtils.getJson('/lyrics/search', {
      'track_name': trackName,
      if (artistName != null && artistName.isNotEmpty)
        'artist_name': artistName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
      'limit': '20',
      'include_rich_sync': 'true',
      'sync_type': 'richsync',
    });
    final unifiedResults = _resultsFromObject(unified);
    if (unifiedResults.isNotEmpty) return unifiedResults;

    return _searchDirect({
      'track_name': trackName,
      if (artistName != null && artistName.isNotEmpty)
        'artist_name': artistName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
    });
  }

  /// music-utils free-text lyrics search, with direct LRCLIB fallback.
  Future<List<LrclibResult>> searchFreeText(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final unified = await _musicUtils.getJson('/lyrics/search', {
      'q': trimmed,
      'limit': '20',
      'include_rich_sync': 'true',
      'sync_type': 'richsync',
    });
    final unifiedResults = _resultsFromObject(unified);
    if (unifiedResults.isNotEmpty) return unifiedResults;

    return _searchDirect({'q': trimmed});
  }

  LrclibResult? _resultFromObject(Object? decoded) {
    if (decoded is! Map<String, dynamic>) return null;
    final result = LrclibResult.fromJson(decoded);
    return result.isUsable ? result : null;
  }

  List<LrclibResult> _resultsFromObject(Object? decoded) {
    if (decoded is! List) return const [];
    final results = <LrclibResult>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final result = LrclibResult.fromJson(entry);
      if (result.isUsable) results.add(result);
    }
    return results;
  }

  Future<LrclibResult?> _getExactDirect({
    required String trackName,
    required String artistName,
    String? albumName,
    Duration? duration,
  }) async {
    final decoded = await _getJson('/api/get', {
      'track_name': trackName,
      'artist_name': artistName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
      if (duration != null) 'duration': '${duration.inSeconds}',
    });
    if (decoded is! Map<String, dynamic>) return null;
    final result = LrclibResult.fromJson(decoded);
    return result.isUsable ? result : null;
  }

  Future<List<LrclibResult>> _searchDirect(Map<String, String> params) async {
    final decoded = await _getJson('/api/search', params);
    if (decoded is! List) return const [];

    final results = <LrclibResult>[];
    for (final entry in decoded) {
      if (entry is! Map<String, dynamic>) continue;
      final result = LrclibResult.fromJson(entry);
      if (result.isUsable) results.add(result);
    }
    return results;
  }

  Future<Object?> _getJson(String path, Map<String, String> params) async {
    final client = HttpClient();
    try {
      final uri = Uri.https(_host, path, params);
      final request = await client.getUrl(uri);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        await _resolveUserAgent(),
      );

      final response = await request.close().timeout(_timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }

      final body =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      return jsonDecode(body);
    } on SocketException catch (_) {
      return null;
    } on TimeoutException catch (_) {
      return null;
    } on HttpException catch (_) {
      return null;
    } on FormatException catch (_) {
      return null;
    } finally {
      client.close(force: true);
    }
  }

  static Future<String> _resolveUserAgent() async {
    final cached = _userAgent;
    if (cached != null) return cached;

    var version = 'dev';
    try {
      final info =
          await PackageInfo.fromPlatform().timeout(const Duration(seconds: 2));
      if (info.version.isNotEmpty) version = info.version;
    } on Object catch (_) {}

    return _userAgent = 'Wispie/$version (https://github.com/sillygru/wispie)';
  }
}
