use std::path::Path;

use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Value};

use super::{in_transaction, read_rows, text_field, with};

pub(super) fn run(payload: &Value) -> Result<Value, String> {
    let op = text_field(payload, "op")?;
    with(payload, |db| {
        if op == "delete" {
            in_transaction(db, |db| delete(db, text_field(payload, "filename")?))?;
            return Ok(json!({}));
        }
        let renames = parse_renames(payload)?;
        let hlc = payload["hlc"].as_i64().ok_or("missing rename clock")?;
        let now = payload["now"].as_f64().unwrap_or_default();
        match op {
            "rename_data" => apply_data(db, &renames, hlc, now)?,
            "rename_stats" => apply_stats(db, &renames, hlc)?,
            _ => return Err(format!("unknown song file operation {op}")),
        }
        Ok(json!({}))
    })
}

pub(super) fn parse_renames(payload: &Value) -> Result<Vec<(&str, &str)>, String> {
    payload["renames"]
        .as_array()
        .ok_or("missing renames")?
        .iter()
        .map(|entry| Ok((text_field(entry, "from")?, text_field(entry, "to")?)))
        .collect()
}

pub(super) fn apply_data(
    data: &mut Connection,
    renames: &[(&str, &str)],
    hlc: i64,
    now: f64,
) -> Result<(), String> {
    in_transaction(data, |data| {
        for &(from, to) in renames {
            if from != to {
                rename_data(data, from, to, hlc, now)?;
            }
        }
        Ok(())
    })
}

pub(super) fn apply_stats(
    stats: &mut Connection,
    renames: &[(&str, &str)],
    hlc: i64,
) -> Result<(), String> {
    in_transaction(stats, |stats| {
        for &(from, to) in renames {
            if from != to {
                stats
                    .execute(
                        "UPDATE playevent SET song_filename = ?2, hlc = ?3, dirty = 1
                     WHERE song_filename = ?1",
                        params![from, to, hlc],
                    )
                    .map_err(|error| error.to_string())?;
            }
        }
        Ok(())
    })
}

fn rename_data(db: &Connection, from: &str, to: &str, hlc: i64, now: f64) -> Result<(), String> {
    let result = (|| -> rusqlite::Result<()> {
        let source = db
            .query_row("SELECT url FROM song WHERE filename = ?", [from], |row| {
                row.get::<_, Option<String>>(0)
            })
            .optional()?;
        // Recovery can replay a completed rename. The destination is only a
        // stale library row if the source still exists.
        if let Some(url) = source {
            let url = url.map(|url| {
                Path::new(&url)
                    .parent()
                    .unwrap_or_else(|| Path::new(""))
                    .join(to)
                    .to_string_lossy()
                    .into_owned()
            });
            db.execute("DELETE FROM song WHERE filename = ?", [to])?;
            db.execute(
                "UPDATE song SET filename = ?2, url = ?3 WHERE filename = ?1",
                params![from, to, url],
            )?;
        }

        for (table, stamped) in [
            ("lyrics_timing_offset", false),
            ("cover_miss", false),
            ("favorite", true),
            ("suggestless", true),
            ("hidden", true),
        ] {
            db.execute(
                &format!(
                    "DELETE FROM {table} WHERE filename = ?1 AND EXISTS
                         (SELECT 1 FROM {table} WHERE filename = ?2)"
                ),
                params![from, to],
            )?;
            let stamp = if stamped { ", hlc = ?3, dirty = 1" } else { "" };
            let sql = format!("UPDATE {table} SET filename = ?2{stamp} WHERE filename = ?1");
            if stamped {
                db.execute(&sql, params![from, to, hlc])?;
            } else {
                db.execute(&sql, params![from, to])?;
            }
        }
        db.execute(
            "DELETE FROM translated_lyrics AS source WHERE filename = ?1 AND EXISTS
                    (SELECT 1 FROM translated_lyrics AS target WHERE target.filename = ?2
                     AND target.target_lang = source.target_lang)",
            params![from, to],
        )?;
        db.execute(
            "UPDATE translated_lyrics SET filename = ?2 WHERE filename = ?1",
            params![from, to],
        )?;
        db.execute(
            "UPDATE merged_song SET filename = ?2, hlc = ?3, dirty = 1 WHERE filename = ?1",
            params![from, to, hlc],
        )?;
        db.execute(
            "UPDATE merged_song_group SET priority_filename = ?2, hlc = ?3, dirty = 1
                    WHERE priority_filename = ?1",
            params![from, to, hlc],
        )?;
        db.execute(
            "DELETE FROM playlist_song AS source WHERE song_filename = ?1 AND EXISTS
                    (SELECT 1 FROM playlist_song AS target WHERE target.song_filename = ?2
                     AND target.playlist_id = source.playlist_id)",
            params![from, to],
        )?;
        db.execute(
            "UPDATE playlist_song SET song_filename = ?2, hlc = ?3, dirty = 1
                    WHERE song_filename = ?1",
            params![from, to, hlc],
        )?;

        db.execute(
            "INSERT OR REPLACE INTO song_identity (filename, cid, mtime, status, seen_at)
                    SELECT ?2, source.cid, source.mtime, 0, ?3 FROM song_identity AS source
                    WHERE source.filename = ?1 AND NOT EXISTS (SELECT 1 FROM song_identity AS target
                       WHERE target.filename = ?2 AND target.cid = source.cid)",
            params![from, to, now],
        )?;
        db.execute(
            "UPDATE song_identity SET status = 2 WHERE filename = ?",
            [from],
        )?;
        Ok(())
    })();
    result.map_err(|error| error.to_string())?;

    let touched = read_rows(
        db,
        "SELECT DISTINCT snapshot_id FROM queue_snapshot_song WHERE song_filename = ?",
        [from],
    )?;
    db.execute(
        "UPDATE queue_snapshot_song SET song_filename = ?2 WHERE song_filename = ?1",
        params![from, to],
    )
    .map_err(|error| error.to_string())?;
    for row in touched {
        let id = text_field(&row, "snapshot_id")?;
        let songs = read_rows(db,
            "SELECT song_filename FROM queue_snapshot_song WHERE snapshot_id = ? ORDER BY position ASC", [id])?;
        let songs: Vec<_> = songs.iter().map(|row| &row["song_filename"]).collect();
        db.execute(
            "UPDATE queue_snapshot SET songs_json = ?, hlc = ?, dirty = 1 WHERE id = ?",
            params![json!(songs).to_string(), hlc, id],
        )
        .map_err(|error| error.to_string())?;
    }
    Ok(())
}

fn delete(db: &Connection, filename: &str) -> Result<(), String> {
    for table in [
        "song",
        "song_identity",
        "lyrics_timing_offset",
        "favorite",
        "suggestless",
        "hidden",
        "merged_song",
    ] {
        db.execute(
            &format!("DELETE FROM {table} WHERE filename = ?"),
            [filename],
        )
        .map_err(|error| error.to_string())?;
    }
    db.execute(
        "DELETE FROM merged_song_group WHERE id NOT IN
                (SELECT group_id FROM merged_song WHERE group_id IS NOT NULL)",
        [],
    )
    .map_err(|error| error.to_string())?;
    db.execute(
        "DELETE FROM playlist_song WHERE song_filename = ?",
        [filename],
    )
    .map_err(|error| error.to_string())?;
    Ok(())
}
