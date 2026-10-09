// ignore_for_file: avoid_print
// Smart shuffle scenario: the report that motivated v2. One artist (A) is the
// whole last 30 days; the slider sits at maximum familiarity. Shuffle and
// recommendations must follow that taste instead of spreading over the library.
//
// Phase 3 note: "first 50" is capped by artist A's own size (40 songs), so A
// can fill at most 40 of 50 slots. Where a plan threshold exceeds that cap it is
// asserted against min(50, |A|) instead, so it stays a real bound.

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/services/shuffle_selector.dart';
import 'package:wispie/domain/services/smart_weights.dart';
import 'package:wispie/domain/services/taste_model.dart';

const _nowSec = 1000000000.0;
const _day = 86400.0;

class _Song {
  final String filename;
  final String artist;
  final String album;
  const _Song(this.filename, this.artist, this.album);
}

class _Library {
  final List<_Song> songs;
  final Map<String, SongMeta> meta;
  final List<PlaySignal> events;
  final Set<String> favorites;
  final Set<String> suggestLess;
  _Library(this.songs, this.events, this.favorites, this.suggestLess)
      : meta = {
          for (final s in songs)
            s.filename: SongMeta(artist: s.artist, album: s.album),
        };
}

/// 3,000 songs across 300 artists. A has 40 songs; B, C, D have 30 each.
_Library _buildLibrary(Random rng, {bool withEvents = true}) {
  final songs = <_Song>[];
  const artists = 300;
  for (var a = 0; a < artists; a++) {
    final name = a == 0
        ? 'A'
        : a == 1
            ? 'B'
            : a == 2
                ? 'C'
                : a == 3
                    ? 'D'
                    : 'art$a';
    final count = a == 0 ? 40 : (a <= 3 ? 30 : 0);
    for (var i = 0; i < count; i++) {
      songs.add(_Song('$name-$i.mp3', name, '$name-album'));
    }
  }
  // Fill the rest of the 3,000 songs across the long tail.
  var k = 0;
  while (songs.length < 3000) {
    final a = 4 + (k % 296);
    songs.add(_Song('art$a-t$k.mp3', 'art$a', 'art$a-album'));
    k++;
  }

  final events = <PlaySignal>[];
  if (withEvents) {
    PlaySignal play(String f, double ageDays, {bool skip = false}) =>
        PlaySignal(
          filename: f,
          timestamp: _nowSec - ageDays * _day,
          ratio: skip ? 0.1 : 0.95,
          secondsPlayed: skip ? 5 : 200,
          sessionId: 's${ageDays.floor()}',
        );
    final aSongs = [
      for (final s in songs)
        if (s.artist == 'A') s.filename
    ];
    for (var i = 0; i < 400; i++) {
      events.add(play(aSongs[rng.nextInt(aSongs.length)], rng.nextDouble() * 30,
          skip: rng.nextInt(10) == 0));
    }
    final others = ['B', 'C', 'D'];
    for (var i = 0; i < 300; i++) {
      final artist = others[rng.nextInt(3)];
      final pool = [
        for (final s in songs)
          if (s.artist == artist) s.filename
      ];
      events.add(
          play(pool[rng.nextInt(pool.length)], 31 + rng.nextDouble() * 59));
    }
  }

  final favorites = {
    for (var i = 0; i < 6; i++) songs[500 + i * 300].filename,
  };
  final suggestLess = {
    for (var i = 0; i < 5; i++) songs[1500 + i * 200].filename,
  };
  return _Library(songs, events, favorites, suggestLess);
}

TasteSnapshot _taste(_Library lib) => buildTasteSnapshot(TasteInputs(
      events: lib.events,
      meta: lib.meta,
      now: DateTime.fromMillisecondsSinceEpoch((_nowSec * 1000).round()),
      favorites: lib.favorites,
      suggestLess: lib.suggestLess,
    ));

List<SmartCandidate<_Song>> _pool(_Library lib) => [
      for (final s in lib.songs)
        SmartCandidate<_Song>(
          item: s,
          filenames: [s.filename],
          artistKey: tasteArtistKey(s.artist, s.filename),
          albumKey: s.album.toLowerCase(),
          isFavorite: lib.favorites.contains(s.filename),
          isSuggestLess: lib.suggestLess.contains(s.filename),
        ),
    ];

List<_Song> _order(_Library lib, TasteSnapshot taste, Random rng,
        {required double familiarity,
        ShuffleContext context = ShuffleContext.library}) =>
    orderSmartQueue<_Song>(
      pool: _pool(lib),
      taste: taste,
      familiarity: familiarity,
      context: context,
      streakBreakerEnabled: true,
      suggestLessMultiplier: 0.2,
      random: rng,
    );

int _countArtist(Iterable<_Song> songs, String artist) =>
    songs.where((s) => s.artist == artist).length;

void main() {
  late _Library lib;
  late TasteSnapshot taste;

  setUpAll(() {
    lib = _buildLibrary(Random(7));
    taste = _taste(lib);
  });

  test('max familiarity: A dominates the first 50 queue slots', () {
    var total = 0;
    const seeds = 200;
    for (var seed = 0; seed < seeds; seed++) {
      final q = _order(lib, taste, Random(seed), familiarity: 1.0).take(50);
      total += _countArtist(q, 'A');
    }
    final mean = total / seeds;
    print('f=1 mean A in first 50: $mean (cap 40)');
    expect(mean, greaterThanOrEqualTo(0.92 * 40));
  });

  test('max familiarity: opening seed is A', () {
    var hits = 0;
    const seeds = 200;
    for (var seed = 0; seed < seeds; seed++) {
      final seedSong = selectSmartSeed<_Song>(
        pool: _pool(lib),
        taste: taste,
        familiarity: 1.0,
        context: ShuffleContext.library,
        random: Random(seed),
      );
      if (seedSong?.artist == 'A') hits++;
    }
    print('f=1 seed is A: ${hits / seeds}');
    expect(hits / seeds, greaterThanOrEqualTo(0.92));
  });

  test('default discovery (f=0.65): A still leads, others are a minority', () {
    var aTotal = 0;
    var otherTotal = 0;
    const seeds = 200;
    for (var seed = 0; seed < seeds; seed++) {
      final q = _order(lib, taste, Random(seed), familiarity: 0.65).take(50);
      aTotal += _countArtist(q, 'A');
      otherTotal +=
          _countArtist(q, 'B') + _countArtist(q, 'C') + _countArtist(q, 'D');
    }
    final aMean = aTotal / seeds;
    final bcd = otherTotal / seeds / 50;
    print('f=0.65 mean A in first 50: $aMean, B+C+D share: $bcd');
    expect(aMean, greaterThanOrEqualTo(0.75 * 40));
    expect(bcd, inInclusiveRange(0.08, 0.25));
  });

  test('max discovery (f=0): A share 0.45..0.75, discovery share >= 0.08', () {
    var aTotal = 0;
    var dTotal = 0;
    const seeds = 200;
    for (var seed = 0; seed < seeds; seed++) {
      final q =
          _order(lib, taste, Random(seed), familiarity: 0.0).take(50).toList();
      aTotal += _countArtist(q, 'A');
      dTotal += _countArtist(q, 'D');
    }
    final aShare = aTotal / seeds / 50;
    final dShare = dTotal / seeds / 50;
    print('f=0 A share: $aShare, D share: $dShare');
    expect(aShare, inInclusiveRange(0.45, 0.75));
    expect(dShare, greaterThanOrEqualTo(0.08));
  });

  test('recommendations at f=1: top 30 has >= 25 of A', () {
    final weights = computeSmartWeights<_Song>(
      pool: _pool(lib),
      taste: taste,
      familiarity: 1.0,
      context: ShuffleContext.sort,
    );
    final top = diversifiedTop<_Song>(_pool(lib), weights, count: 30);
    final aCount = _countArtist(top, 'A');
    print('f=1 top 30 A count: $aCount');
    expect(aCount, greaterThanOrEqualTo(25));
  });

  test('suggest-less songs stay out of the first 50 (at most 1)', () {
    const seeds = 200;
    var worst = 0;
    for (var seed = 0; seed < seeds; seed++) {
      final q = _order(lib, taste, Random(seed), familiarity: 0.65).take(50);
      final n = q.where((s) => lib.suggestLess.contains(s.filename)).length;
      worst = max(worst, n);
    }
    expect(worst, lessThanOrEqualTo(1));
  });

  test('a song never appears twice in the first 50', () {
    final q =
        _order(lib, taste, Random(3), familiarity: 0.65).take(50).toList();
    expect(q.map((s) => s.filename).toSet().length, q.length);
  });

  test('no events: at least 30 distinct artists in the first 50', () {
    final built = _buildLibrary(Random(7), withEvents: false);
    final empty = _Library(built.songs, const [], const {}, const {});
    final emptyTaste = _taste(empty);
    var worst = 1 << 30;
    for (var seed = 0; seed < 200; seed++) {
      final q =
          _order(empty, emptyTaste, Random(seed), familiarity: 0.65).take(50);
      worst = min(worst, q.map((s) => s.artist).toSet().length);
    }
    expect(worst, greaterThanOrEqualTo(30));
  });

  test('trend wins: E (last 14 days) dominates over A (days 31-90)', () {
    final events = <PlaySignal>[
      for (var i = 0; i < 200; i++)
        PlaySignal(
          filename: 'A-${i % 40}.mp3',
          timestamp: _nowSec - (31 + (i % 59)) * _day,
          ratio: 0.95,
          secondsPlayed: 200,
          sessionId: 'old$i',
        ),
      for (var i = 0; i < 200; i++)
        PlaySignal(
          filename: 'E-${i % 20}.mp3',
          timestamp: _nowSec - (i % 14) * _day,
          ratio: 0.95,
          secondsPlayed: 200,
          sessionId: 'new$i',
        ),
    ];
    final songs = [
      for (var i = 0; i < 40; i++) _Song('A-$i.mp3', 'A', 'a'),
      for (var i = 0; i < 20; i++) _Song('E-$i.mp3', 'E', 'e'),
      for (var i = 0; i < 300; i++) _Song('x$i.mp3', 'X$i', 'x$i'),
    ];
    final e = _Library(songs, events, const {}, const {});
    final t = _taste(e);
    var eTotal = 0;
    var aTotal = 0;
    for (var seed = 0; seed < 100; seed++) {
      final q = _order(e, t, Random(seed), familiarity: 0.65).take(50);
      eTotal += _countArtist(q, 'E');
      aTotal += _countArtist(q, 'A');
    }
    print('trend scenario E: ${eTotal / 100}, A: ${aTotal / 100}');
    expect(eTotal, greaterThan(aTotal));
  });

  test('performance: 20k songs, 2k artists, 150k events', () {
    final rng = Random(11);
    final songs = [
      for (var i = 0; i < 20000; i++)
        _Song('s$i.mp3', 'artist${i % 2000}', 'album${i % 4000}'),
    ];
    final events = [
      for (var i = 0; i < 150000; i++)
        PlaySignal(
          filename: 's${rng.nextInt(20000)}.mp3',
          timestamp: _nowSec - rng.nextDouble() * 90 * _day,
          ratio: 0.9,
          secondsPlayed: 180,
          sessionId: 'p${i ~/ 5}',
        ),
    ];
    final big = _Library(songs, events, const {}, const {});

    final sw = Stopwatch()..start();
    final t = _taste(big);
    final snapshotMs = sw.elapsedMilliseconds;

    sw.reset();
    _order(big, t, Random(1), familiarity: 0.65);
    final orderMs = sw.elapsedMilliseconds;

    print('perf: snapshot ${snapshotMs}ms, weights+order ${orderMs}ms');
    expect(snapshotMs, lessThan(10000));
    expect(orderMs, lessThan(5000));
  });
}
