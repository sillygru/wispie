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
import 'package:wispie/domain/services/youtube_library.dart';
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
