use serde_json::{json, Value};
use std::collections::HashMap;

pub fn reorder(request: &Value) -> Value {
    let ids = request
        .get("upcomingIds")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let remembered = request
        .get("rememberedIds")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();

    let mut rank = HashMap::new();
    for (index, id) in remembered.iter().filter_map(Value::as_str).enumerate() {
        rank.entry(id.to_string()).or_insert(index);
    }

    let mut known = Vec::new();
    let mut unknown = Vec::new();
    for (index, id) in ids.iter().filter_map(Value::as_str).enumerate() {
        if let Some(position) = rank.get(id) {
            known.push((*position, index));
        } else {
            unknown.push(index);
        }
    }
    known.sort_by_key(|(position, _)| *position);

    let order = known
        .into_iter()
        .map(|(_, index)| index)
        .chain(unknown)
        .collect::<Vec<_>>();
    json!({"order": order})
}
