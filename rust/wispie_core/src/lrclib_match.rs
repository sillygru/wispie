use std::sync::OnceLock;

use regex::Regex;
use serde_json::{json, Value};

pub fn rank(request: &Value) -> Value {
    let results = request
        .get("results")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let song = request.get("song").unwrap_or(&Value::Null);
    let prefer_plain = request
        .get("preferPlain")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    let mut ranked = results
        .iter()
        .enumerate()
        .filter(|(_, result)| usable(result))
        .map(|(index, result)| (score(result, song, prefer_plain), index))
        .collect::<Vec<_>>();
    ranked.sort_by(|(score_a, index_a), (score_b, index_b)| {
        score_b
            .total_cmp(score_a)
            .then_with(|| index_a.cmp(index_b))
    });
    json!({"indices": ranked.into_iter().map(|(_, index)| index).collect::<Vec<_>>()})
}

pub fn score_one(request: &Value) -> Value {
    let result = request.get("result").unwrap_or(&Value::Null);
    let song = request.get("song").unwrap_or(&Value::Null);
    let prefer_plain = request
        .get("preferPlain")
        .and_then(Value::as_bool)
        .unwrap_or(false);
    json!({"score": score(result, song, prefer_plain)})
}

fn usable(result: &Value) -> bool {
    boolean(result, "instrumental")
        || boolean(result, "hasSynced")
        || boolean(result, "hasPlain")
        || boolean(result, "hasRichSync")
}

fn score(result: &Value, song: &Value, prefer_plain: bool) -> f64 {
    let mut score = 0.0;
    let has_plain = boolean(result, "hasPlain");
    let has_synced = boolean(result, "hasSynced");
    let has_rich = boolean(result, "hasRichSync");
    if prefer_plain {
        if has_plain {
            score += 100.0;
        }
    } else {
        if has_synced {
            score += 100.0;
        }
        if has_rich {
            score += 15.0;
        }
    }

    if let (Some(local), Some(remote)) =
        (integer(song, "durationUs"), integer(result, "durationUs"))
    {
        let delta = (local - remote).abs();
        const EXACT_US: i64 = 2_000_000;
        const CUTOFF_US: i64 = 15_000_000;
        if delta <= EXACT_US {
            score += 50.0;
        } else if delta >= CUTOFF_US {
            score -= 25.0;
        } else {
            let span_ms = ((CUTOFF_US - EXACT_US) / 1000) as f64;
            let over_ms = ((delta - EXACT_US) / 1000) as f64;
            score += 50.0 * (1.0 - over_ms / span_ms);
        }
    }

    let result_title = string(result, "trackName");
    let song_title = string(song, "title");
    if normalize(result_title) == normalize(song_title) {
        score += 25.0;
    } else if contains_either(result_title, song_title) {
        score += 10.0;
    }

    let result_artist = string(result, "artistName");
    let song_artist = string(song, "artist");
    if normalize(result_artist) == normalize(song_artist) {
        score += 20.0;
    } else if contains_either(result_artist, song_artist) {
        score += 8.0;
    }

    if normalize(string(result, "albumName")) == normalize(string(song, "album")) {
        score += 8.0;
    }
    if boolean(result, "instrumental") {
        score -= 15.0;
    }
    score
}

fn normalize(value: &str) -> String {
    static NON_WORD: OnceLock<Regex> = OnceLock::new();
    let regex = NON_WORD.get_or_init(|| Regex::new(r"[^A-Za-z0-9_]").unwrap());
    let lowered = value.replace('\u{0130}', "i").to_lowercase();
    regex
        .replace_all(&lowered, " ")
        .split_whitespace()
        .collect::<Vec<_>>()
        .join(" ")
}

fn contains_either(a: &str, b: &str) -> bool {
    let normalized_a = normalize(a);
    let normalized_b = normalize(b);
    !normalized_a.is_empty()
        && !normalized_b.is_empty()
        && (normalized_a.contains(&normalized_b) || normalized_b.contains(&normalized_a))
}

fn boolean(value: &Value, key: &str) -> bool {
    value.get(key).and_then(Value::as_bool).unwrap_or(false)
}

fn integer(value: &Value, key: &str) -> Option<i64> {
    value.get(key).and_then(Value::as_i64)
}

fn string<'a>(value: &'a Value, key: &str) -> &'a str {
    value.get(key).and_then(Value::as_str).unwrap_or("")
}
