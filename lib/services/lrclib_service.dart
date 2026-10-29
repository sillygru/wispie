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
import 'shared_http_client.dart';

/// Lyrics client with music-utils as the primary API and direct LRCLIB as a
/// fallback.
class LrclibService {
  static const String _host = 'lrclib.net';
  static const Duration _timeout = Duration(seconds: 8);

  /// A response timeout never fires while a socket is still opening.
  static const Duration _connectTimeout = Duration(seconds: 6);

  /// Ceiling on the whole picker: partial results beat a spinner.
  static const Duration _collectBudget = Duration(seconds: 10);

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

  /// Every usable record for [song], best first, for the picker to choose from.
  ///
  /// Plain and timed records both belong here — the user is looking at a list,
  /// not asking to play the track — where [preferPlain] only decides which of
  /// two near-equal records wins.
  Future<List<LrclibResult>> findFor(
    Song song, {
    String? titleOverride,
    String? artistOverride,
    bool preferPlain = false,
  }) async {
    final artist = cleanTag(artistOverride ?? song.artist) ?? '';
    final title = cleanTag(titleOverride ?? song.title);
    if (title == null && artist.isEmpty) return const [];

    return _rankedCandidates(
      song,
      titleOverride: titleOverride,
      artistOverride: artistOverride,
      preferPlain: preferPlain,
    );
  }

  /// Asks every plausible reading of the tags, then ranks what came back.
  ///
  /// One reading is not enough for a streamed track. Its title carries an
  /// "Artist - " prefix and its artist tag is a channel name, so a field query
  /// built from those two finds nothing even when the words are right there.
  /// The picker used to ask exactly that one question and report "no results"
  /// for uploads the player could find lyrics for; both now go through here.
  Future<List<LrclibResult>> _rankedCandidates(
    Song song, {
    String? titleOverride,
    String? artistOverride,
    bool preferPlain = false,
  }) async {
    final collected = await _collectCandidates(
      song,
      titleOverride: titleOverride,
      artistOverride: artistOverride,
    );
    if (collected.results.isEmpty) return const [];

    return rankLrclibResults(
      collected.results,
      song.copyWith(
        title: collected.title,
        artist: collected.artist ?? song.artist,
      ),
      preferPlain: preferPlain,
    );
  }

  /// The candidates plus the title/artist the ranking should score them
  /// against: the primary reading of the tags, which is far more likely to name
  /// the release than the upload's own tags are.
  Future<
      ({
        List<LrclibResult> results,
        String title,
        String? artist,
      })> _collectCandidates(
    Song song, {
    String? titleOverride,
    String? artistOverride,
  }) async {
    const none = <LrclibResult>[];
    final rawTitle = cleanTag(titleOverride ?? song.title);
    if (rawTitle == null) {
      return (results: none, title: song.title, artist: null);
    }
    final artist = cleanTag(artistOverride ?? song.artist) ?? '';
    final queries = lyricsQueriesFor(
      title: rawTitle,
      artist: artist,
      remote: song.isRemote,
    );
    if (queries.isEmpty) {
      final cleaned = cleanSearchTitle(rawTitle, artist: artist);
      return (
        results: none,
        title: cleaned,
        artist: artist.isEmpty ? null : artist,
      );
    }
    final rankedAgainst = (
      title: queries.first.title,
      artist: queries.first.artist ?? (artist.isEmpty ? null : artist),
    );

    final album = cleanTag(song.album);
    final videoId = song.isYoutube ? song.remoteId : null;
    final found = <int, LrclibResult>{};

    void keep(Iterable<LrclibResult> results) {
      for (final result in results) {
        if (result.isUsable) found.putIfAbsent(result.id, () => result);
      }
    }

    // One deadline for both rounds.
    final deadline = DateTime.now().add(_collectBudget);

    // Three readings is enough to cover every tag shape a catalogue produces;
    // more only multiplies requests for records that would lose the ranking.
    final attempts = queries.take(3).toList();
    final lookups = <Future<void>>[];
    for (var i = 0; i < attempts.length; i++) {
      final query = attempts[i];
      final queryArtist = query.artist;
      if (queryArtist != null) {
        lookups.add(
          getExact(
            trackName: query.title,
            artistName: queryArtist,
            albumName: album,
            duration: song.duration,
            videoId: i == 0 ? videoId : null,
          ).then((result) {
            if (result != null) keep([result]);
          }).catchError((Object error) {
            stderr.writeln('Lyrics: exact lookup failed: $error');
          }),
        );
      }
      lookups.add(
        search(trackName: query.title, artistName: queryArtist)
            .then(keep)
            .catchError(
          (Object error) {
            stderr.writeln('Lyrics: search failed: $error');
          },
        ),
      );
    }
    await _settleWithin(lookups, _collectBudget);

    // Last resort for uploads whose title matches no field query; it only gets
    // what is left of the budget.
    if (found.isEmpty) {
      final freeText = <String>{
        for (final query in attempts)
          [query.title, query.artist].whereType<String>().join(' ').trim(),
      };
      await _settleWithin(
        [
          for (final query in freeText)
            searchFreeText(query).then(keep).catchError((Object error) {
              stderr.writeln('Lyrics: free-text search failed: $error');
            }),
        ],
        deadline.difference(DateTime.now()),
      );
    }

    return (
      results: found.values.toList(),
      title: rankedAgainst.title,
      artist: rankedAgainst.artist,
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

  Future<File> _cacheFileFor(Song song) =>
      CacheService.instance.getRemoteLyricsFile(song.filename);

  /// Best online lyrics for a track.
  ///
  /// A streamed track's tags are the uploader's, not the release's, so one
  /// lookup built from them misses most of the time. Every plausible reading of
  /// the tags is queried instead (see [lyricsQueriesFor]), in parallel — a
  /// sequential fallback chain spent tens of seconds to end up with nothing — and
  /// the video id rides along with the primary query, because the service
  /// rejects a request without a track name.
  ///
  /// The results are then ranked against the cleaned title, so duration and
  /// artist agreement decide. A timed record always beats an untimed one: a
  /// transcript with no timings would throw away the synced view.
  Future<LrclibResult?> fetchForSong(Song song) async {
    if (cleanTag(song.title) == null) return null;
    final ranked = await _rankedCandidates(song);
    if (ranked.isEmpty) return null;

    // A transcript with no timings would throw the synced view away, so a timed
    // record wins even when the ranking preferred an untimed one.
    final timed = ranked.where((r) => r.hasSynced || r.hasRichSync);
    return timed.isNotEmpty ? timed.first : ranked.first;
  }

  /// The optional word/syllable payload, without replacing local lyrics.
  ///
  /// Kept on disk beside the chosen lyrics: a streamed track has no file to
  /// write tags into and a local file has nowhere to put syllable timings, so
  /// the word view used to be re-fetched once per session per track and lost
  /// outright whenever the provider was down. A missing rich result is normal:
  /// callers keep line-synced lyrics.
  ///
  /// The in-memory map is static as well, because every lyrics view builds its
  /// own service: the sidebar and the player screen must agree, and a transient
  /// failure in one must not leave the other showing "no lyrics".
  Future<RichLyrics?> getRichSync(Song song) async {
    final key = song.filename;
    final lookup = _richSyncCache[key] ??= _readRichSync(song);
    final result = await lookup;
    // Only a lookup the providers actually answered is remembered: a track they
    // have no word timings for is asked about once per session rather than on
    // every open of the pane, while a timeout or a 5xx is retried next time.
    if (result.lyrics == null && !result.settled) _richSyncCache.remove(key);
    return result.lyrics;
  }

  Future<({RichLyrics? lyrics, bool settled})> _readRichSync(Song song) async {
    final file = await _richCacheFileFor(song);
    try {
      if (await file.exists()) {
        final saved =
            RichLyrics.fromJson(jsonDecode(await file.readAsString()));
        // Saved is settled: nothing to ask about until the file is gone.
        if (saved != null) return (lyrics: saved, settled: true);
      }
    } on Object catch (_) {
      // An unreadable entry is refetched below rather than trusted.
    }

    final fetched = await _fetchRichSync(song);
    final lyrics = fetched.lyrics;
    if (lyrics == null || lyrics.lines.isEmpty) {
      return (lyrics: null, settled: fetched.settled);
    }
    try {
      await file.parent.create(recursive: true);
      await file.writeAsString(jsonEncode(lyrics.toJson()));
    } on Object catch (error) {
      stderr.writeln('Lyrics: could not save word sync: $error');
    }
    return (lyrics: lyrics, settled: true);
  }

  Future<File> _richCacheFileFor(Song song) async {
    final digest = sha1.convert(utf8.encode(song.filename)).toString();
    final base = await CacheService.instance.getV3File('lyrics_cache');
    return File(p.join(base.parent.path, 'lyrics_cache', 'rich_$digest.json'));
  }

  static final Map<String, Future<({RichLyrics? lyrics, bool settled})>>
      _richSyncCache = {};

  /// Asks for the word payload, and reports whether the answer was definitive.
  ///
  /// [MusicUtilsStatus.transient] means nobody really answered — the tunnel was
  /// down, the request timed out — so the result must not be remembered either
  /// way. A 404, or a record that simply has no word timings, is an answer.
  Future<({RichLyrics? lyrics, bool settled})> _fetchRichSync(Song song) async {
    final rawTitle = cleanTag(song.title);
    final queries = rawTitle == null
        ? const <LyricsQuery>[]
        : lyricsQueriesFor(
            title: rawTitle,
            artist: cleanTag(song.artist) ?? '',
            remote: song.isRemote,
          );
    // Nothing to ask about, and nothing will change that by asking again.
    if (queries.isEmpty) return (lyrics: null, settled: true);
    final query = queries.first;
    final artistName = query.artist ?? '';

    final params = _getParams(
      trackName: query.title,
      artistName: artistName,
      albumName: cleanTag(song.album),
      duration: song.duration,
    );
    final videoId = song.isYoutube ? song.remoteId : null;
    var settled = false;
    if (videoId != null && videoId.isNotEmpty) {
      final byVideo = await _musicUtils.getJsonResult(
        '/lyrics/get',
        {...params, 'video_id': videoId},
      );
      settled |= byVideo.status != MusicUtilsStatus.transient;
      final result = _resultFromObject(byVideo.json);
      if (result?.richLyrics != null) {
        return (lyrics: result!.richLyrics, settled: true);
      }
    }

    final decoded = await _musicUtils.getJsonResult('/lyrics/get', params);
    settled |= decoded.status != MusicUtilsStatus.transient;
    final result = _resultFromObject(decoded.json);
    return (lyrics: result?.richLyrics, settled: settled);
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
    final direct = await _searchDirect({
      'track_name': trackName,
      if (artistName != null && artistName.isNotEmpty)
        'artist_name': artistName,
      if (albumName != null && albumName.isNotEmpty) 'album_name': albumName,
    });
    if (unifiedResults.isEmpty) return direct;

    // The service aggregates several providers, but it is not the whole list:
    // stopping at it hid every record lrclib.net has and the service does not
    // (a synced version of a track the service only has untimed, for example).
    // Only records with text nothing else already offers are appended.
    final known = unifiedResults
        .map((result) => (result.lyricsFor() ?? '').trim())
        .where((text) => text.isNotEmpty)
        .toSet();
    return [
      ...unifiedResults,
      ...direct.where((result) {
        final text = (result.lyricsFor() ?? '').trim();
        return text.isNotEmpty && known.add(text);
      }),
    ];
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
    // Pooled client: a fresh one per lookup re-paid the handshake.
    final client = SharedHttpClient.instance;
    try {
      final uri = Uri.https(_host, path, params);
      final request = await client.getUrl(uri).timeout(_connectTimeout);
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
    }
  }

  /// Waits for [futures] up to [budget], then keeps whatever arrived.
  static Future<void> _settleWithin(
    Iterable<Future<void>> futures,
    Duration budget,
  ) async {
    if (futures.isEmpty || budget <= Duration.zero) return;
    final safe = <Future<void>>[
      for (final future in futures)
        future.then<void>((_) {}, onError: (Object _, StackTrace __) {}),
    ];
    try {
      await Future.wait(safe).timeout(budget);
    } on TimeoutException catch (_) {
      // Partial results are the point.
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
