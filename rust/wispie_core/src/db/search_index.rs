use rusqlite::{params, Connection, OptionalExtension};
use serde_json::{json, Value};

use super::{in_transaction, read_rows, row_to_json, text_field, with};
use crate::search_index::{criteria, matches_json};

pub(super) fn create(db: &Connection) -> Result<(), String> {
    db.execute_batch(
        "CREATE TABLE IF NOT EXISTS search_index (
            filename TEXT PRIMARY KEY,
            title TEXT NOT NULL, artist TEXT NOT NULL, album TEXT NOT NULL,
            lyrics_content TEXT,
            title_length INTEGER NOT NULL DEFAULT 0, artist_length INTEGER NOT NULL DEFAULT 0,
            album_length INTEGER NOT NULL DEFAULT 0, lyrics_length INTEGER DEFAULT 0,
            last_modified INTEGER NOT NULL
        );
        CREATE TABLE IF NOT EXISTS search_metadata (key TEXT PRIMARY KEY, value TEXT);
        CREATE INDEX IF NOT EXISTS idx_title ON search_index(title);
        CREATE INDEX IF NOT EXISTS idx_artist ON search_index(artist);
        CREATE INDEX IF NOT EXISTS idx_album ON search_index(album);
        CREATE INDEX IF NOT EXISTS idx_lyrics ON search_index(lyrics_content);",
    )
    .map_err(|error| error.to_string())
}

pub(super) fn run(payload: &Value) -> Result<Value, String> {
    let op = text_field(payload, "op")?;
    with(payload, |db| {
        let reply = match op {
            "entries" => json!({"rows": read_rows(db,
                "SELECT filename, title, artist, album, last_modified, lyrics_content FROM search_index", [])?}),
            "entry" => json!({"rows": read_rows(db,
                "SELECT title, artist, album, last_modified, lyrics_content FROM search_index WHERE filename = ?",
                [text_field(payload, "filename")?])?}),
            "filenames" => {
                json!({"filenames": read_rows(db, "SELECT filename FROM search_index", [])?
                .into_iter().map(|row| row["filename"].clone()).collect::<Vec<_>>() })
            }
            "write" => in_transaction(db, |db| write(db, payload))?,
            "remove" => {
                db.execute(
                    "DELETE FROM search_index WHERE filename = ?",
                    [text_field(payload, "filename")?],
                )
                .map_err(|error| error.to_string())?;
                json!({})
            }
            "rename" => in_transaction(db, |db| rename(db, payload))?,
            "search" => search(db, payload)?,
            "stats" => stats(db).map_err(|error| error.to_string())?,
            "clear" => in_transaction(db, |db| {
                db.execute_batch("DELETE FROM search_index; DELETE FROM search_metadata")
                    .map_err(|error| error.to_string())?;
                Ok(json!({}))
            })?,
            _ => return Err(format!("unknown search index operation {op}")),
        };
        Ok(reply)
    })
}

fn write(db: &Connection, payload: &Value) -> Result<Value, String> {
    // A rebuild reads lyrics before committing. Its old rows must still match
    // before it overwrites a newer index edit or a rename.
    let expected = payload["expected"].as_object();
    let mut lookup = db
        .prepare_cached(
            "SELECT filename, title, artist, album, last_modified, lyrics_content
         FROM search_index WHERE filename = ?",
        )
        .map_err(|error| error.to_string())?;
    let mut can_write = |filename: &str| -> Result<bool, String> {
        let Some(expected) = expected else {
            return Ok(true);
        };
        let current = lookup
            .query_row([filename], row_to_json)
            .optional()
            .map_err(|error| error.to_string())?;
        Ok(current.as_ref() == expected.get(filename))
    };
    if let Some(remove) = payload["remove"].as_array() {
        let mut delete = db
            .prepare_cached("DELETE FROM search_index WHERE filename = ?")
            .map_err(|error| error.to_string())?;
        for filename in remove {
            let filename = filename.as_str().ok_or("invalid search index filename")?;
            if !can_write(filename)? {
                continue;
            }
            delete
                .execute([filename])
                .map_err(|error| error.to_string())?;
        }
    }
    let mut insert = db
        .prepare_cached(
            "INSERT OR REPLACE INTO search_index (filename, title, artist, album, lyrics_content,
         title_length, artist_length, album_length, lyrics_length, last_modified)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)",
        )
        .map_err(|error| error.to_string())?;
    for row in payload["rows"]
        .as_array()
        .ok_or("missing search index rows")?
    {
        let filename = text_field(row, "filename")?;
        if !can_write(filename)? {
            continue;
        }
        insert
            .execute(params![
                filename,
                row["title"].as_str(),
                row["artist"].as_str(),
                row["album"].as_str(),
                row["lyrics_content"].as_str(),
                row["title_length"].as_i64(),
                row["artist_length"].as_i64(),
                row["album_length"].as_i64(),
                row["lyrics_length"].as_i64(),
                row["last_modified"].as_i64()
            ])
            .map_err(|error| error.to_string())?;
    }
    if let (Some(updated), Some(total)) = (payload["updated"].as_i64(), payload["total"].as_u64()) {
        db.execute(
            "INSERT OR REPLACE INTO search_metadata (key, value) VALUES ('last_updated', ?), ('total_entries', ?)",
            [updated.to_string(), total.to_string()],
        ).map_err(|error| error.to_string())?;
    }
    Ok(json!({}))
}

fn rename(db: &Connection, payload: &Value) -> Result<Value, String> {
    for row in payload["renames"]
        .as_array()
        .ok_or("missing search index renames")?
    {
        let from = text_field(row, "from")?;
        let to = text_field(row, "to")?;
        if from != to {
            db.execute(
                "UPDATE OR REPLACE search_index SET filename = ?2 WHERE filename = ?1",
                params![from, to],
            )
            .map_err(|error| error.to_string())?;
        }
    }
    Ok(json!({}))
}

fn search(db: &Connection, payload: &Value) -> Result<Value, String> {
    let query = text_field(payload, "query")?.to_lowercase();
    let mut matches = json!({"query": query});
    for (column, field) in [
        ("title", "titles"),
        ("artist", "artists"),
        ("album", "albums"),
        ("lyrics_content", "lyrics"),
    ] {
        let rows = if payload[field].as_bool().unwrap_or(false) {
            let (predicate, args) = criteria(&query, column, field == "lyrics");
            read_rows(
                db,
                &format!("SELECT filename, {column} AS text FROM search_index WHERE {predicate}"),
                rusqlite::params_from_iter(args),
            )?
        } else {
            Vec::new()
        };
        matches[field] = json!(rows);
    }
    Ok(matches_json(&matches))
}

fn stats(db: &Connection) -> rusqlite::Result<Value> {
    let updated: Option<String> = db
        .query_row(
            "SELECT value FROM search_metadata WHERE key = 'last_updated'",
            [],
            |row| row.get(0),
        )
        .optional()?
        .flatten();
    db.query_row(
        "SELECT COUNT(*), COUNT(lyrics_content), COALESCE(SUM(lyrics_length), 0) FROM search_index",
        [],
        |row| {
            Ok(json!({
                "total": row.get::<_, i64>(0)?,
                "with_lyrics": row.get::<_, i64>(1)?,
                "lyrics_chars": row.get::<_, i64>(2)?,
                "updated": updated.and_then(|value| value.parse::<i64>().ok()),
            }))
        },
    )
}
