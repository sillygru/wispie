//! Pure bulk rename planning. Filesystem existence checks stay in Dart because
//! their providers include document-tree APIs that are not visible to Rust.

use crate::emitter::{Emit, Emitter};
use regex::Regex;
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::sync::OnceLock;

#[derive(Deserialize, Default)]
#[serde(default)]
struct Request {
    songs: Vec<Song>,
    segments: Vec<Segment>,
    #[serde(rename = "windowsPaths")]
    windows_paths: bool,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct Song {
    title: String,
    artist: String,
    album: String,
    filename: String,
    url: String,
    song_date_epoch_sec: Option<f64>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct Segment {
    token: Option<String>,
    literal: String,
}

pub fn run(payload: Value, emitter: &Emitter) -> Result<(), String> {
    let request: Request =
        serde_json::from_value(payload).map_err(|e| format!("bulk rename: {e}"))?;
    let mut claimed = HashMap::<String, String>::new();
    let mut plans = Vec::with_capacity(request.songs.len());
    emitter.emit(Emit::Progress {
        done: 0,
        total: request.songs.len() as u64,
    });
    let progress_step = (request.songs.len() / 100).max(1);
    for (index, song) in request.songs.iter().enumerate() {
        let stem = render_stem(&request.segments, song, index, request.windows_paths);
        let extension = extension(&song.url, request.windows_paths);
        let filename = format!("{stem}{extension}");
        let dirname = dirname(&song.url, request.windows_paths);
        let url = join(&dirname, &filename, request.windows_paths);
        let mut reason = None;
        let mut conflict = None;
        if stem.is_empty() {
            reason = Some("noTitleText");
        } else if filename == song.filename {
            reason = Some("alreadyNamed");
        } else {
            let key = format!("{}\0{}", dirname, filename.to_lowercase());
            if let Some(holder) = claimed.get(&key) {
                reason = Some("sameNameAs");
                conflict = Some(holder.clone());
            } else {
                claimed.insert(key, song.filename.clone());
            }
        }
        plans.push(json!({
            "index": index,
            "newStem": stem,
            "newFilename": filename,
            "newUrl": url,
            "skipReason": reason,
            "conflictingFilename": conflict,
        }));
        if (index + 1) % progress_step == 0 || index + 1 == request.songs.len() {
            emitter.emit(Emit::Progress {
                done: (index + 1) as u64,
                total: request.songs.len() as u64,
            });
        }
    }
    emitter.emit(Emit::Json(json!({ "plans": plans })));
    Ok(())
}

fn render_stem(segments: &[Segment], song: &Song, index: usize, windows: bool) -> String {
    let parts: Vec<String> = segments
        .iter()
        .filter_map(|segment| {
            let value = match segment.token.as_deref() {
                None => segment.literal.clone(),
                Some("title") => song.title.clone(),
                Some("artist") => song.artist.clone(),
                Some("album") => song.album.clone(),
                Some("stem") => basename_without_extension(&song.filename, windows),
                Some("track") => (index + 1).to_string(),
                Some("year") => song
                    .song_date_epoch_sec
                    .filter(|epoch| *epoch > 0.0)
                    .map(|epoch| year_from_epoch(epoch).to_string())
                    .unwrap_or_default(),
                Some(_) => String::new(),
            };
            let trimmed = value.trim();
            (!trimmed.is_empty()).then(|| trimmed.to_string())
        })
        .collect();
    sanitize(&parts.join(" "))
}

fn sanitize(raw: &str) -> String {
    static ILLEGAL: OnceLock<Regex> = OnceLock::new();
    static SPACE: OnceLock<Regex> = OnceLock::new();
    static COLLAPSE: OnceLock<Regex> = OnceLock::new();
    static TRAILING: OnceLock<Regex> = OnceLock::new();
    static LEADING: OnceLock<Regex> = OnceLock::new();
    let mut value = ILLEGAL
        .get_or_init(|| Regex::new(r#"[/\\:*?"<>|\x00-\x1F]"#).unwrap())
        .replace_all(raw, " ")
        .into_owned();
    value = SPACE
        .get_or_init(|| Regex::new(r"\s+").unwrap())
        .replace_all(&value, " ")
        .trim()
        .to_string();
    let collapse = COLLAPSE.get_or_init(|| Regex::new(r"\s*[-–—]\s*(?:[-–—]\s*)+").unwrap());
    while collapse.is_match(&value) {
        value = collapse.replace_all(&value, " - ").into_owned();
    }
    value = TRAILING
        .get_or_init(|| Regex::new(r"[.\s]+$").unwrap())
        .replace_all(&value, "")
        .trim()
        .to_string();
    LEADING
        .get_or_init(|| Regex::new(r"^[-–—]+\s*").unwrap())
        .replace(&value, "")
        .into_owned()
}

fn year_from_epoch(epoch: f64) -> i32 {
    let millis = (epoch * 1000.0).round() as i64;
    chrono::DateTime::from_timestamp_millis(millis)
        .map(|dt| dt.with_timezone(&chrono::Local).year())
        .unwrap_or(1970)
}

use chrono::Datelike;

fn is_sep(c: char, windows: bool) -> bool {
    c == '/' || (windows && c == '\\')
}

fn basename(path: &str, windows: bool) -> &str {
    path.rsplit(|c| is_sep(c, windows)).next().unwrap_or(path)
}

fn basename_without_extension(path: &str, windows: bool) -> String {
    let base = basename(path, windows);
    match base.rfind('.') {
        Some(0) | None => base.to_string(),
        Some(index) => base[..index].to_string(),
    }
}

fn extension(path: &str, windows: bool) -> &str {
    let base = basename(path, windows);
    match base.rfind('.') {
        Some(index) if index > 0 => &base[index..],
        _ => "",
    }
}

fn dirname(path: &str, windows: bool) -> String {
    let Some(index) = path.rfind(|c| is_sep(c, windows)) else {
        return ".".to_string();
    };
    if index == 0 {
        return path[..1].to_string();
    }
    path[..index].to_string()
}

fn join(dir: &str, filename: &str, windows: bool) -> String {
    if dir == "." || dir.is_empty() {
        return filename.to_string();
    }
    let separator = if windows { '\\' } else { '/' };
    format!(
        "{}{}{}",
        dir.trim_end_matches(|c| is_sep(c, windows)),
        separator,
        filename
    )
}
