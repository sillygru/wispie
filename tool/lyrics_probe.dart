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
import 'package:wispie/domain/models/rich_lyrics.dart';
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

  // What the "find lyrics" picker used to ask: one reading of the file's own
  // tags. It returns nothing for an upload whose artist tag is the channel, so
  // the sheet reported "no results" for tracks the player had lyrics for. The
  // picker now asks the query set above; this number is the regression guard.
  final pickerTitle = cleanSearchTitle(rawTitle, artist: artist);
  final pickerFound = <int, LrclibResult>{};
  void keepPicker(LrclibResult? result) {
    if (result != null) pickerFound.putIfAbsent(result.id, () => result);
  }

  void keepPickerAll(Object? decoded) {
    if (decoded is! List) return;
    for (final entry in decoded) {
      if (entry is Map<String, dynamic>) keepPicker(_result(entry));
    }
  }

  await Future.wait([
    _getJson(
      '/get',
      {
        'track_name': pickerTitle,
        'artist_name': artist,
        'include_rich_sync': 'true',
        'sync_type': 'richsync',
      },
      base: _lrclibUrl,
    ).then(_result).then(keepPicker),
    _getJson(
      '/search',
      {'track_name': pickerTitle, 'artist_name': artist},
      base: _lrclibUrl,
    ).then(keepPickerAll),
  ]);
  if (pickerFound.isEmpty) {
    await _getJson(
      '/search',
      {'q': '$pickerTitle $artist'},
      base: _lrclibUrl,
    ).then(keepPickerAll);
  }
  print('one-reading shape ("$pickerTitle" / "$artist"): '
      '${pickerFound.length} candidates, where the picker asks '
      '${attempts.length} readings and found ${found.length}');

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
  final chosen = timed.isNotEmpty ? timed.first : ranked.first;
  print('  ${_describe(chosen)}');

  // Word-level timings are saved to disk, so the payload has to survive the
  // round trip through RichLyrics.toJson/fromJson with its timings intact.
  final rich = chosen.richLyrics;
  if (rich == null) {
    print('word sync: none in the chosen record; line sync is the fallback');
  } else {
    final restored = RichLyrics.fromJson(jsonDecode(jsonEncode(rich.toJson())));
    final firstWords = rich.lines.isEmpty ? 0 : rich.lines.first.words.length;
    final same = restored != null &&
        restored.lines.length == rich.lines.length &&
        (restored.lines.isEmpty
            ? true
            : restored.lines.first.start == rich.lines.first.start &&
                restored.lines.first.words.length == firstWords);
    print('word sync: ${rich.lines.length} lines, word timings survive a save: '
        '$same');
    if (!same) exitCode = 1;
  }

  // Word sync only comes from the aggregator, so the format is checked against
  // a payload of our own: this is what the on-disk cache holds and reads back.
  const sample = RichLyrics(
    title: 'sample',
    artist: 'sample',
    duration: Duration(minutes: 3),
    lines: [
      RichLyricLine(
        start: Duration(milliseconds: 1500),
        end: Duration(milliseconds: 3200),
        text: 'hello world',
        words: [
          RichLyricWord(
            start: Duration(milliseconds: 1500),
            end: Duration(milliseconds: 2400),
            text: 'hello',
          ),
          RichLyricWord(
            start: Duration(milliseconds: 2400),
            end: Duration(milliseconds: 3200),
            text: 'world',
          ),
        ],
      ),
      RichLyricLine(
        start: Duration(milliseconds: 4000),
        end: Duration(milliseconds: 5000),
        text: 'estimated line',
        isSimulated: true,
      ),
    ],
  );
  final restored = RichLyrics.fromJson(jsonDecode(jsonEncode(sample.toJson())));
  final intact = restored != null &&
      restored.duration == const Duration(minutes: 3) &&
      restored.lines.length == 2 &&
      restored.lines.first.words.length == 2 &&
      restored.lines.first.words[1].start ==
          const Duration(milliseconds: 2400) &&
      restored.lines.first.words[1].end == const Duration(milliseconds: 3200) &&
      restored.lines[1].isSimulated &&
      restored.lines[1].words.isEmpty;
  print('cache format: word timings, simulated flags and duration survive a '
      'save: $intact');
  if (!intact) exitCode = 1;
  print('RESULT: ok');
}
