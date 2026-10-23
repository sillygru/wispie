import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:sqflite/sqflite.dart';
import '../services/sync/hlc.dart';

const int kStatsDbVersion = 6;
const int kUserDataDbVersion = 7;

// Every table that participates in E2EE sync carries a hybrid-logical-clock
// stamp and a dirty flag. `dirty` defaults to 1 so a row written by code that
// predates sync still gets pushed once the engine comes online.
const String _syncCols = ', hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1';

const List<String> _statsTableStmts = [
  '''
    CREATE TABLE IF NOT EXISTS playsession (
      id TEXT PRIMARY KEY,
      start_time REAL,
      end_time REAL,
      platform TEXT,
      device_id TEXT$_syncCols
    )''',
  '''
    CREATE TABLE IF NOT EXISTS playevent (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      uid TEXT,
      session_id TEXT,
      song_filename TEXT,
      timestamp REAL,
      duration_played REAL,
      total_length REAL,
      play_ratio REAL,
      foreground_duration REAL,
      background_duration REAL,
      source TEXT,
      queue_id TEXT$_syncCols,
      FOREIGN KEY (session_id) REFERENCES playsession (id)
    )''',
  // Tombstones for explicit removals. Here only the database optimizer writes
  // them (deleting junk play events/sessions) so junk does not resurrect from
  // other devices.
  '''
    CREATE TABLE IF NOT EXISTS sync_tombstone (
      entity TEXT NOT NULL,
      key TEXT NOT NULL,
      hlc INTEGER,
      dirty INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (entity, key)
    )''',
  'CREATE INDEX IF NOT EXISTS idx_playevent_ts ON playevent(timestamp)',
];

const String _songIdentityStmt = '''
    CREATE TABLE IF NOT EXISTS song_identity (
      filename TEXT PRIMARY KEY,
      cid TEXT NOT NULL,
      mtime REAL,
      status INTEGER NOT NULL DEFAULT 0,
      seen_at REAL
    )''';

const List<String> _userDataTableStmts = [
  '''
    CREATE TABLE IF NOT EXISTS userdata (
      username TEXT PRIMARY KEY,
      password_hash TEXT,
      created_at REAL
    )''',
  'CREATE TABLE IF NOT EXISTS favorite (filename TEXT PRIMARY KEY, added_at REAL$_syncCols)',
  'CREATE TABLE IF NOT EXISTS suggestless (filename TEXT PRIMARY KEY, added_at REAL$_syncCols)',
  'CREATE TABLE IF NOT EXISTS hidden (filename TEXT PRIMARY KEY, hidden_at REAL$_syncCols)',
  'CREATE TABLE IF NOT EXISTS cover_miss (filename TEXT PRIMARY KEY, file_mtime REAL, checked_at REAL)',
  '''
    CREATE TABLE IF NOT EXISTS song (
      filename TEXT PRIMARY KEY,
      title TEXT,
      artist TEXT,
      album TEXT,
      url TEXT,
      cover_url TEXT,
      has_lyrics INTEGER,
      play_count INTEGER,
      duration_ms INTEGER,
      mtime REAL,
      created_epoch_sec REAL,
      song_date_epoch_sec REAL
    )''',
  '''
    CREATE TABLE IF NOT EXISTS playlist (
      id TEXT PRIMARY KEY,
      name TEXT,
      description TEXT,
      is_recommendation INTEGER DEFAULT 0,
      created_at REAL,
      updated_at REAL$_syncCols
    )''',
  '''
    CREATE TABLE IF NOT EXISTS playlist_song (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      playlist_id TEXT,
      song_filename TEXT,
      added_at REAL$_syncCols,
      FOREIGN KEY (playlist_id) REFERENCES playlist (id)
    )''',
  '''
    CREATE TABLE IF NOT EXISTS merged_song_group (
      id TEXT PRIMARY KEY,
      priority_filename TEXT,
      created_at REAL$_syncCols
    )''',
  '''
    CREATE TABLE IF NOT EXISTS merged_song (
      filename TEXT PRIMARY KEY,
      group_id TEXT,
      added_at REAL$_syncCols,
      FOREIGN KEY (group_id) REFERENCES merged_song_group (id) ON DELETE CASCADE
    )''',
  '''
    CREATE TABLE IF NOT EXISTS recommendation_preference (
      id TEXT PRIMARY KEY,
      custom_title TEXT,
      is_pinned INTEGER DEFAULT 0,
      updated_at REAL
    )''',
  'CREATE TABLE IF NOT EXISTS recommendation_removal (id TEXT PRIMARY KEY, removed_at REAL)',
  '''
    CREATE TABLE IF NOT EXISTS queue_snapshot (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at REAL NOT NULL,
      source TEXT NOT NULL,
      song_count INTEGER NOT NULL DEFAULT 0,
      songs_json TEXT$_syncCols
    )''',
  '''
    CREATE TABLE IF NOT EXISTS current_queue (
      id TEXT PRIMARY KEY,
      queue_json TEXT,
      updated_at REAL$_syncCols
    )''',
  '''
    CREATE TABLE IF NOT EXISTS queue_snapshot_song (
      snapshot_id TEXT NOT NULL,
      song_filename TEXT NOT NULL,
      position INTEGER NOT NULL,
      PRIMARY KEY (snapshot_id, position),
      FOREIGN KEY (snapshot_id) REFERENCES queue_snapshot (id) ON DELETE CASCADE
    )''',
  '''
    CREATE TABLE IF NOT EXISTS artist_art (
      artist_name TEXT PRIMARY KEY,
      image_url TEXT,
      local_path TEXT,
      source TEXT,
      updated_at REAL$_syncCols
    )''',
  '''
    CREATE TABLE IF NOT EXISTS album_art (
      album_key TEXT PRIMARY KEY,
      album_name TEXT,
      artist_name TEXT,
      image_url TEXT,
      local_path TEXT,
      source TEXT,
      updated_at REAL$_syncCols
    )''',
  '''
    CREATE TABLE IF NOT EXISTS translated_lyrics (
      filename TEXT,
      target_lang TEXT,
      translated_content TEXT,
      source_hash TEXT,
      updated_at REAL,
      PRIMARY KEY (filename, target_lang)
    )''',
  '''
    CREATE TABLE IF NOT EXISTS lyrics_timing_offset (
      filename TEXT PRIMARY KEY,
      offset_seconds REAL NOT NULL DEFAULT 0
    )''',
  // Durable filename -> audio content id memory. Not synced as rows: each
  // device derives it from its own files, and ids travel inside sync payloads.
  // status: 0 live, 1 orphan (waiting for its audio), 2 alias (former name).
  _songIdentityStmt,
  // Explicit removals of synced user-data rows (unfavorite, delete playlist,
  // unmerge, reset art, ...). A tombstone beats a row iff tomb.hlc > row.hlc.
  '''
    CREATE TABLE IF NOT EXISTS sync_tombstone (
      entity TEXT NOT NULL,
      key TEXT NOT NULL,
      hlc INTEGER,
      dirty INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (entity, key)
    )''',
  // Per-settings-key sync metadata (the values themselves stay in
  // SharedPreferences; only the clock/dirty state lives here).
  '''
    CREATE TABLE IF NOT EXISTS sync_setting_meta (
      key TEXT PRIMARY KEY,
      hlc INTEGER,
      dirty INTEGER NOT NULL DEFAULT 1
    )''',
];

// Kept for tests and debugging that join the schema.
String get kStatsSchema => '${_statsTableStmts.join(';\n')};';
String get kUserDataSchemaV2 => '${_userDataTableStmts.join(';\n')};';

Future<void> _createAllUserDataTables(Database db) async {
  for (final stmt in _userDataTableStmts) {
    await db.execute(stmt);
  }
}

Future<void> _createAllStatsTables(Database db) async {
  for (final stmt in _statsTableStmts) {
    await db.execute(stmt);
  }
}

Future<void> createUserDataSchema(Database db) async {
  await _createAllUserDataTables(db);
  await _createUserDataIndexes(db);
  await _ensureTranslatedLyricsSourceHash(db);
}

Future<void> createStatsSchema(Database db) async {
  await _createAllStatsTables(db);
  await _createStatsIndexes(db);
  await _createPlayEventQueueIndex(db);
}

Future<void> upgradeStatsFrom1To2(Database db) async {
  final cols = await db.rawQuery('PRAGMA table_info(playevent)');
  if (!cols.any((c) => c['name'] == 'source')) {
    await db.execute('ALTER TABLE playevent ADD COLUMN source TEXT');
  }
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playevent_ts ON playevent(timestamp)');
}

/// Stats v2 -> v3: sync change tracking. Adds `hlc`/`dirty` to playsession and
/// playevent, a stable `uid` per play event (backfilled deterministically), and
/// the stats-side tombstone table.
Future<void> upgradeStatsFrom2To3(Database db) async {
  await _addSyncColumns(db, 'playsession');
  await _addSyncColumns(db, 'playevent');
  await _addColumnIfMissing(db, 'playevent', 'uid', 'TEXT');
  await db.execute(
      _statsTableStmts.firstWhere((s) => s.contains('sync_tombstone')));
  await backfillPlayEventUids(db);
  await _createStatsIndexes(db);
}

/// Stats v3 -> v4: each play event records the queue history snapshot it was
/// played from (`queue_snapshot.id` in the user-data DB), so listening history
/// can be grouped by queue. Older events stay null; there is nothing reliable
/// to backfill them from.
Future<void> upgradeStatsFrom3To4(Database db) async {
  await _addColumnIfMissing(db, 'playevent', 'queue_id', 'TEXT');
  await _createPlayEventQueueIndex(db);
}

/// Stats v4 -> v5: removes phantom skips. Before the settled-sequence fix,
/// the transient tracks the player flicked through while loading a queue were
/// recorded as sub-second skips, which skewed every skip statistic. Only a
/// burst matching that pattern is removed: several back-to-back fast skips
/// near the start of an app session, ended by a real listen or a slower skip.
/// Isolated quick skips and bursts at the end of a session are kept, since
/// those look like a person skipping.
Future<void> upgradeStatsFrom4To5(Database db) async {
  const fastSkipMaxSec = 1.5;
  const skipRatio = 0.25;
  const minBurst = 3;
  const maxChainGapSec = 5.0;
  const startupWindowSec = 30.0;
  const maxEventsBeforeBurst = 1;

  final rows = await db.rawQuery(
    'SELECT id, session_id, timestamp, duration_played, play_ratio '
    'FROM playevent WHERE session_id IS NOT NULL AND timestamp IS NOT NULL '
    'ORDER BY session_id, timestamp, id',
  );

  bool isFastSkip(Map<String, Object?> r) {
    final played = (r['duration_played'] as num?)?.toDouble() ?? 0.0;
    final ratio = (r['play_ratio'] as num?)?.toDouble() ?? 0.0;
    return played <= fastSkipMaxSec && ratio < skipRatio;
  }

  double ts(Map<String, Object?> r) => (r['timestamp'] as num).toDouble();

  final toDelete = <int>[];
  var start = 0;
  while (start < rows.length) {
    final session = rows[start]['session_id'];
    var end = start;
    while (end < rows.length && rows[end]['session_id'] == session) {
      end++;
    }
    final events = rows.sublist(start, end);
    final sessionStart = ts(events.first);

    var i = 0;
    while (i < events.length) {
      if (!isFastSkip(events[i])) {
        i++;
        continue;
      }
      var j = i + 1;
      while (j < events.length &&
          isFastSkip(events[j]) &&
          ts(events[j]) - ts(events[j - 1]) <= maxChainGapSec) {
        j++;
      }
      final burstLen = j - i;
      final atStartup = i <= maxEventsBeforeBurst &&
          ts(events[i]) - sessionStart <= startupWindowSec;
      // j < length means a non-fast event (or a slow-chained one) follows.
      final terminated = j < events.length && !isFastSkip(events[j]);
      if (burstLen >= minBurst && atStartup && terminated) {
        for (var k = i; k < j; k++) {
          toDelete.add(events[k]['id'] as int);
        }
      }
      i = j;
    }
    start = end;
  }

  const chunk = 500;
  for (var c = 0; c < toDelete.length; c += chunk) {
    final ids = toDelete.sublist(c, min(c + chunk, toDelete.length));
    await db.rawDelete(
      'DELETE FROM playevent WHERE id IN (${List.filled(ids.length, '?').join(',')})',
      ids,
    );
  }
}

/// Stats v5 -> v6: removes skips the player produced, not the listener.
///
/// Removes three or more consecutive fast skips spaced under 0.5s apart. That
/// is faster than a person can tap, so it means the app advanced the queue
/// itself. Human-paced chains are kept however long they are, and a row with no
/// play ratio is kept: a missing ratio is not evidence of a skip.
Future<void> upgradeStatsFrom5To6(Database db) async {
  const fastSkipMaxSec = 1.5;
  const skipRatio = 0.25;
  const maxMachineGapSec = 0.5;
  const minBurst = 3;

  final rows = await db.rawQuery(
    'SELECT id, uid, session_id, timestamp, duration_played, play_ratio, '
    'total_length FROM playevent '
    'WHERE session_id IS NOT NULL AND timestamp IS NOT NULL '
    'ORDER BY session_id, timestamp, id',
  );

  double? ratioOf(Map<String, Object?> r) {
    final stored = (r['play_ratio'] as num?)?.toDouble();
    if (stored != null) return stored;
    final played = (r['duration_played'] as num?)?.toDouble() ?? 0.0;
    final length = (r['total_length'] as num?)?.toDouble() ?? 0.0;
    return length > 0 ? played / length : null;
  }

  bool isFastSkip(Map<String, Object?> r) {
    final played = (r['duration_played'] as num?)?.toDouble() ?? 0.0;
    final ratio = ratioOf(r);
    return ratio != null && played <= fastSkipMaxSec && ratio < skipRatio;
  }

  double ts(Map<String, Object?> r) => (r['timestamp'] as num).toDouble();

  final doomed = <Map<String, Object?>>[];
  var start = 0;
  while (start < rows.length) {
    final session = rows[start]['session_id'];
    var end = start;
    while (end < rows.length && rows[end]['session_id'] == session) {
      end++;
    }
    final events = rows.sublist(start, end);

    var i = 0;
    while (i < events.length) {
      if (!isFastSkip(events[i])) {
        i++;
        continue;
      }
      var j = i + 1;
      while (j < events.length &&
          isFastSkip(events[j]) &&
          ts(events[j]) - ts(events[j - 1]) <= maxMachineGapSec) {
        j++;
      }
      if (j - i >= minBurst) {
        doomed.addAll(events.sublist(i, j));
      }
      i = j;
    }
    start = end;
  }

  if (doomed.isEmpty) return;

  const chunk = 500;
  for (var c = 0; c < doomed.length; c += chunk) {
    final ids = [
      for (final r in doomed.sublist(c, min(c + chunk, doomed.length)))
        r['id'] as int,
    ];
    await db.rawDelete(
      'DELETE FROM playevent WHERE id IN (${List.filled(ids.length, '?').join(',')})',
      ids,
    );
  }

  // Tombstone the removals or they resurrect from another device on sync.
  final newestRow = await db.rawQuery('SELECT MAX(hlc) AS m FROM playevent');
  var stamp = Hlc.instance.now();
  final newest = (newestRow.first['m'] as num?)?.toInt() ?? 0;
  if (newest >= stamp) stamp = newest + 1;
  for (final row in doomed) {
    final uid = row['uid'] as String?;
    if (uid == null || uid.isEmpty) continue;
    await db.insert(
      'sync_tombstone',
      {
        'entity': 'play_events', // DatabaseService.tombPlayEvents
        'key': uid,
        'hlc': stamp++,
        'dirty': 1,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }
}

// Separate from _createStatsIndexes, which older upgrade steps run before the
// column exists.
Future<void> _createPlayEventQueueIndex(Database db) async {
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playevent_queue ON playevent(queue_id)');
}

Future<void> upgradeUserDataFrom1To2(Database db) async {
  await _createAllUserDataTables(db);
  await _ensureSongMissingColumns(db);
  await _createUserDataIndexes(db);
  await _ensureTranslatedLyricsSourceHash(db);
}

Future<void> upgradeUserDataFrom2To3(Database db) async {
  await db.execute('''
    CREATE TABLE IF NOT EXISTS lyrics_timing_offset (
      filename TEXT PRIMARY KEY,
      offset_seconds REAL NOT NULL DEFAULT 0
    )''');
}

Future<void> upgradeUserDataFrom3To4(Database db) async {
  await _createMembershipIndexes(db);
}

/// User data v4 -> v5: sync change tracking. Adds `hlc`/`dirty` to every synced
/// user-data table and creates the tombstone and settings-metadata tables.
Future<void> upgradeUserDataFrom4To5(Database db) async {
  await db.execute(
      _userDataTableStmts.firstWhere((s) => s.contains('sync_tombstone')));
  await db.execute(
      _userDataTableStmts.firstWhere((s) => s.contains('sync_setting_meta')));
  await _createSyncUserDataIndexes(db);
}

/// User data v5 -> v6: queue history and the current queue join sync. Song
/// lists are mirrored into `songs_json` so a snapshot is one syncable row.
Future<void> upgradeUserDataFrom5To6(Database db) async {
  await _addColumnIfMissing(db, 'queue_snapshot', 'songs_json', 'TEXT');
  await db.execute(
      _userDataTableStmts.firstWhere((s) => s.contains('current_queue')));
  await _createSyncUserDataIndexes(db);
  final snaps = await db.query('queue_snapshot', columns: ['id']);
  for (final snap in snaps) {
    final songs = await db.query('queue_snapshot_song',
        columns: ['song_filename'],
        where: 'snapshot_id = ?',
        whereArgs: [snap['id']],
        orderBy: 'position ASC');
    await db.update(
        'queue_snapshot',
        {
          'songs_json':
              jsonEncode(songs.map((r) => r['song_filename']).toList())
        },
        where: 'id = ?',
        whereArgs: [snap['id']]);
  }
}

/// User data v6 -> v7: durable content ids so a song stays recognizable after
/// its file is renamed, on this device or another.
Future<void> upgradeUserDataFrom6To7(Database db) async {
  await db.execute(_songIdentityStmt);
  await _createSongIdentityIndexes(db);
}

Future<void> _createSongIdentityIndexes(Database db) async {
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_identity_cid ON song_identity(cid)');
}

const List<String> _syncedUserDataTables = [
  'queue_snapshot',
  'current_queue',
  'favorite',
  'suggestless',
  'hidden',
  'playlist',
  'playlist_song',
  'merged_song_group',
  'merged_song',
  'artist_art',
  'album_art',
];

Future<void> _addColumnIfMissing(
    Database db, String table, String col, String type) async {
  final cols = await db.rawQuery('PRAGMA table_info($table)');
  if (!cols.any((c) => c['name'] == col)) {
    await db.execute('ALTER TABLE $table ADD COLUMN $col $type');
  }
}

Future<void> _addSyncColumns(Database db, String table) async {
  await _addColumnIfMissing(db, table, 'hlc', 'INTEGER');
  // SQLite forbids adding a NOT NULL column without a constant default; the
  // literal default below satisfies that and marks every pre-existing row dirty.
  await _addColumnIfMissing(db, table, 'dirty', 'INTEGER NOT NULL DEFAULT 1');
}

/// Assigns a stable `uid` to every play event lacking one.
///
/// Deterministic so the same local history produces the same ids on re-run:
/// `uid = sha256(session_id | song_filename | ordinal)[:32]`, where `ordinal`
/// counts rows sharing (session_id, song_filename) in timestamp then id order.
Future<void> backfillPlayEventUids(DatabaseExecutor db) async {
  final rows = await db.query(
    'playevent',
    columns: ['id', 'uid', 'session_id', 'song_filename'],
    orderBy: 'timestamp ASC, id ASC',
  );
  final counters = <String, int>{};
  for (final row in rows) {
    final sid = (row['session_id'] as String?) ?? '';
    final sf = (row['song_filename'] as String?) ?? '';
    final groupKey = '$sid\u0000$sf';
    final ordinal = counters[groupKey] ?? 0;
    counters[groupKey] = ordinal + 1;
    if (row['uid'] != null) continue;
    final digest = sha256.convert(utf8.encode('$sid|$sf|$ordinal')).toString();
    await db.update('playevent', {'uid': digest.substring(0, 32)},
        where: 'id = ?', whereArgs: [row['id']]);
  }
}

/// Indexes for the two tables that name a song from a second column.
///
/// `playlist_song` is keyed on its own `id`, so anything that resolves a song
/// to its playlists — including every batch rename and every bulk delete —
/// scanned the whole table. `queue_snapshot_song` is keyed on
/// (snapshot_id, position), so the same held for saved queues.
Future<void> _createMembershipIndexes(Database db) async {
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playlist_song_song_filename ON playlist_song(song_filename)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_queue_snapshot_song_song_filename ON queue_snapshot_song(song_filename)');
}

Future<void> _ensureSongMissingColumns(Database db) async {
  final cols = await db.rawQuery('PRAGMA table_info(song)');
  final names = {for (final c in cols) c['name'] as String};
  Future<void> addIfMissing(String col, String type) async {
    if (!names.contains(col)) {
      await db.execute('ALTER TABLE song ADD COLUMN $col $type');
    }
  }

  await addIfMissing('created_epoch_sec', 'REAL');
  await addIfMissing('song_date_epoch_sec', 'REAL');
}

Future<void> _createStatsIndexes(Database db) async {
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playevent_ts ON playevent(timestamp)');
  await db.execute(
      'CREATE UNIQUE INDEX IF NOT EXISTS idx_playevent_uid ON playevent(uid)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playevent_dirty ON playevent(dirty)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_playsession_dirty ON playsession(dirty)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_stats_tombstone_dirty ON sync_tombstone(dirty)');
}

Future<void> _createUserDataIndexes(Database db) async {
  await db
      .execute('CREATE INDEX IF NOT EXISTS idx_song_artist ON song(artist)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_song_album ON song(album)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_song_mtime ON song(mtime)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_created_epoch_sec ON song(created_epoch_sec)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_song_date_epoch_sec ON song(song_date_epoch_sec)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_queue_snapshot_created_at ON queue_snapshot(created_at)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_queue_snapshot_song_snapshot_id ON queue_snapshot_song(snapshot_id)');
  await _createMembershipIndexes(db);
  await _createSongIdentityIndexes(db);
  await _createSyncUserDataIndexes(db);
}

/// Sync change-tracking indexes. Also ensures the `hlc`/`dirty` columns exist
/// first: the v1->v2 upgrade path runs this over tables that predate sync.
Future<void> _createSyncUserDataIndexes(Database db) async {
  for (final table in _syncedUserDataTables) {
    await _addSyncColumns(db, table);
    await db.execute(
        'CREATE INDEX IF NOT EXISTS idx_${table}_dirty ON $table(dirty)');
  }
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_userdata_tombstone_dirty ON sync_tombstone(dirty)');
  await db.execute(
      'CREATE INDEX IF NOT EXISTS idx_sync_setting_meta_dirty ON sync_setting_meta(dirty)');
}

Future<void> _ensureTranslatedLyricsSourceHash(Database db) async {
  final cols = await db.rawQuery('PRAGMA table_info(translated_lyrics)');
  if (!cols.any((c) => c['name'] == 'source_hash')) {
    await db
        .execute('ALTER TABLE translated_lyrics ADD COLUMN source_hash TEXT');
  }
}
