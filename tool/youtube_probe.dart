// SPDX-License-Identifier: GPL-3.0-only
//
// Probes the InnerTube endpoints and client profiles the app uses, so a failure
// can be reported as an HTTP status instead of "playback did not work".
//
//   dart run tool/youtube_probe.dart [query]
//
// Each profile is tried the way the app tries them: search on WEB, then a
// player request per client, then a ranged media read on the first direct audio
// URL. Duplicated profiles are intentional — this has to run without Flutter.
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

const _apiKey = 'AIzaSyAO_FJ2SlqU8Q4STEHLGCilw_Y9_11qcW8';

class _Profile {
  final String name;
  final int headerId;
  final String version;
  final String userAgent;
  final Map<String, Object?> context;

  const _Profile({
    required this.name,
    required this.headerId,
    required this.version,
    required this.userAgent,
    this.context = const {},
  });
}

const _profiles = [
  _Profile(
    name: 'ANDROID_VR',
    headerId: 28,
    version: '1.65.10',
    userAgent:
        'com.google.android.apps.youtube.vr.oculus/1.65.10 (Linux; U; Android 12L; eureka-user Build/SQ3A.220605.009.A1) gzip',
    context: {
      'androidSdkVersion': 32,
      'osName': 'Android',
      'osVersion': '12L',
      'deviceMake': 'Oculus',
      'deviceModel': 'Quest 3',
    },
  ),
  _Profile(
    name: 'IOS',
    headerId: 5,
    version: '21.26.4',
    userAgent:
        'com.google.ios.youtube/21.26.4 (iPhone16,2; U; CPU iOS 18_3_2 like Mac OS X;)',
    context: {
      'osName': 'iPhone',
      'osVersion': '18.3.2.22D82',
      'deviceMake': 'Apple',
      'deviceModel': 'iPhone16,2',
    },
  ),
  _Profile(
    name: 'ANDROID',
    headerId: 3,
    version: '21.26.364',
    userAgent:
        'com.google.android.youtube/21.26.364 (Linux; U; Android 11) gzip',
    context: {'androidSdkVersion': 30, 'osName': 'Android', 'osVersion': '11'},
  ),
  _Profile(
    name: 'TVHTML5',
    headerId: 7,
    version: '7.20260707.07.00',
    userAgent:
        'Mozilla/5.0 (ChromiumStylePlatform) Cobalt/29.0-29.prod (unlike Gecko) v8/8.8.278.8-jit gles Starboard/17.0',
    context: {'osName': 'Cobalt', 'osVersion': '29.0'},
  ),
  _Profile(
    name: 'WEB',
    headerId: 1,
    version: '2.20260707.12.00',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
  ),
  _Profile(
    name: 'MWEB',
    headerId: 2,
    version: '2.20260708.05.00',
    userAgent:
        'Mozilla/5.0 (iPad; CPU OS 17_5 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.5 Mobile/15E148 Safari/604.1',
    context: {'osName': 'iPad', 'osVersion': '17.5.0.17F79'},
  ),
  _Profile(
    name: 'WEB_EMBEDDED_PLAYER',
    headerId: 56,
    version: '1.20260707.12.00',
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/127.0.0.0 Safari/537.36',
    context: {'clientScreen': 'EMBED'},
  ),
  _Profile(
    name: 'TVHTML5_SIMPLY_EMBEDDED_PLAYER',
    headerId: 85,
    version: '2.0',
    userAgent:
        'Mozilla/5.0 (PlayStation; PlayStation 4/12.00) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Safari/605.1.15',
    context: {'clientScreen': 'EMBED', 'osName': 'PlayStation 4'},
  ),
  _Profile(
    name: 'ANDROID_MUSIC',
    headerId: 21,
    version: '7.27.52',
    userAgent:
        'com.google.android.apps.youtube.music/7.27.52 (Linux; U; Android 14; en_US) gzip',
    context: {
      'androidSdkVersion': 34,
      'osName': 'Android',
      'osVersion': '14',
      'deviceMake': 'Google',
      'deviceModel': 'Pixel 8',
    },
  ),
];

final _client = HttpClient();

Future<void> main(List<String> args) async {
  final query = args.isNotEmpty ? args[0] : 'lofi hip hop';
  var failures = 0;

  try {
    final ids = await _search(query);
    print('search "$query": ${ids.length} results');
    if (ids.isEmpty) {
      print('search: FAILED (no videoRenderer with a title)');
      exitCode = 1;
      return;
    }
    final firstId = ids.first.split(' | ').first;
    print('search first: $firstId');

    for (final entry in ids.take(3)) {
      print('  parsed: $entry');
    }

    final page = await _watchPage(firstId);
    print('watch page: $page');

    final visitor = page.visitorData;
    if (visitor != null) {
      for (final name in const ['MWEB', 'ANDROID', 'IOS']) {
        final profile = _profiles.firstWhere((item) => item.name == name);
        final result = await _player(profile, firstId, visitorData: visitor);
        print('player [${profile.name}+visitor]: $result');
      }
    }

    String? playable = page.directUrl;
    var usableProfiles = 0;
    for (final profile in _profiles) {
      final result = await _player(profile, firstId);
      print('player [${profile.name}]: $result');
      if (result.directUrl) {
        usableProfiles++;
        playable ??= result.url;
      }
    }

    if (playable == null) {
      print('media: SKIPPED (no profile returned a direct audio URL)');
      exitCode = 1;
      return;
    }
    print('streamable profiles: $usableProfiles/${_profiles.length}');

    final watch = Stopwatch()..start();
    final media = await _probeMedia(playable);
    print('media: $media (${watch.elapsedMilliseconds}ms to first chunk)');
    if (media.status != 206 && media.status != 200) failures++;
  } finally {
    _client.close(force: true);
  }

  print(failures == 0 ? 'RESULT: ok' : 'RESULT: $failures failing checks');
  exitCode = failures == 0 ? 0 : 1;
}

Future<List<String>> _search(String query) async {
  final profile = _profiles.firstWhere((item) => item.name == 'WEB');
  final body = await _post(
    'search',
    {'query': query, 'context': _context(profile)},
    profile,
  );
  final ids = <String>[];
  final seen = <String>{};
  void walk(Object? node) {
    if (node is List) {
      for (final item in node) {
        walk(item);
      }
      return;
    }
    if (node is! Map) return;
    final id = node['videoId'];
    final title = node['title'];
    if (id is String &&
        id.length == 11 &&
        title is Map &&
        seen.add(id) &&
        node['isLiveNow'] != true) {
      final artist = _text(node['longBylineText']) ??
          _text(node['ownerText']) ??
          _text(node['subtitle']);
      ids.add('$id | ${_text(title)} | $artist | ${_text(node['lengthText'])}');
    }
    for (final value in node.values) {
      if (value is Map || value is List) walk(value);
    }
  }

  walk(body);
  return ids;
}

String? _text(Object? node) {
  if (node is! Map) return null;
  final simple = node['simpleText'];
  if (simple != null) return '$simple';
  final runs = node['runs'];
  if (runs is List) {
    final buffer = StringBuffer();
    for (final run in runs) {
      if (run is Map) buffer.write('${run['text'] ?? ''}');
    }
    return buffer.toString();
  }
  return null;
}

/// The plain watch page, which some builds still seed with a full player
/// response. Cheap to try and it also yields the visitor ID the bot check wants.
Future<_PageResult> _watchPage(String videoId) async {
  final uri = Uri.https('www.youtube.com', '/watch', {
    'v': videoId,
    'bpctr': '9999999999',
    'has_verified': '1',
  });
  final request = await _client.getUrl(uri);
  request.headers
    ..set(HttpHeaders.userAgentHeader,
        _profiles.firstWhere((p) => p.name == 'WEB').userAgent)
    ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
  final response = await request.close();
  final html = await response.transform(utf8.decoder).join();
  final visitorMatch = RegExp(r'"VISITOR_DATA":"([^"]+)"').firstMatch(html);
  final marker = html.indexOf('"streamingData"');
  if (marker < 0) {
    return _PageResult(
      status: response.statusCode,
      visitorData: visitorMatch?.group(1),
      detail: 'no streamingData in the page',
    );
  }
  final start = html.lastIndexOf('{', marker);
  final json = _balancedObject(html, start);
  if (json == null) {
    return _PageResult(
      status: response.statusCode,
      visitorData: visitorMatch?.group(1),
      detail: 'streamingData found but the object was truncated',
    );
  }
  final decoded = jsonDecode(json);
  if (decoded is! Map) {
    return _PageResult(
      status: response.statusCode,
      visitorData: visitorMatch?.group(1),
      detail: 'streamingData is not an object',
    );
  }
  final adaptive = decoded['adaptiveFormats'];
  final direct = <String>[];
  if (adaptive is List) {
    for (final entry in adaptive) {
      if (entry is Map && entry['url'] != null) direct.add('${entry['itag']}');
    }
  }
  final formats = <String>[];
  final muxed = decoded['formats'];
  if (muxed is List) {
    for (final entry in muxed) {
      if (entry is Map && entry['url'] != null) formats.add('${entry['itag']}');
    }
  }
  String? firstUrl;
  if (adaptive is List) {
    for (final entry in adaptive) {
      if (entry is Map && entry['url'] != null) {
        firstUrl = '${entry['url']}';
        break;
      }
    }
  }
  return _PageResult(
    status: response.statusCode,
    visitorData: visitorMatch?.group(1),
    detail: 'adaptive urls: ${direct.isEmpty ? 'none' : direct.join(',')}; '
        'muxed urls: ${formats.isEmpty ? 'none' : formats.join(',')}',
    directUrl: firstUrl,
  );
}

String? _balancedObject(String text, int start) {
  if (start < 0 || start >= text.length || text[start] != '{') return null;
  var depth = 0;
  var inString = false;
  var escaped = false;
  for (var i = start; i < text.length; i++) {
    final char = text[i];
    if (inString) {
      if (escaped) {
        escaped = false;
      } else if (char == r'\') {
        escaped = true;
      } else if (char == '"') {
        inString = false;
      }
      continue;
    }
    if (char == '"') {
      inString = true;
    } else if (char == '{') {
      depth++;
    } else if (char == '}') {
      depth--;
      if (depth == 0) return text.substring(start, i + 1);
    }
  }
  return null;
}

Future<_PlayerResult> _player(
  _Profile profile,
  String videoId, {
  String? visitorData,
}) async {
  try {
    final body = await _post(
      'player',
      {
        'videoId': videoId,
        'context': {
          ..._context(profile),
          if (visitorData != null)
            'client': {
              ...(_context(profile)['client'] as Map<String, Object?>),
              'visitorData': visitorData,
            },
        },
        'contentCheckOk': true,
        'racyCheckOk': true,
      },
      profile,
      visitorData: visitorData,
    );
    final status = body['playabilityStatus'];
    final state = status is Map
        ? '${status['status']}${status['reason'] == null ? '' : ' (${status['reason']})'}'
        : 'none';
    final streaming = body['streamingData'];
    if (streaming is! Map) {
      return _PlayerResult(playability: state, detail: 'no streamingData');
    }
    final formats = <Map>[];
    for (final key in ['adaptiveFormats', 'formats']) {
      final entries = streaming[key];
      if (entries is! List) continue;
      for (final entry in entries) {
        if (entry is Map) formats.add(entry);
      }
    }
    final audio = formats.where((format) {
      final mime = '${format['mimeType']}';
      return mime.startsWith('audio/');
    }).toList();
    final ciphered = audio.where((format) => format['url'] == null).length;
    final direct = audio.where((format) => format['url'] != null).toList();
    if (direct.isEmpty) {
      // Adaptive audio is SABR-only; the muxed rendition still has a URL and its
      // AAC track is what the app streams in that case.
      final muxed = formats
          .where((format) =>
              '${format['mimeType']}'.contains('mp4a') && format['url'] != null)
          .toList();
      if (muxed.isNotEmpty) {
        muxed.sort((a, b) =>
            int.tryParse('${a['bitrate']}')! -
            int.tryParse('${b['bitrate']}')!);
        final best = muxed.first;
        final url = Uri.parse('${best['url']}');
        final expire = int.tryParse(url.queryParameters['expire'] ?? '');
        final ttl = expire == null
            ? 'no expire'
            : 'expires in ${((expire * 1000 - DateTime.now().millisecondsSinceEpoch) / 3600000).toStringAsFixed(1)}h';
        return _PlayerResult(
          playability: state,
          detail: '${audio.length} audio formats ($ciphered without url), '
              'muxed itag ${best['itag']} ${best['mimeType']} $ttl',
          url: url.toString(),
          directUrl: true,
        );
      }
      final keys = audio.isEmpty
          ? <String>[]
          : audio.first.keys.map((key) => '$key').toList();
      return _PlayerResult(
        playability: state,
        detail: '${audio.length} audio formats, $ciphered without url, '
            'no muxed URL (fields: ${keys.join(',')})',
      );
    }
    direct.sort((a, b) {
      final rank = const ['140', '139', '251', '250', '249'];
      final indexA = rank.indexOf('${a['itag']}');
      final indexB = rank.indexOf('${b['itag']}');
      return (indexA < 0 ? rank.length : indexA)
          .compareTo(indexB < 0 ? rank.length : indexB);
    });
    final best = direct.first;
    final url = Uri.parse('${best['url']}');
    final expire = int.tryParse(url.queryParameters['expire'] ?? '');
    final ttl = expire == null
        ? 'no expire'
        : 'expires in ${((expire * 1000 - DateTime.now().millisecondsSinceEpoch) / 3600000).toStringAsFixed(1)}h';
    return _PlayerResult(
      playability: state,
      detail: 'itag ${best['itag']} ${best['mimeType']} '
          '${best['contentLength'] ?? '?'} bytes, $ttl',
      url: url.toString(),
      directUrl: true,
    );
  } on Object catch (error) {
    return _PlayerResult(playability: 'error', detail: '$error');
  }
}

Future<_MediaResult> _probeMedia(String url) async {
  final request = await _client.getUrl(Uri.parse(url));
  request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-65535');
  final response = await request.close();
  var bytes = 0;
  await for (final chunk in response) {
    bytes += chunk.length;
    if (bytes >= 65536) break;
  }

  // Just_audio hands the source an exclusive end, which becomes an inclusive
  // last byte on the wire. Each case below must deliver exactly end - start
  // bytes or the player's proxy closes the response with a length error.
  final probes = <String>[];
  var rangeFailures = 0;
  for (final (from, endEx) in [(0, 3), (0, 2), (0, 262144), (1024, 2048)]) {
    final probeRequest = await _client.getUrl(Uri.parse(url));
    probeRequest.headers
        .set(HttpHeaders.rangeHeader, 'bytes=$from-${endEx - 1}');
    final probeResponse = await probeRequest.close();
    var probeBytes = 0;
    await for (final chunk in probeResponse) {
      probeBytes += chunk.length;
    }
    final contentRange =
        probeResponse.headers.value(HttpHeaders.contentRangeHeader) ?? 'none';
    final expected = endEx - from;
    if (probeBytes != expected) rangeFailures++;
    probes.add('[$from,$endEx) -> HTTP ${probeResponse.statusCode}, '
        '$probeBytes/$expected bytes, $contentRange');
  }
  if (rangeFailures > 0) {
    print('RANGE MISMATCH on $rangeFailures/${probes.length} probes');
  }

  return _MediaResult(
    status: response.statusCode,
    bytes: bytes,
    contentType: response.headers.contentType?.mimeType ?? '',
    probe: probes.join(' | '),
  );
}

Map<String, Object?> _context(_Profile profile) => {
      'client': {
        'clientName': profile.name,
        'clientVersion': profile.version,
        'hl': 'en',
        'gl': 'US',
        'userAgent': profile.userAgent,
        ...profile.context,
      },
      'user': {'lockedSafetyMode': false},
      'request': {'useSsl': true},
    };

Future<Map<String, dynamic>> _post(
  String endpoint,
  Map<String, Object?> body,
  _Profile profile, {
  String? visitorData,
}) async {
  final uri = Uri.https('www.youtube.com', '/youtubei/v1/$endpoint', {
    'key': _apiKey,
    'prettyPrint': 'false',
  });
  final request = await _client.postUrl(uri);
  request.headers
    ..set(HttpHeaders.contentTypeHeader, 'application/json')
    ..set('X-YouTube-Client-Name', '${profile.headerId}')
    ..set('X-YouTube-Client-Version', profile.version)
    ..set(HttpHeaders.userAgentHeader, profile.userAgent)
    ..set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');
  if (visitorData != null) {
    request.headers.set('X-Goog-Visitor-Id', visitorData);
  }
  request.write(jsonEncode(body));
  final response = await request.close();
  final text = await response.transform(utf8.decoder).join();
  if (response.statusCode != 200) {
    throw HttpException(
        'HTTP ${response.statusCode}: ${text.substring(0, text.length.clamp(0, 200))}');
  }
  final decoded = jsonDecode(text);
  if (decoded is! Map) throw const FormatException('not a JSON object');
  return Map<String, dynamic>.from(decoded);
}

class _PlayerResult {
  final String playability;
  final String detail;
  final String? url;
  final bool directUrl;

  const _PlayerResult({
    required this.playability,
    required this.detail,
    this.url,
    this.directUrl = false,
  });

  @override
  String toString() => '$playability — $detail';
}

class _PageResult {
  final int status;
  final String? visitorData;
  final String detail;
  final String? directUrl;

  const _PageResult({
    required this.status,
    required this.detail,
    this.visitorData,
    this.directUrl,
  });

  @override
  String toString() =>
      'HTTP $status, $detail${visitorData == null ? '' : ', visitorData ok'}';
}

class _MediaResult {
  final int status;
  final int bytes;
  final String contentType;
  final String probe;

  const _MediaResult({
    required this.status,
    required this.bytes,
    required this.contentType,
    required this.probe,
  });

  @override
  String toString() =>
      'HTTP $status, $bytes bytes, ${contentType.isEmpty ? 'no content-type' : contentType}; '
      'ranges: $probe';
}
