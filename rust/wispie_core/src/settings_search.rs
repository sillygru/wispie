use regex::Regex;
use serde_json::{json, Value};
use std::sync::OnceLock;

const DEFAULT_MAX_RESULTS: usize = 30;

pub fn search(request: &Value) -> Value {
    let query = request
        .get("query")
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_lowercase();
    let tokens = query_whitespace_splitter()
        .split(&query)
        .filter(|token| !token.is_empty())
        .collect::<Vec<_>>();
    if tokens.is_empty() {
        return json!({"indices": []});
    }

    let entries = request
        .get("entries")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let limit = request
        .get("limit")
        .and_then(Value::as_u64)
        .map_or(DEFAULT_MAX_RESULTS, |value| value as usize);
    let mut scored = Vec::new();

    for (index, entry) in entries.iter().enumerate() {
        let title = lower_text(entry, "title");
        let subtitle = lower_text(entry, "subtitle");
        let breadcrumb = lower_text(entry, "breadcrumb");
        let keywords = entry
            .get("keywords")
            .and_then(Value::as_array)
            .into_iter()
            .flatten()
            .filter_map(Value::as_str)
            .map(str::to_lowercase)
            .collect::<Vec<_>>();

        let mut total = 0;
        let mut matched_all = true;
        for token in &tokens {
            let score = token_score(token, &title, &subtitle, &breadcrumb, &keywords);
            if score == 0 {
                matched_all = false;
                break;
            }
            total += score;
        }
        if matched_all {
            scored.push((total, index));
        }
    }

    scored.sort_by(|left, right| right.0.cmp(&left.0).then(left.1.cmp(&right.1)));
    json!({"indices": scored.into_iter().take(limit).map(|(_, index)| index).collect::<Vec<_>>()})
}

fn lower_text(entry: &Value, key: &str) -> String {
    entry
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or("")
        .to_lowercase()
}

fn token_score(
    token: &str,
    title: &str,
    subtitle: &str,
    breadcrumb: &str,
    keywords: &[String],
) -> i32 {
    if title.starts_with(token) {
        8
    } else if has_word_prefix(title, token) {
        6
    } else if has_word_prefix(subtitle, token) {
        3
    } else if keywords.iter().any(|keyword| keyword.starts_with(token)) {
        2
    } else if has_word_prefix(breadcrumb, token) {
        1
    } else {
        0
    }
}

fn has_word_prefix(haystack: &str, token: &str) -> bool {
    if haystack.is_empty() {
        return false;
    }
    ascii_word_splitter()
        .split(haystack)
        .any(|word| word.starts_with(token))
}

fn ascii_word_splitter() -> &'static Regex {
    static SPLITTER: OnceLock<Regex> = OnceLock::new();
    SPLITTER.get_or_init(|| Regex::new(r"[^a-z0-9]+").expect("constant regex is valid"))
}

fn query_whitespace_splitter() -> &'static Regex {
    static SPLITTER: OnceLock<Regex> = OnceLock::new();
    SPLITTER.get_or_init(|| Regex::new(r"[\s\u{feff}]+").expect("constant regex is valid"))
}
