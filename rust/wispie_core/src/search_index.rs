//! Search-index rules: query predicates, lyric text extraction, the best match
//! per filename, index refresh decisions and remote-row reconciliation. Ported
//! from `search_index_repository.dart`; SQLite access stays in Dart.

use crate::model::SongJson;
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::OnceLock;

const YOUTUBE_PREFIX: &str = "youtube:";

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct MatchRow {
    filename: String,
    text: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct MatchRequest {
    query: String,
    titles: Vec<MatchRow>,
    artists: Vec<MatchRow>,
    albums: Vec<MatchRow>,
    lyrics: Vec<MatchRow>,
}

// Database rows arrive with their column names, not camelCase.
#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
struct ExistingRow {
    title: String,
    artist: String,
    album: String,
    last_modified: i64,
    lyrics_content: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct RefreshRequest {
    song: RefreshSong,
    existing: Option<ExistingRow>,
    sidecar: Option<String>,
    remote_lyrics: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct RefreshSong {
    filename: String,
    title: String,
    artist: String,
    album: String,
    mtime: Option<f64>,
    has_lyrics: bool,
    is_local: bool,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(rename_all = "camelCase")]
struct RemoteSong {
    filename: String,
    is_local: bool,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct RemotePlanRequest {
    indexed: Vec<String>,
    songs: Vec<RemoteSong>,
    previous: Option<Vec<String>>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct PlanRequest {
    songs: Vec<RefreshSong>,
    existing: Vec<PlanExisting>,
    sidecar: HashMap<String, String>,
    remote: HashMap<String, String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
struct PlanExisting {
    filename: String,
    title: String,
    artist: String,
    album: String,
    last_modified: i64,
    lyrics_content: Option<String>,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct RowRequest {
    song: SongJson,
    lyrics: Option<String>,
}

/// The searchable text of an LRC/TTML lyric: timestamps and metadata dropped.
fn timestamp_pattern() -> &'static regex::Regex {
    static PATTERN: OnceLock<regex::Regex> = OnceLock::new();
    PATTERN.get_or_init(|| regex::Regex::new(r"\[([0-9]+):([0-9]+\.?[0-9]*)\]").expect("timestamp"))
}

fn metadata_pattern() -> &'static regex::Regex {
    static PATTERN: OnceLock<regex::Regex> = OnceLock::new();
    PATTERN.get_or_init(|| regex::Regex::new(r"^\[[a-z]+:.+\]$").expect("metadata"))
}

pub fn plain_text(content: &str) -> String {
    let timestamp = timestamp_pattern();
    let metadata = metadata_pattern();
    let mut lines = Vec::new();
    for line in content.split('\n') {
        let trimmed = line.trim();
        if trimmed.is_empty() || metadata.is_match(trimmed) {
            continue;
        }
        let plain = timestamp.replace_all(trimmed, "").trim().to_string();
        if !plain.is_empty() {
            lines.push(plain);
        }
    }
    lines.join("\n")
}

/// `where`/`args` for one indexed column: every token must appear in it.
///
/// Lyrics match the whole query instead, so a phrase is not split apart.
pub fn criteria(query: &str, column: &str, whole: bool) -> (String, Vec<String>) {
    if whole {
        return (format!("{column} LIKE ?"), vec![format!("%{query}%")]);
    }
    let tokens: Vec<&str> = query.split_whitespace().collect();
    let clauses: Vec<String> = tokens.iter().map(|_| format!("{column} LIKE ?")).collect();
    let args: Vec<String> = tokens.iter().map(|token| format!("%{token}%")).collect();
    (clauses.join(" AND "), args)
}

/// The best match per filename, in first-seen order.
pub fn matches_json(request: &Value) -> Value {
    let request: MatchRequest = serde_json::from_value(request.clone()).unwrap_or_default();
    let query = request.query.to_lowercase();
    if query.is_empty() {
        return json!({ "matches": [] });
    }
    let timestamp = timestamp_pattern();

    let mut order: Vec<String> = Vec::new();
    let mut best: Vec<MatchOutput> = Vec::new();

    let mut consider = |candidate: MatchOutput| match order
        .iter()
        .position(|filename| *filename == candidate.filename)
    {
        Some(index) => {
            if rank(candidate.field) < rank(best[index].field) {
                best[index] = candidate;
            }
        }
        None => {
            order.push(candidate.filename.clone());
            best.push(candidate);
        }
    };

    for (field, rows) in [
        ("title", &request.titles),
        ("artist", &request.artists),
        ("album", &request.albums),
    ] {
        for row in rows {
            consider(MatchOutput {
                filename: row.filename.clone(),
                field,
                matched_text: if row.text.contains(&query) {
                    query.clone()
                } else {
                    row.text.clone()
                },
                full_line: None,
            });
        }
    }
    for row in &request.lyrics {
        let Some(line) = row.text.split('\n').find(|line| line.contains(&query)) else {
            continue;
        };
        let plain = timestamp.replace_all(line.trim(), "").trim().to_string();
        consider(MatchOutput {
            filename: row.filename.clone(),
            field: "lyrics",
            matched_text: query.clone(),
            full_line: Some(plain),
        });
    }

    json!({
        "matches": best
            .into_iter()
            .map(|item| json!({
                "filename": item.filename,
                "field": item.field,
                "matchedText": item.matched_text,
                "fullLine": item.full_line,
            }))
            .collect::<Vec<_>>(),
    })
}

struct MatchOutput {
    filename: String,
    field: &'static str,
    matched_text: String,
    full_line: Option<String>,
}

fn rank(field: &str) -> u8 {
    match field {
        "title" => 0,
        "artist" => 1,
        "album" => 2,
        _ => 3,
    }
}

/// One refresh decision per song, plus the lyrics already known for it.
pub fn plan_json(request: &Value) -> Value {
    let request: PlanRequest = serde_json::from_value(request.clone()).unwrap_or_default();
    let mut existing: HashMap<&str, &PlanExisting> = HashMap::new();
    for row in &request.existing {
        existing.insert(row.filename.as_str(), row);
    }

    let decisions: Vec<Value> = request
        .songs
        .iter()
        .map(|song| {
            let row = existing.get(song.filename.as_str());
            let existing_row = row.map(|row| ExistingRow {
                title: row.title.clone(),
                artist: row.artist.clone(),
                album: row.album.clone(),
                last_modified: row.last_modified,
                lyrics_content: row.lyrics_content.clone(),
            });
            let sidecar = request.sidecar.get(&song.filename).cloned();
            let remote = request.remote.get(&song.filename).cloned();
            let refresh = refresh(
                song,
                existing_row.as_ref(),
                sidecar.as_deref(),
                remote.as_deref(),
            );
            let lyrics = match refresh.source {
                "sidecar" => sidecar,
                "existing" => row.and_then(|row| row.lyrics_content.clone()),
                "remote" => remote,
                _ => None,
            };
            json!({
                "filename": song.filename,
                "skip": refresh.skip,
                "source": refresh.source,
                "lyrics": lyrics,
            })
        })
        .collect();
    let present: std::collections::HashSet<&str> = request
        .songs
        .iter()
        .map(|song| song.filename.as_str())
        .collect();
    let remove: Vec<&str> = request
        .existing
        .iter()
        .filter(|row| !present.contains(row.filename.as_str()))
        .filter(|row| !row.filename.starts_with(YOUTUBE_PREFIX))
        .map(|row| row.filename.as_str())
        .collect();
    json!({ "decisions": decisions, "remove": remove })
}

struct Refresh {
    skip: bool,
    source: &'static str,
}

fn refresh(
    song: &RefreshSong,
    existing: Option<&ExistingRow>,
    sidecar: Option<&str>,
    remote_lyrics: Option<&str>,
) -> Refresh {
    let song_mtime = song
        .mtime
        .map(|value| (value * 1000.0).round() as i64)
        .unwrap_or(0);
    let sidecar = sidecar.filter(|text| !text.is_empty());
    let metadata_matches = existing.is_some_and(|existing| {
        existing.title == song.title.to_lowercase()
            && existing.artist == song.artist.to_lowercase()
            && existing.album == song.album.to_lowercase()
    });
    let existing_lyrics = existing.and_then(|existing| existing.lyrics_content.clone());
    let lyrics_unchanged = if song.is_local {
        existing.is_some_and(|existing| song_mtime == existing.last_modified)
    } else {
        remote_lyrics.is_some() == existing_lyrics.is_some()
    };
    let sidecar_pending = sidecar.is_some() && existing_lyrics.is_none();
    let skip = existing.is_some() && lyrics_unchanged && metadata_matches && !sidecar_pending;

    let source = if skip {
        "skip"
    } else if sidecar.is_some() {
        "sidecar"
    } else if song.is_local {
        if existing_lyrics.is_some() {
            "existing"
        } else if song.has_lyrics {
            "extract"
        } else {
            "none"
        }
    } else if remote_lyrics.is_some() {
        "remote"
    } else {
        "none"
    };
    Refresh { skip, source }
}

/// Whether an index row can be left alone, and where its lyrics come from.
pub fn refresh_json(request: &Value) -> Value {
    let request: RefreshRequest = serde_json::from_value(request.clone()).unwrap_or_default();
    let refresh = refresh(
        &request.song,
        request.existing.as_ref(),
        request.sidecar.as_deref(),
        request.remote_lyrics.as_deref(),
    );
    json!({ "skip": refresh.skip, "source": refresh.source })
}

/// The streamed half of the index: stale rows to drop and rows to add.
pub fn remote_plan_json(request: &Value) -> Value {
    let request: RemotePlanRequest = serde_json::from_value(request.clone()).unwrap_or_default();
    let wanted: Vec<String> = request
        .songs
        .iter()
        .filter(|song| !song.is_local && song.filename.starts_with(YOUTUBE_PREFIX))
        .map(|song| song.filename.clone())
        .collect();
    // `indexed` is empty on the cheap pre-check, where only `unchanged` matters.

    if let Some(previous) = &request.previous {
        let same = previous.len() == wanted.len()
            && wanted.iter().all(|filename| previous.contains(filename));
        if same {
            return json!({ "unchanged": true, "wanted": wanted, "stale": [], "upsert": [] });
        }
    }

    let stale: Vec<&String> = request
        .indexed
        .iter()
        .filter(|filename| !wanted.contains(filename) && filename.starts_with(YOUTUBE_PREFIX))
        .collect();
    let upsert: Vec<&String> = wanted
        .iter()
        .filter(|filename| {
            request
                .previous
                .as_ref()
                .is_none_or(|previous| !previous.contains(filename))
        })
        .collect();

    json!({
        "unchanged": false,
        "wanted": wanted,
        "stale": stale,
        "upsert": upsert,
    })
}

/// One index row for `song`, with lyrics already lowercased by the caller.
pub fn row_json(request: &Value) -> Value {
    let request: RowRequest = serde_json::from_value(request.clone()).unwrap_or_default();
    let song = &request.song;
    let lyrics = request.lyrics;
    json!({
        "filename": song.filename,
        "title": song.title.to_lowercase(),
        "artist": song.artist.to_lowercase(),
        "album": song.album.to_lowercase(),
        "lyrics_content": lyrics,
        "title_length": utf16_len(&song.title),
        "artist_length": utf16_len(&song.artist),
        "album_length": utf16_len(&song.album),
        "lyrics_length": lyrics.as_ref().map(|text| utf16_len(text)).unwrap_or(0),
        "last_modified": song.mtime.map(|value| (value * 1000.0).round() as i64).unwrap_or(0),
    })
}

fn utf16_len(value: &str) -> usize {
    value.encode_utf16().count()
}
