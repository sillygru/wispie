// SPDX-License-Identifier: GPL-3.0-only

// Verifies the online lyrics chain used for streamed tracks, in the same order
// the app tries it: video id, then tags, then a free-text search. Run it with a
// track that exposes the awkward case (a channel name in the artist tag):
//
//   dart run tool/lyrics_probe.dart S9bCLPwzSC0 "Eminem - Mockingbird (Lyrics)" "Dan Music"
//
// RESULT: ok means at least one tier returned lyrics.

// ignore_for_file: avoid_print

import 'dart:convert';
import 'dart:io';

const String _baseUrl = 'https://music.gru0.dev/api';

final _bracketGroup = RegExp(r'[\(\[]([^\)\]]*)[\)\]]');
const _noiseWords = <String>{
  'official',
  'audio',
  'video',
  'lyric',
  'visualizer',
  'visualiser',
  'explicit',
  'remaster',
  'hd',
  'hq',
  '4k',
  'mv',
  'prod',
};

/// Same cleaning rule as `cleanSearchTitle`, minus the artist-prefix strip: the
/// probe's artist tag is the uploader, which deliberately does not match.
String cleanTitle(String title) {
  final stripped = title.replaceAllMapped(
    _bracketGroup,
    (match) => _noiseWords.any(match.group(1)!.toLowerCase().contains)
        ? ''
        : match.group(0)!,
  );
  final collapsed = stripped.replaceAll(RegExp(r'\s+'), ' ').trim();
  return collapsed.replaceAll(RegExp(r'^[-–—:|\s]+|[-–—:|\s]+$'), '');
}

Future<(int, Map<String, dynamic>?)> get(
  Map<String, String> params,
) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('$_baseUrl/lyrics/get').replace(
      queryParameters: {
        ...params,
        'include_rich_sync': 'true',
        'sync_type': 'richsync'
      },
    );
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) {
      return (response.statusCode, null);
    }
    final decoded = jsonDecode(body);
    return (
      response.statusCode,
      decoded is Map<String, dynamic> ? decoded : null
    );
  } catch (error) {
    print('  request failed: $error');
    return (0, null);
  } finally {
    client.close(force: true);
  }
}

Future<List<Map<String, dynamic>>> search(String query) async {
  final client = HttpClient();
  try {
    final uri = Uri.parse('$_baseUrl/lyrics/search').replace(
      queryParameters: {'q': query, 'limit': '20'},
    );
    final request = await client.getUrl(uri);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final response = await request.close().timeout(const Duration(seconds: 12));
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != HttpStatus.ok) return const [];
    final decoded = jsonDecode(body);
    if (decoded is! List) return const [];
    return decoded.whereType<Map<String, dynamic>>().toList();
  } catch (_) {
    return const [];
  } finally {
    client.close(force: true);
  }
}

String describe(Map<String, dynamic> result) {
  final lines = (result['syncedLyrics'] ?? result['plainLyrics'] ?? '')
      .toString()
      .split('\n')
      .where((line) => line.trim().isNotEmpty)
      .toList();
  final first = lines.isEmpty ? '(no text)' : lines.first;
  final kind = result['syncedLyrics'] != null
      ? 'synced'
      : result['richSync'] != null
          ? 'rich'
          : 'plain';
  return '${result['artistName']} - ${result['trackName']} [$kind] first line: $first';
}

Future<void> main(List<String> args) async {
  final videoId = args.isNotEmpty ? args[0] : 'S9bCLPwzSC0';
  final rawTitle = args.length > 1 ? args[1] : 'Eminem - Mockingbird (Lyrics)';
  final artist = args.length > 2 ? args[2] : 'Dan Music';
  final title = cleanTitle(rawTitle);

  print(
      'title "$rawTitle" -> query "$title", artist "$artist", video "$videoId"');

  bool timed(Map<String, dynamic>? result) =>
      result != null &&
      (result['syncedLyrics'] != null || result['richSync'] != null);

  Map<String, dynamic>? chosen;
  Map<String, dynamic>? untimed;
  var tier = '';

  final (videoStatus, byVideo) = await get({
    'track_name': title,
    'artist_name': artist,
    'video_id': videoId,
  });
  print('tier 1 (video id): HTTP $videoStatus');
  if (byVideo != null) {
    print('  ${describe(byVideo)}');
    if (timed(byVideo)) {
      chosen = byVideo;
      tier = 'video id';
    } else {
      untimed = byVideo;
    }
  }

  if (chosen == null) {
    final (tagStatus, byTags) = await get({
      'track_name': title,
      'artist_name': artist,
    });
    print('tier 2 (tags): HTTP $tagStatus');
    if (byTags != null) {
      print('  ${describe(byTags)}');
      if (timed(byTags)) {
        chosen = byTags;
        tier = 'tags';
      } else {
        untimed ??= byTags;
      }
    }
  }

  if (chosen == null) {
    final results = await search(title);
    print('tier 3 (free text): ${results.length} results');
    for (final result in results.take(2)) {
      print('  ${describe(result)}');
    }
    final withTimings = results.where(timed).toList();
    if (withTimings.isNotEmpty) {
      chosen = withTimings.first;
      tier = 'free text (timed)';
    } else if (results.isNotEmpty) {
      chosen = results.first;
      tier = 'free text (untimed)';
    }
  }

  chosen ??= untimed;
  if (chosen == null) {
    print('RESULT: no lyrics found');
    exitCode = 1;
    return;
  }

  print('chosen from $tier:');
  print('  ${describe(chosen)}');
  print('RESULT: ok');
}
