// SPDX-License-Identifier: GPL-3.0-only
//
// Golden probe for the native hot paths: lyric word timing, search ranking and
// typo matching live in the Rust core, so this runs it over the corpus recorded
// from the Dart reference and diffs every output.
//
//   WISPIE_CORE_LIB=rust/target/release/libwispie_core.dylib \
//     dart run tool/rust_hotpath_probe.dart
//
// The golden file also holds the Dart timings measured before the port, which
// is what the speedup column compares against.
//
// Artifact: build/rust_hotpath/report.md (exit code 1 on any regression).

import 'dart:convert';
import 'dart:io';

import 'package:wispie/data/rust/wispie_core.dart';
import 'package:wispie/domain/models/search_filter.dart';
import 'package:wispie/domain/models/search_result.dart';
import 'package:wispie/domain/services/lyrics_prosodic_estimator.dart';
import 'package:wispie/domain/services/search_fuzzy.dart';
import 'package:wispie/domain/services/search_ranking.dart';
import 'package:wispie/domain/services/search_taste.dart';
import 'package:wispie/models/song.dart';

const String _goldenPath = 'tool/fixtures/hotpath_goldens.json';
const int _toleranceUs = 200000;

void main() {
  if (!WispieCore.isAvailable) {
    stderr.writeln('native core unavailable: ${WispieCore.unavailableReason}');
    exit(2);
  }

  final goldens =
      jsonDecode(File(_goldenPath).readAsStringSync()) as Map<String, dynamic>;
  final failures = <String>[];
  final cases = <_Case>[];
  final checks = <String, bool>{};

  void check(String name, bool ok, [String detail = '']) {
    checks[name] = ok;
    if (!ok) failures.add('$name${detail.isEmpty ? '' : '  ($detail)'}');
    stdout.writeln(
        '  ${ok ? 'ok  ' : 'FAIL'} $name${detail.isEmpty ? '' : ' -> $detail'}');
  }

  final lyricRows = (goldens['lyrics'] as List<dynamic>).cast<Map>();
  final songRows = goldens['songs'] as List<dynamic>;
  final tasteMaps = goldens['taste'] as Map;
  final baseline = (goldens['dartMicros'] as Map).cast<String, int>();

  final songs = [
    for (final row in songRows.cast<Map>())
      Song(
        title: row['title'] as String,
        artist: row['artist'] as String,
        album: row['album'] as String,
        filename: row['filename'] as String,
        url: '/library/${row['filename']}',
      ),
  ];
  final songsByFilename = {for (final song in songs) song.filename: song};
  final taste = SearchTaste(
    songs: _doubles(tasteMaps['songs'] as Map),
    artists: _doubles(tasteMaps['artists'] as Map),
  );

  stdout.writeln('goldens: ${lyricRows.length} lyric lines, '
      '${songs.length} songs, ${(goldens['rank'] as List<dynamic>).length} '
      'rank queries');

  // --- lyric word timing -----------------------------------------------------
  stdout.writeln('\nLyric word timing');
  final lineInputs = [
    for (final row in lyricRows)
      (
        text: row['text'] as String,
        start: Duration(microseconds: (row['startUs'] as num).toInt()),
        end: Duration(microseconds: (row['endUs'] as num).toInt()),
        songCps: (row['songCps'] as num).toDouble(),
      ),
  ];

  // Timing is an analytic model now, so boundaries are checked within a
  // tolerance; the tokens themselves must still be exactly the same.
  var textMatch = true;
  var boundaries = 0;
  var withinTolerance = 0;
  var totalErrorUs = 0;
  final words = LyricsProsodicEstimator.estimateLinesWords(lineInputs);
  for (var i = 0; i < lyricRows.length; i++) {
    final expected = (lyricRows[i]['words'] as List<dynamic>).cast<Map>();
    if (words[i].length != expected.length) {
      textMatch = false;
      continue;
    }
    for (var w = 0; w < expected.length; w++) {
      final want = expected[w];
      final got = words[i][w];
      if (got.text != want['text']) textMatch = false;
      final error =
          (got.start.inMicroseconds - (want['startUs'] as num).toInt()).abs();
      totalErrorUs += error;
      if (error <= _toleranceUs) withinTolerance++;
      boundaries++;
    }
  }
  final share = boundaries == 0 ? 0.0 : withinTolerance / boundaries;
  final meanMs = boundaries == 0 ? 0.0 : totalErrorUs / boundaries / 1000;
  check('prosody: word text identical to the reference', textMatch);
  check(
    'prosody: boundaries land within ${_toleranceUs ~/ 1000} ms',
    share >= 0.8,
    '${(share * 100).round()}% of $boundaries, mean '
        '${meanMs.toStringAsFixed(0)} ms',
  );

  cases.add(_Case(
    'lyric word timing',
    baseline['prosody']!,
    _best(5, () => LyricsProsodicEstimator.estimateLinesWords(lineInputs)),
    'lines',
  ));

  // --- search ranking --------------------------------------------------------
  stdout.writeln('\nSearch ranking');
  final rankSets = (goldens['rank'] as List<dynamic>).cast<Map>();
  var rankMatch = true;
  final rankInputs = <(String, List<SearchResult>)>[];

  for (final set in rankSets) {
    final rows = (set['rows'] as List<dynamic>).cast<Map>();
    rankInputs.add((
      set['query'] as String,
      [
        for (final row in rows)
          SearchResult(
            song: songsByFilename[row['filename']]!,
            matchedFilters: {
              if (row['matchedTitle'] == true) SearchFilterType.songs,
              if (row['matchedArtist'] == true) SearchFilterType.artists,
              if (row['matchedAlbum'] == true) SearchFilterType.albums,
            },
            lyricsMatch: row['lyricsLine'] == null
                ? null
                : LyricsMatch(
                    matchedText: set['query'] as String,
                    fullLine: row['lyricsLine'] as String,
                  ),
          ),
      ],
    ));
  }

  for (var i = 0; i < rankInputs.length; i++) {
    final (query, results) = rankInputs[i];
    final ranked = rankSearchResults(
      results: results,
      query: query,
      taste: taste,
    );
    final order = [for (final result in ranked) results.indexOf(result)];
    final expected = (rankSets[i]['order'] as List<dynamic>).cast<int>();
    if (order.join(',') != expected.join(',')) rankMatch = false;
  }
  check('rank: every query orders the rows exactly as recorded', rankMatch);

  cases.add(_Case(
    'search ranking (40 hits x ${rankInputs.length} queries)',
    baseline['rank']!,
    _best(5, () {
      for (final (query, results) in rankInputs) {
        rankSearchResults(results: results, query: query, taste: taste);
      }
    }),
    'queries',
  ));

  // --- typo matching ---------------------------------------------------------
  stdout.writeln('\nTypo matching');
  final fuzzySets = (goldens['fuzzy'] as List<dynamic>).cast<Map>();
  final fuzzyInputs = <String>[
    for (final set in fuzzySets) set['query'] as String,
  ];
  var fuzzyMatch = true;

  for (var i = 0; i < fuzzyInputs.length; i++) {
    final hits = _fuzzy(fuzzyInputs[i], songs, taste);
    final actual = [
      for (final hit in hits)
        '${songs.indexOf(hit.song)}:${hit.matchedFilters.first.name}',
    ];
    final expected = (fuzzySets[i]['matches'] as List<dynamic>).cast<String>();
    if (actual.join(',') != expected.join(',')) fuzzyMatch = false;
  }
  check('typo: every query returns the rows recorded for it', fuzzyMatch);

  cases.add(_Case(
    'typo scan (${songs.length} songs x ${fuzzyInputs.length} queries)',
    baseline['typo']!,
    _best(5, () {
      for (final query in fuzzyInputs) {
        _fuzzy(query, songs, taste);
      }
    }),
    'queries',
  ));

  // --- report ---------------------------------------------------------------
  for (final item in cases) {
    check(
        '${item.name}: native is faster than the recorded Dart run',
        item.nativeMicros < item.dartMicros,
        '${item.dartMillis} vs ${item.nativeMillis}');
  }

  final report = StringBuffer()
    ..writeln('# Native hot paths')
    ..writeln()
    ..writeln('Generated by `dart run tool/rust_hotpath_probe.dart`.')
    ..writeln()
    ..writeln('- platform: ${Platform.operatingSystem}, '
        'dart ${Platform.version.split(' ').first}')
    ..writeln('- checked against `$_goldenPath`, recorded from the Dart '
        'reference before it was removed')
    ..writeln('- ranking and typo matching must match it exactly; lyric word '
        'timing is an analytic model and is checked within '
        '${_toleranceUs ~/ 1000} ms')
    ..writeln('- Dart column: that recorded run. Native: best of 5 now')
    ..writeln('- parity checks: ${checks.values.where((ok) => ok).length}'
        ' of ${checks.length} passed')
    ..writeln()
    ..writeln('| Case | Dart | Native | Speedup | Unit |')
    ..writeln('| --- | ---: | ---: | ---: | --- |');
  for (final item in cases) {
    report.writeln('| ${item.name} | ${item.dartMillis} '
        '| ${item.nativeMillis} | ${item.speedup.toStringAsFixed(1)}x '
        '| ${item.unit} |');
  }
  report
    ..writeln()
    ..writeln(failures.isEmpty
        ? 'All checks passed.'
        : '${failures.length} checks failed:')
    ..writeln()
    ..writeln([for (final failure in failures) '- $failure'].join('\n'));

  final artifact = File('build/rust_hotpath/report.md')
    ..createSync(recursive: true)
    ..writeAsStringSync(report.toString());

  stdout.write('\n${report.toString()}');
  stdout.writeln('Report: ${artifact.path}');

  exitCode = failures.isEmpty ? 0 : 1;
}

List<SearchResult> _fuzzy(String query, List<Song> songs, SearchTaste taste) =>
    fuzzyMatches(
      query.split(RegExp(r'\s+')).where((token) => token.isNotEmpty).toList(),
      songs,
      const {},
      taste: taste,
      titles: true,
      artists: true,
      albums: true,
    );

Map<String, double> _doubles(Map raw) => {
      for (final entry in raw.entries)
        entry.key as String: (entry.value as num).toDouble(),
    };

int _best(int runs, void Function() body) {
  var best = 1 << 62;
  for (var i = 0; i < runs; i++) {
    final watch = Stopwatch()..start();
    body();
    watch.stop();
    if (watch.elapsedMicroseconds < best) best = watch.elapsedMicroseconds;
  }
  return best;
}

String _ms(int micros) => '${(micros / 1000).toStringAsFixed(2)} ms';

class _Case {
  _Case(this.name, this.dartMicros, this.nativeMicros, this.unit);

  final String name;
  final int dartMicros;
  final int nativeMicros;
  final String unit;

  double get speedup => nativeMicros == 0 ? 0 : dartMicros / nativeMicros;
  String get dartMillis => _ms(dartMicros);
  String get nativeMillis => _ms(nativeMicros);
}
