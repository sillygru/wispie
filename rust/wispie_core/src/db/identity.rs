use rusqlite::params;
use serde_json::{json, Value};

use super::{in_transaction, read_rows, text_field, with};

pub(super) fn run(payload: &Value) -> Result<Value, String> {
    let op = text_field(payload, "op")?;
    with(payload, |db| {
        if op == "list" {
            return Ok(
                json!({"rows": read_rows(db, "SELECT filename, cid, mtime, status FROM song_identity", [])?}),
            );
        }
        in_transaction(db, |db| {
            match op {
                "upsert" | "learn" => {
                    let sql = if op == "learn" {
                        "INSERT OR IGNORE INTO song_identity (filename, cid, mtime, status, seen_at) VALUES (?, ?, ?, ?, ?)"
                    } else {
                        "INSERT OR REPLACE INTO song_identity (filename, cid, mtime, status, seen_at) VALUES (?, ?, ?, ?, ?)"
                    };
                    let now = payload["now"]
                        .as_f64()
                        .ok_or("missing identity timestamp")?;
                    let mut statement =
                        db.prepare_cached(sql).map_err(|error| error.to_string())?;
                    for row in payload["rows"].as_array().ok_or("missing identities")? {
                        let status = if op == "learn" {
                            1
                        } else {
                            row["status"].as_i64().unwrap_or(0)
                        };
                        statement
                            .execute(params![
                                text_field(row, "filename")?,
                                text_field(row, "cid")?,
                                row["mtime"].as_f64(),
                                status,
                                now
                            ])
                            .map_err(|error| error.to_string())?;
                    }
                }
                "status" => {
                    let status = payload["status"]
                        .as_i64()
                        .ok_or("missing identity status")?;
                    let mut statement = db
                        .prepare_cached("UPDATE song_identity SET status = ? WHERE filename = ?")
                        .map_err(|error| error.to_string())?;
                    for name in super::string_list(payload, "filenames") {
                        statement
                            .execute(params![status, name])
                            .map_err(|error| error.to_string())?;
                    }
                }
                _ => return Err(format!("unknown identity operation {op}")),
            }
            Ok(json!({}))
        })
    })
}
