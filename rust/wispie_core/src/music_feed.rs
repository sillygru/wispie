//! The listener's own YouTube Music feed: a taste snapshot, a cleanup pass over
//! catalogue rows, and the ranking that puts what this device plays ahead of
//! what the account's shelves merely suggest.
//!
//! Both pools are music-scoped at the source, so the judging here is cleanup
//! rather than classification: it drops the stray podcast row, the Short and the
//! full programme.

use std::collections::HashMap;
use std::sync::OnceLock;

use regex::{Regex, RegexBuilder};
use serde_json::{json, Map, Value};

use crate::affinity::decay_factor;
use crate::emitter::{Emit, Emitter};
use crate::youtube::{item_from_wire, strip_topic_suffix, Item};

/// Half-life of the per-title recency discount, in days.
const RECENCY_HALF_LIFE_DAYS: f64 = 45.0;

/// Share of the final artist weight that comes from the library itself. Taste
/// leads; ownership still seeds the feed.
const LIBRARY_SHARE: f64 = 0.25;

/// Below this blended weight an artist is not worth a search slot.
const BLEND_FLOOR: f64 = 0.05;

/// Noise markers: never in the title of a track worth suggesting from a
/// catalogue that also hosts every other kind of video.
const VIDEO_NOISE: &[&str] = &[
    "official trailer",
    "trailer",
    "teaser",
    "gameplay",
    "walkthrough",
    "let's play",
    "speedrun",
    "unboxing",
    "haul",
    "vlog",
    "prank",
    "reaction",
    "tutorial",
    "how to ",
    "review",
    "press conference",
    "behind the scenes",
    "making of",
    "bloopers",
    "podcast",
    "full episode",
    "karaoke",
    // Not `tribute` on its own: "Tribute" is a real song title.
    "tribute version",
    "originally performed",
    "playlist",
    "compilation",
    "megamix",
    "interview",
    "highlights",
    "match recap",
    "news update",
    "breaking news",
    "shorts",
    "asmr",
];

/// Bylines that name the row's shape rather than an artist.
const CONTAINER_ARTISTS: &[&str] = &[
    "episode",
    "episodes",
    "song",
    "songs",
    "video",
    "videos",
    "album",
    "albums",
    "single",
    "playlist",
    "artist",
    "movie",
    "movies",
    "podcast",
    "new release",
    "various artists",
    "unknown",
    "unknown artist",
];

#[derive(Clone, Copy, PartialEq)]
enum Source {
    AccountFeed,
    LibraryArtist,
}

impl Source {
    fn from_wire(raw: Option<&Value>) -> Source {
        match raw.and_then(|value| value.as_str()) {
            Some("library_artist") => Source::LibraryArtist,
            _ => Source::AccountFeed,
        }
    }

    fn prior(self) -> f64 {
        match self {
            Source::LibraryArtist => 1.0,
            Source::AccountFeed => 0.35,
        }
    }
}

struct TasteProfile {
    artist_weights: Vec<(String, f64)>,
    top_artists: Vec<String>,
    known_video_ids: Vec<String>,
    known_track_keys: Vec<String>,
}

pub fn run(payload: &Value, emitter: &Emitter) -> Result<(), String> {
    let action = payload
        .get("action")
        .and_then(|value| value.as_str())
        .ok_or_else(|| "music_feed needs an action".to_string())?;
    let reply = match action {
        "taste_profile" => taste_profile(payload),
        "rank" => rank(payload)?,
        "artist_key" => json!({ "value": artist_key(text(payload, "value")) }),
        "display_artist" => json!({ "value": display_artist(text(payload, "value")) }),
        "title_key" => json!({ "value": title_key(text(payload, "value")) }),
        "track_key" => json!({
            "value": track_key(text(payload, "artist"), text(payload, "title")),
        }),
        "clean_title" => json!({ "value": clean_music_title(text(payload, "value")) }),
        "plausible_artist" => json!({
            "plausible": is_plausible_artist(text(payload, "value")),
        }),
        "evidence" => {
            let item = item_from_wire(payload.get("item").unwrap_or(&Value::Null));
            json!({
                "evidence": item.map(|item| music_evidence(&item)).unwrap_or_default(),
            })
        }
        "judge" => {
            let item = item_from_wire(payload.get("item").unwrap_or(&Value::Null));
            let verdict = match item {
                Some(item) => judge(&item),
                None => Verdict {
                    accepted: false,
                    reason: "no-artist".to_string(),
                },
            };
            json!({ "accepted": verdict.accepted, "reason": verdict.reason })
        }
        "score" => {
            let item = item_from_wire(payload.get("item").unwrap_or(&Value::Null));
            let taste = taste_from_wire(payload.get("taste"));
            let source = Source::from_wire(payload.get("source"));
            json!({ "score": item.map(|item| score(&item, source, &taste)).unwrap_or_default() })
        }
        "split" => match item_from_wire(payload.get("item").unwrap_or(&Value::Null)) {
            Some(item) => {
                let (artist, title) = split_title_and_artist(&item);
                json!({ "artist": artist, "title": title })
            }
            None => json!({ "artist": "", "title": "" }),
        },
        "normalize_track" => match item_from_wire(payload.get("item").unwrap_or(&Value::Null)) {
            Some(item) => json!({ "item": normalize_track(&item) }),
            None => json!({ "item": null }),
        },
        "clock_text" => json!({ "clock": is_clock_text(text(payload, "value")) }),
        other => return Err(format!("unknown music_feed action {other}")),
    };
    emitter.emit(Emit::Json(reply));
    Ok(())
}

fn text<'a>(payload: &'a Value, key: &str) -> &'a str {
    payload
        .get(key)
        .and_then(|value| value.as_str())
        .unwrap_or("")
}

// ---------------------------------------------------------------------------
// Keys and titles
// ---------------------------------------------------------------------------

fn vevo_suffix() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        RegexBuilder::new(r"\s*-?\s*vevo$")
            .case_insensitive(true)
            .build()
            .expect("vevo suffix")
    })
}

fn channel_suffix() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        Regex::new(r"\s*[-–]\s*(official|music|records|label|channel)$").expect("channel suffix")
    })
}

fn non_alnum() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"[^a-z0-9]+").expect("non alnum"))
}

/// A normalized artist name: lowercase, without YouTube's channel decoration.
///
/// `Artist - Topic`, `ArtistVEVO` and `Artist Official` are the same listener as
/// `Artist`, and matching them separately would hide half the taste history.
fn artist_key(raw: &str) -> String {
    let value = strip_topic_suffix(raw).to_lowercase();
    let value = vevo_suffix().replace(&value, "");
    let value = channel_suffix().replace(&value, "");
    let value = non_alnum().replace_all(&value, " ");
    let value = value.trim().to_string();
    let value = match value.strip_prefix("the ") {
        Some(rest) => rest.to_string(),
        None => value,
    };
    value.trim().to_string()
}

/// The name to show, with YouTube's channel decoration removed.
fn display_artist(raw: &str) -> String {
    let value = strip_topic_suffix(raw).trim().to_string();
    vevo_suffix().replace(&value, "").trim().to_string()
}

fn bracket_group() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"\(([^)]*)\)|\[([^\]]*)\]").expect("bracket group"))
}

fn bracket_noise() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        Regex::new(
            r"\b(official|oficial|videoclip|video|clip|audio|audio\s+only|lyrics?|lyric\s+video|visuali[sz]er|hd|hq|4k|8k|mv|m/v|explicit|music\s+video|remaster(ed)?|with\s+lyrics)\b",
        )
        .expect("bracket noise")
    })
}

fn trailing_upload_marker() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        RegexBuilder::new(r"\s*[|/\-–]\s*(official\s+)?(music\s+)?(video|audio|lyric\s+video)\s*$")
            .case_insensitive(true)
            .build()
            .expect("upload marker")
    })
}

fn repeated_space() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"\s{2,}").expect("repeated space"))
}

fn trailing_junk() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"[\s\-|/]+$").expect("trailing junk"))
}

/// Removes the upload decoration from a title: `(Official Video)`, `[4K]`,
/// `(Lyric Video)`, `Official Audio`. `(Live at Wembley)` and `(Acoustic)` say
/// something about the recording, so they stay.
fn clean_music_title(raw: &str) -> String {
    let value = raw.replace('_', " ");
    let value = value.trim().to_string();
    let value = bracket_group().replace_all(&value, |captures: &regex::Captures| {
        let body = captures
            .get(1)
            .or_else(|| captures.get(2))
            .map(|group| group.as_str())
            .unwrap_or_default()
            .to_lowercase();
        if bracket_noise().is_match(&body) {
            String::new()
        } else {
            captures
                .get(0)
                .map(|group| group.as_str().to_string())
                .unwrap_or_default()
        }
    });
    let value = trailing_upload_marker().replace(&value, "");
    let value = repeated_space().replace_all(&value, " ");
    let value = trailing_junk().replace(&value, "");
    value.trim().to_string()
}

/// Lowercase, bracket-stripped title with punctuation collapsed.
fn title_key(raw: &str) -> String {
    let cleaned = clean_music_title(raw).to_lowercase();
    non_alnum().replace_all(&cleaned, " ").trim().to_string()
}

/// Dedupe key for a track, independent of video id and title decoration.
fn track_key(artist: &str, title: &str) -> String {
    format!("{}|{}", artist_key(artist), title_key(title))
}

/// True when a byline is a real artist name rather than a row label.
fn is_plausible_artist(raw: &str) -> bool {
    let value = artist_key(raw);
    !value.is_empty() && !CONTAINER_ARTISTS.contains(&value.as_str())
}

fn channel_topic_suffix() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        RegexBuilder::new(r"-\s*topic$")
            .case_insensitive(true)
            .build()
            .expect("topic suffix")
    })
}

fn channel_vevo_suffix() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        RegexBuilder::new(r"vevo$")
            .case_insensitive(true)
            .build()
            .expect("vevo")
    })
}

fn music_marker() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| {
        RegexBuilder::new(
            r"\b(official\s+(music\s+)?(video|audio)|lyric\s+video|lyrics|visuali[sz]er|music\s+video|audio\s+only|remaster(ed)?|feat\.?|ft\.?|instrumental|acoustic|live\s+at|official\s+audio)\b",
        )
        .case_insensitive(true)
        .build()
        .expect("music marker")
    })
}

fn clock_text() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"^\d{1,2}:\d{2}(?::\d{2})?$").expect("clock"))
}

fn split_pattern() -> &'static Regex {
    static RE: OnceLock<Regex> = OnceLock::new();
    RE.get_or_init(|| Regex::new(r"^(.{2,60}?)\s+[-–]\s+(.+)$").expect("split"))
}

/// True when `text` looks like a clock (`3:52`).
fn is_clock_text(text: &str) -> bool {
    clock_text().is_match(text.trim())
}

/// How much a title reads like a music upload, 0..1.
fn music_evidence(item: &Item) -> f64 {
    let channel = item.artist.trim();
    let mut score: f64 = 0.0;
    if channel_topic_suffix().is_match(channel) || channel_vevo_suffix().is_match(channel) {
        score += 0.5;
    }
    if music_marker().is_match(&item.title) {
        score += 0.35;
    }
    if item.title.contains(" - ") || item.title.contains(" – ") {
        score += 0.15;
    }
    if let Some(millis) = item.duration_ms {
        let seconds = millis / 1000;
        // A single track occupies this window; anything outside it is a set, a
        // stream, a Short or a full programme.
        if (75..=8 * 60).contains(&seconds) {
            score += 0.25;
        } else if seconds < 60 {
            score -= 0.1;
        }
    }
    // A byline that is a real artist line rather than a channel name.
    if !channel.is_empty() && !channel.contains(" - ") {
        score += 0.05;
    }
    score.clamp(0.0, 1.0)
}

struct Verdict {
    accepted: bool,
    /// Kept for the probe, so the marker is part of the verdict.
    reason: String,
}

fn judge(item: &Item) -> Verdict {
    let title = item.title.to_lowercase();
    let byline = item.artist.to_lowercase();
    for marker in VIDEO_NOISE {
        if title.contains(marker) || byline.contains(marker) {
            return Verdict {
                accepted: false,
                reason: format!("noise:{marker}"),
            };
        }
    }
    if !is_plausible_artist(&item.artist) {
        return Verdict {
            accepted: false,
            reason: "no-artist".to_string(),
        };
    }
    if let Some(millis) = item.duration_ms {
        let seconds = millis / 1000;
        if seconds < 55 {
            return Verdict {
                accepted: false,
                reason: "too-short".to_string(),
            };
        }
        if seconds > 15 * 60 {
            return Verdict {
                accepted: false,
                reason: "too-long".to_string(),
            };
        }
    }
    Verdict {
        accepted: true,
        reason: "music".to_string(),
    }
}

fn score(candidate_item: &Item, source: Source, taste: &TasteProfile) -> f64 {
    let affinity = lookup(&taste.artist_weights, &artist_key(&candidate_item.artist));
    let evidence = music_evidence(candidate_item);
    let prior = source.prior();
    // Affinity dominates: a shelf YouTube suggests has to beat what this device
    // actually plays, not merely attach to it.
    0.68 * affinity + 0.18 * evidence + 0.14 * prior
}

fn lookup(weights: &[(String, f64)], key: &str) -> f64 {
    weights
        .iter()
        .find(|(candidate, _)| candidate == key)
        .map(|(_, weight)| *weight)
        .unwrap_or(0.0)
}

/// `Artist - Song` split into its parts. A title like this is the most common
/// shape for an upload that carries no artist field.
fn split_title_and_artist(item: &Item) -> (String, String) {
    let title = clean_music_title(&item.title);
    let artist = display_artist(&item.artist);
    let Some(captures) = split_pattern().captures(&title) else {
        return (artist, title);
    };
    let left = captures
        .get(1)
        .map(|group| group.as_str().trim().to_string());
    let right = captures
        .get(2)
        .map(|group| group.as_str().trim().to_string());
    let (Some(left), Some(right)) = (left, right) else {
        return (artist, title);
    };
    if left.is_empty() || right.is_empty() {
        return (artist, title);
    }

    // Only trust the split when the channel agrees with it, or when there is no
    // channel at all. `Song - Part 2` is a title, not artist and track.
    let left_key = artist_key(&left);
    let channel_key = artist_key(&artist);
    let agrees = !channel_key.is_empty()
        && (channel_key == left_key
            || channel_key.contains(&left_key)
            || left_key.contains(&channel_key));

    if channel_key.is_empty() {
        return (left, right);
    }
    if !agrees {
        return (artist, title);
    }
    (artist, right)
}

/// Normalizes one catalogue row for display and for dedupe.
fn normalize_track(item: &Item) -> Item {
    let (artist, title) = split_title_and_artist(item);
    Item {
        video_id: item.video_id.clone(),
        title,
        artist,
        duration_ms: item.duration_ms,
        thumbnail_url: item.thumbnail_url.clone(),
        position: item.position,
        view_count_text: item.view_count_text.clone(),
    }
}

// ---------------------------------------------------------------------------
// Taste
// ---------------------------------------------------------------------------

struct Signal {
    artist: String,
    title: String,
    play_count: i64,
    favorite: bool,
    video_id: Option<String>,
    age_days: Option<f64>,
}

fn signal_from_wire(value: &Value) -> Option<Signal> {
    let map = value.as_object()?;
    Some(Signal {
        artist: map
            .get("artist")
            .and_then(|value| value.as_str())
            .unwrap_or_default()
            .to_string(),
        title: map
            .get("title")
            .and_then(|value| value.as_str())
            .unwrap_or_default()
            .to_string(),
        play_count: map
            .get("play_count")
            .and_then(|value| value.as_i64())
            .unwrap_or_default(),
        favorite: map
            .get("favorite")
            .and_then(|value| value.as_bool())
            .unwrap_or(false),
        video_id: map
            .get("video_id")
            .and_then(|value| value.as_str())
            .filter(|id| !id.is_empty())
            .map(|id| id.to_string()),
        age_days: map.get("age_days").and_then(|value| value.as_f64()),
    })
}

/// Multiplier for one row's repeat plays. A row with no known last listen keeps
/// full weight; the floor keeps an abandoned favourite from vanishing.
fn recency(signal: &Signal) -> f64 {
    match signal.age_days {
        None => 1.0,
        Some(_) if signal.play_count <= 0 => 1.0,
        Some(age_days) => 0.1 + 0.9 * decay_factor(age_days, RECENCY_HALF_LIFE_DAYS),
    }
}

/// Scales the entries so the strongest is 1, dropping empty ones.
fn normalized(values: &[(String, f64)]) -> Vec<(String, f64)> {
    let usable: Vec<(String, f64)> = values
        .iter()
        .filter(|(key, value)| !key.is_empty() && *value > 0.0)
        .cloned()
        .collect();
    if usable.is_empty() {
        return Vec::new();
    }
    let strongest = usable
        .iter()
        .fold(f64::MIN, |max, (_, value)| max.max(*value));
    if strongest <= 0.0 {
        return Vec::new();
    }
    usable
        .into_iter()
        .map(|(key, value)| (key, value / strongest))
        .collect()
}

fn insert_or_add(values: &mut Vec<(String, f64)>, key: &str, weight: f64) {
    if let Some(entry) = values.iter_mut().find(|(candidate, _)| candidate == key) {
        entry.1 += weight;
    } else {
        values.push((key.to_string(), weight));
    }
}

fn insert_or_replace(values: &mut Vec<(String, f64)>, key: &str, weight: f64) {
    if let Some(entry) = values.iter_mut().find(|(candidate, _)| candidate == key) {
        entry.1 = weight;
    } else {
        values.push((key.to_string(), weight));
    }
}

fn taste_profile(payload: &Value) -> Value {
    let signals: Vec<Signal> = payload
        .get("signals")
        .and_then(|value| value.as_array())
        .map(|rows| rows.iter().filter_map(signal_from_wire).collect())
        .unwrap_or_default();
    let max_artists = payload
        .get("max_artists")
        .and_then(|value| value.as_u64())
        .unwrap_or(4) as usize;
    let artist_taste: Vec<(String, f64)> = payload
        .get("artist_taste")
        .and_then(|value| value.as_object())
        .map(|entries| {
            entries
                .iter()
                .map(|(key, value)| (key.clone(), value.as_f64().unwrap_or_default()))
                .collect()
        })
        .unwrap_or_default();

    let mut raw: Vec<(String, f64)> = Vec::new();
    let mut display: Vec<(String, String)> = Vec::new();
    let mut known_video_ids: Vec<String> = Vec::new();
    let mut known_track_keys: Vec<String> = Vec::new();

    for signal in &signals {
        let key = artist_key(&signal.artist);
        // A placeholder byline is not a taste signal, and searching it would
        // return whatever YouTube has for those words.
        if is_plausible_artist(&signal.artist) {
            // Ownership and a favorite are intent, so they do not age; repeats
            // do.
            let weight = 1.0
                + signal.play_count as f64 * recency(signal)
                + if signal.favorite { 6.0 } else { 0.0 };
            insert_or_add(&mut raw, &key, weight);
            if !display.iter().any(|(candidate, _)| candidate == &key) {
                display.push((key.clone(), display_artist(&signal.artist)));
            }
        }
        if let Some(video_id) = &signal.video_id {
            if !known_video_ids.contains(video_id) {
                known_video_ids.push(video_id.clone());
            }
        }
        if !title_key(&signal.title).is_empty() {
            let track = track_key(&signal.artist, &signal.title);
            if !known_track_keys.contains(&track) {
                known_track_keys.push(track);
            }
        }
    }

    let library = normalized(&raw);
    let mut taste_values: Vec<(String, f64)> = Vec::new();
    for (name, value) in &artist_taste {
        if *value > 0.0 {
            insert_or_replace(&mut taste_values, &artist_key(name), *value);
        }
    }
    let taste = normalized(&taste_values);
    // A taste artist whose local rows are gone still needs a searchable name.
    for (name, _) in &artist_taste {
        let key = artist_key(name);
        let trimmed = name.trim();
        if !key.is_empty() && !trimmed.is_empty() && !display.iter().any(|(c, _)| c == &key) {
            display.push((key, trimmed.to_string()));
        }
    }

    if library.is_empty() && taste.is_empty() {
        return profile_json(TasteProfile {
            artist_weights: Vec::new(),
            top_artists: Vec::new(),
            known_video_ids,
            known_track_keys,
        });
    }

    let mut blended: Vec<(String, f64)> = Vec::new();
    for (key, _) in library.iter().chain(taste.iter()) {
        if blended.iter().any(|(candidate, _)| candidate == key) {
            continue;
        }
        let weight = if taste.is_empty() {
            lookup(&library, key)
        } else {
            (1.0 - LIBRARY_SHARE) * lookup(&taste, key) + LIBRARY_SHARE * lookup(&library, key)
        };
        // An artist the listener has not touched in months sinks here rather
        // than borrowing a slot the top four artists should own.
        if weight >= BLEND_FLOOR {
            blended.push((key.clone(), weight));
        }
    }

    let weights = normalized(&blended);
    let mut ordered = weights.clone();
    // Stable: ties keep the order the artists entered the blend in.
    ordered.sort_by(|a, b| b.1.partial_cmp(&a.1).unwrap_or(std::cmp::Ordering::Equal));
    let top_artists: Vec<String> = ordered
        .iter()
        .take(max_artists)
        .filter_map(|(key, _)| {
            display
                .iter()
                .find(|(candidate, _)| candidate == key)
                .map(|(_, name)| name.clone())
        })
        .collect();

    profile_json(TasteProfile {
        artist_weights: weights,
        top_artists,
        known_video_ids,
        known_track_keys,
    })
}

fn profile_json(profile: TasteProfile) -> Value {
    let mut weights = Map::new();
    for (key, value) in &profile.artist_weights {
        weights.insert(key.clone(), json!(value));
    }
    json!({
        "artist_weights": weights,
        "top_artists": profile.top_artists,
        "known_video_ids": profile.known_video_ids,
        "known_track_keys": profile.known_track_keys,
    })
}

// ---------------------------------------------------------------------------
// Ranking
// ---------------------------------------------------------------------------

fn taste_from_wire(value: Option<&Value>) -> TasteProfile {
    let map = value.and_then(|value| value.as_object());
    let weights = map
        .and_then(|map| map.get("artist_weights"))
        .and_then(|value| value.as_object())
        .map(|entries| {
            entries
                .iter()
                .map(|(key, value)| (key.clone(), value.as_f64().unwrap_or_default()))
                .collect()
        })
        .unwrap_or_default();
    let strings = |key: &str| -> Vec<String> {
        map.and_then(|map| map.get(key))
            .and_then(|value| value.as_array())
            .map(|rows| {
                rows.iter()
                    .filter_map(|row| row.as_str().map(|row| row.to_string()))
                    .collect()
            })
            .unwrap_or_default()
    };
    TasteProfile {
        artist_weights: weights,
        top_artists: Vec::new(),
        known_video_ids: strings("known_video_ids"),
        known_track_keys: strings("known_track_keys"),
    }
}

fn rank(payload: &Value) -> Result<Value, String> {
    let taste = taste_from_wire(payload.get("taste"));
    let candidates = payload
        .get("candidates")
        .and_then(|value| value.as_array())
        .ok_or_else(|| "rank needs candidates".to_string())?;
    let limit = payload
        .get("limit")
        .and_then(|value| value.as_u64())
        .unwrap_or(18) as usize;
    let max_per_artist = payload
        .get("max_per_artist")
        .and_then(|value| value.as_u64())
        .unwrap_or(2) as usize;

    let mut scored: Vec<(Item, f64, usize)> = Vec::new();
    let mut seen_videos: Vec<String> = Vec::new();
    let mut seen_tracks: Vec<String> = Vec::new();

    for candidate in candidates {
        let source = Source::from_wire(candidate.get("source"));
        let Some(item) = item_from_wire(candidate.get("item").unwrap_or(&Value::Null)) else {
            continue;
        };
        if item.video_id.is_empty() || taste.known_video_ids.contains(&item.video_id) {
            continue;
        }
        if seen_videos.contains(&item.video_id) {
            continue;
        }
        seen_videos.push(item.video_id.clone());
        let key = track_key(&item.artist, &item.title);
        if taste.known_track_keys.contains(&key) || seen_tracks.contains(&key) {
            continue;
        }
        seen_tracks.push(key);
        if !judge(&item).accepted {
            continue;
        }
        let score = score(&item, source, &taste);
        let order = scored.len();
        scored.push((item, score, order));
    }

    scored.sort_by(|a, b| {
        b.1.partial_cmp(&a.1)
            .unwrap_or(std::cmp::Ordering::Equal)
            // Ties keep catalogue order, so the same pool always produces the
            // same feed.
            .then(a.2.cmp(&b.2))
    });

    let mut per_artist: HashMap<String, usize> = HashMap::new();
    let mut result: Vec<Item> = Vec::new();
    for (item, _, _) in scored {
        if result.len() >= limit {
            break;
        }
        let artist = artist_key(&item.artist);
        let count = per_artist.get(&artist).copied().unwrap_or(0);
        if count >= max_per_artist {
            continue;
        }
        per_artist.insert(artist, count + 1);
        result.push(item);
    }
    Ok(json!({ "items": result }))
}
