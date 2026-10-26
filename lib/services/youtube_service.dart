// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'shared_http_client.dart';

/// One search hit from YouTube.
class YouTubeVideo {
  final String id;
  final String title;
  final String artist;
  final Duration? duration;

  const YouTubeVideo({
    required this.id,
    required this.title,
    required this.artist,
    this.duration,
  });

  String get thumbnailUrl => 'https://i.ytimg.com/vi/$id/mqdefault.jpg';
}

/// A resolved audio rendition. [expiresAt] is derived from the signed URL's own
/// `expire` parameter, so callers never hold a URL past the point YouTube
/// accepts it.
class YouTubeAudioStream {
  final Uri url;
  final String mimeType;
  final String itag;
  final int? contentLength;
  final DateTime expiresAt;

  const YouTubeAudioStream({
    required this.url,
    required this.mimeType,
    required this.itag,
    required this.contentLength,
    required this.expiresAt,
  });

  String get containerExtension =>
      mimeType.startsWith('audio/webm') ? 'webm' : 'm4a';

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

class YouTubeVideoStream {
  final Uri url;
  final String mimeType;
  final DateTime expiresAt;

  const YouTubeVideoStream({
    required this.url,
    required this.mimeType,
    required this.expiresAt,
  });
}

enum YouTubeErrorKind {
  network,
  rateLimited,
  unavailable,
  blocked,
  invalidResponse,
  other,
}

class YouTubeApiException implements Exception {
  final String message;
  final YouTubeErrorKind kind;
  final int? statusCode;

  const YouTubeApiException(
    this.message, {
    this.kind = YouTubeErrorKind.other,
    this.statusCode,
  });

  @override
  String toString() => 'YouTubeApiException: $message';
}

/// Minimal InnerTube client: search and player, with the client rotation every
/// current open-source implementation needs.
///
/// YouTube does not publish a streaming API. Each request therefore presents a
/// real client profile (Android VR, iOS, Android, TV, web) and the app takes
/// whichever profile answers with a direct audio URL. Profiles drift: YouTube
/// enforces attestation on some of them and starts returning 403s, so a failure
/// rotates the profile instead of failing the track, and the one that worked is
/// tried first next time.
class YouTubeService {
  YouTubeService({HttpClient? client})
      : _client = client ?? SharedHttpClient.instance;

  static final YouTubeService instance = YouTubeService();

  static const String _host = 'www.youtube.com';
  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxCachedSearches = 24;
  static const Duration _searchTtl = Duration(minutes: 10);

  /// The player endpoint is much cheaper than Audius streaming, but a burst of
  /// one request per queue row still reads as a scraper. Three keeps a search
  /// result responsive without ever hammering the endpoint.
  static const int _maxConcurrentRequests = 3;
  static const Duration _rateLimitCooldown = Duration(minutes: 1);
  static const Duration _profilePenalty = Duration(minutes: 10);

  /// Users behind a blocked IP can point a build at an Invidious or Piped
  /// instance: `--dart-define=YOUTUBE_RESOLVER_URL=https://invidious.example`.
  static const String _resolverBase =
      String.fromEnvironment('YOUTUBE_RESOLVER_URL');

  /// AAC first: every platform decoder handles it, including iOS and mpv.
  static const List<String> _audioPreference = [
    '140',
    '139',
    '251',
    '250',
    '249'
  ];

  /// Ordered by what actually serves a playable URL, measured live: ANDROID
  /// returns the muxed rendition while the others are mostly login-gated, so
  /// putting a gated client first would spend a failed request per track.
  static const List<_ClientProfile> _profiles = [
    _ClientProfile(
      name: 'ANDROID',
      headerId: 3,
      version: '21.26.364',
      androidSdk: 30,
      userAgent:
          'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip',
      device: {'osName': 'Android', 'osVersion': '11'},
    ),
    _ClientProfile(
      name: 'ANDROID_VR',
      headerId: 28,
      version: '1.65.10',
      androidSdk: 32,
      userAgent:
          'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
      device: {
        'osName': 'Android',
        'osVersion': '12L',
        'deviceMake': 'Oculus',
        'deviceModel': 'Quest 3',
      },
    ),
    _ClientProfile(
      name: 'IOS',
      headerId: 5,
      version: '21.26.4',
      userAgent:
          'com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
      device: {
        'osName': 'iPhone',
        'osVersion': '18.3.2.22D82',
        'deviceMake': 'Apple',
        'deviceModel': 'iPhone16,2',
      },
    ),
    _ClientProfile(
      name: 'TVHTML5',
      headerId: 7,
      version: '7.20260707.07.00',
      userAgent:
          'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/29.0-29.prod (unlike Gecko) v8/8.8.278.8-jit gles Starboard/17.0',
      device: {'osName': 'Cobalt', 'osVersion': '29.0'},
    ),
  ];

  static const _ClientProfile _webProfile = _ClientProfile(
    name: 'WEB',
    headerId: 1,
    version: '2.20260707.12.00',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
  );

  final HttpClient _client;

  final LinkedHashMap<String, _CachedSearch> _searchCache =
      LinkedHashMap<String, _CachedSearch>();
  final Map<String, YouTubeAudioStream> _audioCache = {};
  final Map<String, YouTubeVideoStream> _videoCache = {};
  final Map<int, DateTime> _profileBlockedUntil = {};

  int _preferredProfile = 0;
  int _activeRequests = 0;
  final Queue<Completer<void>> _waiters = Queue<Completer<void>>();
  DateTime? _cooldownUntil;

  /// True while every profile is cooling down, so the UI can say "wait" instead
  /// of blaming the connection.
  bool get isRateLimited =>
      _cooldownUntil != null && DateTime.now().isBefore(_cooldownUntil!);

  Future<List<YouTubeVideo>> search(String query, {int limit = 25}) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final cached = _searchCache.remove(normalized);
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      _searchCache[normalized] = cached;
      return cached.videos;
    }

    Map<String, dynamic> json;
    try {
      json = await _postJson(
        'search',
        {'query': normalized, 'context': _contextFor(_webProfile)},
        profile: _webProfile,
      );
    } on YouTubeApiException catch (error) {
      if (error.kind == YouTubeErrorKind.rateLimited) rethrow;
      // The web client is the one that usually answers search; when it is
      // gated, the app client returns the same renderer tree.
      json = await _postJson(
        'search',
        {'query': normalized, 'context': _contextFor(_searchFallbackProfile)},
        profile: _searchFallbackProfile,
      );
    }

    final videos = <YouTubeVideo>[];
    final seen = <String>{};
    _collectVideos(json, videos, seen, limit);
    final result = List<YouTubeVideo>.unmodifiable(videos);
    _searchCache[normalized] = _CachedSearch(
      videos: result,
      expiresAt: DateTime.now().add(_searchTtl),
    );
    while (_searchCache.length > _maxCachedSearches) {
      _searchCache.remove(_searchCache.keys.first);
    }
    return result;
  }

  /// Resolves the best audio-only rendition for [videoId].
  Future<YouTubeAudioStream> resolveAudioStream(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) {
      throw const YouTubeApiException('YouTube video ID is missing.');
    }

    final cached = _audioCache[id];
    if (cached != null && !cached.isExpired) return cached;

    final resolved = await _withRequestSlot(() => _resolveAudio(id));
    _audioCache[id] = resolved;
    _pruneAudioCache();
    return resolved;
  }

  /// Video-only rendition for the player's video pane. Deliberately never
  /// cached on disk: it is decoded in RAM and dropped when the pane closes.
  Future<YouTubeVideoStream> resolveVideoStream(String videoId) async {
    final id = videoId.trim();
    if (id.isEmpty) {
      throw const YouTubeApiException('YouTube video ID is missing.');
    }

    final cached = _videoCache[id];
    if (cached != null && DateTime.now().isBefore(cached.expiresAt)) {
      return cached;
    }

    final resolved = await _withRequestSlot(() => _resolveVideo(id));
    _videoCache[id] = resolved;
    return resolved;
  }

  /// Called by the audio source when the CDN refuses a URL. The profile that
  /// produced it is benched so the retry asks a different client — unless the
  /// URL had simply run out its six hours, which says nothing about the client.
  void reportStreamFailure(String videoId) {
    final cached = _audioCache.remove(videoId);
    if (cached != null && cached.isExpired) return;
    _profileBlockedUntil[_preferredProfile] =
        DateTime.now().add(_profilePenalty);
  }

  void clearCaches() {
    _searchCache.clear();
    _audioCache.clear();
    _videoCache.clear();
  }

  /// Asks each client in turn until one hands back a stream this build can
  /// actually play. A profile that answers `OK` with SABR-only formats is not a
  /// success: the next profile may still offer the muxed rendition.
  Future<YouTubeAudioStream> _resolveAudio(String id) async {
    YouTubeApiException? lastError;
    for (final index in _profileOrder()) {
      final response = await _requestPlayer(id, index);
      if (response == null) continue;
      final stream = _audioFromResponse(response);
      if (stream == null) {
        lastError = const YouTubeApiException(
          'YouTube offered no playable audio rendition.',
          kind: YouTubeErrorKind.blocked,
        );
        continue;
      }
      _preferredProfile = index;
      return stream;
    }

    final proxied = await _throughProxy(id, wantVideo: false);
    if (proxied is YouTubeAudioStream) return proxied;
    throw lastError ??
        const YouTubeApiException(
          'No YouTube client answered.',
          kind: YouTubeErrorKind.blocked,
        );
  }

  YouTubeAudioStream? _audioFromResponse(Map<String, dynamic> response) {
    final streaming = response['streamingData'];
    if (streaming is! Map) return null;

    final audioOnly = <Map<String, dynamic>>[];
    final adaptive = streaming['adaptiveFormats'];
    if (adaptive is List) {
      for (final entry in adaptive) {
        if (entry is Map) {
          final format = Map<String, dynamic>.from(entry);
          final mime = format['mimeType']?.toString() ?? '';
          if (mime.startsWith('audio/')) audioOnly.add(format);
        }
      }
    }

    audioOnly.sort((a, b) {
      final rank = _preferenceRank(a['itag']?.toString());
      final otherRank = _preferenceRank(b['itag']?.toString());
      if (rank != otherRank) return rank.compareTo(otherRank);
      return _int(b['bitrate']).compareTo(_int(a['bitrate']));
    });

    for (final format in audioOnly) {
      final url = _directUrl(format);
      if (url == null) continue;
      return YouTubeAudioStream(
        url: url,
        mimeType: format['mimeType']?.toString() ?? 'audio/mp4',
        itag: format['itag']?.toString() ?? '140',
        contentLength: _intOrNull(format['contentLength']),
        expiresAt: _expiryOf(url),
      );
    }

    // Adaptive audio is now SABR-only for most clients: the formats carry
    // `initRange`/`indexRange` instead of a URL and need YouTube's UMP protocol
    // to fetch. The muxed progressive rendition is still handed out as a plain
    // URL, and its AAC track is what a music player needs. Feeding the muxed
    // file to the audio decoder costs a video track worth of bytes it will
    // never decode, which is a far better trade than not playing at all.
    final muxed = _muxedFormatsWithUrl(streaming);
    if (muxed.isEmpty) return null;
    muxed.sort((a, b) => _int(a['bitrate']).compareTo(_int(b['bitrate'])));
    final format = muxed.first;
    final url = _directUrl(format)!;
    return YouTubeAudioStream(
      url: url,
      // The container is mp4 either way; telling the decoder it is audio keeps
      // the muxed video track from being set up as a second surface.
      mimeType: 'audio/mp4',
      itag: format['itag']?.toString() ?? '18',
      contentLength: _intOrNull(format['contentLength']),
      expiresAt: _expiryOf(url),
    );
  }

  List<Map<String, dynamic>> _muxedFormatsWithUrl(Map streaming) {
    final result = <Map<String, dynamic>>[];
    for (final key in const ['formats', 'adaptiveFormats']) {
      final entries = streaming[key];
      if (entries is! List) continue;
      for (final entry in entries) {
        if (entry is! Map) continue;
        final format = Map<String, dynamic>.from(entry);
        final mime = format['mimeType']?.toString() ?? '';
        if (mime.startsWith('audio/')) continue;
        // Muxed means it carries AAC: a video-only rendition is silent.
        if (!mime.contains('mp4a')) continue;
        if (_directUrl(format) == null) continue;
        result.add(format);
      }
    }
    return result;
  }

  Future<YouTubeVideoStream> _resolveVideo(String id) async {
    for (final index in _profileOrder()) {
      final response = await _requestPlayer(id, index);
      if (response == null) continue;
      final stream = _videoFromResponse(response);
      if (stream == null) continue;
      _preferredProfile = index;
      return stream;
    }

    final proxied = await _throughProxy(id, wantVideo: true);
    if (proxied is YouTubeVideoStream) return proxied;
    throw const YouTubeApiException(
      'No YouTube client offered a playable video rendition.',
      kind: YouTubeErrorKind.unavailable,
    );
  }

  YouTubeVideoStream? _videoFromResponse(Map<String, dynamic> response) {
    final streaming = response['streamingData'];
    if (streaming is! Map) return null;

    // Only the muxed rendition has a direct URL; adaptive video is SABR-only.
    final formats = _muxedFormatsWithUrl(streaming)
        .where((format) => _int(format['height']) <= 720)
        .toList()
      ..sort((a, b) => _int(b['height']).compareTo(_int(a['height'])));
    if (formats.isEmpty) return null;

    final format = formats.first;
    final url = _directUrl(format);
    if (url == null) return null;
    return YouTubeVideoStream(
      url: url,
      mimeType: format['mimeType']?.toString() ?? 'video/mp4',
      expiresAt: _expiryOf(url),
    );
  }

  /// Profiles in the order to try: the last one that worked, then the rest.
  Iterable<int> _profileOrder() sync* {
    for (var step = 0; step < _profiles.length; step++) {
      final index = (_preferredProfile + step) % _profiles.length;
      if (_isProfileBlocked(index)) continue;
      yield index;
    }
  }

  /// One player request. Returns null when this client cannot answer, and
  /// benches the client when the refusal is about the client rather than the
  /// video (bot checks, 403s) so the next track skips it.
  Future<Map<String, dynamic>?> _requestPlayer(String id, int index) async {
    final profile = _profiles[index];
    try {
      final response = await _postJson(
        'player',
        {
          'videoId': id,
          'context': _contextFor(profile),
          'contentCheckOk': true,
          'racyCheckOk': true,
        },
        profile: profile,
      );
      final status = response['playabilityStatus'];
      final state = status is Map ? status['status']?.toString() : null;
      if (state != null && state != 'OK' && state != 'LIVE_STREAM_OFFLINE') {
        final reason = status is Map ? status['reason']?.toString() : null;
        if (_kindForReason(reason) == YouTubeErrorKind.blocked) {
          _profileBlockedUntil[index] = DateTime.now().add(_profilePenalty);
        }
        return null;
      }
      return response;
    } on YouTubeApiException catch (error) {
      if (error.kind == YouTubeErrorKind.rateLimited) rethrow;
      if (error.kind == YouTubeErrorKind.blocked) {
        _profileBlockedUntil[index] = DateTime.now().add(_profilePenalty);
      }
      return null;
    }
  }

  bool get _resolverConfigured => _resolverBase.trim().isNotEmpty;

  /// Search and playback both start from the same primary client, so a query
  /// never spends a bot check on a profile that only serves search.
  _ClientProfile get _searchFallbackProfile => _profiles[0];

  Future<Object?> _throughProxy(String id, {required bool wantVideo}) async {
    if (!_resolverConfigured || isRateLimited) return null;
    try {
      return await _resolveThroughProxy(id, wantVideo: wantVideo);
    } on Object catch (error) {
      debugPrint('YouTube resolver failed: $error');
      return null;
    }
  }

  int _preferenceRank(String? itag) {
    final index = _audioPreference.indexOf(itag ?? '');
    return index < 0 ? _audioPreference.length : index;
  }

  /// Last resort for a blocked network: an Invidious or Piped instance returns
  /// stream URLs that are not tied to this device's IP.
  Future<Object?> _resolveThroughProxy(
    String id, {
    required bool wantVideo,
  }) async {
    final base = _resolverBase.trim().replaceAll(RegExp(r'/+$'), '');
    final candidates = [
      '$base/api/v1/videos/$id?local=true',
      '$base/streams/$id',
    ];

    for (final candidate in candidates) {
      final uri = Uri.tryParse(candidate);
      if (uri == null) continue;
      try {
        final response = await _send(uri, profile: _webProfile);
        if (response.statusCode < HttpStatus.ok ||
            response.statusCode >= HttpStatus.multipleChoices) {
          await _drain(response);
          continue;
        }
        final decoded = jsonDecode(await _readBody(response));
        if (decoded is! Map) continue;
        final formats = <Map<String, dynamic>>[];
        for (final key in const [
          'adaptiveFormats',
          'audioStreams',
          'formats'
        ]) {
          final entries = decoded[key];
          if (entries is! List) continue;
          for (final entry in entries) {
            if (entry is Map) formats.add(Map<String, dynamic>.from(entry));
          }
        }
        for (final format in formats) {
          final url = _directUrl(format);
          if (url == null) continue;
          final mime = format['mimeType']?.toString() ??
              format['type']?.toString() ??
              '';
          final isVideo = mime.startsWith('video/');
          if (isVideo != wantVideo) continue;
          final expiresAt = _expiryOf(url);
          if (wantVideo) {
            return YouTubeVideoStream(
              url: url,
              mimeType: mime.isEmpty ? 'video/mp4' : mime,
              expiresAt: expiresAt,
            );
          }
          return YouTubeAudioStream(
            url: url,
            mimeType: mime.isEmpty ? 'audio/mp4' : mime,
            itag: format['itag']?.toString() ?? 'proxy',
            contentLength:
                _intOrNull(format['contentLength'] ?? format['clen']),
            expiresAt: expiresAt,
          );
        }
      } on Object catch (error) {
        debugPrint('YouTube resolver $candidate failed: $error');
      }
    }
    return null;
  }

  Future<Map<String, dynamic>> _postJson(
    String endpoint,
    Map<String, dynamic> body, {
    required _ClientProfile profile,
  }) async {
    final uri = Uri.https(_host, '/youtubei/v1/$endpoint', {
      'key': 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8',
      'prettyPrint': 'false',
    });

    final response = await _send(
      uri,
      method: 'POST',
      profile: profile,
      body: jsonEncode(body),
    );

    final status = response.statusCode;
    if (status == HttpStatus.tooManyRequests) {
      _cooldownUntil = DateTime.now().add(_rateLimitCooldown);
      await _drain(response);
      throw const YouTubeApiException(
        'YouTube is rate limiting requests.',
        kind: YouTubeErrorKind.rateLimited,
        statusCode: 429,
      );
    }
    if (status == HttpStatus.forbidden) {
      await _drain(response);
      throw const YouTubeApiException(
        'YouTube refused the request.',
        kind: YouTubeErrorKind.blocked,
        statusCode: 403,
      );
    }
    if (status < HttpStatus.ok || status >= HttpStatus.multipleChoices) {
      await _drain(response);
      throw _httpException(endpoint, status);
    }

    final text = await _readBody(response);
    if (text.trim().isEmpty) return const {};
    final decoded = jsonDecode(text);
    if (decoded is! Map) {
      throw const YouTubeApiException(
        'YouTube returned an unexpected response.',
        kind: YouTubeErrorKind.invalidResponse,
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  Map<String, dynamic> _contextFor(_ClientProfile profile) => {
        'client': profile.client,
        'user': const {'lockedSafetyMode': false},
        'request': const {'useSsl': true},
      };

  Future<T> _withRequestSlot<T>(Future<T> Function() task) async {
    final cooldown = _cooldownUntil;
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      throw const YouTubeApiException(
        'YouTube is rate limiting requests.',
        kind: YouTubeErrorKind.rateLimited,
        statusCode: 429,
      );
    }
    while (_activeRequests >= _maxConcurrentRequests) {
      final waiter = Completer<void>();
      _waiters.add(waiter);
      await waiter.future;
    }
    _activeRequests++;
    try {
      return await task();
    } finally {
      _activeRequests--;
      if (_waiters.isNotEmpty) _waiters.removeFirst().complete();
    }
  }

  bool _isProfileBlocked(int index) {
    final until = _profileBlockedUntil[index];
    return until != null && DateTime.now().isBefore(until);
  }

  void _pruneAudioCache() {
    if (_audioCache.length <= 64) return;
    final now = DateTime.now();
    _audioCache.removeWhere((_, stream) => now.isAfter(stream.expiresAt));
    while (_audioCache.length > 64) {
      _audioCache.remove(_audioCache.keys.first);
    }
  }

  Uri? _directUrl(Map<String, dynamic> format) {
    // A `signatureCipher` needs the player JavaScript's cipher. Skipping that
    // profile and asking the next client is both cheaper and far more stable
    // than shipping a JavaScript interpreter.
    final raw = format['url']?.toString();
    if (raw == null || raw.isEmpty) return null;
    return Uri.tryParse(raw);
  }

  DateTime _expiryOf(Uri url) {
    final expire = int.tryParse(url.queryParameters['expire'] ?? '');
    if (expire == null) {
      return DateTime.now().add(const Duration(minutes: 15));
    }
    final signedExpiry = DateTime.fromMillisecondsSinceEpoch(expire * 1000);
    // Stop using the URL before the CDN does, so a queue entry never starts
    // playback on a link that is about to die.
    return signedExpiry.subtract(const Duration(minutes: 5));
  }

  YouTubeErrorKind? _kindForReason(String? reason) {
    if (reason == null) return null;
    final lower = reason.toLowerCase();
    if (lower.contains('bot') || lower.contains('sign in')) {
      return YouTubeErrorKind.blocked;
    }
    if (lower.contains('unavailable') || lower.contains('private')) {
      return YouTubeErrorKind.unavailable;
    }
    return null;
  }

  YouTubeApiException _httpException(String endpoint, int status) {
    final kind = switch (status) {
      HttpStatus.unauthorized ||
      HttpStatus.forbidden =>
        YouTubeErrorKind.blocked,
      HttpStatus.notFound => YouTubeErrorKind.unavailable,
      HttpStatus.tooManyRequests => YouTubeErrorKind.rateLimited,
      >= 500 => YouTubeErrorKind.other,
      _ => YouTubeErrorKind.other,
    };
    return YouTubeApiException(
      'YouTube $endpoint returned HTTP $status.',
      kind: kind,
      statusCode: status,
    );
  }

  Future<HttpClientResponse> _send(
    Uri uri, {
    required _ClientProfile profile,
    String? body,
    String method = 'GET',
  }) async {
    try {
      final request = await _client.openUrl(method, uri).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9')
        ..set('X-YouTube-Client-Name', '${profile.headerId}')
        ..set('X-YouTube-Client-Version', profile.version)
        ..set(HttpHeaders.userAgentHeader, profile.userAgent);
      if (body != null) request.write(body);
      return await request.close().timeout(_timeout);
    } on TimeoutException {
      throw const YouTubeApiException(
        'YouTube request timed out.',
        kind: YouTubeErrorKind.network,
      );
    } on SocketException {
      throw const YouTubeApiException(
        'Could not connect to YouTube.',
        kind: YouTubeErrorKind.network,
      );
    } on HttpException {
      throw const YouTubeApiException(
        'YouTube request failed.',
        kind: YouTubeErrorKind.network,
      );
    }
  }

  Future<String> _readBody(HttpClientResponse response) async {
    try {
      return await response.transform(utf8.decoder).join().timeout(_timeout);
    } on TimeoutException {
      throw const YouTubeApiException(
        'YouTube response timed out.',
        kind: YouTubeErrorKind.network,
      );
    } on SocketException {
      throw const YouTubeApiException(
        'Could not read the YouTube response.',
        kind: YouTubeErrorKind.network,
      );
    }
  }

  Future<void> _drain(HttpClientResponse response) async {
    try {
      await response.drain<void>().timeout(_timeout);
    } catch (_) {
      // The body of a failed response is only worth discarding.
    }
  }

  /// Search responses nest renderers differently between client versions, so
  /// results are collected by shape (a video ID plus a title) instead of by a
  /// path that breaks on the next rollout.
  void _collectVideos(
    Object? node,
    List<YouTubeVideo> out,
    Set<String> seen,
    int limit,
  ) {
    if (out.length >= limit) return;
    if (node is List) {
      for (final child in node) {
        _collectVideos(child, out, seen, limit);
        if (out.length >= limit) return;
      }
      return;
    }
    if (node is! Map) return;

    final id = node['videoId']?.toString();
    if (id != null && id.length == 11 && !seen.contains(id)) {
      final title = _text(node['title']) ?? _text(node['headline']);
      final isLive =
          node['isLiveNow'] == true || node['upcomingEventData'] != null;
      if (title != null && title.isNotEmpty && !isLive) {
        seen.add(id);
        out.add(
          YouTubeVideo(
            id: id,
            title: title,
            artist: _text(node['longBylineText']) ??
                _text(node['ownerText']) ??
                _text(node['shortBylineText']) ??
                _text(node['subtitle']) ??
                '',
            duration: _parseDuration(_text(node['lengthText'])),
          ),
        );
      }
    }

    for (final value in node.values) {
      if (value is Map || value is List) {
        _collectVideos(value, out, seen, limit);
        if (out.length >= limit) return;
      }
    }
  }

  /// InnerTube text runs come back as `{runs: [{text}]}` or
  /// `{simpleText: "..."}` depending on the field.
  String? _text(Object? node) {
    if (node is String) return node;
    if (node is! Map) return null;
    final simple = node['simpleText']?.toString();
    if (simple != null) return simple;
    final runs = node['runs'];
    if (runs is List) {
      final buffer = StringBuffer();
      for (final run in runs) {
        if (run is Map) buffer.write(run['text']?.toString() ?? '');
      }
      final text = buffer.toString().trim();
      return text.isEmpty ? null : text;
    }
    return null;
  }

  Duration? _parseDuration(String? text) {
    if (text == null) return null;
    final parts = text.split(':');
    if (parts.length < 2 || parts.length > 3) return null;
    var seconds = 0;
    for (final part in parts) {
      final value = int.tryParse(part.trim());
      if (value == null) return null;
      seconds = seconds * 60 + value;
    }
    return seconds > 0 ? Duration(seconds: seconds) : null;
  }

  static int _int(Object? value) => _intOrNull(value) ?? 0;

  static int? _intOrNull(Object? value) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '');
  }
}

class _ClientProfile {
  final String name;
  final int headerId;
  final String version;
  final String userAgent;
  final int? androidSdk;
  final Map<String, dynamic> device;

  const _ClientProfile({
    required this.name,
    required this.headerId,
    required this.version,
    required this.userAgent,
    this.androidSdk,
    this.device = const {},
  });

  Map<String, dynamic> get client => {
        'clientName': name,
        'clientVersion': version,
        'hl': 'en',
        'gl': 'US',
        'userAgent': userAgent,
        if (androidSdk != null) 'androidSdkVersion': androidSdk,
        ...device,
      };
}

class _CachedSearch {
  final List<YouTubeVideo> videos;
  final DateTime expiresAt;

  const _CachedSearch({required this.videos, required this.expiresAt});
}
