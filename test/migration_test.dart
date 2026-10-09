import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wispie/data/migrations.dart';

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
