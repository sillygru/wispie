// SPDX-License-Identifier: GPL-3.0-only

// Verifies the online lyrics chain used for streamed tracks, with the same
// query set and ranking the app uses: every reading of the upload tags is
// looked up in parallel, the results are ranked against the cleaned title, and
// a timed record always beats an untimed one. Run it with a track that exposes
// the awkward case (a channel name in the artist tag):
//
//   dart run tool/lyrics_probe.dart S9bCLPwzSC0 "Eminem - Mockingbird (Lyrics)" "Dan Music"
//
// RESULT: ok means at least one reading returned lyrics.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

import 'package:wispie/domain/models/lrclib_result.dart';
import 'package:wispie/domain/services/lrclib_match.dart';
import 'package:wispie/domain/services/lrclib_query.dart';
import 'package:wispie/models/song.dart';

/// The aggregator the app prefers, and the source it falls back to. The
/// aggregator is a self-hosted tunnel and is genuinely down sometimes, so the
/// probe follows both paths the app does.
const String _baseUrl = 'https://music.gru0.dev/api';
const String _lrclibUrl = 'https://lrclib.net/api';

Future<Object?> _getJson(
  String path,
  Map<String, String> params, {
  String base = _baseUrl,
}) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('$base$path').replace(queryParameters: params);
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    request.headers.set(HttpHeaders.userAgentHeader, 'wispie-lyrics-probe/1.0');
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) return null;
    return jsonDecode(body);
  } catch (error) {
    print('  request failed: $error');
    return null;
  } finally {
    client.close(force: true);
  }
}

Map<String, String> _params(LyricsQuery query, {String? videoId}) => {
      'track_name': query.title,
      if (query.artist != null) 'artist_name': query.artist!,
      if (videoId != null && videoId.isNotEmpty) 'video_id': videoId,
      'include_rich_sync': 'true',
      'sync_type': 'richsync',
    };

LrclibResult? _result(Object? decoded) {
  if (decoded is! Map<String, dynamic>) return null;
  final result = LrclibResult.fromJson(decoded);
  return result.isUsable ? result : null;
}

String _describe(LrclibResult result) {
  final lines = (result.syncedLyrics ?? result.plainLyrics ?? '')
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();
  final kind = result.richLyrics != null
      ? 'rich'
      : result.hasSynced
          ? 'synced'
          : 'plain';
  final first = lines.isEmpty ? '(no text)' : lines.first;
  return '${result.artistName} - ${result.trackName} [$kind] '
      'first line: $first';
}

Future<void> main(List<String> args) async {
  final videoId = args.isNotEmpty ? args[0] : 'S9bCLPwzSC0';
  final rawTitle = args.length > 1 ? args[1] : 'Eminem - Mockingbird (Lyrics)';
  final artist = args.length > 2 ? args[2] : 'Dan Music';

  final queries = lyricsQueriesFor(
    title: rawTitle,
    artist: artist,
    remote: true,
  );
  print('title "$rawTitle", artist "$artist", video "$videoId"');
  for (var i = 0; i < queries.length; i++) {
    print(
        'query ${i + 1}: "${queries[i].title}" / ${queries[i].artist ?? '-'}');
  }

  // The app stops at three readings; the probe mirrors that exactly.
  final attempts = queries.take(3).toList();
  final found = <int, LrclibResult>{};

  void keep(LrclibResult? result) {
    if (result != null) found.putIfAbsent(result.id, () => result);
  }

  void keepAll(Object? decoded) {
    if (decoded is! List) return;
    for (final entry in decoded) {
      if (entry is Map<String, dynamic>) keep(_result(entry));
    }
  }

  await Future.wait([
    for (var i = 0; i < attempts.length; i++) ...[
      _getJson('/lyrics/get',
              _params(attempts[i], videoId: i == 0 ? videoId : null))
          .then(_result)
          .then(keep),
      _getJson('/lyrics/search', {..._params(attempts[i]), 'limit': '20'})
          .then(keepAll),
      // Direct LRCLIB always runs: the aggregator is not the whole catalogue.
      _getJson('/get', _params(attempts[i]), base: _lrclibUrl)
          .then(_result)
          .then(keep),
      _getJson(
        '/search',
        {
          'track_name': attempts[i].title,
          if (attempts[i].artist != null) 'artist_name': attempts[i].artist!,
        },
        base: _lrclibUrl,
      ).then(keepAll),
    ],
  ]);

  // Providers return the same recording under several ids; one line each is
  // enough to see what the ranking had to choose from.
  final seen = <String>{};
  for (final result in found.values) {
    final line = _describe(result);
    if (seen.add(line)) print('  candidate: $line');
  }
  print('${found.length} candidates, ${seen.length} distinct records');

  if (found.isEmpty) {
    // Same last resort as the service: one free-text search per reading.
    await Future.wait([
      for (final query in attempts) ...[
        _getJson('/lyrics/search', {
          'q': [query.title, query.artist].whereType<String>().join(' '),
          'limit': '20',
        }).then(keepAll),
        _getJson(
          '/search',
          {
            'q': [query.title, query.artist].whereType<String>().join(' ')
          },
          base: _lrclibUrl,
        ).then(keepAll),
      ],
    ]);
    print('free-text fallback: ${found.length} candidates');
  }

  if (found.isEmpty) {
    print('RESULT: no lyrics found');
    exitCode = 1;
    return;
  }

  final ranked = rankLrclibResults(
    found.values.toList(),
    Song(
      title: attempts.first.title,
      artist: attempts.first.artist ?? artist,
      album: '',
      filename: 'youtube:$videoId',
      url: '',
      source: SongSource.youtube,
      remoteId: videoId,
    ),
  );
  final timed = ranked.where((r) => r.hasSynced || r.hasRichSync);

  print('chosen (${timed.isNotEmpty ? 'timed' : 'untimed'} of '
      '${ranked.length} candidates):');
  print('  ${_describe(timed.isNotEmpty ? timed.first : ranked.first)}');
  print('RESULT: ok');
}
