use std::collections::{HashMap, HashSet};

use serde_json::{json, Value};

#[path = "queue_ops/dart_sort.rs"]
pub(crate) mod dart_sort;

pub fn update_top_order(request: &Value) -> Value {
    let current = strings(request, "currentOrder");
    let queue_id = text(request, "queueId");
    let mut next = current
        .into_iter()
        .filter(|id| id != queue_id)
        .collect::<Vec<_>>();
    if request
        .get("isOverride")
        .and_then(Value::as_bool)
        .unwrap_or(false)
    {
        next.insert(0, queue_id.to_string());
    } else {
        next.push(queue_id.to_string());
    }
    json!({"order": next})
}

pub fn prune_top_order(request: &Value) -> Value {
    let order = strings(request, "sessionTopOrder");
    if order.is_empty() {
        return json!({"order": []});
    }
    let queue = request
        .get("queue")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let current_index = request
        .get("currentIndex")
        .and_then(Value::as_i64)
        .unwrap_or(-1);
    let next = order
        .into_iter()
        .filter(|id| {
            queue
                .iter()
                .position(|item| item.get("queueId").and_then(Value::as_str) == Some(id))
                .is_some_and(|index| index as i64 > current_index)
        })
        .collect::<Vec<_>>();
    json!({"order": next})
}

pub fn plan_reorder(request: &Value) -> Value {
    let length = request.get("length").and_then(Value::as_u64).unwrap_or(0) as usize;
    let old_index = request
        .get("oldIndex")
        .and_then(Value::as_i64)
        .unwrap_or(-1);
    let new_index = request
        .get("newIndex")
        .and_then(Value::as_i64)
        .unwrap_or(-1);

    if length == 0 || old_index < 0 || old_index as usize >= length {
        return json!({"valid": false});
    }

    let mut target = new_index.clamp(0, length as i64) as usize;
    if (old_index as usize) < target {
        target -= 1;
    }
    if target >= length || old_index as usize == target {
        return json!({"valid": false});
    }
    json!({"valid": true, "from": old_index, "to": target})
}

pub fn plan_jump(request: &Value) -> Value {
    let queue_ids = strings(request, "queueIds");
    let current = request
        .get("currentIndex")
        .and_then(Value::as_i64)
        .unwrap_or(-1);
    if current < 0 || current as usize >= queue_ids.len() {
        return json!({"valid": false});
    }
    let queue_id = text(request, "queueId");
    let Some(source) = queue_ids.iter().position(|id| id == queue_id) else {
        return json!({"valid": false});
    };
    if source as i64 == current {
        return json!({"valid": false});
    }
    let target = current + 1;
    if source as i64 > current {
        if source as i64 == target {
            return json!({"valid": false});
        }
        json!({"valid": true, "from": source, "to": target, "source": source})
    } else {
        json!({"valid": true, "from": Value::Null, "to": target, "source": source})
    }
}

pub fn plan_move_upcoming_to_top(request: &Value) -> Value {
    let queue_ids = strings(request, "queueIds");
    let current = request
        .get("currentIndex")
        .and_then(Value::as_i64)
        .unwrap_or(-1);
    if current < 0 || current as usize >= queue_ids.len() {
        return json!({"valid": false});
    }
    let queue_id = text(request, "queueId");
    let Some(source) = queue_ids.iter().position(|id| id == queue_id) else {
        return json!({"valid": false});
    };
    if source as i64 <= current {
        return json!({"valid": false});
    }

    let order = strings(request, "sessionTopOrder");
    let target = if order.iter().any(|id| id == queue_id) {
        current + 1
    } else {
        let mut last_top = current;
        for top_id in order {
            if top_id == queue_id {
                continue;
            }
            if let Some(index) = queue_ids.iter().position(|id| id == &top_id) {
                if index as i64 > current && index as i64 > last_top {
                    last_top = index as i64;
                }
            }
        }
        last_top + 1
    };
    let mut target = target.clamp(0, queue_ids.len() as i64);
    if (source as i64) < target {
        target -= 1;
    }
    if target < 0 || target as usize >= queue_ids.len() || source as i64 == target {
        return json!({"valid": false});
    }
    json!({"valid": true, "from": source, "to": target})
}

pub fn plan_play_next(request: &Value) -> Value {
    let queue_ids = strings(request, "queueIds");
    let filenames = strings(request, "filenames");
    let current = request
        .get("currentIndex")
        .and_then(Value::as_i64)
        .unwrap_or(-1);
    let candidate_filename = text(request, "candidateFilename");
    let start = (current + 1).clamp(0, filenames.len() as i64) as usize;
    let upcoming = filenames
        .iter()
        .enumerate()
        .skip(start)
        .find_map(|(index, filename)| (filename == candidate_filename).then_some(index));
    let session_top_order = strings(request, "sessionTopOrder");

    let mut last_top = current;
    for top_id in session_top_order {
        if upcoming.is_some_and(|index| queue_ids.get(index) == Some(&top_id)) {
            continue;
        }
        if let Some(index) = queue_ids.iter().position(|id| id == &top_id) {
            if index as i64 > current && index as i64 > last_top {
                last_top = index as i64;
            }
        }
    }
    let target = (last_top + 1).clamp(0, queue_ids.len() as i64);
    if let Some(source) = upcoming {
        let to = if source as i64 >= target {
            target
        } else {
            target - 1
        };
        json!({"valid": true, "from": source, "to": to, "source": source})
    } else {
        json!({"valid": true, "from": Value::Null, "to": target, "source": Value::Null})
    }
}

pub fn apply_plan(request: &Value) -> Value {
    let length = request.get("length").and_then(Value::as_u64).unwrap_or(0) as usize;
    let from_value = request.get("from");
    let from = if from_value.is_none_or(Value::is_null) {
        None
    } else if let Some(index) = from_value.and_then(Value::as_i64) {
        if index < 0 {
            return json!({"valid": false});
        }
        Some(index as usize)
    } else {
        return json!({"valid": false});
    };
    let to = request.get("to").and_then(Value::as_u64).unwrap_or(0) as usize;
    if from.is_some_and(|index| index >= length) {
        return json!({"valid": false});
    }
    let mut order = (0..length).collect::<Vec<_>>();
    if let Some(index) = from {
        order.remove(index);
    }
    order.insert(to.min(order.len()), length);
    json!({"valid": true, "order": order})
}

pub fn find_in_queue(request: &Value) -> Value {
    let filenames = strings(request, "filenames");
    let filename = text(request, "filename");
    if let Some(index) = filenames.iter().position(|value| value == filename) {
        return json!({"index": index});
    }
    for sibling in strings(request, "mergedSiblings") {
        if let Some(index) = filenames.iter().position(|value| value == &sibling) {
            return json!({"index": index});
        }
    }
    json!({"index": -1})
}

pub fn original_order(request: &Value) -> Value {
    let upcoming_ids = strings(request, "upcomingIds");
    let upcoming_filenames = strings(request, "upcomingFilenames");
    let original_ids = strings(request, "originalIds");
    let original_filenames = strings(request, "originalFilenames");
    let mut by_id = HashMap::new();
    let mut by_filename = HashMap::new();
    for (index, id) in original_ids.iter().enumerate() {
        by_id.insert(id.as_str(), index);
        by_filename
            .entry(original_filenames[index].as_str())
            .or_insert(index);
    }

    let anchor = position(
        text(request, "currentId"),
        text(request, "currentFilename"),
        &by_id,
        &by_filename,
    )
    .map_or(-1, |index| index as i64);
    let length = original_ids.len() as i64;
    let mut known = Vec::new();
    let mut unknown = Vec::new();
    for index in 0..upcoming_ids.len() {
        if let Some(original_index) = position(
            &upcoming_ids[index],
            &upcoming_filenames[index],
            &by_id,
            &by_filename,
        ) {
            let original_index = original_index as i64;
            let rank = if original_index > anchor {
                original_index
            } else {
                original_index + length
            };
            known.push((rank, index));
        } else {
            unknown.push(index);
        }
    }
    let ranks = known.iter().map(|(rank, _)| *rank).collect::<Vec<_>>();
    let mut known_order = (0..known.len()).collect::<Vec<_>>();
    dart_sort::sort_by_key(&mut known_order, &ranks);
    json!({
        "order": known_order
            .into_iter()
            .map(|index| known[index].1)
            .chain(unknown)
            .collect::<Vec<_>>()
    })
}

pub fn reconcile_sequence(request: &Value) -> Value {
    let effective = request
        .get("effective")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let sequence = request
        .get("sequence")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let library_found = request
        .get("libraryFound")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();

    let mut by_id = HashMap::new();
    let mut by_filename: HashMap<&str, Vec<usize>> = HashMap::new();
    let mut effective_ids = Vec::with_capacity(effective.len());
    for (index, item) in effective.iter().enumerate() {
        let id = item.get("queueId").and_then(Value::as_str).unwrap_or("");
        let filename = item.get("filename").and_then(Value::as_str).unwrap_or("");
        by_id.insert(id, index);
        by_filename.entry(filename).or_default().push(index);
        effective_ids.push(id);
    }

    let mut consumed_ids = HashSet::new();
    let mut consumed_filename_counts: HashMap<&str, usize> = HashMap::new();
    let mut actions = Vec::new();
    for (sequence_index, entry) in sequence.iter().enumerate() {
        let filename = entry.get("filename").and_then(Value::as_str).unwrap_or("");
        let queue_id = entry.get("queueId").and_then(Value::as_str);
        let mut resolved = queue_id
            .filter(|id| !consumed_ids.contains(id))
            .and_then(|id| by_id.get(id).copied());

        if resolved.is_none() {
            if let Some(candidates) = by_filename.get(filename) {
                let used = consumed_filename_counts.entry(filename).or_default();
                if *used < candidates.len() {
                    resolved = Some(candidates[*used]);
                    *used += 1;
                }
            }
        }

        let has_library = library_found
            .get(sequence_index)
            .and_then(Value::as_bool)
            .unwrap_or(false);
        if resolved.is_none() && !has_library {
            continue;
        }

        let resolved_id = resolved.map(|index| effective_ids[index]);
        if let Some(id) = queue_id.or(resolved_id) {
            consumed_ids.insert(id);
        }
        actions.push(json!({
            "sequenceIndex": sequence_index,
            "effectiveIndex": resolved,
            "queueId": queue_id,
            "hasLibrary": has_library
        }));
    }
    json!({"actions": actions})
}

fn position(
    queue_id: &str,
    filename: &str,
    by_id: &HashMap<&str, usize>,
    by_filename: &HashMap<&str, usize>,
) -> Option<usize> {
    by_id
        .get(queue_id)
        .copied()
        .or_else(|| by_filename.get(filename).copied())
}

fn strings(value: &Value, key: &str) -> Vec<String> {
    value
        .get(key)
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
        .map(str::to_string)
        .collect()
}

fn text<'a>(value: &'a Value, key: &str) -> &'a str {
    value.get(key).and_then(Value::as_str).unwrap_or("")
}
