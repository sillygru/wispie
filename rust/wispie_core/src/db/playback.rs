use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Value};

use super::{arguments, in_transaction, read_rows, text_field, with};

pub(super) fn run(payload: &Value) -> Result<Value, String> {
    let op = text_field(payload, "op")?;
    with(payload, |db| {
        match op {
            "write" => return write(db, payload),
            "repair" => return repair(db, payload),
            "device_counts" => {
                let device = text_field(payload, "device")?;
                return db.query_row(
                    "SELECT COUNT(*) AS total,
                     COUNT(CASE WHEN COALESCE(ps.device_id, ?1) IN (?1, 'unknown') THEN 1 END) AS local
                     FROM playevent pe LEFT JOIN playsession ps ON pe.session_id = ps.id",
                    [device], |row| {
                        let total: i64 = row.get(0)?;
                        let local: i64 = row.get(1)?;
                        Ok(json!({"localPlayCount": local, "remotePlayCount": total - local,
                                  "totalPlayCount": total}))
                    },
                ).map_err(|error| error.to_string());
            }
            "clear" => {
                in_transaction(db, |db| {
                    db.execute_batch("DELETE FROM playevent; DELETE FROM playsession")
                        .map_err(|error| error.to_string())
                })?;
                return Ok(json!({}));
            }
            _ => {}
        }
        let sql = match op {
            "events" => "SELECT * FROM playevent",
            "sessions" => "SELECT ps.id, ps.start_time, ps.end_time, ps.platform,
                            COUNT(pe.id) AS song_count, SUM(pe.duration_played) AS total_duration
                            FROM playsession ps LEFT JOIN playevent pe ON ps.id = pe.session_id
                            GROUP BY ps.id HAVING (ps.end_time - ps.start_time) >= ? OR song_count > 0
                            ORDER BY ps.start_time DESC",
            "session_events" => "SELECT * FROM playevent WHERE session_id = ? ORDER BY timestamp ASC",
            "counts" => "SELECT song_filename, COUNT(*) AS count FROM playevent
                         WHERE play_ratio > 0.25 GROUP BY song_filename",
            "queue_listens" => "SELECT song_filename, timestamp FROM playevent
                                WHERE queue_id = ? ORDER BY timestamp ASC, id ASC",
            "last_played" => "SELECT song_filename, MAX(timestamp) AS last_played FROM playevent
                              WHERE play_ratio > 0.25 GROUP BY song_filename",
            "affinity" => "SELECT song_filename, timestamp, play_ratio, duration_played, total_length
                            FROM playevent WHERE timestamp >= ? ORDER BY timestamp DESC",
            "taste" => "SELECT song_filename, timestamp, play_ratio, duration_played, total_length,
                        session_id, source FROM playevent WHERE timestamp >= ?
                        ORDER BY session_id, timestamp",
            "skips" => "SELECT song_filename, COUNT(CASE WHEN play_ratio < 0.10 THEN 1 END) AS skip_count,
                        AVG(play_ratio) AS avg_ratio FROM playevent GROUP BY song_filename",
            "history" => "SELECT * FROM playevent ORDER BY timestamp DESC LIMIT ?",
            "samples" => "SELECT song_filename, timestamp, duration_played, total_length, play_ratio
                          FROM playevent ORDER BY timestamp ASC",
            "last_event" => "SELECT timestamp FROM playevent ORDER BY timestamp DESC LIMIT 1",
            _ => return Err(format!("unknown playback operation {op}")),
        };
        let args = arguments(payload)?;
        Ok(json!({"rows": read_rows(db, sql, rusqlite::params_from_iter(args))?}))
    })
}

fn write(db: &mut Connection, payload: &Value) -> Result<Value, String> {
    let events = payload["events"]
        .as_array()
        .ok_or("missing playback events")?;
    let hlc = payload["hlc"].as_i64().ok_or("missing playback clock")?;
    let sync = payload["sync"].as_bool().unwrap_or(false);
    in_transaction(db, |db| {
        for event in events {
            write_event(db, event, hlc, sync)?;
        }
        Ok(json!({}))
    })
}

fn write_event(db: &Connection, event: &Value, hlc: i64, sync: bool) -> Result<(), String> {
    let session = text_field(event, "session_id")?;
    let filename = text_field(event, "song_filename")?;
    if session.is_empty() || filename.is_empty() {
        return Err("session_id and song_filename are required".to_string());
    }
    let timestamp = event["timestamp"].as_f64().ok_or("timestamp is required")?;
    let dirty = !sync;
    let device = event["device_id"].as_str();
    let queue = event["queue_id"].as_str();
    let source = event["source"].as_str();
    let platform = event["platform"].as_str().unwrap_or("unknown");
    db.execute(
        "INSERT OR IGNORE INTO playsession (id, start_time, end_time, platform, device_id, hlc, dirty)
         VALUES (?1, ?2, ?2, ?3, ?4, ?5, ?6)",
        params![session, timestamp, platform, device, hlc, dirty],
    ).map_err(|error| error.to_string())?;
    if let Some(device) = device.filter(|value| !value.is_empty()) {
        db.execute(
            "UPDATE playsession SET device_id = ?1, hlc = ?2, dirty = ?3
             WHERE id = ?4 AND (device_id IS NULL OR device_id = '')",
            params![device, hlc, dirty, session],
        )
        .map_err(|error| error.to_string())?;
    }
    db.execute(
        "UPDATE playsession SET end_time = ?1, hlc = ?2, dirty = ?3 WHERE id = ?4 AND end_time < ?1",
        params![timestamp, hlc, dirty, session],
    ).map_err(|error| error.to_string())?;

    // A local flush can only extend the latest listen in that session.
    let (sql, args) = if sync {
        (
            "SELECT * FROM playevent WHERE session_id = ? AND song_filename = ? AND queue_id IS ?
          ORDER BY timestamp DESC LIMIT 1",
            params![session, filename, queue],
        )
    } else {
        ("SELECT * FROM (SELECT * FROM playevent WHERE session_id = ? ORDER BY timestamp DESC LIMIT 1)
          WHERE song_filename = ? AND queue_id IS ?", params![session, filename, queue])
    };
    let last = db
        .query_row(sql, args, super::row_to_json)
        .optional()
        .map_err(|error| error.to_string())?;
    let number = |row: &Value, key: &str| row[key].as_f64().unwrap_or_default();
    let mut length = number(event, "total_length");
    let mut duration = number(event, "duration_played");
    let mut ratio = event["play_ratio"].as_f64().unwrap_or_else(|| {
        if length > 0.0 {
            duration / length
        } else {
            0.0
        }
    });
    let fg = event["foreground_duration"].as_f64();
    let bg = event["background_duration"].as_f64();

    if let Some(last) = last {
        if length <= 0.0 {
            length = number(&last, "total_length");
        }
        let combine = |previous: f64, next: f64| {
            if sync {
                previous.max(next)
            } else {
                previous + next
            }
        };
        duration = combine(number(&last, "duration_played"), duration);
        let mut fg = combine(number(&last, "foreground_duration"), fg.unwrap_or_default());
        let mut bg = combine(number(&last, "background_duration"), bg.unwrap_or_default());
        if length > 0.0 && duration > length * 1.05 + 10.0 {
            duration = length;
            if !sync && fg + bg > 0.0 {
                let scale = duration / (fg + bg);
                fg *= scale;
                bg *= scale;
            }
        }
        if length > 0.0 {
            ratio = (duration / length).min(1.0);
        } else if sync {
            ratio = ratio.max(number(&last, "play_ratio"));
        }
        let timestamp = if sync {
            timestamp.max(number(&last, "timestamp"))
        } else {
            timestamp
        };
        db.execute(
            "UPDATE playevent SET duration_played = ?, foreground_duration = ?, background_duration = ?,
             total_length = ?, timestamp = ?, play_ratio = ?, hlc = ?, dirty = ?, source = COALESCE(source, ?)
             WHERE id = ?",
            params![duration, fg, bg, length, timestamp, ratio, hlc, dirty, source, last["id"].as_i64()],
        ).map_err(|error| error.to_string())?;
    } else {
        if length > 0.0 && duration > length * 1.05 + 10.0 {
            duration = length;
            ratio = 1.0;
        }
        let generated;
        let uid = if let Some(uid) = event["uid"].as_str() {
            uid
        } else {
            generated = event_uid()?;
            &generated
        };
        db.execute(
            "INSERT INTO playevent (uid, session_id, song_filename, timestamp, duration_played, total_length,
             play_ratio, foreground_duration, background_duration, source, queue_id, hlc, dirty)
             VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
            params![uid, session, filename, timestamp, duration, length, ratio, fg, bg, source, queue, hlc, dirty],
        ).map_err(|error| error.to_string())?;
    }
    Ok(())
}

fn event_uid() -> Result<String, String> {
    let mut bytes = [0; 16];
    getrandom::getrandom(&mut bytes).map_err(|error| error.to_string())?;
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    let hex: String = bytes.iter().map(|byte| format!("{byte:02x}")).collect();
    Ok(format!(
        "{}-{}-{}-{}-{}",
        &hex[..8],
        &hex[8..12],
        &hex[12..16],
        &hex[16..20],
        &hex[20..]
    ))
}

fn repair(db: &mut Connection, payload: &Value) -> Result<Value, String> {
    let durations = &payload["durations"];
    in_transaction(db, |db| {
        let rows = read_rows(
            db,
            "SELECT id, song_filename, duration_played, total_length,
                                   foreground_duration, background_duration FROM playevent",
            [],
        )?;
        let mut count = 0;
        for row in rows {
            let filename = row["song_filename"].as_str().unwrap_or_default();
            let duration = row["duration_played"].as_f64().unwrap_or_default();
            let mut length = row["total_length"].as_f64().unwrap_or_default();
            if length <= 0.0 {
                length = durations[filename].as_f64().unwrap_or(length);
            }
            let target = if length > 0.0 && duration > length * 1.01 {
                length
            } else if length <= 0.0 && duration > 600.0 {
                600.0
            } else {
                continue;
            };
            let mut fg = row["foreground_duration"].as_f64().unwrap_or_default();
            let mut bg = row["background_duration"].as_f64().unwrap_or_default();
            if fg + bg > 0.0 {
                let scale = target / (fg + bg);
                fg *= scale;
                bg *= scale;
            } else {
                fg = target;
            }
            let ratio = if length > 0.0 {
                (target / length).min(1.0)
            } else {
                1.0
            };
            count += db.execute(
                "UPDATE playevent SET duration_played = ?, total_length = ?, foreground_duration = ?,
                 background_duration = ?, play_ratio = ? WHERE id = ?",
                params![target, length.max(0.0), fg, bg, ratio, row["id"].as_i64()],
            ).map_err(|error| error.to_string())?;
        }
        Ok(json!({"count": count}))
    })
}
