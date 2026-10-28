// SPDX-License-Identifier: GPL-3.0-only
//
// End-to-end probe for the taste model's newness channel.
//
//   dart run tool/taste_probe.dart
//
// Checks two things a listener would notice: a track added to an established
// library is preferred for a while, and a library that all arrived together has
// no \"newer\" rows to prefer. Then it checks the weight itself through the
// shipping smart-shuffle maths, including how little it does in familiar mode.
//
// Artifact: build/taste_probe.json (exit code 1 on any failure).

import 'dart:convert';
import 'dart:io';

import 'package:wispie/domain/services/shuffle_selector.dart'
    show ShuffleContext;
import 'package:wispie/domain/services/smart_weights.dart';
import 'package:wispie/domain/services/taste_model.dart';

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

final DateTime _now = DateTime.utc(2026, 10, 28, 12);
final double _nowSec = _now.millisecondsSinceEpoch / 1000.0;

double _addedDaysAgo(double days) => _nowSec - days * 86400.0;

Map<String, double> _newnessOf(Map<String, double> addedAt) =>
    buildTasteSnapshot(
      TasteInputs(
          events: const [], meta: const {}, now: _now, addedAt: addedAt),
    ).newness;

TasteSnapshot _snapshot({
  Map<String, SongTaste> songs = const {},
  Map<String, ArtistTaste> artists = const {},
  Map<String, double> newness = const {},
}) =>
    TasteSnapshot(
      songs: songs,
      artists: artists,
      coPlay: const {},
      artistCoPlay: const {},
      newness: newness,
    );

SongTaste _played({double trend = 0, double long = 0, int plays = 1}) =>
    SongTaste(
      trendMass: trend,
      longMass: long,
      saturation: 0,
      skipRate: 0,
      playCount: plays,
      lastPlayed: _nowSec,
    );

double _weightOf(
  String item, {
  required TasteSnapshot taste,
  required double familiarity,
}) {
  final weights = computeSmartWeights<String>(
    pool: [
      SmartCandidate<String>(
        item: 'fresh',
        filenames: const ['fresh.flac'],
        artistKey: 'nova',
        albumKey: 'album',
      ),
      SmartCandidate<String>(
        item: 'old',
        filenames: const ['old.flac'],
        artistKey: 'nova',
        albumKey: 'album',
      ),
    ],
    taste: taste,
    familiarity: familiarity,
    context: ShuffleContext.library,
  );
  return weights[item] ?? 0;
}

Future<void> main() async {
  stdout.writeln('\nLibrary age');
  final established = <String, double>{
    for (var i = 0; i < 20; i++) 'old$i.flac': _addedDaysAgo(20.0 + i * 18),
    'fresh.flac': _addedDaysAgo(0),
  };
  final newness = _newnessOf(established);
  check(
    'newness: a track added today to an old library is fully new',
    (newness['fresh.flac'] ?? 0) > 0.99,
    detail: newness['fresh.flac'],
  );
  check(
    'newness: rows older than the window are not new at all',
    !newness.containsKey('old19.flac'),
    detail: newness.keys.toList(),
  );
  check(
    'newness: only the recent arrivals are listed',
    newness.length < established.length,
    detail: '${newness.length} of ${established.length}',
  );
  final partly = _newnessOf({
    for (var i = 0; i < 20; i++) 'old$i.flac': _addedDaysAgo(100.0 + i * 12),
    'mid.flac': _addedDaysAgo(60),
  });
  check(
    'newness: two months in an old library is a partial signal',
    (partly['mid.flac'] ?? 0) > 0.2 && (partly['mid.flac'] ?? 0) < 0.5,
    detail: partly['mid.flac'],
  );

  stdout.writeln('\nBulk imports');
  final bulk = _newnessOf({
    for (var i = 0; i < 395; i++) 'imported$i.flac': _addedDaysAgo(0),
    for (var i = 0; i < 10; i++) 'original$i.flac': _addedDaysAgo(1),
  });
  check(
    'bulk: a 395-track import into a one-day-old library is not favoured',
    bulk.isEmpty,
    detail: bulk.length,
  );
  final oneImport = _newnessOf({
    for (var i = 0; i < 20; i++) 'imported$i.flac': _addedDaysAgo(20),
    'later.flac': _addedDaysAgo(0),
  });
  check(
    'bulk: a library that all arrived last month has no newer rows',
    oneImport.isEmpty,
    detail: oneImport.length,
  );
  final halfImport = _newnessOf({
    for (var i = 0; i < 20; i++) 'old$i.flac': _addedDaysAgo(200.0 + i),
    for (var i = 0; i < 20; i++) 'imported$i.flac': _addedDaysAgo(1),
  });
  check(
    'bulk: a fresh half does not make the older half invisible',
    (halfImport['old0.flac'] ?? 0) == 0 &&
        (halfImport['imported0.flac'] ?? 0) > 0,
    detail:
        'old=${halfImport['old0.flac']} new=${halfImport['imported0.flac']}',
  );
  check(
    'bulk: a library with nothing to compare against yields nothing',
    _newnessOf({'only.flac': _addedDaysAgo(400)}).isEmpty,
  );

  stdout.writeln('\nWeights');
  final fresh = _snapshot(newness: {'fresh.flac': 1.0});
  final discovery = _weightOf('fresh', taste: fresh, familiarity: 0.0);
  final familiar = _weightOf('fresh', taste: fresh, familiarity: 1.0);
  final plain = _weightOf('fresh', taste: _snapshot(), familiarity: 0.0);
  check(
    'weights: a new track is preferred over an equally unplayed old one',
    discovery > _weightOf('old', taste: fresh, familiarity: 0.0),
    detail: discovery,
  );
  check(
    'weights: discovery notices a new arrival more than familiar does',
    discovery > familiar && familiar > plain,
    detail: 'discovery=$discovery familiar=$familiar plain=$plain',
  );
  check(
    'weights: familiar mode keeps the lift small',
    familiar / plain < 1.10,
    detail: familiar / plain,
  );
  check(
    'weights: with no newness the two rows are equal',
    (plain - _weightOf('old', taste: _snapshot(), familiarity: 0.0)).abs() <
        1e-9,
  );

  final played = _snapshot(
    songs: {'old.flac': _played(trend: 1.0, long: 1.0, plays: 8)},
    artists: const {
      'nova': ArtistTaste(trendMass: 1.0, longMass: 1.0),
    },
    newness: {'fresh.flac': 1.0},
  );
  check(
    'weights: newness does not outrank a song this device actually plays',
    _weightOf('old', taste: played, familiarity: 1.0) >
        _weightOf('fresh', taste: played, familiarity: 1.0),
    detail: [
      _weightOf('old', taste: played, familiarity: 1.0),
      _weightOf('fresh', taste: played, familiarity: 1.0),
    ],
  );

  final artifact = File('build/taste_probe.json');
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
