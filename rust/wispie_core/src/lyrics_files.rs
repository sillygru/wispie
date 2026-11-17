//! Sidecar lyrics: `.lrc` and `.ttml` files named after a song.
//!
//! Matching, TTML conversion and renaming live here so the scanner, the search
//! index and the lyrics sheet all agree on which file belongs to a song.

use crate::emitter::{Emit, Emitter};
use regex::Regex;
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use walkdir::WalkDir;

/// Only these extensions are lyrics; anything else beside a song is not ours.
const EXTENSIONS: [&str; 2] = ["lrc", "ttml"];

#[derive(Deserialize, Default)]
#[serde(default)]
struct SongRef {
    filename: String,
    url: String,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct LinkRequest {
    songs: Vec<SongRef>,
    roots: Vec<String>,
    #[serde(rename = "excludedFolders")]
    excluded_folders: Vec<String>,
    text: bool,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct RenameItem {
    paths: Vec<String>,
    #[serde(rename = "newStem")]
    new_stem: String,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct RenameRequest {
    items: Vec<RenameItem>,
}

/// Lowercase stem to the candidate files for it, best first.
pub type LyricsIndex = HashMap<String, Vec<PathBuf>>;

pub fn is_lyrics_path(path: &Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| {
            EXTENSIONS
                .iter()
                .any(|known| extension.eq_ignore_ascii_case(known))
        })
}

pub fn index_paths(paths: impl IntoIterator<Item = PathBuf>) -> LyricsIndex {
    let mut index = LyricsIndex::new();
    for path in paths {
        if !is_lyrics_path(&path) {
            continue;
        }
        let Some(stem) = path.file_stem().and_then(|stem| stem.to_str()) else {
            continue;
        };
        index.entry(stem.to_lowercase()).or_default().push(path);
    }
    for candidates in index.values_mut() {
        sort_candidates(candidates);
    }
    index
}

/// Lyrics sitting beside the songs, one listing per folder rather than a walk.
pub fn index_directories<'a>(dirs: impl IntoIterator<Item = &'a Path>) -> LyricsIndex {
    let mut paths = Vec::new();
    for dir in dirs {
        let Ok(entries) = fs::read_dir(dir) else {
            continue;
        };
        for entry in entries.flatten() {
            if entry
                .file_type()
                .map(|kind| kind.is_file())
                .unwrap_or(false)
            {
                paths.push(entry.path());
            }
        }
    }
    index_paths(paths)
}

/// Lyrics under folders the user pointed at, walked recursively.
pub fn index_roots(roots: &[String], excluded_folders: &[String]) -> LyricsIndex {
    let mut paths = Vec::new();
    for root in roots {
        let root = Path::new(root);
        if !root.is_dir() {
            continue;
        }
        for entry in WalkDir::new(root).follow_links(false) {
            let Ok(entry) = entry else {
                continue;
            };
            if !entry.file_type().is_file()
                || !is_lyrics_path(entry.path())
                || crate::scan::is_excluded(entry.path(), excluded_folders)
            {
                continue;
            }
            paths.push(entry.path().to_path_buf());
        }
    }
    index_paths(paths)
}

pub fn merge(into: &mut LyricsIndex, other: LyricsIndex) {
    for (stem, mut paths) in other {
        into.entry(stem).or_default().append(&mut paths);
    }
    for candidates in into.values_mut() {
        sort_candidates(candidates);
    }
}

pub fn lookup<'a>(index: &'a LyricsIndex, filename: &str) -> Option<&'a [PathBuf]> {
    let stem = Path::new(filename)
        .file_stem()
        .and_then(|stem| stem.to_str())?;
    index.get(&stem.to_lowercase()).map(Vec::as_slice)
}

fn index_for(songs: &[SongRef], roots: &[String], excluded_folders: &[String]) -> LyricsIndex {
    let mut index = index_roots(roots, excluded_folders);

    let mut seen = HashSet::new();
    let mut dirs: Vec<PathBuf> = Vec::new();
    for song in songs {
        let Some(parent) = Path::new(&song.url).parent() else {
            continue;
        };
        if seen.insert(parent.to_path_buf()) {
            dirs.push(parent.to_path_buf());
        }
    }
    merge(
        &mut index,
        index_directories(dirs.iter().map(PathBuf::as_path)),
    );
    index
}

fn sort_candidates(paths: &mut [PathBuf]) {
    paths.sort_by(|left, right| {
        preference(left).cmp(&preference(right)).then_with(|| {
            left.to_string_lossy()
                .to_lowercase()
                .cmp(&right.to_string_lossy().to_lowercase())
        })
    });
}

/// `.lrc` beats `.ttml`: the player reads LRC natively and a TTML file is
/// converted into one anyway, so the file already in that shape is the pick.
fn preference(path: &Path) -> u8 {
    match path.extension().and_then(|extension| extension.to_str()) {
        Some(extension) if extension.eq_ignore_ascii_case("lrc") => 0,
        _ => 1,
    }
}

/// The LRC text of one sidecar file, converting TTML on the way.
pub fn read_text(path: &Path) -> Result<String, String> {
    let bytes = fs::read(path).map_err(|error| error.to_string())?;
    let raw = String::from_utf8_lossy(&bytes);
    let text = raw.trim_start_matches('\u{feff}');
    if is_ttml(path) {
        Ok(ttml_to_lrc(text))
    } else {
        Ok(text.to_string())
    }
}

fn is_ttml(path: &Path) -> bool {
    path.extension()
        .and_then(|extension| extension.to_str())
        .is_some_and(|extension| extension.eq_ignore_ascii_case("ttml"))
}

/// Turns an Apple-style TTML file into line-synced LRC.
///
/// Word timings are not carried over: the player already estimates those from
/// line stamps, and a line-synced file is what every lyrics view parses.
pub fn ttml_to_lrc(xml: &str) -> String {
    static COMMENT: OnceLock<Regex> = OnceLock::new();
    static PARAGRAPH: OnceLock<Regex> = OnceLock::new();
    static ATTRIBUTE: OnceLock<Regex> = OnceLock::new();
    static TAG: OnceLock<Regex> = OnceLock::new();
    static LINE_BREAK: OnceLock<Regex> = OnceLock::new();
    static SPACES: OnceLock<Regex> = OnceLock::new();

    let without_comments = COMMENT
        .get_or_init(|| Regex::new(r"(?s)<!--.*?-->").unwrap())
        .replace_all(xml, "");
    let paragraph = PARAGRAPH.get_or_init(|| {
        Regex::new(r"(?s)<(?:[A-Za-z0-9_.-]+:)?p\b([^>]*)>(.*?)</(?:[A-Za-z0-9_.-]+:)?p\s*>")
            .unwrap()
    });
    let attribute =
        ATTRIBUTE.get_or_init(|| Regex::new(r#"(?i)\b(begin)\s*=\s*["']([^"']*)["']"#).unwrap());
    let tag = TAG.get_or_init(|| Regex::new(r"<[^>]*>").unwrap());
    let line_break = LINE_BREAK.get_or_init(|| Regex::new(r"(?i)<br\s*/?>").unwrap());
    let spaces = SPACES.get_or_init(|| Regex::new(r"\s+").unwrap());

    let mut lines: Vec<(i64, String)> = Vec::new();
    for capture in paragraph.captures_iter(&without_comments) {
        let Some(begin) = attribute
            .captures_iter(&capture[1])
            .next()
            .and_then(|found| timestamp_centis(&found[2]))
        else {
            continue;
        };

        let with_breaks = line_break.replace_all(&capture[2], " ");
        let without_tags = tag.replace_all(&with_breaks, "");
        let decoded = decode_entities(&without_tags);
        let text = spaces.replace_all(decoded.trim(), " ");
        if text.is_empty() {
            continue;
        }
        lines.push((begin, text.to_string()));
    }
    lines.sort_by_key(|(begin, _)| *begin);

    let mut output = String::new();
    for (centis, text) in lines {
        let minutes = centis / 6000;
        let seconds = (centis % 6000) as f64 / 100.0;
        output.push_str(&format!("[{minutes:02}:{seconds:05.2}]{text}\n"));
    }
    output
}

/// `hh:mm:ss.mmm`, `mm:ss.mmm` or plain seconds, as centiseconds.
fn timestamp_centis(raw: &str) -> Option<i64> {
    let parts: Vec<&str> = raw.trim().split(':').collect();
    let total = match parts.as_slice() {
        [seconds] => seconds.parse::<f64>().ok()?,
        [minutes, seconds] => minutes.parse::<f64>().ok()? * 60.0 + seconds.parse::<f64>().ok()?,
        [hours, minutes, seconds] => {
            hours.parse::<f64>().ok()? * 3600.0
                + minutes.parse::<f64>().ok()? * 60.0
                + seconds.parse::<f64>().ok()?
        }
        _ => return None,
    };
    if !total.is_finite() || total < 0.0 {
        return None;
    }
    Some((total * 100.0).round() as i64)
}

fn decode_entities(text: &str) -> String {
    text.replace("&lt;", "<")
        .replace("&gt;", ">")
        .replace("&quot;", "\"")
        .replace("&apos;", "'")
        .replace("&#39;", "'")
        .replace("&nbsp;", " ")
        .replace("&amp;", "&")
}

pub fn run_link(payload: Value, emitter: &Emitter) -> Result<(), String> {
    let request: LinkRequest =
        serde_json::from_value(payload).map_err(|error| format!("lyrics_link: {error}"))?;

    let index = index_for(&request.songs, &request.roots, &request.excluded_folders);
    let mut links = Vec::new();
    for song in &request.songs {
        let Some(candidates) = lookup(&index, &song.filename) else {
            continue;
        };
        let Some(primary) = candidates.first() else {
            continue;
        };

        let mut row = json!({
            "filename": song.filename,
            "path": primary.to_string_lossy(),
            "duplicates": candidates[1..]
                .iter()
                .map(|path| path.to_string_lossy().to_string())
                .collect::<Vec<_>>(),
        });
        if request.text {
            if let Ok(text) = read_text(primary) {
                row["text"] = json!(text);
            }
        }
        links.push(row);
    }

    emitter.emit(Emit::Json(json!({ "links": links })));
    Ok(())
}

pub fn run_rename(payload: Value, emitter: &Emitter) -> Result<(), String> {
    let request: RenameRequest =
        serde_json::from_value(payload).map_err(|error| format!("lyrics_rename: {error}"))?;

    let mut renames = Vec::new();
    let mut failures = Vec::new();
    for item in &request.items {
        let stem = item.new_stem.trim();
        if stem.is_empty() {
            continue;
        }
        for path in &item.paths {
            let source = Path::new(path);
            let (Some(extension), Some(parent)) = (source.extension(), source.parent()) else {
                continue;
            };
            let target = parent.join(format!("{stem}.{}", extension.to_string_lossy()));
            if target == source || !source.is_file() {
                continue;
            }
            if target.exists() {
                failures.push(json!({ "path": path, "reason": "targetExists" }));
                continue;
            }
            match fs::rename(source, &target) {
                Ok(()) => renames.push(json!({
                    "from": path,
                    "to": target.to_string_lossy(),
                })),
                Err(error) => failures.push(json!({
                    "path": path,
                    "reason": error.to_string(),
                })),
            }
        }
    }

    emitter.emit(Emit::Json(
        json!({ "renames": renames, "failures": failures }),
    ));
    Ok(())
}
