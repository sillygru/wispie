use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

fn script(text: &str) -> usize {
    let ranges = [
        '\u{3040}'..='\u{30ff}',
        '\u{ac00}'..='\u{d7af}',
        '\u{4e00}'..='\u{9faf}',
        '\u{0400}'..='\u{04ff}',
        '\u{0600}'..='\u{06ff}',
        '\u{0900}'..='\u{097f}',
        '\u{0370}'..='\u{03ff}',
        '\u{0e00}'..='\u{0e7f}',
    ];
    ranges
        .iter()
        .position(|range| text.chars().any(|c| range.contains(&c)))
        .unwrap_or(ranges.len())
}

pub fn batch_ends<'a>(lines: impl IntoIterator<Item = &'a str>) -> Vec<usize> {
    let mut ends = Vec::new();
    let mut current_script = None;
    let mut current_chars = 0;
    let mut count = 0;
    for line in lines {
        let script = script(line);
        let chars = line.encode_utf16().count() + 1;
        if current_script.is_some_and(|current| current != script || current_chars + chars > 1800) {
            ends.push(count);
            current_chars = 0;
        }
        current_script = Some(script);
        current_chars += chars;
        count += 1;
    }
    if count != 0 {
        ends.push(count);
    }
    ends
}

#[derive(Serialize)]
#[serde(tag = "provider", rename_all = "snake_case")]
pub enum Provider<'a> {
    GoogleGtx,
    GoogleClients5,
    Lingva { host: &'a str },
    MyMemory,
}

pub fn providers<'a>(query: &str, hosts: &'a [String]) -> Vec<Provider<'a>> {
    let mut providers = vec![Provider::GoogleGtx, Provider::GoogleClients5];
    providers.extend(hosts.iter().map(|host| Provider::Lingva { host }));
    if query.encode_utf16().take(451).count() <= 450 {
        providers.push(Provider::MyMemory);
    }
    providers
}

pub fn split_batch(text: &str, expected: usize) -> Option<Vec<String>> {
    let normalized = text.replace("\r\n", "\n").replace('\r', "\n");
    let lines: Vec<_> = normalized.split('\n').map(str::to_owned).collect();
    (lines.len() == expected).then_some(lines)
}

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
enum Request {
    Batches { lines: Vec<String> },
    Providers { query: String, hosts: Vec<String> },
    SplitBatch { text: String, expected: usize },
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    let request = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    Ok(match request {
        Request::Batches { lines } => json!({"ends": batch_ends(lines.iter().map(String::as_str))}),
        Request::Providers { query, hosts } => json!({"attempts": providers(&query, &hosts)}),
        Request::SplitBatch { text, expected } => json!({"lines": split_batch(&text, expected)}),
    })
}
