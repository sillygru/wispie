use std::collections::HashMap;

use serde::Deserialize;
use serde_json::{json, Value};

pub fn group_indices(group_ids: &[Option<String>]) -> Vec<Vec<usize>> {
    let mut standalone = Vec::new();
    let mut merged = Vec::<Vec<usize>>::new();
    let mut by_group = HashMap::new();

    for (index, id) in group_ids.iter().enumerate() {
        if let Some(id) = id {
            let group_index = *by_group.entry(id).or_insert_with(|| {
                merged.push(Vec::new());
                merged.len() - 1
            });
            merged[group_index].push(index);
        } else {
            standalone.push(vec![index]);
        }
    }
    standalone.extend(merged);
    standalone
}

pub fn recency(
    queue: &[String],
    current: Option<usize>,
    history: &[String],
    group_by_filename: &HashMap<String, String>,
    groups: &HashMap<String, Vec<String>>,
    limit: usize,
) -> HashMap<String, usize> {
    let mut positions = HashMap::new();
    let mut next = 0;
    let mut insert = |filename: &String| {
        if positions.contains_key(filename) {
            return false;
        }
        if let Some(siblings) = group_by_filename
            .get(filename)
            .and_then(|id| groups.get(id))
        {
            for sibling in siblings {
                positions.entry(sibling.clone()).or_insert(next);
            }
        }
        positions.entry(filename.clone()).or_insert(next);
        next += 1;
        next >= limit
    };

    if !queue.is_empty() && limit > 0 {
        let current = current
            .filter(|index| *index < queue.len())
            .unwrap_or_default();
        for filename in queue[..=current].iter().rev().chain(&queue[current + 1..]) {
            if insert(filename) {
                break;
            }
        }
    }

    for filename in history {
        if insert(filename) {
            break;
        }
    }
    positions
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    #[derive(Deserialize)]
    #[serde(tag = "op", rename_all = "snake_case")]
    enum Request {
        Groups {
            group_ids: Vec<Option<String>>,
        },
        History {
            queue: Vec<String>,
            current: Option<i64>,
            history: Vec<String>,
            group_by_filename: HashMap<String, String>,
            groups: HashMap<String, Vec<String>>,
            limit: i64,
        },
    }

    match serde_json::from_value(payload).map_err(|error| error.to_string())? {
        Request::Groups { group_ids } => Ok(json!({ "groups": group_indices(&group_ids) })),
        Request::History {
            queue,
            current,
            history,
            group_by_filename,
            groups,
            limit,
        } => {
            let current = current.and_then(|index| usize::try_from(index).ok());
            let limit = usize::try_from(limit).unwrap_or_default();
            Ok(json!({
                "history": recency(&queue, current, &history, &group_by_filename, &groups, limit)
            }))
        }
    }
}
