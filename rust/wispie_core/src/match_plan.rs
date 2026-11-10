//! Name-first, one-to-one matching for batch replacement.

use serde::Deserialize;
use serde_json::json;
use std::collections::{HashMap, HashSet};

const MINIMUM_CONFIDENCE: f64 = 0.55;
const LENGTH_CLOSE_MS: i64 = 3_000;
const LENGTH_LOOSE_MS: i64 = 10_000;
const LENGTH_WARNING_MS: i64 = 30_000;
const LENGTH_IMPOSSIBLE_MS: i64 = 60_000;

const STOP_WORDS: &[&str] = &[
    "the",
    "a",
    "an",
    "and",
    "of",
    "to",
    "in",
    "on",
    "with",
    "feat",
    "ft",
    "official",
    "audio",
    "video",
    "lyrics",
    "lyric",
    "hd",
    "hq",
    "remaster",
    "remastered",
    "explicit",
    "prod",
    "version",
    "mix",
    "music",
    "mv",
    "4k",
];

#[derive(Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct SongRef {
    filename: String,
    path: String,
    title: String,
    artist: String,
    album: String,
    duration_ms: Option<i64>,
}

pub fn run(request: serde_json::Value) -> Result<serde_json::Value, String> {
    let library: Vec<SongRef> =
        serde_json::from_value(request.get("library").cloned().unwrap_or_default())
            .map_err(|error| format!("match library: {error}"))?;
    let candidates: Vec<SongRef> =
        serde_json::from_value(request.get("candidates").cloned().unwrap_or_default())
            .map_err(|error| format!("match candidates: {error}"))?;
    let library_names: HashSet<String> =
        library.iter().map(|s| s.filename.to_lowercase()).collect();
    let library_index: HashMap<&str, &SongRef> =
        library.iter().map(|s| (s.filename.as_str(), s)).collect();
    let mut scored = Vec::new();
    for (candidate_index, candidate) in candidates.iter().enumerate() {
        if library_names.contains(&candidate.filename.to_lowercase()) {
            continue;
        }
        let candidate_keys = keys_for(
            candidate.title.as_str(),
            candidate.artist.as_str(),
            candidate.path_or_filename(),
        );
        for song in &library {
            let score = score(song, candidate, &candidate_keys);
            if let Some(mut value) = score {
                value.candidate_index = candidate_index;
                scored.push(value);
            }
        }
    }
    scored.sort_by(|a, b| {
        b.confidence.total_cmp(&a.confidence).then_with(|| {
            candidates[a.candidate_index]
                .filename
                .cmp(&candidates[b.candidate_index].filename)
        })
    });
    let mut taken_songs = HashSet::new();
    let mut taken_candidates = HashSet::new();
    let mut proposals = Vec::new();
    for entry in scored {
        let candidate_path = candidates[entry.candidate_index].path_or_filename();
        if taken_songs.contains(&entry.library_filename)
            || taken_candidates.contains(candidate_path)
        {
            continue;
        }
        taken_songs.insert(entry.library_filename.clone());
        taken_candidates.insert(candidate_path.to_string());
        proposals.push(json!({
            "filename": entry.library_filename,
            "candidateIndex": entry.candidate_index,
            "confidence": entry.confidence,
            "signals": entry.signals,
            "lengthDiffers": entry.length_differs,
        }));
    }
    proposals.sort_by(|a, b| {
        let a_score = a["confidence"].as_f64().unwrap_or(0.0);
        let b_score = b["confidence"].as_f64().unwrap_or(0.0);
        let a_name = a["filename"].as_str().unwrap_or("");
        let b_name = b["filename"].as_str().unwrap_or("");
        let at = library_index
            .get(a_name)
            .map_or(a_name, |s| s.title.as_str())
            .to_lowercase();
        let bt = library_index
            .get(b_name)
            .map_or(b_name, |s| s.title.as_str())
            .to_lowercase();
        b_score.total_cmp(&a_score).then_with(|| at.cmp(&bt))
    });
    let unmatched: Vec<usize> = candidates
        .iter()
        .enumerate()
        .filter_map(|(i, c)| (!taken_candidates.contains(c.path_or_filename())).then_some(i))
        .collect();
    Ok(
        json!({ "proposals": proposals, "unmatched": unmatched, "libraryCompared": library.len(), "candidatesCompared": candidates.len() }),
    )
}

impl SongRef {
    fn path_or_filename(&self) -> &str {
        if self.path.is_empty() {
            &self.filename
        } else {
            &self.path
        }
    }
}

struct NameKeys {
    title: Option<String>,
    strong: Vec<String>,
    tokens: HashSet<String>,
}
struct ArtistCompare {
    score: f64,
    exact: bool,
    conflict: bool,
}
struct Scored {
    library_filename: String,
    candidate_index: usize,
    confidence: f64,
    signals: Vec<&'static str>,
    length_differs: bool,
}

fn score(song: &SongRef, candidate: &SongRef, candidate_keys: &NameKeys) -> Option<Scored> {
    let library_keys = keys_for(&song.title, &song.artist, &song.filename);
    let title_exact = library_keys.title.is_some()
        && candidate_keys.title.is_some()
        && library_keys.title == candidate_keys.title;
    let name_exact = shares_key(&library_keys.strong, &candidate_keys.strong);
    let mut points = 0.0;
    let mut signals = Vec::new();
    if title_exact || name_exact {
        points += 0.55;
        signals.push(if title_exact { "title" } else { "filename" });
    } else if reads_as_same(&library_keys, candidate_keys) {
        points += 0.28;
    } else {
        return None;
    }
    let artist = compare_artists(&song.artist, &candidate.artist);
    points += artist.score;
    if artist.exact {
        signals.push("artist");
    }
    if artist.conflict && !title_exact {
        return None;
    }
    if same_text(&song.album, &candidate.album) {
        points += 0.05;
        signals.push("album");
    }
    let mut length_differs = false;
    if let (Some(a), Some(b)) = (song.duration_ms, candidate.duration_ms) {
        if a > 0 && b > 0 {
            let difference = (a - b).abs();
            if difference <= LENGTH_CLOSE_MS {
                points += 0.12;
                signals.push("duration");
            } else if difference <= LENGTH_LOOSE_MS {
                points += 0.06;
            } else if difference <= LENGTH_WARNING_MS {
                points += 0.02;
                length_differs = true;
            } else if difference <= LENGTH_IMPOSSIBLE_MS {
                length_differs = true;
            } else if !(title_exact && artist.exact) {
                return None;
            }
        }
    }
    if points < MINIMUM_CONFIDENCE {
        return None;
    }
    Some(Scored {
        library_filename: song.filename.clone(),
        candidate_index: 0,
        confidence: points.min(1.0),
        signals,
        length_differs,
    })
}

fn clean(value: &str) -> String {
    let mut out = String::new();
    let mut pending_space = false;
    for c in value.chars().flat_map(char::to_lowercase) {
        if c.is_alphanumeric() {
            if pending_space && !out.is_empty() {
                out.push(' ');
            }
            pending_space = false;
            out.push(c);
        } else {
            pending_space = true;
        }
    }
    out
}
fn basename_without_extension(path: &str) -> String {
    let name = path.rsplit(['/', '\\']).next().unwrap_or(path);
    match name.rfind('.') {
        Some(i) => name[..i].to_string(),
        None => name.to_string(),
    }
}
fn keys_for(title: &str, artist: &str, path: &str) -> NameKeys {
    let title_tag = clean(title);
    let artist_tag = clean(artist);
    let stem = basename_without_extension(path);
    let mut strong = Vec::new();
    let mut add = |value: &str| {
        let text = clean(value);
        if !text.is_empty() && !strong.contains(&text) {
            strong.push(text);
        }
    };
    add(&stem);
    let stripped = strip_track_number(&stem);
    add(&stripped);
    let without = strip_brackets(&stripped);
    add(&without);
    if !artist_tag.is_empty() {
        for value in [&stripped, &without] {
            let c = clean(value);
            if c.starts_with(&artist_tag) {
                let offset = artist_tag.len();
                let rest = value
                    .get(offset..)
                    .unwrap_or("")
                    .trim_start_matches(|c: char| {
                        c.is_whitespace() || matches!(c, '-' | '–' | '—' | ':' | '|')
                    });
                add(rest);
            }
        }
    }
    let mut tokens = HashSet::new();
    for key in &strong {
        tokens.extend(
            key.split_whitespace()
                .filter(|w| !STOP_WORDS.contains(w))
                .map(str::to_string),
        );
    }
    NameKeys {
        title: if title_tag.is_empty() {
            None
        } else {
            Some(title_tag)
        },
        strong,
        tokens,
    }
}
fn strip_track_number(value: &str) -> String {
    let chars: Vec<char> = value.chars().collect();
    let mut i = 0;
    loop {
        let start = i;
        let mut digits = 0;
        while i < chars.len() && chars[i].is_ascii_digit() && digits < 3 {
            i += 1;
            digits += 1;
        }
        if digits == 0 {
            break;
        }
        while i < chars.len() && chars[i].is_whitespace() {
            i += 1;
        }
        if i < chars.len() && matches!(chars[i], '-' | '.' | '_') {
            i += 1;
            while i < chars.len() && chars[i].is_whitespace() {
                i += 1;
            }
        } else {
            i = start;
            break;
        }
        if i >= chars.len() || !chars[i].is_ascii_digit() {
            break;
        }
    }
    chars[i..].iter().collect()
}
fn strip_brackets(value: &str) -> String {
    let mut out = String::new();
    let mut skip = None;
    for c in value.chars() {
        if skip.is_some() {
            if c == ')' || c == ']' {
                skip = None;
            }
            continue;
        }
        if c == '(' || c == '[' {
            skip = Some(c);
            continue;
        }
        out.push(c);
    }
    out
}
fn shares_key(a: &[String], b: &[String]) -> bool {
    a.iter().any(|left| b.iter().any(|right| left == right))
}
fn reads_as_same(a: &NameKeys, b: &NameKeys) -> bool {
    for left in &a.strong {
        for right in &b.strong {
            if left.len() >= 6 && right.len() >= 6 && (left.contains(right) || right.contains(left))
            {
                return true;
            }
        }
    }
    tokens_contained(&a.tokens, &b.tokens) || tokens_contained(&b.tokens, &a.tokens)
}
fn tokens_contained(small: &HashSet<String>, large: &HashSet<String>) -> bool {
    if small.is_empty()
        || large.is_empty()
        || !small.iter().all(|v| large.contains(v))
        || large.len() - small.len() > 3
    {
        return false;
    }
    small.len() >= 2 || small.iter().next().is_some_and(|word| word.len() >= 6)
}
fn compare_artists(a: &str, b: &str) -> ArtistCompare {
    let left = clean(a);
    let right = clean(b);
    if left.is_empty() || right.is_empty() {
        return ArtistCompare {
            score: 0.0,
            exact: false,
            conflict: false,
        };
    }
    if left == right {
        return ArtistCompare {
            score: 0.18,
            exact: true,
            conflict: false,
        };
    }
    if left.contains(&right) || right.contains(&left) {
        return ArtistCompare {
            score: 0.09,
            exact: false,
            conflict: false,
        };
    }
    let left_tokens: HashSet<_> = left
        .split_whitespace()
        .filter(|t| !STOP_WORDS.contains(t))
        .collect();
    if right
        .split_whitespace()
        .filter(|t| !STOP_WORDS.contains(t))
        .any(|t| left_tokens.contains(t))
    {
        return ArtistCompare {
            score: 0.09,
            exact: false,
            conflict: false,
        };
    }
    ArtistCompare {
        score: -0.45,
        exact: false,
        conflict: true,
    }
}
fn same_text(a: &str, b: &str) -> bool {
    let left = clean(a);
    !left.is_empty() && left == clean(b)
}
