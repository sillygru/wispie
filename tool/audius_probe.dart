// SPDX-License-Identifier: GPL-3.0-only
//
// Probes the Audius endpoints the app uses, so a failure can be reported as an
// HTTP status instead of "playback did not work".
//
//   AUDIUS_API_KEY=... dart run tool/audius_probe.dart [query] [concurrency]
//
// ignore_for_file: avoid_print
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> args) async {
  final query = args.isNotEmpty ? args[0] : 'lofi';
  final concurrency = args.length > 1 ? int.tryParse(args[1]) ?? 8 : 8;
  final key = Platform.environment['AUDIUS_API_KEY']?.trim() ?? '';

  final client = HttpClient()..maxConnectionsPerHost = concurrency;
  try {
    print(
      'API key: ${key.isEmpty ? 'not set (anonymous)' : 'set (${key.length} chars)'}',
    );

    final tracks = await _search(client, key, query);
    final streamable = tracks.where((track) => track.streamable).toList();
    print(
      'search: ${tracks.length} tracks for "$query" '
      '(${tracks.length - streamable.length} not streamable)',
    );
    if (tracks.isEmpty) {
      exitCode = 1;
      return;
    }

    final first = streamable.isNotEmpty ? streamable.first : tracks.first;
    final resolved = await _stream(client, key, first.id);
    print('stream?no_redirect=true [${first.id}]: HTTP ${resolved.status}');
    if (resolved.url == null) {
      print('resolved url: missing');
    } else {
      final playable = await _head(client, resolved.url!);
      print(
        'resolved url: HTTP ${playable.status} ${playable.contentType ?? ''}',
      );
    }

    print('concurrency $concurrency:');
    final results = await Future.wait([
      for (final track in tracks.take(concurrency))
        _stream(client, key, track.id),
    ]);
    for (var i = 0; i < results.length; i++) {
      final result = results[i];
      print(
        '  ${tracks[i].id}: HTTP ${result.status}'
        '${result.url == null ? '' : ' url=ok'}',
      );
    }
  } finally {
    client.close(force: true);
  }
}

Future<List<({String id, bool streamable})>> _search(
  HttpClient client,
  String key,
  String query,
) async {
  final uri = Uri.https('api.audius.co', '/v1/tracks/search', {
    'query': query,
    'limit': '25',
  });
  final response = await _get(client, uri, key);
  final body = await response.transform(utf8.decoder).join();
  print('search HTTP ${response.statusCode}');
  if (response.statusCode != 200) {
    print('body: ${_snippet(body)}');
    return const [];
  }
  final decoded = jsonDecode(body);
  final data = decoded is Map ? decoded['data'] : null;
  if (data is! List) return const [];
  return [
    for (final track in data)
      if (track is Map && track['id'] != null)
        (
          id: track['id'].toString(),
          streamable:
              track['is_streamable'] != false && track['is_delete'] != true,
        ),
  ];
}

Future<({int status, String? url})> _stream(
  HttpClient client,
  String key,
  String id,
) async {
  final uri = Uri.https('api.audius.co', '/v1/tracks/$id/stream', {
    'no_redirect': 'true',
    if (key.isNotEmpty) 'api_key': key,
  });
  final response = await _get(client, uri, key);
  final body = await response.transform(utf8.decoder).join();
  String? url;
  if (response.statusCode == 200) {
    final decoded = jsonDecode(body);
    final data = decoded is Map ? decoded['data'] : null;
    if (data is String && data.isNotEmpty) url = data;
  } else if (body.isNotEmpty) {
    print('  stream $id body: ${_snippet(body)}');
  }
  return (status: response.statusCode, url: url);
}

Future<({int status, String? contentType})> _head(
  HttpClient client,
  String url,
) async {
  final request = await client.headUrl(Uri.parse(url));
  final response = await request.close();
  await response.drain<void>();
  return (
    status: response.statusCode,
    contentType: response.headers.contentType?.mimeType,
  );
}

Future<HttpClientResponse> _get(HttpClient client, Uri uri, String key) async {
  final request = await client.getUrl(uri);
  request.followRedirects = false;
  request.headers.set(HttpHeaders.acceptHeader, 'application/json');
  if (key.isNotEmpty) request.headers.set('x-api-key', key);
  return request.close();
}

String _snippet(String body) =>
    body.length <= 200 ? body : '${body.substring(0, 200)}...';
