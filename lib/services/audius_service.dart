// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';

import 'shared_http_client.dart';

class AudiusTrack {
  final String id;
  final String title;
  final String artist;
  final String? artworkUrl;
  final Duration? duration;
  final String? genre;

  /// False for tracks Audius still lists but refuses to stream (deleted or
  /// gated). Those return 404 from the stream endpoint, so they must never
  /// enter a queue.
  final bool isStreamable;

  const AudiusTrack({
    required this.id,
    required this.title,
    required this.artist,
    this.artworkUrl,
    this.duration,
    this.genre,
    this.isStreamable = true,
  });

  factory AudiusTrack.fromJson(Map<String, dynamic> json) {
    final rawUser = json['user'];
    final user = rawUser is Map ? Map<String, dynamic>.from(rawUser) : const {};
    final rawArtwork = json['artwork'];
    final artwork = rawArtwork is Map
        ? Map<String, dynamic>.from(rawArtwork)
        : const <String, dynamic>{};
    final rawDuration = json['duration'];

    return AudiusTrack(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      artist: user['name']?.toString() ?? user['handle']?.toString() ?? '',
      artworkUrl: _artworkUrl(rawArtwork, artwork),
      duration: rawDuration is num && rawDuration > 0
          ? Duration(milliseconds: (rawDuration * 1000).round())
          : null,
      genre: json['genre']?.toString(),
      isStreamable: json['is_streamable'] != false && json['is_delete'] != true,
    );
  }

  static String? _artworkUrl(Object? rawArtwork, Map<String, dynamic> artwork) {
    if (rawArtwork is String && rawArtwork.isNotEmpty) return rawArtwork;
    for (final key in const [
      '480x480',
      '_480x480',
      '1000x1000',
      '_1000x1000',
      '150x150',
      '_150x150',
    ]) {
      final value = artwork[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return null;
  }
}

/// Why an Audius request failed. The UI needs this to say something more
/// useful than "check your connection", which is wrong for a 429.
enum AudiusErrorKind {
  network,
  unauthorized,
  rateLimited,
  unavailable,
  server,
  invalidResponse,
  other,
}

class AudiusApiException implements Exception {
  final String message;
  final AudiusErrorKind kind;
  final int? statusCode;

  const AudiusApiException(
    this.message, {
    this.kind = AudiusErrorKind.other,
    this.statusCode,
  });

  @override
  String toString() => 'AudiusApiException: $message';
}

class AudiusService {
  AudiusService({HttpClient? client, String? apiKey})
      : _client = client ?? SharedHttpClient.instance,
        _apiKey =
            (apiKey ?? const String.fromEnvironment('AUDIUS_API_KEY')).trim();

  static final AudiusService instance = AudiusService();

  static const String _host = 'api.audius.co';
  static const Duration _timeout = Duration(seconds: 12);
  static const int _maxCachedSearches = 20;

  /// Audius starts answering 429 well before a full search result queue has
  /// been resolved. Keep a few slots for artwork and search, never one per row.
  static const int _maxConcurrentStreamRequests = 4;

  final HttpClient _client;
  final String _apiKey;
  final LinkedHashMap<String, List<AudiusTrack>> _searchCache =
      LinkedHashMap<String, List<AudiusTrack>>();

  int _activeStreamRequests = 0;
  final Queue<Completer<void>> _streamWaiters = Queue<Completer<void>>();
  bool _loggedMissingKey = false;

  bool get _hasApiKey => _apiKey.isNotEmpty;

  Future<List<AudiusTrack>> searchTracks(
    String query, {
    String? genre,
    int limit = 25,
  }) async {
    final normalizedQuery = query.trim();
    if (normalizedQuery.isEmpty) return const [];

    final normalizedGenre = genre?.trim();
    final cacheKey = jsonEncode([
      normalizedQuery,
      normalizedGenre,
      limit,
    ]);
    final cached = _searchCache.remove(cacheKey);
    if (cached != null) {
      _searchCache[cacheKey] = cached;
      return cached;
    }

    final json = await _getJson(
      ['v1', 'tracks', 'search'],
      queryParameters: {
        'query': normalizedQuery,
        'limit': '$limit',
        if (normalizedGenre != null && normalizedGenre.isNotEmpty)
          'genre': normalizedGenre,
      },
    );
    final tracks = List<AudiusTrack>.unmodifiable(_tracksFromJson(json));
    _searchCache[cacheKey] = tracks;
    while (_searchCache.length > _maxCachedSearches) {
      _searchCache.remove(_searchCache.keys.first);
    }
    return tracks;
  }

  Future<List<AudiusTrack>> getTrendingTracks({
    String? genre,
    int limit = 25,
  }) async {
    final normalizedGenre = genre?.trim();
    final json = await _getJson(
      ['v1', 'tracks', 'trending'],
      queryParameters: {
        'limit': '$limit',
        if (normalizedGenre != null && normalizedGenre.isNotEmpty)
          'genre': normalizedGenre,
      },
    );
    return _tracksFromJson(json);
  }

  Future<AudiusTrack?> getTrack(String trackId) async {
    final id = trackId.trim();
    if (id.isEmpty) return null;

    final json = await _getJson(
      ['v1', 'tracks', id],
      notFoundIsNull: true,
    );
    final data = _dataFromJson(json);
    if (data is Map) {
      final track = AudiusTrack.fromJson(Map<String, dynamic>.from(data));
      return track.id.isEmpty ? null : track;
    }
    if (data is List && data.isNotEmpty && data.first is Map) {
      final track =
          AudiusTrack.fromJson(Map<String, dynamic>.from(data.first as Map));
      return track.id.isEmpty ? null : track;
    }
    return null;
  }

  /// Resolves the playable URL for [trackId] right now.
  ///
  /// Uses `no_redirect=true` so the URL comes back as JSON. The default
  /// response is a 302 whose `Location` is the audio URL; both are accepted
  /// because the redirect target is what the player actually consumes.
  /// Returns null only when Audius says the track does not exist.
  Future<Uri?> getStreamUrl(String trackId) {
    final id = trackId.trim();
    if (id.isEmpty) return Future.value(null);
    return _withStreamSlot(() => _resolveStreamUrl(id));
  }

  /// A stable endpoint for a queued track that is not playing yet.
  ///
  /// Resolving every queue entry up front is what produced bursts of 429s, so
  /// queued entries keep this URL and the player follows the redirect when it
  /// actually reaches them.
  Uri? playbackUri(String trackId) {
    final id = trackId.trim();
    if (id.isEmpty) return null;
    return _uri(
      ['v1', 'tracks', id, 'stream'],
      queryParameters: _authQuery(),
    );
  }

  void clearSearchCache() => _searchCache.clear();

  Future<Uri?> _resolveStreamUrl(String id) async {
    final uri = _uri(
      ['v1', 'tracks', id, 'stream'],
      queryParameters: {
        'no_redirect': 'true',
        ..._authQuery(),
      },
    );
    debugPrint('Audius GET https://$_host/v1/tracks/$id/stream (no_redirect)');

    final response = await _send(uri, followRedirects: false);
    final status = response.statusCode;
    final location = response.headers.value(HttpHeaders.locationHeader);
    final body = await _readBody(response);

    debugPrint('Audius stream $id -> HTTP $status');

    if (status == HttpStatus.notFound) return null;

    if (status >= HttpStatus.multipleChoices &&
        status < HttpStatus.badRequest) {
      if (location != null && location.isNotEmpty) {
        return uri.resolve(location);
      }
      _logFailureBody(body);
      throw _httpException('stream', status);
    }

    if (status == HttpStatus.ok) {
      final streamUri = _streamUriFromJson(body);
      if (streamUri != null) return streamUri;
      _logFailureBody(body);
      throw const AudiusApiException(
        'Audius returned an unexpected stream response.',
        kind: AudiusErrorKind.invalidResponse,
      );
    }

    _logFailureBody(body);
    throw _httpException('stream', status);
  }

  Uri? _streamUriFromJson(String body) {
    try {
      final decoded = jsonDecode(body);
      final data = decoded is Map ? decoded['data'] : null;
      if (data is String && data.isNotEmpty) {
        final parsed = Uri.tryParse(data);
        if (parsed != null && parsed.hasScheme) return parsed;
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  Future<T> _withStreamSlot<T>(Future<T> Function() task) async {
    while (_activeStreamRequests >= _maxConcurrentStreamRequests) {
      final waiter = Completer<void>();
      _streamWaiters.add(waiter);
      await waiter.future;
    }
    _activeStreamRequests++;
    try {
      return await task();
    } finally {
      _activeStreamRequests--;
      if (_streamWaiters.isNotEmpty) {
        _streamWaiters.removeFirst().complete();
      }
    }
  }

  void _logFailureBody(String body) {
    if (body.trim().isEmpty) return;
    debugPrint('Audius error body: ${_snippet(body)}');
  }

  String _snippet(String body) =>
      body.length <= 200 ? body : '${body.substring(0, 200)}...';

  Map<String, String> _authQuery() =>
      _hasApiKey ? {'api_key': _apiKey} : const {};

  Future<Object?> _getJson(
    List<String> pathSegments, {
    Map<String, String>? queryParameters,
    bool notFoundIsNull = false,
  }) async {
    final response = await _send(
      _uri(pathSegments, queryParameters: queryParameters),
    );
    if (response.statusCode == HttpStatus.notFound && notFoundIsNull) {
      await _discardBody(response);
      return null;
    }
    if (response.statusCode < HttpStatus.ok ||
        response.statusCode >= HttpStatus.multipleChoices) {
      final body = await _readBody(response);
      debugPrint(
        'Audius GET /${pathSegments.join('/')} -> '
        'HTTP ${response.statusCode}',
      );
      _logFailureBody(body);
      throw _httpException('request', response.statusCode);
    }

    final body = await _readBody(response);
    if (body.trim().isEmpty) return null;
    try {
      return jsonDecode(body);
    } on FormatException {
      throw const AudiusApiException(
        'Audius returned invalid JSON.',
        kind: AudiusErrorKind.invalidResponse,
      );
    }
  }

  AudiusApiException _httpException(String label, int status) {
    final kind = switch (status) {
      HttpStatus.unauthorized ||
      HttpStatus.forbidden =>
        AudiusErrorKind.unauthorized,
      HttpStatus.notFound => AudiusErrorKind.unavailable,
      HttpStatus.tooManyRequests => AudiusErrorKind.rateLimited,
      >= 500 => AudiusErrorKind.server,
      _ => AudiusErrorKind.other,
    };
    return AudiusApiException(
      'Audius $label returned HTTP $status.',
      kind: kind,
      statusCode: status,
    );
  }

  Future<HttpClientResponse> _send(
    Uri uri, {
    bool followRedirects = true,
  }) async {
    if (!_hasApiKey && !_loggedMissingKey) {
      _loggedMissingKey = true;
      debugPrint('Audius: no API key configured, using anonymous requests.');
    }

    try {
      final request = await _client.getUrl(uri).timeout(_timeout);
      request.followRedirects = followRedirects;
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      if (_hasApiKey) request.headers.set('x-api-key', _apiKey);
      return await request.close().timeout(_timeout);
    } on TimeoutException {
      throw const AudiusApiException(
        'Audius request timed out.',
        kind: AudiusErrorKind.network,
      );
    } on SocketException {
      throw const AudiusApiException(
        'Could not connect to Audius.',
        kind: AudiusErrorKind.network,
      );
    } on HttpException {
      throw const AudiusApiException(
        'Audius request failed.',
        kind: AudiusErrorKind.network,
      );
    }
  }

  Future<String> _readBody(HttpClientResponse response) async {
    try {
      return await response.transform(utf8.decoder).join().timeout(_timeout);
    } on TimeoutException {
      throw const AudiusApiException(
        'Audius response timed out.',
        kind: AudiusErrorKind.network,
      );
    } on SocketException {
      throw const AudiusApiException(
        'Could not read the Audius response.',
        kind: AudiusErrorKind.network,
      );
    } on FormatException {
      throw const AudiusApiException(
        'Audius returned invalid text data.',
        kind: AudiusErrorKind.invalidResponse,
      );
    }
  }

  Future<void> _discardBody(HttpClientResponse response) async {
    try {
      await response.drain<void>().timeout(_timeout);
    } on TimeoutException {
      throw const AudiusApiException(
        'Audius response timed out.',
        kind: AudiusErrorKind.network,
      );
    } on SocketException {
      throw const AudiusApiException(
        'Could not read the Audius response.',
        kind: AudiusErrorKind.network,
      );
    }
  }

  Uri _uri(
    List<String> pathSegments, {
    Map<String, String>? queryParameters,
  }) =>
      Uri(
        scheme: 'https',
        host: _host,
        pathSegments: pathSegments,
        queryParameters: queryParameters,
      );

  List<AudiusTrack> _tracksFromJson(Object? json) {
    final data = _dataFromJson(json);
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((track) => AudiusTrack.fromJson(Map<String, dynamic>.from(track)))
        .where((track) => track.id.isNotEmpty && track.isStreamable)
        .toList();
  }

  Object? _dataFromJson(Object? json) {
    if (json is Map) return json['data'];
    return null;
  }
}
