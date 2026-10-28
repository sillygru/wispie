// SPDX-License-Identifier: GPL-3.0-only
//
// End-to-end probe for the search ranker.
//
//   dart run tool/search_probe.dart
//
// Drives the shipping ranking code over real `SearchResult` values, then checks
// what a listener notices: songs before artist/album/lyric hits, an exact word
// above a prefix above a fragment, the word pair above the same words split
// across two other words, and a title tie going to the artist this device
// actually plays.
//
// Artifact: build/search_probe.json (exit code 1 on any failure).

import 'dart:convert';
import 'dart:io';

import 'package:wispie/domain/models/search_filter.dart';
import 'package:wispie/domain/models/search_result.dart';
import 'package:wispie/domain/services/search_ranking.dart';
import 'package:wispie/domain/services/search_taste.dart';
import 'package:wispie/domain/services/taste_model.dart';
import 'package:wispie/models/song.dart';

final List<Map<String, Object?>> _results = [];
int _passed = 0;
int _failed = 0;

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

Song song(String name, {String artist = 'Nova', String album = 'Album'}) =>
    Song(
      title: name,
      artist: artist,
      album: album,
      filename: '${name.toLowerCase().replaceAll(' ', '_')}.mp3',
      url: '/tmp/${name.toLowerCase().replaceAll(' ', '_')}.mp3',
    );

SearchResult hit(
  Song song,
  SearchFilterType field, {
  String? lyricLine,
}) {
  if (field == SearchFilterType.lyrics) {
    return SearchResult(
      song: song,
      matchedFilters: {SearchFilterType.lyrics},
      lyricsMatch: LyricsMatch(matchedText: 'sweet', fullLine: lyricLine ?? ''),
    );
  }
  return SearchResult(song: song, matchedFilters: {field});
}

int indexOfFilename(List<SearchResult> results, String filename) =>
    results.indexWhere((r) => r.song.filename == filename);

Future<void> main() async {
  final sweetChild = song('Sweet Child O Mine');
  final sweetDreams = song('Sweet Dreams', artist: 'Aurora');
  final unsweetened = song('Unsweetened', artist: 'Kilo');
  final sweetshop = song('Sweetshop', artist: 'Kilo');
  final childishSweets = song('Childish Sweets', artist: 'Nova');
  final sweetArtistHit = song('Ten', artist: 'Sweet Tooth');
  final lyricHit = song('Unrelated', artist: 'Kilo');

  final pool = <SearchResult>[
    hit(sweetChild, SearchFilterType.songs),
    hit(sweetDreams, SearchFilterType.songs),
    hit(unsweetened, SearchFilterType.songs),
    hit(sweetshop, SearchFilterType.songs),
    hit(childishSweets, SearchFilterType.songs),
    hit(sweetArtistHit, SearchFilterType.artists),
    hit(lyricHit, SearchFilterType.lyrics, lyricLine: 'she said sweet'),
  ];

  stdout.writeln('\nField order');
  final sweet = rankSearchResults(results: pool, query: 'sweet');
  check(
    'rank: a title hit outranks an artist hit outranks a lyric hit',
    matchPriority(sweet.first) == 0 &&
        matchPriority(sweet[indexOfFilename(sweet, sweetArtistHit.filename)]) ==
            1 &&
        matchPriority(sweet[indexOfFilename(sweet, lyricHit.filename)]) == 3,
    detail: sweet.map((r) => '${r.song.title}/${matchPriority(r)}').toList(),
  );
  check(
    'rank: the lyric hit still makes the list',
    sweet.any((r) => r.song.filename == lyricHit.filename),
  );

  stdout.writeln('\nMatch quality');
  final byTitle = [
    indexOfFilename(sweet, sweetChild.filename),
    indexOfFilename(sweet, sweetshop.filename),
    indexOfFilename(sweet, unsweetened.filename),
  ];
  check(
    'rank: a whole word beats a prefix beats a fragment',
    byTitle[0] >= 0 && byTitle[1] > byTitle[0] && byTitle[2] > byTitle[1],
    detail: byTitle,
  );

  final phrase = rankSearchResults(
    results: [
      hit(sweetChild, SearchFilterType.songs),
      hit(childishSweets, SearchFilterType.songs),
    ],
    query: 'sweet child',
  );
  check(
    'rank: the exact word pair outranks the words split across two others',
    phrase.first.song.filename == sweetChild.filename,
    detail: phrase.map((r) => r.song.title).toList(),
  );

  stdout.writeln('\nTaste');
  final taste = SearchTaste(
    songs: {sweetDreams.filename: 0.9},
    artists: {tasteArtistKey('Aurora', sweetDreams.filename): 1.0},
  );
  final tasted = rankSearchResults(
    results: pool,
    query: 'sweet',
    taste: taste,
  );
  check(
    'taste: an equally good title match by a played artist leads',
    tasted.first.song.filename == sweetDreams.filename,
    detail: tasted.take(3).map((r) => r.song.title).toList(),
  );
  check(
    'taste: it never outranks match quality',
    indexOfFilename(tasted, sweetDreams.filename) <
            indexOfFilename(tasted, sweetshop.filename) &&
        indexOfFilename(tasted, sweetDreams.filename) <
            indexOfFilename(tasted, unsweetened.filename),
    detail: tasted.map((r) => r.song.title).toList(),
  );
  check(
    'taste: an artist this device still plays leads its own rows',
    SearchTaste(
          artists: {tasteArtistKey('Aurora', 'a.mp3'): 1.0},
        ).scoreOf(sweetDreams) >
        SearchTaste.empty.scoreOf(sweetDreams),
  );

  stdout.writeln('\nStability');
  final again = rankSearchResults(results: pool, query: 'sweet');
  check(
    'rank: the same pool ranks the same way twice',
    [for (final r in again) r.song.filename].join(',') ==
        [for (final r in sweet) r.song.filename].join(','),
    detail: again.map((r) => r.song.title).toList(),
  );
  check(
    'rank: an empty query leaves the order alone',
    [
          for (final r in rankSearchResults(results: pool, query: '  '))
            r.song.filename
        ].join(',') ==
        [for (final r in pool) r.song.filename].join(','),
  );

  final artifact = File('build/search_probe.json');
  await artifact.parent.create(recursive: true);
  await artifact.writeAsString(
    const JsonEncoder.withIndent('  ').convert({
      'passed': _passed,
      'failed': _failed,
      'checks': _results,
    }),
  );

  stdout.writeln(
    '\n$_passed passed, $_failed failed\nartifact: ${artifact.path}',
  );
  if (_failed > 0) exitCode = 1;
}
