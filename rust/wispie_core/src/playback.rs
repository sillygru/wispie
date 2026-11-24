//! Playback rules that used to live in `AudioPlayerManager`.
//!
//! Only decisions are here: queue/transport ownership, the platform player and
//! its lifecycle quirks stay in the host. Every function is pure over its
//! request so a probe can compare it against the old Dart implementation.

use std::collections::{HashMap, HashSet};

use serde_json::{json, Value};

fn number(request: &Value, key: &str) -> Result<f64, String> {
    request
        .get(key)
        .and_then(Value::as_f64)
        .ok_or_else(|| format!("playback: {key} must be a number"))
}

fn opt_number(request: &Value, key: &str) -> Option<f64> {
    request.get(key).and_then(Value::as_f64)
}

fn flag(request: &Value, key: &str) -> bool {
    request.get(key).and_then(Value::as_bool).unwrap_or(false)
}

fn opt_index(request: &Value, key: &str) -> Option<i64> {
    request.get(key).and_then(Value::as_i64)
}

fn strings(request: &Value, key: &str) -> Vec<String> {
    request
        .get(key)
        .and_then(Value::as_array)
        .map(|rows| {
            rows.iter()
                .filter_map(Value::as_str)
                .map(str::to_string)
                .collect()
        })
        .unwrap_or_default()
}

fn rows(request: &Value, key: &str) -> Vec<Value> {
    request
        .get(key)
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default()
}

fn text_at<'a>(value: &'a Value, key: &str) -> &'a str {
    value.get(key).and_then(Value::as_str).unwrap_or("")
}

/// Volume for one fade tick. `out` decays as progress^2, `in` rises as
/// progress^1.5, both scaled by the user's own volume so a fade never moves the
/// volume slider.
pub fn fade_volume(request: &Value) -> Result<Value, String> {
    let progress = number(request, "progress")?.clamp(0.0, 1.0);
    let user = opt_number(request, "userVolume")
        .unwrap_or(1.0)
        .clamp(0.0, 1.0);
    let curved = match request.get("kind").and_then(Value::as_str).unwrap_or("out") {
        "in" => progress.powf(1.5),
        _ => progress.powf(2.0),
    };
    Ok(json!({ "volume": curved * user }))
}

/// What the playhead listener should do at this position.
///
/// Transitions need a real song: anything under 30 seconds is left alone.
/// Fade-out is cancelled when the listener seeks back out of the window, with
/// 500 ms of hysteresis so the cancel does not race the tick that started it.
pub fn tick(request: &Value) -> Result<Value, String> {
    let position = number(request, "positionMs")?;
    let duration = number(request, "durationMs")?;
    let playing = flag(request, "playing");
    let fading_out = flag(request, "isFadingOut");
    let delay = opt_number(request, "delayDuration").unwrap_or(0.0);
    let fade = opt_number(request, "fadeOutDuration").unwrap_or(0.0);

    // A park owns the end of the track, and a gap that is already running or
    // armed must not be triggered twice.
    let gap_armed = !flag(request, "parkPending")
        && !flag(request, "isInGap")
        && !flag(request, "gapTimerActive");

    let mut gap = false;
    let mut fade_out = false;
    let mut cancel_fade = false;

    if duration >= 30_000.0 {
        let remaining = duration - position;
        if delay > 0.0 && gap_armed && playing {
            gap = true;
        }
        if fade > 0.0 && playing && !fading_out && remaining <= fade * 1000.0 && remaining > 0.0 {
            fade_out = true;
        }
        let fade_ms = fade * 1000.0;
        if fading_out && fade_ms > 0.0 && remaining > fade_ms + 500.0 {
            cancel_fade = true;
        }
    }

    Ok(json!({
        "gap": gap,
        "fadeOut": fade_out,
        "cancelFade": cancel_fade,
    }))
}

/// The play event a finished or paused listen produces.
///
/// A listen under half a second, or one from an open-with file, leaves no row.
/// A track that was resumed mid-way counts from where this session picked it up,
/// and a listen is complete at 85% of that span — the tail is often credits.
pub fn stats_record(request: &Value) -> Result<Value, String> {
    let filename = text_at(request, "filename");
    let total = opt_number(request, "totalLength").unwrap_or(0.0);
    let foreground = opt_number(request, "foreground").unwrap_or(0.0);
    let background = opt_number(request, "background").unwrap_or(0.0);

    let mut effective = total;
    let first_start = opt_number(request, "firstSongStartSec").unwrap_or(0.0);
    let first_song = request.get("firstSongFilename").and_then(Value::as_str);
    if first_song == Some(filename) && first_start > 0.0 && total > 0.0 {
        let adjusted = (total - first_start).max(0.0);
        if adjusted > 0.0 {
            effective = adjusted;
        }
    }

    let played = foreground + background;
    let emit = played > 0.5 && !flag(request, "isExternal");
    // A listen that produces no row has no completion state either.
    let completed = emit && effective > 0.0 && played / effective >= 0.85;

    Ok(json!({
        "emit": emit,
        "completed": completed,
        "durationPlayed": played,
        "foreground": foreground,
        "background": background,
        "totalLength": effective,
    }))
}

/// Which version of a merged track plays.
///
/// The group's priority version wins; otherwise favourites are twice as likely
/// and suggest-less versions a fifth, which keeps every variant reachable
/// without letting a disliked rip take over the queue.
pub fn variant_pick(request: &Value) -> Result<Value, String> {
    let items = rows(request, "items");
    if items.is_empty() {
        return Ok(json!({ "index": Value::Null }));
    }
    if items.len() == 1 {
        return Ok(json!({ "index": 0 }));
    }
    if let Some(priority) = opt_index(request, "priorityIndex") {
        if priority >= 0 && (priority as usize) < items.len() {
            return Ok(json!({ "index": priority }));
        }
    }

    let mut weights = Vec::with_capacity(items.len());
    for item in &items {
        let mut weight = 1.0;
        if flag(item, "favorite") {
            weight *= 2.0;
        }
        if flag(item, "suggestLess") {
            weight *= 0.2;
        }
        weights.push(weight);
    }
    let total: f64 = weights.iter().sum();
    if total <= 0.0 {
        return Ok(json!({ "index": 0 }));
    }

    let draw = number(request, "roll")?.clamp(0.0, 1.0) * total;
    let mut cumulative = 0.0;
    for (index, weight) in weights.iter().enumerate() {
        cumulative += weight;
        if draw <= cumulative {
            return Ok(json!({ "index": index }));
        }
    }
    Ok(json!({ "index": items.len() - 1 }))
}

/// Original order for the upcoming section.
///
/// Entries keep their position in the original queue, wrapping around the
/// current track so everything upcoming (regardless of whether the queue has
/// passed the end of the original list) stays ordered. Entries the original
/// queue never had keep their relative order at the end instead of being
/// dropped.
pub fn original_order(request: &Value) -> Result<Value, String> {
    let upcoming = rows(request, "upcoming");
    let original = rows(request, "original");
    let current = request.get("current").cloned().unwrap_or(Value::Null);

    let mut by_queue: HashMap<String, usize> = HashMap::new();
    let mut by_file: HashMap<String, usize> = HashMap::new();
    for (index, item) in original.iter().enumerate() {
        by_queue.insert(text_at(item, "queueId").to_string(), index);
        by_file
            .entry(text_at(item, "filename").to_string())
            .or_insert(index);
    }

    let position_of = |item: &Value| -> Option<usize> {
        if let Some(index) = by_queue.get(text_at(item, "queueId")) {
            return Some(*index);
        }
        by_file.get(text_at(item, "filename")).copied()
    };

    let anchor = position_of(&current).map_or(-1, |index| index as i64);
    let length = original.len() as i64;

    let mut known: Vec<(i64, usize)> = Vec::new();
    let mut unknown: Vec<usize> = Vec::new();
    for (index, item) in upcoming.iter().enumerate() {
        match position_of(item) {
            Some(position) => {
                let position = position as i64;
                let rank = if position > anchor {
                    position
                } else {
                    position + length
                };
                known.push((rank, index));
            }
            None => unknown.push(index),
        }
    }
    known.sort_by_key(|(rank, _)| *rank);

    let mut order: Vec<usize> = known.into_iter().map(|(_, index)| index).collect();
    order.extend(unknown);
    Ok(json!({ "order": order }))
}

/// Whether a sleep timer stops listening now, and whether the current track is
/// allowed to finish first.
///
/// `remainingMs` is the re-arm delay, so a timer that fires early (a suspended
/// process, a doze) never ends the session ahead of time.
pub fn sleep_decision(request: &Value) -> Result<Value, String> {
    let mode = request.get("mode").and_then(Value::as_str).unwrap_or("");
    let elapsed = opt_number(request, "elapsedMs").unwrap_or(0.0);
    let target = opt_number(request, "durationMs").unwrap_or(0.0);
    let heard = opt_index(request, "tracksHeard").unwrap_or(0);
    let wanted = opt_index(request, "targetTracks").unwrap_or(1).max(1);
    let completed = flag(request, "completed");
    let finish_current = flag(request, "finishCurrent");

    let (end, finish, remaining) = match mode {
        "stopAfterTracks" => {
            if heard >= wanted {
                (true, true, 0.0)
            } else {
                // A queue shorter than the request still has to stop.
                (completed, false, 0.0)
            }
        }
        "loopCurrent" => (elapsed >= target, false, (target - elapsed).max(0.0)),
        "playForTime" => (
            elapsed >= target,
            finish_current,
            (target - elapsed).max(0.0),
        ),
        "stopAfterCurrent" => (true, true, 0.0),
        _ => (false, false, 0.0),
    };

    Ok(json!({
        "end": end,
        "finishCurrent": finish,
        "remainingMs": remaining,
    }))
}

/// The `original` queue to persist for the cloud.
///
/// Null when it carries nothing the effective queue does not, so a plain
/// shuffle is not written as a second list that only differs in order.
pub fn queue_original(request: &Value) -> Result<Value, String> {
    let effective = strings(request, "effective");
    let original = strings(request, "original");

    let mut effective_set: Vec<String> = effective
        .iter()
        .cloned()
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    let mut original_set: Vec<String> = original
        .iter()
        .cloned()
        .collect::<HashSet<_>>()
        .into_iter()
        .collect();
    effective_set.sort_unstable();
    original_set.sort_unstable();

    let same = effective_set == original_set && effective.len() == original.len();
    Ok(json!({
        "original": if same { Value::Null } else { json!(original) },
    }))
}
