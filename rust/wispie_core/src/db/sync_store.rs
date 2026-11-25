use std::cmp::Ordering;

use rusqlite::{params, params_from_iter, Connection, OptionalExtension};
use serde_json::{json, Map, Value};

use super::{
    clear_tombstone, in_transaction, read_rows, restore::insert_row, text_field, to_sql, with,
};

struct Entity {
    table: &'static str,
    keys: &'static [&'static str],
    data: &'static [&'static str],
}

fn entity(name: &str) -> Result<Entity, String> {
    let (table, keys, data): (&str, &[&str], &[&str]) = match name {
        "favorites" => ("favorite", &["filename"], &["added_at"]),
        "suggestless" => ("suggestless", &["filename"], &["added_at"]),
        "hidden" => ("hidden", &["filename"], &["hidden_at"]),
        "playlists" => (
            "playlist",
            &["id"],
            &[
                "name",
                "description",
                "is_recommendation",
                "created_at",
                "updated_at",
            ],
        ),
        "playlist_songs" => (
            "playlist_song",
            &["playlist_id", "song_filename"],
            &["added_at"],
        ),
        "merged_groups" => (
            "merged_song_group",
            &["id"],
            &["priority_filename", "created_at"],
        ),
        "merged_songs" => ("merged_song", &["filename"], &["group_id", "added_at"]),
        "artist_art" => (
            "artist_art",
            &["artist_name"],
            &["image_url", "source", "updated_at"],
        ),
        "album_art" => (
            "album_art",
            &["album_key"],
            &[
                "album_name",
                "artist_name",
                "image_url",
                "source",
                "updated_at",
            ],
        ),
        "queue_snapshots" => (
            "queue_snapshot",
            &["id"],
            &["name", "created_at", "source", "song_count", "songs_json"],
        ),
        "current_queue" => ("current_queue", &["id"], &["queue_json", "updated_at"]),
        "play_sessions" => (
            "playsession",
            &["id"],
            &["start_time", "end_time", "platform", "device_id"],
        ),
        "play_events" => (
            "playevent",
            &["uid"],
            &[
                "session_id",
                "song_filename",
                "timestamp",
                "duration_played",
                "total_length",
                "play_ratio",
                "foreground_duration",
                "background_duration",
                "source",
                "queue_id",
            ],
        ),
        "settings" => ("sync_setting_meta", &["key"], &[]),
        "tombstones" => ("sync_tombstone", &["entity", "key"], &[]),
        _ => return Err(format!("unknown sync entity {name}")),
    };
    Ok(Entity { table, keys, data })
}

fn assignments(cols: &[&str], separator: &str) -> String {
    cols.iter()
        .map(|col| format!("{col} = ?"))
        .collect::<Vec<_>>()
        .join(separator)
}

fn rows<'a>(payload: &'a Value, field: &str) -> Result<&'a [Value], String> {
    payload[field]
        .as_array()
        .map(Vec::as_slice)
        .ok_or_else(|| format!("missing sync {field}"))
}

fn display(value: &Value) -> String {
    value
        .as_str()
        .map(str::to_owned)
        .unwrap_or_else(|| value.to_string())
}

fn compare_text(a: &str, b: &str) -> Ordering {
    a.encode_utf16().cmp(b.encode_utf16())
}

fn clock(record: &Value) -> i64 {
    record["hlc"].as_i64().unwrap_or_default()
}

pub(super) fn run(payload: &Value) -> Result<Value, String> {
    let op = text_field(payload, "op")?;
    with(payload, |db| match op {
        "collect" => collect(db, payload),
        "setting_can_apply" => {
            let key = text_field(payload, "key")?;
            let allowed = crate::sync_payload::SYNCABLE_SETTINGS_KEYS.contains(&key);
            if !allowed {
                return Ok(json!({ "apply": false }));
            }
            let local: Option<i64> = db
                .query_row(
                    "SELECT COALESCE(hlc, 0) FROM sync_setting_meta WHERE key = ?",
                    [key],
                    |row| row.get(0),
                )
                .optional()
                .map_err(|error| error.to_string())?;
            Ok(json!({ "apply": clock(payload) > local.unwrap_or(-1) }))
        }
        "setting_write" => {
            db.execute(
                "INSERT OR REPLACE INTO sync_setting_meta (key, hlc, dirty) VALUES (?, ?, ?)",
                params![
                    text_field(payload, "key")?,
                    clock(payload),
                    payload["dirty"].as_bool().unwrap_or(false)
                ],
            )
            .map_err(|error| error.to_string())?;
            Ok(json!({}))
        }
        "setting_dirty" => {
            db.execute("INSERT INTO sync_setting_meta (key, hlc, dirty) VALUES (?1, ?2, 1)
                         ON CONFLICT(key) DO UPDATE SET hlc = COALESCE(hlc, excluded.hlc), dirty = 1",
                params![text_field(payload, "key")?, clock(payload)]).map_err(|error| error.to_string())?;
            Ok(json!({}))
        }
        "gc" => {
            db.execute("DELETE FROM sync_tombstone WHERE hlc < ?", [clock(payload)])
                .map_err(|error| error.to_string())?;
            Ok(json!({}))
        }
        "remote_rows" => {
            let mut result = Vec::new();
            for chunk in rows(payload, "filenames")?.chunks(400) {
                let sql = format!(
                    "SELECT * FROM remote_song WHERE filename IN ({})",
                    vec!["?"; chunk.len()].join(",")
                );
                result.extend(read_rows(
                    db,
                    &sql,
                    params_from_iter(chunk.iter().map(to_sql)),
                )?);
            }
            Ok(json!({"rows": result}))
        }
        "remote_write" => in_transaction(db, |db| {
            for row in rows(payload, "rows")? {
                insert_row(db, "remote_song", "IGNORE", row)?;
            }
            Ok(json!({}))
        }),
        "apply_queue" => in_transaction(db, |db| apply_queue(db, &payload["record"])),
        "stamp" | "mark" | "wipe" | "ack" | "merge" | "bulk" => in_transaction(db, |db| match op {
            "stamp" | "mark" | "wipe" => change_tracking(db, payload, op),
            "ack" => acknowledge(db, payload),
            _ => apply_records(db, payload, op == "bulk"),
        }),
        _ => Err(format!("unknown sync store operation {op}")),
    })
}

fn collect(db: &Connection, payload: &Value) -> Result<Value, String> {
    let spec = entity(text_field(payload, "entity")?)?;
    let mut columns = vec!["*"];
    if !matches!(spec.table, "sync_tombstone" | "sync_setting_meta") {
        columns = spec.keys.iter().chain(spec.data).copied().collect();
        columns.push("hlc");
    }
    let filter = if payload["dirty_only"] == true {
        " WHERE dirty = 1"
    } else {
        ""
    };
    let mut sql = format!(
        "SELECT {} FROM {}{filter} ORDER BY rowid",
        columns.join(", "),
        spec.table
    );
    let args = if let Some(offset) = payload["offset"].as_i64() {
        sql.push_str(" LIMIT 2000 OFFSET ?");
        vec![offset]
    } else {
        Vec::new()
    };
    Ok(json!({"rows": read_rows(db, &sql, params_from_iter(args))?}))
}

fn change_tracking(db: &Connection, payload: &Value, op: &str) -> Result<Value, String> {
    let hlc = clock(payload);
    for item in rows(payload, "entities")? {
        let name = item.as_str().ok_or("invalid sync entity")?;
        let spec = entity(name)?;
        let table = spec.table;
        match op {
            "stamp" => {
                let dirty = if name == "tombstones" {
                    ""
                } else {
                    " AND dirty = 1"
                };
                db.execute(
                    &format!("UPDATE {table} SET hlc = ? WHERE hlc IS NULL{dirty}"),
                    [hlc],
                )
            }
            "mark" => db
                .execute(
                    &format!("UPDATE {table} SET dirty = 1, hlc = COALESCE(hlc, ?)"),
                    [hlc],
                )
                .and_then(|_| {
                    db.execute(
                        "UPDATE sync_tombstone SET dirty = 1 WHERE entity = ?",
                        [name],
                    )
                }),
            _ => {
                if name == "queue_snapshots" {
                    db.execute("DELETE FROM queue_snapshot_song", [])
                        .map_err(|error| error.to_string())?;
                }
                db.execute(&format!("DELETE FROM {table}"), [])
                    .and_then(|_| db.execute("DELETE FROM sync_tombstone WHERE entity = ?", [name]))
            }
        }
        .map_err(|error| error.to_string())?;
    }
    Ok(json!({}))
}

fn acknowledge(db: &Connection, payload: &Value) -> Result<Value, String> {
    for row in rows(payload, "rows")? {
        let spec = entity(text_field(row, "entity")?)?;
        let predicate = assignments(spec.keys, " AND ");
        let args = rows(row, "keys")?;
        let sql = format!(
            "UPDATE {} SET dirty = 0 WHERE {predicate} AND hlc = ?",
            spec.table
        );
        db.execute(
            &sql,
            params_from_iter(args.iter().map(to_sql).chain([clock(row).into()])),
        )
        .map_err(|error| error.to_string())?;
    }
    Ok(json!({}))
}

fn apply_records(db: &Connection, payload: &Value, bulk: bool) -> Result<Value, String> {
    let name = text_field(payload, "entity")?;
    let mut applied = 0;
    for record in rows(payload, "rows")? {
        if name == "tombstones" {
            merge_tombstone(db, record, bulk)?;
            applied += 1;
            continue;
        }
        let spec = entity(name)?;
        if spec
            .keys
            .iter()
            .any(|key| record[key].is_null() || display(&record[key]).is_empty())
        {
            continue;
        }
        let mut incoming: Map<String, Value> = spec
            .keys
            .iter()
            .chain(spec.data)
            .map(|col| ((*col).into(), record[col].clone()))
            .collect();
        if name == "play_events" && !sanitize_event(&mut incoming) {
            continue;
        }
        let hlc = clock(record);
        incoming.insert("hlc".into(), json!(hlc));
        incoming.insert("dirty".into(), json!(0));
        let mut incoming = Value::Object(incoming);
        let keys: Vec<_> = spec.keys.iter().map(|col| incoming[col].clone()).collect();
        let key = keys.iter().map(display).collect::<Vec<_>>().join("\0");
        if bulk {
            insert_row(db, spec.table, "IGNORE", &incoming)?;
        } else {
            if let Some(tomb) = tomb_clock(db, name, &key)? {
                if tomb > hlc {
                    continue;
                }
                clear_tombstone(db, name, &key)?;
            }
            let predicate = assignments(spec.keys, " AND ");
            let sql = format!("SELECT * FROM {} WHERE {predicate} LIMIT 1", spec.table);
            let previous = read_rows(db, &sql, params_from_iter(keys.iter().map(to_sql)))?.pop();
            if let Some(previous) = previous {
                let local_clock = clock(&previous);
                match name {
                    "play_sessions" | "play_events" => {
                        let mut merged = merge_play(name, &previous, &incoming);
                        if same(&merged, &previous, spec.data) {
                            continue;
                        }
                        merged["dirty"] = json!(i32::from(!same(&merged, &incoming, spec.data)));
                        merged["hlc"] = json!(hlc.max(local_clock));
                        incoming = merged;
                    }
                    _ => {
                        let remote = payload["remote_device"].as_str().unwrap_or_default();
                        let local = payload["device"].as_str().unwrap_or_default();
                        if hlc < local_clock
                            || (hlc == local_clock && !compare_text(remote, local).is_gt())
                        {
                            continue;
                        }
                    }
                }
                let columns = [spec.data, &["hlc", "dirty"]].concat();
                let set = assignments(&columns, ", ");
                let sql = format!("UPDATE {} SET {set} WHERE {predicate}", spec.table);
                db.execute(
                    &sql,
                    params_from_iter(
                        columns
                            .iter()
                            .map(|col| to_sql(&incoming[col]))
                            .chain(keys.iter().map(to_sql)),
                    ),
                )
                .map_err(|error| error.to_string())?;
            } else {
                insert_row(db, spec.table, "ABORT", &incoming)?;
            }
        }
        if name == "queue_snapshots" {
            rebuild_snapshot(db, &incoming)?;
        }
        applied += 1;
    }
    Ok(json!({"count": applied}))
}

fn tomb_clock(db: &Connection, name: &str, key: &str) -> Result<Option<i64>, String> {
    db.query_row(
        "SELECT COALESCE(hlc, 0) FROM sync_tombstone WHERE entity = ? AND key = ?",
        params![name, key],
        |row| row.get(0),
    )
    .optional()
    .map_err(|error| error.to_string())
}

fn merge_tombstone(db: &Connection, record: &Value, bulk: bool) -> Result<(), String> {
    let name = text_field(record, "entity")?;
    let spec = entity(name)?;
    let key = display(&record["key"]);
    let hlc = clock(record);
    if !bulk {
        let keys: Vec<_> = key.split('\0').collect();
        if keys.len() != spec.keys.len() {
            return Ok(());
        }
        let predicate = assignments(spec.keys, " AND ");
        let table = spec.table;
        let local: Option<i64> = db
            .query_row(
                &format!("SELECT COALESCE(hlc, 0) FROM {table} WHERE {predicate} LIMIT 1"),
                params_from_iter(&keys),
                |row| row.get(0),
            )
            .optional()
            .map_err(|error| error.to_string())?;
        if let Some(local) = local {
            if hlc <= local {
                return Ok(());
            }
            db.execute(
                &format!("DELETE FROM {table} WHERE {predicate}"),
                params_from_iter(&keys),
            )
            .map_err(|error| error.to_string())?;
            if name == "queue_snapshots" {
                db.execute(
                    "DELETE FROM queue_snapshot_song WHERE snapshot_id = ?",
                    [&key],
                )
                .map_err(|error| error.to_string())?;
            }
        }
        if tomb_clock(db, name, &key)?.is_some_and(|previous| hlc <= previous) {
            return Ok(());
        }
    }
    let conflict = if bulk { "IGNORE" } else { "REPLACE" };
    insert_row(
        db,
        "sync_tombstone",
        conflict,
        &json!({"entity": name, "key": key, "hlc": hlc, "dirty": 0}),
    )
}

fn rebuild_snapshot(db: &Connection, record: &Value) -> Result<(), String> {
    let id = display(&record["id"]);
    db.execute(
        "DELETE FROM queue_snapshot_song WHERE snapshot_id = ?",
        [&id],
    )
    .map_err(|error| error.to_string())?;
    let songs: Option<Vec<Value>> = record["songs_json"]
        .as_str()
        .and_then(|json| serde_json::from_str(json).ok());
    for (position, song) in songs.unwrap_or_default().iter().enumerate() {
        db.execute("INSERT INTO queue_snapshot_song (snapshot_id, song_filename, position) VALUES (?, ?, ?)",
            params![id, display(song), position]).map_err(|error| error.to_string())?;
    }
    Ok(())
}

fn apply_queue(db: &Connection, record: &Value) -> Result<Value, String> {
    let id = record["id"].as_str().unwrap_or("current");
    let hlc = clock(record);
    let newer: bool = db
        .query_row(
            "SELECT EXISTS(SELECT 1 FROM current_queue WHERE id = ? AND dirty = 0 AND hlc > ?)",
            params![id, hlc],
            |row| row.get(0),
        )
        .map_err(|error| error.to_string())?;
    if !newer {
        db.execute("INSERT OR REPLACE INTO current_queue (id, queue_json, updated_at, hlc, dirty) VALUES (?, ?, ?, ?, 0)",
            params![id, record["queue_json"].as_str(), record["updated_at"].as_f64(), hlc])
            .map_err(|error| error.to_string())?;
    }
    Ok(json!({"applied": !newer}))
}

fn same(a: &Value, b: &Value, cols: &[&str]) -> bool {
    cols.iter().all(|col| {
        a[col] == b[col]
            || a[col]
                .as_f64()
                .zip(b[col].as_f64())
                .is_some_and(|(a, b)| a == b)
    })
}

fn sanitize_event(row: &mut Map<String, Value>) -> bool {
    if ["uid", "session_id", "song_filename"]
        .iter()
        .any(|col| row[*col].as_str().is_none_or(str::is_empty))
        || row["timestamp"].as_f64().is_none()
    {
        return false;
    }
    let number = |col: &str| row[col].as_f64().unwrap_or_default().max(0.0);
    let total = number("total_length");
    let mut duration = number("duration_played");
    if total > 0.0 && duration > total * 1.05 + 10.0 {
        duration = total;
    }
    let ratio = if total > 0.0 {
        (duration / total).min(1.0)
    } else {
        number("play_ratio")
    };
    for (col, value) in [
        ("total_length", total),
        ("duration_played", duration),
        ("play_ratio", ratio),
        ("foreground_duration", number("foreground_duration")),
        ("background_duration", number("background_duration")),
    ] {
        row.insert(col.into(), json!(value));
    }
    true
}

fn merge_play(name: &str, a: &Value, b: &Value) -> Value {
    let pick = |col: &str, f: fn(f64, f64) -> f64| match (a[col].as_f64(), b[col].as_f64()) {
        (Some(a), Some(b)) => json!(f(a, b)),
        (a, b) => json!(a.or(b)),
    };
    let text = |col: &str, skip: Option<&str>, minimum: bool| {
        let a = a[col].as_str();
        let b = b[col].as_str();
        let left = a.filter(|value| Some(*value) != skip);
        let right = b.filter(|value| Some(*value) != skip);
        let preferred = match (left, right) {
            (None | Some(""), _) => right,
            (_, None | Some("")) => left,
            (Some(left), Some(right)) => {
                let order = compare_text(left, right);
                if (minimum && order.is_le()) || (!minimum && order.is_ge()) {
                    Some(left)
                } else {
                    Some(right)
                }
            }
        };
        if skip.is_some() {
            preferred.or(a).or(b)
        } else {
            preferred
        }
    };
    if name == "play_sessions" {
        return json!({
            "start_time": pick("start_time", f64::min), "end_time": pick("end_time", f64::max),
            "platform": text("platform", Some("unknown"), false), "device_id": text("device_id", None, true),
        });
    }

    let max = |col: &str| {
        a[col]
            .as_f64()
            .unwrap_or_default()
            .max(b[col].as_f64().unwrap_or_default())
    };
    let duration = max("duration_played");
    let total = max("total_length");
    let name_key = |row: &Value| {
        format!(
            "{}{}",
            display(&row["session_id"]),
            display(&row["song_filename"])
        )
    };
    let incoming_wins = clock(b)
        .cmp(&clock(a))
        .then_with(|| compare_text(&name_key(b), &name_key(a)))
        .is_gt();
    let (winner, other) = if incoming_wins { (b, a) } else { (a, b) };
    json!({
        "session_id": winner["session_id"], "song_filename": winner["song_filename"],
        "timestamp": max("timestamp"), "duration_played": duration, "total_length": total,
        "play_ratio": if total > 0.0 { (duration / total).min(1.0) } else { max("play_ratio") },
        "foreground_duration": max("foreground_duration"), "background_duration": max("background_duration"),
        "source": text("source", None, false),
        "queue_id": winner["queue_id"].as_str().or_else(|| other["queue_id"].as_str()),
    })
}
