// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'youtube_session.dart';

/// Read-only InnerTube client for the signed-in account, authenticated with the
/// browser cookies collected by [YouTubeWebSession].
///
/// InnerTube is the API YouTube's own web client calls, so it needs no
/// developer registration, no consent screen and no per-app quota: the request
/// carries Google's public web-client key plus a `SAPISIDHASH` signature over
/// the session's cookie. Playback elsewhere in the app uses the same endpoints
/// (`youtube_service.dart`); only the account-level shelves are read here.
///
/// Response shapes are parsed by walking the JSON rather than by hardcoding a
/// path to `contents.twoColumnBrowseResultsRenderer...`: YouTube reshuffles
/// those containers regularly and has been migrating grids from
/// `gridPlaylistRenderer` to `lockupViewModel`. The walkers accept every shape
/// seen in the wild and ignore anything unfamiliar.
class YouTubeLibraryException implements Exception {
  final YouTubeLibraryErrorKind kind;
  final String message;
  final int? statusCode;

  const YouTubeLibraryException(this.kind, this.message, {this.statusCode});

  @override
  String toString() => 'YouTubeLibraryException(${kind.name}): $message';
}

enum YouTubeLibraryErrorKind {
  network,

  /// The stored cookies are missing, expired, or not a YouTube session.
  unauthorized,

  /// The playlist or video is gone, or the list is empty.
  notFound,

  /// YouTube answered, but not with something this client can read.
  invalidResponse,

  /// YouTube is throttling this device. Waiting is the only fix.
  rateLimited,
  other,
}

class YouTubeAccountProfile {
  final String channelId;
  final String title;
  final String? avatarUrl;

  const YouTubeAccountProfile({
    required this.channelId,
    required this.title,
    this.avatarUrl,
  });
}

/// Synthetic id for the liked-videos list, which the account does not see as a
/// playlist but behaves like one everywhere else in the UI.
const String kLikedVideosPlaylistId = 'liked-videos';

/// `LL` is YouTube's own id for liked videos; it is folded into
/// [kLikedVideosPlaylistId] so the list is not offered twice.
const String _kLikedBrowsePlaylistId = 'LL';

class YouTubeAccountPlaylist {
  final String id;
  final String title;
  final String? description;
  final int? itemCount;
  final String? thumbnailUrl;

  const YouTubeAccountPlaylist({
    required this.id,
    required this.title,
    this.description,
    this.itemCount,
    this.thumbnailUrl,
  });

  bool get isLikedVideos => id == kLikedVideosPlaylistId;
}

/// Thumbnail URL for a video. `mqdefault` is the smallest size that still
/// looks sharp behind the player and in a list row.
String youtubeThumbnailUrl(String videoId) =>
    'https://i.ytimg.com/vi/$videoId/mqdefault.jpg';

class YouTubePlaylistItem {
  final String videoId;
  final String title;
  final String artist;
  final Duration? duration;
  final String? thumbnailUrl;
  final int position;

  const YouTubePlaylistItem({
    required this.videoId,
    required this.title,
    required this.artist,
    this.duration,
    this.thumbnailUrl,
    this.position = 0,
  });
}

/// The public key YouTube ships inside its own web pages. It is not a secret
/// and not tied to a project: every browser sends it, and it is the reason this
/// integration needs no setup from the user.
const String kYouTubeWebApiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

/// Used only when the live client version cannot be read. YouTube rejects a
/// badly stale version, so the client re-resolves it on every launch.
const String kYouTubeWebClientVersionFallback = '2.20261026.01.00';

const String kYouTubeWebUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/// Supplies the cookies to sign with, or null when the user is signed out.
typedef YouTubeSessionProvider = Future<YouTubeWebSession?> Function();

class YouTubeLibraryApi {
  YouTubeLibraryApi({
    required YouTubeSessionProvider session,
    HttpClient? client,
    Uri? baseUrl,
    Uri? versionUrl,
    String? clientVersion,
    Duration timeout = const Duration(seconds: 20),
    DateTime Function()? clock,
  })  : _session = session,
        _client = client ?? HttpClient(),
        _base = baseUrl ?? Uri.parse('https://www.youtube.com/youtubei/v1/'),
        _versionUrl = versionUrl,
        _version = clientVersion,
        _pinnedVersion = clientVersion != null,
        _timeout = timeout,
        _clock = clock ?? DateTime.now;

  final YouTubeSessionProvider _session;
  final HttpClient _client;
  final Uri _base;
  final Uri? _versionUrl;
  final bool _pinnedVersion;
  final Duration _timeout;
  final DateTime Function() _clock;

  String? _version;
  bool _versionFromConfig = false;

  /// True once the client version came from YouTube itself rather than from
  /// [kYouTubeWebClientVersionFallback]. Diagnostics and the probe use it to
  /// tell "resolved" from "fell back".
  bool get hasLiveClientVersion => _versionFromConfig;

  /// Channel metadata, used for the signed-in card and to prove the cookies
  /// still work. Returns null when YouTube treats the session as signed out.
  Future<YouTubeAccountProfile?> account() async {
    final json = await _post('account/account_menu', const {});
    return parseAccountProfile(json);
  }

  /// The account's own playlists, in YouTube's order, plus the synthetic
  /// liked-videos entry.
  Future<List<YouTubeAccountPlaylist>> playlists({int maxPages = 3}) async {
    final result = <YouTubeAccountPlaylist>[];
    final seen = <String>{};
    String? continuation;
    final usedContinuations = <String>{};

    for (var page = 0; page < maxPages; page++) {
      final json = await _post(
        'browse',
        continuation == null
            // `FEplaylists` was retired and now answers 400; the aggregation
            // page is the one the library's playlists tab loads.
            ? const {'browseId': 'FEplaylist_aggregation'}
            : {'continuation': continuation},
      );
      for (final playlist in parseAccountPlaylists(json)) {
        if (seen.add(playlist.id)) result.add(playlist);
      }
      final next = nextContinuation(json);
      if (next == null || !usedContinuations.add(next)) break;
      continuation = next;
    }

    result.add(
      const YouTubeAccountPlaylist(id: kLikedVideosPlaylistId, title: ''),
    );
    return result;
  }

  /// Every playable track in [playlistId], in playlist order.
  Future<List<YouTubePlaylistItem>> playlistItems(
    String playlistId, {
    int maxPages = 20,
  }) {
    final browseId = playlistId.startsWith('VL') ? playlistId : 'VL$playlistId';
    return _collectPlaylist(browseId, maxPages: maxPages);
  }

  /// The account's liked videos.
  Future<List<YouTubePlaylistItem>> likedVideos({int maxPages = 20}) {
    return _collectPlaylist('VL$_kLikedBrowsePlaylistId', maxPages: maxPages);
  }

  /// The client version that will be sent, resolved once per instance.
  /// Exposed so diagnostics and the probe can verify what YouTube is told.
  Future<String> resolvedClientVersion() => _clientVersion();

  Future<List<YouTubePlaylistItem>> _collectPlaylist(
    String browseId, {
    required int maxPages,
  }) async {
    final items = <YouTubePlaylistItem>[];
    final seen = <String>{};
    final usedContinuations = <String>{};
    String? continuation;

    for (var page = 0; page < maxPages; page++) {
      final json = await _post(
        'browse',
        continuation == null
            ? {'browseId': browseId}
            : {'continuation': continuation},
      );
      for (final item in parsePlaylistVideoItems(json)) {
        if (!seen.add(item.videoId)) continue;
        items.add(
          YouTubePlaylistItem(
            videoId: item.videoId,
            title: item.title,
            artist: item.artist,
            duration: item.duration,
            thumbnailUrl: item.thumbnailUrl,
            position: items.length,
          ),
        );
      }
      final next = nextContinuation(json);
      // A token that repeats means YouTube has nothing more for us; treating it
      // as a continuation would loop until the page budget ran out.
      if (next == null || !usedContinuations.add(next)) break;
      continuation = next;
    }
    return items;
  }

  Future<Map<String, dynamic>> _post(
    String endpoint,
    Map<String, Object?> body,
  ) async {
    final session = await _session();
    if (session == null || !session.isUsable) {
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.unauthorized,
        'Not signed in to a YouTube account.',
      );
    }

    final uri = _base.replace(
      path: '${_base.path.endsWith('/') ? _base.path : '${_base.path}/'}'
          '$endpoint',
      queryParameters: const {
        'key': kYouTubeWebApiKey,
        'prettyPrint': 'false',
      },
    );

    var attempt = 0;
    while (true) {
      final version = await _clientVersion();
      final payload = {
        'context': _context(version),
        ...body,
      };
      final response = await _send(uri, payload, session, version);
      final status = response.status;

      if (status >= HttpStatus.ok && status < HttpStatus.multipleChoices) {
        final json = response.json;
        if (json is Map) return Map<String, dynamic>.from(json);
        throw const YouTubeLibraryException(
          YouTubeLibraryErrorKind.invalidResponse,
          'YouTube returned an unexpected response.',
        );
      }

      // A 400 from InnerTube is usually a client version YouTube no longer
      // accepts. Re-resolve once rather than making the user restart.
      if (status == HttpStatus.badRequest && attempt == 0 && !_pinnedVersion) {
        _version = null;
        attempt++;
        continue;
      }

      throw switch (status) {
        HttpStatus.unauthorized ||
        HttpStatus.forbidden =>
          YouTubeLibraryException(
            YouTubeLibraryErrorKind.unauthorized,
            'YouTube did not accept the stored session.',
            statusCode: status,
          ),
        HttpStatus.notFound => YouTubeLibraryException(
            YouTubeLibraryErrorKind.notFound,
            'YouTube could not find $endpoint.',
            statusCode: status,
          ),
        HttpStatus.tooManyRequests => YouTubeLibraryException(
            YouTubeLibraryErrorKind.rateLimited,
            'YouTube is rate limiting requests.',
            statusCode: status,
          ),
        HttpStatus.badRequest => YouTubeLibraryException(
            YouTubeLibraryErrorKind.invalidResponse,
            'YouTube rejected the request to $endpoint.',
            statusCode: status,
          ),
        _ => YouTubeLibraryException(
            YouTubeLibraryErrorKind.other,
            'YouTube $endpoint returned HTTP $status.',
            statusCode: status,
          ),
      };
    }
  }

  Future<_JsonResponse> _send(
    Uri uri,
    Map<String, Object?> payload,
    YouTubeWebSession session,
    String version,
  ) async {
    try {
      final request = await _client.postUrl(uri).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set('X-YouTube-Client-Name', '1')
        ..set('X-YouTube-Client-Version', version)
        ..set('X-Goog-Api-Key', kYouTubeWebApiKey)
        ..set('Origin', YouTubeWebSession.origin)
        ..set('X-Origin', YouTubeWebSession.origin)
        ..set('Referer', '${YouTubeWebSession.origin}/')
        ..set(HttpHeaders.userAgentHeader, kYouTubeWebUserAgent)
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
      for (final header in session.authHeaders(_clock()).entries) {
        request.headers.set(header.key, header.value);
      }
      request.add(utf8.encode(jsonEncode(payload)));

      final response = await request.close().timeout(_timeout);
      final body =
          await response.transform(utf8.decoder).join().timeout(_timeout);
      Object? json;
      if (body.trim().isNotEmpty) {
        try {
          json = jsonDecode(body);
        } on FormatException {
          json = null;
        }
      }
      return _JsonResponse(response.statusCode, json);
    } on TimeoutException {
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.network,
        'YouTube did not answer in time.',
      );
    } on SocketException {
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.network,
        'Could not reach YouTube.',
      );
    } on HttpException {
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.network,
        'The request to YouTube failed.',
      );
    }
  }

  /// The web client version the page is currently shipping. YouTube rotates it
  /// every few weeks and older values start failing, so it is read at runtime
  /// with the compiled default as a last resort.
  Future<String> _clientVersion() async {
    final cached = _version;
    if (cached != null) return cached;
    final resolved =
        await _resolveClientVersion() ?? kYouTubeWebClientVersionFallback;
    _version = resolved;
    return resolved;
  }

  Future<String?> _resolveClientVersion() async {
    // The homepage embeds the version in its `ytcfg`; `sw.js_data` used to
    // carry it and is kept as a second source because YouTube moves this
    // around. A caller that supplied a URL (tests, diagnostics) gets only that.
    final configured = _versionUrl;
    final sources = configured != null
        ? <Uri>[configured]
        : <Uri>[
            Uri.parse('https://www.youtube.com/'),
            Uri.parse('https://www.youtube.com/sw.js_data'),
          ];

    for (final uri in sources) {
      try {
        final text = await _getText(uri);
        final match = RegExp(r'INNERTUBE_CLIENT_VERSION"?\s*:\s*"?([0-9.]+)')
            .firstMatch(text);
        if (match != null) {
          _versionFromConfig = true;
          return match.group(1);
        }
      } on Object catch (error) {
        // Offline, or the endpoint moved: the compiled fallback still lets a
        // request go out.
        stderr.writeln('YouTube: could not read the client version: $error');
      }
    }
    return null;
  }

  Future<String> _getText(Uri uri) async {
    var target = uri;
    for (var hop = 0; hop < 3; hop++) {
      final request = await _client.getUrl(target).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.userAgentHeader, kYouTubeWebUserAgent)
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
      final response = await request.close().timeout(_timeout);
      // Consent pages and region redirects answer 30x before the real page.
      if (response.isRedirect) {
        final location = response.headers.value(HttpHeaders.locationHeader);
        await response.drain<void>();
        if (location == null || location.isEmpty) break;
        target = target.resolve(location);
        continue;
      }
      return response.transform(utf8.decoder).join().timeout(_timeout);
    }
    throw const YouTubeLibraryException(
      YouTubeLibraryErrorKind.network,
      'YouTube redirected too many times.',
    );
  }

  Map<String, Object?> _context(String version) => {
        'client': {
          'clientName': 'WEB',
          'clientVersion': version,
          'hl': 'en',
          'gl': 'US',
          'userAgent': kYouTubeWebUserAgent,
          'originalUrl': '${YouTubeWebSession.origin}/',
          'platform': 'DESKTOP',
        },
        'user': const {'lockedSafetyMode': false},
        'request': const {'useSsl': true},
      };
}

class _JsonResponse {
  final int status;
  final Object? json;

  const _JsonResponse(this.status, this.json);
}

// ---------------------------------------------------------------------------
// Response parsing
// ---------------------------------------------------------------------------

/// The signed-in account header from `account/account_menu`.
YouTubeAccountProfile? parseAccountProfile(Object? json) {
  for (final node in walkJsonMaps(json)) {
    final header = node['activeAccountHeaderRenderer'];
    if (header is! Map) continue;
    final title = textOf(header['accountName']);
    if (title == null) continue;
    final browseId = mapOf(
        mapOf(header['navigationEndpoint'])['browseEndpoint'])['browseId'];
    return YouTubeAccountProfile(
      channelId: browseId?.toString() ?? '',
      title: title,
      avatarUrl: bestImageUrl(header['accountPhoto']),
    );
  }
  return null;
}

/// Playlists from a `FEplaylists` browse response, in page order.
///
/// Accepts the grid shapes (`gridPlaylistRenderer`, `playlistRenderer`) and the
/// newer `lockupViewModel` grid. Liked videos come back as the `LL` playlist on
/// some layouts; it is dropped here because the API exposes it as its own
/// synthetic entry.
List<YouTubeAccountPlaylist> parseAccountPlaylists(Object? json) {
  final result = <YouTubeAccountPlaylist>[];
  final seen = <String>{};

  for (final node in walkJsonMaps(json)) {
    YouTubeAccountPlaylist? playlist;
    final renderer = node['gridPlaylistRenderer'] ?? node['playlistRenderer'];
    if (renderer is Map) {
      playlist = _playlistFromRenderer(renderer);
    } else {
      final lockup = node['lockupViewModel'];
      if (lockup is Map) playlist = _playlistFromLockup(lockup);
    }
    if (playlist == null) continue;
    if (playlist.id == _kLikedBrowsePlaylistId) continue;
    if (!seen.add(playlist.id)) continue;
    result.add(playlist);
  }
  return result;
}

YouTubeAccountPlaylist? _playlistFromRenderer(Map renderer) {
  final id = _playlistIdOf(renderer);
  final title = textOf(renderer['title']);
  if (id == null || title == null) return null;
  final count = intOf(renderer['videoCount']) ??
      countOfText(textOf(renderer['videoCountText']));
  return YouTubeAccountPlaylist(
    id: id,
    title: title,
    itemCount: count,
    thumbnailUrl: bestImageUrl(renderer['thumbnail']),
  );
}

YouTubeAccountPlaylist? _playlistFromLockup(Map lockup) {
  final type = lockup['contentType']?.toString().toUpperCase() ?? '';
  if (!type.contains('PLAYLIST')) return null;
  final id = stripVl(lockup['contentId']?.toString() ?? '');
  if (id.isEmpty) return null;
  final metadata = mapOf(mapOf(lockup['metadata'])['lockupMetadataViewModel']);
  final title = textOf(metadata['title']);
  if (title == null) return null;
  return YouTubeAccountPlaylist(
    id: id,
    title: title,
    itemCount: countInNode(metadata['metadata']),
    thumbnailUrl: bestImageUrl(lockup['contentImage']),
  );
}

/// Tracks from a playlist or liked-videos browse response, in page order,
/// de-duplicated.
List<YouTubePlaylistItem> parsePlaylistVideoItems(Object? json) {
  final result = <YouTubePlaylistItem>[];
  final seen = <String>{};

  for (final node in walkJsonMaps(json)) {
    YouTubePlaylistItem? item;
    final playlistVideo = node['playlistVideoRenderer'];
    final compactVideo = node['compactVideoRenderer'];
    final video = node['videoRenderer'];
    final lockup = node['lockupViewModel'];
    if (playlistVideo is Map) {
      item = _itemFromPlaylistVideo(playlistVideo);
    } else if (compactVideo is Map) {
      item = _itemFromVideoRenderer(compactVideo);
    } else if (video is Map) {
      item = _itemFromVideoRenderer(video);
    } else if (lockup is Map) {
      item = _itemFromLockup(lockup);
    }
    if (item == null) continue;
    if (!seen.add(item.videoId)) continue;
    result.add(
      YouTubePlaylistItem(
        videoId: item.videoId,
        title: item.title,
        artist: item.artist,
        duration: item.duration,
        thumbnailUrl: item.thumbnailUrl,
        position: result.length,
      ),
    );
  }
  return result;
}

YouTubePlaylistItem? _itemFromPlaylistVideo(Map renderer) {
  if (renderer['isPlayable'] == false) return null;
  final id = renderer['videoId']?.toString() ?? '';
  final title = textOf(renderer['title']);
  if (id.isEmpty || !isPlayableTitle(title)) return null;
  return YouTubePlaylistItem(
    videoId: id,
    title: title!,
    artist: artistOf(renderer['shortBylineText'] ?? renderer['longBylineText']),
    duration: parseClock(textOf(renderer['lengthText'])),
    thumbnailUrl: bestImageUrl(renderer['thumbnail']),
  );
}

YouTubePlaylistItem? _itemFromVideoRenderer(Map renderer) {
  final id = renderer['videoId']?.toString() ?? '';
  final title = textOf(renderer['title']);
  if (id.isEmpty || !isPlayableTitle(title)) return null;
  return YouTubePlaylistItem(
    videoId: id,
    title: title!,
    artist: artistOf(
      renderer['shortBylineText'] ??
          renderer['longBylineText'] ??
          renderer['ownerText'],
    ),
    duration: parseClock(
      textOf(renderer['lengthText'] ??
          renderer['thumbnailOverlayTimeStatusRenderer']),
    ),
    thumbnailUrl: bestImageUrl(renderer['thumbnail']),
  );
}

YouTubePlaylistItem? _itemFromLockup(Map lockup) {
  final type = lockup['contentType']?.toString().toUpperCase() ?? '';
  if (!type.contains('VIDEO')) return null;
  final id = lockup['contentId']?.toString() ?? '';
  if (id.isEmpty) return null;
  final metadata = mapOf(mapOf(lockup['metadata'])['lockupMetadataViewModel']);
  final title = textOf(metadata['title']);
  if (!isPlayableTitle(title)) return null;
  return YouTubePlaylistItem(
    videoId: id,
    title: title!,
    artist: '',
    duration: clockInNode(lockup),
    thumbnailUrl: bestImageUrl(lockup['contentImage']),
  );
}

/// Continuation token for the next page, from either the current
/// `continuationItemRenderer` shape or the older `nextContinuationData` one.
String? nextContinuation(Object? json) {
  for (final node in walkJsonMaps(json)) {
    final renderer = node['continuationItemRenderer'];
    if (renderer is Map) {
      final endpoint = mapOf(renderer['continuationEndpoint']);
      final token = mapOf(endpoint['continuationCommand'])['token'];
      if (token is String && token.isNotEmpty) return token;
      final button = mapOf(mapOf(renderer['button'])['buttonRenderer']);
      final buttonToken =
          mapOf(mapOf(button['command'])['continuationCommand'])['token'];
      if (buttonToken is String && buttonToken.isNotEmpty) return buttonToken;
    }
    final legacy = node['nextContinuationData'];
    if (legacy is Map) {
      final token = legacy['continuation'];
      if (token is String && token.isNotEmpty) return token;
    }
  }
  return null;
}

// ---------------------------------------------------------------------------
// Import planning
// ---------------------------------------------------------------------------

/// What importing (or re-syncing) a remote playlist would change locally.
///
/// Additive on purpose: a sync never removes a track the user might have meant
/// to keep, so a playlist reorganised on YouTube can only grow here. Local
/// edits and ordering survive.
class YouTubePlaylistImportPlan {
  /// Remote order, first occurrence of each video, not present locally yet.
  final List<YouTubePlaylistItem> toAdd;

  /// Remote tracks already in the local playlist.
  final List<YouTubePlaylistItem> alreadyLocal;

  /// Remote tracks dropped because [planPlaylistImport] hit its limit.
  final int skippedForLimit;

  const YouTubePlaylistImportPlan({
    required this.toAdd,
    required this.alreadyLocal,
    this.skippedForLimit = 0,
  });

  bool get isNoOp => toAdd.isEmpty;

  int get addCount => toAdd.length;
}

YouTubePlaylistImportPlan planPlaylistImport({
  required List<YouTubePlaylistItem> remoteItems,
  required Set<String> localVideoIds,
  int maxNewItems = 600,
}) {
  final seen = <String>{};
  final toAdd = <YouTubePlaylistItem>[];
  final alreadyLocal = <YouTubePlaylistItem>[];
  var skipped = 0;

  for (final item in remoteItems) {
    if (!seen.add(item.videoId)) continue;
    if (localVideoIds.contains(item.videoId)) {
      alreadyLocal.add(item);
      continue;
    }
    if (toAdd.length >= maxNewItems) {
      skipped++;
      continue;
    }
    toAdd.add(item);
  }

  return YouTubePlaylistImportPlan(
    toAdd: List.unmodifiable(toAdd),
    alreadyLocal: List.unmodifiable(alreadyLocal),
    skippedForLimit: skipped,
  );
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// `Artist - Topic` is YouTube's auto-generated artist channel; the suffix is
/// noise in a music library.
String stripTopicSuffix(String raw) {
  var value = raw.trim();
  const suffix = ' - Topic';
  if (value.toLowerCase().endsWith(suffix.toLowerCase())) {
    value = value.substring(0, value.length - suffix.length).trim();
  }
  return value;
}

/// Visits every map in [root], parents before children and siblings in document
/// order. Response shapes move around; walking is what keeps this parser alive
/// across those changes.
Iterable<Map> walkJsonMaps(Object? root) sync* {
  final stack = <Object?>[root];
  while (stack.isNotEmpty) {
    final node = stack.removeLast();
    if (node is Map) {
      yield node;
      final children = node.values.toList();
      for (var i = children.length - 1; i >= 0; i--) {
        final child = children[i];
        if (child is Map || child is List) stack.add(child);
      }
    } else if (node is List) {
      for (var i = node.length - 1; i >= 0; i--) {
        final child = node[i];
        if (child is Map || child is List) stack.add(child);
      }
    }
  }
}

Map mapOf(Object? value) => value is Map ? value : const {};

/// InnerTube text fields are `{simpleText}`, `{runs: [{text}]}` or, in the newer
/// view models, `{content}`.
String? textOf(Object? node) {
  if (node is String) {
    final text = node.trim();
    return text.isEmpty ? null : text;
  }
  if (node is! Map) return null;
  for (final key in const ['simpleText', 'content', 'text']) {
    final value = node[key];
    if (value is String) {
      final text = value.trim();
      if (text.isNotEmpty) return text;
    }
  }
  final runs = node['runs'];
  if (runs is List) {
    final buffer = StringBuffer();
    for (final run in runs) {
      if (run is Map) buffer.write(run['text']?.toString() ?? '');
    }
    final text = buffer.toString().trim();
    if (text.isNotEmpty) return text;
  }
  return null;
}

/// Byline text, with the auto-generated `- Topic` suffix removed.
String artistOf(Object? node) {
  final text = textOf(node);
  if (text == null) return '';
  return stripTopicSuffix(text);
}

/// `3:52`, `1:02:03` -> [Duration]. Returns null for live streams and premieres,
/// whose length reads `LIVE` or is absent.
Duration? parseClock(String? raw) {
  if (raw == null) return null;
  final parts = raw.trim().split(':');
  if (parts.length < 2 || parts.length > 3) return null;
  var seconds = 0;
  for (final part in parts) {
    final value = int.tryParse(part.trim());
    if (value == null || value < 0) return null;
    seconds = seconds * 60 + value;
  }
  return seconds > 0 ? Duration(seconds: seconds) : null;
}

/// Largest image URL in a thumbnail/collection node.
String? bestImageUrl(Object? node) {
  String? best;
  var bestSize = -1;
  for (final map in walkJsonMaps(node)) {
    final url = map['url'];
    if (url is! String || url.isEmpty) continue;
    final size = intOf(map['width']) ?? intOf(map['height']) ?? 0;
    if (size >= bestSize) {
      best = url;
      bestSize = size;
    }
  }
  return best;
}

int? intOf(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '');
}

int? countOfText(String? text) {
  if (text == null) return null;
  final match =
      RegExp(r'([\d.,\s]+)\s*(video|track|song|item)', caseSensitive: false)
          .firstMatch(text);
  if (match == null) return null;
  final digits = match.group(1)!.replaceAll(RegExp(r'[^\d]'), '');
  return int.tryParse(digits);
}

/// First `count`-like text (`12 videos`) anywhere under [node].
int? countInNode(Object? node) {
  for (final map in walkJsonMaps(node)) {
    for (final value in map.values) {
      final text = value is String ? value : textOf(value);
      final count = countOfText(text);
      if (count != null) return count;
    }
  }
  return null;
}

/// First clock-shaped text (`3:52`) anywhere under [node], used for the view
/// models that only expose duration as a thumbnail overlay.
Duration? clockInNode(Object? node) {
  final clock = RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?$');
  for (final map in walkJsonMaps(node)) {
    for (final value in map.values) {
      final text = value is String ? value : textOf(value);
      if (text != null && clock.hasMatch(text)) {
        final parsed = parseClock(text);
        if (parsed != null) return parsed;
      }
    }
  }
  return null;
}

bool isPlayableTitle(String? title) {
  if (title == null) return false;
  final lower = title.trim().toLowerCase();
  if (lower.isEmpty) return false;
  return !lower.contains('deleted video') &&
      !lower.contains('private video') &&
      lower != '[private video]';
}

String? _playlistIdOf(Map node) {
  final direct = node['playlistId'];
  if (direct is String && direct.isNotEmpty) {
    final id = stripVl(direct);
    if (id.isNotEmpty) return id;
  }
  final navigation = mapOf(node['navigationEndpoint']);
  final browse = mapOf(navigation['browseEndpoint'])['browseId'];
  if (browse is String) {
    final id = stripVl(browse);
    if (id.isNotEmpty) return id;
  }
  final watch = mapOf(navigation['watchEndpoint'])['playlistId'];
  if (watch is String && watch.isNotEmpty) return watch;

  final command =
      mapOf(mapOf(node['rendererContext'])['commandContext'])['onTap'];
  final inner = mapOf(mapOf(command)['innertubeCommand']);
  final innerWatch = mapOf(inner['watchEndpoint'])['playlistId'];
  if (innerWatch is String && innerWatch.isNotEmpty) return innerWatch;
  final innerBrowse = mapOf(inner['browseEndpoint'])['browseId'];
  if (innerBrowse is String) {
    final id = stripVl(innerBrowse);
    if (id.isNotEmpty) return id;
  }
  return null;
}

/// Browse ids address a playlist as `VL<playlistId>`; stored ids are bare.
String stripVl(String raw) {
  final value = raw.trim();
  if (value.length > 2 && value.startsWith('VL')) return value.substring(2);
  return value;
}
