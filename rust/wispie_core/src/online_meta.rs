//! Provider response rules for online cover art and metadata.
//!
//! Four keyless sources answer in four different shapes, and picking a usable
//! image out of each is the part worth owning in one place. Requests, rate
//! limits and the result caches stay in `online_metadata_service.dart`.

use serde_json::{json, Value};

use crate::artwork;
use crate::emitter::{Emit, Emitter};

const AUDIO_EXTENSIONS: [&str; 10] = [
    ".mp3", ".m4a", ".flac", ".wav", ".aac", ".ogg", ".opus", ".wma", ".alac", ".aiff",
];

/// Last.fm serves this placeholder for artists it has no picture for.
const LASTFM_DUMMY_HASHES: [&str; 4] = [
    "2a96cbd8b46e442fc41c2b86b821562f",
    "c6f59c1e5e7240a4c0d427abd71f3dbb",
    "8c82560e57b2707f670149fcd45b7c4e",
    "4128a60920044723ba0790b513b2a068",
];

const MAX_SONG_COVERS: usize = 8;

pub fn run(payload: &Value, emitter: &Emitter) -> Result<(), String> {
    let action = payload
        .get("action")
        .and_then(Value::as_str)
        .ok_or_else(|| "online_meta needs an action".to_string())?;
    let reply = match action {
        "clean_tag" => json!({ "value": clean_tag(payload.get("value")) }),
        "clean_search_title" => json!({
            "value": clean_search_title(
                text(payload, "title"),
                payload.get("artist").and_then(Value::as_str),
            ),
        }),
        "song_cover_candidates" => json!({
            "candidates": song_cover_candidates(payload.get("songs")),
        }),
        "music_utils_results" => json!({
            "results": music_utils_results(payload.get("json")),
        }),
        "deezer_tracks" => json!({ "results": deezer_tracks(payload.get("json")) }),
        "deezer_image" => json!({
            "url": deezer_image(payload.get("json"), text(payload, "kind")),
        }),
        "itunes_tracks" => json!({ "results": itunes_tracks(payload.get("json")) }),
        "itunes_image" => json!({ "url": itunes_image(payload.get("json")) }),
        "lastfm_image" => json!({ "url": lastfm_image(text(payload, "html")) }),
        "merge_results" => json!({ "results": merge_results(payload.get("groups")) }),
        "candidates" => json!({ "candidates": candidates(payload.get("entries")) }),
        "cover_candidates" => json!({
            "candidates": cover_candidates(payload.get("json")),
        }),
        other => return Err(format!("unknown online_meta action {other}")),
    };
    emitter.emit(Emit::Json(reply));
    Ok(())
}

/// Trimmed text, or nothing for an empty string and for the placeholder names
/// the providers use when they have no tag at all.
fn clean_tag(value: Option<&Value>) -> Option<String> {
    let raw = value.and_then(Value::as_str)?.trim();
    if raw.is_empty() {
        return None;
    }
    match raw.to_lowercase().as_str() {
        "unknown title" | "unknown artist" | "unknown album" | "unknown" => None,
        _ => Some(raw.to_string()),
    }
}

/// A title stripped of the decoration that would only hurt a search query:
/// file extension, `(Official Video)`-style markers, a leading `Artist - ` and
/// a trailing feature credit.
fn clean_search_title(raw: &str, artist: Option<&str>) -> String {
    let mut title = raw.trim().to_string();
    if title.is_empty() {
        return title;
    }
    title = strip_audio_extension(&title);
    title = marker_pattern(r"\([^)]*(official|lyric|music|video|audio|visualizer|hd|4k)[^)]*\)")
        .replace_all(&title, "")
        .into_owned();
    title = marker_pattern(r"\[[^\]]*(official|lyric|music|video|audio|visualizer|hd|4k)[^\]]*\]")
        .replace_all(&title, "")
        .into_owned();

    let lowered = title.to_lowercase();
    let prefixed = artist
        .filter(|value| !value.is_empty())
        .is_some_and(|value| lowered.starts_with(&format!("{} - ", value.to_lowercase())));
    if prefixed {
        let artist = artist.unwrap();
        title = title[artist.len() + 3..].trim().to_string();
    } else if let Some((_, rest)) = title.split_once(" - ") {
        title = rest.trim().to_string();
    }

    title = marker_pattern(r"\b(ft|feat|featuring)[.\s].*")
        .replace_all(&title, "")
        .into_owned();
    whitespace().replace_all(&title, " ").trim().to_string()
}

fn strip_audio_extension(value: &str) -> String {
    let segment = value.rsplit('/').next().unwrap_or(value);
    let Some(dot) = segment.rfind('.') else {
        return value.to_string();
    };
    if dot == 0 {
        return value.to_string();
    }
    let suffix = segment[dot..].to_lowercase();
    if !AUDIO_EXTENSIONS.contains(&suffix.as_str()) {
        return value.to_string();
    }
    // A query is a bare title, so a pasted path keeps only its last segment.
    segment[..dot].to_string()
}

fn marker_pattern(pattern: &str) -> regex::Regex {
    regex::RegexBuilder::new(pattern)
        .case_insensitive(true)
        .build()
        .expect("static pattern")
}

fn whitespace() -> &'static regex::Regex {
    static PATTERN: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
    PATTERN.get_or_init(|| regex::Regex::new(r"\s+").expect("static pattern"))
}

/// The collection's own covers in page order, skipping a `content://` cover
/// there is no path to save as artwork.
fn song_cover_candidates(songs: Option<&Value>) -> Vec<Value> {
    let mut seen = std::collections::HashSet::new();
    let mut candidates = Vec::new();
    for song in songs
        .and_then(Value::as_array)
        .map_or(&[][..], Vec::as_slice)
    {
        let cover = song
            .get("cover_url")
            .and_then(Value::as_str)
            .unwrap_or("")
            .trim();
        if cover.is_empty() || !seen.insert(cover.to_string()) {
            continue;
        }
        if !cover.starts_with("http") && artwork::to_local_path(cover).is_none() {
            continue;
        }
        candidates.push(json!({
            "url": cover,
            "source": text(song, "title"),
        }));
        if candidates.len() == MAX_SONG_COVERS {
            break;
        }
    }
    candidates
}

fn music_utils_results(decoded: Option<&Value>) -> Vec<Value> {
    let mut results = Vec::new();
    for entry in decoded
        .and_then(Value::as_array)
        .map_or(&[][..], Vec::as_slice)
    {
        if !entry.is_object() {
            continue;
        }
        let title = string_of(entry.get("trackName"));
        let artist = string_of(entry.get("artistName"));
        if title.is_empty() || artist.is_empty() {
            continue;
        }
        let source = entry
            .get("metadataSource")
            .filter(|value| !value.is_null())
            .or_else(|| entry.get("coverUrlSource").filter(|value| !value.is_null()))
            .map_or_else(|| "music-utils".to_string(), |found| string_of(Some(found)));
        let seconds = entry.get("duration").and_then(Value::as_f64);
        results.push(json!({
            "title": title,
            "artist": artist,
            "album": string_of(entry.get("albumName")),
            "cover_url": non_empty_string(entry.get("coverUrl")),
            "source": source,
            "duration_ms": seconds.filter(|value| *value > 0.0).map(|value| (value * 1000.0).round() as i64),
        }));
    }
    results
}

fn deezer_tracks(decoded: Option<&Value>) -> Vec<Value> {
    let Some(items) = decoded
        .filter(|value| value.is_object())
        .and_then(|value| value.get("data"))
        .and_then(Value::as_array)
    else {
        return Vec::new();
    };
    let mut results = Vec::new();
    for item in items {
        if !item.is_object() {
            continue;
        }
        let title = first_string(item, &["title", "title_short"]);
        if title.is_empty() {
            continue;
        }
        let artist = nested_string(item, "artist", "name");
        let album = nested_string(item, "album", "title");
        let cover = ["cover_xl", "cover_big", "cover_medium"]
            .iter()
            .find_map(|key| {
                item.get("album")
                    .and_then(|album| album.get(*key))
                    .and_then(Value::as_str)
            })
            .map(str::to_string);
        results.push(json!({
            "title": title,
            "artist": artist,
            "album": album,
            "cover_url": cover,
            "source": "deezer",
            "duration_ms": item.get("duration").and_then(Value::as_i64).map(|seconds| seconds * 1000),
        }));
    }
    results
}

/// The first picture Deezer lists for an artist or an album.
fn deezer_image(decoded: Option<&Value>, kind: &str) -> Option<String> {
    let items = decoded
        .filter(|value| value.is_object())
        .and_then(|value| value.get("data"))
        .and_then(Value::as_array)?;
    let keys: [&str; 3] = if kind == "artist" {
        ["picture_xl", "picture_big", "picture_medium"]
    } else {
        ["cover_xl", "cover_big", "cover_medium"]
    };
    for item in items {
        if !item.is_object() {
            continue;
        }
        for key in keys {
            if let Some(value) = item.get(key).and_then(Value::as_str) {
                if !value.is_empty() {
                    return Some(value.to_string());
                }
            }
        }
    }
    None
}

fn itunes_tracks(decoded: Option<&Value>) -> Vec<Value> {
    let rows = itunes_rows(decoded);
    let mut results = Vec::new();
    for item in rows {
        let title = text(item, "trackName");
        if title.is_empty() {
            continue;
        }
        results.push(json!({
            "title": title,
            "artist": text(item, "artistName"),
            "album": text(item, "collectionName"),
            "cover_url": item.get("artworkUrl100").and_then(Value::as_str)
                .filter(|value| !value.is_empty())
                .map(upgrade_itunes_artwork),
            "source": "itunes",
            "duration_ms": item.get("trackTimeMillis").and_then(Value::as_i64),
        }));
    }
    results
}

fn itunes_image(decoded: Option<&Value>) -> Option<String> {
    for item in itunes_rows(decoded) {
        if let Some(artwork) = item.get("artworkUrl100").and_then(Value::as_str) {
            if !artwork.is_empty() {
                return Some(upgrade_itunes_artwork(artwork));
            }
        }
    }
    None
}

fn itunes_rows(decoded: Option<&Value>) -> Vec<&Value> {
    decoded
        .filter(|value| value.is_object())
        .and_then(|value| value.get("results"))
        .and_then(Value::as_array)
        .map_or(Vec::new(), |rows| {
            rows.iter().filter(|row| row.is_object()).collect()
        })
}

/// iTunes' 100px still, raised to the size the artwork picker can use.
fn upgrade_itunes_artwork(url: &str) -> String {
    url.replace("100x100bb", "600x600bb")
        .replace("100x100", "600x600")
}

/// Best image URL on a Last.fm page: a GIF bubble, the `og:image` meta tag, or
/// any avatar image, in that order.
fn lastfm_image(html: &str) -> Option<String> {
    if let Some(url) = lastfm_gif_image(html) {
        return Some(upgrade_lastfm_artwork(&url));
    }
    for pattern in [
        r#"(?i)<meta\s+[^>]*?property="og:image"\s+[^>]*?content="([^"]+)""#,
        r#"(?i)<meta\s+[^>]*?content="([^"]+)"\s+[^>]*?property="og:image""#,
    ] {
        let found = marker_pattern(pattern)
            .captures(html)
            .and_then(|captures| captures.get(1))
            .map(|value| value.as_str().to_string());
        if let Some(url) = found.filter(|url| !is_dummy_hash(url)) {
            return Some(upgrade_lastfm_artwork(&url));
        }
    }
    for captures in marker_pattern(LASTFM_IMAGE_PATTERN).captures_iter(html) {
        let Some(url) = captures.get(1) else { continue };
        if !is_dummy_hash(url.as_str()) {
            return Some(upgrade_lastfm_artwork(url.as_str()));
        }
    }
    None
}

/// `src="...fastly.../i/u/<hash>..."` cells, which are the actual pictures
/// rather than logos or links.
const LASTFM_IMAGE_PATTERN: &str =
    r#"(?i)src="([^"]*?lastfm[^"]*?fastly[^"]*?/i/u/[^/]+/([a-f0-9]+)[^"]*)""#;

/// The same pattern, but only for a cell whose alt text is `gif` - the bubble
/// Last.fm puts on an artist with no uploaded picture. The alt check has to
/// look at what follows the match, since Rust's regex crate has no lookahead.
fn lastfm_gif_image(html: &str) -> Option<String> {
    for captures in marker_pattern(LASTFM_IMAGE_PATTERN).captures_iter(html) {
        let Some(url) = captures.get(1) else { continue };
        let end = captures.get(0).map_or(0, |value| value.end());
        let tag = html[end..].split('>').next().unwrap_or("");
        if tag.to_lowercase().contains("alt=\"gif\"") && !is_dummy_hash(url.as_str()) {
            return Some(url.as_str().to_string());
        }
    }
    None
}

fn is_dummy_hash(url: &str) -> bool {
    LASTFM_DUMMY_HASHES.iter().any(|hash| url.contains(hash))
}

/// Last.fm's CDN only serves a thumbnail at the small segment sizes.
fn upgrade_lastfm_artwork(url: &str) -> String {
    url.replace("/avatar170s/", "/300x300/")
        .replace("/174s/", "/300x300/")
        .replace("/64s/", "/300x300/")
        .replace("/300x300s/", "/300x300/")
}

/// Interleaves the provider lists and drops the same title by the same artist,
/// so the first rows of every source stay near the top.
fn merge_results(groups: Option<&Value>) -> Vec<Value> {
    let groups = groups
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let longest = groups
        .iter()
        .map(|group| group.as_array().map_or(0, Vec::len))
        .max()
        .unwrap_or(0);
    let mut seen = std::collections::HashSet::new();
    let mut merged = Vec::new();
    for index in 0..longest {
        for group in &groups {
            let Some(row) = group.get(index) else {
                continue;
            };
            let key = format!(
                "{}|{}",
                text(row, "title").to_lowercase(),
                text(row, "artist").to_lowercase()
            );
            if seen.insert(key) {
                merged.push(row.clone());
            }
        }
    }
    merged
}

/// Ordered artwork candidates: the first URL wins, repeats are dropped.
fn candidates(entries: Option<&Value>) -> Vec<Value> {
    let mut seen = std::collections::HashSet::new();
    let mut kept = Vec::new();
    for entry in entries
        .and_then(Value::as_array)
        .map_or(&[][..], Vec::as_slice)
    {
        let url = text(entry, "url");
        if url.is_empty() || !seen.insert(url.to_string()) {
            continue;
        }
        kept.push(json!({ "url": url, "source": text(entry, "source") }));
    }
    kept
}

fn cover_candidates(decoded: Option<&Value>) -> Vec<Value> {
    let entries = match decoded {
        Some(Value::Array(rows)) => rows.clone(),
        Some(value) => vec![value.clone()],
        None => Vec::new(),
    };
    let mut seen = std::collections::HashSet::new();
    let mut kept = Vec::new();
    for entry in entries {
        let url = non_empty_string(entry.get("coverUrl"));
        let Some(url) = url else { continue };
        if !seen.insert(url.clone()) {
            continue;
        }
        let source = entry
            .get("coverUrlSource")
            .filter(|value| !value.is_null())
            .map_or_else(|| "music-utils".to_string(), |found| string_of(Some(found)));
        kept.push(json!({ "url": url, "source": source }));
    }
    kept
}

/// Dart's `value.toString()` over an optional JSON value.
fn string_of(value: Option<&Value>) -> String {
    match value {
        None | Some(Value::Null) => String::new(),
        Some(Value::String(text)) => text.clone(),
        Some(Value::Number(number)) => number.to_string(),
        Some(Value::Bool(flag)) => flag.to_string(),
        Some(other) => other.to_string(),
    }
}

/// A string that is not blank, kept as it was sent: the providers' padding is
/// theirs to keep, and only the emptiness check looks at the trimmed form.
fn non_empty_string(value: Option<&Value>) -> Option<String> {
    let text = value.and_then(Value::as_str)?;
    if text.trim().is_empty() {
        None
    } else {
        Some(text.to_string())
    }
}

fn first_string(value: &Value, keys: &[&str]) -> String {
    for key in keys {
        if let Some(found) = value.get(*key).filter(|found| !found.is_null()) {
            return string_of(Some(found));
        }
    }
    String::new()
}

fn nested_string(value: &Value, parent: &str, key: &str) -> String {
    value
        .get(parent)
        .and_then(|inner| inner.get(key))
        .map_or_else(String::new, |found| string_of(Some(found)))
}

fn text<'a>(value: &'a Value, key: &str) -> &'a str {
    value.get(key).and_then(Value::as_str).unwrap_or("")
}
