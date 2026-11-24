use rusqlite::{params, Connection, OpenFlags};
use serde_json::{json, Value};

use super::{backfill_play_event_uids, in_transaction, read_rows, text_field, to_sql, with};

pub(super) fn run(payload: &Value) -> Result<Value, String> {
    let kind = text_field(payload, "kind")?;
    if kind == "queue_history" {
        return with(payload, |db| {
            in_transaction(db, |db| restore_queue_history(db, payload))
        });
    }
    let source = Connection::open_with_flags(
        text_field(payload, "path")?,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
    .map_err(|error| format!("open backup: {error}"))?;
    let additive = payload["additive"]
        .as_bool()
        .ok_or("missing restore mode")?;
    let hlc = payload["hlc"].as_i64().ok_or("missing restore clock")?;
    with(payload, |db| {
        in_transaction(db, |db| {
            match kind {
                "stats" => restore_stats(db, &source, additive, hlc)?,
                "userdata" => restore_data(db, &source, payload, additive, hlc)?,
                _ => return Err(format!("unknown restore database {kind}")),
            }
            Ok(json!({}))
        })
    })
}

fn restore_queue_history(db: &Connection, payload: &Value) -> Result<Value, String> {
    db.execute_batch("DELETE FROM queue_snapshot_song; DELETE FROM queue_snapshot")
        .map_err(|error| error.to_string())?;
    for row in payload["snapshots"]
        .as_array()
        .ok_or("missing queue history")?
    {
        let id = text_field(row, "id")?;
        let songs = row["songs"].as_array().ok_or("missing snapshot songs")?;
        db.execute(
            "INSERT INTO queue_snapshot (id, name, created_at, source, song_count, songs_json)
             VALUES (?, ?, ?, ?, ?, ?)",
            params![
                id,
                text_field(row, "name")?,
                row["created_at"].as_f64(),
                text_field(row, "source")?,
                songs.len(),
                row["songs"].to_string()
            ],
        )
        .map_err(|error| error.to_string())?;
        let mut insert = db.prepare_cached(
            "INSERT INTO queue_snapshot_song (snapshot_id, song_filename, position) VALUES (?, ?, ?)",
        ).map_err(|error| error.to_string())?;
        for (position, song) in songs.iter().enumerate() {
            insert
                .execute(params![id, song.as_str(), position])
                .map_err(|error| error.to_string())?;
        }
    }
    Ok(json!({}))
}

fn restore_stats(
    db: &Connection,
    source: &Connection,
    additive: bool,
    hlc: i64,
) -> Result<(), String> {
    if !additive {
        db.execute_batch("DELETE FROM playevent; DELETE FROM playsession")
            .map_err(|error| error.to_string())?;
    }
    copy_table(db, source, "playsession", "IGNORE", false)?;
    let rows = read_rows(source, "SELECT * FROM playevent", [])?;
    for mut row in rows {
        if additive {
            let exists: bool = db.query_row(
                "SELECT EXISTS(SELECT 1 FROM playevent WHERE session_id = ? AND song_filename = ? AND timestamp = ?)",
                params![to_sql(&row["session_id"]), to_sql(&row["song_filename"]), to_sql(&row["timestamp"])],
                |row| row.get(0),
            ).map_err(|error| error.to_string())?;
            if exists {
                continue;
            }
        }
        row.as_object_mut()
            .ok_or("invalid play event row")?
            .remove("id");
        insert_row(db, "playevent", "ABORT", &row)?;
    }
    backfill_play_event_uids(db)?;
    mark_dirty(db, "playsession", hlc)?;
    mark_dirty(db, "playevent", hlc)
}

fn restore_data(
    db: &Connection,
    source: &Connection,
    payload: &Value,
    additive: bool,
    hlc: i64,
) -> Result<(), String> {
    let categories = super::string_list(payload, "categories");
    for (category, tables) in [
        ("favorites", &["favorite"][..]),
        ("suggestless", &["suggestless"][..]),
        ("hidden", &["hidden"][..]),
        ("userdata", &["userdata"][..]),
        (
            "recommendations",
            &["recommendation_preference", "recommendation_removal"][..],
        ),
        ("playlists", &["playlist", "playlist_song"][..]),
        ("mergedGroups", &["merged_song_group", "merged_song"][..]),
        ("", &["artist_art", "album_art"][..]),
    ] {
        if !category.is_empty() && !categories.iter().any(|item| item == category) {
            continue;
        }
        if !additive {
            for table in tables.iter().rev() {
                db.execute(&format!("DELETE FROM {table}"), [])
                    .map_err(|error| error.to_string())?;
            }
        }
        for &table in tables {
            let mandatory = matches!(
                table,
                "favorite" | "suggestless" | "hidden" | "playlist" | "playlist_song"
            );
            if mandatory || table_exists(source, table)? {
                let conflict = match table {
                    "userdata" | "recommendation_preference" | "artist_art" | "album_art" => {
                        "REPLACE"
                    }
                    _ => "IGNORE",
                };
                copy_table(db, source, table, conflict, table == "playlist_song")?;
            }
            if table == "playlist" {
                db.execute("DELETE FROM youtube_playlist_link WHERE local_playlist_id NOT IN (SELECT id FROM playlist)", [])
                    .map_err(|error| error.to_string())?;
            }
            if matches!(table, "favorite" | "playlist_song") && table_exists(source, "remote_song")?
            {
                import_remote_songs(db, source, table)?;
            }
            if !matches!(category, "userdata" | "recommendations") {
                mark_dirty(db, table, hlc)?;
            }
        }
    }

    if table_exists(source, "song_identity")? {
        let now = payload["now"].as_f64().unwrap_or_default();
        for row in read_rows(source, "SELECT filename, cid FROM song_identity", [])? {
            db.execute(
                "INSERT OR IGNORE INTO song_identity (filename, cid, status, seen_at) VALUES (?, ?, 1, ?)",
                params![row["filename"].as_str(), row["cid"].as_str(), now],
            ).map_err(|error| error.to_string())?;
        }
    }
    Ok(())
}

fn import_remote_songs(db: &Connection, source: &Connection, table: &str) -> Result<(), String> {
    let column = if table == "favorite" {
        "filename"
    } else {
        "song_filename"
    };
    let sql = format!(
        "SELECT * FROM remote_song WHERE filename IN
        (SELECT {column} FROM {table} WHERE substr({column}, 1, 8) = 'youtube:')"
    );
    for row in read_rows(source, &sql, [])? {
        insert_row(db, "remote_song", "REPLACE", &row)?;
    }
    Ok(())
}

pub(super) fn table_exists(db: &Connection, name: &str) -> Result<bool, String> {
    db.query_row(
        "SELECT EXISTS(SELECT 1 FROM sqlite_master WHERE type = 'table' AND name = ?)",
        [name],
        |row| row.get(0),
    )
    .map_err(|error| error.to_string())
}

fn copy_table(
    db: &Connection,
    source: &Connection,
    table: &str,
    conflict: &str,
    drop_id: bool,
) -> Result<(), String> {
    for mut row in read_rows(source, &format!("SELECT * FROM {table}"), [])? {
        if drop_id {
            row.as_object_mut()
                .ok_or("invalid backup row")?
                .remove("id");
        }
        insert_row(db, table, conflict, &row)?;
    }
    Ok(())
}

pub(super) fn insert_row(
    db: &Connection,
    table: &str,
    conflict: &str,
    row: &Value,
) -> Result<(), String> {
    let row = row.as_object().ok_or("expected a row object")?;
    let columns = row
        .keys()
        .map(|key| quote_identifier(key))
        .collect::<Vec<_>>()
        .join(", ");
    let placeholders = vec!["?"; row.len()].join(", ");
    let sql = format!("INSERT OR {conflict} INTO {table} ({columns}) VALUES ({placeholders})");
    db.prepare_cached(&sql)
        .and_then(|mut stmt| stmt.execute(rusqlite::params_from_iter(row.values().map(to_sql))))
        .map_err(|error| format!("restore {table}: {error}"))?;
    Ok(())
}

pub(super) fn quote_identifier(name: &str) -> String {
    format!("\"{}\"", name.replace('"', "\"\""))
}

fn mark_dirty(db: &Connection, table: &str, hlc: i64) -> Result<(), String> {
    db.execute(
        &format!("UPDATE {table} SET dirty = 1, hlc = COALESCE(hlc, ?)"),
        [hlc],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}
