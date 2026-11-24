use rusqlite::{params, Connection};
use serde_json::{json, Value};

use super::{
    in_transaction, read_rows, restore::quote_identifier, restore::table_exists, text_field,
    tombstone, with,
};

pub(super) fn run(payload: &Value) -> Result<Value, String> {
    let op = text_field(payload, "op")?;
    with(payload, |db| match op {
        "integrity" => db
            .query_row("PRAGMA integrity_check", [], |row| row.get::<_, String>(0))
            .map(|result| json!({"ok": result == "ok"}))
            .map_err(|error| error.to_string()),
        "vacuum" => db
            .execute_batch("VACUUM")
            .map(|()| json!({}))
            .map_err(|error| error.to_string()),
        "count" | "has_rows" => {
            let table = text_field(payload, "table")?;
            let count = if table_exists(db, table)? {
                let table = quote_identifier(table);
                let sql = if op == "count" {
                    format!("SELECT COUNT(*) FROM {table}")
                } else {
                    format!("SELECT EXISTS(SELECT 1 FROM {table})")
                };
                db.query_row(&sql, [], |row| row.get::<_, i64>(0))
                    .map_err(|error| error.to_string())?
            } else {
                0
            };
            Ok(json!({"count": count}))
        }
        "short_sessions" => in_transaction(db, |db| short_sessions(db, payload)),
        "followups" => in_transaction(db, |db| followups(db, payload)),
        "orphans" => in_transaction(db, repair_orphans),
        "duplicates" => in_transaction(db, repair_duplicates),
        _ => Err(format!("unknown maintenance operation {op}")),
    })
}

fn sync_enabled(db: &Connection) -> Result<bool, String> {
    Ok(table_exists(db, "sync_tombstone")?
        && read_rows(db, "PRAGMA table_info(playevent)", [])?
            .iter()
            .any(|row| row["name"] == "uid"))
}

fn short_sessions(db: &Connection, payload: &Value) -> Result<Value, String> {
    let minimum = payload["minimum"]
        .as_f64()
        .ok_or("missing session minimum")?;
    let hlc = payload["hlc"].as_i64().ok_or("missing cleanup clock")?;
    let sessions = "(end_time - start_time) < ? OR start_time IS NULL OR end_time IS NULL";
    let events = format!(
        "session_id IN (SELECT id FROM playsession WHERE {sessions})
        OR session_id NOT IN (SELECT id FROM playsession) OR session_id IS NULL"
    );
    if sync_enabled(db)? {
        for (table, column, predicate, entity) in [
            ("playevent", "uid", events.as_str(), "play_events"),
            ("playsession", "id", sessions, "play_sessions"),
        ] {
            for row in read_rows(
                db,
                &format!("SELECT {column} FROM {table} WHERE {predicate}"),
                [minimum],
            )? {
                if let Some(key) = row[column].as_str() {
                    tombstone(db, entity, key, hlc)?;
                }
            }
        }
    }
    let events = db
        .execute(&format!("DELETE FROM playevent WHERE {events}"), [minimum])
        .map_err(|error| error.to_string())?;
    let sessions = db
        .execute(
            &format!("DELETE FROM playsession WHERE {sessions}"),
            [minimum],
        )
        .map_err(|error| error.to_string())?;
    Ok(
        json!({"deletedEvents": events, "deletedSessions": sessions, "details": {
            "sessions_deleted": sessions, "events_deleted": events, "min_duration_seconds": minimum,
        }}),
    )
}

fn followups(db: &Connection, payload: &Value) -> Result<Value, String> {
    let hlc = payload["hlc"].as_i64().ok_or("missing cleanup clock")?;
    let sync = sync_enabled(db)?;
    let uid = if sync { ", uid" } else { "" };
    let rows = read_rows(
        db,
        &format!(
            "SELECT id, song_filename, timestamp, duration_played, total_length{uid}
         FROM playevent ORDER BY timestamp ASC, id ASC"
        ),
        [],
    )?;
    let mut previous = None;
    let mut deleted = 0;
    for row in &rows {
        let (Some(id), Some(song), Some(_), Some(duration)) = (
            row["id"].as_i64(),
            row["song_filename"].as_str(),
            row["timestamp"].as_f64(),
            row["duration_played"].as_f64(),
        ) else {
            continue;
        };
        let is_followup =
            previous.is_some_and(|(prev_song, prev_duration, length): (&str, f64, f64)| {
                if song != prev_song || length <= 0.0 || duration >= 10.0 {
                    return false;
                }
                let multiplier = (prev_duration / length).round();
                multiplier >= 1.0 && (prev_duration - multiplier * length).abs() <= 10.0
            });
        if is_followup {
            db.execute("DELETE FROM playevent WHERE id = ?", [id])
                .map_err(|error| error.to_string())?;
            if let Some(uid) = row["uid"].as_str() {
                tombstone(db, "play_events", uid, hlc)?;
            }
            deleted += 1;
        } else {
            previous = Some((
                song,
                duration,
                row["total_length"].as_f64().unwrap_or_default(),
            ));
        }
    }
    Ok(json!({"deleted": deleted, "details": {
        "events_scanned": rows.len(), "events_deleted": deleted,
        "max_followup_duration_seconds": 10.0, "full_multiple_tolerance_seconds": 10.0,
        "immediate_definition": "next playevent row in timestamp order",
    }}))
}

fn tables(db: &Connection) -> Result<Vec<Value>, String> {
    read_rows(
        db,
        "SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'",
        [],
    )
}

fn repair_orphans(db: &Connection) -> Result<Value, String> {
    let mut removed = 0;
    for row in tables(db)? {
        let table = quote_identifier(text_field(&row, "name")?);
        for fk in read_rows(db, &format!("PRAGMA foreign_key_list({table})"), [])? {
            let from = quote_identifier(text_field(&fk, "from")?);
            let parent = quote_identifier(text_field(&fk, "table")?);
            let to = quote_identifier(fk["to"].as_str().unwrap_or("id"));
            let sql = format!(
                "DELETE FROM {table} AS child WHERE child.{from} IS NOT NULL
                 AND NOT EXISTS (SELECT 1 FROM {parent} WHERE {parent}.{to} = child.{from})"
            );
            if let Ok(changes) = db.execute(&sql, []) {
                removed += changes;
            }
        }
    }
    Ok(json!({"issuesFound": removed, "issuesFixed": removed}))
}

fn repair_duplicates(db: &Connection) -> Result<Value, String> {
    let mut found = 0;
    let mut removed = 0;
    for row in tables(db)? {
        let table = quote_identifier(text_field(&row, "name")?);
        let cols = read_rows(db, &format!("PRAGMA table_info({table})"), [])?;
        if !cols.iter().any(|row| row["name"] == "filename") {
            continue;
        }
        let Some(timestamp) = cols
            .iter()
            .filter_map(|col| col["name"].as_str())
            .find(|name| name.ends_with("_at") || *name == "timestamp")
        else {
            continue;
        };
        let timestamp = quote_identifier(timestamp);
        let sql = format!(
            "SELECT filename, COUNT(*) AS cnt, MAX({timestamp}) AS max_time
            FROM {table} GROUP BY filename HAVING cnt > 1"
        );
        for duplicate in read_rows(db, &sql, [])? {
            if duplicate["max_time"].is_null() {
                continue;
            }
            removed += db
                .execute(
                    &format!("DELETE FROM {table} WHERE filename = ? AND {timestamp} < ?"),
                    params![
                        super::to_sql(&duplicate["filename"]),
                        super::to_sql(&duplicate["max_time"])
                    ],
                )
                .map_err(|error| error.to_string())?;
            found += duplicate["cnt"].as_i64().unwrap_or(1) - 1;
        }
    }
    Ok(json!({"issuesFound": found, "issuesFixed": removed}))
}
