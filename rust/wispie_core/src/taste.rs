//! Smart shuffle's taste model: play history into decayed evidence per song and
//! per artist, plus co-play, artist transitions and library newness.
//!
//! Ported from `taste_model.dart`. Events arrive as fixed-stride rows over the
//! binary channel (the way `affinity` does) and the reply is columnar, because a
//! library-sized history would otherwise pay for JSON on both sides.

use crate::affinity::decay_factor;
use serde_json::{json, Map, Value};
use std::collections::HashMap;

const NEGATIVE_CAP: f64 = 3.0;
const FULL_LISTEN_RATIO: f64 = 0.85;
const SHORT_LISTEN_SECONDS: f64 = 3.0;
const LONG_LISTEN_SECONDS: f64 = 240.0;
const BURST_WINDOW_SECONDS: f64 = 90.0;
const FORGIVENESS_FACTOR: f64 = 0.3;
const REPLAY_BONUS: f64 = 0.5;
const CO_PLAY_TOP: usize = 20;
const ARTIST_CO_PLAY_TOP: usize = 10;
const FRESHNESS_MIN_LIBRARY_AGE_DAYS: f64 = 30.0;
const FRESHNESS_WINDOW_DAYS: f64 = 90.0;

/// filename u32 | timestamp f64 | ratio f64 | seconds f64 | session u32 | source u8
const STRIDE: usize = 33;
const NO_SESSION: u32 = u32::MAX;

/// Normalized artist key. Untagged songs get a per-file key so they never pool.
///
/// YouTube channel decoration is stripped: a streamed track credited to
/// `Aurora - Topic` or `AuroraVEVO` is the same artist as a local file tagged
/// `Aurora`.
pub fn artist_key(artist: &str, filename: &str) -> String {
    let stripped = strip_channel_decoration(artist);
    let lower = stripped.to_lowercase();
    if lower.is_empty() {
        format!("\u{0}{filename}")
    } else {
        lower
    }
}

fn strip_channel_decoration(raw: &str) -> String {
    const TOPIC: &[u8] = b" - topic";
    let mut value = raw.trim();

    if value.len() >= TOPIC.len()
        && value.as_bytes()[value.len() - TOPIC.len()..].eq_ignore_ascii_case(TOPIC)
    {
        value = value[..value.len() - TOPIC.len()].trim();
    }

    let trimmed = value.trim_end();
    if trimmed.len() >= 4 && trimmed.as_bytes()[trimmed.len() - 4..].eq_ignore_ascii_case(b"vevo") {
        let head = trimmed[..trimmed.len() - 4].trim_end();
        value = head.strip_suffix('-').map(str::trim_end).unwrap_or(head);
    }

    value.trim().to_string()
}

pub fn artist_keys_json(payload: &Value) -> Result<Value, String> {
    let items = payload
        .get("items")
        .and_then(Value::as_array)
        .ok_or_else(|| "taste_artist_keys needs items".to_string())?;
    let keys: Vec<String> = items
        .iter()
        .map(|item| {
            let row = item.as_array();
            let artist = row
                .and_then(|row| row.first())
                .and_then(Value::as_str)
                .unwrap_or("");
            let filename = row
                .and_then(|row| row.get(1))
                .and_then(Value::as_str)
                .unwrap_or("");
            artist_key(artist, filename)
        })
        .collect();
    Ok(json!({ "keys": keys }))
}

fn strings(payload: &Value, key: &str) -> Result<Vec<String>, String> {
    match payload.get(key) {
        Some(Value::Array(rows)) => Ok(rows
            .iter()
            .map(|row| row.as_str().unwrap_or("").to_string())
            .collect()),
        Some(_) => Err(format!("{key} must be an array")),
        None => Ok(Vec::new()),
    }
}

struct Event {
    file: usize,
    timestamp: f64,
    ratio: f64,
    seconds: f64,
    session: Option<usize>,
    source: u8,
}

pub fn run(payload: &Value, bytes: &[u8]) -> Result<Value, String> {
    let now = payload
        .get("now")
        .and_then(Value::as_f64)
        .ok_or_else(|| "taste_snapshot needs now".to_string())?;
    let filenames = strings(payload, "filenames")?;
    let sessions = strings(payload, "sessions")?;
    let artists = strings(payload, "artists")?;
    let added_files = strings(payload, "addedFiles")?;
    let count = payload
        .get("eventCount")
        .and_then(Value::as_u64)
        .unwrap_or(0) as usize;
    let rows_len = count * STRIDE;
    if rows_len > bytes.len() {
        return Err("taste event payload is shorter than eventCount".to_string());
    }
    let (rows, added) = bytes.split_at(rows_len);
    if added.len() != added_files.len() * 8 {
        return Err("taste added payload does not match addedFiles".to_string());
    }

    let mut events: Vec<Event> = Vec::with_capacity(count);
    for row in rows.as_chunks::<STRIDE>().0 {
        let file = u32::from_le_bytes(row[0..4].try_into().unwrap()) as usize;
        if file >= filenames.len() {
            return Err("taste event filename index is out of range".to_string());
        }
        let session = u32::from_le_bytes(row[28..32].try_into().unwrap());
        let session = if session == NO_SESSION {
            None
        } else {
            let index = session as usize;
            if index >= sessions.len() {
                return Err("taste event session index is out of range".to_string());
            }
            Some(index)
        };
        events.push(Event {
            file,
            timestamp: f64::from_le_bytes(row[4..12].try_into().unwrap()),
            ratio: f64::from_le_bytes(row[12..20].try_into().unwrap()),
            seconds: f64::from_le_bytes(row[20..28].try_into().unwrap()),
            session,
            source: row[32],
        });
    }

    events.sort_by(|a, b| {
        let left = a.session.map(|i| sessions[i].as_str()).unwrap_or("");
        let right = b.session.map(|i| sessions[i].as_str()).unwrap_or("");
        left.cmp(right)
            .then_with(|| a.timestamp.total_cmp(&b.timestamp))
    });
    let count = events.len();

    let mut ratio = vec![0.0; count];
    let mut seconds = vec![0.0; count];
    let mut quality = vec![0.0; count];
    for (index, event) in events.iter().enumerate() {
        let value = event.ratio.clamp(0.0, 1.0);
        let played = event.seconds;
        let mut q = base_quality(value);
        if played >= LONG_LISTEN_SECONDS {
            q = q.max(0.6);
        }
        ratio[index] = value;
        seconds[index] = played;
        quality[index] = q;
    }

    let burst = burst_flags(&events, &quality);
    let forgiven = forgiveness_flags(&events, &quality, &ratio);
    let replay = replay_flags(&events, &ratio);
    let artist_of: Vec<String> = filenames
        .iter()
        .enumerate()
        .map(|(index, filename)| {
            artist_key(
                artists.get(index).map(String::as_str).unwrap_or(""),
                filename,
            )
        })
        .collect();

    let mut songs: Vec<Acc> = (0..filenames.len()).map(|_| Acc::new()).collect();
    let mut song_credited = vec![false; filenames.len()];
    let mut artists_ledger = ArtistLedger::default();
    let mut co_raw: HashMap<usize, HashMap<usize, f64>> = HashMap::new();
    let mut artist_co_raw: HashMap<usize, HashMap<usize, f64>> = HashMap::new();

    for index in 0..count {
        let event = &events[index];
        let decay = decay_at((now - event.timestamp) / 86400.0);
        let q = quality[index];

        let weight = if q > 0.0 {
            q * positive_source_multiplier(event.source)
        } else if q < 0.0 {
            let mut multiplier = negative_source_multiplier(event.source);
            if seconds[index] < SHORT_LISTEN_SECONDS {
                multiplier *= 0.1;
            }
            if burst[index] {
                multiplier *= 0.15;
            }
            if forgiven[index] {
                multiplier *= FORGIVENESS_FACTOR;
            }
            q * multiplier
        } else {
            0.0
        };

        let slot = artists_ledger.slot(&artist_of[event.file]);
        song_credited[event.file] = true;
        songs[event.file].add(weight, event.timestamp, &decay, true);
        artists_ledger.accs[slot].add(weight, event.timestamp, &decay, true);
        if replay[index] {
            songs[event.file].add(REPLAY_BONUS, event.timestamp, &decay, false);
            artists_ledger.accs[slot].add(REPLAY_BONUS, event.timestamp, &decay, false);
        }

        if index > 0
            && event.session.is_some()
            && events[index - 1].session == event.session
            && quality[index - 1] >= 0.5
            && q >= 0.5
            && decay.trend > 0.0
        {
            let previous = &events[index - 1];
            if previous.file != event.file {
                *co_raw
                    .entry(previous.file)
                    .or_default()
                    .entry(event.file)
                    .or_insert(0.0) += decay.trend;
            }
            let previous_artist = artists_ledger.slot(&artist_of[previous.file]);
            if previous_artist != slot {
                *artist_co_raw
                    .entry(previous_artist)
                    .or_default()
                    .entry(slot)
                    .or_insert(0.0) += decay.trend;
            }
        }
    }

    let artist_keys = artists_ledger.names.clone();
    let mut song_order: Vec<usize> = Vec::new();
    for (index, credited) in song_credited.iter().enumerate() {
        if *credited {
            song_order.push(index);
        }
    }

    let reply = json!({
        "songs": {
            "filenames": song_order.iter().map(|i| json!(filenames[*i])).collect::<Vec<_>>(),
            "trendMass": song_order.iter().map(|i| json!(songs[*i].trend_mass())).collect::<Vec<_>>(),
            "longMass": song_order.iter().map(|i| json!(songs[*i].long_mass())).collect::<Vec<_>>(),
            "saturation": song_order.iter().map(|i| json!(songs[*i].saturation)).collect::<Vec<_>>(),
            "skipRate": song_order.iter().map(|i| json!(songs[*i].skip_rate())).collect::<Vec<_>>(),
            "playCount": song_order.iter().map(|i| json!(songs[*i].play_count)).collect::<Vec<_>>(),
            "lastPlayed": song_order.iter().map(|i| if songs[*i].last_played.is_finite() {
                json!(songs[*i].last_played)
            } else {
                Value::Null
            }).collect::<Vec<_>>(),
        },
        "artists": {
            "keys": artists_ledger.names,
            "trendMass": artists_ledger.accs.iter().map(|acc| json!(acc.trend_mass())).collect::<Vec<_>>(),
            "longMass": artists_ledger.accs.iter().map(|acc| json!(acc.long_mass())).collect::<Vec<_>>(),
        },
        "coPlay": top_normalized(co_raw, &filenames, CO_PLAY_TOP),
        "artistCoPlay": top_normalized(artist_co_raw, &artist_keys, ARTIST_CO_PLAY_TOP),
        "newness": freshness_of(&added_files, added, now),
    });
    Ok(reply)
}

/// Base evidence of one play from how much of it was heard.
fn base_quality(ratio: f64) -> f64 {
    if ratio >= FULL_LISTEN_RATIO {
        return 1.0;
    }
    if ratio >= 0.5 {
        return 0.5 + 0.5 * (ratio - 0.5) / 0.35;
    }
    if ratio >= 0.25 {
        return 0.5 * (ratio - 0.25) / 0.25;
    }
    -1.0
}

/// Skips that are one of at least three within 90 s in the same session.
/// Events are sorted by session then time, so a two-pointer window suffices.
fn burst_flags(events: &[Event], quality: &[f64]) -> Vec<bool> {
    let mut burst = vec![false; events.len()];
    let mut group_start = 0;
    while group_start < events.len() {
        let mut group_end = group_start + 1;
        while group_end < events.len() && events[group_end].session == events[group_start].session {
            group_end += 1;
        }
        if events[group_start].session.is_some() {
            let skips: Vec<usize> = (group_start..group_end)
                .filter(|index| quality[*index] < 0.0)
                .collect();
            let mut low = 0usize;
            let mut high: isize = -1;
            for index in 0..skips.len() {
                let stamp = events[skips[index]].timestamp;
                while high + 1 < skips.len() as isize
                    && events[skips[(high + 1) as usize]].timestamp <= stamp + BURST_WINDOW_SECONDS
                {
                    high += 1;
                }
                while low < skips.len()
                    && events[skips[low]].timestamp < stamp - BURST_WINDOW_SECONDS
                {
                    low += 1;
                }
                if high - low as isize >= 2 {
                    burst[skips[index]] = true;
                }
            }
        }
        group_start = group_end;
    }
    burst
}

/// A skip is forgiven if the same song was fully heard at some later time.
fn forgiveness_flags(events: &[Event], quality: &[f64], ratio: &[f64]) -> Vec<bool> {
    let mut forgiven = vec![false; events.len()];
    let mut order: Vec<usize> = (0..events.len()).collect();
    order.sort_by(|&a, &b| events[b].timestamp.total_cmp(&events[a].timestamp));
    let mut completed_later: HashMap<usize, ()> = HashMap::new();
    for index in order {
        let file = events[index].file;
        if quality[index] < 0.0 && completed_later.contains_key(&file) {
            forgiven[index] = true;
        }
        if ratio[index] >= FULL_LISTEN_RATIO {
            completed_later.insert(file, ());
        }
    }
    forgiven
}

/// Marks the second full listen of a song within one session.
fn replay_flags(events: &[Event], ratio: &[f64]) -> Vec<bool> {
    let mut replay = vec![false; events.len()];
    let mut completions: HashMap<(usize, usize), i32> = HashMap::new();
    for (index, event) in events.iter().enumerate() {
        let Some(session) = event.session else {
            continue;
        };
        if ratio[index] < FULL_LISTEN_RATIO {
            continue;
        }
        let count = completions.entry((session, event.file)).or_insert(0);
        *count += 1;
        if *count == 2 {
            replay[index] = true;
        }
    }
    replay
}

fn positive_source_multiplier(source: u8) -> f64 {
    match source {
        3 => 1.4, // queued
        1 => 1.3, // manual
        2 => 0.8, // shuffle
        _ => 1.0,
    }
}

fn negative_source_multiplier(source: u8) -> f64 {
    match source {
        2 => 1.0, // shuffle
        3 => 0.5, // queued
        1 => 0.3, // manual
        _ => 0.6,
    }
}

struct Decay {
    long: f64,
    trend: f64,
    neg: f64,
    neg_trend: f64,
    sat: f64,
}

/// Positive evidence decays on the long/trend half-lives. Negative evidence
/// decays fast (10 days) so old skips stop mattering quickly.
fn decay_at(age_days: f64) -> Decay {
    let age = age_days.max(0.0);
    let neg = decay_factor(age, 10.0);
    Decay {
        long: decay_factor(age, 90.0),
        trend: if age <= 30.0 {
            decay_factor(age, 10.0)
        } else {
            0.0
        },
        neg,
        neg_trend: if age <= 30.0 { neg } else { 0.0 },
        sat: decay_factor(age, 2.0),
    }
}

#[derive(Default)]
struct ArtistLedger {
    index: HashMap<String, usize>,
    names: Vec<String>,
    accs: Vec<Acc>,
}

impl ArtistLedger {
    fn slot(&mut self, key: &str) -> usize {
        if let Some(index) = self.index.get(key) {
            return *index;
        }
        let index = self.names.len();
        self.names.push(key.to_string());
        self.accs.push(Acc::new());
        self.index.insert(key.to_string(), index);
        index
    }
}

struct Acc {
    pos_long: f64,
    neg_long: f64,
    pos_trend: f64,
    neg_trend: f64,
    saturation: f64,
    skip_w: f64,
    total_w: f64,
    play_count: i64,
    last_played: f64,
}

impl Acc {
    fn new() -> Self {
        Self {
            pos_long: 0.0,
            neg_long: 0.0,
            pos_trend: 0.0,
            neg_trend: 0.0,
            saturation: 0.0,
            skip_w: 0.0,
            total_w: 0.0,
            play_count: 0,
            last_played: f64::NEG_INFINITY,
        }
    }

    fn long_mass(&self) -> f64 {
        (self.pos_long - self.neg_long.min(NEGATIVE_CAP)).max(0.0)
    }

    fn trend_mass(&self) -> f64 {
        (self.pos_trend - self.neg_trend.min(NEGATIVE_CAP)).max(0.0)
    }

    fn skip_rate(&self) -> f64 {
        if self.total_w > 0.0 {
            self.skip_w / self.total_w
        } else {
            0.0
        }
    }

    fn add(&mut self, weight: f64, timestamp: f64, decay: &Decay, count_play: bool) {
        let magnitude = weight.abs();
        if weight > 0.0 {
            self.pos_long += weight * decay.long;
            self.pos_trend += weight * decay.trend;
            self.saturation += decay.sat;
        } else {
            self.neg_long += magnitude * decay.neg;
            self.neg_trend += magnitude * decay.neg_trend;
        }
        if weight < 0.0 {
            self.skip_w += magnitude * decay.long;
        }
        self.total_w += magnitude * decay.long;
        if count_play {
            self.play_count += 1;
            self.last_played = self.last_played.max(timestamp);
        }
    }
}

fn top_normalized(
    raw: HashMap<usize, HashMap<usize, f64>>,
    names: &[String],
    top: usize,
) -> Map<String, Value> {
    let mut out = Map::new();
    for (source, row) in raw {
        let mut entries: Vec<(usize, f64)> =
            row.into_iter().filter(|(_, value)| *value > 0.0).collect();
        if entries.is_empty() {
            continue;
        }
        entries.sort_by(|a, b| b.1.total_cmp(&a.1));
        entries.truncate(top);
        let peak = entries[0].1;
        let mut normalized = Map::new();
        for (target, value) in entries {
            normalized.insert(names[target].clone(), json!(value / peak));
        }
        out.insert(names[source].clone(), Value::Object(normalized));
    }
    out
}

/// 0..1 newness per filename, relative to the library's own age distribution.
fn freshness_of(files: &[String], added: &[u8], now: f64) -> Value {
    let values: Vec<f64> = added
        .as_chunks::<8>()
        .0
        .iter()
        .map(|chunk| f64::from_le_bytes(*chunk))
        .collect();

    let mut ages: Vec<f64> = values
        .iter()
        .filter(|value| value.is_finite() && **value > 0.0)
        .map(|value| ((now - value) / 86400.0).clamp(0.0, 36500.0))
        .collect();
    let empty = json!({ "filenames": Vec::<String>::new(), "values": Vec::<f64>::new() });
    if files.len() < 2 || ages.len() < 2 {
        return empty;
    }
    ages.sort_by(f64::total_cmp);

    let median = ages[ages.len() / 2];
    if median < FRESHNESS_MIN_LIBRARY_AGE_DAYS {
        return empty;
    }
    let window = if median < FRESHNESS_WINDOW_DAYS {
        median
    } else {
        FRESHNESS_WINDOW_DAYS
    };

    let mut names: Vec<&String> = Vec::new();
    let mut scores: Vec<f64> = Vec::new();
    for (index, added) in values.iter().enumerate() {
        if !added.is_finite() || *added <= 0.0 {
            continue;
        }
        let age = (now - added) / 86400.0;
        let fresh = (1.0 - age / window).clamp(0.0, 1.0);
        if fresh > 0.0 {
            names.push(&files[index]);
            scores.push(fresh);
        }
    }
    json!({ "filenames": names, "values": scores })
}
