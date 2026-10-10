import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wispie/data/migrations.dart';
import 'package:wispie/services/sync/changeset.dart';
import 'package:wispie/services/sync/hlc.dart';

class _MemSettings implements SettingsAccess {
  final Map<String, Object?> values = {};
  @override
  Future<Object?> read(String key) async => values[key];
  @override
  Future<void> write(String key, Object value) async => values[key] = value;
}

class _Dev {
  final Database stats;
  final Database user;
  final _MemSettings settings;
  final Changeset cs;
  _Dev(this.stats, this.user, this.settings, this.cs);
}

Future<_Dev> _open(String id, {int Function()? nowMs}) async {
  final stats = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false));
  final user = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath,
      options: OpenDatabaseOptions(singleInstance: false));
  await createStatsSchema(stats);
  await createUserDataSchema(user);
  final s = _MemSettings();
  return _Dev(
      stats,
      user,
      s,
      Changeset(
          stats: stats,
          userData: user,
          deviceId: id,
          settings: s,
          nowMs: nowMs));
}

Map<String, dynamic> _payload(String dev, Map<String, List<Map>> records) => {
      'v': 1,
      'kind': 'delta',
      'device_id': dev,
      'max_hlc': 0,
      'records': records,
    };

Future<Map<String, Object?>> _dump(_Dev d) async {
  final out = <String, Object?>{};
  Future<void> grab(Database db, String t, String order) async {
    final rows = await db.query(t, orderBy: order);
    out[t] = rows
        .map((r) => (Map<String, Object?>.from(r)
          ..remove('dirty')
          ..remove('id')))
        .toList();
  }

  await grab(d.stats, 'playsession', 'id');
  await grab(d.stats, 'playevent', 'uid');
  await grab(d.stats, 'sync_tombstone', 'entity, key');
  await grab(d.user, 'favorite', 'filename');
  await grab(d.user, 'playlist', 'id');
  await grab(d.user, 'playlist_song', 'playlist_id, song_filename');
  await grab(d.user, 'merged_song', 'filename');
  await grab(d.user, 'sync_tombstone', 'entity, key');
  await grab(d.user, 'sync_setting_meta', 'key');
  out['settings'] = Map.of(d.settings.values);
  return out;
}

Map<String, dynamic> _ev(String uid, double dur, double total, double ts,
        {int hlc = 5, String? source}) =>
    {
      'uid': uid,
      'session_id': 's1',
      'song_filename': 'a.mp3',
      'timestamp': ts,
      'duration_played': dur,
      'total_length': total,
      'play_ratio': 0.0,
      'foreground_duration': dur,
      'background_duration': 0.0,
      'source': source,
      'hlc': hlc,
    };

void main() {
  sqfliteFfiInit();
  setUpAll(() => SharedPreferences.setMockInitialValues({}));
  setUp(() => Hlc.instance.resetForTest(1 << 40));

  final payloads = <Map<String, dynamic>>[
    _payload('A', {
      'play_sessions': [
        {
          'id': 's1',
          'start_time': 100.0,
          'end_time': 200.0,
          'platform': 'android',
          'device_id': 'A',
          'hlc': 3
        }
      ],
      'play_events': [
        _ev('e1', 100, 180, 150, hlc: 4),
        _ev('e2', 30, 200, 160)
      ],
      'favorites': [
        {'filename': 'a.mp3', 'added_at': 1.0, 'hlc': 10},
        {'filename': 'b.mp3', 'added_at': 1.0, 'hlc': 10},
      ],
      'playlists': [
        {
          'id': 'p1',
          'name': 'One',
          'description': '',
          'is_recommendation': 0,
          'created_at': 1.0,
          'updated_at': 1.0,
          'hlc': 10
        }
      ],
      'playlist_songs': [
        {
          'playlist_id': 'p1',
          'song_filename': 'a.mp3',
          'added_at': 1.0,
          'hlc': 10
        }
      ],
      'settings': [
        {'key': 'theme_mode', 'value': 'dark', 'hlc': 10}
      ],
    }),
    _payload('B', {
      'play_sessions': [
        {
          'id': 's1',
          'start_time': 90.0,
          'end_time': 150.0,
          'platform': 'linux',
          'device_id': 'B',
          'hlc': 3
        }
      ],
      'play_events': [_ev('e1', 170, 180, 140, hlc: 6, source: 'x')],
      'favorites': [
        {'filename': 'a.mp3', 'added_at': 2.0, 'hlc': 20}
      ],
      'tombstones': [
        {'entity': 'favorites', 'key': 'b.mp3', 'hlc': 15},
        {'entity': 'playlist_songs', 'key': 'p1\u0000a.mp3', 'hlc': 12},
        {'entity': 'play_events', 'key': 'e2', 'hlc': 30},
      ],
      'settings': [
        {'key': 'theme_mode', 'value': 'light', 'hlc': 11}
      ],
    }),
    _payload('C', {
      'favorites': [
        {'filename': 'b.mp3', 'added_at': 3.0, 'hlc': 25},
        {'filename': 'c.mp3', 'added_at': 3.0, 'hlc': 5},
      ],
      'tombstones': [
        {'entity': 'favorites', 'key': 'c.mp3', 'hlc': 9},
        {'entity': 'playlists', 'key': 'p1', 'hlc': 8},
      ],
      'merged_groups': [
        {'id': 'g1', 'priority_filename': 'a.mp3', 'created_at': 1.0, 'hlc': 7}
      ],
      'merged_songs': [
        {'filename': 'a.mp3', 'group_id': 'g1', 'added_at': 1.0, 'hlc': 7}
      ],
    }),
  ];

  test('merge is order independent and idempotent', () async {
    final reference = await _open('R');
    for (final p in payloads) {
      await reference.cs.merge(p);
    }
    final expected = await _dump(reference);

    final rnd = Random(42);
    for (var i = 0; i < 25; i++) {
      final seq = <Map<String, dynamic>>[];
      for (final p in payloads) {
        seq.addAll(List.filled(1 + rnd.nextInt(3), p));
      }
      seq.shuffle(rnd);
      final d = await _open('R');
      for (final p in seq) {
        await d.cs.merge(p);
      }
      expect(await _dump(d), expected, reason: 'run $i');
    }

    // Spot checks on the converged state.
    final fav =
        (expected['favorite'] as List).map((r) => (r as Map)['filename']);
    expect(fav, containsAll(['a.mp3', 'b.mp3']));
    expect(fav, isNot(contains('c.mp3')));
    final ev = (expected['playevent'] as List).cast<Map>();
    expect(ev.map((e) => e['uid']), ['e1']);
    expect(ev.first['duration_played'], 170.0);
    expect(ev.first['timestamp'], 150.0);
    expect(ev.first['source'], 'x');
    expect((expected['settings'] as Map)['theme_mode'], 'light');
  });

  test('absence never deletes', () async {
    final d = await _open('A');
    await d.cs.merge(payloads[0]);
    await d.cs.merge(_payload('Z', {}));
    await d.cs.merge(_payload('Z', {'favorites': []}));
    expect(await d.user.query('favorite'), hasLength(2));
    expect(await d.user.query('sync_tombstone'), isEmpty);
  });

  test('tombstone vs re-add ordering', () async {
    final tomb = _payload('A', {
      'tombstones': [
        {'entity': 'favorites', 'key': 'x.mp3', 'hlc': 10}
      ]
    });
    Map<String, dynamic> fav(int hlc) => _payload('B', {
          'favorites': [
            {'filename': 'x.mp3', 'added_at': 1.0, 'hlc': hlc}
          ]
        });
    for (final order in [
      [fav(5), tomb],
      [tomb, fav(5)],
    ]) {
      final d = await _open('A');
      for (final p in order) {
        await d.cs.merge(p);
      }
      expect(await d.user.query('favorite'), isEmpty);
      expect(await d.user.query('sync_tombstone'), hasLength(1));
    }
    for (final order in [
      [fav(20), tomb],
      [tomb, fav(20)],
    ]) {
      final d = await _open('A');
      for (final p in order) {
        await d.cs.merge(p);
      }
      expect(await d.user.query('favorite'), hasLength(1));
      expect(await d.user.query('sync_tombstone'), isEmpty);
    }
  });

  test('play events: max semantics, no inflation on repeat, clamping',
      () async {
    final d = await _open('A');
    final p = _payload('B', {
      'play_sessions': [
        {
          'id': 's1',
          'start_time': 1.0,
          'end_time': 2.0,
          'platform': 'x',
          'device_id': 'B',
          'hlc': 1
        }
      ],
      'play_events': [
        _ev('u1', 180, 180, 1000),
        _ev('u2', 3600, 180, 1000),
      ],
    });
    for (var i = 0; i < 4; i++) {
      await d.cs.merge(p);
    }
    final rows = await d.stats.query('playevent', orderBy: 'uid');
    expect(rows[0]['duration_played'], 180.0);
    expect(rows[1]['duration_played'], 180.0);
    expect(rows[1]['play_ratio'], 1.0);
  });

  test('merged rows are clean; category off is skipped', () async {
    final d = await _open('A');
    await d.cs.merge(payloads[0], categories: {SyncCategory.favorites});
    expect(await d.user.query('favorite', where: 'dirty = 1'), isEmpty);
    expect(await d.user.query('favorite'), hasLength(2));
    expect(await d.user.query('playlist'), isEmpty);
    expect(await d.stats.query('playevent'), isEmpty);
    expect(d.settings.values, isEmpty);
    expect(await d.cs.buildDeltas(), isEmpty);
  });

  test('settings LWW', () async {
    final d = await _open('A');
    Map<String, dynamic> s(Object v, int h) => _payload('B', {
          'settings': [
            {'key': 'theme_mode', 'value': v, 'hlc': h},
            {'key': 'not_whitelisted', 'value': 1, 'hlc': h},
          ]
        });
    await d.cs.merge(s('dark', 10));
    await d.cs.merge(s('light', 5));
    expect(d.settings.values['theme_mode'], 'dark');
    await d.cs.merge(s('amoled', 11));
    expect(d.settings.values['theme_mode'], 'amoled');
    expect(d.settings.values.containsKey('not_whitelisted'), isFalse);
  });

  test('delta build, split, no echo and clear-if-unchanged', () async {
    final a = await _open('A');
    for (var i = 0; i < 50; i++) {
      await a.user.insert('favorite',
          {'filename': 'f$i.mp3', 'added_at': 1.0, 'hlc': 100 + i, 'dirty': 1});
    }
    await a.user.insert('sync_tombstone',
        {'entity': 'hidden', 'key': 'h.mp3', 'hlc': 200, 'dirty': 1});
    await a.user.insert(
        'sync_setting_meta', {'key': 'theme_mode', 'hlc': 300, 'dirty': 1});
    a.settings.values['theme_mode'] = 'dark';

    final batches = await a.cs.buildDeltas(maxBytes: 400);
    expect(batches.length, greaterThan(1));
    final total = batches.fold<int>(0, (n, b) => n + b.recordCount);
    expect(total, 52);

    // A write racing the upload must stay dirty.
    await a.user.update('favorite', {'hlc': 999},
        where: 'filename = ?', whereArgs: ['f0.mp3']);
    for (final b in batches) {
      await a.cs.markPushed(b);
    }
    final dirty = await a.user.query('favorite', where: 'dirty = 1');
    expect(dirty.map((r) => r['filename']), ['f0.mp3']);
    expect(await a.user.query('sync_tombstone', where: 'dirty = 1'), isEmpty);
    expect(
        await a.user.query('sync_setting_meta', where: 'dirty = 1'), isEmpty);

    // Round trip into another device converges without echo.
    final b = await _open('B');
    for (final batch in batches) {
      await b.cs.merge(batch.payload);
    }
    expect(await b.user.query('favorite'), hasLength(50));
    expect(await b.cs.buildDeltas(), isEmpty);
    expect(b.settings.values['theme_mode'], 'dark');
  });

  test('legacy null-hlc rows get stamped on build', () async {
    final a = await _open('A');
    await a.user.insert('favorite', {'filename': 'x.mp3', 'added_at': 1.0});
    final batches = await a.cs.buildDeltas();
    final rec = (batches.single.payload['records']['favorites'] as List).single;
    expect(rec['hlc'], greaterThan(0));
  });

  test('snapshot drops old tombstones; bulk import into wiped DB', () async {
    final now = DateTime(2025, 6, 1).millisecondsSinceEpoch;
    final a = await _open('A', nowMs: () => now);
    await a.user.insert('favorite',
        {'filename': 'x.mp3', 'added_at': 1.0, 'hlc': now << 16, 'dirty': 0});
    await a.user.insert('sync_tombstone', {
      'entity': 'hidden',
      'key': 'old',
      'hlc': (now - 200 * 86400000) << 16,
      'dirty': 0
    });
    await a.user.insert('sync_tombstone', {
      'entity': 'hidden',
      'key': 'new',
      'hlc': (now - 10 * 86400000) << 16,
      'dirty': 0
    });
    await a.stats.insert('playevent', {
      'uid': 'u1',
      'session_id': 's',
      'song_filename': 'x.mp3',
      'timestamp': 1.0,
      'duration_played': 10.0,
      'total_length': 100.0,
      'hlc': 5,
      'dirty': 0
    });
    final snap = await a.cs.buildSnapshot();
    expect(snap.payload['kind'], 'snapshot');
    final tombs = snap.payload['records']['tombstones'] as List;
    expect(tombs.map((t) => t['key']), ['new']);
    expect(snap.recordCount, 3);

    final b = await _open('B');
    await b.user.insert('favorite', {'filename': 'junk.mp3', 'added_at': 1.0});
    await b.cs.wipe();
    expect(await b.user.query('favorite'), isEmpty);
    var progress = 0;
    await b.cs.bulkImport(snap.payload, onProgress: (d, t) => progress = d);
    expect(progress, 3);
    expect(await b.user.query('favorite', where: 'dirty = 0'), hasLength(1));
    expect(await b.stats.query('playevent'), hasLength(1));
    expect(await b.cs.buildDeltas(), isEmpty);
  });

  test('wipe respects categories', () async {
    final d = await _open('A');
    await d.cs.merge(payloads[0]);
    await d.cs.wipe(categories: {SyncCategory.favorites});
    expect(await d.user.query('favorite'), isEmpty);
    expect(await d.user.query('playlist'), hasLength(1));
  });
}
