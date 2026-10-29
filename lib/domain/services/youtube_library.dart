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

/// Thumbnail URL for a video.
///
/// `hqdefault` (480x360) is the smallest still that is not already upscaled and
/// exists for every video. Display surfaces ask for `maxresdefault` on top of it
/// and fall back to this URL when a clip has no maxres rendition; `mqdefault` is
/// 320x180 and looks soft behind a full-size player cover.
String youtubeThumbnailUrl(String videoId) =>
    'https://i.ytimg.com/vi/$videoId/hqdefault.jpg';

/// A YouTube-hosted thumbnail requested at a larger size.
///
/// Catalogue rows carry their size in the URL itself (`...=w120-h120-l90-rj`,
/// `...=s120`), so the id-only still of [youtubeThumbnailUrl] cannot be used
/// here: the suffix has to be rewritten in place. YouTube serves 720 across the
/// board, so this asks for that instead of guessing from the widget size.
String upscaleThumbnailUrl(String url, {int size = 720}) {
  if (url.isEmpty) return url;
  final boxed = RegExp(r'=w\d+-h\d+');
  if (boxed.hasMatch(url)) return url.replaceFirst(boxed, '=w$size-h$size');
  final square = RegExp(r'=s(\d+)(?=-|$)').firstMatch(url);
  if (square == null) return url;
  final current = int.tryParse(square.group(1) ?? '');
  if (current != null && current >= size) return url;
  return url.replaceRange(square.start, square.end, '=s$size');
}

class YouTubePlaylistItem {
  final String videoId;
  final String title;
  final String artist;
  final Duration? duration;
  final String? thumbnailUrl;
  final int position;

  /// `36M plays`, exactly as the catalogue prints it, or null when the row
  /// carried no count.
  final String? viewCountText;

  const YouTubePlaylistItem({
    required this.videoId,
    required this.title,
    required this.artist,
    this.duration,
    this.thumbnailUrl,
    this.position = 0,
    this.viewCountText,
  });
}

/// What a catalogue row opens instead of playing.
enum YouTubeContainerKind { album, playlist, artist }

/// A row that is a place rather than a track: an album, a playlist or an
/// artist. [id] is the browse id the row's endpoint carries.
class YouTubeContainer {
  final String id;
  final String title;

  /// YouTube's own byline, e.g. `Album • 2021` or `Artist`.
  final String subtitle;
  final String? thumbnailUrl;
  final YouTubeContainerKind kind;

  const YouTubeContainer({
    required this.id,
    required this.title,
    this.subtitle = '',
    this.thumbnailUrl,
    required this.kind,
  });
}

/// One search page: playable tracks plus the albums, playlists and artists the
/// same page offered.
class YouTubeMusicSearch {
  final List<YouTubePlaylistItem> tracks;
  final List<YouTubeContainer> albums;
  final List<YouTubeContainer> playlists;
  final List<YouTubeContainer> artists;

  const YouTubeMusicSearch({
    this.tracks = const [],
    this.albums = const [],
    this.playlists = const [],
    this.artists = const [],
  });

  static const YouTubeMusicSearch empty = YouTubeMusicSearch();

  bool get isEmpty =>
      tracks.isEmpty && albums.isEmpty && playlists.isEmpty && artists.isEmpty;
}

/// A sort chip YouTube itself offers on an artist page. The label is the
/// catalogue's, already localised, and [params] is the token that asks for it.
class YouTubeSortOption {
  final String label;
  final String params;
  final bool selected;

  const YouTubeSortOption({
    required this.label,
    this.params = '',
    this.selected = false,
  });
}

/// An artist page: their songs in the order YouTube ranks them, the albums and
/// singles the page links, and its own sort chips.
class YouTubeArtistPage {
  final String id;
  final String name;
  final String? thumbnailUrl;
  final List<YouTubePlaylistItem> songs;
  final List<YouTubeContainer> albums;
  final List<YouTubeSortOption> sorts;

  const YouTubeArtistPage({
    required this.id,
    required this.name,
    this.thumbnailUrl,
    this.songs = const [],
    this.albums = const [],
    this.sorts = const [],
  });
}

class YouTubeAlbumPage {
  final String id;
  final String title;
  final String artist;
  final String? thumbnailUrl;
  final List<YouTubePlaylistItem> tracks;

  const YouTubeAlbumPage({
    required this.id,
    required this.title,
    this.artist = '',
    this.thumbnailUrl,
    this.tracks = const [],
  });
}

/// The public key YouTube ships inside its own web pages. It is not a secret
/// and not tied to a project: every browser sends it, and it is the reason this
/// integration needs no setup from the user.
const String kYouTubeWebApiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

/// Used only when the live client version cannot be read. YouTube rejects a
/// badly stale version, so the client re-resolves it on every launch.
const String kYouTubeWebClientVersionFallback = '2.20261026.01.00';

/// YouTube Music's web client, which only ever answers with music. Its key is
/// as public as the www one; using it with the right client name is what keeps
/// trailers and vlogs out of the feed.
const String kYouTubeMusicApiKey = 'AIzaSyC9XL3ZjWddXya6X74dJoCTL-WEYFDNX30';

const String kYouTubeMusicClientVersionFallback = '1.20261020.01.00';

const String kYouTubeWebUserAgent =
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
    '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';

/// Supplies the cookies to sign with, or null when the user is signed out.
typedef YouTubeSessionProvider = Future<YouTubeWebSession?> Function();

/// Persists InnerTube responses. Kept abstract so this layer stays free of
/// Flutter and file-system concerns; the app supplies a disk-backed store.
abstract class YouTubeResponseStore {
  /// The stored body for [key], or null when it is older than [maxAge].
  /// [allowStale] returns an expired body, which is what a failed refresh wants.
  Future<Map<String, dynamic>?> read(
    String key,
    Duration maxAge, {
    bool allowStale = false,
  });

  Future<void> write(String key, Map<String, dynamic> body);

  /// Drops a stored body. Stores that keep nothing worth deleting can ignore it.
  Future<void> remove(String key) async {}
}

/// Which YouTube web client a request speaks as.
///
/// Both are InnerTube and both accept the same cookie signature; they differ in
/// host, origin, key and client identity, and in what they will return. The www
/// client answers with everything YouTube hosts, while `WEB_REMIX` (YouTube
/// Music) only ever returns music.
enum _ApiClient {
  web(
    host: 'www.youtube.com',
    origin: YouTubeWebSession.origin,
    clientName: 'WEB',
    headerId: 1,
    apiKey: kYouTubeWebApiKey,
    versionFallback: kYouTubeWebClientVersionFallback,
    requiresSession: true,
  ),
  music(
    host: 'music.youtube.com',
    origin: YouTubeWebSession.musicOrigin,
    clientName: 'WEB_REMIX',
    headerId: 67,
    apiKey: kYouTubeMusicApiKey,
    versionFallback: kYouTubeMusicClientVersionFallback,
    requiresSession: false,
  );

  const _ApiClient({
    required this.host,
    required this.origin,
    required this.clientName,
    required this.headerId,
    required this.apiKey,
    required this.versionFallback,
    required this.requiresSession,
  });

  final String host;
  final String origin;
  final String clientName;
  final int headerId;
  final String apiKey;
  final String versionFallback;

  /// Account data needs a cookie session; the music catalogue does not.
  final bool requiresSession;
}

class YouTubeLibraryApi {
  YouTubeLibraryApi({
    required YouTubeSessionProvider session,
    HttpClient? client,
    Uri? baseUrl,
    Uri? musicBaseUrl,
    Uri? versionUrl,
    String? clientVersion,
    Duration timeout = const Duration(seconds: 20),
    DateTime Function()? clock,
    YouTubeResponseStore? store,
  })  : _session = session,
        _client = client ?? HttpClient(),
        _base = baseUrl ?? Uri.parse('https://www.youtube.com/youtubei/v1/'),
        _musicBase = musicBaseUrl ??
            baseUrl ??
            Uri.parse('https://music.youtube.com/youtubei/v1/'),
        _versionUrl = versionUrl,
        _pinnedVersion = clientVersion != null,
        _timeout = timeout,
        _clock = clock ?? DateTime.now,
        _store = store {
    if (clientVersion != null) {
      for (final client in _ApiClient.values) {
        _versions[client] = clientVersion;
      }
    }
  }

  final YouTubeSessionProvider _session;
  final YouTubeResponseStore? _store;
  final HttpClient _client;
  final Uri _base;
  final Uri _musicBase;
  final Uri? _versionUrl;
  final bool _pinnedVersion;
  final Duration _timeout;
  final DateTime Function() _clock;

  final Map<_ApiClient, String> _versions = {};
  final Set<_ApiClient> _resolvedVersions = {};

  /// True once the www client version came from YouTube itself rather than from
  /// [kYouTubeWebClientVersionFallback]. Diagnostics and the probe use it to
  /// tell "resolved" from "fell back".
  bool get hasLiveClientVersion => _resolvedVersions.contains(_ApiClient.web);

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
        cacheFor: const Duration(minutes: 10),
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

  /// The account's YouTube Music home, in shelf order.
  ///
  /// Deliberately YouTube *Music* and not youtube.com's `FEwhat_to_watch`: the
  /// www home mixes in gaming, vlogs and trailers, and a music player's feed
  /// has no use for them. Every renderer on this page is a song, video, album or
  /// playlist, and [parseMusicTracks] only keeps the playable tracks.
  ///
  /// A signed-out visitor gets the same page's charts and popular picks.
  Future<List<YouTubePlaylistItem>> musicHomeFeed({int maxPages = 2}) {
    return _collectBrowseFeed(
      'FEmusic_home',
      client: _ApiClient.music,
      maxPages: maxPages,
      cacheFor: const Duration(minutes: 30),
    );
  }

  /// Searches the music catalogue. Unlike a www search, every hit is a song or
  /// music video, so seeding this with an artist the listener already plays
  /// cannot return a trailer.
  ///
  /// An artist query answers with that artist's top songs, and those rows omit
  /// the artist because the page header already names them. [artistHint] fills
  /// it back in; without it those rows would rank as unknown artists.
  Future<List<YouTubePlaylistItem>> musicSearch(
    String query, {
    int maxPages = 1,
    String? artistHint,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return const [];

    final items = <YouTubePlaylistItem>[];
    final seen = <String>{};
    final usedContinuations = <String>{};
    String? continuation;

    for (var page = 0; page < maxPages; page++) {
      final json = await _post(
        'search',
        continuation == null
            ? {'query': normalized}
            : {'continuation': continuation},
        client: _ApiClient.music,
        cacheFor: const Duration(minutes: 30),
      );
      for (final item in parseMusicTracks(json, artistHint: artistHint)) {
        if (!seen.add(item.videoId)) continue;
        items.add(
          YouTubePlaylistItem(
            videoId: item.videoId,
            title: item.title,
            artist: item.artist,
            duration: item.duration,
            thumbnailUrl: item.thumbnailUrl,
            position: items.length,
            viewCountText: item.viewCountText,
          ),
        );
      }
      final next = nextContinuation(json);
      if (next == null || !usedContinuations.add(next)) break;
      continuation = next;
    }
    return items;
  }

  /// Search, keeping the albums, playlists and artists the page offered.
  ///
  /// [musicSearch] throws those rows away because only tracks are playable;
  /// this is the same request with the containers kept, so a query for an album
  /// name answers with the album.
  Future<YouTubeMusicSearch> musicSearchAll(
    String query, {
    int maxPages = 1,
    String? artistHint,
  }) async {
    final normalized = query.trim();
    if (normalized.isEmpty) return YouTubeMusicSearch.empty;

    final tracks = <YouTubePlaylistItem>[];
    final seenVideos = <String>{};
    final containers = <YouTubeContainer>[];
    final seenContainers = <String>{};
    final usedContinuations = <String>{};
    String? continuation;

    for (var page = 0; page < maxPages; page++) {
      final json = await _post(
        'search',
        continuation == null
            ? {'query': normalized}
            : {'continuation': continuation},
        client: _ApiClient.music,
        cacheFor: const Duration(minutes: 30),
      );
      for (final item in parseMusicTracks(json, artistHint: artistHint)) {
        if (!seenVideos.add(item.videoId)) continue;
        tracks.add(
          YouTubePlaylistItem(
            videoId: item.videoId,
            title: item.title,
            artist: item.artist,
            duration: item.duration,
            thumbnailUrl: item.thumbnailUrl,
            position: tracks.length,
            viewCountText: item.viewCountText,
          ),
        );
      }
      for (final container in parseMusicContainers(json)) {
        if (!seenContainers.add(container.id)) continue;
        containers.add(container);
      }
      final next = nextContinuation(json);
      if (next == null || !usedContinuations.add(next)) break;
      continuation = next;
    }

    return YouTubeMusicSearch(
      tracks: List<YouTubePlaylistItem>.unmodifiable(tracks),
      albums: _ofKind(containers, YouTubeContainerKind.album),
      playlists: _ofKind(containers, YouTubeContainerKind.playlist),
      artists: _ofKind(containers, YouTubeContainerKind.artist),
    );
  }

  /// An artist page. [params] is one of the page's own sort tokens, which is
  /// how "most popular" and "oldest" are ordered: YouTube ranks them itself
  /// rather than the app guessing years out of a byline.
  Future<YouTubeArtistPage> artist(
    String browseId, {
    String? params,
    int maxPages = 2,
  }) async {
    final id = browseId.trim();
    if (id.isEmpty) {
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.notFound,
        'YouTube artist id is missing.',
      );
    }

    final first = await _musicBrowse(
      {
        'browseId': id,
        if (params != null && params.isNotEmpty) 'params': params
      },
      cacheFor: const Duration(minutes: 20),
    );

    final songs = <YouTubePlaylistItem>[];
    final seen = <String>{};
    void collect(Map<String, dynamic> json, String? hint) {
      for (final item in parseMusicTracks(json, artistHint: hint)) {
        if (!seen.add(item.videoId)) continue;
        songs.add(
          YouTubePlaylistItem(
            videoId: item.videoId,
            title: item.title,
            artist: item.artist,
            duration: item.duration,
            thumbnailUrl: item.thumbnailUrl,
            position: songs.length,
            viewCountText: item.viewCountText,
          ),
        );
      }
    }

    final header = parseArtistHeader(first);
    collect(first, header.name.isEmpty ? null : header.name);

    String? continuation = nextContinuation(first);
    final used = <String>{};
    for (var page = 1; page < maxPages && continuation != null; page++) {
      final token = continuation;
      if (!used.add(token)) break;
      final next = await _musicBrowse(
        {'continuation': token},
        cacheFor: const Duration(minutes: 20),
      );
      collect(next, header.name.isEmpty ? null : header.name);
      continuation = nextContinuation(next);
    }

    return YouTubeArtistPage(
      id: id,
      name: header.name,
      thumbnailUrl: header.thumbnailUrl,
      songs: List<YouTubePlaylistItem>.unmodifiable(songs),
      albums: List<YouTubeContainer>.unmodifiable(
        parseMusicContainers(first)
            .where((c) => c.kind == YouTubeContainerKind.album),
      ),
      sorts: List<YouTubeSortOption>.unmodifiable(parseMusicSortOptions(first)),
    );
  }

  /// An album's tracks, in the album's own order.
  Future<YouTubeAlbumPage> album(String browseId, {int maxPages = 2}) async {
    final id = browseId.trim();
    if (id.isEmpty) {
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.notFound,
        'YouTube album id is missing.',
      );
    }

    final first = await _musicBrowse(
      {'browseId': id},
      cacheFor: const Duration(minutes: 20),
    );
    final header = parseCollectionHeader(first);

    final tracks = <YouTubePlaylistItem>[];
    final seen = <String>{};
    void collect(Map<String, dynamic> json) {
      for (final item in parseMusicTracks(
        json,
        artistHint: header.artist.isEmpty ? null : header.artist,
      )) {
        if (!seen.add(item.videoId)) continue;
        tracks.add(
          YouTubePlaylistItem(
            videoId: item.videoId,
            title: item.title,
            artist: item.artist,
            duration: item.duration,
            thumbnailUrl: item.thumbnailUrl,
            position: tracks.length,
            viewCountText: item.viewCountText,
          ),
        );
      }
    }

    collect(first);
    String? continuation = nextContinuation(first);
    final used = <String>{};
    for (var page = 1; page < maxPages && continuation != null; page++) {
      final token = continuation;
      if (!used.add(token)) break;
      final next = await _musicBrowse(
        {'continuation': token},
        cacheFor: const Duration(minutes: 20),
      );
      collect(next);
      continuation = nextContinuation(next);
    }

    return YouTubeAlbumPage(
      id: id,
      title: header.title,
      artist: header.artist,
      thumbnailUrl: header.thumbnailUrl,
      tracks: List<YouTubePlaylistItem>.unmodifiable(tracks),
    );
  }

  Future<Map<String, dynamic>> _musicBrowse(
    Map<String, Object?> body, {
    required Duration cacheFor,
  }) =>
      _post('browse', body, client: _ApiClient.music, cacheFor: cacheFor);

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

  /// The www client version that will be sent, resolved once per instance.
  /// Exposed so diagnostics and the probe can verify what YouTube is told.
  Future<String> resolvedClientVersion() => _clientVersion(_ApiClient.web);

  Future<List<YouTubePlaylistItem>> _collectPlaylist(
    String browseId, {
    required int maxPages,
  }) =>
      _collectBrowseFeed(
        browseId,
        maxPages: maxPages,
        cacheFor: const Duration(minutes: 20),
      );

  Future<List<YouTubePlaylistItem>> _collectBrowseFeed(
    String browseId, {
    required int maxPages,
    required Duration cacheFor,
    _ApiClient client = _ApiClient.web,
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
        client: client,
        cacheFor: cacheFor,
      );
      final parsed = client == _ApiClient.music
          ? parseMusicTracks(json)
          : parsePlaylistVideoItems(json);
      for (final item in parsed) {
        if (!seen.add(item.videoId)) continue;
        items.add(
          YouTubePlaylistItem(
            videoId: item.videoId,
            title: item.title,
            artist: item.artist,
            duration: item.duration,
            thumbnailUrl: item.thumbnailUrl,
            position: items.length,
            viewCountText: item.viewCountText,
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
    Map<String, Object?> body, {
    _ApiClient client = _ApiClient.web,
    Duration cacheFor = Duration.zero,
  }) async {
    final session = await _session();
    final usable = session != null && session.isUsable;
    // The music client is anonymous-friendly: its home page and search answer
    // without an account, which is what keeps the feed working signed out.
    if (!usable && client.requiresSession) {
      throw const YouTubeLibraryException(
        YouTubeLibraryErrorKind.unauthorized,
        'Not signed in to a YouTube account.',
      );
    }

    final store = _store;
    final cacheKey = '${client.host}:$endpoint:${jsonEncode(body)}';
    if (store != null && cacheFor > Duration.zero) {
      final cached = await store.read(cacheKey, cacheFor);
      if (cached != null) return cached;
    }

    final base = client == _ApiClient.music ? _musicBase : _base;
    final uri = base.replace(
      path: '${base.path.endsWith('/') ? base.path : '${base.path}/'}'
          '$endpoint',
      queryParameters: {
        'key': client.apiKey,
        'prettyPrint': 'false',
      },
    );

    try {
      return await _request(
        endpoint,
        body,
        uri,
        usable ? session : null,
        client,
        cacheKey,
        store,
        cacheFor,
      );
    } on YouTubeLibraryException {
      // A refresh that fails should not blank a screen the cache can fill.
      if (store != null && cacheFor > Duration.zero) {
        final stale = await store.read(cacheKey, cacheFor, allowStale: true);
        if (stale != null) return stale;
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _request(
    String endpoint,
    Map<String, Object?> body,
    Uri uri,
    YouTubeWebSession? session,
    _ApiClient client,
    String cacheKey,
    YouTubeResponseStore? store,
    Duration cacheFor,
  ) async {
    var attempt = 0;
    while (true) {
      final version = await _clientVersion(client);
      final payload = {
        'context': _context(version, client),
        ...body,
      };
      final response = await _send(uri, payload, session, client, version);
      final status = response.status;

      if (status >= HttpStatus.ok && status < HttpStatus.multipleChoices) {
        final json = response.json;
        if (json is Map) {
          final result = Map<String, dynamic>.from(json);
          if (store != null && cacheFor > Duration.zero) {
            await store.write(cacheKey, result);
          }
          return result;
        }
        throw const YouTubeLibraryException(
          YouTubeLibraryErrorKind.invalidResponse,
          'YouTube returned an unexpected response.',
        );
      }

      // A 400 from InnerTube is usually a client version YouTube no longer
      // accepts. Re-resolve once rather than making the user restart.
      if (status == HttpStatus.badRequest && attempt == 0 && !_pinnedVersion) {
        _versions.remove(client);
        final store = _store;
        if (store != null) await store.remove(_versionKey(client));
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
    YouTubeWebSession? session,
    _ApiClient client,
    String version,
  ) async {
    try {
      final request = await _client.postUrl(uri).timeout(_timeout);
      request.headers
        ..set(HttpHeaders.contentTypeHeader, 'application/json')
        ..set('X-YouTube-Client-Name', '${client.headerId}')
        ..set('X-YouTube-Client-Version', version)
        ..set('X-Goog-Api-Key', client.apiKey)
        ..set('Origin', client.origin)
        ..set('X-Origin', client.origin)
        ..set('Referer', '${client.origin}/')
        ..set(HttpHeaders.userAgentHeader, kYouTubeWebUserAgent)
        ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
      if (session != null) {
        for (final header
            in session.authHeaders(_clock(), origin: client.origin).entries) {
          request.headers.set(header.key, header.value);
        }
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
  Future<String> _clientVersion(_ApiClient client) async {
    final cached = _versions[client];
    if (cached != null) return cached;

    // Reading the version means downloading a whole YouTube page. Doing that
    // on every launch is what made the first feed of a session slow, so the
    // answer is kept for a day; a version YouTube has retired surfaces as a 400
    // and is re-resolved by the retry in [_post].
    final stored = await _storedClientVersion(client);
    if (stored != null) {
      _versions[client] = stored;
      return stored;
    }

    final resolved =
        await _resolveClientVersion(client) ?? client.versionFallback;
    _versions[client] = resolved;
    await _storeClientVersion(client, resolved);
    return resolved;
  }

  static const Duration _clientVersionMaxAge = Duration(hours: 24);

  String _versionKey(_ApiClient client) => 'client-version:${client.host}';

  Future<String?> _storedClientVersion(_ApiClient client) async {
    if (_pinnedVersion) return null;
    final store = _store;
    if (store == null) return null;
    try {
      final body = await store.read(_versionKey(client), _clientVersionMaxAge);
      final version = body?['version'];
      return version is String && version.isNotEmpty ? version : null;
    } on Object catch (error) {
      stderr
          .writeln('YouTube: could not read the stored client version: $error');
      return null;
    }
  }

  Future<void> _storeClientVersion(_ApiClient client, String version) async {
    if (_pinnedVersion) return;
    final store = _store;
    if (store == null) return;
    try {
      await store.write(_versionKey(client), {'version': version});
    } on Object catch (error) {
      stderr.writeln('YouTube: could not store the client version: $error');
    }
  }

  Future<String?> _resolveClientVersion(_ApiClient client) async {
    // The homepage embeds the version in its `ytcfg`; `sw.js_data` used to
    // carry it and is kept as a second source because YouTube moves this
    // around. A caller that supplied a URL (tests, diagnostics) gets only that.
    final configured = _versionUrl;
    final sources = configured != null
        ? <Uri>[configured]
        : <Uri>[
            Uri.parse('https://${client.host}/'),
            Uri.parse('https://${client.host}/sw.js_data'),
          ];

    for (final uri in sources) {
      try {
        final text = await _getText(uri);
        final match = RegExp(r'INNERTUBE_CLIENT_VERSION"?\s*:\s*"?([0-9.]+)')
            .firstMatch(text);
        if (match != null) {
          _resolvedVersions.add(client);
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

  Map<String, Object?> _context(String version, _ApiClient client) => {
        'client': {
          'clientName': client.clientName,
          'clientVersion': version,
          'hl': 'en',
          'gl': 'US',
          'userAgent': kYouTubeWebUserAgent,
          'originalUrl': '${client.origin}/',
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

/// Tracks from a YouTube Music browse or search response, in page order.
///
/// Music pages wrap results in `musicResponsiveListItemRenderer` (shelf rows)
/// or `musicTwoRowItemRenderer` (carousels). Both carry a watch endpoint for a
/// playable track and a browse id for an album or playlist, so only entries
/// with a watch endpoint are kept: everything else is a container.
List<YouTubePlaylistItem> parseMusicTracks(Object? json, {String? artistHint}) {
  final result = <YouTubePlaylistItem>[];
  final seen = <String>{};

  for (final node in walkJsonMaps(json)) {
    final responsive = node['musicResponsiveListItemRenderer'];
    final twoRow = node['musicTwoRowItemRenderer'];
    YouTubePlaylistItem? item;
    if (responsive is Map) {
      item = _itemFromMusicResponsive(responsive);
    } else if (twoRow is Map) {
      item = _itemFromMusicTwoRow(twoRow);
    }
    if (item == null) continue;
    if (item.artist.isEmpty && artistHint != null && artistHint.isNotEmpty) {
      item = YouTubePlaylistItem(
        videoId: item.videoId,
        title: item.title,
        artist: stripTopicSuffix(artistHint),
        duration: item.duration,
        thumbnailUrl: item.thumbnailUrl,
        position: item.position,
        viewCountText: item.viewCountText,
      );
    }
    if (!seen.add(item.videoId)) continue;
    result.add(
      YouTubePlaylistItem(
        videoId: item.videoId,
        title: item.title,
        artist: item.artist,
        duration: item.duration,
        thumbnailUrl: item.thumbnailUrl,
        position: result.length,
        viewCountText: item.viewCountText,
      ),
    );
  }
  return result;
}

/// Container rows (albums, playlists, artists) from a music search or browse
/// page, in page order.
///
/// The same two renderers carry tracks and places; a row with no watch endpoint
/// but a browse id that names an album, playlist or channel is a place.
List<YouTubeContainer> parseMusicContainers(Object? json) {
  final result = <YouTubeContainer>[];
  final seen = <String>{};

  for (final node in walkJsonMaps(json)) {
    final twoRow = node['musicTwoRowItemRenderer'];
    final responsive = node['musicResponsiveListItemRenderer'];
    final YouTubeContainer? container = twoRow is Map
        ? _containerFromMusicTwoRow(twoRow)
        : responsive is Map
            ? _containerFromMusicResponsive(responsive)
            : null;
    if (container == null) continue;
    if (!seen.add(container.id)) continue;
    result.add(container);
  }
  return result;
}

/// The sort chips a music page offers (`Popularity`, `Release date`, ...).
///
/// The labels are the catalogue's own, so they need no translation, and each
/// chip carries the token that asks YouTube for that order.
List<YouTubeSortOption> parseMusicSortOptions(Object? json) {
  final result = <YouTubeSortOption>[];
  final seen = <String>{};

  for (final node in walkJsonMaps(json)) {
    for (final entry in node.entries) {
      if (!entry.key.toString().toLowerCase().contains('sortfilterbutton')) {
        continue;
      }
      final renderer = mapOf(entry.value);
      final label = textOf(renderer['title']) ?? textOf(renderer['label']);
      if (label == null || label.isEmpty) continue;
      if (!seen.add(label)) continue;
      final bool selected = renderer['isSelected'] == true ||
          renderer['selected'] == true ||
          mapOf(renderer['icon'])['iconType'] == 'CHECK';
      result.add(
        YouTubeSortOption(
          label: label,
          params: renderer['params']?.toString() ?? '',
          selected: selected,
        ),
      );
    }
  }
  // The chip YouTube marks as current leads, so the default label is the order
  // the songs arrived in.
  final selectedIndex = result.indexWhere((option) => option.selected);
  if (selectedIndex > 0) {
    final selected = result.removeAt(selectedIndex);
    result.insert(0, selected);
  }
  return result;
}

/// Name and avatar from an artist page's header.
({String name, String? thumbnailUrl}) parseArtistHeader(Object? json) {
  const keys = [
    'musicImmersiveHeaderRenderer',
    'musicVisualHeaderRenderer',
    'musicResponsiveHeaderRenderer',
    'musicDetailHeaderRenderer',
  ];
  for (final node in walkJsonMaps(json)) {
    for (final key in keys) {
      final header = node[key];
      if (header is! Map) continue;
      final name = textOf(header['title']);
      if (name == null || name.isEmpty) continue;
      return (
        name: stripTopicSuffix(name),
        thumbnailUrl: bestImageUrl(header['thumbnail']) ??
            bestImageUrl(header['foregroundThumbnail']),
      );
    }
  }
  return (name: '', thumbnailUrl: null);
}

/// Title, byline artist and artwork from an album or playlist header.
({String title, String artist, String? thumbnailUrl}) parseCollectionHeader(
  Object? json,
) {
  const keys = [
    'musicResponsiveHeaderRenderer',
    'musicDetailHeaderRenderer',
    'musicEditablePlaylistDetailHeaderRenderer',
  ];
  for (final node in walkJsonMaps(json)) {
    for (final key in keys) {
      final header = node[key];
      if (header is! Map) continue;
      final title = textOf(header['title']);
      if (title == null || title.isEmpty) continue;

      var artist = '';
      for (final field in const ['straplineTextOne', 'subtitle', 'subtitle2']) {
        final byline = textOf(header[field]);
        if (byline == null) continue;
        for (final raw in byline.split('•')) {
          final part = raw.trim();
          if (part.isEmpty) continue;
          if (_musicTypeLabels.contains(part.toLowerCase())) continue;
          if (RegExp(r'^\d{4}$').hasMatch(part)) continue;
          if (_viewCountPattern.hasMatch(part)) continue;
          if (_relativeTimePattern.hasMatch(part)) continue;
          artist = stripTopicSuffix(part);
          break;
        }
        if (artist.isNotEmpty) break;
      }

      return (
        title: title,
        artist: artist,
        thumbnailUrl: bestImageUrl(header['thumbnail']),
      );
    }
  }
  return (title: '', artist: '', thumbnailUrl: null);
}

List<YouTubeContainer> _ofKind(
  List<YouTubeContainer> all,
  YouTubeContainerKind kind,
) =>
    List<YouTubeContainer>.unmodifiable(all.where((c) => c.kind == kind));

YouTubeContainer? _containerFromMusicTwoRow(Map renderer) {
  final id = _browseIdOf(renderer);
  if (id == null) return null;
  final kind = _containerKindOf(id);
  if (kind == null) return null;
  final title = textOf(renderer['title']);
  if (title == null || title.isEmpty) return null;
  return YouTubeContainer(
    id: id,
    title: title,
    subtitle: textOf(renderer['subtitle']) ?? '',
    thumbnailUrl: _largeThumbnail(renderer),
    kind: kind,
  );
}

YouTubeContainer? _containerFromMusicResponsive(Map renderer) {
  if (_isTrackRow(renderer)) return null;
  final id = _browseIdOf(renderer);
  if (id == null) return null;
  final kind = _containerKindOf(id);
  if (kind == null) return null;
  final title = textOf(_flexColumn(renderer, 0));
  if (title == null || title.isEmpty) return null;

  // The section above the row already names the kind, so `Album` is dropped
  // from the byline and the row reads `Aurora • 2016`.
  final parts = <String>[];
  for (var column = 1; column <= 2; column++) {
    final text = textOf(_flexColumn(renderer, column));
    if (text == null || text.isEmpty) continue;
    for (final raw in text.split('•')) {
      final part = raw.trim();
      if (part.isEmpty) continue;
      if (_musicTypeLabels.contains(part.toLowerCase())) continue;
      parts.add(part);
    }
  }
  return YouTubeContainer(
    id: id,
    title: title,
    subtitle: parts.join(' • '),
    thumbnailUrl: _largeThumbnail(renderer['thumbnail']),
    kind: kind,
  );
}

/// The page a row opens, if it opens one. A radio playlist (`RD...`) is a
/// playback queue rather than a place, so only `VL` ids count.
String? _browseIdOf(Map renderer) {
  final navigation = mapOf(renderer['navigationEndpoint']);
  final browse = mapOf(navigation['browseEndpoint'])['browseId']?.toString();
  if (browse != null && browse.isNotEmpty) return browse;

  final playlist = mapOf(navigation['watchEndpoint'])['playlistId']?.toString();
  if (playlist != null && playlist.startsWith('VL')) return playlist;

  final button = mapOf(
    mapOf(
        mapOf(mapOf(renderer['overlay'])['musicItemThumbnailOverlayRenderer'])[
            'content'])['musicPlayButtonRenderer'],
  );
  final play = mapOf(button['playNavigationEndpoint']);
  final playBrowse = mapOf(play['browseEndpoint'])['browseId']?.toString();
  if (playBrowse != null && playBrowse.isNotEmpty) return playBrowse;
  final playPlaylist = mapOf(play['watchEndpoint'])['playlistId']?.toString();
  if (playPlaylist != null && playPlaylist.startsWith('VL')) {
    return playPlaylist;
  }

  final command =
      mapOf(mapOf(renderer['rendererContext'])['commandContext'])['onTap'];
  final inner = mapOf(mapOf(command)['innertubeCommand']);
  final innerBrowse = mapOf(inner['browseEndpoint'])['browseId']?.toString();
  if (innerBrowse != null && innerBrowse.isNotEmpty) return innerBrowse;
  return null;
}

/// Albums, playlists and channels each have their own browse id prefix.
YouTubeContainerKind? _containerKindOf(String id) {
  if (id.startsWith('MPRE')) return YouTubeContainerKind.album;
  if (id.startsWith('VL')) return YouTubeContainerKind.playlist;
  if (id.startsWith('UC')) return YouTubeContainerKind.artist;
  return null;
}

YouTubePlaylistItem? _itemFromMusicResponsive(Map renderer) {
  final id = _watchVideoId(renderer) ??
      mapOf(mapOf(renderer['playlistItemData']))['videoId']?.toString() ??
      '';
  if (id.isEmpty) return null;
  // A search page mixes albums, playlists, artists, profiles, podcasts and
  // episodes into the same row renderer, and all of them carry a play button.
  // Only the type label tells a track from a container.
  if (!_isTrackRow(renderer)) return null;
  final title = textOf(_flexColumn(renderer, 0));
  if (!isPlayableTitle(title)) return null;
  // The metadata columns shift with the shelf: a search hit reads
  // `Song • 4:11` then `36M plays`, a playlist row reads `Artist • Album` then
  // `4:11`, so each column is read for whatever it happens to hold.
  var artist = '';
  Duration? duration;
  String? viewCountText;
  for (var column = 1; column <= 4; column++) {
    final byline = _musicByline(_flexColumn(renderer, column));
    if (artist.isEmpty) artist = byline.artist;
    duration ??= byline.duration;
    viewCountText ??= byline.viewCountText;
  }
  // On a search hit the artist is nowhere in the columns: the only copy is in
  // the play button's accessibility label. Without it the row shows Unknown
  // artist, which is what half of the catalogue's search results used to do.
  if (artist.isEmpty) artist = _artistFromPlayLabel(renderer['overlay']);
  duration ??= clockInNode(renderer['overlay']);
  return YouTubePlaylistItem(
    videoId: id,
    title: title!,
    artist: artist,
    duration: duration,
    thumbnailUrl: _largeThumbnail(renderer['thumbnail']),
    viewCountText: viewCountText,
  );
}

/// A row's artwork at a row's size.
///
/// Catalogue URLs are tiny (`=w60-h60`), so they are rewritten to the smallest
/// rendition that still looks sharp in a 52dp row. Surfaces that draw the cover
/// large (the player) ask for more through `CoverPath.sharperUrl` themselves, so
/// asking for 720 here spent four times the bytes on every list row in the app.
String? _largeThumbnail(Object? node) {
  final url = bestImageUrl(node);
  return url == null ? null : upscaleThumbnailUrl(url, size: 320);
}

final RegExp _viewCountPattern =
    RegExp(r'^[\d.,]+\s*[KMB]?\s*(?:plays?|views?)$', caseSensitive: false);

/// The `Play <title> - <artist>` label YouTube Music puts on a row's play
/// button. The artist is the last ` - ` segment, because titles may contain one.
String _artistFromPlayLabel(Object? overlay) {
  for (final node in walkJsonMaps(overlay)) {
    final label = textOf(mapOf(node['accessibilityData'])['label']);
    if (label == null || !label.startsWith('Play ')) continue;
    final parts = label.substring(5).split(' - ');
    if (parts.length < 2) continue;
    final artist = stripTopicSuffix(parts.last.trim());
    if (artist.isNotEmpty) return artist;
  }
  return '';
}

YouTubePlaylistItem? _itemFromMusicTwoRow(Map renderer) {
  final id = _watchVideoId(renderer) ?? '';
  if (id.isEmpty) return null;
  final title = textOf(renderer['title']);
  if (!isPlayableTitle(title)) return null;
  final byline = _musicByline(renderer['subtitle']);
  return YouTubePlaylistItem(
    videoId: id,
    title: title!,
    artist: byline.artist,
    duration: byline.duration,
    thumbnailUrl: _largeThumbnail(renderer),
    viewCountText: byline.viewCountText,
  );
}

/// The watch endpoint a music renderer opens, or null when it opens a browse
/// page (which is an album, an artist or a playlist rather than a track).
String? _watchVideoId(Map renderer) {
  final candidates = <Object?>[
    mapOf(renderer['navigationEndpoint'])['watchEndpoint'],
    mapOf(
        mapOf(mapOf(renderer['overlay'])['musicItemThumbnailOverlayRenderer'])[
            'content'])['musicPlayButtonRenderer'],
  ];
  for (final candidate in candidates) {
    final watch = candidate;
    if (watch is! Map) continue;
    final direct = watch['videoId']?.toString();
    if (direct != null && direct.isNotEmpty) return direct;
    final endpoint = mapOf(watch['playNavigationEndpoint'])['watchEndpoint'];
    final nested = mapOf(endpoint)['videoId']?.toString();
    if (nested != null && nested.isNotEmpty) return nested;
    final queue = mapOf(watch['playlistItemData'])['videoId']?.toString();
    if (queue != null && queue.isNotEmpty) return queue;
  }
  return null;
}

Object? _flexColumn(Map renderer, int index) {
  final columns = renderer['flexColumns'];
  if (columns is! List || columns.length <= index) return null;
  final column = mapOf(columns[index]);
  final flex = mapOf(column['musicResponsiveListItemFlexColumnRenderer']);
  return flex['text'];
}

/// Artist, duration and view count from a music byline
/// (`Artist • Album • 3:52`, or `Song • 4:11`), any of which may be absent.
({String artist, Duration? duration, String? viewCountText}) _musicByline(
  Object? node,
) {
  final text = textOf(node);
  if (text == null) return (artist: '', duration: null, viewCountText: null);

  Duration? duration;
  String artist = '';
  String? viewCountText;
  for (final raw in text.split('•')) {
    final part = raw.trim();
    if (part.isEmpty) continue;
    if (RegExp(r'^\d{1,2}:\d{2}(?::\d{2})?$').hasMatch(part)) {
      duration ??= parseClock(part);
      continue;
    }
    if (_musicTypeLabels.contains(part.toLowerCase())) continue;
    if (_viewCountPattern.hasMatch(part)) {
      viewCountText ??= part;
      continue;
    }
    if (_relativeTimePattern.hasMatch(part)) continue;
    if (RegExp(r'^\d{4}$').hasMatch(part)) continue;
    if (artist.isEmpty) artist = stripTopicSuffix(part);
  }
  return (artist: artist, duration: duration, viewCountText: viewCountText);
}

final RegExp _relativeTimePattern =
    RegExp(r'\b(?:ago|premiere[sd]?|watching)\b', caseSensitive: false);

/// Words the music catalogue puts in the second row where an artist would be.
const Set<String> _musicTypeLabels = {
  'song',
  'video',
  'music video',
  'single',
  'album',
  'ep',
  'playlist',
  'artist',
  'profile',
  'podcast',
  'episode',
};

/// Type labels that name something the player can actually play as itself.
/// Anything else on a row is a container worth at least two levels of tapping.
const Set<String> _trackTypeLabels = {'song', 'video', 'music video'};

/// True unless the row labels itself as a container. Rows that label nothing
/// are kept: an untyped row predates the label and has always been playable.
bool _isTrackRow(Map renderer) {
  final byline = textOf(_flexColumn(renderer, 1));
  if (byline == null) return true;
  final label = byline.split('•').first.trim().toLowerCase();
  if (!_musicTypeLabels.contains(label)) return true;
  return _trackTypeLabels.contains(label);
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
    thumbnailUrl: _largeThumbnail(renderer['thumbnail']),
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
    thumbnailUrl: _largeThumbnail(renderer['thumbnail']),
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
    artist: artistFromMetadata(metadata['metadata']),
    duration: clockInNode(lockup),
    thumbnailUrl: _largeThumbnail(lockup['contentImage']),
  );
}

/// Channel name from a view model's metadata rows.
///
/// The first row holds the channel and then views/age; only the channel is a
/// byline, so anything that reads as a count or a relative time is skipped.
String artistFromMetadata(Object? node) {
  final rows = mapOf(node)['metadataRows'];
  if (rows is! List) return '';
  for (final row in rows) {
    final parts = mapOf(row)['metadataParts'];
    if (parts is! List) continue;
    for (final part in parts) {
      final text = textOf(mapOf(part)['text']);
      if (text == null || text.isEmpty) continue;
      if (RegExp(r'\b(views?|watching|ago|premiere[sd]?)\b',
              caseSensitive: false)
          .hasMatch(text)) {
        continue;
      }
      if (RegExp(r'^[\d.,]+[KMB]?$', caseSensitive: false).hasMatch(text)) {
        continue;
      }
      return stripTopicSuffix(text);
    }
  }
  return '';
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
