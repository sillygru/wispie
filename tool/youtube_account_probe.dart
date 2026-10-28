// SPDX-License-Identifier: GPL-3.0-only
//
// End-to-end probe for the YouTube account integration.
//
//   dart run tool/youtube_account_probe.dart
//
// It drives the shipping protocol code (cookie parsing, SAPISIDHASH signing,
// InnerTube request construction, response walking, import planning) against a
// fake YouTube that speaks the real wire format, then checks the live endpoints
// as far as it can without an account.
//
// Artifact: build/youtube_account_probe.json (exit code 1 on any failure).
//
// Manual pass, once a real account is available:
//   1. Sign in at youtube.com in a browser, copy the `Cookie` request header of
//      any youtube.com request.
//   2. Account screen -> "Use cookies instead" -> paste -> expect the account
//      card with your channel name.
//   3. Import a small playlist, play a track, check it appears in Insights.
//   4. Add a track on YouTube, press Sync on the playlist row: only the new
//      track is added.
//   5. Sign out, sign in again through the in-app browser: Google asks for the
//      account again (the WebView jar is cleared), and the imported playlists
//      are still there.

import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:wispie/domain/models/lrclib_result.dart';
import 'package:wispie/domain/services/lrclib_match.dart';
import 'package:wispie/domain/services/lrclib_query.dart';
import 'package:wispie/domain/services/youtube_library.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/domain/services/taste_model.dart';
import 'package:wispie/domain/services/youtube_music_feed.dart';
import 'package:wispie/domain/services/youtube_session.dart';

final List<Map<String, Object?>> _results = [];
int _passed = 0;
int _failed = 0;
int _skipped = 0;

void check(String name, bool condition, {Object? detail}) {
  if (condition) {
    _passed++;
    _results.add({'check': name, 'ok': true});
    stdout.writeln('  ok   $name');
  } else {
    _failed++;
    _results.add({'check': name, 'ok': false, 'detail': detail?.toString()});
    stdout.writeln('  FAIL $name${detail == null ? '' : ' -> $detail'}');
  }
}

void skip(String name, String reason) {
  _skipped++;
  _results.add({'check': name, 'skipped': true, 'detail': reason});
  stdout.writeln('  skip $name ($reason)');
}

Future<void> main() async {
  final started = DateTime.now();
  stdout.writeln('YouTube account probe');

  _cookieParsing();
  _signature();
  await _protocol();
  await _live();

  final artifact = File('build/youtube_account_probe.json');
  await artifact.parent.create(recursive: true);
  await artifact.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'generatedAt': started.toIso8601String(),
      'passed': _passed,
      'failed': _failed,
      'skipped': _skipped,
      'checks': _results,
    }),
  );

  stdout.writeln(
    '\n$_passed passed, $_failed failed, $_skipped skipped '
    '(${DateTime.now().difference(started).inMilliseconds} ms)',
  );
  stdout.writeln('artifact: ${artifact.path}');
  if (_failed > 0) exitCode = 1;
}

// ---------------------------------------------------------------------------
// Cookies
// ---------------------------------------------------------------------------

void _cookieParsing() {
  stdout.writeln('\nCookie jar parsing');

  final header = YouTubeCookieParser.parse(
    'Cookie: SAPISID=AbCdEf123456; __Secure-3PAPISID=ZzYy; SID=g.a000; '
    'HSID=xyz; Path=/; Domain=.youtube.com; Secure; HttpOnly; SameSite=None',
  );
  check(
      'header: keeps the sign-in cookies', header['SAPISID'] == 'AbCdEf123456');
  check('header: keeps the 3P secret', header['__Secure-3PAPISID'] == 'ZzYy');
  check('header: keeps ordinary cookies', header['SID'] == 'g.a000');
  check(
    'header: drops attributes',
    !header.containsKey('Path') &&
        !header.containsKey('Domain') &&
        !header.containsKey('Secure') &&
        !header.containsKey('HttpOnly'),
  );

  final netscape = YouTubeCookieParser.parse(
    '# Netscape HTTP Cookie File\n'
    '#HttpOnly_.youtube.com\tTRUE\t/\tTRUE\t1893456000\tSAPISID\tNetscapeSid\n'
    '.youtube.com\tTRUE\t/\tFALSE\t1893456000\tPREF\thl=en\n'
    '.example.com\tTRUE\t/\tFALSE\t1893456000\tSAPISID\tWrongDomain\n',
  );
  check(
      'netscape: reads an HttpOnly row', netscape['SAPISID'] == 'NetscapeSid');
  check('netscape: reads a plain row', netscape['PREF'] == 'hl=en');
  check(
      'netscape: ignores other sites', !netscape.containsValue('WrongDomain'));

  final json = YouTubeCookieParser.parse(
    '[{"name":"SAPISID","value":"JsonSid","domain":".youtube.com"},'
    '{"name":"NID","value":"google-only","domain":".google.com"}]',
  );
  check('json: reads a youtube.com cookie', json['SAPISID'] == 'JsonSid');
  check('json: ignores google.com cookies', !json.containsKey('NID'));

  check(
    'empty input parses to nothing',
    YouTubeCookieParser.parse('   ').isEmpty,
  );
  check(
    'a jar without SAPISID is not a session',
    YouTubeWebSession.fromCookies({'PREF': 'hl=en'}) == null,
  );

  final session = YouTubeWebSession.fromCookies(header)!;
  check(
    'session: cookie header round-trips',
    session.cookieHeader.contains('SAPISID=AbCdEf123456') &&
        session.cookieHeader.contains('; '),
  );
  check(
    'session: stored JSON reloads',
    YouTubeWebSession.fromJson(jsonDecode(jsonEncode(session.toJson())))!
            .cookies['SAPISID'] ==
        'AbCdEf123456',
  );
  check(
    'session: merge keeps both jars',
    session
            .merge(YouTubeWebSession.fromCookies({'SAPISID': 'new', 'X': '1'})!)
            .cookies['X'] ==
        '1',
  );
  check(
    'session: domain test accepts youtube.com',
    YouTubeCookieParser.isYouTubeDomain('.youtube.com') &&
        YouTubeCookieParser.isYouTubeDomain('youtube.com'),
  );
  check(
    'session: domain test rejects lookalikes',
    !YouTubeCookieParser.isYouTubeDomain('youtube.com.example'),
  );
}

// ---------------------------------------------------------------------------
// Signature
// ---------------------------------------------------------------------------

void _signature() {
  stdout.writeln('\nSAPISIDHASH');

  final session = YouTubeWebSession.fromCookies({
    'SAPISID': 'AbCdEf123456',
    'SID': 'g.a000',
  })!;
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);

  // Independently computed with openssl:
  //   printf '1700000000 AbCdEf123456 https://www.youtube.com' | openssl sha1
  const expected =
      'SAPISIDHASH 1700000000_1ec1c4870f839c96c43a35bfdad66d8b9a65720d';
  final header = session.authorizationHeader(now);
  check(
    'matches the sha1 of "<ts> <sapisid> <origin>"',
    header == expected,
    detail: header,
  );

  final later =
      session.authorizationHeader(now.add(const Duration(minutes: 5)));
  check('timestamp changes the signature', later != header);
  check(
    'uses the 3P secret when SAPISID is absent',
    YouTubeWebSession.fromCookies({'__Secure-3PAPISID': 'ThreeP'})!
        .authorizationHeader(now)
        .endsWith(
          '_${sha1.convert(utf8.encode('1700000000 ThreeP https://www.youtube.com'))}',
        ),
  );

  final headers = session.authHeaders(now);
  check('header: Authorization', headers['Authorization'] == expected);
  check('header: Cookie', headers['Cookie']!.contains('SAPISID=AbCdEf123456'));
  check('header: account index', headers['X-Goog-AuthUser'] == '0');
  check(
    'header: second account index is forwarded',
    YouTubeWebSession(cookies: const {'SAPISID': 'x'}, authUser: 2)
            .authHeaders(now)['X-Goog-AuthUser'] ==
        '2',
  );
}

// ---------------------------------------------------------------------------
// Protocol against a fake YouTube
// ---------------------------------------------------------------------------

Future<void> _protocol() async {
  final server = FakeYouTube();
  await server.start();
  final session = YouTubeWebSession.fromCookies({
    'SAPISID': 'AbCdEf123456',
    'SID': 'g.a000',
    'PREF': 'hl=en',
  })!;

  YouTubeLibraryApi api() => YouTubeLibraryApi(
        session: () async => session,
        baseUrl: server.base,
        versionUrl: server.versionUrl,
        timeout: const Duration(seconds: 10),
      );

  try {
    stdout.writeln('\nAccount request shape');
    server.reset();
    server.handler = (call) => (status: 200, json: _accountMenu());
    final profile = await api().account();
    final call = server.calls.last;

    check('profile: title', profile?.title == 'Nova Listener',
        detail: profile?.title);
    check('profile: channel id', profile?.channelId == 'UC1234567890');
    check(
      'profile: largest avatar',
      profile?.avatarUrl == 'https://yt3.example/s176',
      detail: profile?.avatarUrl,
    );
    check('request: endpoint',
        call.path.endsWith('youtubei/v1/account/account_menu'));
    check('request: API key header',
        call.headers['x-goog-api-key'] == kYouTubeWebApiKey);
    check('request: API key query', call.query['key'] == kYouTubeWebApiKey);
    check('request: web client name',
        call.headers['x-youtube-client-name'] == '1');
    check(
      'request: version resolved from the config endpoint',
      call.headers['x-youtube-client-version'] == '2.20260101.00.00',
      detail: call.headers['x-youtube-client-version'],
    );
    check('request: config page was read', server.configRequests >= 1);
    check('request: origin header',
        call.headers['origin'] == 'https://www.youtube.com');
    check(
      'request: signature',
      RegExp(r'^SAPISIDHASH \d{10}_[0-9a-f]{40}$')
          .hasMatch(call.headers['authorization'] ?? ''),
      detail: call.headers['authorization'],
    );
    check('request: cookies',
        (call.headers['cookie'] ?? '').contains('SAPISID='));
    check('request: auth user', call.headers['x-goog-authuser'] == '0');
    check(
      'request: context version matches the header',
      mapOf(mapOf(call.body['context'])['client'])['clientVersion'] ==
          '2.20260101.00.00',
      detail: mapOf(mapOf(call.body['context'])['client'])['clientVersion'],
    );
    check(
      'request: body asks for WEB',
      mapOf(mapOf(call.body['context'])['client'])['clientName'] == 'WEB',
    );
    check('request: user agent present',
        (call.headers['user-agent'] ?? '').contains('Chrome'));

    stdout.writeln('\nAccount playlists');
    server.reset();
    server.handler = (call) {
      if (call.body['continuation'] == 'FE1') {
        return (status: 200, json: _feplaylistsPage(_feSecondPage));
      }
      return (status: 200, json: _feplaylistsPage(_feFirstPage));
    };
    final playlists = await api().playlists();
    final ids = playlists.map((p) => p.id).toList();
    check('grid: lockup shape', ids.contains('PLlockup1'));
    check('grid: legacy grid shape', ids.contains('PLgrid2'));
    check(
        'grid: classic shape, VL prefix stripped', ids.contains('UUclassic3'));
    check('grid: second page via continuation', ids.contains('PLpage2'));
    check(
      'grid: liked (LL) folded into the synthetic entry',
      !ids.contains('LL') && ids.last == kLikedVideosPlaylistId,
    );
    check('grid: video lockups ignored', !ids.contains('vidOnly'));
    check(
      'grid: count from view-model metadata',
      playlists.firstWhere((p) => p.id == 'PLlockup1').itemCount == 23,
      detail: playlists.firstWhere((p) => p.id == 'PLlockup1').itemCount,
    );
    check(
      'grid: count from "1 video"',
      playlists.firstWhere((p) => p.id == 'PLgrid2').itemCount == 1,
    );
    check(
      'grid: title from runs',
      playlists.firstWhere((p) => p.id == 'UUclassic3').title == 'Classic',
    );
    check(
      'grid: thumbnail is the largest source',
      playlists.firstWhere((p) => p.id == 'PLlockup1').thumbnailUrl ==
          'https://i.ytimg.com/pl/PLlockup1/hqdefault.jpg',
    );
    check(
      'grid: first request asked for the playlist aggregation',
      server.browseCalls.first.body['browseId'] == 'FEplaylist_aggregation',
      detail: server.browseCalls.first.body['browseId'],
    );
    check('grid: second page asked with a continuation token',
        server.calls.any((c) => c.body['continuation'] == 'FE1'));

    stdout.writeln('\nLiked videos paging');
    server.reset();
    server.handler = (call) {
      if (call.body['continuation'] == 'C1') {
        return (status: 200, json: _playlistPage(_likedSecondPage));
      }
      return (
        status: 200,
        json: _playlistPage(_likedFirstPage, continuation: 'C1')
      );
    };
    final liked = await api().likedVideos();
    check(
      'liked: browses VLLL',
      server.browseCalls.first.body['browseId'] == 'VLLL',
      detail: server.browseCalls.first.body['browseId'],
    );
    check('liked: both pages', liked.length == 4, detail: liked.length);
    check(
      'liked: playlist order',
      liked.map((i) => i.videoId).join(',') ==
          'vidOne,vidLockup,vidFive,vidSix',
      detail: liked.map((i) => i.videoId).toList(),
    );
    check('liked: positions renumbered', liked[3].position == 3);
    check('liked: duration from lengthText',
        liked[0].duration == const Duration(seconds: 232));
    check('liked: long duration',
        liked[2].duration == const Duration(seconds: 3723));
    check('liked: lockup duration from the overlay',
        liked[1].duration == const Duration(seconds: 260));
    check('liked: " - Topic" stripped from the artist',
        liked[0].artist == 'Aurora',
        detail: liked[0].artist);
    check(
      'liked: deleted and private videos dropped',
      !liked.any((i) => i.videoId == 'vidDeleted') &&
          !liked.any((i) => i.videoId == 'vidPrivate'),
    );

    stdout.writeln('\nPlaylist items');
    server.reset();
    server.handler = (call) => (status: 200, json: _playlistPage(_mixedPage));
    final items = await api().playlistItems('PLmixed');
    check(
      'items: browses VL<playlistId>',
      server.browseCalls.first.body['browseId'] == 'VLPLmixed',
      detail: server.browseCalls.first.body['browseId'],
    );
    check('items: reads classic playlist videos',
        items.any((i) => i.videoId == 'vidOne'));
    check(
      'items: reads a video lockup with an overlay duration',
      items.firstWhere((i) => i.videoId == 'vidLockup').duration ==
          const Duration(seconds: 260),
    );
    check('items: de-duplicates repeated ids',
        items.where((i) => i.videoId == 'vidOne').length == 1);
    check(
      'items: ids are filename-safe',
      items.every((i) => RegExp(r'^[A-Za-z0-9_-]+$').hasMatch(i.videoId)),
    );

    server.reset();
    await api().playlistItems('VLPLmixed');
    check('items: already-VL ids are not double-prefixed',
        server.calls.last.body['browseId'] == 'VLPLmixed',
        detail: server.calls.last.body['browseId']);

    stdout.writeln('\nFailure modes');
    server.reset();
    server.handler =
        (call) => (status: 401, json: const {'error': 'unauthorized'});
    check(
      '401 -> unauthorized',
      await _kindOf(() => api().playlists()) ==
          YouTubeLibraryErrorKind.unauthorized,
    );

    server.reset();
    server.handler =
        (call) => (status: 403, json: const {'error': 'forbidden'});
    check(
      '403 -> unauthorized',
      await _kindOf(() => api().playlists()) ==
          YouTubeLibraryErrorKind.unauthorized,
    );

    server.reset();
    server.handler = (call) => (status: 429, json: const {});
    check(
      '429 -> rate limited',
      await _kindOf(() => api().playlists()) ==
          YouTubeLibraryErrorKind.rateLimited,
    );

    server.reset();
    server.handler = (call) => (status: 500, json: const {});
    check(
      '500 -> other',
      await _kindOf(() => api().playlists()) == YouTubeLibraryErrorKind.other,
    );

    server.reset();
    server.handler = (call) => (status: 404, json: const {});
    check(
      '404 -> not found',
      await _kindOf(() => api().playlistItems('PLmissing')) ==
          YouTubeLibraryErrorKind.notFound,
    );

    server.reset();
    server.handler = (call) => (status: 200, json: '<html>not json</html>');
    check(
      'unparseable body -> invalid response',
      await _kindOf(() => api().playlists()) ==
          YouTubeLibraryErrorKind.invalidResponse,
    );

    stdout.writeln('\nStale client version');
    server.reset();
    var browseAttempts = 0;
    server.handler = (call) {
      if (call.path.endsWith('/browse')) {
        browseAttempts++;
        if (browseAttempts == 1) {
          server.clientVersion = '2.20270000.00.00';
          return (status: 400, json: const {'error': 'bad client version'});
        }
        // No continuation, so the retry is the only other browse request.
        return (status: 200, json: _feplaylistsPage(_feSecondPage));
      }
      return (status: 200, json: _accountMenu());
    };
    final recovered = await api().playlists();
    final browseCalls = server.browseCalls;
    check('400 triggers a re-resolved version and one retry',
        browseCalls.length == 2,
        detail: browseCalls.length);
    check(
      'retry uses the new version',
      browseCalls.length == 2 &&
          browseCalls.last.headers['x-youtube-client-version'] ==
              '2.20270000.00.00',
      detail: browseCalls.isEmpty
          ? null
          : browseCalls.last.headers['x-youtube-client-version'],
    );
    check('retry succeeds', recovered.length > 1);

    stdout.writeln('\nContinuation guard');
    server.reset();
    server.handler = (call) => (
          status: 200,
          json: _playlistPage(_likedFirstPage, continuation: 'LOOP')
        );
    final looped = await api().likedVideos();
    check('a repeating continuation stops the pager',
        server.browseCalls.length == 2,
        detail: server.browseCalls.length);
    check('looping page is parsed once', looped.length == 2,
        detail: looped.length);

    stdout.writeln('\nLyrics queries');
    final uploadQueries = lyricsQueriesFor(
      title: 'Aurora - Runaway (Official Video)',
      artist: 'Aurora - Topic',
      remote: true,
    );
    check(
      'queries: the title\'s own artist beats the channel',
      uploadQueries.first.title == 'Runaway' &&
          uploadQueries.first.artist == 'Aurora',
      detail: '${uploadQueries.first.title} / ${uploadQueries.first.artist}',
    );
    check(
      'queries: the channel is tried as well',
      uploadQueries.any((q) => q.artist == 'Aurora - Topic'),
      detail: uploadQueries.map((q) => q.artist).toList(),
    );
    check(
      'queries: title alone is a fallback',
      uploadQueries.any((q) => q.artist == null && q.title == 'Runaway'),
      detail: uploadQueries.map((q) => '${q.title}|${q.artist}').toList(),
    );
    check(
      'queries: each reading appears once',
      uploadQueries.length ==
          {
            for (final q in uploadQueries) '${q.title}|${q.artist}',
          }.length,
      detail: uploadQueries.length,
    );
    check(
      'queries: a titled upload with no artist prefix is not mangled',
      lyricsQueriesFor(
            title: 'Midnight City (Official Video)',
            artist: 'M83',
            remote: true,
          ).first.title ==
          'Midnight City',
    );
    check(
      'queries: local files get a single tag query',
      lyricsQueriesFor(title: 'Runaway', artist: 'Aurora').length == 1,
    );
    check(
      'queries: an empty title asks for nothing',
      lyricsQueriesFor(title: '  ', artist: 'Aurora', remote: true).isEmpty,
    );

    stdout.writeln('\nLyrics ranking');
    final remoteSong = Song(
      title: 'Runaway',
      artist: 'Aurora',
      album: '',
      filename: 'youtube:abc123',
      url: '',
      source: SongSource.youtube,
      remoteId: 'abc123',
      duration: const Duration(seconds: 200),
    );
    LrclibResult lyricRecord(int id,
            {String? synced, String? plain, int seconds = 200}) =>
        LrclibResult(
          id: id,
          trackName: 'Runaway',
          artistName: 'Aurora',
          albumName: '',
          duration: Duration(seconds: seconds),
          syncedLyrics: synced,
          plainLyrics: plain,
        );
    final untimedVideo = lyricRecord(11, plain: 'auto transcript');
    final timedRelease = lyricRecord(22, synced: '[00:01.00]first line');
    final otherRecording =
        lyricRecord(33, synced: '[00:01.00]wrong song', seconds: 260);
    check(
      'ranking: a timed record outranks an untimed one',
      rankLrclibResults([untimedVideo, timedRelease], remoteSong).first.id ==
          22,
    );
    check(
      'ranking: a synchronised record is preferred over a plainly different one',
      rankLrclibResults([otherRecording, timedRelease], remoteSong).first.id ==
          22,
      detail: rankLrclibResults([otherRecording, timedRelease], remoteSong)
          .map((r) => r.id)
          .toList(),
    );

    stdout.writeln('\nMusic home feed');
    server.reset();
    server.handler = (call) => (status: 200, json: _musicHomePage());
    final feed = await api().musicHomeFeed(maxPages: 1);
    final musicCall =
        server.calls.firstWhere((c) => c.path.endsWith('/browse'));
    check('music feed: shelf rows and carousel tracks parsed', feed.length == 3,
        detail: feed.length);
    check('music feed: page order preserved', feed.first.videoId == 'vidTwoRow',
        detail: feed.map((i) => i.videoId).toList());
    final shelfRow = feed.firstWhere((i) => i.videoId == 'vidRow');
    check('music feed: title from the flex column',
        shelfRow.title == 'First song',
        detail: shelfRow.title);
    check('music feed: artist before the album in a byline',
        shelfRow.artist == 'Aurora',
        detail: shelfRow.artist);
    check(
      'music feed: duration from a byline',
      shelfRow.duration == const Duration(minutes: 3, seconds: 52),
      detail: shelfRow.duration,
    );
    check(
      'music feed: " - Topic" stripped from a byline',
      feed.firstWhere((i) => i.videoId == 'vidRow2').artist == 'Nova',
      detail: feed.firstWhere((i) => i.videoId == 'vidRow2').artist,
    );
    check(
      'music feed: two-row carousel tracks are kept',
      feed.any((i) => i.videoId == 'vidTwoRow'),
      detail: feed.map((i) => i.videoId).toList(),
    );
    check(
      'music feed: albums, artists and playlists are not tracks',
      !feed.any((i) => i.videoId.startsWith('MPRE')),
      detail: feed.map((i) => i.videoId).toList(),
    );
    check('music feed: asks for the music home',
        musicCall.body['browseId'] == 'FEmusic_home',
        detail: musicCall.body['browseId']);
    check('music feed: music client id',
        musicCall.headers['x-youtube-client-name'] == '67',
        detail: musicCall.headers['x-youtube-client-name']);
    check(
        'music feed: music origin headers',
        musicCall.headers['origin'] == 'https://music.youtube.com' &&
            musicCall.headers['referer'] == 'https://music.youtube.com/',
        detail: musicCall.headers['origin']);
    check('music feed: music API key',
        musicCall.query['key'] == kYouTubeMusicApiKey,
        detail: musicCall.query['key']);
    check(
      'music feed: WEB_REMIX context',
      mapOf(mapOf(musicCall.body['context'])['client'])['clientName'] ==
          'WEB_REMIX',
      detail: mapOf(mapOf(musicCall.body['context'])['client'])['clientName'],
    );
    check(
      'music feed: the signature is minted for the music origin',
      _signatureMatches(
        musicCall.headers['authorization'] ?? '',
        session.secret!,
        YouTubeWebSession.musicOrigin,
      ),
      detail: musicCall.headers['authorization'],
    );

    stdout.writeln('\nMusic home without an account');
    server.reset();
    server.handler = (call) => (status: 200, json: _musicHomePage());
    final anonymous = YouTubeLibraryApi(
      session: () async => null,
      baseUrl: server.base,
      versionUrl: server.versionUrl,
      timeout: const Duration(seconds: 10),
    );
    final anonymousFeed = await anonymous.musicHomeFeed(maxPages: 1);
    final anonymousCall =
        server.calls.firstWhere((c) => c.path.endsWith('/browse'));
    check('music feed: answers signed out', anonymousFeed.length == 3,
        detail: anonymousFeed.length);
    check(
      'music feed: sends no cookie or signature when signed out',
      !anonymousCall.headers.containsKey('cookie') &&
          !anonymousCall.headers.containsKey('authorization'),
      detail: anonymousCall.headers.keys.toList(),
    );
    check(
      'account data: still requires a session',
      await _kindOf(() async {
            await anonymous.playlists(maxPages: 1);
          }) ==
          YouTubeLibraryErrorKind.unauthorized,
    );

    stdout.writeln('\nMusic search');
    server.reset();
    server.handler = (call) => (status: 200, json: _musicSearchPage());
    final hits = await api().musicSearch('  Aurora  ');
    check('music search: query trimmed',
        server.calls.last.body['query'] == 'Aurora',
        detail: server.calls.last.body['query']);
    check('music search: hits parsed', hits.length == 2, detail: hits.length);
    check(
      'music search: only playable tracks',
      hits.every((i) => i.videoId.startsWith('vid')),
      detail: hits.map((i) => i.videoId).toList(),
    );

    server.reset();
    server.handler = (call) => (status: 200, json: _musicArtistSearchPage());
    final artistHits = await api().musicSearch('Aurora', artistHint: 'Aurora');
    check(
      'music search: an artist page fills in the omitted artist',
      artistHits.first.artist == 'Aurora',
      detail: artistHits.first.artist,
    );
    check(
      'music search: without a hint the artist stays empty',
      (await api().musicSearch('Aurora'))
          .firstWhere((i) => i.videoId == 'vidNoArtist')
          .artist
          .isEmpty,
    );

    stdout.writeln('\nMusic feed engine');
    YouTubePlaylistItem track(
      String id,
      String title,
      String artist, {
      int seconds = 200,
    }) =>
        YouTubePlaylistItem(
          videoId: id,
          title: title,
          artist: artist,
          duration: Duration(seconds: seconds),
        );
    YouTubeFeedCandidate candidate(
      YouTubePlaylistItem item, {
      YouTubeFeedSource source = YouTubeFeedSource.libraryArtist,
    }) =>
        YouTubeFeedCandidate(item: item, source: source);

    check(
      'engine: a trailer is rejected',
      !judgeMusicCandidate(
        candidate(track('t1', 'GTA 6 - Official Trailer', 'Rockstar')),
      ).accepted,
    );
    check(
      'engine: gameplay is rejected',
      !judgeMusicCandidate(
        candidate(track('t2', 'Insane Gameplay Highlights', 'Some Channel')),
      ).accepted,
    );
    check(
      'engine: a Short is rejected',
      !judgeMusicCandidate(
        candidate(track('t3', 'Song clip', 'Aurora', seconds: 20)),
      ).accepted,
    );
    check(
      'engine: a full programme is rejected',
      !judgeMusicCandidate(
        candidate(track('t4', 'Radio show', 'Aurora', seconds: 45 * 60)),
      ).accepted,
    );
    check(
      'engine: an account shelf row is kept, duration or not',
      judgeMusicCandidate(
        candidate(
          track('t5', 'Beat It', 'Michael Jackson'),
          source: YouTubeFeedSource.accountFeed,
        ),
      ).accepted,
    );
    check(
      'engine: a podcast row on a music shelf is dropped',
      !judgeMusicCandidate(
        candidate(
          track('t6', 'Podcast Episode 12', 'Some Channel', seconds: 3600),
          source: YouTubeFeedSource.accountFeed,
        ),
      ).accepted,
    );
    check(
      'engine: a row labelled "Episode" is not an artist',
      !judgeMusicCandidate(
        candidate(
          track('t9', "Someone's Secret", 'Episode'),
          source: YouTubeFeedSource.accountFeed,
        ),
      ).accepted,
    );
    check(
      'engine: a song actually named "Tribute" survives',
      judgeMusicCandidate(
        candidate(track('t10', 'Tribute', 'Tenacious D')),
      ).accepted,
    );
    check(
      'engine: a tribute-version upload is dropped',
      !judgeMusicCandidate(
        candidate(
          track('t11', 'Song (Tribute Version)', 'New Tribute Kings'),
        ),
      ).accepted,
    );
    check(
      'engine: title decoration removed',
      cleanMusicTitle('Runaway (Official Video) [4K]') == 'Runaway',
      detail: cleanMusicTitle('Runaway (Official Video) [4K]'),
    );
    check(
      'engine: a real recording note is kept',
      cleanMusicTitle('Runaway (Live at Wembley)') ==
          'Runaway (Live at Wembley)',
      detail: cleanMusicTitle('Runaway (Live at Wembley)'),
    );
    check(
      'engine: artist split from a decorated upload title',
      splitTitleAndArtist(
                  track('t7', 'Aurora - Runaway (Official Audio)', 'Aurora'))
              .title ==
          'Runaway',
    );
    check(
      'engine: a title with no matching channel is left alone',
      splitTitleAndArtist(track('t8', 'Song - Part 2', 'Aurora')).title ==
          'Song - Part 2',
    );

    final taste = buildYouTubeTasteProfile([
      const YouTubeTasteSignal(
        artist: 'Aurora - Topic',
        title: 'Runaway',
        playCount: 10,
        favorite: true,
      ),
      const YouTubeTasteSignal(artist: 'Nova', title: 'Other', playCount: 1),
      const YouTubeTasteSignal(
        artist: 'Nova',
        title: 'Known Thing',
        videoId: 'knownId',
      ),
    ]);
    check('engine: channel decoration folded into one artist',
        artistKey('Aurora - Topic') == artistKey('AuroraVEVO'));

    stdout.writeln('\nTaste model');
    check(
      'taste: a channel name and a local tag are the same artist',
      tasteArtistKey('Aurora - Topic', 'youtube:abc') ==
          tasteArtistKey('Aurora', 'local.flac'),
      detail: [
        tasteArtistKey('Aurora - Topic', 'youtube:abc'),
        tasteArtistKey('Aurora', 'local.flac'),
      ].join(' / '),
    );
    check(
      'taste: VEVO decoration is dropped too',
      tasteArtistKey('AuroraVEVO', 'youtube:abc') ==
          tasteArtistKey('Aurora', 'local.flac'),
    );
    check(
      'taste: an untagged file keeps its own bucket',
      tasteArtistKey('', 'youtube:abc') != tasteArtistKey('', 'local.flac'),
    );
    final mixedSignals = TasteInputs(
      events: [
        PlaySignal(
          filename: 'local.flac',
          timestamp: 1000,
          ratio: 1,
          secondsPlayed: 210,
          sessionId: 's1',
        ),
        PlaySignal(
          filename: 'youtube:abc',
          timestamp: 1400,
          ratio: 1,
          secondsPlayed: 200,
          sessionId: 's1',
        ),
      ],
      meta: const {
        'local.flac': SongMeta(artist: 'Aurora'),
        'youtube:abc': SongMeta(artist: 'Aurora - Topic'),
      },
      now: DateTime.fromMillisecondsSinceEpoch(1500000),
    );
    final mixedTaste = buildTasteSnapshot(mixedSignals);
    check(
      'taste: a local track and a streamed one credit one artist',
      mixedTaste.artists.length == 1 &&
          (mixedTaste.artists['aurora']?.longMass ?? 0) > 1.5,
      detail: mixedTaste.artists.keys,
    );
    check(
      'taste: both tracks are in the snapshot',
      mixedTaste.songs.containsKey('local.flac') &&
          mixedTaste.songs.containsKey('youtube:abc'),
    );
    check('engine: strongest artist first', taste.topArtists.first == 'Aurora',
        detail: taste.topArtists);
    check(
        'engine: play counts decide the weight',
        (taste.artistWeights['aurora'] ?? 0) == 1.0 &&
            (taste.artistWeights['nova'] ?? 0) < 0.2,
        detail: taste.artistWeights);
    check('engine: known remote ids remembered',
        taste.knownVideoIds.contains('knownId'));
    check(
      'engine: a placeholder artist never becomes a seed',
      buildYouTubeTasteProfile([
        const YouTubeTasteSignal(
          artist: 'Unknown Artist',
          title: 'Some file',
          playCount: 40,
        ),
      ]).isEmpty,
    );
    check(
      'engine: a row credited to a placeholder is dropped',
      !judgeMusicCandidate(
        candidate(track('t12', 'Some file', 'Unknown Artist')),
      ).accepted,
    );

    stdout.writeln('\nFeed taste');
    // A fresh install: nothing has been played, so the rows in the library are
    // the only taste signal there is. The favourite decides the order.
    final fresh = buildYouTubeTasteProfile(const [
      YouTubeTasteSignal(artist: 'Aurora', title: 'Runaway'),
      YouTubeTasteSignal(artist: 'Nova', title: 'Other', favorite: true),
    ]);
    check(
      'taste: an unplayed library still seeds its own artists',
      fresh.topArtists.length == 2 && fresh.topArtists.first == 'Nova',
      detail: fresh.topArtists,
    );

    final faded = buildYouTubeTasteProfile(
      const [
        YouTubeTasteSignal(artist: 'Nova', title: 'Played once', playCount: 1),
        YouTubeTasteSignal(
          artist: 'Aurora',
          title: 'Played for years',
          playCount: 400,
          ageDays: 240,
        ),
      ],
      artistTaste: const {'Nova': 0.9},
    );
    check(
      'taste: an artist abandoned months ago loses the seed slot',
      faded.topArtists.first == 'Nova' &&
          (faded.artistWeights['aurora'] ?? 0) < 0.5,
      detail: faded.artistWeights,
    );

    final tasteOnly = buildYouTubeTasteProfile(
      const [YouTubeTasteSignal(artist: 'Nova', title: 'Other')],
      artistTaste: const {'Nova': 0.5, 'Kite': 1.0},
    );
    check(
      'taste: the strongest played artist is seeded even with no rows left',
      tasteOnly.topArtists.first == 'Kite',
      detail: tasteOnly.topArtists,
    );

    final tasteRanked = rankYouTubeMusicFeed(
      taste: faded,
      maxPerArtist: 5,
      candidates: [
        candidate(
          track('acctOnly', 'Shelf row', 'Stranger'),
          source: YouTubeFeedSource.accountFeed,
        ),
        candidate(track('seedRow', 'Followed row', 'Nova')),
      ],
    );
    check(
      'taste: the seeded artist outranks a shelf row by an artist it forgot',
      tasteRanked.first.videoId == 'seedRow',
      detail: tasteRanked.map((i) => i.videoId).toList(),
    );

    final ranked = rankYouTubeMusicFeed(
      taste: taste,
      limit: 10,
      maxPerArtist: 5,
      candidates: [
        candidate(
          track('acct1', 'Account pick', 'Aurora'),
          source: YouTubeFeedSource.accountFeed,
        ),
        candidate(track('lib1', 'Library pick', 'Aurora')),
        candidate(track('lib2', 'Nova pick', 'Nova')),
        candidate(track('noise', 'GTA 6 Gameplay', 'Some Channel')),
        candidate(track('knownId', 'Known Thing', 'Nova')),
        candidate(track('dup1', 'Library pick (Official Video)', 'Aurora')),
      ],
    );
    check(
      'engine: the library pool outranks the account pool',
      ranked.first.videoId == 'lib1',
      detail: ranked.map((i) => i.videoId).toList(),
    );
    check(
      'engine: an account pick still makes the cut when taste matches',
      ranked.any((i) => i.videoId == 'acct1'),
      detail: ranked.map((i) => i.videoId).toList(),
    );
    check('engine: noise is dropped', !ranked.any((i) => i.videoId == 'noise'));
    check(
      'engine: a track already in the library is not suggested back',
      !ranked.any((i) => i.videoId == 'knownId'),
    );
    check(
      'engine: the same song under two ids is offered once',
      ranked.where((i) => titleKey(i.title) == 'library pick').length == 1,
      detail: ranked.map((i) => i.title).toList(),
    );

    final capped = rankYouTubeMusicFeed(
      taste: taste,
      maxPerArtist: 2,
      candidates: [
        candidate(track('a1', 'One', 'Aurora')),
        candidate(track('a2', 'Two', 'Aurora')),
        candidate(track('a3', 'Three', 'Aurora')),
      ],
    );
    check('engine: one artist cannot fill the feed', capped.length == 2,
        detail: capped.length);

    stdout.writeln('\nResponse cache');
    final store = _ProbeStore();
    YouTubeLibraryApi cachedApi() => YouTubeLibraryApi(
          session: () async => session,
          baseUrl: server.base,
          versionUrl: server.versionUrl,
          timeout: const Duration(seconds: 10),
          store: store,
        );

    server.reset();
    server.handler = (call) => (status: 200, json: _musicHomePage());
    final firstLoad = await cachedApi().musicHomeFeed(maxPages: 1);
    final requestsAfterFirst = server.browseCalls.length;
    final secondLoad = await cachedApi().musicHomeFeed(maxPages: 1);
    check('cache: first load hits the network', requestsAfterFirst == 1,
        detail: requestsAfterFirst);
    check(
      'cache: second load is served without a request',
      server.browseCalls.length == requestsAfterFirst,
      detail: server.browseCalls.length,
    );
    check('cache: entry written', store.writes > 0, detail: store.writes);
    check(
      'cache: same content',
      secondLoad.length == firstLoad.length &&
          secondLoad.first.videoId == firstLoad.first.videoId,
    );

    store.age = const Duration(hours: 1);
    server.reset();
    server.handler = (call) => (status: 500, json: const {});
    final staleLoad = await cachedApi().musicHomeFeed(maxPages: 1);
    check(
      'cache: an expired copy survives a failed refresh',
      staleLoad.length == firstLoad.length,
      detail: staleLoad.length,
    );

    stdout.writeln('\nImport planning');
    const remote = [
      YouTubePlaylistItem(videoId: 'a', title: 'A', artist: ''),
      YouTubePlaylistItem(videoId: 'b', title: 'B', artist: ''),
      YouTubePlaylistItem(videoId: 'a', title: 'A again', artist: ''),
      YouTubePlaylistItem(videoId: 'c', title: 'C', artist: ''),
      YouTubePlaylistItem(videoId: 'd', title: 'D', artist: ''),
    ];
    final plan =
        planPlaylistImport(remoteItems: remote, localVideoIds: const {'b'});
    check('planner: keeps remote order, skips known ids',
        plan.toAdd.map((i) => i.videoId).join(',') == 'a,c,d');
    check('planner: reports what was already there',
        plan.alreadyLocal.map((i) => i.videoId).join(',') == 'b');
    check('planner: drops duplicates',
        plan.toAdd.where((i) => i.videoId == 'a').length == 1);

    final limited = planPlaylistImport(
      remoteItems: remote,
      localVideoIds: const {},
      maxNewItems: 2,
    );
    check(
      'planner: honours the per-import limit',
      limited.toAdd.length == 2 && limited.skippedForLimit == 2,
      detail: '${limited.toAdd.length}/${limited.skippedForLimit}',
    );

    final untouched = planPlaylistImport(
      remoteItems: remote,
      localVideoIds: const {'a', 'b', 'c', 'd'},
    );
    check('planner: a fully-known playlist is a no-op', untouched.isNoOp);
  } finally {
    await server.stop();
  }
}

Future<YouTubeLibraryErrorKind?> _kindOf(Future<void> Function() run) async {
  try {
    await run();
    return null;
  } on YouTubeLibraryException catch (error) {
    return error.kind;
  }
}

/// Recomputes a `SAPISIDHASH` header from its timestamp and compares it, which
/// is the only way to prove which origin the request really signed for.
bool _signatureMatches(String header, String secret, String origin) {
  final match =
      RegExp(r'^SAPISIDHASH (\d{10})_([0-9a-f]{40})$').firstMatch(header);
  if (match == null) return false;
  final digest =
      sha1.convert(utf8.encode('${match.group(1)} $secret $origin')).toString();
  return digest == match.group(2);
}

// ---------------------------------------------------------------------------
// Live endpoints (no account needed for the shape check)
// ---------------------------------------------------------------------------

Future<void> _live() async {
  stdout.writeln('\nLive endpoints');

  final fakeSession = YouTubeWebSession.fromCookies({
    'SAPISID': 'not-a-real-session',
    'SID': 'not-a-real-session',
  })!;

  try {
    final api = YouTubeLibraryApi(
      session: () async => fakeSession,
      timeout: const Duration(seconds: 25),
    );
    final version = await api.resolvedClientVersion();
    if (!api.hasLiveClientVersion) {
      skip(
        'live: client version resolves',
        'config page unreachable or moved; compiled fallback used',
      );
    } else {
      check(
        'live: client version resolves',
        // e.g. 2.20261026.01.00
        RegExp(r'^\d\.\d{8}\.\d{2}\.\d{2}$').hasMatch(version),
        detail: version,
      );
    }
  } on Object catch (error) {
    skip('live: client version resolves', '$error');
  }

  try {
    final api = YouTubeLibraryApi(
      session: () async => fakeSession,
      timeout: const Duration(seconds: 20),
    );
    await api.playlists(maxPages: 1);
    check('live: YouTube accepts the request shape', true);
  } on YouTubeLibraryException catch (error) {
    if (error.kind == YouTubeLibraryErrorKind.network) {
      skip('live: YouTube accepts the request shape', error.message);
    } else {
      check(
        'live: YouTube rejects only the cookie',
        error.kind == YouTubeLibraryErrorKind.unauthorized ||
            error.kind == YouTubeLibraryErrorKind.rateLimited,
        detail: '${error.kind.name}: ${error.message}',
      );
    }
  } on Object catch (error) {
    skip('live: YouTube accepts the request shape', '$error');
  }

  // The feed no longer touches www.youtube.com's home; it lives or dies on
  // whether the music client answers anonymously.
  try {
    final api = YouTubeLibraryApi(
      session: () async => null,
      timeout: const Duration(seconds: 25),
    );
    final tracks = await api.musicHomeFeed(maxPages: 1);
    check(
      'live: YouTube Music home returns tracks',
      tracks.isNotEmpty,
      detail: '${tracks.length} tracks',
    );
    check(
      'live: music rows carry a title and a channel',
      tracks.every((t) => t.title.isNotEmpty && t.artist.isNotEmpty),
      detail: tracks.take(3).map((t) => '${t.title} / ${t.artist}').toList(),
    );
    final playable = tracks
        .where((t) => judgeMusicCandidate(
              YouTubeFeedCandidate(
                item: normalizeMusicTrack(t),
                source: YouTubeFeedSource.accountFeed,
              ),
            ).accepted)
        .length;
    check(
      'live: most of the music home survives the music filter',
      playable >= tracks.length * 0.6,
      detail: '$playable of ${tracks.length}',
    );
  } on YouTubeLibraryException catch (error) {
    if (error.kind == YouTubeLibraryErrorKind.network ||
        error.kind == YouTubeLibraryErrorKind.rateLimited) {
      skip('live: YouTube Music home returns tracks', error.message);
    } else {
      check(
        'live: YouTube Music home returns tracks',
        false,
        detail: '${error.kind.name}: ${error.message}',
      );
    }
  } on Object catch (error) {
    skip('live: YouTube Music home returns tracks', '$error');
  }
}

// ---------------------------------------------------------------------------
// Fake YouTube
// ---------------------------------------------------------------------------

typedef Reply = ({int status, Object? json});

class FakeYouTube {
  HttpServer? _server;
  final List<Call> calls = [];
  int configRequests = 0;
  String clientVersion = '2.20260101.00.00';
  Reply Function(Call call)? handler;

  Uri get base => Uri.parse('http://127.0.0.1:${_server!.port}/youtubei/v1/');
  Uri get versionUrl => Uri.parse('http://127.0.0.1:${_server!.port}/home');

  /// Only the InnerTube calls, without the client-config fetch that precedes
  /// the first of them.
  List<Call> get browseCalls =>
      calls.where((call) => call.path.endsWith('/browse')).toList();

  void reset() {
    calls.clear();
    configRequests = 0;
  }

  Future<void> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server = server;
    server.listen(_serve);
  }

  Future<void> stop() async {
    await _server?.close(force: true);
  }

  Future<void> _serve(HttpRequest request) async {
    final raw = await utf8.decoder.bind(request).join();
    var body = <String, dynamic>{};
    if (raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) body = Map<String, dynamic>.from(decoded);
      } on FormatException {
        // Recorded as an empty body; the probe asserts on shape, not garbage.
      }
    }

    final headers = <String, String>{};
    request.headers.forEach(
        (name, values) => headers[name.toLowerCase()] = values.join(','));

    final call = Call(
      path: request.uri.path,
      query: request.uri.queryParameters,
      headers: headers,
      body: body,
    );
    calls.add(call);

    if (request.uri.path == '/home' || request.uri.path == '/sw.js_data') {
      configRequests++;
      request.response
        ..statusCode = 200
        ..headers.contentType = ContentType.html
        ..write('<html><script>ytcfg.set({"INNERTUBE_CLIENT_VERSION":'
            '"$clientVersion","INNERTUBE_API_KEY":"$kYouTubeWebApiKey"});'
            '</script></html>');
      await request.response.close();
      return;
    }

    final reply = handler?.call(call) ?? (status: 404, json: const {});
    request.response.statusCode = reply.status;
    final json = reply.json;
    if (json != null) {
      request.response.headers.contentType = ContentType.json;
      request.response.write(jsonEncode(json));
    }
    await request.response.close();
  }
}

class Call {
  final String path;
  final Map<String, String> query;
  final Map<String, String> headers;
  final Map<String, dynamic> body;

  const Call({
    required this.path,
    required this.query,
    required this.headers,
    required this.body,
  });
}

// ---------------------------------------------------------------------------
// Fixtures, shaped like the responses the web client receives
// ---------------------------------------------------------------------------

Map<String, Object?> _accountMenu() => {
      'actions': [
        {
          'openPopupAction': {
            'popup': {
              'multiPageMenuRenderer': {
                'header': {
                  'activeAccountHeaderRenderer': {
                    'accountName': {'simpleText': 'Nova Listener'},
                    'channelHandle': {'simpleText': '@nova'},
                    'accountPhoto': {
                      'thumbnails': [
                        {
                          'url': 'https://yt3.example/s88',
                          'width': 88,
                          'height': 88,
                        },
                        {
                          'url': 'https://yt3.example/s176',
                          'width': 176,
                          'height': 176,
                        },
                      ],
                    },
                    'navigationEndpoint': {
                      'browseEndpoint': {
                        'browseId': 'UC1234567890',
                        'canonicalBaseUrl': '/@nova',
                      },
                    },
                  },
                },
              },
            },
          },
        },
      ],
    };

/// A YouTube Music home page: one carousel of two-row items and one shelf of
/// responsive rows, which is the shape the WEB_REMIX browse endpoint returns.
Map<String, Object?> _musicHomePage() => {
      'contents': {
        'singleColumnBrowseResultsRenderer': {
          'tabs': [
            {
              'tabRenderer': {
                'content': {
                  'sectionListRenderer': {
                    'contents': [
                      {
                        'musicCarouselShelfRenderer': {
                          'header': {
                            'musicCarouselShelfBasicHeaderRenderer': {
                              'title': {
                                'runs': [
                                  {'text': 'Picked for you'}
                                ]
                              }
                            }
                          },
                          'contents': [
                            _musicTwoRow('vidTwoRow', 'Night Drive', 'Aurora'),
                            _musicTwoRow('MPREalbum', 'Another Album', 'Aurora',
                                playable: false),
                          ],
                        }
                      },
                      {
                        'musicShelfRenderer': {
                          'contents': [
                            _musicResponsive(
                              'vidRow',
                              'First song',
                              ['Aurora', 'Album', '3:52'],
                            ),
                            _musicResponsive(
                              'vidRow2',
                              'Second song',
                              ['Nova - Topic', 'Single', '4:10'],
                            ),
                            {
                              'musicResponsiveListItemRenderer': {
                                'flexColumns': [
                                  {
                                    'musicResponsiveListItemFlexColumnRenderer':
                                        {
                                      'text': {
                                        'runs': [
                                          {'text': 'A container'}
                                        ]
                                      }
                                    }
                                  }
                                ],
                                'navigationEndpoint': {
                                  'browseEndpoint': {'browseId': 'MPRElist'},
                                },
                              }
                            },
                          ],
                        }
                      },
                    ],
                  }
                }
              }
            }
          ]
        }
      },
    };

/// A music search response: the same renderers as the home shelves.
Map<String, Object?> _musicSearchPage() => {
      'contents': {
        'tabbedSearchResultsRenderer': {
          'tabs': [
            {
              'tabRenderer': {
                'content': {
                  'sectionListRenderer': {
                    'contents': [
                      {
                        'musicShelfRenderer': {
                          'contents': [
                            _musicResponsive(
                              'vidSearch1',
                              'Search Hit',
                              ['Aurora', 'Single', '3:20'],
                            ),
                            _musicResponsive(
                              'vidSearch2',
                              'Search Hit Two',
                              ['Aurora', 'Single', '4:05'],
                            ),
                            {
                              'musicResponsiveListItemRenderer': {
                                'flexColumns': [
                                  {
                                    'musicResponsiveListItemFlexColumnRenderer':
                                        {
                                      'text': {
                                        'runs': [
                                          {'text': 'Aurora'}
                                        ]
                                      }
                                    }
                                  }
                                ],
                                'navigationEndpoint': {
                                  'browseEndpoint': {'browseId': 'UCartist'},
                                },
                              }
                            },
                          ],
                        }
                      },
                    ],
                  }
                }
              }
            }
          ]
        }
      },
    };

/// An artist search result page: the rows name the song and its type but omit
/// the artist, because the page header already does.
Map<String, Object?> _musicArtistSearchPage() => {
      'contents': {
        'musicShelfRenderer': {
          'contents': [
            _musicResponsive(
              'vidNoArtist',
              'Top Song',
              ['Song', '3:00'],
            ),
          ],
        },
      },
    };

Map<String, Object?> _musicResponsive(
  String videoId,
  String title,
  List<String> byline,
) =>
    {
      'musicResponsiveListItemRenderer': {
        'playlistItemData': {'videoId': videoId},
        'flexColumns': [
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  {'text': title}
                ]
              }
            }
          },
          {
            'musicResponsiveListItemFlexColumnRenderer': {
              'text': {
                'runs': [
                  for (var i = 0; i < byline.length; i++) ...[
                    if (i > 0) {'text': ' • '},
                    {'text': byline[i]},
                  ]
                ]
              }
            }
          },
        ],
        'thumbnail': {
          'musicThumbnailRenderer': {
            'thumbnail': {
              'thumbnails': [
                {
                  'url': 'https://i.ytimg.com/vi/$videoId/default.jpg',
                  'width': 120,
                },
                {
                  'url': 'https://i.ytimg.com/vi/$videoId/hqdefault.jpg',
                  'width': 480,
                },
              ]
            }
          }
        },
      },
    };

Map<String, Object?> _musicTwoRow(
  String id,
  String title,
  String subtitle, {
  bool playable = true,
}) =>
    {
      'musicTwoRowItemRenderer': {
        'title': {
          'runs': [
            {'text': title}
          ]
        },
        'subtitle': {
          'runs': [
            {'text': subtitle}
          ]
        },
        'navigationEndpoint': playable
            ? {
                'watchEndpoint': {'videoId': id},
              }
            : {
                'browseEndpoint': {'browseId': id},
              },
        'thumbnailRenderer': {
          'musicThumbnailRenderer': {
            'thumbnail': {
              'thumbnails': [
                {
                  'url': 'https://i.ytimg.com/vi/$id/hqdefault.jpg',
                  'width': 480,
                },
              ]
            }
          }
        },
      },
    };

Map<String, Object?> _feplaylistsPage(List<Map<String, Object?>> items) => {
      'contents': {
        'twoColumnBrowseResultsRenderer': {
          'tabs': [
            {
              'tabRenderer': {
                'content': {
                  'sectionListRenderer': {
                    'contents': [
                      {
                        'itemSectionRenderer': {
                          'contents': [
                            {
                              'gridRenderer': {'items': items},
                            },
                          ],
                        },
                      },
                    ],
                  },
                },
              },
            },
          ],
        },
      },
    };

final List<Map<String, Object?>> _feFirstPage = [
  {'lockupViewModel': _lockupPlaylist('PLlockup1', 'Focus', '23 videos')},
  {'lockupViewModel': _lockupPlaylist('PLlockup2', 'Road trip', '1 video')},
  {'lockupViewModel': _lockupPlaylist('LL', 'Liked videos', '412 videos')},
  {'lockupViewModel': _lockupVideoItem('vidOnly', 'A lone video')},
  {
    'gridPlaylistRenderer': {
      'playlistId': 'PLgrid2',
      'title': {
        'runs': [
          {'text': 'Grid '},
          {'text': 'playlist'},
        ],
      },
      'videoCountText': {
        'runs': [
          {'text': '1 video'},
        ],
      },
      'thumbnail': {
        'thumbnails': [
          {'url': 'https://i.ytimg.com/pl/PLgrid2/default.jpg', 'width': 120},
          {'url': 'https://i.ytimg.com/pl/PLgrid2/hqdefault.jpg', 'width': 480},
        ],
      },
      'navigationEndpoint': {
        'browseEndpoint': {'browseId': 'VLPLgrid2'},
      },
    },
  },
  {
    'playlistRenderer': {
      'title': {'simpleText': 'Classic'},
      'videoCount': '7',
      'thumbnail': {
        'thumbnails': [
          {
            'url': 'https://i.ytimg.com/pl/UUclassic3/hqdefault.jpg',
            'width': 480,
          },
        ],
      },
      'navigationEndpoint': {
        'browseEndpoint': {'browseId': 'VLUUclassic3'},
      },
    },
  },
  {
    'continuationItemRenderer': {
      'continuationEndpoint': {
        'continuationCommand': {'token': 'FE1'},
      },
    },
  },
];

final List<Map<String, Object?>> _feSecondPage = [
  {'lockupViewModel': _lockupPlaylist('PLpage2', 'Later', '4 videos')},
];

Map<String, Object?> _lockupPlaylist(String id, String title, String count) => {
      'contentId': id,
      'contentType': 'LOCKUP_CONTENT_TYPE_PLAYLIST',
      'contentImage': {
        'collectionThumbnailViewModel': {
          'primaryThumbnail': {
            'thumbnailViewModel': {
              'image': {
                'sources': [
                  {
                    'url': 'https://i.ytimg.com/pl/$id/hqdefault.jpg',
                    'width': 480,
                    'height': 360,
                  },
                ],
              },
            },
          },
        },
      },
      'metadata': {
        'lockupMetadataViewModel': {
          'title': {'content': title},
          'metadata': {
            'contentMetadataViewModel': {
              'metadataRows': [
                {
                  'metadataParts': [
                    {
                      'text': {'content': count},
                    },
                  ],
                },
              ],
            },
          },
        },
      },
      'rendererContext': {
        'commandContext': {
          'onTap': {
            'innertubeCommand': {
              'watchEndpoint': {'playlistId': id},
            },
          },
        },
      },
    };

Map<String, Object?> _lockupVideoItem(String id, String title) => {
      'contentId': id,
      'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
      'metadata': {
        'lockupMetadataViewModel': {
          'title': {'content': title},
        },
      },
      'thumbnailOverlays': [
        {
          'thumbnailOverlayTimeStatusRenderer': {
            'text': {'simpleText': '4:20'},
          },
        },
      ],
    };

Map<String, Object?> _playlistPage(
  List<Map<String, Object?>> contents, {
  String? continuation,
}) =>
    {
      'contents': {
        'twoColumnBrowseResultsRenderer': {
          'tabs': [
            {
              'tabRenderer': {
                'content': {
                  'sectionListRenderer': {
                    'contents': [
                      {
                        'itemSectionRenderer': {
                          'contents': [
                            {
                              'playlistVideoListRenderer': {
                                'contents': [
                                  ...contents,
                                  if (continuation != null)
                                    {
                                      'continuationItemRenderer': {
                                        'continuationEndpoint': {
                                          'continuationCommand': {
                                            'token': continuation,
                                          },
                                        },
                                      },
                                    },
                                ],
                              },
                            },
                          ],
                        },
                      },
                    ],
                  },
                },
              },
            },
          ],
        },
      },
    };

Map<String, Object?> _video(
  String id,
  String title, {
  String? length,
  String? byline,
  bool playable = true,
}) {
  final renderer = <String, Object?>{
    'videoId': id,
    'title': {
      'runs': [
        {'text': title},
      ],
    },
    'thumbnail': {
      'thumbnails': [
        {'url': 'https://i.ytimg.com/vi/$id/default.jpg', 'width': 120},
        {'url': 'https://i.ytimg.com/vi/$id/hqdefault.jpg', 'width': 480},
      ],
    },
    'isPlayable': playable,
  };
  if (length != null) renderer['lengthText'] = {'simpleText': length};
  if (byline != null) {
    renderer['shortBylineText'] = {
      'runs': [
        {'text': byline},
      ],
    };
  }
  return {'playlistVideoRenderer': renderer};
}

final List<Map<String, Object?>> _likedFirstPage = [
  _video('vidOne', 'Aurora Borealis', length: '3:52', byline: 'Aurora - Topic'),
  _video('vidDeleted', 'Deleted video'),
  _video('vidPrivate', 'Private video'),
  {
    'lockupViewModel': {
      'contentId': 'vidLockup',
      'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
      'metadata': {
        'lockupMetadataViewModel': {
          'title': {'content': 'Lockup track'},
        },
      },
      'thumbnailOverlays': [
        {
          'thumbnailOverlayTimeStatusRenderer': {
            'text': {'simpleText': '4:20'},
          },
        },
      ],
    },
  },
];

final List<Map<String, Object?>> _likedSecondPage = [
  _video('vidFive', 'Long one', length: '1:02:03'),
  _video('vidSix', 'Short one', length: '0:41'),
];

final List<Map<String, Object?>> _mixedPage = [
  _video('vidOne', 'Aurora Borealis', length: '3:52', byline: 'Aurora'),
  _video('vidOne', 'Aurora Borealis (duplicate)', length: '3:52'),
  {
    'lockupViewModel': {
      'contentId': 'vidLockup',
      'contentType': 'LOCKUP_CONTENT_TYPE_VIDEO',
      'metadata': {
        'lockupMetadataViewModel': {
          'title': {'content': 'Lockup track'},
        },
      },
      'thumbnailOverlays': [
        {
          'thumbnailOverlayTimeStatusRenderer': {
            'text': {'simpleText': '4:20'},
          },
        },
      ],
    },
  },
  _video('vidPrivate', 'Private video'),
];

/// In-memory stand-in for the disk store, with an injectable age so the stale
/// path can be exercised without waiting for a TTL.
class _ProbeStore implements YouTubeResponseStore {
  final Map<String, Map<String, dynamic>> bodies = {};
  Duration age = Duration.zero;
  int writes = 0;

  @override
  Future<Map<String, dynamic>?> read(
    String key,
    Duration maxAge, {
    bool allowStale = false,
  }) async {
    final body = bodies[key];
    if (body == null) return null;
    if (allowStale || age < maxAge) return body;
    return null;
  }

  @override
  Future<void> write(String key, Map<String, dynamic> body) async {
    writes++;
    bodies[key] = body;
  }

  @override
  Future<void> remove(String key) async {
    bodies.remove(key);
  }
}
