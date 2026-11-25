//! Small rule sets that used to live in Dart: the lyrics timing offset, LRCLIB
//! query cleanup, version comparison, backup stats, the decode-gate order,
//! cached waveform decoding and search-taste scoring.
//!
//! These are one-shot or per-event helpers, not per-frame: a JSON request is
//! cheaper than a dedicated export per function.

use crate::artwork;
use crate::emitter::{Emit, Emitter};
use crate::lyrics_view;
use crate::playback;
use serde_json::{json, Value};

const WAVEFORM_MAGIC: [u8; 4] = [0x57, 0x53, 0x50, 0x33];
const TASTE_ARTIST_WEIGHT: f64 = 0.55;
const TASTE_SONG_WEIGHT: f64 = 0.45;

pub fn run(request: Value, bytes: Option<&[u8]>, emitter: &Emitter) -> Result<(), String> {
    let action = request
        .get("action")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string();

    match action.as_str() {
        "playback_stats" => emitter.emit(Emit::Json(playback::stats_record(&request)?)),
        "playback_variant" => emitter.emit(Emit::Json(playback::variant_pick(&request)?)),
        "playback_variant_batch" => {
            emitter.emit(Emit::Json(playback::variant_pick_batch(&request)?));
        }
        "playback_original_order" => {
            emitter.emit(Emit::Json(playback::original_order(&request)?));
        }
        "playback_queue_original" => {
            emitter.emit(Emit::Json(playback::queue_original(&request)?));
        }
        "timing_quantize" => {
            let seconds = number(&request, "seconds")?;
            let step = request
                .get("step")
                .and_then(Value::as_f64)
                .unwrap_or(lyrics_view::TIMING_QUANTIZE_STEP);
            emitter.emit(Emit::Json(json!({
                "value": lyrics_view::quantize_offset(seconds, step),
            })));
        }
        "timing_clamp" => {
            let seconds = number(&request, "seconds")?;
            emitter.emit(Emit::Json(json!({
                "value": lyrics_view::clamp_offset(seconds),
            })));
        }
        "cover_key" => {
            let key =
                artwork::content_key(bytes.ok_or_else(|| "cover_key needs bytes".to_string())?);
            emitter.emit(Emit::Json(json!({ "key": key })));
        }
        "timing_nudge" => {
            let current = number(&request, "current")?;
            let steps = number(&request, "steps")?;
            emitter.emit(Emit::Json(json!({
                "value": lyrics_view::nudge_offset(current, steps),
            })));
        }
        "timing_sync" => {
            let position_us = integer(&request, "positionUs")?;
            let active = request.get("activeUs").and_then(Value::as_i64);
            emitter.emit(Emit::Json(json!({
                "value": lyrics_view::sync_offset_us(position_us, active),
            })));
        }
        "timing_apply" => {
            let position_us = integer(&request, "positionUs")?;
            let offset = number(&request, "offset")?;
            emitter.emit(Emit::Json(json!({
                "valueUs": lyrics_view::apply_offset(position_us, offset),
            })));
        }
        "timing_undo" => {
            let lyric_us = integer(&request, "lyricUs")?;
            let offset = number(&request, "offset")?;
            emitter.emit(Emit::Json(json!({
                "valueUs": lyrics_view::undo_offset(lyric_us, offset),
            })));
        }
        "lrclib_clean" => {
            let title = text(&request, "title")?;
            let artist = request.get("artist").and_then(Value::as_str);
            emitter.emit(Emit::Json(json!({
                "title": lyrics_view::clean_search_title(title, artist),
            })));
        }
        "lrclib_queries" => {
            let title = text(&request, "title")?;
            let artist = request.get("artist").and_then(Value::as_str).unwrap_or("");
            let remote = request
                .get("remote")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            let queries: Vec<Value> = lyrics_view::queries_for(title, artist, remote)
                .into_iter()
                .map(|query| json!([query.title, query.artist]))
                .collect();
            emitter.emit(Emit::Json(json!({ "queries": queries })));
        }
        "lyrics_timings" => {
            let lines = request
                .get("lines")
                .and_then(Value::as_array)
                .ok_or_else(|| "lyrics_timings needs lines".to_string())?;
            let mut packed: Vec<[i64; 7]> = Vec::with_capacity(lines.len());
            for line in lines {
                let row = line
                    .as_array()
                    .ok_or_else(|| "lyrics_timings line must be an array".to_string())?;
                let line_us = row.first().and_then(Value::as_i64).unwrap_or(0);
                let timed = row.get(1).and_then(Value::as_bool).unwrap_or(false);
                let simulated = row.get(2).and_then(Value::as_bool).unwrap_or(false);
                let words = row.get(3).and_then(Value::as_array);
                let mut starts: Vec<i64> = Vec::new();
                let mut ends: Vec<i64> = Vec::new();
                if let Some(words) = words {
                    for word in words {
                        let Some(pair) = word.as_array() else {
                            continue;
                        };
                        let start = pair.first().and_then(Value::as_i64).unwrap_or(0);
                        let end = pair.get(1).and_then(Value::as_i64).unwrap_or(0);
                        starts.push(start);
                        ends.push(end);
                    }
                }
                let timing = lyrics_view::resolve_timing(
                    line_us,
                    timed,
                    Some(starts.as_slice()),
                    Some(ends.as_slice()),
                    simulated,
                );
                packed.push(lyrics_view::pack_timing(timing));
            }
            emitter.emit(Emit::Json(json!({ "timings": packed })));
        }
        "cover_sniff" => {
            let head_only = request
                .get("headOnly")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            emitter.emit(Emit::Json(artwork::sniff_json(bytes, head_only)));
        }
        "cover_find" => {
            let directory = text(&request, "dir")?;
            let key = text(&request, "key")?;
            let found = artwork::find_existing(std::path::Path::new(directory), key);
            emitter.emit(Emit::Json(json!({ "path": found })));
        }
        "cover_save" => artwork::emit_save(&request, bytes, emitter)?,
        "version_compare" => {
            let a = text(&request, "a")?;
            let b = text(&request, "b")?;
            emitter.emit(Emit::Json(json!({ "value": compare_versions(a, b) })));
        }
        "version_classify" => {
            let previous = request.get("previous").and_then(Value::as_str);
            let current = text(&request, "current")?;
            emitter.emit(Emit::Json(
                json!({ "kind": classify_version(previous, current) }),
            ));
        }
        "auth_username" => {
            let name = text(&request, "name")?;
            emitter.emit(Emit::Json(json!({
                "ok": !name.is_empty(),
                "value": name,
            })));
        }
        "fun_stats" => {
            let insights = request
                .get("insights")
                .ok_or_else(|| "fun_stats needs insights".to_string())?;
            let library_size = request
                .get("librarySize")
                .and_then(Value::as_i64)
                .unwrap_or(0);
            emitter.emit(Emit::Json(json!({
                "stats": fun_stats(insights, library_size),
            })));
        }
        "warm_order" => {
            let count = integer(&request, "count")?.max(0) as usize;
            let current = integer(&request, "current")?;
            let mut order: Vec<usize> = Vec::with_capacity(count);
            if count <= 1 || current < 0 || current as usize >= count {
                order.extend(0..count);
            } else {
                for offset in 1..=count {
                    order.push((current as usize + offset) % count);
                }
            }
            emitter.emit(Emit::Json(json!({ "order": order })));
        }
        "waveform_bars" => {
            let bars = waveform_bars(bytes.unwrap_or(&[]));
            emitter.emit(Emit::Json(json!({ "bars": bars })));
        }
        "repair_placeholder" => {
            let song: crate::model::SongJson = serde_json::from_value(
                request
                    .get("song")
                    .cloned()
                    .ok_or_else(|| "repair_placeholder needs song".to_string())?,
            )
            .map_err(|error| error.to_string())?;
            emitter.emit(Emit::Json(json!({
                "value": crate::library_repair::is_placeholder(&song),
            })));
        }
        "repair_merge" => {
            let local: crate::model::SongJson = serde_json::from_value(
                request
                    .get("local")
                    .cloned()
                    .ok_or_else(|| "repair_merge needs local".to_string())?,
            )
            .map_err(|error| error.to_string())?;
            let imported: crate::model::SongJson = serde_json::from_value(
                request
                    .get("imported")
                    .cloned()
                    .ok_or_else(|| "repair_merge needs imported".to_string())?,
            )
            .map_err(|error| error.to_string())?;
            emitter.emit(Emit::Json(json!(crate::library_repair::merge_song_rows(
                &local, &imported
            ))));
        }
        "repair_decide" => {
            let current: crate::model::SongJson = serde_json::from_value(
                request
                    .get("current")
                    .cloned()
                    .ok_or_else(|| "repair_decide needs current".to_string())?,
            )
            .map_err(|error| error.to_string())?;
            let probe: crate::library_repair::ProbeInput = serde_json::from_value(
                request
                    .get("probe")
                    .cloned()
                    .ok_or_else(|| "repair_decide needs probe".to_string())?,
            )
            .map_err(|error| error.to_string())?;
            let drop = request
                .get("dropUnresolvable")
                .and_then(Value::as_bool)
                .unwrap_or(true);
            let decision = crate::library_repair::decide_repair(&current, &probe.into(), drop);
            emitter.emit(Emit::Json(json!({
                "action": decision.action,
                "row": decision.row,
                "coverRepointed": decision.cover_repointed,
                "coverCleared": decision.cover_cleared,
                "urlReresolved": decision.url_reresolved,
            })));
        }
        "stats_stamp" => {
            let stats = request
                .get("stats")
                .and_then(Value::as_object)
                .cloned()
                .unwrap_or_default();
            let mut event = stats;
            event.insert(
                "platform".to_string(),
                Value::String(text(&request, "platform")?.to_string()),
            );
            event.insert(
                "session_id".to_string(),
                Value::String(text(&request, "sessionId")?.to_string()),
            );
            event.insert(
                "device_id".to_string(),
                Value::String(text(&request, "deviceId")?.to_string()),
            );
            event.insert(
                "timestamp".to_string(),
                json!(number(&request, "timestamp")?),
            );
            emitter.emit(Emit::Json(json!({ "event": event })));
        }
        "stats_flush" => {
            let background = request
                .get("background")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            let pending = integer(&request, "pending")?.max(0);
            emitter.emit(Emit::Json(json!({ "flush": !background || pending >= 50 })));
        }
        "stats_trim" => {
            let pending = integer(&request, "pending")?.max(0);
            let max = integer(&request, "max").unwrap_or(500).max(0);
            emitter.emit(Emit::Json(json!({ "drop": (pending - max).max(0) })));
        }
        "taste_scores" => {
            let items = request
                .get("items")
                .and_then(Value::as_array)
                .ok_or_else(|| "taste_scores needs items".to_string())?;
            let song_scores = request.get("songScores").and_then(Value::as_object);
            let artist_scores = request.get("artistScores").and_then(Value::as_object);
            let empty = song_scores.map(serde_json::Map::is_empty).unwrap_or(true)
                && artist_scores.map(serde_json::Map::is_empty).unwrap_or(true);
            let mut scores: Vec<f64> = Vec::with_capacity(items.len());
            for item in items {
                let row = item.as_array().cloned().unwrap_or_default();
                if empty {
                    scores.push(0.0);
                    continue;
                }
                let filename = row.first().and_then(Value::as_str).unwrap_or("");
                let artist_key = row.get(1).and_then(Value::as_str).unwrap_or("");
                let by_artist = artist_scores
                    .and_then(|map| map.get(artist_key))
                    .and_then(Value::as_f64)
                    .unwrap_or(0.0);
                let by_song = song_scores
                    .and_then(|map| map.get(filename))
                    .and_then(Value::as_f64)
                    .unwrap_or(0.0);
                scores.push(TASTE_ARTIST_WEIGHT * by_artist + TASTE_SONG_WEIGHT * by_song);
            }
            emitter.emit(Emit::Json(json!({ "scores": scores })));
        }
        other => return Err(format!("unknown helper: {other}")),
    }
    Ok(())
}

fn number(request: &Value, key: &str) -> Result<f64, String> {
    request
        .get(key)
        .and_then(Value::as_f64)
        .ok_or_else(|| format!("missing number: {key}"))
}

fn integer(request: &Value, key: &str) -> Result<i64, String> {
    request
        .get(key)
        .and_then(Value::as_i64)
        .ok_or_else(|| format!("missing integer: {key}"))
}

fn text<'a>(request: &'a Value, key: &str) -> Result<&'a str, String> {
    request
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| format!("missing text: {key}"))
}

fn compare_versions(a: &str, b: &str) -> i64 {
    fn parse(value: &str) -> Vec<i64> {
        let head = value.split(['+', '-']).next().unwrap_or("");
        head.split('.')
            .map(|part| part.trim().parse::<i64>().unwrap_or(0))
            .collect()
    }
    let left = parse(a);
    let right = parse(b);
    let len = left.len().max(right.len());
    for index in 0..len {
        let x = left.get(index).copied().unwrap_or(0);
        let y = right.get(index).copied().unwrap_or(0);
        if x != y {
            return if x < y { -1 } else { 1 };
        }
    }
    0
}

fn classify_version(previous: Option<&str>, current: &str) -> &'static str {
    let Some(previous) = previous.filter(|value| !value.is_empty()) else {
        return "firstRun";
    };
    match compare_versions(previous, current) {
        0 => "same",
        value if value < 0 => "upgraded",
        _ => "downgraded",
    }
}

fn string_field(insights: &Value, key: &str) -> String {
    insights
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_string()
}

fn number_field(insights: &Value, key: &str) -> f64 {
    insights.get(key).and_then(Value::as_f64).unwrap_or(0.0)
}

fn integer_field(insights: &Value, key: &str) -> i64 {
    insights.get(key).and_then(Value::as_i64).unwrap_or(0)
}

fn fun_stats(insights: &Value, library_size: i64) -> Vec<Value> {
    let mut stats: Vec<Value> = Vec::new();
    let total_seconds = number_field(insights, "listenedMs") / 1000.0;
    let hours = (total_seconds / 3600.0) as i64;
    let minutes = ((total_seconds % 3600.0) / 60.0) as i64;

    stats.push(json!({
        "id": "total_time",
        "label": "Total Listening Time",
        "value": format!("{hours}h {minutes}m"),
        "subtitle": format!(
            "You've listened for {:.1} days total!",
            total_seconds / 86400.0
        ),
    }));

    if let Some(artist) = top_row(insights, "topArtists") {
        let name = artist.0;
        let plays = artist.1;
        stats.push(json!({
            "id": "top_artist",
            "label": "Most Played Artist",
            "value": name,
            "subtitle": format!("{plays} plays. You clearly love them."),
        }));
    }

    if let Some(song) = top_row(insights, "topSongs") {
        let name = song.0;
        let plays = song.1;
        stats.push(json!({
            "id": "top_song",
            "label": "Most Played Song",
            "value": name,
            "subtitle": format!("Played {plays} times."),
        }));
    }

    let current_streak = integer_field(insights, "currentStreak");
    stats.push(json!({
        "id": "streak",
        "label": "Longest Streak",
        "value": format!("{} Days", integer_field(insights, "longestStreak")),
        "subtitle": if current_streak > 0 {
            format!("Current streak: {current_streak} days")
        } else {
            "Start a new streak today!".to_string()
        },
    }));

    if let Some(hour) = insights.get("peakHour").and_then(Value::as_i64) {
        stats.push(json!({
            "id": "active_hour",
            "label": "Most Active Hour",
            "value": hour_label(hour),
            "subtitle": "You listen most at this time.",
        }));
    }

    if let Some(weekday) = insights.get("peakWeekday").and_then(Value::as_i64) {
        stats.push(json!({
            "id": "active_day",
            "label": "Most Active Day",
            "value": weekday_name(weekday),
            "subtitle": "Your favorite day to jam.",
        }));
    }

    stats.push(json!({
        "id": "skips",
        "label": "Quick Skips",
        "value": integer_field(insights, "skips").to_string(),
        "subtitle": "Songs skipped quickly.",
    }));

    let unique_songs = integer_field(insights, "uniqueSongs");
    stats.push(json!({
        "id": "unique_songs",
        "label": "Unique Songs Played",
        "value": unique_songs.to_string(),
        "subtitle": "Distinct tracks you've heard.",
    }));

    let plays = integer_field(insights, "plays");
    stats.push(json!({
        "id": "total_songs_played",
        "label": "Total Songs Played",
        "value": plays.to_string(),
        "subtitle": "Total times you've jammed out.",
    }));

    if library_size > 0 {
        let explored = (unique_songs as f64 / library_size as f64 * 100.0) as i64;
        stats.push(json!({
            "id": "explorer_score",
            "label": "Explorer Score",
            "value": format!("{explored}%"),
            "subtitle": "Of your library explored.",
        }));
    }

    if plays > 0 {
        let consistency = (number_field(insights, "favoriteShare") * 100.0) as i64;
        stats.push(json!({
            "id": "consistency",
            "label": "Consistency Score",
            "value": format!("{consistency}%"),
            "subtitle": "Plays that were Favorites.",
        }));
    }

    stats
}

fn top_row(insights: &Value, key: &str) -> Option<(String, i64)> {
    let first = insights.get(key)?.as_array()?.first()?.clone();
    let name = string_field(&first, "name");
    let plays = integer_field(&first, "plays");
    Some((name, plays))
}

fn hour_label(hour: i64) -> String {
    match hour {
        0 => "12 AM".to_string(),
        value if value < 12 => format!("{value} AM"),
        12 => "12 PM".to_string(),
        value => format!("{} PM", value - 12),
    }
}

fn weekday_name(index: i64) -> &'static str {
    match index {
        0 => "Monday",
        1 => "Tuesday",
        2 => "Wednesday",
        3 => "Thursday",
        4 => "Friday",
        5 => "Saturday",
        6 => "Sunday",
        _ => "",
    }
}

/// Bars from the cached binary waveform, or empty when it is not that format.
pub fn waveform_bars(bytes: &[u8]) -> Vec<f64> {
    if bytes.len() < 6 || bytes[..4] != WAVEFORM_MAGIC {
        return Vec::new();
    }
    let count = bytes[4] as usize | (bytes[5] as usize) << 8;
    if count == 0 || bytes.len() < 6 + count {
        return Vec::new();
    }
    bytes[6..6 + count]
        .iter()
        .map(|byte| *byte as f64 / 255.0)
        .collect()
}
