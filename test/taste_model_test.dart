import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/models/play_source.dart';
import 'package:wispie/domain/services/taste_model.dart';

final _now = DateTime.utc(2026, 10, 9, 12);
final _nowSec = _now.millisecondsSinceEpoch / 1000.0;

double _ago(double days) => _nowSec - days * 86400;

PlaySignal _play(
  String filename,
  double daysAgo, {
  double ratio = 0.95,
  double secs = 180,
  String? session,
  PlaySource? source = PlaySource.linear,
  double? atSec,
}) =>
    PlaySignal(
      filename: filename,
      timestamp: atSec ?? _ago(daysAgo),
      ratio: ratio,
      secondsPlayed: secs,
      sessionId: session,
      source: source,
    );

TasteSnapshot _build(
  List<PlaySignal> events, {
  Map<String, SongMeta> meta = const {},
  Set<String> favorites = const {},
}) =>
    buildTasteSnapshot(TasteInputs(
      events: events,
      meta: meta,
      favorites: favorites,
      now: _now,
    ));

List<PlaySignal> _completions(String f, List<double> daysAgo) =>
    [for (final d in daysAgo) _play(f, d)];

void _expectFinite(SongTaste t) {
  for (final v in [
    t.trendMass,
    t.longMass,
    t.saturation,
    t.skipRate,
  ]) {
    expect(v.isFinite, isTrue);
  }
}

void main() {
  final base = _completions('x', [10, 11, 12, 13]);

  test('a burst of quick skips barely lowers a song', () {
    final burst = [
      for (var i = 0; i < 5; i++)
        _play('x', 2,
            ratio: 0.01,
            secs: 1,
            session: 's',
            source: PlaySource.shuffle,
            atSec: _ago(2) + i * 10),
    ];
    final without = _build(base).songs['x']!.longMass;
    final withBurst = _build([...base, ...burst]).songs['x']!.longMass;
    expect((without - withBurst) / without, lessThan(0.05));
  });

  test('a manual skip lowers a song less than a shuffle-served skip', () {
    final manual = _build([
      ...base,
      _play('x', 1, ratio: 0.05, secs: 10, source: PlaySource.manual),
    ]).songs['x']!.longMass;
    final shuffled = _build([
      ...base,
      _play('x', 1, ratio: 0.05, secs: 10, source: PlaySource.shuffle),
    ]).songs['x']!.longMass;
    expect(manual, greaterThan(shuffled));
  });

  test('skips followed by a later full listen are forgiven', () {
    final skipped = _build([
      ...base,
      _play('x', 5, ratio: 0.05, secs: 10, source: PlaySource.shuffle),
      _play('x', 4, ratio: 0.05, secs: 10, source: PlaySource.shuffle),
      _play('x', 1),
    ]).songs['x']!;
    final unforgiven = _build([
      ...base,
      _play('x', 5, ratio: 0.05, secs: 10, source: PlaySource.shuffle),
      _play('x', 4, ratio: 0.05, secs: 10, source: PlaySource.shuffle),
    ]).songs['x']!;
    expect(skipped.longMass, greaterThan(unforgiven.longMass));
  });

  test('skips 60 days old barely affect a song', () {
    final old = [
      for (var i = 0; i < 5; i++)
        _play('x', 60, ratio: 0.01, secs: 10, source: PlaySource.shuffle),
    ];
    final without = _build(base).songs['x']!.longMass;
    final withOld = _build([...base, ...old]).songs['x']!.longMass;
    expect((without - withOld).abs(), lessThan(0.05));
  });

  test('recent plays lift trend above plays from 200 days ago', () {
    final recent = [for (var i = 0; i < 10; i++) _play('r', 20)];
    final old = [for (var i = 0; i < 10; i++) _play('o', 200)];
    final snap = _build([...recent, ...old]);
    expect(snap.songs['r']!.trendMass, greaterThan(snap.songs['o']!.trendMass));
    expect(snap.songs['o']!.trendMass, 0);
    expect(snap.songs['o']!.longMass, greaterThan(0));
  });

  test('an artist played only 200 days ago has no trend mass', () {
    final events = [
      for (var i = 0; i < 10; i++) _play('old', 200),
      for (var i = 0; i < 10; i++) _play('new', 5),
    ];
    final meta = {
      'old': const SongMeta(artist: 'Past'),
      'new': const SongMeta(artist: 'Now'),
    };
    final snap = _build(events, meta: meta);
    expect(snap.artists['past']!.trendMass, 0);
    expect(snap.artists['past']!.longMass, greaterThan(0));
    expect(snap.artists['now']!.trendMass, greaterThan(0));
  });

  test('unplayed songs have no entry and artist evidence stays on the artist',
      () {
    final events = [for (var i = 0; i < 10; i++) _play('h1', 2)];
    final meta = {
      'h1': const SongMeta(artist: 'Hot'),
      'u': const SongMeta(artist: 'Hot'),
    };
    final snap = _build(events, meta: meta);
    expect(snap.songs.containsKey('u'), isFalse);
    expect(snap.artists['hot']!.trendMass, greaterThan(0));
    expect(snap.artists.containsKey('unknown'), isFalse);
  });

  test('untagged songs do not share an artist bucket', () {
    final events = [
      for (var i = 0; i < 5; i++) _play('n1', 3),
      for (var i = 0; i < 5; i++) _play('n2', 3),
    ];
    final meta = {
      'n1': const SongMeta(artist: '', album: 'A'),
      'n2': const SongMeta(artist: '', album: 'B'),
    };
    final snap = _build(events, meta: meta);
    expect(snap.artists.containsKey(''), isFalse);
    expect(snap.artists.length, 2);
    expect(snap.artists['\u0000n1']!.longMass, greaterThan(0));
  });

  test('artist keys are case and whitespace insensitive', () {
    expect(
        tasteArtistKey(' Daft Punk ', 'a'), tasteArtistKey('daft punk', 'b'));
    expect(tasteArtistKey('', 'a'), isNot(tasteArtistKey('', 'b')));
  });

  test('artist co-play links different artists only, within the trend window',
      () {
    final meta = {
      'a1': const SongMeta(artist: 'X'),
      'a2': const SongMeta(artist: 'X'),
      'b1': const SongMeta(artist: 'Y'),
      'old1': const SongMeta(artist: 'P'),
      'old2': const SongMeta(artist: 'Q'),
    };
    final events = [
      _play('a1', 1, session: 's1', atSec: _ago(1)),
      _play('a2', 1, session: 's1', atSec: _ago(1) + 60),
      _play('b1', 1, session: 's1', atSec: _ago(1) + 120),
      _play('old1', 100, session: 's2', atSec: _ago(100)),
      _play('old2', 100, session: 's2', atSec: _ago(100) + 60),
    ];
    final snap = _build(events, meta: meta);
    expect(snap.artistCoPlay['x']!['y'], 1.0);
    expect(snap.artistCoPlay['x']!.containsKey('x'), isFalse);
    expect(snap.artistCoPlay.containsKey('p'), isFalse);
  });

  test('empty, single, NaN and future inputs stay finite', () {
    expect(_build([]).songs, isEmpty);
    expect(_build([]).artists, isEmpty);

    final degenerate = _build(
      [
        PlaySignal(
          filename: 's',
          timestamp: _nowSec + 86400 * 5,
          ratio: double.nan,
          secondsPlayed: double.nan,
        ),
      ],
      meta: {
        's': const SongMeta(artist: 'A', album: 'B', moods: ['calm'])
      },
    );
    _expectFinite(degenerate.songs['s']!);
    expect(degenerate.artists['a']!.longMass.isFinite, isTrue);
  });

  test('100k events over 10k songs build quickly', () {
    final rng = Random(7);
    final events = <PlaySignal>[
      for (var i = 0; i < 100000; i++)
        PlaySignal(
          filename: 's${rng.nextInt(10000)}',
          timestamp: _ago(rng.nextDouble() * 365),
          ratio: rng.nextDouble(),
          secondsPlayed: rng.nextDouble() * 200,
          sessionId: 'sess${i ~/ 20}',
          source: PlaySource.values[rng.nextInt(PlaySource.values.length)],
        ),
    ];
    final meta = {
      for (var i = 0; i < 10000; i++)
        's$i': SongMeta(
          artist: 'a${i % 500}',
          album: 'al${i % 900}',
          moods: ['m${i % 7}'],
        ),
    };
    final sw = Stopwatch()..start();
    final snap = _build(events, meta: meta);
    sw.stop();
    expect(snap.songs.length, greaterThan(9900));
    expect(snap.artists.length, lessThanOrEqualTo(500));
    expect(sw.elapsedMilliseconds, lessThan(3000));
  });
}
