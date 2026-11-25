import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;

import '../data/rust/native_command.dart';
import '../domain/models/online_search_result.dart';
import '../domain/services/cover_optimizer.dart';
import '../domain/services/embedded_cover_bytes.dart';
import '../models/song.dart';
import 'music_utils_api_client.dart';
import 'scanner_service.dart';
import 'shared_http_client.dart';

Map<String, dynamic> _core(String action, Map<String, Object?> request) =>
    runCoreCommand('online_meta', {'action': action, ...request});

Map<String, Object?> _resultWire(OnlineSearchResult result) => {
      'title': result.title,
      'artist': result.artist,
      'album': result.album,
      'cover_url': result.coverUrl,
      'source': result.source,
      'duration_ms': result.duration?.inMilliseconds,
    };

OnlineSearchResult _resultFromWire(Map<String, dynamic> row) {
  final millis = (row['duration_ms'] as num?)?.toInt();
  return OnlineSearchResult(
    title: row['title'] as String? ?? '',
    artist: row['artist'] as String? ?? '',
    album: row['album'] as String? ?? '',
    coverUrl: row['cover_url'] as String?,
    source: row['source'] as String? ?? '',
    duration: millis == null ? null : Duration(milliseconds: millis),
  );
}

List<OnlineSearchResult> _resultsFromWire(Object? rows) => [
      for (final row in rows as List? ?? const [])
        _resultFromWire(row as Map<String, dynamic>),
    ];

List<Map<String, String>> _candidateMaps(Object? rows) => [
      for (final row in rows as List? ?? const [])
        {
          'url': (row as Map<String, dynamic>)['url'] as String,
          'source': row['source'] as String,
        },
    ];

/// Client for Deezer & iTunes keyless search APIs.
///
/// Deezer API: ~50 requests per 5s.
/// iTunes API: ~20 requests per minute (soft-cap).
/// music-utils API: ~200 requests per second (supports burst prefetch).
enum CoverLookupOutcome { found, notFound, transient }

class CoverLookupResult {
  final List<Map<String, String>> candidates;
  final CoverLookupOutcome outcome;

  const CoverLookupResult(this.candidates, this.outcome);
}

class OnlineMetadataService {
  /// The collection's own covers, in the page's song order, so the artwork
  /// picker can offer one of them when the online search has nothing.
  static List<Map<String, String>> songCoverCandidates(List<Song> songs) {
    final reply = _core('song_cover_candidates', {
      'songs': [
        for (final song in songs)
          {'cover_url': song.coverUrl, 'title': song.title},
      ],
    });
    return [
      for (final row in reply['candidates'] as List? ?? const [])
        {
          'url': (row as Map<String, dynamic>)['url'] as String,
          'source': row['source'] as String,
        },
    ];
  }

  static final OnlineMetadataService instance =
      OnlineMetadataService._internal();

  OnlineMetadataService._internal();

  factory OnlineMetadataService() => instance;

  static const String _deezerHost = 'api.deezer.com';
  static const String _itunesHost = 'itunes.apple.com';
  static const String _lastfmHost = 'www.last.fm';
  static const Duration _timeout = Duration(seconds: 8);

  final MusicUtilsApiClient _musicUtils = MusicUtilsApiClient.instance;

  static String? _userAgent;

  final Map<String, int> _lastRequests = {};

  // In-memory caches for artwork candidates and query resolutions
  final Map<String, List<Map<String, String>>> _artistCandidatesCache = {};
  final Map<String, List<Map<String, String>>> _albumCandidatesCache = {};
  final Map<String, String> _artistImageCache = {};
  final Map<String, String> _albumImageCache = {};

  static String? cleanTag(String? value) =>
      _core('clean_tag', {'value': value})['value'] as String?;

  /// Cleans titles of extra noise such as "(Official Video)", "ft. Artist", etc.
  static String cleanSearchTitle(String rawTitle, {String? artist}) =>
      _core('clean_search_title', {
        'title': rawTitle,
        'artist': artist,
      })['value'] as String;

  /// Searches both Deezer and iTunes in parallel for [song] or custom query.
  Future<List<OnlineSearchResult>> searchParallelForSong(
    Song song, {
    String? queryOverride,
    String? titleOverride,
    String? artistOverride,
  }) async {
    final rawArtist = cleanTag(artistOverride ?? song.artist) ?? '';
    final rawTitle = cleanTag(titleOverride ?? song.title) ??
        p.basenameWithoutExtension(song.filename);
    final cleanTitle = cleanSearchTitle(rawTitle, artist: rawArtist);

    final query = queryOverride ??
        (rawArtist.isNotEmpty ? '$rawArtist $cleanTitle' : cleanTitle);

    if (query.trim().isEmpty) return const [];

    final unified = await _searchMusicUtilsMetadata(
      query: query,
      title: cleanTitle,
      artist: rawArtist,
    );
    if (unified.isNotEmpty) return unified;

    return _searchDirectForSong(query);
  }

  Future<List<OnlineSearchResult>> _searchDirectForSong(String query) async {
    final results = await Future.wait([
      searchDeezerTrack(query),
      searchITunesTrack(query),
    ]);

    final reply = _core('merge_results', {
      'groups': [
        for (final group in [results[1], results[0]])
          [for (final result in group) _resultWire(result)],
      ],
    });
    return _resultsFromWire(reply['results']);
  }

  Future<List<OnlineSearchResult>> _searchMusicUtilsMetadata({
    required String query,
    required String title,
    required String artist,
  }) async {
    final decoded = await _musicUtils.getJson('/metadata/search', {
      'q': query,
      'limit': '20',
    });
    if (decoded is! List) return const [];
    return _resultsFromWire(
      _core('music_utils_results', {'json': decoded})['results'],
    );
  }

  /// Search Deezer for track
  Future<List<OnlineSearchResult>> searchDeezerTrack(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    final decoded = await _getJson(_deezerHost, '/search', {'q': trimmed});
    return _resultsFromWire(
      _core('deezer_tracks', {'json': decoded})['results'],
    );
  }

  /// Resolves artist artwork through music-utils, then direct providers.
  Future<String?> searchArtistImage(String artistName) async {
    final clean = cleanTag(artistName);
    if (clean == null) return null;
    final cacheKey = clean.toLowerCase();
    final cached = _artistImageCache[cacheKey];
    if (cached != null) return cached;

    final unified = await _musicUtils.getJson('/cover/artist', {
      'artist_name': clean,
    });
    final unifiedUrl = _coverUrlFromResponse(unified);
    if (unifiedUrl != null) {
      if (_artistImageCache.length > 200) _artistImageCache.clear();
      _artistImageCache[cacheKey] = unifiedUrl;
      return unifiedUrl;
    }

    final directUrl = await _searchDirectArtistImage(clean);
    if (directUrl != null) {
      if (_artistImageCache.length > 200) _artistImageCache.clear();
      _artistImageCache[cacheKey] = directUrl;
    }
    return directUrl;
  }

  /// Search Deezer for artist image (direct-provider fallback).
  Future<String?> searchDeezerArtistImage(String artistName) async {
    final clean = cleanTag(artistName);
    if (clean == null) return null;

    final decoded = await _getJson(_deezerHost, '/search/artist', {'q': clean});
    return _core('deezer_image', {
      'json': decoded,
      'kind': 'artist',
    })['url'] as String?;
  }

  /// Returns artist artwork candidates from music-utils, then direct providers.
  Future<List<Map<String, String>>> searchArtistImageCandidates(
    String artistName,
  ) async {
    final clean = cleanTag(artistName);
    if (clean == null) return const [];
    final cacheKey = clean.toLowerCase();
    final cached = _artistCandidatesCache[cacheKey];
    if (cached != null) return cached;

    final unified = await _musicUtils.getJson('/cover/search', {
      'q': clean,
      'type': 'artist',
      'limit': '10',
    });
    final unifiedCandidates = _coverCandidatesFromResponse(unified);
    if (unifiedCandidates.isNotEmpty) {
      if (_artistCandidatesCache.length > 200) _artistCandidatesCache.clear();
      _artistCandidatesCache[cacheKey] = unifiedCandidates;
      return unifiedCandidates;
    }

    final directHits = await Future.wait([
      searchDeezerArtistImage(clean),
      searchITunesArtistImage(clean),
      searchLastfmArtistImage(clean),
    ]);

    final candidates = _distinctCandidates(
      directHits[0],
      directHits[1],
      directHits[2],
    );
    if (_artistCandidatesCache.length > 200) _artistCandidatesCache.clear();
    _artistCandidatesCache[cacheKey] = candidates;
    return candidates;
  }

  /// Resolves album artwork through music-utils, then direct providers.
  Future<String?> searchAlbumImage(
    String albumName, {
    String? artistName,
  }) async {
    final cleanAlbum = cleanTag(albumName);
    if (cleanAlbum == null) return null;
    final cleanArtist = cleanTag(artistName);
    final cacheKey = cleanArtist != null
        ? '${cleanArtist.toLowerCase()}|${cleanAlbum.toLowerCase()}'
        : cleanAlbum.toLowerCase();

    final cached = _albumImageCache[cacheKey];
    if (cached != null) return cached;

    final unified = await _musicUtils.getJson('/cover/album', {
      'album_name': cleanAlbum,
      if (cleanArtist != null) 'artist_name': cleanArtist,
    });
    final unifiedUrl = _coverUrlFromResponse(unified);
    if (unifiedUrl != null) {
      if (_albumImageCache.length > 200) _albumImageCache.clear();
      _albumImageCache[cacheKey] = unifiedUrl;
      return unifiedUrl;
    }

    final directUrl = await _searchDirectAlbumImage(
      cleanAlbum,
      artistName: cleanArtist,
    );
    if (directUrl != null) {
      if (_albumImageCache.length > 200) _albumImageCache.clear();
      _albumImageCache[cacheKey] = directUrl;
    }
    return directUrl;
  }

  /// Search Deezer for album image (direct-provider fallback).
  Future<String?> searchDeezerAlbumImage(
    String albumName, {
    String? artistName,
  }) async {
    final cleanAlbum = cleanTag(albumName);
    if (cleanAlbum == null) return null;
    final cleanArtist = cleanTag(artistName);

    final query = cleanArtist != null ? '$cleanArtist $cleanAlbum' : cleanAlbum;
    final decoded = await _getJson(_deezerHost, '/search/album', {'q': query});
    return _core('deezer_image', {
      'json': decoded,
      'kind': 'album',
    })['url'] as String?;
  }

  /// Search iTunes for track (with rate-limiting pause)
  Future<List<OnlineSearchResult>> searchITunesTrack(String query) async {
    final trimmed = query.trim();
    if (trimmed.isEmpty) return const [];

    await _enforceITunesRateLimit();

    final decoded = await _getJson(_itunesHost, '/search', {
      'term': trimmed,
      'entity': 'song',
      'limit': '10',
    });

    return _resultsFromWire(
      _core('itunes_tracks', {'json': decoded})['results'],
    );
  }

  /// Search iTunes for artist image (fetches top album or artist entity artwork)
  Future<String?> searchITunesArtistImage(String artistName) async {
    final clean = cleanTag(artistName);
    if (clean == null) return null;

    await _enforceITunesRateLimit();

    final decoded = await _getJson(_itunesHost, '/search', {
      'term': clean,
      'entity': 'album',
      'limit': '5',
    });

    return _core('itunes_image', {'json': decoded})['url'] as String?;
  }

  /// Search iTunes for album image
  Future<String?> searchITunesAlbumImage(
    String albumName, {
    String? artistName,
  }) async {
    final cleanAlbum = cleanTag(albumName);
    if (cleanAlbum == null) return null;
    final cleanArtist = cleanTag(artistName);

    await _enforceITunesRateLimit();

    final query = cleanArtist != null ? '$cleanArtist $cleanAlbum' : cleanAlbum;
    final decoded = await _getJson(_itunesHost, '/search', {
      'term': query,
      'entity': 'album',
      'limit': '5',
    });

    return _core('itunes_image', {'json': decoded})['url'] as String?;
  }

  Future<String?> _searchDirectArtistImage(String artistName) =>
      _searchDirectImage(
        itunes: () => searchITunesArtistImage(artistName),
        deezer: () => searchDeezerArtistImage(artistName),
        lastfm: () => searchLastfmArtistImage(artistName),
      );

  Future<String?> _searchDirectAlbumImage(String albumName,
          {String? artistName}) =>
      _searchDirectImage(
        itunes: () => searchITunesAlbumImage(albumName, artistName: artistName),
        deezer: () => searchDeezerAlbumImage(albumName, artistName: artistName),
        lastfm: () => searchLastfmAlbumImage(albumName, artistName: artistName),
      );

  Future<String?> _searchDirectImage({
    required Future<String?> Function() itunes,
    required Future<String?> Function() deezer,
    required Future<String?> Function() lastfm,
  }) async {
    final plan = _core('direct_art_providers', const {});
    final providers = (plan['providers'] as List).cast<String>();
    for (final provider in providers) {
      final image = await switch (provider) {
        'itunes' => itunes(),
        'deezer' => deezer(),
        'lastfm' => lastfm(),
        _ => throw StateError('Unknown artwork provider: $provider'),
      };
      if (image != null && (image.isNotEmpty || provider == providers.last)) {
        return image;
      }
    }
    return null;
  }

  /// Searches artist artwork directly through Last.fm (fallback provider).
  Future<String?> searchLastfmArtistImage(String artistName) async {
    final clean = cleanTag(artistName);
    if (clean == null) return null;
    final encoded = Uri.encodeComponent(clean).replaceAll('%20', '+');
    // The artist page carries an og:image meta tag in the common case; the
    // images gallery is a heavier page, so fetch it only when needed.
    final mainResult = await _searchLastfmPage('/music/$encoded');
    if (mainResult != null && mainResult.isNotEmpty) {
      return mainResult;
    }
    return _searchLastfmPage('/music/$encoded/+images');
  }

  /// Searches Last.fm directly for an album cover (fallback only).
  Future<String?> searchLastfmAlbumImage(
    String albumName, {
    String? artistName,
  }) async {
    final cleanAlbum = cleanTag(albumName);
    if (cleanAlbum == null) return null;
    final cleanArtist = cleanTag(artistName);
    if (cleanArtist == null) return null;
    final encodedAlbum = Uri.encodeComponent(cleanAlbum).replaceAll('%20', '+');
    final encodedArtist =
        Uri.encodeComponent(cleanArtist).replaceAll('%20', '+');
    final mainResult = await _searchLastfmPage(
      '/music/$encodedArtist/$encodedAlbum',
    );
    if (mainResult != null && mainResult.isNotEmpty) {
      return mainResult;
    }
    return _searchLastfmPage('/music/$encodedArtist/$encodedAlbum/+images');
  }

  /// Returns album artwork candidates from music-utils, then direct providers.
  Future<List<Map<String, String>>> searchAlbumImageCandidates(
    String albumName, {
    String? artistName,
  }) async {
    final cleanAlbum = cleanTag(albumName);
    if (cleanAlbum == null) return const [];
    final cleanArtist = cleanTag(artistName);
    final cacheKey = cleanArtist != null
        ? '${cleanArtist.toLowerCase()}|${cleanAlbum.toLowerCase()}'
        : cleanAlbum.toLowerCase();

    final cached = _albumCandidatesCache[cacheKey];
    if (cached != null) return cached;

    final unified = await _musicUtils.getJson('/cover/search', {
      'type': 'album',
      'album_name': cleanAlbum,
      if (cleanArtist != null) 'artist_name': cleanArtist,
      'limit': '10',
    });
    final unifiedCandidates = _coverCandidatesFromResponse(unified);
    if (unifiedCandidates.isNotEmpty) {
      if (_albumCandidatesCache.length > 200) _albumCandidatesCache.clear();
      _albumCandidatesCache[cacheKey] = unifiedCandidates;
      return unifiedCandidates;
    }

    final directHits = await Future.wait([
      searchDeezerAlbumImage(cleanAlbum, artistName: cleanArtist),
      searchITunesAlbumImage(cleanAlbum, artistName: cleanArtist),
      searchLastfmAlbumImage(cleanAlbum, artistName: cleanArtist),
    ]);

    final candidates = _distinctCandidates(
      directHits[0],
      directHits[1],
      directHits[2],
    );
    if (_albumCandidatesCache.length > 200) _albumCandidatesCache.clear();
    _albumCandidatesCache[cacheKey] = candidates;
    return candidates;
  }

  /// music-utils-only artist lookup for burst prefetch. Never touches the
  /// slow direct providers, so it is safe to run with high concurrency.
  /// Empty success and explicit 404 both map to [CoverLookupOutcome.notFound];
  /// timeouts, sockets and 5xx map to [CoverLookupOutcome.transient].
  Future<CoverLookupResult> searchArtistCandidatesUnified(
    String artistName,
  ) async {
    final clean = cleanTag(artistName);
    if (clean == null) {
      return const CoverLookupResult([], CoverLookupOutcome.notFound);
    }
    final cacheKey = clean.toLowerCase();
    final cached = _artistCandidatesCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return CoverLookupResult(cached, CoverLookupOutcome.found);
    }

    final unified = await _musicUtils.getJsonResult('/cover/search', {
      'q': clean,
      'type': 'artist',
      'limit': '10',
    });
    if (unified.status == MusicUtilsStatus.transient) {
      return const CoverLookupResult([], CoverLookupOutcome.transient);
    }
    final candidates = _coverCandidatesFromResponse(unified.json);
    if (candidates.isEmpty) {
      return const CoverLookupResult([], CoverLookupOutcome.notFound);
    }
    if (_artistCandidatesCache.length > 200) _artistCandidatesCache.clear();
    _artistCandidatesCache[cacheKey] = candidates;
    return CoverLookupResult(candidates, CoverLookupOutcome.found);
  }

  /// music-utils-only album lookup for burst prefetch, mirroring
  /// [searchArtistCandidatesUnified].
  Future<CoverLookupResult> searchAlbumCandidatesUnified(
    String albumName, {
    String? artistName,
  }) async {
    final cleanAlbum = cleanTag(albumName);
    if (cleanAlbum == null) {
      return const CoverLookupResult([], CoverLookupOutcome.notFound);
    }
    final cleanArtist = cleanTag(artistName);
    final cacheKey = cleanArtist != null
        ? '${cleanArtist.toLowerCase()}|${cleanAlbum.toLowerCase()}'
        : cleanAlbum.toLowerCase();
    final cached = _albumCandidatesCache[cacheKey];
    if (cached != null && cached.isNotEmpty) {
      return CoverLookupResult(cached, CoverLookupOutcome.found);
    }

    final unified = await _musicUtils.getJsonResult('/cover/search', {
      'type': 'album',
      'album_name': cleanAlbum,
      if (cleanArtist != null) 'artist_name': cleanArtist,
      'limit': '10',
    });
    if (unified.status == MusicUtilsStatus.transient) {
      return const CoverLookupResult([], CoverLookupOutcome.transient);
    }
    final candidates = _coverCandidatesFromResponse(unified.json);
    if (candidates.isEmpty) {
      return const CoverLookupResult([], CoverLookupOutcome.notFound);
    }
    if (_albumCandidatesCache.length > 200) _albumCandidatesCache.clear();
    _albumCandidatesCache[cacheKey] = candidates;
    return CoverLookupResult(candidates, CoverLookupOutcome.found);
  }

  String? _coverUrlFromResponse(Object? decoded) {
    final candidates = _coverCandidatesFromResponse(decoded);
    return candidates.isEmpty ? null : candidates.first['url'];
  }

  List<Map<String, String>> _coverCandidatesFromResponse(Object? decoded) {
    final reply = _core('cover_candidates', {'json': decoded});
    return _candidateMaps(reply['candidates']);
  }

  /// Deezer, iTunes and Last.fm in priority order, without repeats.
  List<Map<String, String>> _distinctCandidates(
    String? deezer,
    String? itunes,
    String? lastfm,
  ) {
    final reply = _core('candidates', {
      'entries': [
        if (deezer != null) {'url': deezer, 'source': 'Deezer'},
        if (itunes != null) {'url': itunes, 'source': 'iTunes'},
        if (lastfm != null) {'url': lastfm, 'source': 'Last.fm'},
      ],
    });
    return _candidateMaps(reply['candidates']);
  }

  /// Fetches a Last.fm page and extracts the best image URL from its HTML.
  /// Tries GIF image, then og:image meta tag, then any avatar image.
  Future<String?> _searchLastfmPage(String path) async {
    await _pace('lastfm', path: path);

    final client = SharedHttpClient.instance;
    try {
      final uri = Uri.https(_lastfmHost, path);
      final request =
          await SharedHttpClient.openUrl(client, uri, timeout: _timeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        await _resolveUserAgent(),
      );

      final response =
          await SharedHttpClient.awaitResponse(request, timeout: _timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }

      final html = await SharedHttpClient.readUtf8(
        response,
        request: request,
        timeout: _timeout,
      );
      return _extractLastfmImageUrl(html);
    } catch (e) {
      debugPrint('Last.fm scrape error for $path: $e');
      return null;
    }
  }

  /// Runs the ordered rules against [html] and validates the result.
  String? _extractLastfmImageUrl(String html) =>
      _core('lastfm_image', {'html': html})['url'] as String?;

  Future<void> _enforceITunesRateLimit() => _pace('itunes');

  Future<void> _pace(String provider, {String path = ''}) async {
    final plan = runCoreCommand('provider_requests', {
      'op': 'pace',
      'provider': provider,
      'path': path,
      'now_ms': DateTime.now().millisecondsSinceEpoch,
      'last_ms': _lastRequests[provider],
    });
    final previous = _lastRequests[provider] ?? 0;
    final start = plan['start_ms'] as int;
    if (start >= previous) _lastRequests[provider] = start;
    final delay = plan['delay_ms'] as int;
    if (delay > 0) await Future<void>.delayed(Duration(milliseconds: delay));
  }

  /// Downloads cover art from [imageUrl] and saves it locally in extracted covers directory.
  Future<String?> downloadAndCacheCover(String imageUrl, String keyName) async {
    final client = SharedHttpClient.instance;
    try {
      final uri = Uri.parse(imageUrl);
      final request =
          await SharedHttpClient.openUrl(client, uri, timeout: _timeout);
      request.headers.set(
        HttpHeaders.userAgentHeader,
        await _resolveUserAgent(),
      );

      final response =
          await SharedHttpClient.awaitResponse(request, timeout: _timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }

      final bytesBuilder = BytesBuilder();
      try {
        await for (final chunk in response.timeout(_timeout)) {
          bytesBuilder.add(chunk);
        }
      } on Object {
        // A body that stopped arriving holds the connection; release it.
        SharedHttpClient.abort(request);
        rethrow;
      }
      final bytes = bytesBuilder.takeBytes();
      if (bytes.isEmpty) return null;

      // A CDN that answers 200 with a placeholder, a rate-limit notice or an
      // HTML error page would otherwise be cached as a cover: the path gets
      // saved, the tile shows nothing, and the key is treated as done. Anything
      // without an image signature is a failure worth reporting as one, so the
      // caller can try the next candidate.
      if (!hasImageSignature(bytes)) {
        debugPrint(
          'Rejected non-image cover payload from $imageUrl (${bytes.length} bytes)',
        );
        return null;
      }

      final coversDir = await ScannerService.coversDirectory();
      return await CoverOptimizer.saveOptimizedCover(
        bytes,
        coversDir.path,
        fallbackExtension: '.jpg',
      );
    } catch (e) {
      debugPrint('Error downloading cover from $imageUrl: $e');
      return null;
    }
  }

  Future<Object?> _getJson(
    String host,
    String path,
    Map<String, String> params,
  ) async {
    final client = SharedHttpClient.instance;
    try {
      final uri = Uri.https(host, path, params);
      final request =
          await SharedHttpClient.openUrl(client, uri, timeout: _timeout);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.headers.set(
        HttpHeaders.userAgentHeader,
        await _resolveUserAgent(),
      );

      final response =
          await SharedHttpClient.awaitResponse(request, timeout: _timeout);
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }

      final body = await SharedHttpClient.readUtf8(
        response,
        request: request,
        timeout: _timeout,
      );
      return jsonDecode(body);
    } catch (e) {
      debugPrint('OnlineMetadataService GET $path error: $e');
      return null;
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
    } catch (_) {}

    return _userAgent = 'Wispie/$version (https://github.com/sillygru/wispie)';
  }
}
