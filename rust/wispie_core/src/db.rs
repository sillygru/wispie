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

pub(crate) mod files;
mod identity;
mod maintenance;
mod playback;
mod restore;
mod search_index;
mod song_files;
mod sync_store;

use std::collections::HashMap;
use std::path::Path;
use std::sync::atomic::{AtomicU64, Ordering};
use std::sync::{Mutex, OnceLock};

use rusqlite::types::Value as SqlValue;
use rusqlite::{Connection, OpenFlags, OptionalExtension};
use serde_json::{json, Map, Value};

use crate::emitter::{Emit, Emitter};

pub const STATS_VERSION: i64 = 6;
pub const DATA_VERSION: i64 = 13;

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

const FILTERED_LIBRARY_FILE_TABLE: &str = "
    CREATE TABLE IF NOT EXISTS filtered_library_file (
      filename TEXT PRIMARY KEY,
      url TEXT NOT NULL,
      mtime REAL
    )";

const DATA_TABLES: &[&str] = &[
    FILTERED_LIBRARY_FILE_TABLE,
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

/// Converts a stored SQLite value to JSON without coercing its type, so callers
/// see exactly what the column holds (the snapshot importer relies on it).
fn json_from_ref(value: rusqlite::types::ValueRef<'_>) -> Value {
    use rusqlite::types::ValueRef;
    match value {
        ValueRef::Null => Value::Null,
        ValueRef::Integer(number) => json!(number),
        ValueRef::Real(number) => json!(number),
        ValueRef::Text(bytes) => Value::String(String::from_utf8_lossy(bytes).into_owned()),
        ValueRef::Blob(bytes) => Value::String(String::from_utf8_lossy(bytes).into_owned()),
    }
}

pub fn run(payload: &Value, emitter: &Emitter) -> Result<(), String> {
    let action = payload
        .get("action")
        .and_then(|value| value.as_str())
        .ok_or_else(|| "db needs an action".to_string())?;
    let reply = match action {
        "open" => open(payload)?,
        "file" => files::run(payload)?,
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
        "playback" => playback::run(payload)?,
        "rename_library_files" => rename_library_files(payload)?,
        "song_files" => song_files::run(payload)?,
        "search_index" => search_index::run(payload)?,
        "restore" => restore::run(payload)?,
        "maintenance" => maintenance::run(payload)?,
        "identity" => identity::run(payload)?,
        "sync_store" => sync_store::run(payload)?,
        "query" => query(payload)?,
        "execute" => execute(payload)?,
        "batch" => batch(payload)?,
        "user_list" => user_list(payload)?,
        "cover_miss" => cover_miss(payload)?,
        "lyrics_offset" => lyrics_offset(payload)?,
        "art" => art(payload)?,
        "playlist_op" => playlist_op(payload)?,
        "youtube_link_op" => youtube_link_op(payload)?,
        "merged_op" => merged_op(payload)?,
        "recommendation_op" => recommendation_op(payload)?,
        "translated_lyrics_op" => translated_lyrics_op(payload)?,
        "queue_snapshot_op" => queue_snapshot_op(payload)?,
        "song_op" => song_op(payload)?,
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

fn rename_library_files(payload: &Value) -> Result<Value, String> {
    let id = connection_id(payload)?;
    let stats_id = payload["stats_id"]
        .as_u64()
        .ok_or("missing stats connection")?;
    if id == stats_id {
        return Err("rename needs distinct library and stats connections".into());
    }
    let renames = song_files::parse_renames(payload)?;
    let hlc = payload["hlc"].as_i64().ok_or("missing rename clock")?;
    let now = payload["now"].as_f64().unwrap_or_default();
    let completion: Option<RenameCompletion> = payload
        .get("completion")
        .map(|value| serde_json::from_value(value.clone()))
        .transpose()
        .map_err(|error| error.to_string())?;
    if let Some(completion) = &completion {
        restore_rename_sidecars(&completion.recover);
    }
    {
        let mut connections = lock();
        let [Some(data), Some(stats)] = connections.get_disjoint_mut([&id, &stats_id]) else {
            return Err("rename database connection is closed".into());
        };
        if payload.get("songs").is_none() {
            apply_renames(data, stats, &renames, hlc, now)?;
        } else {
            in_transaction(data, |data| {
                song_files::apply_data_rows(data, &renames, hlc, now)?;
                song_write_batch_on(payload, data)?;
                Ok(())
            })?;
            song_files::apply_stats(stats, &renames, hlc)?;
        }
    }
    let warning = completion
        .as_ref()
        .map(|completion| finish_renames(completion, &renames))
        .transpose()?
        .flatten();
    Ok(json!({"index_warning": warning}))
}

#[derive(serde::Deserialize)]
struct RenameCompletion {
    directory: std::path::PathBuf,
    index: std::path::PathBuf,
    intents: Vec<crate::file_workflow::PendingRename>,
    #[serde(default)]
    recover: Vec<crate::file_workflow::PendingRename>,
}

fn restore_rename_sidecars(entries: &[crate::file_workflow::PendingRename]) {
    for entry in entries {
        crate::file_workflow::rename_sidecars(Path::new(&entry.url), &entry.sidecars);
    }
}

fn finish_renames(
    completion: &RenameCompletion,
    renames: &[(&str, &str)],
) -> Result<Option<String>, String> {
    let update_index = || -> Result<(), String> {
        if renames.is_empty() || !completion.index.is_file() {
            return Ok(());
        }
        let mut index =
            Connection::open_with_flags(&completion.index, OpenFlags::SQLITE_OPEN_READ_WRITE)
                .map_err(|error| error.to_string())?;
        index
            .busy_timeout(std::time::Duration::from_secs(5))
            .map_err(|error| error.to_string())?;
        in_transaction(&mut index, |db| search_index::rename_rows(db, renames))
    };
    // The search index is derived. A stale row is repaired by the next scan.
    let index_warning = update_index().err();
    crate::file_workflow::acknowledge_renames(&completion.directory, &completion.intents)?;
    Ok(index_warning)
}

fn apply_renames(
    data: &mut Connection,
    stats: &mut Connection,
    renames: &[(&str, &str)],
    hlc: i64,
    now: f64,
) -> Result<(), String> {
    // Each database commits independently. The rename journal makes replay safe.
    song_files::apply_data(data, renames, hlc, now)?;
    song_files::apply_stats(stats, renames, hlc)
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
    let schema = payload.get("schema").and_then(Value::as_str);
    let stats = match schema {
        Some("stats") => Some(true),
        Some("userdata") => Some(false),
        Some("search_index") | None => None,
        Some(other) => return Err(format!("unknown schema {other}")),
    };
    let read_only = payload
        .get("read_only")
        .and_then(|value| value.as_bool())
        .unwrap_or(false);
    let base_hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();
    let (connection, version, fresh) =
        open_connection(Path::new(path), schema, stats, read_only, base_hlc)?;
    let id = NEXT_ID.fetch_add(1, Ordering::Relaxed);
    lock().insert(id, connection);
    Ok(json!({ "id": id, "version": version, "fresh": fresh }))
}

fn open_connection(
    path: &Path,
    schema: Option<&str>,
    stats: Option<bool>,
    read_only: bool,
    base_hlc: i64,
) -> Result<(Connection, i64, bool), String> {
    if !read_only {
        if let Some(parent) = path.parent() {
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
        .map_err(|error| format!("open {}: {error}", path.display()))?;
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

    if schema == Some("search_index") && !read_only {
        search_index::create(&connection)?;
    }
    let Some(stats) = stats.filter(|_| !read_only) else {
        return Ok((connection, 0, false));
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

    Ok((connection, target, fresh))
}

pub(crate) fn count_backup_playevents(path: &Path) -> i64 {
    open_connection(path, None, None, true, 0)
        .and_then(|(connection, _, _)| maintenance::table_count(&connection, "playevent", true))
        .unwrap_or_default()
}

pub(crate) fn inspect_backup_tables(path: &Path, tables: &[&str]) -> Vec<bool> {
    let connection = open_connection(path, None, None, true, 0)
        .ok()
        .map(|(connection, _, _)| connection);
    tables
        .iter()
        .map(|table| {
            connection.as_ref().is_some_and(|connection| {
                maintenance::table_count(connection, table, false).is_ok_and(|count| count == 1)
            })
        })
        .collect()
}

/// A library opened with the same migrations and connection settings as Flutter.
pub struct Library {
    data: Connection,
    stats: Connection,
}

/// A local track in the library database.
pub struct LibraryTrack {
    pub filename: String,
    pub title: String,
    pub artist: String,
    pub album: String,
    pub path: String,
    pub cover: Option<String>,
    pub duration_ms: Option<i64>,
}

#[derive(serde::Serialize)]
pub struct LibraryPlaylistSong {
    pub song_filename: String,
    pub added_at: f64,
}

#[derive(serde::Serialize)]
pub struct LibraryPlaylist {
    pub id: String,
    pub name: String,
    pub description: Option<String>,
    pub is_recommendation: i64,
    pub created_at: f64,
    pub updated_at: f64,
    pub songs: Vec<LibraryPlaylistSong>,
}

#[derive(Clone, Copy)]
pub enum LibraryList {
    Favorites,
    SuggestLess,
    Hidden,
}

impl LibraryList {
    fn fields(self) -> (&'static str, &'static str, &'static str) {
        match self {
            Self::Favorites => ("favorite", "added_at", "favorites"),
            Self::SuggestLess => ("suggestless", "added_at", "suggestless"),
            Self::Hidden => ("hidden", "hidden_at", "hidden"),
        }
    }
}

impl Library {
    pub fn open(data_path: &Path, stats_path: &Path, base_hlc: i64) -> Result<Self, String> {
        let (data, _, _) =
            open_connection(data_path, Some("userdata"), Some(false), false, base_hlc)?;
        let (stats, _, _) =
            open_connection(stats_path, Some("stats"), Some(true), false, base_hlc)?;
        Ok(Self { data, stats })
    }

    pub fn tracks(&self) -> Result<Vec<LibraryTrack>, String> {
        let mut statement = self
            .data
            .prepare(ALL_SONGS)
            .map_err(|error| error.to_string())?;
        let tracks = statement
            .query_map([], |row| {
                Ok(LibraryTrack {
                    filename: row.get("filename")?,
                    title: row.get::<_, Option<String>>("title")?.unwrap_or_default(),
                    artist: row.get::<_, Option<String>>("artist")?.unwrap_or_default(),
                    album: row.get::<_, Option<String>>("album")?.unwrap_or_default(),
                    path: row.get::<_, Option<String>>("url")?.unwrap_or_default(),
                    cover: row.get("cover_url")?,
                    duration_ms: row.get("duration_ms")?,
                })
            })
            .map_err(|error| error.to_string())?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|error| error.to_string())?;
        Ok(tracks)
    }

    pub fn playlists(&self) -> Result<Vec<LibraryPlaylist>, String> {
        library_playlists(&self.data)
    }

    pub fn save_playlist(&mut self, playlist: &LibraryPlaylist, hlc: i64) -> Result<(), String> {
        playlist_save(&json!({"playlist": playlist, "hlc": hlc}), &mut self.data).map(|_| ())
    }

    pub fn filenames(&self, list: LibraryList) -> Result<Vec<String>, String> {
        list_filenames(&self.data, list)
    }

    pub fn apply_renames(
        &mut self,
        renames: &[(&str, &str)],
        hlc: i64,
        now: f64,
    ) -> Result<(), String> {
        apply_renames(&mut self.data, &mut self.stats, renames, hlc, now)
    }

    pub fn recover_renames(
        &mut self,
        directory: &Path,
        index: &Path,
        hlc: i64,
        now: f64,
    ) -> Result<Option<String>, String> {
        let intents = crate::file_workflow::read_rename_journal(directory)?;
        let recover = intents
            .iter()
            .filter(|entry| Path::new(&entry.url).is_file())
            .cloned()
            .collect();
        let completion = RenameCompletion {
            directory: directory.into(),
            index: index.into(),
            intents,
            recover,
        };
        restore_rename_sidecars(&completion.recover);
        let renames: Vec<_> = completion
            .recover
            .iter()
            .map(|entry| (entry.from.as_str(), entry.to.as_str()))
            .collect();
        if !renames.is_empty() {
            self.apply_renames(&renames, hlc, now)?;
        }
        finish_renames(&completion, &renames)
    }

    pub fn schema_versions(&self) -> Result<(i64, i64), String> {
        fn version(connection: &Connection) -> rusqlite::Result<i64> {
            connection.query_row("PRAGMA user_version", [], |row| row.get(0))
        }
        Ok((
            version(&self.data).map_err(|error| error.to_string())?,
            version(&self.stats).map_err(|error| error.to_string())?,
        ))
    }
}

const ALL_SONGS: &str = "SELECT * FROM song";

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
    if from < 13 {
        connection
            .execute_batch(FILTERED_LIBRARY_FILE_TABLE)
            .map_err(|error| format!("create filtered library files: {error}"))?;
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
fn backfill_play_event_uids(connection: &Connection) -> Result<(), String> {
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
        Ok(json!({"rows": read_rows(connection, sql, rusqlite::params_from_iter(args))?}))
    })
}

fn read_rows(
    connection: &Connection,
    sql: &str,
    params: impl rusqlite::Params,
) -> Result<Vec<Value>, String> {
    let mut sql = connection
        .prepare(sql)
        .map_err(|error| format!("prepare query: {error}"))?;
    let rows = sql
        .query_map(params, |row| {
            let mut object = Map::new();
            for (index, name) in row.as_ref().column_names().iter().enumerate() {
                object.insert((*name).to_string(), to_json(row.get(index)?));
            }
            Ok(Value::Object(object))
        })
        .map_err(|error| format!("run query: {error}"))?;
    rows.collect::<Result<Vec<_>, _>>()
        .map_err(|error| format!("read row: {error}"))
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
    let list = match kind {
        "favorite" => LibraryList::Favorites,
        "suggestless" => LibraryList::SuggestLess,
        "hidden" => LibraryList::Hidden,
        other => return Err(format!("unknown user list {other}")),
    };
    let (table, time_column, entity) = list.fields();
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");

    with(payload, |connection| {
        if op == "list" {
            return Ok(json!({ "items": list_filenames(connection, list)? }));
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

fn list_filenames(connection: &Connection, list: LibraryList) -> Result<Vec<String>, String> {
    let (table, _, _) = list.fields();
    let mut statement = connection
        .prepare(&format!("SELECT filename FROM {table}"))
        .map_err(|error| format!("list {table}: {error}"))?;
    let items = statement
        .query_map([], |row| row.get::<_, String>(0))
        .map_err(|error| format!("list {table}: {error}"))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|error| format!("list {table}: {error}"))?;
    Ok(items)
}

fn library_playlists(connection: &Connection) -> Result<Vec<LibraryPlaylist>, String> {
    let mut items = connection
        .prepare("SELECT id, name, description, is_recommendation, created_at, updated_at                   FROM playlist ORDER BY updated_at DESC")
        .map_err(|error| format!("playlist list: {error}"))?;
    let mut playlists = items
        .query_map([], |row| {
            Ok(LibraryPlaylist {
                id: row.get(0)?,
                name: row.get::<_, Option<String>>(1)?.unwrap_or_default(),
                description: row.get(2)?,
                is_recommendation: row.get::<_, Option<i64>>(3)?.unwrap_or_default(),
                created_at: row.get::<_, Option<f64>>(4)?.unwrap_or_default(),
                updated_at: row.get::<_, Option<f64>>(5)?.unwrap_or_default(),
                songs: Vec::new(),
            })
        })
        .map_err(|error| format!("playlist list: {error}"))?
        .collect::<Result<Vec<_>, _>>()
        .map_err(|error| format!("playlist list: {error}"))?;
    let mut songs = connection
        .prepare("SELECT song_filename, added_at FROM playlist_song                   WHERE playlist_id = ?1 ORDER BY added_at ASC")
        .map_err(|error| format!("playlist songs: {error}"))?;
    for playlist in &mut playlists {
        playlist.songs = songs
            .query_map([&playlist.id], |row| {
                Ok(LibraryPlaylistSong {
                    song_filename: row.get(0)?,
                    added_at: row.get::<_, Option<f64>>(1)?.unwrap_or_default(),
                })
            })
            .map_err(|error| format!("playlist songs: {error}"))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|error| format!("playlist songs: {error}"))?;
    }
    Ok(playlists)
}

/// Playlist rows and their membership.
///
/// A save is a full replacement: every song that disappeared is tombstoned so
/// it cannot resurrect from another device, and every surviving song clears its
/// tombstone. The caller supplies the clock, as with `user_list`.
fn playlist_op(payload: &Value) -> Result<Value, String> {
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");
    match op {
        "list" => with(payload, |connection| {
            Ok(json!({ "playlists": library_playlists(connection)? }))
        }),
        "save" => with(payload, |connection| playlist_save(payload, connection)),
        "delete" => with(payload, |connection| playlist_delete(payload, connection)),
        "add_songs" => with(payload, |connection| {
            playlist_add_songs(payload, connection)
        }),
        "remove_songs" => with(payload, |connection| {
            playlist_remove_songs(payload, connection)
        }),
        "rename" => with(payload, |connection| playlist_rename(payload, connection)),
        "validate" => with(payload, |connection| playlist_validate(payload, connection)),
        other => Err(format!("unknown playlist op {other}")),
    }
}

fn playlist_save(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let playlist = payload
        .get("playlist")
        .ok_or_else(|| "playlist save needs a playlist".to_string())?;
    let id = playlist
        .get("id")
        .and_then(Value::as_str)
        .ok_or_else(|| "playlist save needs an id".to_string())?
        .to_string();
    let name = playlist
        .get("name")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();
    let description = playlist
        .get("description")
        .and_then(Value::as_str)
        .map(str::to_owned);
    let recommendation = playlist
        .get("is_recommendation")
        .and_then(Value::as_i64)
        .unwrap_or(0);
    let created = playlist
        .get("created_at")
        .and_then(Value::as_f64)
        .unwrap_or(0.0);
    let updated = playlist
        .get("updated_at")
        .and_then(Value::as_f64)
        .unwrap_or(0.0);
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();
    let songs: Vec<(String, f64)> = playlist
        .get("songs")
        .and_then(Value::as_array)
        .map(|rows| {
            rows.iter()
                .map(|row| {
                    (
                        row.get("song_filename")
                            .and_then(Value::as_str)
                            .unwrap_or("")
                            .to_string(),
                        row.get("added_at").and_then(Value::as_f64).unwrap_or(0.0),
                    )
                })
                .collect()
        })
        .unwrap_or_default();

    in_transaction(connection, |connection| {
        connection
            .execute(
                "INSERT OR REPLACE INTO playlist \
                 (id, name, description, is_recommendation, created_at, updated_at, hlc, dirty) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 1)",
                rusqlite::params![id, name, description, recommendation, created, updated, hlc],
            )
            .map_err(|error| format!("save playlist: {error}"))?;

        let existing: Vec<String> = {
            let mut statement = connection
                .prepare("SELECT song_filename FROM playlist_song WHERE playlist_id = ?1")
                .map_err(|error| format!("existing songs: {error}"))?;
            let collected = statement
                .query_map([&id], |row| row.get::<_, String>(0))
                .map_err(|error| format!("existing songs: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("existing songs: {error}"))?;
            collected
        };
        for filename in &existing {
            if !songs.iter().any(|(kept, _)| kept == filename) {
                tombstone(
                    connection,
                    "playlist_songs",
                    &format!("{id}\u{0}{filename}"),
                    hlc,
                )?;
            }
        }

        connection
            .execute("DELETE FROM playlist_song WHERE playlist_id = ?1", [&id])
            .map_err(|error| format!("clear playlist songs: {error}"))?;
        for (filename, added_at) in &songs {
            connection
                .execute(
                    "INSERT INTO playlist_song (playlist_id, song_filename, added_at, hlc, dirty) \
                     VALUES (?1, ?2, ?3, ?4, 1)",
                    rusqlite::params![id, filename, added_at, hlc],
                )
                .map_err(|error| format!("insert playlist song: {error}"))?;
            connection
                .execute(
                    "DELETE FROM sync_tombstone WHERE entity = 'playlist_songs' AND key = ?1",
                    [format!("{id}\u{0}{filename}")],
                )
                .map_err(|error| format!("clear playlist song tombstone: {error}"))?;
        }
        Ok(json!({ "saved": true }))
    })
}

fn playlist_delete(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let id = payload
        .get("playlistId")
        .and_then(Value::as_str)
        .ok_or_else(|| "playlist delete needs a playlistId".to_string())?
        .to_string();
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();

    in_transaction(connection, |connection| {
        let songs: Vec<String> = {
            let mut statement = connection
                .prepare("SELECT song_filename FROM playlist_song WHERE playlist_id = ?1")
                .map_err(|error| format!("delete playlist songs: {error}"))?;
            let collected = statement
                .query_map([&id], |row| row.get::<_, String>(0))
                .map_err(|error| format!("delete playlist songs: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("delete playlist songs: {error}"))?;
            collected
        };
        connection
            .execute("DELETE FROM playlist_song WHERE playlist_id = ?1", [&id])
            .map_err(|error| format!("delete playlist songs: {error}"))?;
        connection
            .execute("DELETE FROM playlist WHERE id = ?1", [&id])
            .map_err(|error| format!("delete playlist: {error}"))?;
        connection
            .execute(
                "DELETE FROM youtube_playlist_link WHERE local_playlist_id = ?1",
                [&id],
            )
            .map_err(|error| format!("delete playlist links: {error}"))?;
        tombstone(connection, "playlists", &id, hlc)?;
        for filename in &songs {
            tombstone(
                connection,
                "playlist_songs",
                &format!("{id}\u{0}{filename}"),
                hlc,
            )?;
        }
        Ok(json!({ "deleted": true }))
    })
}

fn playlist_add_songs(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let id = payload
        .get("playlistId")
        .and_then(Value::as_str)
        .ok_or_else(|| "playlist add needs a playlistId".to_string())?
        .to_string();
    let filenames: Vec<String> = payload
        .get("filenames")
        .and_then(Value::as_array)
        .map(|rows| {
            rows.iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default();
    let now = payload
        .get("now")
        .and_then(Value::as_f64)
        .unwrap_or_default();
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();
    // A single add leaves the playlist untouched when the song is already in it;
    // a bulk add always refreshes the timestamp so the UI stops calling it stale.
    let touch_always = payload
        .get("touchAlways")
        .and_then(Value::as_bool)
        .unwrap_or(false);

    in_transaction(connection, |connection| {
        let mut added = 0usize;
        for filename in &filenames {
            let exists: bool = {
                let mut statement = connection
                    .prepare(
                        "SELECT 1 FROM playlist_song \
                         WHERE playlist_id = ?1 AND song_filename = ?2",
                    )
                    .map_err(|error| format!("playlist song exists: {error}"))?;
                let found = statement
                    .query_row(rusqlite::params![id, filename], |_| Ok(()))
                    .optional()
                    .map_err(|error| format!("playlist song exists: {error}"))?;
                found.is_some()
            };
            if exists {
                continue;
            }
            connection
                .execute(
                    "INSERT INTO playlist_song \
                     (playlist_id, song_filename, added_at, hlc, dirty) \
                     VALUES (?1, ?2, ?3, ?4, 1)",
                    rusqlite::params![id, filename, now, hlc],
                )
                .map_err(|error| format!("add playlist song: {error}"))?;
            connection
                .execute(
                    "DELETE FROM sync_tombstone WHERE entity = 'playlist_songs' AND key = ?1",
                    [format!("{id}\u{0}{filename}")],
                )
                .map_err(|error| format!("clear playlist song tombstone: {error}"))?;
            added += 1;
        }
        if touch_always || added > 0 {
            connection
                .execute(
                    "UPDATE playlist SET updated_at = ?1, hlc = ?2, dirty = 1 WHERE id = ?3",
                    rusqlite::params![now, hlc, id],
                )
                .map_err(|error| format!("touch playlist: {error}"))?;
        }
        Ok(json!({ "added": added }))
    })
}

fn playlist_remove_songs(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let id = payload
        .get("playlistId")
        .and_then(Value::as_str)
        .ok_or_else(|| "playlist remove needs a playlistId".to_string())?
        .to_string();
    let filenames: Vec<String> = payload
        .get("filenames")
        .and_then(Value::as_array)
        .map(|rows| {
            rows.iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default();
    let now = payload
        .get("now")
        .and_then(Value::as_f64)
        .unwrap_or_default();
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();

    in_transaction(connection, |connection| {
        for filename in &filenames {
            connection
                .execute(
                    "DELETE FROM playlist_song WHERE playlist_id = ?1 AND song_filename = ?2",
                    rusqlite::params![id, filename],
                )
                .map_err(|error| format!("remove playlist song: {error}"))?;
            tombstone(
                connection,
                "playlist_songs",
                &format!("{id}\u{0}{filename}"),
                hlc,
            )?;
        }
        connection
            .execute(
                "UPDATE playlist SET updated_at = ?1, hlc = ?2, dirty = 1 WHERE id = ?3",
                rusqlite::params![now, hlc, id],
            )
            .map_err(|error| format!("touch playlist: {error}"))?;
        Ok(json!({ "removed": filenames.len() }))
    })
}

fn playlist_rename(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let id = payload
        .get("playlistId")
        .and_then(Value::as_str)
        .ok_or_else(|| "playlist rename needs a playlistId".to_string())?;
    let name = payload
        .get("name")
        .and_then(Value::as_str)
        .ok_or_else(|| "playlist rename needs a name".to_string())?;
    let now = payload
        .get("now")
        .and_then(Value::as_f64)
        .unwrap_or_default();
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();

    connection
        .execute(
            "UPDATE playlist SET name = ?1, updated_at = ?2, hlc = ?3, dirty = 1 WHERE id = ?4",
            rusqlite::params![name, now, hlc, id],
        )
        .map_err(|error| format!("rename playlist: {error}"))?;
    Ok(json!({ "renamed": true }))
}

/// A merge group only ever groups queue candidates: members keep their own
/// favourites, play counts and playlist membership.
fn merged_op(payload: &Value) -> Result<Value, String> {
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");
    match op {
        "list" => with(payload, |connection| {
            let priorities: HashMap<String, Option<String>> = {
                let mut statement = connection
                    .prepare("SELECT id, priority_filename FROM merged_song_group")
                    .map_err(|error| format!("merged groups: {error}"))?;
                let collected = statement
                    .query_map([], |row| {
                        Ok((row.get::<_, String>(0)?, row.get::<_, Option<String>>(1)?))
                    })
                    .map_err(|error| format!("merged groups: {error}"))?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(|error| format!("merged groups: {error}"))?;
                collected.into_iter().collect()
            };
            let rows: Vec<(String, String)> = {
                let mut statement = connection
                    .prepare(
                        "SELECT g.id AS group_id, m.filename FROM merged_song_group g \
                         JOIN merged_song m ON g.id = m.group_id \
                         ORDER BY g.id, m.added_at",
                    )
                    .map_err(|error| format!("merged members: {error}"))?;
                let collected = statement
                    .query_map([], |row| {
                        Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
                    })
                    .map_err(|error| format!("merged members: {error}"))?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(|error| format!("merged members: {error}"))?;
                collected
            };

            // Group in first-seen order, which is the order the JOIN returns.
            let mut order: Vec<String> = Vec::new();
            let mut members: HashMap<String, Vec<String>> = HashMap::new();
            for (group, filename) in rows {
                if !members.contains_key(&group) {
                    order.push(group.clone());
                }
                members.entry(group).or_default().push(filename);
            }
            let groups: Vec<Value> = order
                .into_iter()
                .filter_map(|group| {
                    let filenames = members.remove(&group)?;
                    if filenames.len() < 2 {
                        return None;
                    }
                    Some(json!({
                        "id": group,
                        "priority_filename": priorities.get(&group).cloned().flatten(),
                        "filenames": filenames,
                    }))
                })
                .collect();
            Ok(json!({ "groups": groups }))
        }),
        "priority" => with(payload, |connection| {
            let group = text_field(payload, "groupId")?;
            let found = {
                let mut statement = connection
                    .prepare(
                        "SELECT priority_filename FROM merged_song_group WHERE id = ?1 LIMIT 1",
                    )
                    .map_err(|error| format!("merged priority: {error}"))?;
                statement
                    .query_row([&group], |row| row.get::<_, Option<String>>(0))
                    .optional()
                    .map_err(|error| format!("merged priority: {error}"))?
            };
            Ok(json!({ "priority_filename": found.flatten() }))
        }),
        "group_id" => with(payload, |connection| {
            let filename = text_field(payload, "filename")?;
            let found = {
                let mut statement = connection
                    .prepare("SELECT group_id FROM merged_song WHERE filename = ?1 LIMIT 1")
                    .map_err(|error| format!("merged group id: {error}"))?;
                statement
                    .query_row([&filename], |row| row.get::<_, Option<String>>(0))
                    .optional()
                    .map_err(|error| format!("merged group id: {error}"))?
            };
            Ok(json!({ "group_id": found.flatten() }))
        }),
        "siblings" => {
            with(payload, |connection| {
                let filename = text_field(payload, "filename")?;
                let group = {
                    let mut statement = connection
                        .prepare("SELECT group_id FROM merged_song WHERE filename = ?1 LIMIT 1")
                        .map_err(|error| format!("merged siblings: {error}"))?;
                    statement
                        .query_row([&filename], |row| row.get::<_, Option<String>>(0))
                        .optional()
                        .map_err(|error| format!("merged siblings: {error}"))?
                        .flatten()
                };
                let Some(group) = group else {
                    return Ok(json!({ "filenames": [] }));
                };
                let filenames: Vec<String> = {
                    let mut statement = connection
                    .prepare("SELECT filename FROM merged_song WHERE group_id = ?1 AND filename != ?2")
                    .map_err(|error| format!("merged siblings: {error}"))?;
                    let collected = statement
                        .query_map(rusqlite::params![group, filename], |row| {
                            row.get::<_, String>(0)
                        })
                        .map_err(|error| format!("merged siblings: {error}"))?
                        .collect::<Result<Vec<_>, _>>()
                        .map_err(|error| format!("merged siblings: {error}"))?;
                    collected
                };
                Ok(json!({ "filenames": filenames }))
            })
        }
        "set_priority" => with(payload, |connection| {
            let group = text_field(payload, "groupId")?;
            let priority = payload
                .get("priorityFilename")
                .and_then(Value::as_str)
                .map(str::to_owned);
            connection
                .execute(
                    "UPDATE merged_song_group SET priority_filename = ?1 WHERE id = ?2",
                    rusqlite::params![priority, group],
                )
                .map_err(|error| format!("set merged priority: {error}"))?;
            Ok(json!({ "updated": true }))
        }),
        "create" => with(payload, |connection| {
            let group = text_field(payload, "groupId")?;
            merged_create(payload, connection, group)
        }),
        "add_songs" => with(payload, |connection| merged_add_songs(payload, connection)),
        "remove_song" => with(payload, |connection| {
            merged_remove_song(payload, connection)
        }),
        "delete" => with(payload, |connection| merged_delete(payload, connection)),
        "set_all" => with(payload, |connection| merged_set_all(payload, connection)),
        other => Err(format!("unknown merged op {other}")),
    }
}

fn text_field<'a>(payload: &'a Value, key: &str) -> Result<&'a str, String> {
    payload
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| format!("missing {key}"))
}

fn filename_list(payload: &Value) -> Vec<String> {
    payload
        .get("filenames")
        .and_then(Value::as_array)
        .map(|rows| {
            rows.iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default()
}

fn merged_create(
    payload: &Value,
    connection: &mut Connection,
    group: &str,
) -> Result<Value, String> {
    let filenames = filename_list(payload);
    if filenames.len() < 2 {
        return Err("need at least 2 songs to merge".to_string());
    }
    let priority = payload
        .get("priorityFilename")
        .and_then(Value::as_str)
        .filter(|name| filenames.iter().any(|filename| filename == name))
        .map(str::to_owned);
    let now = payload
        .get("now")
        .and_then(Value::as_f64)
        .unwrap_or_default();
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();

    in_transaction(connection, |connection| {
        connection
            .execute(
                "INSERT INTO merged_song_group (id, priority_filename, created_at, hlc, dirty) \
                 VALUES (?1, ?2, ?3, ?4, 1)",
                rusqlite::params![group, priority, now, hlc],
            )
            .map_err(|error| format!("create merged group: {error}"))?;
        clear_tombstone(connection, "merged_groups", group)?;
        for filename in &filenames {
            connection
                .execute(
                    "INSERT OR REPLACE INTO merged_song \
                     (filename, group_id, added_at, hlc, dirty) VALUES (?1, ?2, ?3, ?4, 1)",
                    rusqlite::params![filename, group, now, hlc],
                )
                .map_err(|error| format!("add merged song: {error}"))?;
            clear_tombstone(connection, "merged_songs", filename)?;
        }
        cleanup_single_song_groups(connection, hlc)?;
        Ok(json!({ "groupId": group }))
    })
}

fn merged_add_songs(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let group = text_field(payload, "groupId")?.to_string();
    let filenames = filename_list(payload);
    let now = payload
        .get("now")
        .and_then(Value::as_f64)
        .unwrap_or_default();
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();

    in_transaction(connection, |connection| {
        for filename in &filenames {
            connection
                .execute(
                    "INSERT OR REPLACE INTO merged_song \
                     (filename, group_id, added_at, hlc, dirty) VALUES (?1, ?2, ?3, ?4, 1)",
                    rusqlite::params![filename, group, now, hlc],
                )
                .map_err(|error| format!("add merged song: {error}"))?;
            clear_tombstone(connection, "merged_songs", filename)?;
        }
        cleanup_single_song_groups(connection, hlc)?;
        Ok(json!({ "added": filenames.len() }))
    })
}

fn merged_remove_song(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let filename = text_field(payload, "filename")?.to_string();
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();

    in_transaction(connection, |connection| {
        connection
            .execute("DELETE FROM merged_song WHERE filename = ?1", [&filename])
            .map_err(|error| format!("remove merged song: {error}"))?;
        tombstone(connection, "merged_songs", &filename, hlc)?;
        cleanup_single_song_groups(connection, hlc)?;
        Ok(json!({ "removed": true }))
    })
}

fn merged_delete(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let group = text_field(payload, "groupId")?.to_string();
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();

    in_transaction(connection, |connection| {
        let members: Vec<String> = {
            let mut statement = connection
                .prepare("SELECT filename FROM merged_song WHERE group_id = ?1")
                .map_err(|error| format!("delete merged group: {error}"))?;
            let collected = statement
                .query_map([&group], |row| row.get::<_, String>(0))
                .map_err(|error| format!("delete merged group: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("delete merged group: {error}"))?;
            collected
        };
        connection
            .execute("DELETE FROM merged_song WHERE group_id = ?1", [&group])
            .map_err(|error| format!("delete merged songs: {error}"))?;
        connection
            .execute("DELETE FROM merged_song_group WHERE id = ?1", [&group])
            .map_err(|error| format!("delete merged group: {error}"))?;
        tombstone(connection, "merged_groups", &group, hlc)?;
        for filename in &members {
            tombstone(connection, "merged_songs", filename, hlc)?;
        }
        Ok(json!({ "deleted": true }))
    })
}

fn merged_set_all(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let groups = payload
        .get("groups")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let now = payload
        .get("now")
        .and_then(Value::as_f64)
        .unwrap_or_default();
    let hlc = payload
        .get("hlc")
        .and_then(Value::as_i64)
        .unwrap_or_default();

    in_transaction(connection, |connection| {
        connection
            .execute("DELETE FROM merged_song", [])
            .map_err(|error| format!("clear merged songs: {error}"))?;
        connection
            .execute("DELETE FROM merged_song_group", [])
            .map_err(|error| format!("clear merged groups: {error}"))?;
        for entry in &groups {
            let filenames = filename_list(entry);
            if filenames.len() < 2 {
                continue;
            }
            let group = entry
                .get("id")
                .and_then(Value::as_str)
                .ok_or_else(|| "merged group needs an id".to_string())?;
            let priority = entry
                .get("priority_filename")
                .and_then(Value::as_str)
                .map(str::to_owned);
            connection
                .execute(
                    "INSERT INTO merged_song_group (id, priority_filename, created_at, hlc, dirty) \
                     VALUES (?1, ?2, ?3, ?4, 1)",
                    rusqlite::params![group, priority, now, hlc],
                )
                .map_err(|error| format!("set merged group: {error}"))?;
            for filename in &filenames {
                connection
                    .execute(
                        "INSERT INTO merged_song (filename, group_id, added_at, hlc, dirty) \
                         VALUES (?1, ?2, ?3, ?4, 1)",
                        rusqlite::params![filename, group, now, hlc],
                    )
                    .map_err(|error| format!("set merged song: {error}"))?;
            }
        }
        Ok(json!({ "groups": groups.len() }))
    })
}

fn cleanup_single_song_groups(connection: &Connection, hlc: i64) -> Result<(), String> {
    let thin_groups: Vec<String> = {
        let mut statement = connection
            .prepare("SELECT group_id FROM merged_song GROUP BY group_id HAVING COUNT(*) < 2")
            .map_err(|error| format!("thin merged groups: {error}"))?;
        let collected = statement
            .query_map([], |row| row.get::<_, String>(0))
            .map_err(|error| format!("thin merged groups: {error}"))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|error| format!("thin merged groups: {error}"))?;
        collected
    };
    for group in thin_groups {
        let members: Vec<String> = {
            let mut statement = connection
                .prepare("SELECT filename FROM merged_song WHERE group_id = ?1")
                .map_err(|error| format!("thin merged members: {error}"))?;
            let collected = statement
                .query_map([&group], |row| row.get::<_, String>(0))
                .map_err(|error| format!("thin merged members: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("thin merged members: {error}"))?;
            collected
        };
        connection
            .execute("DELETE FROM merged_song WHERE group_id = ?1", [&group])
            .map_err(|error| format!("thin merged songs: {error}"))?;
        connection
            .execute("DELETE FROM merged_song_group WHERE id = ?1", [&group])
            .map_err(|error| format!("thin merged group: {error}"))?;
        tombstone(connection, "merged_groups", &group, hlc)?;
        for filename in &members {
            tombstone(connection, "merged_songs", filename, hlc)?;
        }
    }
    connection
        .execute(
            "DELETE FROM merged_song_group WHERE id NOT IN (\
             SELECT DISTINCT group_id FROM merged_song WHERE group_id IS NOT NULL)",
            [],
        )
        .map_err(|error| format!("orphan merged groups: {error}"))?;
    Ok(())
}

fn recommendation_op(payload: &Value) -> Result<Value, String> {
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");
    match op {
        "preferences" => with(payload, |connection| {
            let mut statement = connection
                .prepare("SELECT id, custom_title, is_pinned FROM recommendation_preference")
                .map_err(|error| format!("recommendation preferences: {error}"))?;
            let collected = statement
                .query_map([], |row| {
                    Ok(json!({
                        "id": row.get::<_, String>(0)?,
                        "custom_title": row.get::<_, Option<String>>(1)?,
                        "is_pinned": row.get::<_, Option<i64>>(2)?.unwrap_or(0),
                    }))
                })
                .map_err(|error| format!("recommendation preferences: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("recommendation preferences: {error}"))?;
            Ok(json!({ "preferences": collected }))
        }),
        "save_preference" => with(payload, |connection| {
            // `id` is reserved by the request envelope for the connection.
            let id = text_field(payload, "recommendationId")?;
            let now = payload
                .get("now")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            let custom_title = payload
                .get("customTitle")
                .and_then(Value::as_str)
                .map(str::to_owned);
            let pinned = payload
                .get("isPinned")
                .and_then(Value::as_bool)
                .map(|value| if value { 1i64 } else { 0i64 });
            let exists: bool = {
                let mut statement = connection
                    .prepare("SELECT 1 FROM recommendation_preference WHERE id = ?1")
                    .map_err(|error| format!("recommendation preference: {error}"))?;
                statement
                    .query_row([&id], |_| Ok(()))
                    .optional()
                    .map_err(|error| format!("recommendation preference: {error}"))?
                    .is_some()
            };
            if exists {
                connection
                    .execute(
                        "UPDATE recommendation_preference SET updated_at = ?1, \
                         custom_title = COALESCE(?2, custom_title), \
                         is_pinned = COALESCE(?3, is_pinned) WHERE id = ?4",
                        rusqlite::params![now, custom_title, pinned, id],
                    )
                    .map_err(|error| format!("save recommendation preference: {error}"))?;
            } else {
                connection
                    .execute(
                        "INSERT INTO recommendation_preference (id, updated_at, custom_title, is_pinned) \
                         VALUES (?1, ?2, ?3, ?4)",
                        rusqlite::params![id, now, custom_title, pinned],
                    )
                    .map_err(|error| format!("save recommendation preference: {error}"))?;
            }
            Ok(json!({ "saved": true }))
        }),
        "removals" => with(payload, |connection| {
            let mut statement = connection
                .prepare("SELECT id FROM recommendation_removal")
                .map_err(|error| format!("recommendation removals: {error}"))?;
            let collected = statement
                .query_map([], |row| row.get::<_, String>(0))
                .map_err(|error| format!("recommendation removals: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("recommendation removals: {error}"))?;
            Ok(json!({ "ids": collected }))
        }),
        "add_removal" => with(payload, |connection| {
            let id = text_field(payload, "recommendationId")?;
            let now = payload
                .get("now")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            connection
                .execute(
                    "INSERT OR REPLACE INTO recommendation_removal (id, removed_at) VALUES (?1, ?2)",
                    rusqlite::params![id, now],
                )
                .map_err(|error| format!("add recommendation removal: {error}"))?;
            Ok(json!({ "added": true }))
        }),
        "remove_removal" => with(payload, |connection| {
            let id = text_field(payload, "recommendationId")?;
            connection
                .execute("DELETE FROM recommendation_removal WHERE id = ?1", [id])
                .map_err(|error| format!("remove recommendation removal: {error}"))?;
            Ok(json!({ "removed": true }))
        }),
        other => Err(format!("unknown recommendation op {other}")),
    }
}

/// Translations are trusted only while the source lyrics hash still matches:
/// entries written before hashing existed must never be paired with new lyrics.
fn translated_lyrics_op(payload: &Value) -> Result<Value, String> {
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("get");
    match op {
        "get" => with(payload, |connection| {
            let filename = text_field(payload, "filename")?;
            let target = text_field(payload, "targetLang")?.to_lowercase();
            let source_hash = payload
                .get("sourceContent")
                .and_then(Value::as_str)
                .map(lyrics_hash);
            let row = {
                let mut statement = connection
                    .prepare(
                        "SELECT translated_content, source_hash FROM translated_lyrics \
                         WHERE filename = ?1 AND target_lang = ?2 LIMIT 1",
                    )
                    .map_err(|error| format!("translated lyrics: {error}"))?;
                statement
                    .query_row(rusqlite::params![filename, target], |row| {
                        Ok((
                            row.get::<_, Option<String>>(0)?,
                            row.get::<_, Option<String>>(1)?,
                        ))
                    })
                    .optional()
                    .map_err(|error| format!("translated lyrics: {error}"))?
            };
            let Some((content, stored_hash)) = row else {
                return Ok(json!({ "content": Value::Null }));
            };
            if let Some(expected) = source_hash {
                if stored_hash.as_deref() != Some(expected.as_str()) {
                    return Ok(json!({ "content": Value::Null }));
                }
            }
            Ok(json!({ "content": content }))
        }),
        "save" => with(payload, |connection| {
            let filename = text_field(payload, "filename")?;
            let target = text_field(payload, "targetLang")?.to_lowercase();
            let content = text_field(payload, "content")?;
            let source_hash = payload
                .get("sourceContent")
                .and_then(Value::as_str)
                .map(lyrics_hash);
            let now = payload
                .get("now")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            connection
                .execute(
                    "INSERT OR REPLACE INTO translated_lyrics \
                     (filename, target_lang, translated_content, source_hash, updated_at) \
                     VALUES (?1, ?2, ?3, ?4, ?5)",
                    rusqlite::params![filename, target, content, source_hash, now],
                )
                .map_err(|error| format!("save translated lyrics: {error}"))?;
            Ok(json!({ "saved": true }))
        }),
        "delete" => with(payload, |connection| {
            let filename = text_field(payload, "filename")?;
            match payload.get("targetLang").and_then(Value::as_str) {
                Some(target) => {
                    connection
                        .execute(
                            "DELETE FROM translated_lyrics WHERE filename = ?1 AND target_lang = ?2",
                            rusqlite::params![filename, target.to_lowercase()],
                        )
                        .map_err(|error| format!("delete translated lyrics: {error}"))?;
                }
                None => {
                    connection
                        .execute(
                            "DELETE FROM translated_lyrics WHERE filename = ?1",
                            [filename],
                        )
                        .map_err(|error| format!("delete translated lyrics: {error}"))?;
                }
            }
            Ok(json!({ "deleted": true }))
        }),
        other => Err(format!("unknown translation op {other}")),
    }
}

fn lyrics_hash(content: &str) -> String {
    use sha2::{Digest, Sha256};
    let mut hasher = Sha256::new();
    hasher.update(content.as_bytes());
    format!("{:x}", hasher.finalize())
}

fn playlist_validate(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    let _ = payload;
    let rows = {
        let mut statement = connection
            .prepare(
                "SELECT id, name, is_recommendation, created_at, updated_at \
                 FROM playlist WHERE is_recommendation = 1",
            )
            .map_err(|error| format!("validate playlists: {error}"))?;
        let collected = statement
            .query_map([], |row| {
                Ok((
                    row.get_ref(0).is_ok_and(|value| {
                        matches!(value, rusqlite::types::ValueRef::Text(bytes) if !bytes.is_empty())
                    }),
                    row.get_ref(1).is_ok_and(|value| {
                        matches!(value, rusqlite::types::ValueRef::Text(_))
                    }),
                    matches!(
                        row.get_ref(2),
                        Ok(rusqlite::types::ValueRef::Integer(_))
                    ),
                    matches!(
                        row.get_ref(3),
                        Ok(rusqlite::types::ValueRef::Real(_))
                            | Ok(rusqlite::types::ValueRef::Integer(_))
                    ),
                    matches!(
                        row.get_ref(4),
                        Ok(rusqlite::types::ValueRef::Real(_))
                            | Ok(rusqlite::types::ValueRef::Integer(_))
                    ),
                    row.get::<_, Option<String>>(0)?,
                ))
            })
            .map_err(|error| format!("validate playlists: {error}"))?
            .collect::<Result<Vec<_>, _>>()
            .map_err(|error| format!("validate playlists: {error}"))?;
        collected
    };
    if rows.is_empty() {
        return Ok(json!({ "valid": false }));
    }
    for (id_ok, name_ok, rec_ok, created_ok, updated_ok, id) in rows {
        if !(id_ok && name_ok && rec_ok && created_ok && updated_ok) {
            return Ok(json!({ "valid": false }));
        }
        let Some(id) = id else {
            return Ok(json!({ "valid": false }));
        };
        let songs = {
            let mut statement = connection
                .prepare("SELECT song_filename, added_at FROM playlist_song WHERE playlist_id = ?1")
                .map_err(|error| format!("validate playlist songs: {error}"))?;
            let collected = statement
                .query_map([&id], |row| {
                    Ok((
                        row.get_ref(0).is_ok_and(|value| {
                            matches!(value, rusqlite::types::ValueRef::Text(bytes) if !bytes.is_empty())
                        }),
                        matches!(
                            row.get_ref(1),
                            Ok(rusqlite::types::ValueRef::Real(_))
                                | Ok(rusqlite::types::ValueRef::Integer(_))
                        ),
                    ))
                })
                .map_err(|error| format!("validate playlist songs: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("validate playlist songs: {error}"))?;
            collected
        };
        if songs
            .iter()
            .any(|(name_ok, added_ok)| !name_ok || !added_ok)
        {
            return Ok(json!({ "valid": false }));
        }
    }
    Ok(json!({ "valid": true }))
}

/// Queue history. Replaying a queue is meant to move its entry to the top, so a
/// save first drops older snapshots with the same source and songs, and history
/// reads collapse entries that ended up with identical fingerprints.
fn queue_snapshot_op(payload: &Value) -> Result<Value, String> {
    const RETAINED: i64 = 50;
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");
    match op {
        "save" => with(payload, |connection| {
            let id = text_field(payload, "snapshotId")?.to_string();
            let name = payload
                .get("name")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string();
            let created_at = payload
                .get("createdAt")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            let source = payload
                .get("source")
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string();
            let filenames = filename_list(payload);
            let songs_json = serde_json::to_string(&filenames)
                .map_err(|error| format!("snapshot songs json: {error}"))?;
            let hlc = payload
                .get("hlc")
                .and_then(Value::as_i64)
                .unwrap_or_default();

            in_transaction(connection, |connection| {
                let dupes: Vec<String> = {
                    let mut statement = connection
                        .prepare(
                            "SELECT id FROM queue_snapshot \
                             WHERE source = ?1 AND songs_json = ?2 AND id != ?3",
                        )
                        .map_err(|error| format!("snapshot dupes: {error}"))?;
                    let collected = statement
                        .query_map(rusqlite::params![source, songs_json, id], |row| {
                            row.get::<_, String>(0)
                        })
                        .map_err(|error| format!("snapshot dupes: {error}"))?
                        .collect::<Result<Vec<_>, _>>()
                        .map_err(|error| format!("snapshot dupes: {error}"))?;
                    collected
                };
                for dupe in &dupes {
                    connection
                        .execute(
                            "DELETE FROM queue_snapshot_song WHERE snapshot_id = ?1",
                            [dupe],
                        )
                        .map_err(|error| format!("drop dupe snapshot songs: {error}"))?;
                    connection
                        .execute("DELETE FROM queue_snapshot WHERE id = ?1", [dupe])
                        .map_err(|error| format!("drop dupe snapshot: {error}"))?;
                    tombstone(connection, "queue_snapshots", dupe, hlc)?;
                }
                connection
                    .execute(
                        "INSERT OR REPLACE INTO queue_snapshot \
                         (id, name, created_at, source, song_count, songs_json, hlc, dirty) \
                         VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, 1)",
                        rusqlite::params![
                            id,
                            name,
                            created_at,
                            source,
                            filenames.len() as i64,
                            songs_json,
                            hlc
                        ],
                    )
                    .map_err(|error| format!("save snapshot: {error}"))?;
                clear_tombstone(connection, "queue_snapshots", &id)?;
                connection
                    .execute(
                        "DELETE FROM queue_snapshot_song WHERE snapshot_id = ?1",
                        [&id],
                    )
                    .map_err(|error| format!("clear snapshot songs: {error}"))?;
                for (position, filename) in filenames.iter().enumerate() {
                    connection
                        .execute(
                            "INSERT INTO queue_snapshot_song \
                             (snapshot_id, song_filename, position) VALUES (?1, ?2, ?3)",
                            rusqlite::params![id, filename, position as i64],
                        )
                        .map_err(|error| format!("save snapshot song: {error}"))?;
                }
                Ok(json!({ "saved": true }))
            })
        }),
        "update_songs" => with(payload, |connection| {
            let id = text_field(payload, "snapshotId")?.to_string();
            let filenames = filename_list(payload);
            let songs_json = serde_json::to_string(&filenames)
                .map_err(|error| format!("snapshot songs json: {error}"))?;
            let hlc = payload
                .get("hlc")
                .and_then(Value::as_i64)
                .unwrap_or_default();

            in_transaction(connection, |connection| {
                let stored: Option<Option<String>> = {
                    let mut statement = connection
                        .prepare("SELECT songs_json FROM queue_snapshot WHERE id = ?1 LIMIT 1")
                        .map_err(|error| format!("snapshot lookup: {error}"))?;
                    statement
                        .query_row([&id], |row| row.get::<_, Option<String>>(0))
                        .optional()
                        .map_err(|error| format!("snapshot lookup: {error}"))?
                };
                let Some(stored) = stored else {
                    return Ok(json!({ "exists": false }));
                };
                if stored.as_deref() == Some(songs_json.as_str()) {
                    return Ok(json!({ "exists": true, "changed": false }));
                }
                connection
                    .execute(
                        "DELETE FROM queue_snapshot_song WHERE snapshot_id = ?1",
                        [&id],
                    )
                    .map_err(|error| format!("clear snapshot songs: {error}"))?;
                for (position, filename) in filenames.iter().enumerate() {
                    connection
                        .execute(
                            "INSERT INTO queue_snapshot_song \
                             (snapshot_id, song_filename, position) VALUES (?1, ?2, ?3)",
                            rusqlite::params![id, filename, position as i64],
                        )
                        .map_err(|error| format!("save snapshot song: {error}"))?;
                }
                connection
                    .execute(
                        "UPDATE queue_snapshot SET song_count = ?1, songs_json = ?2, \
                         hlc = ?3, dirty = 1 WHERE id = ?4",
                        rusqlite::params![filenames.len() as i64, songs_json, hlc, id],
                    )
                    .map_err(|error| format!("update snapshot: {error}"))?;
                Ok(json!({ "exists": true, "changed": true }))
            })
        }),
        "list" => with(payload, |connection| {
            let rows = {
                let mut statement = connection
                    .prepare("SELECT * FROM queue_snapshot ORDER BY created_at DESC")
                    .map_err(|error| format!("snapshot list: {error}"))?;
                let names: Vec<String> = statement
                    .column_names()
                    .iter()
                    .map(|name| (*name).to_string())
                    .collect();
                let collected = statement
                    .query_map([], |row| {
                        let mut object = Map::new();
                        for (index, name) in names.iter().enumerate() {
                            object.insert(name.clone(), json_from_ref(row.get_ref(index)?));
                        }
                        Ok(Value::Object(object))
                    })
                    .map_err(|error| format!("snapshot list: {error}"))?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(|error| format!("snapshot list: {error}"))?;
                collected
            };
            Ok(json!({ "snapshots": rows }))
        }),
        "history" => with(payload, |connection| {
            let snapshots = {
                let mut statement = connection
                    .prepare(
                        "SELECT id, name, created_at, source FROM queue_snapshot \
                         ORDER BY created_at DESC",
                    )
                    .map_err(|error| format!("snapshot history: {error}"))?;
                let collected = statement
                    .query_map([], |row| {
                        Ok((
                            row.get::<_, String>(0)?,
                            row.get::<_, Option<String>>(1)?,
                            json_from_ref(row.get_ref(2)?),
                            row.get::<_, Option<String>>(3)?,
                        ))
                    })
                    .map_err(|error| format!("snapshot history: {error}"))?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(|error| format!("snapshot history: {error}"))?;
                collected
            };
            let members: Vec<(String, String)> = {
                let mut statement = connection
                    .prepare(
                        "SELECT snapshot_id, song_filename FROM queue_snapshot_song \
                         ORDER BY snapshot_id ASC, position ASC",
                    )
                    .map_err(|error| format!("snapshot history songs: {error}"))?;
                let collected = statement
                    .query_map([], |row| {
                        Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
                    })
                    .map_err(|error| format!("snapshot history songs: {error}"))?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(|error| format!("snapshot history songs: {error}"))?;
                collected
            };
            let mut songs: HashMap<String, Vec<String>> = HashMap::new();
            for (snapshot, filename) in members {
                songs.entry(snapshot).or_default().push(filename);
            }
            let mut seen: Vec<String> = Vec::new();
            let mut result: Vec<Value> = Vec::new();
            for (id, name, created_at, source) in snapshots {
                let filenames = songs.remove(&id).unwrap_or_default();
                let source = source.unwrap_or_else(|| "unknown".to_string());
                let mut fingerprint = source.clone();
                for filename in &filenames {
                    fingerprint.push('\u{0}');
                    fingerprint.push_str(filename);
                }
                if seen.iter().any(|entry| entry == &fingerprint) {
                    continue;
                }
                seen.push(fingerprint);
                result.push(json!({
                    "id": id,
                    "name": name,
                    "created_at": created_at,
                    "source": source,
                    "songs": filenames,
                }));
            }
            Ok(json!({ "history": result }))
        }),
        "songs" => with(payload, |connection| {
            let id = text_field(payload, "snapshotId")?;
            let filenames: Vec<String> = {
                let mut statement = connection
                    .prepare(
                        "SELECT song_filename FROM queue_snapshot_song \
                         WHERE snapshot_id = ?1 ORDER BY position ASC",
                    )
                    .map_err(|error| format!("snapshot songs: {error}"))?;
                let collected = statement
                    .query_map([&id], |row| row.get::<_, String>(0))
                    .map_err(|error| format!("snapshot songs: {error}"))?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(|error| format!("snapshot songs: {error}"))?;
                collected
            };
            Ok(json!({ "filenames": filenames }))
        }),
        "delete" => with(payload, |connection| {
            let id = text_field(payload, "snapshotId")?.to_string();
            let hlc = payload
                .get("hlc")
                .and_then(Value::as_i64)
                .unwrap_or_default();
            in_transaction(connection, |connection| {
                connection
                    .execute(
                        "DELETE FROM queue_snapshot_song WHERE snapshot_id = ?1",
                        [&id],
                    )
                    .map_err(|error| format!("delete snapshot songs: {error}"))?;
                connection
                    .execute("DELETE FROM queue_snapshot WHERE id = ?1", [&id])
                    .map_err(|error| format!("delete snapshot: {error}"))?;
                tombstone(connection, "queue_snapshots", &id, hlc)?;
                Ok(json!({ "deleted": true }))
            })
        }),
        "clear" => with(payload, |connection| {
            let hlc = payload
                .get("hlc")
                .and_then(Value::as_i64)
                .unwrap_or_default();
            in_transaction(connection, |connection| {
                let ids: Vec<String> = {
                    let mut statement = connection
                        .prepare("SELECT id FROM queue_snapshot")
                        .map_err(|error| format!("clear snapshots: {error}"))?;
                    let collected = statement
                        .query_map([], |row| row.get::<_, String>(0))
                        .map_err(|error| format!("clear snapshots: {error}"))?
                        .collect::<Result<Vec<_>, _>>()
                        .map_err(|error| format!("clear snapshots: {error}"))?;
                    collected
                };
                connection
                    .execute("DELETE FROM queue_snapshot_song", [])
                    .map_err(|error| format!("clear snapshot songs: {error}"))?;
                connection
                    .execute("DELETE FROM queue_snapshot", [])
                    .map_err(|error| format!("clear snapshot rows: {error}"))?;
                for id in &ids {
                    tombstone(connection, "queue_snapshots", id, hlc)?;
                }
                Ok(json!({ "cleared": ids.len() }))
            })
        }),
        "prune" => with(payload, |connection| {
            let hlc = payload
                .get("hlc")
                .and_then(Value::as_i64)
                .unwrap_or_default();
            in_transaction(connection, |connection| {
                let ids: Vec<String> = {
                    let mut statement = connection
                        .prepare(
                            "SELECT id FROM queue_snapshot ORDER BY created_at DESC \
                             LIMIT -1 OFFSET ?1",
                        )
                        .map_err(|error| format!("prune snapshots: {error}"))?;
                    let collected = statement
                        .query_map([RETAINED], |row| row.get::<_, String>(0))
                        .map_err(|error| format!("prune snapshots: {error}"))?
                        .collect::<Result<Vec<_>, _>>()
                        .map_err(|error| format!("prune snapshots: {error}"))?;
                    collected
                };
                for id in &ids {
                    connection
                        .execute(
                            "DELETE FROM queue_snapshot_song WHERE snapshot_id = ?1",
                            [id],
                        )
                        .map_err(|error| format!("prune snapshot songs: {error}"))?;
                    connection
                        .execute("DELETE FROM queue_snapshot WHERE id = ?1", [id])
                        .map_err(|error| format!("prune snapshot: {error}"))?;
                    tombstone(connection, "queue_snapshots", id, hlc)?;
                }
                Ok(json!({ "pruned": ids.len() }))
            })
        }),
        "export" => with(payload, |connection| {
            let snapshots: Vec<(String, Option<String>, Value, Option<String>)> = {
                let mut statement = connection
                    .prepare(
                        "SELECT id, name, created_at, source FROM queue_snapshot \
                         ORDER BY created_at DESC",
                    )
                    .map_err(|error| format!("snapshot export: {error}"))?;
                let collected = statement
                    .query_map([], |row| {
                        Ok((
                            row.get::<_, String>(0)?,
                            row.get::<_, Option<String>>(1)?,
                            json_from_ref(row.get_ref(2)?),
                            row.get::<_, Option<String>>(3)?,
                        ))
                    })
                    .map_err(|error| format!("snapshot export: {error}"))?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(|error| format!("snapshot export: {error}"))?;
                collected
            };
            let members = {
                let mut statement = connection
                    .prepare(
                        "SELECT snapshot_id, song_filename FROM queue_snapshot_song \
                         ORDER BY snapshot_id ASC, position ASC",
                    )
                    .map_err(|error| format!("snapshot export songs: {error}"))?;
                let collected = statement
                    .query_map([], |row| {
                        Ok((row.get::<_, String>(0)?, row.get::<_, String>(1)?))
                    })
                    .map_err(|error| format!("snapshot export songs: {error}"))?
                    .collect::<Result<Vec<_>, _>>()
                    .map_err(|error| format!("snapshot export songs: {error}"))?;
                collected
            };
            let mut songs: HashMap<String, Vec<String>> = HashMap::new();
            for (snapshot, filename) in members {
                songs.entry(snapshot).or_default().push(filename);
            }
            let result: Vec<Value> = snapshots
                .into_iter()
                .map(|(id, name, created_at, source)| {
                    let filenames = songs.remove(&id).unwrap_or_default();
                    json!({
                        "id": id,
                        "name": name,
                        "created_at": created_at,
                        "source": source,
                        "songs": filenames,
                    })
                })
                .collect();
            Ok(json!({ "snapshots": result }))
        }),
        "current_save" => with(payload, |connection| {
            let queue_json = text_field(payload, "queueJson")?;
            let now = payload
                .get("now")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            let hlc = payload
                .get("hlc")
                .and_then(Value::as_i64)
                .unwrap_or_default();
            connection
                .execute(
                    "INSERT OR REPLACE INTO current_queue (id, queue_json, updated_at, hlc, dirty) \
                     VALUES ('current', ?1, ?2, ?3, 1)",
                    rusqlite::params![queue_json, now, hlc],
                )
                .map_err(|error| format!("save current queue: {error}"))?;
            Ok(json!({ "saved": true }))
        }),
        "current_load" => with(payload, |connection| {
            let raw: Option<Option<String>> = {
                let mut statement = connection
                    .prepare("SELECT queue_json FROM current_queue WHERE id = 'current' LIMIT 1")
                    .map_err(|error| format!("load current queue: {error}"))?;
                statement
                    .query_row([], |row| row.get::<_, Option<String>>(0))
                    .optional()
                    .map_err(|error| format!("load current queue: {error}"))?
            };
            Ok(json!({ "queue_json": raw.flatten() }))
        }),
        other => Err(format!("unknown queue snapshot op {other}")),
    }
}

fn row_to_json(row: &rusqlite::Row<'_>) -> rusqlite::Result<Value> {
    let mut object = Map::new();
    for (index, name) in row.as_ref().column_names().iter().enumerate() {
        object.insert((*name).to_string(), json_from_ref(row.get_ref(index)?));
    }
    Ok(Value::Object(object))
}

struct SongRow {
    filename: String,
    title: String,
    artist: String,
    album: String,
    url: String,
    cover_url: Option<String>,
    has_lyrics: i64,
    play_count: i64,
    duration_ms: Option<i64>,
    mtime: Option<f64>,
    created: Option<f64>,
    song_date: Option<f64>,
}

impl SongRow {
    fn from_json(value: &Value) -> Result<Self, String> {
        let text = |key: &str| {
            value
                .get(key)
                .and_then(Value::as_str)
                .unwrap_or("")
                .to_string()
        };
        Ok(Self {
            filename: text("filename"),
            title: text("title"),
            artist: text("artist"),
            album: text("album"),
            url: text("url"),
            cover_url: value
                .get("cover_url")
                .and_then(Value::as_str)
                .map(str::to_owned),
            has_lyrics: value.get("has_lyrics").and_then(Value::as_i64).unwrap_or(0),
            play_count: value.get("play_count").and_then(Value::as_i64).unwrap_or(0),
            duration_ms: value.get("duration_ms").and_then(Value::as_i64),
            mtime: value.get("mtime").and_then(Value::as_f64),
            created: value.get("created_epoch_sec").and_then(Value::as_f64),
            song_date: value.get("song_date_epoch_sec").and_then(Value::as_f64),
        })
    }
}

/// Library and remote-song rows. The cover guard lives here: a null incoming
/// cover never erases working art, because a scan that could not read a file, a
/// failed cover rebuild and an import from another device all look like that.
fn song_op(payload: &Value) -> Result<Value, String> {
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");
    match op {
        "write_batch" => with(payload, |connection| song_write_batch(payload, connection)),
        "all" => with(payload, |connection| {
            let mut statement = connection
                .prepare(ALL_SONGS)
                .map_err(|error| format!("songs: {error}"))?;
            let collected = statement
                .query_map([], row_to_json)
                .map_err(|error| format!("songs: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("songs: {error}"))?;
            Ok(json!({ "songs": collected }))
        }),
        "get" => with(payload, |connection| {
            let filename = text_field(payload, "filename")?;
            let found = {
                let mut statement = connection
                    .prepare("SELECT * FROM song WHERE filename = ?1 LIMIT 1")
                    .map_err(|error| format!("song lookup: {error}"))?;
                statement
                    .query_row([filename], row_to_json)
                    .optional()
                    .map_err(|error| format!("song lookup: {error}"))?
            };
            Ok(json!({ "song": found }))
        }),
        "list" => with(payload, |connection| {
            let mut sql = String::from("SELECT * FROM song");
            let mut args: Vec<Value> = Vec::new();
            if let Some(clause) = payload.get("where").and_then(Value::as_str) {
                sql.push_str(" WHERE ");
                sql.push_str(clause);
                args.extend(
                    payload
                        .get("whereArgs")
                        .and_then(Value::as_array)
                        .cloned()
                        .unwrap_or_default(),
                );
            }
            if let Some(order) = payload.get("orderBy").and_then(Value::as_str) {
                sql.push_str(" ORDER BY ");
                sql.push_str(order);
            }
            if let Some(limit) = payload.get("limit").and_then(Value::as_i64) {
                sql.push_str(&format!(" LIMIT {limit}"));
            }
            if let Some(offset) = payload.get("offset").and_then(Value::as_i64) {
                sql.push_str(&format!(" OFFSET {offset}"));
            }
            let mut statement = connection
                .prepare(&sql)
                .map_err(|error| format!("song list: {error}"))?;
            let bound: Vec<Box<dyn rusqlite::ToSql>> = args
                .iter()
                .map(|value| match value {
                    Value::Null => Box::new(Option::<String>::None) as Box<dyn rusqlite::ToSql>,
                    Value::Bool(flag) => Box::new(*flag as i64),
                    Value::Number(number) => match number.as_i64() {
                        Some(integer) => Box::new(integer) as Box<dyn rusqlite::ToSql>,
                        None => Box::new(number.as_f64().unwrap_or_default()),
                    },
                    Value::String(text) => Box::new(text.clone()),
                    other => Box::new(other.to_string()),
                })
                .collect();
            let references: Vec<&dyn rusqlite::ToSql> =
                bound.iter().map(|value| value.as_ref()).collect();
            let collected = statement
                .query_map(references.as_slice(), row_to_json)
                .map_err(|error| format!("song list: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("song list: {error}"))?;
            Ok(json!({ "songs": collected }))
        }),
        "count" => with(payload, |connection| {
            let count: i64 = connection
                .query_row("SELECT COUNT(*) FROM song", [], |row| row.get(0))
                .map_err(|error| format!("song count: {error}"))?;
            Ok(json!({ "count": count }))
        }),
        "clear" => with(payload, |connection| {
            in_transaction(connection, |connection| {
                connection
                    .execute_batch("DELETE FROM song; DELETE FROM filtered_library_file;")
                    .map_err(|error| format!("clear songs: {error}"))?;
                Ok(json!({ "cleared": true }))
            })
        }),
        "delete" => with(payload, |connection| {
            let filenames = filename_list(payload);
            in_transaction(connection, |connection| {
                let mut removed = 0usize;
                for chunk in filenames.chunks(500) {
                    let placeholders = vec!["?"; chunk.len()].join(", ");
                    let sql = format!("DELETE FROM song WHERE filename IN ({placeholders})");
                    let params: Vec<&dyn rusqlite::ToSql> = chunk
                        .iter()
                        .map(|name| name as &dyn rusqlite::ToSql)
                        .collect();
                    removed += connection
                        .execute(&sql, params.as_slice())
                        .map_err(|error| format!("delete songs: {error}"))?;
                }
                Ok(json!({ "removed": removed }))
            })
        }),
        "clear_cover_urls" => with(payload, |connection| {
            let changed = connection
                .execute(
                    "UPDATE song SET cover_url = NULL WHERE cover_url IS NOT NULL",
                    [],
                )
                .map_err(|error| format!("clear cover urls: {error}"))?;
            Ok(json!({ "changed": changed }))
        }),
        "artists" => with(payload, |connection| {
            let mut statement = connection
                .prepare("SELECT DISTINCT artist FROM song ORDER BY artist COLLATE NOCASE")
                .map_err(|error| format!("artists: {error}"))?;
            let collected = statement
                .query_map([], |row| row.get::<_, String>(0))
                .map_err(|error| format!("artists: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("artists: {error}"))?;
            Ok(json!({ "values": collected }))
        }),
        "albums" => with(payload, |connection| {
            let mut statement = connection
                .prepare("SELECT DISTINCT album FROM song ORDER BY album COLLATE NOCASE")
                .map_err(|error| format!("albums: {error}"))?;
            let collected = statement
                .query_map([], |row| row.get::<_, String>(0))
                .map_err(|error| format!("albums: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("albums: {error}"))?;
            Ok(json!({ "values": collected }))
        }),
        "update_cover" => with(payload, |connection| {
            let filename = text_field(payload, "filename")?;
            let url = text_field(payload, "url")?;
            let cover = text_field(payload, "coverPath")?;
            let mtime = payload.get("mtime").and_then(Value::as_f64);
            let changed = connection
                .execute(
                    "UPDATE song SET cover_url = ?1 WHERE filename = ?2 AND url = ?3 AND mtime IS ?4",
                    rusqlite::params![cover, filename, url, mtime],
                )
                .map_err(|error| format!("update cover: {error}"))?;
            Ok(json!({ "changed": changed > 0 }))
        }),
        "remote_upsert" => with(payload, |connection| {
            let song = payload
                .get("song")
                .ok_or_else(|| "remote upsert needs a song".to_string())?;
            let filename = text_field(song, "filename")?.to_string();
            // Membership is user data, so a metadata refresh must not overwrite it.
            let in_library: i64 = {
                let mut statement = connection
                    .prepare("SELECT in_library FROM remote_song WHERE filename = ?1 LIMIT 1")
                    .map_err(|error| format!("remote membership: {error}"))?;
                statement
                    .query_row([&filename], |row| row.get::<_, Option<i64>>(0))
                    .optional()
                    .map_err(|error| format!("remote membership: {error}"))?
                    .flatten()
                    .unwrap_or(0)
            };
            let now = payload
                .get("now")
                .and_then(Value::as_f64)
                .unwrap_or_default();
            connection
                .execute(
                    "INSERT OR REPLACE INTO remote_song (filename, remote_id, title, artist, \
                     album, cover_url, duration_ms, is_available, in_library, updated_at) \
                     VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10)",
                    rusqlite::params![
                        filename,
                        song.get("remote_id").and_then(Value::as_str),
                        song.get("title").and_then(Value::as_str),
                        song.get("artist").and_then(Value::as_str),
                        song.get("album").and_then(Value::as_str),
                        song.get("cover_url").and_then(Value::as_str),
                        song.get("duration_ms").and_then(Value::as_i64),
                        song.get("is_available")
                            .and_then(Value::as_i64)
                            .unwrap_or(1),
                        in_library,
                        now
                    ],
                )
                .map_err(|error| format!("remote upsert: {error}"))?;
            Ok(json!({ "saved": true }))
        }),
        "remote_library" => with(payload, |connection| {
            let mut statement = connection
                .prepare("SELECT filename FROM remote_song WHERE in_library = 1")
                .map_err(|error| format!("remote library: {error}"))?;
            let collected = statement
                .query_map([], |row| row.get::<_, String>(0))
                .map_err(|error| format!("remote library: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("remote library: {error}"))?;
            Ok(json!({ "filenames": collected }))
        }),
        "remote_set_library" => with(payload, |connection| {
            let filename = text_field(payload, "filename")?;
            let in_library = payload
                .get("inLibrary")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            let changed = connection
                .execute(
                    "UPDATE remote_song SET in_library = ?1 WHERE filename = ?2",
                    rusqlite::params![if in_library { 1i64 } else { 0i64 }, filename],
                )
                .map_err(|error| format!("remote membership: {error}"))?;
            Ok(json!({ "changed": changed > 0 }))
        }),
        "remote_all" => with(payload, |connection| {
            let mut statement = connection
                .prepare("SELECT * FROM remote_song")
                .map_err(|error| format!("remote songs: {error}"))?;
            let collected = statement
                .query_map([], row_to_json)
                .map_err(|error| format!("remote songs: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("remote songs: {error}"))?;
            Ok(json!({ "songs": collected }))
        }),
        other => Err(format!("unknown song op {other}")),
    }
}

fn song_write_batch(payload: &Value, connection: &mut Connection) -> Result<Value, String> {
    in_transaction(connection, |connection| {
        song_write_batch_on(payload, connection)
    })
}

fn song_write_batch_on(payload: &Value, connection: &Connection) -> Result<Value, String> {
    let songs: Vec<SongRow> = payload
        .get("songs")
        .and_then(Value::as_array)
        .map(|rows| {
            rows.iter()
                .map(SongRow::from_json)
                .collect::<Result<Vec<_>, _>>()
        })
        .transpose()?
        .unwrap_or_default();
    let preserve_cover = payload
        .get("preserveCoverUrl")
        .and_then(Value::as_bool)
        .unwrap_or(true);
    let replace_library = payload
        .get("replaceLibrary")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    if songs.is_empty() && !replace_library {
        return Ok(json!({ "written": 0 }));
    }

    let mut existing: HashMap<String, (Option<String>, Option<f64>)> = HashMap::new();
    if preserve_cover {
        for chunk in songs.chunks(500) {
            let placeholders = vec!["?"; chunk.len()].join(", ");
            let sql = format!(
                "SELECT filename, cover_url, created_epoch_sec FROM song \
                 WHERE filename IN ({placeholders})"
            );
            let params: Vec<&dyn rusqlite::ToSql> = chunk
                .iter()
                .map(|song| &song.filename as &dyn rusqlite::ToSql)
                .collect();
            let mut statement = connection
                .prepare(&sql)
                .map_err(|error| format!("existing songs: {error}"))?;
            let rows = statement
                .query_map(params.as_slice(), |row| {
                    Ok((
                        row.get::<_, String>(0)?,
                        row.get::<_, Option<String>>(1)?,
                        row.get::<_, Option<f64>>(2)?,
                    ))
                })
                .map_err(|error| format!("existing songs: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("existing songs: {error}"))?;
            for (filename, cover, created) in rows {
                existing.insert(filename, (cover, created));
            }
        }
    }

    if replace_library {
        connection
            .execute("DELETE FROM filtered_library_file", [])
            .map_err(|error| format!("clear filtered library files: {error}"))?;
        if let Some(filtered) = payload.get("filteredFiles").and_then(Value::as_array) {
            let mut insert = connection
                .prepare("INSERT OR REPLACE INTO filtered_library_file VALUES (?1, ?2, ?3)")
                .map_err(|error| format!("prepare filtered library files: {error}"))?;
            for file in filtered {
                insert
                    .execute(rusqlite::params![
                        text_field(file, "filename")?,
                        text_field(file, "url")?,
                        file.get("mtime").and_then(Value::as_f64)
                    ])
                    .map_err(|error| format!("write filtered library file: {error}"))?;
            }
        }
        let scanned: Vec<&str> = songs.iter().map(|song| song.filename.as_str()).collect();
        let known: Vec<String> = {
            let mut statement = connection
                .prepare("SELECT filename FROM song")
                .map_err(|error| format!("known songs: {error}"))?;
            let collected = statement
                .query_map([], |row| row.get::<_, String>(0))
                .map_err(|error| format!("known songs: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("known songs: {error}"))?;
            collected
        };
        for filename in known {
            if !scanned.contains(&filename.as_str()) {
                connection
                    .execute("DELETE FROM song WHERE filename = ?1", [&filename])
                    .map_err(|error| format!("drop unscanned song: {error}"))?;
            }
        }
    }

    for song in &songs {
        let prior = existing.get(&song.filename);
        let cover = if preserve_cover && song.cover_url.is_none() {
            prior.and_then(|entry| entry.0.clone())
        } else {
            song.cover_url.clone()
        };
        let created = prior.and_then(|entry| entry.1).or(song.created);
        connection
            .execute(
                "INSERT OR REPLACE INTO song (filename, title, artist, album, url, \
                 cover_url, has_lyrics, play_count, duration_ms, mtime, \
                 created_epoch_sec, song_date_epoch_sec) \
                 VALUES (?1, ?2, ?3, ?4, ?5, ?6, ?7, ?8, ?9, ?10, ?11, ?12)",
                rusqlite::params![
                    song.filename,
                    song.title,
                    song.artist,
                    song.album,
                    song.url,
                    cover,
                    song.has_lyrics,
                    song.play_count,
                    song.duration_ms,
                    song.mtime,
                    created,
                    song.song_date
                ],
            )
            .map_err(|error| format!("write song: {error}"))?;
        if preserve_cover {
            existing.insert(song.filename.clone(), (cover, created));
        }
    }
    Ok(json!({ "written": songs.len() }))
}

pub(crate) fn library_file_baseline(
    path: &Path,
) -> Result<HashMap<String, crate::scan::LibraryFile>, String> {
    let (connection, _, _) = open_connection(path, None, None, true, 0)?;
    let mut statement = connection
        .prepare(
            "SELECT filename, url, mtime FROM song
             UNION ALL
             SELECT filename, url, mtime FROM filtered_library_file AS f
             WHERE NOT EXISTS (SELECT 1 FROM song WHERE filename = f.filename)",
        )
        .map_err(|error| format!("prepare library file baseline: {error}"))?;
    let rows = statement
        .query_map([], |row| {
            Ok((
                row.get(0)?,
                crate::scan::LibraryFile {
                    path: row.get::<_, Option<String>>(1)?.unwrap_or_default().into(),
                    mtime: row.get(2)?,
                },
            ))
        })
        .map_err(|error| format!("read library file baseline: {error}"))?;
    rows.collect::<Result<_, _>>()
        .map_err(|error| format!("read library file: {error}"))
}

fn clear_tombstone(connection: &Connection, entity: &str, key: &str) -> Result<(), String> {
    connection
        .execute(
            "DELETE FROM sync_tombstone WHERE entity = ?1 AND key = ?2",
            rusqlite::params![entity, key],
        )
        .map_err(|error| format!("clear tombstone {entity}: {error}"))?;
    Ok(())
}

/// YouTube playlist mappings. Deliberately not synced: they name a playlist on
/// one Google account, so another device must not inherit them.
fn youtube_link_op(payload: &Value) -> Result<Value, String> {
    let op = payload.get("op").and_then(Value::as_str).unwrap_or("list");
    match op {
        "list" => with(payload, |connection| {
            let mut statement = connection
                .prepare(
                    "SELECT remote_playlist_id, local_playlist_id, remote_title, \
                     last_synced_at, item_count FROM youtube_playlist_link",
                )
                .map_err(|error| format!("link list: {error}"))?;
            let collected = statement
                .query_map([], |row| {
                    Ok(json!({
                        "remote_playlist_id": row.get::<_, Option<String>>(0)?,
                        "local_playlist_id": row.get::<_, Option<String>>(1)?,
                        "remote_title": row.get::<_, Option<String>>(2)?,
                        "last_synced_at": row.get::<_, Option<f64>>(3)?,
                        "item_count": row.get::<_, Option<i64>>(4)?,
                    }))
                })
                .map_err(|error| format!("link list: {error}"))?
                .collect::<Result<Vec<_>, _>>()
                .map_err(|error| format!("link list: {error}"))?;
            Ok(json!({ "links": collected }))
        }),
        "save" => with(payload, |connection| {
            let link = payload
                .get("link")
                .ok_or_else(|| "link save needs a link".to_string())?;
            connection
                .execute(
                    "INSERT OR REPLACE INTO youtube_playlist_link \
                     (remote_playlist_id, local_playlist_id, remote_title, \
                     last_synced_at, item_count) VALUES (?1, ?2, ?3, ?4, ?5)",
                    rusqlite::params![
                        link.get("remote_playlist_id").and_then(Value::as_str),
                        link.get("local_playlist_id").and_then(Value::as_str),
                        link.get("remote_title").and_then(Value::as_str),
                        link.get("last_synced_at").and_then(Value::as_f64),
                        link.get("item_count").and_then(Value::as_i64),
                    ],
                )
                .map_err(|error| format!("save link: {error}"))?;
            Ok(json!({ "saved": true }))
        }),
        "delete" => with(payload, |connection| {
            let remote = payload
                .get("remotePlaylistId")
                .and_then(Value::as_str)
                .ok_or_else(|| "link delete needs a remotePlaylistId".to_string())?;
            connection
                .execute(
                    "DELETE FROM youtube_playlist_link WHERE remote_playlist_id = ?1",
                    [remote],
                )
                .map_err(|error| format!("delete link: {error}"))?;
            Ok(json!({ "deleted": true }))
        }),
        other => Err(format!("unknown youtube link op {other}")),
    }
}

fn tombstone(connection: &Connection, entity: &str, key: &str, hlc: i64) -> Result<(), String> {
    connection
        .execute(
            "INSERT OR REPLACE INTO sync_tombstone (entity, key, hlc, dirty) \
             VALUES (?1, ?2, ?3, 1)",
            rusqlite::params![entity, key, hlc],
        )
        .map_err(|error| format!("tombstone {entity}: {error}"))?;
    Ok(())
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
    let transaction = connection
        .transaction()
        .map_err(|error| format!("begin: {error}"))?;
    let result = body(&transaction)?;
    transaction
        .commit()
        .map_err(|error| format!("commit: {error}"))?;
    Ok(result)
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
