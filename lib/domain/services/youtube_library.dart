// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../data/rust/wispie_core.dart';
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
  return _parse('thumbnail', {'url': url, 'size': size})['url'] as String? ??
      url;
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
      // Only the result shelves: the page's discovery carousels name related
      // artists, which is not an answer to the query.
      var pageContainers = parseMusicContainers(json, shelvesOnly: true);
      if (pageContainers.isEmpty) {
        pageContainers = parseMusicContainers(json);
      }
      for (final container in pageContainers) {
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

/// One parsing request to the core, which owns every catalogue rule: the
/// containers move around often, and one walker that ignores unfamiliar shapes
/// is easier to keep alive in one place than in two languages.
Map<String, dynamic> _parse(String action, Map<String, Object?> request) {
  Map<String, dynamic>? reply;
  String? error;
  final code = WispieCore.run(
    {'command': 'youtube', 'action': action, ...request},
    onEvent: (kind, payload) {
      if (kind == WispieCore.eventItems) {
        final decoded = jsonDecode(payload);
        if (decoded is Map<String, dynamic>) reply = decoded;
      } else if (kind == WispieCore.eventError) {
        error =
            (jsonDecode(payload) as Map<String, dynamic>)['message'] as String?;
      }
    },
  );
  if (code != 0 || reply == null) {
    throw StateError('youtube $action failed: ${error ?? 'code $code'}');
  }
  return reply!;
}

YouTubePlaylistItem _itemFromCore(Map<String, dynamic> row) {
  final millis = (row['duration_ms'] as num?)?.toInt();
  return YouTubePlaylistItem(
    videoId: row['video_id'] as String? ?? '',
    title: row['title'] as String? ?? '',
    artist: row['artist'] as String? ?? '',
    duration: millis == null ? null : Duration(milliseconds: millis),
    thumbnailUrl: row['thumbnail_url'] as String?,
    position: (row['position'] as num?)?.toInt() ?? 0,
    viewCountText: row['view_count_text'] as String?,
  );
}

Map<String, Object?> _itemToCore(YouTubePlaylistItem item) => {
      'video_id': item.videoId,
      'title': item.title,
      'artist': item.artist,
      'duration_ms': item.duration?.inMilliseconds,
      'thumbnail_url': item.thumbnailUrl,
      'position': item.position,
      'view_count_text': item.viewCountText,
    };

YouTubeContainerKind _containerKindFromCore(Object? raw) => switch (raw) {
      'album' => YouTubeContainerKind.album,
      'playlist' => YouTubeContainerKind.playlist,
      'artist' => YouTubeContainerKind.artist,
      _ => throw StateError('unknown container kind $raw'),
    };

YouTubeContainer _containerFromCore(Map<String, dynamic> row) =>
    YouTubeContainer(
      id: row['id'] as String? ?? '',
      title: row['title'] as String? ?? '',
      subtitle: row['subtitle'] as String? ?? '',
      thumbnailUrl: row['thumbnail_url'] as String?,
      kind: _containerKindFromCore(row['kind']),
    );

List<YouTubePlaylistItem> _itemsFromCore(Object? rows) => [
      for (final row in rows as List? ?? const [])
        _itemFromCore(row as Map<String, dynamic>),
    ];

List<YouTubeContainer> _containersFromCore(Object? rows) => [
      for (final row in rows as List? ?? const [])
        _containerFromCore(row as Map<String, dynamic>),
    ];

/// The signed-in account header from `account/account_menu`.
YouTubeAccountProfile? parseAccountProfile(Object? json) {
  final profile = _parse('account_profile', {'json': json})['profile'];
  if (profile is! Map) return null;
  return YouTubeAccountProfile(
    channelId: profile['channel_id'] as String? ?? '',
    title: profile['title'] as String? ?? '',
    avatarUrl: profile['avatar_url'] as String?,
  );
}

/// Playlists from a `FEplaylists` browse response, in page order.
///
/// Liked videos come back as the `LL` playlist on some layouts; the core drops
/// it because the API exposes it as its own synthetic entry.
List<YouTubeAccountPlaylist> parseAccountPlaylists(Object? json) {
  final rows = _parse('account_playlists', {'json': json})['playlists'];
  return [
    for (final row in rows as List? ?? const [])
      YouTubeAccountPlaylist(
        id: (row as Map<String, dynamic>)['id'] as String? ?? '',
        title: row['title'] as String? ?? '',
        itemCount: (row['item_count'] as num?)?.toInt(),
        thumbnailUrl: row['thumbnail_url'] as String?,
      ),
  ];
}

/// Tracks from a playlist or liked-videos browse response, in page order,
/// de-duplicated.
List<YouTubePlaylistItem> parsePlaylistVideoItems(Object? json) =>
    _itemsFromCore(_parse('playlist_videos', {'json': json})['items']);

/// Tracks from a YouTube Music browse or search response, in page order.
///
/// Music pages wrap results in `musicResponsiveListItemRenderer` (shelf rows)
/// or `musicTwoRowItemRenderer` (carousels). Both carry a watch endpoint for a
/// playable track and a browse id for an album or playlist, so only entries
/// with a watch endpoint are kept: everything else is a container.
List<YouTubePlaylistItem> parseMusicTracks(Object? json,
        {String? artistHint}) =>
    _itemsFromCore(_parse('music_tracks', {
      'json': json,
      'artist_hint': artistHint,
    })['items']);

/// Container rows (albums, playlists, artists) from a music search or browse
/// page, in page order.
///
/// The same two renderers carry tracks and places; a row with no watch endpoint
/// but a browse id that names an album, playlist or channel is a place.
List<YouTubeContainer> parseMusicContainers(
  Object? json, {
  bool shelvesOnly = false,
}) =>
    _containersFromCore(_parse('music_containers', {
      'json': json,
      'shelves_only': shelvesOnly,
    })['containers']);

List<YouTubeContainer> _ofKind(
  List<YouTubeContainer> all,
  YouTubeContainerKind kind,
) =>
    List<YouTubeContainer>.unmodifiable(all.where((c) => c.kind == kind));

/// The sort chips a music page offers (`Popularity`, `Release date`, ...).
///
/// The labels are the catalogue's own, so they need no translation, and each
/// chip carries the token that asks YouTube for that order.
List<YouTubeSortOption> parseMusicSortOptions(Object? json) {
  final rows = _parse('sort_options', {'json': json})['options'];
  return [
    for (final row in rows as List? ?? const [])
      YouTubeSortOption(
        label: (row as Map<String, dynamic>)['label'] as String? ?? '',
        params: row['params'] as String? ?? '',
        selected: row['selected'] == true,
      ),
  ];
}

/// Name and avatar from an artist page's header.
({String name, String? thumbnailUrl}) parseArtistHeader(Object? json) {
  final header = _parse('artist_header', {'json': json})['header'];
  if (header is! Map) return (name: '', thumbnailUrl: null);
  return (
    name: header['name'] as String? ?? '',
    thumbnailUrl: header['thumbnail_url'] as String?,
  );
}

/// Title, byline artist and artwork from an album or playlist header.
({String title, String artist, String? thumbnailUrl}) parseCollectionHeader(
  Object? json,
) {
  final header = _parse('collection_header', {'json': json})['header'];
  if (header is! Map) return (title: '', artist: '', thumbnailUrl: null);
  return (
    title: header['title'] as String? ?? '',
    artist: header['artist'] as String? ?? '',
    thumbnailUrl: header['thumbnail_url'] as String?,
  );
}

/// Channel name from a view model's metadata rows.
String artistFromMetadata(Object? node) =>
    _parse('artist_from_metadata', {'node': node})['artist'] as String? ?? '';

/// Continuation token for the next page, from either the current
/// `continuationItemRenderer` shape or the older `nextContinuationData` one.
String? nextContinuation(Object? json) =>
    _parse('next_continuation', {'json': json})['token'] as String?;

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
  final reply = _parse('import_plan', {
    'items': [for (final item in remoteItems) _itemToCore(item)],
    'local_ids': localVideoIds.toList(),
    'max_new_items': maxNewItems,
  });
  return YouTubePlaylistImportPlan(
    toAdd: List.unmodifiable(_itemsFromCore(reply['to_add'])),
    alreadyLocal: List.unmodifiable(_itemsFromCore(reply['already_local'])),
    skippedForLimit: (reply['skipped_for_limit'] as num?)?.toInt() ?? 0,
  );
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------

/// `Artist - Topic` is YouTube's auto-generated artist channel; the suffix is
/// noise in a music library.
String stripTopicSuffix(String raw) =>
    _parse('strip_topic', {'value': raw})['value'] as String? ?? raw;

/// Browse ids address a playlist as `VL<playlistId>`; stored ids are bare.
String stripVl(String raw) =>
    _parse('strip_vl', {'value': raw})['value'] as String? ?? raw;

/// `3:52`, `1:02:03` -> [Duration]. Returns null for live streams and
/// premieres, whose length reads `LIVE` or is absent.
Duration? parseClock(String? raw) {
  if (raw == null) return null;
  final seconds = (_parse('clock', {'value': raw})['seconds'] as num?)?.toInt();
  return seconds == null ? null : Duration(seconds: seconds);
}

bool isPlayableTitle(String? title) =>
    _parse('playable_title', {'value': title})['playable'] == true;
