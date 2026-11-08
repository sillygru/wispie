//! Search ranking and typo-tolerant matching, ported from `search_ranking.dart`
//! and `SearchService._fuzzyFieldCost`. Both run on every keystroke.

use crate::emitter::{Emit, Emitter};
use crate::model::{
    FuzzyField, FuzzyMatch, FuzzyRequest, FuzzySong, PrepareRequest, RankRequest, RankResult,
};
use serde_json::json;
use std::cmp::Ordering;
use std::sync::{OnceLock, RwLock};

const FUZZY_LIMIT: usize = 30;

pub fn rank(request: RankRequest, emitter: &Emitter) -> Result<(), String> {
    let query = request.query.to_lowercase();
    let query = query.trim();
    if query.is_empty() {
        let order: Vec<usize> = (0..request.results.len()).collect();
        emitter.emit(Emit::Json(json!({ "order": order })));
        return Ok(());
    }

    let tokens: Vec<&str> = query.split_whitespace().collect();

    // Keys are computed once per result instead of once per comparison.
    let mut keyed: Vec<RankKey> = Vec::with_capacity(request.results.len());
    for (index, result) in request.results.iter().enumerate() {
        let text = matched_text(result);
        keyed.push(RankKey {
            index,
            priority: priority_of(result),
            score: word_match_score(&text, &tokens),
            taste: result.taste,
            position: match_position(&text, query),
        });
    }

    keyed.sort_by(|a, b| {
        a.priority
            .cmp(&b.priority)
            .then_with(|| a.score.cmp(&b.score))
            .then_with(|| b.taste.partial_cmp(&a.taste).unwrap_or(Ordering::Equal))
            .then_with(|| a.position.cmp(&b.position))
            .then_with(|| {
                let left = request.results[a.index].title.to_lowercase();
                let right = request.results[b.index].title.to_lowercase();
                left.cmp(&right)
            })
            // Dart's sort is unstable, so exact ties had no defined order.
            .then_with(|| a.index.cmp(&b.index))
    });

    let order: Vec<usize> = keyed.iter().map(|key| key.index).collect();
    emitter.emit(Emit::Json(json!({ "order": order })));
    Ok(())
}

struct RankKey {
    index: usize,
    priority: u8,
    score: u8,
    taste: f64,
    position: usize,
}

/// 0 for a title hit, then artist, album and lyrics.
fn priority_of(result: &RankResult) -> u8 {
    if result.matched_title {
        0
    } else if result.matched_artist {
        1
    } else if result.matched_album {
        2
    } else if result.lyrics_line.is_some() {
        3
    } else {
        4
    }
}

fn matched_text(result: &RankResult) -> String {
    let text = match &result.lyrics_line {
        Some(line) => line.as_str(),
        None if result.matched_title => result.title.as_str(),
        None if result.matched_artist => result.artist.as_str(),
        None if result.matched_album => result.album.as_str(),
        None => "",
    };
    text.to_lowercase()
}

/// 0 for a whole word, 1 for a word prefix, 2 otherwise.
fn word_match_score(text: &str, tokens: &[&str]) -> u8 {
    if text.is_empty() {
        return 2;
    }
    let words = word_split(text);
    if words.is_empty() {
        return 2;
    }

    let mut score = 0;
    for token in tokens {
        if words.iter().any(|word| word == token) {
            continue;
        }
        if words.iter().any(|word| word.starts_with(token)) {
            if score < 1 {
                score = 1;
            }
            continue;
        }
        return 2;
    }
    score
}

fn match_position(text: &str, query: &str) -> usize {
    if text.is_empty() {
        return 999_999;
    }
    text.find(query).unwrap_or(999_999)
}

static PREPARED: OnceLock<RwLock<Option<Prepared>>> = OnceLock::new();

struct Prepared {
    generation: u64,
    songs: Vec<FuzzySong>,
}

fn prepared_slot() -> &'static RwLock<Option<Prepared>> {
    PREPARED.get_or_init(|| RwLock::new(None))
}

/// Stages the whole library once, so a keystroke only crosses with its tokens.
pub fn prepare(request: PrepareRequest, emitter: &Emitter) -> Result<(), String> {
    let count = request.songs.len();
    let mut slot = prepared_slot()
        .write()
        .map_err(|_| "search cache poisoned".to_string())?;
    *slot = Some(Prepared {
        generation: request.generation,
        songs: request.songs,
    });
    emitter.emit(Emit::Json(json!({ "count": count })));
    Ok(())
}

pub fn fuzzy(request: FuzzyRequest, emitter: &Emitter) -> Result<(), String> {
    let guard = prepared_slot()
        .read()
        .map_err(|_| "search cache poisoned".to_string())?;
    let prepared = guard
        .as_ref()
        .ok_or_else(|| "search corpus not prepared".to_string())?;
    // The caller re-stages and retries when another isolate replaced the corpus.
    if prepared.generation != request.generation {
        return Err("stale search corpus".to_string());
    }

    let songs = &prepared.songs;
    let mut scored: Vec<Scored> = Vec::new();

    for (index, song) in songs.iter().enumerate() {
        if request.exclude.iter().any(|name| name == song.filename()) {
            continue;
        }
        if let Some((field, cost)) = first_matching_field(song, &request) {
            scored.push(Scored {
                cost: cost * 10 + field.rank() as i64,
                field,
                taste: song.taste(),
                index,
            });
        }
    }

    scored.sort_by(|a, b| {
        a.cost
            .cmp(&b.cost)
            .then_with(|| b.taste.partial_cmp(&a.taste).unwrap_or(Ordering::Equal))
            .then_with(|| {
                let left = songs[a.index].title().to_lowercase();
                let right = songs[b.index].title().to_lowercase();
                left.cmp(&right)
            })
            .then_with(|| a.index.cmp(&b.index))
    });

    let matches: Vec<FuzzyMatch> = scored
        .into_iter()
        .take(FUZZY_LIMIT)
        .map(|hit| FuzzyMatch {
            index: hit.index,
            field: hit.field,
        })
        .collect();
    emitter.emit(Emit::Json(json!({ "matches": matches })));
    Ok(())
}

struct Scored {
    cost: i64,
    field: FuzzyField,
    taste: f64,
    index: usize,
}

/// Field order is also the rank: a title hit beats an artist hit.
fn first_matching_field(song: &FuzzySong, request: &FuzzyRequest) -> Option<(FuzzyField, i64)> {
    for field in fields_of(request) {
        let lower = text_of(song, field).to_lowercase();
        if let Some(cost) = fuzzy_field_cost(&request.tokens, &lower) {
            return Some((field, cost));
        }
    }
    None
}

fn fields_of(request: &FuzzyRequest) -> Vec<FuzzyField> {
    let mut fields = Vec::new();
    if request.titles {
        fields.push(FuzzyField::Songs);
    }
    if request.artists {
        fields.push(FuzzyField::Artists);
    }
    if request.albums {
        fields.push(FuzzyField::Albums);
    }
    fields
}

fn text_of(song: &FuzzySong, field: FuzzyField) -> &str {
    match field {
        FuzzyField::Songs => song.title(),
        FuzzyField::Artists => song.artist(),
        FuzzyField::Albums => song.album(),
    }
}

/// Total typo cost if every token matches some word within tolerance.
fn fuzzy_field_cost(tokens: &[String], text: &str) -> Option<i64> {
    if text.is_empty() {
        return None;
    }
    let words = word_split(text);
    let mut total = 0i64;

    for token in tokens {
        let token_units: Vec<u16> = token.encode_utf16().collect();
        let token_len = token_units.len();
        let max_cost = if token_len <= 3 {
            0
        } else if token_len <= 7 {
            1
        } else {
            2
        };

        let mut best: Option<i64> = None;
        for word in &words {
            let word_units: Vec<u16> = word.encode_utf16().collect();
            if word_units.len() < token_len.saturating_sub(max_cost) {
                continue;
            }
            // Prefix compare so a half-typed, slightly wrong word still matches.
            let head = if word_units.len() > token_len {
                &word_units[..token_len]
            } else {
                &word_units[..]
            };
            let distance = edit_distance(&token_units, head, max_cost as i64);
            if distance <= max_cost as i64 && best.map(|b| distance < b).unwrap_or(true) {
                best = Some(distance);
            }
        }
        total += best?;
    }
    Some(total)
}

/// Optimal string alignment distance, over UTF-16 units like `codeUnitAt`.
fn edit_distance(a: &[u16], b: &[u16], limit: i64) -> i64 {
    let limit = limit.max(0) as usize;
    if a.len().abs_diff(b.len()) > limit {
        return limit as i64 + 1;
    }

    let mut prev2 = vec![0usize; b.len() + 1];
    let mut prev: Vec<usize> = (0..=b.len()).collect();
    let mut cur = vec![0usize; b.len() + 1];

    for i in 1..=a.len() {
        cur[0] = i;
        let mut row_min = cur[0];
        for j in 1..=b.len() {
            let cost = usize::from(a[i - 1] != b[j - 1]);
            let mut value = prev[j - 1] + cost;
            if prev[j] + 1 < value {
                value = prev[j] + 1;
            }
            if cur[j - 1] + 1 < value {
                value = cur[j - 1] + 1;
            }
            if i > 1
                && j > 1
                && a[i - 1] == b[j - 2]
                && a[i - 2] == b[j - 1]
                && prev2[j - 2] + 1 < value
            {
                value = prev2[j - 2] + 1;
            }
            cur[j] = value;
            if value < row_min {
                row_min = value;
            }
        }
        if row_min > limit {
            return limit as i64 + 1;
        }
        std::mem::swap(&mut prev2, &mut prev);
        std::mem::swap(&mut prev, &mut cur);
    }
    prev[b.len()] as i64
}

/// Splits on anything that is not a letter or a digit, as `[^\p{L}\p{N}]+`.
fn word_split(text: &str) -> Vec<String> {
    let mut words = Vec::new();
    let mut current = String::new();
    for ch in text.chars() {
        if ch.is_alphanumeric() {
            current.push(ch);
        } else if !current.is_empty() {
            words.push(std::mem::take(&mut current));
        }
    }
    if !current.is_empty() {
        words.push(current);
    }
    words
}
