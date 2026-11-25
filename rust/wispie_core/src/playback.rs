//! Playback rules that used to live in `AudioPlayerManager`.
//!
//! Only decisions are here: queue/transport ownership, the platform player and
//! its lifecycle quirks stay in the host. Every function is pure over its
//! request so a probe can compare it against the old Dart implementation.

use std::collections::{HashMap, HashSet};

use serde_json::{json, Value};

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
fn pick_variant(items: &[Value], priority: Option<i64>, roll: f64) -> Option<usize> {
    if items.is_empty() {
        return None;
    }
    if items.len() == 1 {
        return Some(0);
    }
    if let Some(index) = priority {
        if index >= 0 && (index as usize) < items.len() {
            return Some(index as usize);
        }
    }

    let mut weights = Vec::with_capacity(items.len());
    for item in items {
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
        return Some(0);
    }

    let draw = roll.clamp(0.0, 1.0) * total;
    let mut cumulative = 0.0;
    for (index, weight) in weights.iter().enumerate() {
        cumulative += weight;
        if draw <= cumulative {
            return Some(index);
        }
    }
    Some(items.len() - 1)
}

pub fn variant_pick(request: &Value) -> Result<Value, String> {
    let items = rows(request, "items");
    let priority = opt_index(request, "priorityIndex");
    let roll = opt_number(request, "roll").unwrap_or(0.0);
    Ok(json!({
        "index": pick_variant(&items, priority, roll).map_or(Value::Null, |index| json!(index)),
    }))
}

/// One pick per merged group in a single crossing. A shuffle of a large library
/// is thousands of groups; asking per group would cost a round trip each.
pub fn variant_pick_batch(request: &Value) -> Result<Value, String> {
    let groups = rows(request, "groups");
    let mut indices = Vec::with_capacity(groups.len());
    for group in &groups {
        let items = group
            .get("items")
            .and_then(Value::as_array)
            .cloned()
            .unwrap_or_default();
        let priority = group.get("priorityIndex").and_then(Value::as_i64);
        let roll = group.get("roll").and_then(Value::as_f64).unwrap_or(0.0);
        indices
            .push(pick_variant(&items, priority, roll).map_or(Value::Null, |index| json!(index)));
    }
    Ok(json!({ "indices": indices }))
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
