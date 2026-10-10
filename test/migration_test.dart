import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wispie/data/migrations.dart';

String _expectedUid(String sid, String sf, int ordinal) => sha256
    .convert(utf8.encode('$sid|$sf|$ordinal'))
    .toString()
    .substring(0, 32);

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('fresh v2 create contains all tables', () async {
    final dir = await Directory.systemTemp.createTemp('migrate_fresh_');
    final path = '${dir.path}/wispie_data.db';
    final db = await openDatabase(path,
        version: kUserDataDbVersion,
        onCreate: (db, v) async => createUserDataSchema(db));
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' ORDER BY name");
    final names = tables.map((r) => r['name'] as String).toSet();
    expect(names.contains('favorite'), isTrue);
    expect(names.contains('queue_snapshot'), isTrue);
    expect(names.contains('translated_lyrics'), isTrue);
    expect(names.contains('artist_art'), isTrue);
    final cols = await db.rawQuery('PRAGMA table_info(translated_lyrics)');
    expect(cols.any((c) => c['name'] == 'source_hash'), isTrue);
    await db.close();
    await dir.delete(recursive: true);
  });

  test('upgrade v1->v2 adds new tables and source_hash', () async {
    final dir = await Directory.systemTemp.createTemp('migrate_up_');
    final path = '${dir.path}/wispie_data.db';
    final dbV1 = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE favorite (filename TEXT PRIMARY KEY, added_at REAL)');
      await db.execute(
          'CREATE TABLE song (filename TEXT PRIMARY KEY, title TEXT, artist TEXT, album TEXT, url TEXT, cover_url TEXT, has_lyrics INTEGER, play_count INTEGER, duration_ms INTEGER, mtime REAL, created_epoch_sec REAL, song_date_epoch_sec REAL)');
      await db.execute(
          'CREATE TABLE translated_lyrics (filename TEXT, target_lang TEXT, translated_content TEXT, updated_at REAL, PRIMARY KEY (filename, target_lang))');
    });
    await dbV1.insert('favorite', {'filename': 'a.mp3', 'added_at': 1.0});
    await dbV1.close();

    final dbV2 = await openDatabase(path,
        version: kUserDataDbVersion,
        onCreate: (db, v) async => createUserDataSchema(db),
        onUpgrade: (db, oldV, newV) async {
          if (oldV < 2) await upgradeUserDataFrom1To2(db);
        });
    final fav = await dbV2.query('favorite');
    expect(fav.length, 1);
    final tables = await dbV2.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='queue_snapshot'");
    expect(tables.isNotEmpty, isTrue);
    final cols = await dbV2.rawQuery('PRAGMA table_info(translated_lyrics)');
    expect(cols.any((c) => c['name'] == 'source_hash'), isTrue);
    await dbV2.close();
    await dir.delete(recursive: true);
  });
  test('fresh stats create has playevent.source', () async {
    final dir = await Directory.systemTemp.createTemp('migrate_stats_');
    final db = await openDatabase('${dir.path}/wispie_stats.db',
        version: kStatsDbVersion,
        onCreate: (db, v) async => createStatsSchema(db));
    final cols = await db.rawQuery('PRAGMA table_info(playevent)');
    expect(cols.any((c) => c['name'] == 'source'), isTrue);
    final idx = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_playevent_ts'");
    expect(idx.length, 1);
    await db.close();
    await dir.delete(recursive: true);
  });

  test('stats upgrade v1->v2 adds source, keeps rows, is idempotent', () async {
    final dir = await Directory.systemTemp.createTemp('migrate_stats_up_');
    final path = '${dir.path}/wispie_stats.db';
    final v1 = await openDatabase(path, version: 1, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE playevent (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT, song_filename TEXT, timestamp REAL, duration_played REAL, total_length REAL, play_ratio REAL, foreground_duration REAL, background_duration REAL)');
    });
    await v1.insert('playevent', {'song_filename': 'a.mp3', 'timestamp': 1.0});
    await v1.close();

    final v2 = await openDatabase(path, version: kStatsDbVersion,
        onUpgrade: (db, oldV, newV) async {
      if (oldV < 2) await upgradeStatsFrom1To2(db);
    });
    await upgradeStatsFrom1To2(v2);
    final rows = await v2.query('playevent');
    expect(rows.length, 1);
    expect(rows.first['source'], isNull);
    final cols = await v2.rawQuery('PRAGMA table_info(playevent)');
    expect(cols.any((c) => c['name'] == 'source'), isTrue);
    final idx = await v2.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_playevent_ts'");
    expect(idx.length, 1);
    await v2.close();
    await dir.delete(recursive: true);
  });

  test('upgrade v3->v4 indexes the filename column of membership tables',
      () async {
    final dir = await Directory.systemTemp.createTemp('migrate_v4_');
    final path = '${dir.path}/wispie_data.db';

    // A real v3 database: current schema, minus the indexes v4 adds. Creating
    // it with the current create function would already include them and prove
    // nothing about the migration.
    final dbV3 = await openDatabase(path,
        version: 3, onCreate: (db, v) async => createUserDataSchema(db));
    await dbV3.execute('DROP INDEX IF EXISTS idx_playlist_song_song_filename');
    await dbV3
        .execute('DROP INDEX IF EXISTS idx_queue_snapshot_song_song_filename');
    await dbV3.close();

    // Confirm the starting point really lacks them.
    final before = await openDatabase(path,
        version: 3,
        onCreate: (db, v) async => createUserDataSchema(db),
        onUpgrade: (db, oldV, newV) async {});
    final beforeIndexes = await before
        .rawQuery("SELECT name FROM sqlite_master WHERE type='index'");
    expect(beforeIndexes.map((r) => r['name']),
        isNot(contains('idx_playlist_song_song_filename')));
    await before.close();

    final dbV4 = await openDatabase(path,
        version: kUserDataDbVersion,
        onCreate: (db, v) async => createUserDataSchema(db),
        onUpgrade: (db, oldV, newV) async {
          if (oldV < 4) await upgradeUserDataFrom3To4(db);
        });

    final indexes = (await dbV4
            .rawQuery("SELECT name FROM sqlite_master WHERE type='index'"))
        .map((r) => r['name'])
        .toSet();
    expect(indexes, contains('idx_playlist_song_song_filename'));
    expect(indexes, contains('idx_queue_snapshot_song_song_filename'));
    await dbV4.close();
    await dir.delete(recursive: true);
  });

  test('fresh stats v3 adds uid, hlc, dirty and sync_tombstone', () async {
    final dir = await Directory.systemTemp.createTemp('migrate_stats_v3_');
    final db = await openDatabase('${dir.path}/wispie_stats.db',
        version: kStatsDbVersion,
        onCreate: (db, v) async => createStatsSchema(db));
    final peCols = await db.rawQuery('PRAGMA table_info(playevent)');
    final peNames = peCols.map((c) => c['name']).toSet();
    expect(peNames, containsAll(['uid', 'hlc', 'dirty']));
    final psCols = await db.rawQuery('PRAGMA table_info(playsession)');
    final psNames = psCols.map((c) => c['name']).toSet();
    expect(psNames, containsAll(['hlc', 'dirty']));
    final tables = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='table' AND name='sync_tombstone'");
    expect(tables, isNotEmpty);
    final idx = await db.rawQuery(
        "SELECT name FROM sqlite_master WHERE type='index' AND name='idx_playevent_uid'");
    expect(idx.length, 1);
    await db.close();
    await dir.delete(recursive: true);
  });

  test('stats v2->v3 adds sync columns and backfills uids deterministically',
      () async {
    final dir = await Directory.systemTemp.createTemp('migrate_stats_v3up_');
    final path = '${dir.path}/wispie_stats.db';
    final v2 = await openDatabase(path, version: 2, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE playsession (id TEXT PRIMARY KEY, start_time REAL, end_time REAL, platform TEXT, device_id TEXT)');
      await db.execute(
          'CREATE TABLE playevent (id INTEGER PRIMARY KEY AUTOINCREMENT, session_id TEXT, song_filename TEXT, timestamp REAL, duration_played REAL, total_length REAL, play_ratio REAL, foreground_duration REAL, background_duration REAL, source TEXT)');
    });
    // Two events share (session, song); ordinal distinguishes them.
    await v2.insert('playevent',
        {'session_id': 's1', 'song_filename': 'a.mp3', 'timestamp': 1.0});
    await v2.insert('playevent',
        {'session_id': 's1', 'song_filename': 'a.mp3', 'timestamp': 2.0});
    await v2.insert('playevent',
        {'session_id': 's2', 'song_filename': 'b.mp3', 'timestamp': 3.0});
    await v2.close();

    final v3 = await openDatabase(path, version: kStatsDbVersion,
        onUpgrade: (db, oldV, newV) async {
      if (oldV < 3) await upgradeStatsFrom2To3(db);
    });
    final rows = await v3.query('playevent', orderBy: 'timestamp ASC, id ASC');
    expect(rows.length, 3);
    expect(rows[0]['uid'], _expectedUid('s1', 'a.mp3', 0));
    expect(rows[1]['uid'], _expectedUid('s1', 'a.mp3', 1));
    expect(rows[2]['uid'], _expectedUid('s2', 'b.mp3', 0));
    expect(rows.map((r) => r['uid']).toSet().length, 3);
    // Idempotent: running backfill again changes nothing.
    await backfillPlayEventUids(v3);
    final rows2 = await v3.query('playevent', orderBy: 'timestamp ASC, id ASC');
    expect(rows2[0]['uid'], _expectedUid('s1', 'a.mp3', 0));
    await v3.close();
    await dir.delete(recursive: true);
  });

  test('fresh userdata v5 adds sync columns and tables', () async {
    final dir = await Directory.systemTemp.createTemp('migrate_v5_');
    final db = await openDatabase('${dir.path}/wispie_data.db',
        version: kUserDataDbVersion,
        onCreate: (db, v) async => createUserDataSchema(db));
    for (final table in const [
      'favorite',
      'playlist',
      'playlist_song',
      'merged_song',
      'artist_art',
      'album_art'
    ]) {
      final cols = await db.rawQuery('PRAGMA table_info($table)');
      final names = cols.map((c) => c['name']).toSet();
      expect(names, containsAll(['hlc', 'dirty']), reason: table);
    }
    final tables =
        (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
            .map((r) => r['name'])
            .toSet();
    expect(tables, containsAll(['sync_tombstone', 'sync_setting_meta']));
    await db.close();
    await dir.delete(recursive: true);
  });

  test('userdata v4->v5 adds sync columns, keeps rows dirty, adds tables',
      () async {
    final dir = await Directory.systemTemp.createTemp('migrate_v5up_');
    final path = '${dir.path}/wispie_data.db';
    final v4 = await openDatabase(path, version: 4, onCreate: (db, v) async {
      await db.execute(
          'CREATE TABLE favorite (filename TEXT PRIMARY KEY, added_at REAL)');
      await db.execute(
          'CREATE TABLE suggestless (filename TEXT PRIMARY KEY, added_at REAL)');
      await db.execute(
          'CREATE TABLE hidden (filename TEXT PRIMARY KEY, hidden_at REAL)');
      await db.execute(
          'CREATE TABLE playlist (id TEXT PRIMARY KEY, name TEXT, description TEXT, is_recommendation INTEGER, created_at REAL, updated_at REAL)');
      await db.execute(
          'CREATE TABLE playlist_song (id INTEGER PRIMARY KEY AUTOINCREMENT, playlist_id TEXT, song_filename TEXT, added_at REAL)');
      await db.execute(
          'CREATE TABLE merged_song_group (id TEXT PRIMARY KEY, priority_filename TEXT, created_at REAL)');
      await db.execute(
          'CREATE TABLE merged_song (filename TEXT PRIMARY KEY, group_id TEXT, added_at REAL)');
      await db.execute(
          'CREATE TABLE artist_art (artist_name TEXT PRIMARY KEY, image_url TEXT, local_path TEXT, source TEXT, updated_at REAL)');
      await db.execute(
          'CREATE TABLE album_art (album_key TEXT PRIMARY KEY, album_name TEXT, artist_name TEXT, image_url TEXT, local_path TEXT, source TEXT, updated_at REAL)');
    });
    await v4.insert('favorite', {'filename': 'a.mp3', 'added_at': 1.0});
    await v4.close();

    final v5 = await openDatabase(path, version: kUserDataDbVersion,
        onUpgrade: (db, oldV, newV) async {
      if (oldV < 5) await upgradeUserDataFrom4To5(db);
    });
    final cols = await v5.rawQuery('PRAGMA table_info(favorite)');
    expect(cols.map((c) => c['name']).toSet(), containsAll(['hlc', 'dirty']));
    final fav = await v5.query('favorite');
    expect(fav.length, 1);
    expect(fav.first['dirty'], 1);
    final tables =
        (await v5.rawQuery("SELECT name FROM sqlite_master WHERE type='table'"))
            .map((r) => r['name'])
            .toSet();
    expect(tables, containsAll(['sync_tombstone', 'sync_setting_meta']));
    await v5.close();
    await dir.delete(recursive: true);
  });

  test('a fresh install gets the membership indexes too', () async {
    final dir = await Directory.systemTemp.createTemp('migrate_fresh4_');
    final path = '${dir.path}/wispie_data.db';
    final db = await openDatabase(path,
        version: kUserDataDbVersion,
        onCreate: (db, v) async => createUserDataSchema(db));

    final indexes =
        (await db.rawQuery("SELECT name FROM sqlite_master WHERE type='index'"))
            .map((r) => r['name'])
            .toSet();
    expect(indexes, contains('idx_playlist_song_song_filename'));
    expect(indexes, contains('idx_queue_snapshot_song_song_filename'));
    await db.close();
    await dir.delete(recursive: true);
  });
}
