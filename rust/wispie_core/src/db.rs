//! SQLite engine for the two local databases.
//!
//! The app used to reach SQLite through sqflite (a platform plugin on mobile,
//! `sqflite_common_ffi` on desktop). Here it is one bundled SQLite per target,
//! opened in this process, which is what lets the same file open on all six
//! platforms.
//!
//! Opening runs the same upgrade ladder the Dart build ran, step for step, so
//! a database from any older version lands on the same schema and the same
//! rows, including the two passes that prune skips the old queue bug invented.
//! A final idempotent reconcile then repairs anything a half-finished upgrade
//! left behind, since the ladder only ever runs once per version.

use std::collections::HashMap;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};

use rusqlite::types::Value as SqlValue;
use rusqlite::{Connection, OpenFlags, OptionalExtension};
use serde_json::{json, Map, Value};

use crate::emitter::{Emit, Emitter};

pub const STATS_VERSION: i64 = 6;
pub const DATA_VERSION: i64 = 12;

/// Every table that carries sync stamps, with the kind of database it lives in.
const STATS_SYNCED: &[&str] = &["playsession", "playevent"];
const DATA_SYNCED: &[&str] = &[
    "queue_snapshot",
    "current_queue",
    "favorite",
    "suggestless",
    "hidden",
    "playlist",
    "playlist_song",
    "merged_song_group",
    "merged_song",
    "artist_art",
    "album_art",
];

const SYNC_TOMBSTONE: &str = "
    CREATE TABLE IF NOT EXISTS sync_tombstone (
      entity TEXT NOT NULL,
      key TEXT NOT NULL,
      hlc INTEGER,
      dirty INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (entity, key)
    )";

const STATS_TABLES: &[&str] = &[
    "
    CREATE TABLE IF NOT EXISTS playsession (
      id TEXT PRIMARY KEY,
      start_time REAL,
      end_time REAL,
      platform TEXT,
      device_id TEXT, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1
    )",
    "
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
      queue_id TEXT, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (session_id) REFERENCES playsession (id)
    )",
    SYNC_TOMBSTONE,
];

const STATS_INDEXES: &[&str] = &[
    "CREATE INDEX IF NOT EXISTS idx_playevent_ts ON playevent(timestamp)",
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_playevent_uid ON playevent(uid)",
    "CREATE INDEX IF NOT EXISTS idx_playevent_dirty ON playevent(dirty)",
    "CREATE INDEX IF NOT EXISTS idx_playsession_dirty ON playsession(dirty)",
    "CREATE INDEX IF NOT EXISTS idx_stats_tombstone_dirty ON sync_tombstone(dirty)",
];

// Separate from STATS_INDEXES: the 2 -> 3 step runs that list before the
// `queue_id` column exists.
const STATS_QUEUE_INDEX: &str =
    "CREATE INDEX IF NOT EXISTS idx_playevent_queue ON playevent(queue_id)";

const REMOTE_SONG_TABLE: &str = "
    CREATE TABLE IF NOT EXISTS remote_song (
      filename TEXT PRIMARY KEY,
      remote_id TEXT NOT NULL,
      title TEXT NOT NULL,
      artist TEXT NOT NULL,
      album TEXT,
      cover_url TEXT,
      duration_ms INTEGER,
      is_available INTEGER NOT NULL DEFAULT 1,
      in_library INTEGER NOT NULL DEFAULT 0,
      updated_at REAL NOT NULL
    )";

const YOUTUBE_LINK_TABLE: &str = "
    CREATE TABLE IF NOT EXISTS youtube_playlist_link (
      remote_playlist_id TEXT PRIMARY KEY,
      local_playlist_id TEXT NOT NULL,
      remote_title TEXT,
      last_synced_at REAL,
      item_count INTEGER
    )";

const CURRENT_QUEUE_TABLE: &str = "
    CREATE TABLE IF NOT EXISTS current_queue (
      id TEXT PRIMARY KEY,
      queue_json TEXT,
      updated_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1
    )";

const SETTING_META_TABLE: &str = "
    CREATE TABLE IF NOT EXISTS sync_setting_meta (
      key TEXT PRIMARY KEY,
      hlc INTEGER,
      dirty INTEGER NOT NULL DEFAULT 1
    )";

const SONG_IDENTITY_TABLE: &str = "
    CREATE TABLE IF NOT EXISTS song_identity (
      filename TEXT PRIMARY KEY,
      cid TEXT NOT NULL,
      mtime REAL,
      status INTEGER NOT NULL DEFAULT 0,
      seen_at REAL
    )";

const DATA_TABLES: &[&str] = &[
    "
    CREATE TABLE IF NOT EXISTS userdata (
      username TEXT PRIMARY KEY,
      password_hash TEXT,
      created_at REAL
    )",
    "CREATE TABLE IF NOT EXISTS favorite (filename TEXT PRIMARY KEY, added_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1)",
    "CREATE TABLE IF NOT EXISTS suggestless (filename TEXT PRIMARY KEY, added_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1)",
    "CREATE TABLE IF NOT EXISTS hidden (filename TEXT PRIMARY KEY, hidden_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1)",
    "CREATE TABLE IF NOT EXISTS cover_miss (filename TEXT PRIMARY KEY, file_mtime REAL, checked_at REAL)",
    REMOTE_SONG_TABLE,
    "
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
    )",
    "
    CREATE TABLE IF NOT EXISTS playlist (
      id TEXT PRIMARY KEY,
      name TEXT,
      description TEXT,
      is_recommendation INTEGER DEFAULT 0,
      created_at REAL,
      updated_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1
    )",
    "
    CREATE TABLE IF NOT EXISTS playlist_song (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      playlist_id TEXT,
      song_filename TEXT,
      added_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (playlist_id) REFERENCES playlist (id)
    )",
    "
    CREATE TABLE IF NOT EXISTS merged_song_group (
      id TEXT PRIMARY KEY,
      priority_filename TEXT,
      created_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1
    )",
    "
    CREATE TABLE IF NOT EXISTS merged_song (
      filename TEXT PRIMARY KEY,
      group_id TEXT,
      added_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1,
      FOREIGN KEY (group_id) REFERENCES merged_song_group (id) ON DELETE CASCADE
    )",
    "
    CREATE TABLE IF NOT EXISTS recommendation_preference (
      id TEXT PRIMARY KEY,
      custom_title TEXT,
      is_pinned INTEGER DEFAULT 0,
      updated_at REAL
    )",
    "CREATE TABLE IF NOT EXISTS recommendation_removal (id TEXT PRIMARY KEY, removed_at REAL)",
    "
    CREATE TABLE IF NOT EXISTS queue_snapshot (
      id TEXT PRIMARY KEY,
      name TEXT NOT NULL,
      created_at REAL NOT NULL,
      source TEXT NOT NULL,
      song_count INTEGER NOT NULL DEFAULT 0,
      songs_json TEXT, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1
    )",
    CURRENT_QUEUE_TABLE,
    "
    CREATE TABLE IF NOT EXISTS queue_snapshot_song (
      snapshot_id TEXT NOT NULL,
      song_filename TEXT NOT NULL,
      position INTEGER NOT NULL,
      PRIMARY KEY (snapshot_id, position),
      FOREIGN KEY (snapshot_id) REFERENCES queue_snapshot (id) ON DELETE CASCADE
    )",
    "
    CREATE TABLE IF NOT EXISTS artist_art (
      artist_name TEXT PRIMARY KEY,
      image_url TEXT,
      local_path TEXT,
      source TEXT,
      updated_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1
    )",
    "
    CREATE TABLE IF NOT EXISTS album_art (
      album_key TEXT PRIMARY KEY,
      album_name TEXT,
      artist_name TEXT,
      image_url TEXT,
      local_path TEXT,
      source TEXT,
      updated_at REAL, hlc INTEGER, dirty INTEGER NOT NULL DEFAULT 1
    )",
    "
    CREATE TABLE IF NOT EXISTS translated_lyrics (
      filename TEXT,
      target_lang TEXT,
      translated_content TEXT,
      source_hash TEXT,
      updated_at REAL,
      PRIMARY KEY (filename, target_lang)
    )",
    "
    CREATE TABLE IF NOT EXISTS lyrics_timing_offset (
      filename TEXT PRIMARY KEY,
      offset_seconds REAL NOT NULL DEFAULT 0
    )",
    YOUTUBE_LINK_TABLE,
    SONG_IDENTITY_TABLE,
    SYNC_TOMBSTONE,
    SETTING_META_TABLE,
];

const DATA_INDEXES: &[&str] = &[
    "CREATE INDEX IF NOT EXISTS idx_song_artist ON song(artist)",
    "CREATE INDEX IF NOT EXISTS idx_song_album ON song(album)",
    "CREATE INDEX IF NOT EXISTS idx_song_mtime ON song(mtime)",
    "CREATE INDEX IF NOT EXISTS idx_song_created_epoch_sec ON song(created_epoch_sec)",
    "CREATE INDEX IF NOT EXISTS idx_song_date_epoch_sec ON song(song_date_epoch_sec)",
    "CREATE INDEX IF NOT EXISTS idx_queue_snapshot_created_at ON queue_snapshot(created_at)",
    "CREATE INDEX IF NOT EXISTS idx_queue_snapshot_song_snapshot_id ON queue_snapshot_song(snapshot_id)",
    "CREATE INDEX IF NOT EXISTS idx_playlist_song_song_filename ON playlist_song(song_filename)",
    "CREATE INDEX IF NOT EXISTS idx_queue_snapshot_song_song_filename ON queue_snapshot_song(song_filename)",
    "CREATE INDEX IF NOT EXISTS idx_song_identity_cid ON song_identity(cid)",
    "CREATE INDEX IF NOT EXISTS idx_youtube_playlist_link_local ON youtube_playlist_link(local_playlist_id)",
    "CREATE INDEX IF NOT EXISTS idx_userdata_tombstone_dirty ON sync_tombstone(dirty)",
    "CREATE INDEX IF NOT EXISTS idx_sync_setting_meta_dirty ON sync_setting_meta(dirty)",
];

/// Columns a database from an older build may lack, with the type to add.
const DATA_LATE_COLUMNS: &[(&str, &str, &str)] = &[
    ("song", "created_epoch_sec", "REAL"),
    ("song", "song_date_epoch_sec", "REAL"),
    ("remote_song", "in_library", "INTEGER NOT NULL DEFAULT 0"),
    ("remote_song", "album", "TEXT"),
    ("translated_lyrics", "source_hash", "TEXT"),
    ("queue_snapshot", "songs_json", "TEXT"),
];

const STATS_LATE_COLUMNS: &[(&str, &str, &str)] = &[
    ("playevent", "source", "TEXT"),
    ("playevent", "uid", "TEXT"),
    ("playevent", "queue_id", "TEXT"),
];

static NEXT_ID: AtomicU64 = AtomicU64::new(1);
static CONNECTIONS: OnceLock<Mutex<HashMap<u64, Connection>>> = OnceLock::new();

fn connections() -> &'static Mutex<HashMap<u64, Connection>> {
    CONNECTIONS.get_or_init(|| Mutex::new(HashMap::new()))
}

pub fn run(payload: &Value, emitter: &Emitter) -> Result<(), String> {
    let action = payload
        .get("action")
        .and_then(|value| value.as_str())
        .ok_or_else(|| "db needs an action".to_string())?;
    let reply = match action {
        "open" => open(payload)?,
        "close" => {
            let id = connection_id(payload)?;
            let mut guard = lock();
            guard.remove(&id);
            json!({ "closed": true })
        }
        "begin" => with(payload, |connection| {
            connection
                .execute_batch("BEGIN")
                .map_err(|error| format!("begin: {error}"))?;
            Ok(json!({ "begin": true }))
        })?,
        "commit" => with(payload, |connection| {
            connection
                .execute_batch("COMMIT")
                .map_err(|error| format!("commit: {error}"))?;
            Ok(json!({ "commit": true }))
        })?,
        "rollback" => with(payload, |connection| {
            if !connection.is_autocommit() {
                connection
                    .execute_batch("ROLLBACK")
                    .map_err(|error| format!("rollback: {error}"))?;
            }
            Ok(json!({ "rollback": true }))
        })?,
        "backfill_uids" => with(payload, |connection| {
            backfill_play_event_uids(connection)?;
            Ok(json!({ "backfilled": true }))
        })?,
        "query" => query(payload)?,
        "execute" => execute(payload)?,
        "batch" => batch(payload)?,
        "user_list" => user_list(payload)?,
        "cover_miss" => cover_miss(payload)?,
        "lyrics_offset" => lyrics_offset(payload)?,
        "art" => art(payload)?,
        other => return Err(format!("unknown db action {other}")),
    };
    emitter.emit(Emit::Json(reply));
    Ok(())
}

fn lock() -> std::sync::MutexGuard<'static, HashMap<u64, Connection>> {
    match connections().lock() {
        Ok(guard) => guard,
        Err(poisoned) => poisoned.into_inner(),
    }
}

fn connection_id(payload: &Value) -> Result<u64, String> {
    payload
        .get("id")
        .and_then(|value| value.as_u64())
        .ok_or_else(|| "db needs a connection id".to_string())
}

fn with<T>(
    payload: &Value,
    body: impl FnOnce(&mut Connection) -> Result<T, String>,
) -> Result<T, String> {
    let id = connection_id(payload)?;
    let mut guard = lock();
    let connection = guard
        .get_mut(&id)
        .ok_or_else(|| format!("connection {id} is not open"))?;
    body(connection)
}

fn open(payload: &Value) -> Result<Value, String> {
    let path = payload
        .get("path")
        .and_then(|value| value.as_str())
        .ok_or_else(|| "db open needs a path".to_string())?;
    // No schema means "open as it stands": an integrity check or a backup
    // read must not create or upgrade anything.
    let stats = match payload.get("schema").and_then(|value| value.as_str()) {
        Some("stats") => Some(true),
        Some("userdata") => Some(false),
        Some(other) => return Err(format!("unknown schema {other}")),
        None => None,
    };
    let read_only = payload
        .get("read_only")
        .and_then(|value| value.as_bool())
        .unwrap_or(false);
    if !read_only {
        if let Some(parent) = Path::new(path).parent() {
            if !parent.as_os_str().is_empty() {
                std::fs::create_dir_all(parent)
                    .map_err(|error| format!("create db directory: {error}"))?;
            }
        }
    }

    let flags = if read_only {
        OpenFlags::SQLITE_OPEN_READ_ONLY
            | OpenFlags::SQLITE_OPEN_NO_MUTEX
            | OpenFlags::SQLITE_OPEN_URI
    } else {
        OpenFlags::SQLITE_OPEN_READ_WRITE
            | OpenFlags::SQLITE_OPEN_CREATE
            | OpenFlags::SQLITE_OPEN_NO_MUTEX
            | OpenFlags::SQLITE_OPEN_URI
    };
    let mut connection = Connection::open_with_flags(path, flags)
        .map_err(|error| format!("open {path}: {error}"))?;
    connection
        .busy_timeout(std::time::Duration::from_secs(5))
        .map_err(|error| format!("busy timeout: {error}"))?;

    // Foreign keys stay off, as they were under sqflite: it does not enable
    // them either, and bundled SQLite compiles with the opposite default. The
    // schema's REFERENCES clauses are documentation. Enforcement makes a newer
    // remote tombstone for a playlist abort the whole sync transaction while
    // local playlist_song rows still exist, and turns every parent DELETE into
    // a cascade that skips the tombstones the app writes for the children.
    connection
        .execute_batch("PRAGMA foreign_keys = OFF")
        .map_err(|error| format!("foreign keys: {error}"))?;

    let Some(stats) = stats.filter(|_| !read_only) else {
        let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
        lock().insert(id, connection);
        return Ok(json!({ "id": id, "version": 0, "fresh": false }));
    };
    let target = if stats { STATS_VERSION } else { DATA_VERSION };
    let current: i64 = connection
        .query_row("PRAGMA user_version", [], |row| row.get(0))
        .map_err(|error| format!("read version: {error}"))?;
    let fresh = current == 0;
    if fresh {
        let statements = if stats {
            [STATS_TABLES, STATS_INDEXES, &[STATS_QUEUE_INDEX]].concat()
        } else {
            [DATA_TABLES, DATA_INDEXES].concat()
        };
        for statement in statements {
            connection
                .execute_batch(statement)
                .map_err(|error| format!("create schema: {error}"))?;
        }
        if !stats {
            // The per-table dirty indexes are shared with the upgrade steps.
            create_sync_indexes(&connection)?;
        }
    } else if current < target {
        let base_hlc = payload
            .get("hlc")
            .and_then(|value| value.as_i64())
            .unwrap_or_default();
        upgrade(&mut connection, stats, current, base_hlc)?;
        // A killed upgrade can leave a version stamped but a step unfinished;
        // reconcile only adds what is missing, so re-running it is harmless.
        reconcile(&mut connection, stats)?;
    }

    if current < target {
        connection
            .execute_batch(&format!("PRAGMA user_version = {target}"))
            .map_err(|error| format!("stamp version: {error}"))?;
    }

    let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
    lock().insert(id, connection);
    Ok(json!({ "id": id, "version": target, "fresh": fresh }))
}

fn upgrade(
    connection: &mut Connection,
    stats: bool,
    from: i64,
    base_hlc: i64,
) -> Result<(), String> {
    if stats {
        if from < 2 {
            add_column_if_missing(connection, "playevent", "source", "TEXT")?;
            create_index(connection, "idx_playevent_ts", "playevent", "timestamp")?;
        }
        if from < 3 {
            add_sync_columns(connection, "playsession")?;
            add_sync_columns(connection, "playevent")?;
            add_column_if_missing(connection, "playevent", "uid", "TEXT")?;
            connection
                .execute_batch(SYNC_TOMBSTONE)
                .map_err(|error| format!("create tombstones: {error}"))?;
            backfill_play_event_uids(connection)?;
            for statement in STATS_INDEXES {
                connection
                    .execute_batch(statement)
                    .map_err(|error| format!("create stats index: {error}"))?;
            }
        }
        if from < 4 {
            add_column_if_missing(connection, "playevent", "queue_id", "TEXT")?;
            connection
                .execute_batch(STATS_QUEUE_INDEX)
                .map_err(|error| format!("create queue index: {error}"))?;
        }
        if from < 5 {
            prune_startup_skip_bursts(connection)?;
        }
        if from < 6 {
            prune_machine_skip_bursts(connection, base_hlc)?;
        }
        return Ok(());
    }

    if from < 2 {
        for statement in DATA_TABLES {
            connection
                .execute_batch(statement)
                .map_err(|error| format!("create table: {error}"))?;
        }
        add_column_if_missing(connection, "song", "created_epoch_sec", "REAL")?;
        add_column_if_missing(connection, "song", "song_date_epoch_sec", "REAL")?;
        for statement in DATA_INDEXES {
            connection
                .execute_batch(statement)
                .map_err(|error| format!("create index: {error}"))?;
        }
        add_column_if_missing(connection, "translated_lyrics", "source_hash", "TEXT")?;
    }
    if from < 3 {
        connection
            .execute_batch(
                "CREATE TABLE IF NOT EXISTS lyrics_timing_offset (\n      filename TEXT PRIMARY KEY,\n      offset_seconds REAL NOT NULL DEFAULT 0\n    )",
            )
            .map_err(|error| format!("create lyrics_timing_offset: {error}"))?;
    }
    if from < 4 {
        create_index(
            connection,
            "idx_playlist_song_song_filename",
            "playlist_song",
            "song_filename",
        )?;
        create_index(
            connection,
            "idx_queue_snapshot_song_song_filename",
            "queue_snapshot_song",
            "song_filename",
        )?;
    }
    if from < 5 {
        connection
            .execute_batch(SYNC_TOMBSTONE)
            .map_err(|error| format!("create tombstones: {error}"))?;
        connection
            .execute_batch(SETTING_META_TABLE)
            .map_err(|error| format!("create setting meta: {error}"))?;
        create_sync_indexes(connection)?;
    }
    if from < 6 {
        add_column_if_missing(connection, "queue_snapshot", "songs_json", "TEXT")?;
        connection
            .execute_batch(CURRENT_QUEUE_TABLE)
            .map_err(|error| format!("create current_queue: {error}"))?;
        create_sync_indexes(connection)?;
        backfill_snapshot_songs(connection)?;
    }
    if from < 7 {
        connection
            .execute_batch(SONG_IDENTITY_TABLE)
            .map_err(|error| format!("create song_identity: {error}"))?;
        create_index(connection, "idx_song_identity_cid", "song_identity", "cid")?;
    }
    if from < 8 {
        connection
            .execute_batch(REMOTE_SONG_TABLE)
            .map_err(|error| format!("create remote_song: {error}"))?;
    }
    if from < 9 {
        connection
            .execute_batch(YOUTUBE_LINK_TABLE)
            .map_err(|error| format!("create youtube_playlist_link: {error}"))?;
        create_index(
            connection,
            "idx_youtube_playlist_link_local",
            "youtube_playlist_link",
            "local_playlist_id",
        )?;
    }
    if from < 10 {
        delete_audius_rows(connection)?;
    }
    if from < 11 {
        add_column_if_missing(
            connection,
            "remote_song",
            "in_library",
            "INTEGER NOT NULL DEFAULT 0",
        )?;
    }
    if from < 12 {
        add_column_if_missing(connection, "remote_song", "album", "TEXT")?;
    }
    Ok(())
}

fn create_index(
    connection: &Connection,
    name: &str,
    table: &str,
    column: &str,
) -> Result<(), String> {
    connection
        .execute_batch(&format!(
            "CREATE INDEX IF NOT EXISTS {name} ON {table}({column})"
        ))
        .map_err(|error| format!("create {name}: {error}"))
}

fn add_sync_columns(connection: &Connection, table: &str) -> Result<(), String> {
    add_column_if_missing(connection, table, "hlc", "INTEGER")?;
    add_column_if_missing(connection, table, "dirty", "INTEGER NOT NULL DEFAULT 1")
}

fn create_sync_indexes(connection: &Connection) -> Result<(), String> {
    for table in DATA_SYNCED {
        create_index(connection, &format!("idx_{table}_dirty"), table, "dirty")?;
    }
    create_index(
        connection,
        "idx_userdata_tombstone_dirty",
        "sync_tombstone",
        "dirty",
    )?;
    create_index(
        connection,
        "idx_sync_setting_meta_dirty",
        "sync_setting_meta",
        "dirty",
    )
}

fn delete_audius_rows(connection: &Connection) -> Result<(), String> {
    for table in [
        "remote_song",
        "playlist_song",
        "favorite",
        "suggestless",
        "hidden",
        "cover_miss",
    ] {
        let column = if table == "playlist_song" {
            "song_filename"
        } else {
            "filename"
        };
        let statement = format!("DELETE FROM {table} WHERE {column} LIKE 'audius:%'");
        connection
            .execute_batch(&statement)
            .map_err(|error| format!("drop audius rows: {error}"))?;
    }
    Ok(())
}

/// One play event, the fields both skip-pruning passes inspect.
struct PlayRow {
    id: i64,
    uid: Option<String>,
    session: String,
    timestamp: f64,
    played: f64,
    ratio: Option<f64>,
    length: f64,
}

fn read_play_rows(connection: &Connection) -> Result<Vec<PlayRow>, String> {
    let mut statement = connection
        .prepare(
            "SELECT id, uid, session_id, timestamp, duration_played, play_ratio, total_length \
             FROM playevent WHERE session_id IS NOT NULL AND timestamp IS NOT NULL \
             ORDER BY session_id, timestamp, id",
        )
        .map_err(|error| format!("select play events: {error}"))?;
    let rows = statement
        .query_map([], |row| {
            Ok(PlayRow {
                id: row.get(0)?,
                uid: row.get(1)?,
                session: row.get(2)?,
                timestamp: row.get(3)?,
                played: row.get::<_, Option<f64>>(4)?.unwrap_or_default(),
                ratio: row.get(5)?,
                length: row.get::<_, Option<f64>>(6)?.unwrap_or_default(),
            })
        })
        .map_err(|error| format!("read play events: {error}"))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|error| format!("read play events: {error}"))?;
    Ok(rows)
}

fn delete_play_events(connection: &Connection, ids: &[i64]) -> Result<(), String> {
    const CHUNK: usize = 500;
    for chunk in ids.chunks(CHUNK) {
        let placeholders = std::iter::repeat_n("?", chunk.len())
            .collect::<Vec<_>>()
            .join(",");
        let statement = format!("DELETE FROM playevent WHERE id IN ({placeholders})");
        connection
            .execute(&statement, rusqlite::params_from_iter(chunk.iter()))
            .map_err(|error| format!("delete skip rows: {error}"))?;
    }
    Ok(())
}

/// Stats v4 -> v5: the player used to record the tracks it flicked through while
/// loading a queue as sub-second skips. Only a startup burst matching that
/// shape is removed; isolated quick skips look like a person skipping.
fn prune_startup_skip_bursts(connection: &Connection) -> Result<(), String> {
    const FAST_SKIP_MAX_SEC: f64 = 1.5;
    const SKIP_RATIO: f64 = 0.25;
    const MIN_BURST: usize = 3;
    const MAX_CHAIN_GAP_SEC: f64 = 5.0;
    const STARTUP_WINDOW_SEC: f64 = 30.0;
    const MAX_EVENTS_BEFORE_BURST: usize = 1;

    let rows = read_play_rows(connection)?;
    let is_fast_skip = |row: &PlayRow| {
        row.played <= FAST_SKIP_MAX_SEC && row.ratio.unwrap_or_default() < SKIP_RATIO
    };

    let mut doomed: Vec<i64> = Vec::new();
    let mut start = 0usize;
    while start < rows.len() {
        let session = &rows[start].session;
        let mut end = start;
        while end < rows.len() && &rows[end].session == session {
            end += 1;
        }
        let events = &rows[start..end];
        let session_start = events[0].timestamp;
        let mut index = 0usize;
        while index < events.len() {
            if !is_fast_skip(&events[index]) {
                index += 1;
                continue;
            }
            let mut stop = index + 1;
            while stop < events.len()
                && is_fast_skip(&events[stop])
                && events[stop].timestamp - events[stop - 1].timestamp <= MAX_CHAIN_GAP_SEC
            {
                stop += 1;
            }
            let burst = stop - index;
            let at_startup = index <= MAX_EVENTS_BEFORE_BURST
                && events[index].timestamp - session_start <= STARTUP_WINDOW_SEC;
            let terminated = stop < events.len() && !is_fast_skip(&events[stop]);
            if burst >= MIN_BURST && at_startup && terminated {
                doomed.extend(events[index..stop].iter().map(|row| row.id));
            }
            index = stop;
        }
        start = end;
    }
    delete_play_events(connection, &doomed)
}

/// Stats v5 -> v6: three or more fast skips under half a second apart is faster
/// than a person can tap, so the app advanced the queue itself. Removals are
/// tombstoned or they resurrect from another device on sync.
fn prune_machine_skip_bursts(connection: &Connection, base_hlc: i64) -> Result<(), String> {
    const FAST_SKIP_MAX_SEC: f64 = 1.5;
    const SKIP_RATIO: f64 = 0.25;
    const MAX_MACHINE_GAP_SEC: f64 = 0.5;
    const MIN_BURST: usize = 3;

    let rows = read_play_rows(connection)?;
    let ratio_of = |row: &PlayRow| -> Option<f64> {
        if let Some(stored) = row.ratio {
            return Some(stored);
        }
        if row.length > 0.0 {
            return Some(row.played / row.length);
        }
        None
    };
    let is_fast_skip = |row: &PlayRow| -> bool {
        match ratio_of(row) {
            Some(ratio) => row.played <= FAST_SKIP_MAX_SEC && ratio < SKIP_RATIO,
            None => false,
        }
    };

    let mut doomed: Vec<&PlayRow> = Vec::new();
    let mut start = 0usize;
    while start < rows.len() {
        let session = &rows[start].session;
        let mut end = start;
        while end < rows.len() && &rows[end].session == session {
            end += 1;
        }
        let events = &rows[start..end];
        let mut index = 0usize;
        while index < events.len() {
            if !is_fast_skip(&events[index]) {
                index += 1;
                continue;
            }
            let mut stop = index + 1;
            while stop < events.len()
                && is_fast_skip(&events[stop])
                && events[stop].timestamp - events[stop - 1].timestamp <= MAX_MACHINE_GAP_SEC
            {
                stop += 1;
            }
            if stop - index >= MIN_BURST {
                doomed.extend(events[index..stop].iter());
            }
            index = stop;
        }
        start = end;
    }

    if doomed.is_empty() {
        return Ok(());
    }
    let ids: Vec<i64> = doomed.iter().map(|row| row.id).collect();
    delete_play_events(connection, &ids)?;

    let newest: i64 = connection
        .query_row("SELECT MAX(hlc) FROM playevent", [], |row| {
            row.get::<_, Option<i64>>(0)
        })
        .map_err(|error| format!("read newest stamp: {error}"))?
        .unwrap_or_default();
    let mut stamp = if newest >= base_hlc {
        newest + 1
    } else {
        base_hlc
    };
    for row in doomed {
        let Some(uid) = row.uid.as_ref().filter(|uid| !uid.is_empty()) else {
            continue;
        };
        connection
            .execute(
                "INSERT OR REPLACE INTO sync_tombstone (entity, key, hlc, dirty) \
                 VALUES ('play_events', ?1, ?2, 1)",
                rusqlite::params![uid, stamp],
            )
            .map_err(|error| format!("tombstone removed skip: {error}"))?;
        stamp += 1;
    }
    Ok(())
}

/// Brings a database written by an older build up to the current schema.
///
/// Idempotent by construction: every step checks before it acts, so a partial
/// run (a crash mid-open) simply repeats on the next launch.
fn reconcile(connection: &mut Connection, stats: bool) -> Result<(), String> {
    let (tables, indexes, synced, late) = if stats {
        (
            STATS_TABLES,
            [STATS_INDEXES, &[STATS_QUEUE_INDEX]].concat(),
            STATS_SYNCED,
            STATS_LATE_COLUMNS,
        )
    } else {
        (
            DATA_TABLES,
            DATA_INDEXES.to_vec(),
            DATA_SYNCED,
            DATA_LATE_COLUMNS,
        )
    };

    for statement in tables {
        connection
            .execute_batch(statement)
            .map_err(|error| format!("create missing table: {error}"))?;
    }
    for (table, column, kind) in late {
        add_column_if_missing(connection, table, column, kind)?;
    }
    for table in synced {
        add_column_if_missing(connection, table, "hlc", "INTEGER")?;
        add_column_if_missing(connection, table, "dirty", "INTEGER NOT NULL DEFAULT 1")?;
        let statement = format!("CREATE INDEX IF NOT EXISTS idx_{table}_dirty ON {table}(dirty)");
        connection
            .execute_batch(&statement)
            .map_err(|error| format!("create dirty index: {error}"))?;
    }
    for statement in indexes {
        connection
            .execute_batch(statement)
            .map_err(|error| format!("create missing index: {error}"))?;
    }

    // Schema only. The ladder's row rewrites (uid and songs_json backfills, the
    // skip pruning, the audius purge) belong to their own versions: repeating
    // them on every open would delete rows a synced device still has.
    Ok(())
}

fn add_column_if_missing(
    connection: &Connection,
    table: &str,
    column: &str,
    kind: &str,
) -> Result<(), String> {
    let exists: i64 = connection
        .query_row(
            &format!("SELECT COUNT(*) FROM pragma_table_info('{table}') WHERE name = ?1"),
            [column],
            |row| row.get(0),
        )
        .map_err(|error| format!("inspect {table}: {error}"))?;
    if exists > 0 {
        return Ok(());
    }
    connection
        .execute_batch(&format!("ALTER TABLE {table} ADD COLUMN {column} {kind}"))
        .map_err(|error| format!("add {table}.{column}: {error}"))
}

/// A play event's identity columns, as read back for the uid backfill.
type PlayEventIdentity = (i64, Option<String>, Option<String>, Option<String>);

/// Stable ids for play events written before sync existed.
///
/// Deterministic, so re-running produces the same ids: the first 32 hex digits
/// of sha256(session_id | song_filename | ordinal), where ordinal counts rows
/// sharing that pair in timestamp order.
fn backfill_play_event_uids(connection: &mut Connection) -> Result<(), String> {
    use sha2::{Digest, Sha256};

    let rows: Vec<PlayEventIdentity> = {
        let mut statement = connection
            .prepare(
                "SELECT id, uid, session_id, song_filename FROM playevent \
                 ORDER BY timestamp ASC, id ASC",
            )
            .map_err(|error| format!("select play events: {error}"))?;
        let rows = statement
            .query_map([], |row| {
                Ok((row.get(0)?, row.get(1)?, row.get(2)?, row.get(3)?))
            })
            .map_err(|error| format!("read play events: {error}"))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|error| format!("read play events: {error}"))?;
        rows
    };

    let mut counters: HashMap<String, u64> = HashMap::new();
    for (id, uid, session, song) in rows {
        let session = session.unwrap_or_default();
        let song = song.unwrap_or_default();
        let group = format!("{session}\u{0}{song}");
        let ordinal = counters.entry(group).or_insert(0);
        let current = *ordinal;
        *ordinal += 1;
        if uid.is_some() {
            continue;
        }
        let mut hasher = Sha256::new();
        hasher.update(format!("{session}|{song}|{current}").as_bytes());
        let digest = hasher
            .finalize()
            .iter()
            .map(|byte| format!("{byte:02x}"))
            .collect::<String>();
        connection
            .execute(
                "UPDATE playevent SET uid = ?1 WHERE id = ?2",
                rusqlite::params![&digest[..32], id],
            )
            .map_err(|error| format!("backfill uid: {error}"))?;
    }
    Ok(())
}

/// Mirrors each saved queue's song list into `songs_json`, which is the row a
/// sync payload carries.
fn backfill_snapshot_songs(connection: &mut Connection) -> Result<(), String> {
    let snapshots: Vec<(String, Option<String>)> = {
        let mut statement = connection
            .prepare("SELECT id, songs_json FROM queue_snapshot")
            .map_err(|error| format!("select snapshots: {error}"))?;
        let rows = statement
            .query_map([], |row| Ok((row.get(0)?, row.get(1)?)))
            .map_err(|error| format!("read snapshots: {error}"))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|error| format!("read snapshots: {error}"))?;
        rows
    };
    for (id, songs_json) in snapshots {
        if songs_json.is_some() {
            continue;
        }
        let songs: Vec<String> = {
            let mut statement = connection
                .prepare(
                    "SELECT song_filename FROM queue_snapshot_song \
                     WHERE snapshot_id = ?1 ORDER BY position ASC",
                )
                .map_err(|error| format!("select snapshot songs: {error}"))?;
            let songs = statement
                .query_map([&id], |row| row.get(0))
                .map_err(|error| format!("read snapshot songs: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("read snapshot songs: {error}"))?;
            songs
        };
        let encoded =
            serde_json::to_string(&songs).map_err(|error| format!("encode songs: {error}"))?;
        connection
            .execute(
                "UPDATE queue_snapshot SET songs_json = ?1 WHERE id = ?2",
                rusqlite::params![encoded, id],
            )
            .map_err(|error| format!("backfill songs_json: {error}"))?;
    }
    Ok(())
}

fn query(payload: &Value) -> Result<Value, String> {
    let sql = payload
        .get("sql")
        .and_then(|value| value.as_str())
        .ok_or_else(|| "db query needs sql".to_string())?;
    let args = arguments(payload)?;
    with(payload, |connection| {
        let mut statement = connection
            .prepare(sql)
            .map_err(|error| format!("prepare query: {error}"))?;
        let names: Vec<String> = statement
            .column_names()
            .iter()
            .map(|name| (*name).to_string())
            .collect();
        let mut rows = statement
            .query(rusqlite::params_from_iter(args.iter()))
            .map_err(|error| format!("run query: {error}"))?;
        let mut out = Vec::new();
        loop {
            let row = rows.next().map_err(|error| format!("read row: {error}"))?;
            let Some(row) = row else { break };
            let mut map = Map::with_capacity(names.len());
            for (index, name) in names.iter().enumerate() {
                let value = row
                    .get::<_, SqlValue>(index)
                    .map_err(|error| format!("read column {name}: {error}"))?;
                map.insert(name.clone(), to_json(value));
            }
            out.push(Value::Object(map));
        }
        Ok(json!({ "rows": out }))
    })
}

fn execute(payload: &Value) -> Result<Value, String> {
    let sql = payload
        .get("sql")
        .and_then(|value| value.as_str())
        .ok_or_else(|| "db execute needs sql".to_string())?;
    let args = arguments(payload)?;
    with(payload, |connection| {
        let mut statement = connection
            .prepare(sql)
            .map_err(|error| format!("prepare statement: {error}"))?;
        let changes = statement
            .execute(rusqlite::params_from_iter(args.iter()))
            .map_err(|error| format!("run statement: {error}"))?;
        Ok(json!({
            "changes": changes,
            "id": connection.last_insert_rowid(),
        }))
    })
}

fn batch(payload: &Value) -> Result<Value, String> {
    let operations = payload
        .get("ops")
        .and_then(|value| value.as_array())
        .ok_or_else(|| "db batch needs ops".to_string())?;
    let continue_on_error = payload
        .get("continueOnError")
        .and_then(|value| value.as_bool())
        .unwrap_or(false);
    let wants_results = !payload
        .get("noResult")
        .and_then(|value| value.as_bool())
        .unwrap_or(false);
    with(payload, |connection| {
        // A batch inside an open transaction is already covered by it; SQLite
        // has no nested BEGIN.
        let nested = !connection.is_autocommit();
        let transaction = if nested {
            None
        } else {
            Some(
                connection
                    .unchecked_transaction()
                    .map_err(|error| format!("begin batch: {error}"))?,
            )
        };
        let mut results: Vec<Value> = Vec::with_capacity(operations.len());
        let mut failure: Option<String> = None;
        for operation in operations {
            let sql = operation
                .get("sql")
                .and_then(|value| value.as_str())
                .ok_or_else(|| "batch op needs sql".to_string())?;
            let args = arguments(operation)?;
            let outcome = match transaction.as_ref() {
                Some(transaction) => transaction
                    .execute(sql, rusqlite::params_from_iter(args.iter()))
                    .map(|changes| (changes, transaction.last_insert_rowid())),
                None => connection
                    .execute(sql, rusqlite::params_from_iter(args.iter()))
                    .map(|changes| (changes, connection.last_insert_rowid())),
            };
            match outcome {
                Ok((changes, last_id)) => {
                    if wants_results {
                        results.push(json!({
                            "changes": changes,
                            "id": last_id,
                        }));
                    }
                }
                Err(error) => {
                    let message = format!("batch statement failed: {error}");
                    if !continue_on_error {
                        return Err(message);
                    }
                    failure = Some(message);
                }
            }
        }
        if let Some(transaction) = transaction {
            transaction
                .commit()
                .map_err(|error| format!("commit batch: {error}"))?;
        }
        Ok(json!({ "results": results, "error": failure }))
    })
}

/// The three filename lists the app treats as user intent.
///
/// They share one statement shape and one stamp/tombstone rule, so a client
/// should not be able to invent a fourth variant. `now` is the wall clock and
/// `hlc` the hybrid logical clock: both come from the caller because only the
/// app knows its clock position.
fn user_list(payload: &Value) -> Result<Value, String> {
    let kind = payload
        .get("kind")
        .and_then(Value::as_str)
        .ok_or_else(|| "user_list needs a kind".to_string())?;
    let (table, time_column, entity) = match kind {
        "favorite" => ("favorite", "added_at", "favorites"),
        "suggestless" => ("suggestless", "added_at", "suggestless"),
        "hidden" => ("hidden", "hidden_at", "hidden"),
        other => return Err(format!("unknown user list {other}")),
    };
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");

    with(payload, |connection| {
        if op == "list" {
            let mut statement = connection
                .prepare(&format!("SELECT filename FROM {table}"))
                .map_err(|error| format!("list {table}: {error}"))?;
            let items = statement
                .query_map([], |row| row.get::<_, String>(0))
                .map_err(|error| format!("list {table}: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("list {table}: {error}"))?;
            return Ok(json!({ "items": items }));
        }

        let hlc = payload
            .get("hlc")
            .and_then(Value::as_i64)
            .unwrap_or_default();
        let now = payload
            .get("now")
            .and_then(Value::as_f64)
            .unwrap_or_default();
        match op {
            "add" => {
                let filename = required_filename(payload, table, op)?;
                in_transaction(connection, |connection| {
                    connection
                        .execute(
                            &format!(
                                "INSERT OR REPLACE INTO {table} (filename, {time_column}, hlc, dirty) VALUES (?1, ?2, ?3, 1)"
                            ),
                            rusqlite::params![filename, now, hlc],
                        )
                        .map_err(|error| format!("add {table}: {error}"))?;
                    connection
                        .execute(
                            "DELETE FROM sync_tombstone WHERE entity = ?1 AND key = ?2",
                            rusqlite::params![entity, filename],
                        )
                        .map_err(|error| format!("clear tombstone: {error}"))?;
                    Ok(json!({ "changed": 1 }))
                })
            }
            "remove" => {
                let filename = required_filename(payload, table, op)?;
                in_transaction(connection, |connection| {
                    let changed = connection
                        .execute(
                            &format!("DELETE FROM {table} WHERE filename = ?1"),
                            rusqlite::params![filename],
                        )
                        .map_err(|error| format!("remove {table}: {error}"))?;
                    connection
                        .execute(
                            "INSERT OR REPLACE INTO sync_tombstone (entity, key, hlc, dirty) VALUES (?1, ?2, ?3, 1)",
                            rusqlite::params![entity, filename, hlc],
                        )
                        .map_err(|error| format!("tombstone {table}: {error}"))?;
                    Ok(json!({ "changed": changed }))
                })
            }
            "set" => {
                let filenames: Vec<String> = payload
                    .get("filenames")
                    .and_then(Value::as_array)
                    .map(|values| {
                        values
                            .iter()
                            .filter_map(Value::as_str)
                            .map(str::to_owned)
                            .collect()
                    })
                    .unwrap_or_default();
                in_transaction(connection, |connection| {
                    connection
                        .execute(&format!("DELETE FROM {table}"), [])
                        .map_err(|error| format!("clear {table}: {error}"))?;
                    let mut statement = connection
                        .prepare(&format!(
                            "INSERT OR REPLACE INTO {table} (filename, {time_column}, hlc, dirty) VALUES (?1, ?2, ?3, 1)"
                        ))
                        .map_err(|error| format!("set {table}: {error}"))?;
                    for filename in &filenames {
                        statement
                            .execute(rusqlite::params![filename, now, hlc])
                            .map_err(|error| format!("set {table}: {error}"))?;
                    }
                    Ok(json!({ "changed": filenames.len() }))
                })
            }
            other => Err(format!("unknown user_list op {other}")),
        }
    })
}

fn required_filename<'a>(payload: &'a Value, table: &str, op: &str) -> Result<&'a str, String> {
    payload
        .get("filename")
        .and_then(Value::as_str)
        .ok_or_else(|| format!("user_list {op} on {table} needs a filename"))
}

/// Runs `body` between BEGIN and COMMIT, rolling back on failure so a partial
/// list mutation cannot leave a table and its tombstones disagreeing.
fn in_transaction<T>(
    connection: &mut Connection,
    body: impl FnOnce(&Connection) -> Result<T, String>,
) -> Result<T, String> {
    connection
        .execute_batch("BEGIN")
        .map_err(|error| format!("begin: {error}"))?;
    match body(connection) {
        Ok(value) => {
            connection
                .execute_batch("COMMIT")
                .map_err(|error| format!("commit: {error}"))?;
            Ok(value)
        }
        Err(error) => {
            let _ = connection.execute_batch("ROLLBACK");
            Err(error)
        }
    }
}

/// Negative cover cache: filenames already probed and found to have no art.
fn cover_miss(payload: &Value) -> Result<Value, String> {
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");
    with(payload, |connection| match op {
        "list" => {
            let mut statement = connection
                .prepare("SELECT filename, file_mtime FROM cover_miss")
                .map_err(|error| format!("cover_miss list: {error}"))?;
            let items = statement
                .query_map([], |row| {
                    Ok(json!({
                        "filename": row.get::<_, String>(0)?,
                        "file_mtime": row.get::<_, Option<f64>>(1)?.unwrap_or(0.0),
                    }))
                })
                .map_err(|error| format!("cover_miss list: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("cover_miss list: {error}"))?;
            Ok(json!({ "items": items }))
        }
        "mark" => {
            let filename = required_filename(payload, "cover_miss", op)?;
            let mtime = payload
                .get("file_mtime")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            let now = payload
                .get("now")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            connection
                .execute(
                    "INSERT OR REPLACE INTO cover_miss (filename, file_mtime, checked_at) VALUES (?1, ?2, ?3)",
                    rusqlite::params![filename, mtime, now],
                )
                .map_err(|error| format!("cover_miss mark: {error}"))?;
            Ok(json!({ "changed": 1 }))
        }
        "clear" => {
            let filename = required_filename(payload, "cover_miss", op)?;
            let changed = connection
                .execute(
                    "DELETE FROM cover_miss WHERE filename = ?1",
                    rusqlite::params![filename],
                )
                .map_err(|error| format!("cover_miss clear: {error}"))?;
            Ok(json!({ "changed": changed }))
        }
        "clear_all" => {
            let changed = connection
                .execute("DELETE FROM cover_miss", [])
                .map_err(|error| format!("cover_miss clear_all: {error}"))?;
            Ok(json!({ "changed": changed }))
        }
        "clear_many" => {
            let filenames = string_list(payload, "filenames");
            in_transaction(connection, |connection| {
                let mut changed = 0usize;
                for chunk in filenames.chunks(500) {
                    let placeholders = vec!["?"; chunk.len()].join(", ");
                    let sql = format!("DELETE FROM cover_miss WHERE filename IN ({placeholders})");
                    let mut statement = connection
                        .prepare(&sql)
                        .map_err(|error| format!("cover_miss clear_many: {error}"))?;
                    changed += statement
                        .execute(rusqlite::params_from_iter(chunk.iter()))
                        .map_err(|error| format!("cover_miss clear_many: {error}"))?;
                }
                Ok(json!({ "changed": changed }))
            })
        }
        other => Err(format!("unknown cover_miss op {other}")),
    })
}

/// The per-song lyrics timing offset, quantized on the way in by the same rule
/// the tuning UI uses.
fn lyrics_offset(payload: &Value) -> Result<Value, String> {
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("get");
    with(payload, |connection| match op {
        "get" => {
            let filename = required_filename(payload, "lyrics_timing_offset", op)?;
            let offset: Option<f64> = connection
                .query_row(
                    "SELECT offset_seconds FROM lyrics_timing_offset WHERE filename = ?1 LIMIT 1",
                    rusqlite::params![filename],
                    |row| row.get(0),
                )
                .optional()
                .map_err(|error| format!("lyrics_offset get: {error}"))?;
            Ok(json!({ "offset": offset.unwrap_or(0.0) }))
        }
        "set" => {
            let filename = required_filename(payload, "lyrics_timing_offset", op)?;
            let seconds = payload
                .get("seconds")
                .and_then(Value::as_f64)
                .ok_or_else(|| "lyrics_offset set needs seconds".to_string())?;
            let quantized = crate::lyrics_view::quantize_offset(
                seconds,
                crate::lyrics_view::TIMING_QUANTIZE_STEP,
            );
            connection
                .execute(
                    "INSERT OR REPLACE INTO lyrics_timing_offset (filename, offset_seconds) VALUES (?1, ?2)",
                    rusqlite::params![filename, quantized],
                )
                .map_err(|error| format!("lyrics_offset set: {error}"))?;
            Ok(json!({ "offset": quantized }))
        }
        other => Err(format!("unknown lyrics_offset op {other}")),
    })
}

/// Artist and album artwork rows. Keys are normalized on read (trim + lower) so
/// every client looks them up the same way, and deletes match the same rule the
/// UI uses while tombstoning the stored spelling.
fn art(payload: &Value) -> Result<Value, String> {
    let kind = payload
        .get("kind")
        .and_then(Value::as_str)
        .ok_or_else(|| "art needs a kind".to_string())?;
    let (table, key_column) = match kind {
        "artist" => ("artist_art", "artist_name"),
        "album" => ("album_art", "album_key"),
        other => return Err(format!("unknown art kind {other}")),
    };
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");

    with(payload, |connection| match op {
        "list" => {
            let mut statement = connection
                .prepare(&format!("SELECT {key_column}, local_path FROM {table}"))
                .map_err(|error| format!("art list: {error}"))?;
            let rows = statement
                .query_map([], |row| {
                    Ok((row.get::<_, String>(0)?, row.get::<_, Option<String>>(1)?))
                })
                .map_err(|error| format!("art list: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("art list: {error}"))?;
            let mut items = Vec::new();
            for (key, path) in rows {
                let Some(path) = path else { continue };
                if key.trim().is_empty() || path.is_empty() {
                    continue;
                }
                items.push(json!({ "key": key.trim().to_lowercase(), "path": path }));
            }
            Ok(json!({ "items": items }))
        }
        "save" => {
            let hlc = payload
                .get("hlc")
                .and_then(Value::as_i64)
                .unwrap_or_default();
            let now = payload
                .get("now")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            let image_url = payload.get("image_url").and_then(Value::as_str);
            let source = payload.get("source").and_then(Value::as_str);
            let local_path = payload
                .get("local_path")
                .and_then(Value::as_str)
                .ok_or_else(|| "art save needs a local_path".to_string())?;
            if kind == "artist" {
                let name = payload
                    .get("name")
                    .and_then(Value::as_str)
                    .ok_or_else(|| "art save needs a name".to_string())?;
                let name = name.trim();
                in_transaction(connection, |connection| {
                    connection
                        .execute(
                            "INSERT OR REPLACE INTO artist_art (artist_name, image_url, local_path, source, updated_at, hlc, dirty) VALUES (?1, ?2, ?3, ?4, ?5, ?6, 1)",
                            rusqlite::params![name, image_url, local_path, source, now, hlc],
                        )
                        .map_err(|error| format!("art save: {error}"))?;
                    connection
                        .execute(
                            "DELETE FROM sync_tombstone WHERE entity = ?1 AND key = ?2",
                            rusqlite::params!["artist_art", name],
                        )
                        .map_err(|error| format!("clear tombstone: {error}"))?;
                    Ok(json!({ "changed": 1 }))
                })
            } else {
                let key = payload
                    .get("key")
                    .and_then(Value::as_str)
                    .ok_or_else(|| "art save needs a key".to_string())?;
                let album_name = payload.get("album_name").and_then(Value::as_str);
                let artist_name = payload.get("artist_name").and_then(Value::as_str);
                in_transaction(connection, |connection| {
                    connection
                        .execute(
                            "INSERT OR REPLACE INTO album_art (album_key, album_name, artist_name, image_url, local_path, source, updated_at, hlc, dirty) VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, 1)",
                            rusqlite::params![key, album_name, artist_name, image_url, local_path, source, now, hlc],
                        )
                        .map_err(|error| format!("art save: {error}"))?;
                    connection
                        .execute(
                            "DELETE FROM sync_tombstone WHERE entity = ?1 AND key = ?2",
                            rusqlite::params!["album_art", key],
                        )
                        .map_err(|error| format!("clear tombstone: {error}"))?;
                    Ok(json!({ "changed": 1 }))
                })
            }
        }
        "delete" => {
            let hlc = payload
                .get("hlc")
                .and_then(Value::as_i64)
                .unwrap_or_default();
            let raw = match kind {
                "artist" => payload.get("name").and_then(Value::as_str),
                _ => payload.get("key").and_then(Value::as_str),
            }
            .ok_or_else(|| "art delete needs a name or key".to_string())?;
            let needle = if kind == "artist" {
                raw.trim().to_lowercase()
            } else {
                raw.to_lowercase()
            };
            let match_sql = if kind == "artist" {
                "LOWER(TRIM(artist_name)) = ?1"
            } else {
                "LOWER(album_key) = ?1"
            };
            in_transaction(connection, |connection| {
                let stored: Vec<String> = {
                    let mut statement = connection
                        .prepare(&format!(
                            "SELECT {key_column} FROM {table} WHERE {match_sql}"
                        ))
                        .map_err(|error| format!("art delete: {error}"))?;
                    let rows = statement
                        .query_map(rusqlite::params![needle], |row| row.get::<_, String>(0))
                        .map_err(|error| format!("art delete: {error}"))?;
                    rows.collect::<Result<Vec<_>, _>>()
                        .map_err(|error| format!("art delete: {error}"))?
                };
                let changed = connection
                    .execute(
                        &format!("DELETE FROM {table} WHERE {match_sql}"),
                        rusqlite::params![needle],
                    )
                    .map_err(|error| format!("art delete: {error}"))?;
                for key in &stored {
                    connection
                        .execute(
                            "INSERT OR REPLACE INTO sync_tombstone (entity, key, hlc, dirty) VALUES (?1, ?2, ?3, 1)",
                            rusqlite::params![table, key, hlc],
                        )
                        .map_err(|error| format!("tombstone {table}: {error}"))?;
                }
                Ok(json!({ "changed": changed }))
            })
        }
        "clear" => {
            let changed = connection
                .execute(&format!("DELETE FROM {table}"), [])
                .map_err(|error| format!("art clear: {error}"))?;
            Ok(json!({ "changed": changed }))
        }
        other => Err(format!("unknown art op {other}")),
    })
}

fn string_list(payload: &Value, field: &str) -> Vec<String> {
    payload
        .get(field)
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default()
}

fn arguments(payload: &Value) -> Result<Vec<SqlValue>, String> {
    let Some(list) = payload.get("args").and_then(|value| value.as_array()) else {
        return Ok(Vec::new());
    };
    Ok(list.iter().map(to_sql).collect())
}

fn to_sql(value: &Value) -> SqlValue {
    match value {
        Value::Null => SqlValue::Null,
        Value::Bool(flag) => SqlValue::Integer(i64::from(*flag)),
        Value::Number(number) => {
            if let Some(integer) = number.as_i64() {
                SqlValue::Integer(integer)
            } else {
                SqlValue::Real(number.as_f64().unwrap_or_default())
            }
        }
        Value::String(text) => SqlValue::Text(text.clone()),
        // Bytes arrive as a base64 envelope; a plain list of byte values is
        // accepted too, since that is what JSON encoding a typed list makes.
        Value::Object(map) => match map.get("$blob").and_then(|value| value.as_str()) {
            Some(encoded) => SqlValue::Blob(base64_decode(encoded).unwrap_or_default()),
            None => SqlValue::Text(value.to_string()),
        },
        Value::Array(items) => {
            let bytes: Option<Vec<u8>> = items
                .iter()
                .map(|item| item.as_u64().and_then(|byte| u8::try_from(byte).ok()))
                .collect();
            match bytes {
                Some(bytes) => SqlValue::Blob(bytes),
                None => SqlValue::Text(value.to_string()),
            }
        }
    }
}

fn to_json(value: SqlValue) -> Value {
    match value {
        SqlValue::Null => Value::Null,
        SqlValue::Integer(number) => json!(number),
        SqlValue::Real(number) => json!(number),
        SqlValue::Text(text) => json!(text),
        SqlValue::Blob(bytes) => {
            let encoded = base64_encode(&bytes);
            json!({ "$blob": encoded })
        }
    }
}

fn base64_encode(bytes: &[u8]) -> String {
    use base64::Engine;
    base64::engine::general_purpose::STANDARD.encode(bytes)
}

fn base64_decode(text: &str) -> Option<Vec<u8>> {
    use base64::Engine;
    base64::engine::general_purpose::STANDARD.decode(text).ok()
}
