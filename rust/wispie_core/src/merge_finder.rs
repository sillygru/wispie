//! Finds duplicate-looking library tracks while preserving user-defined groups.

use regex::Regex;
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};
use std::sync::OnceLock;

#[derive(Deserialize, Default)]
#[serde(default)]
struct Request {
    songs: Vec<Song>,
    #[serde(rename = "existingGroups")]
    existing_groups: HashMap<String, Vec<String>>,
}

#[derive(Deserialize, Default)]
#[serde(default)]
struct Song {
    title: String,
    artist: String,
    filename: String,
}
struct Candidate {
    title: String,
    indices: Vec<usize>,
}

pub fn run(payload: Value) -> Result<Value, String> {
    let request: Request =
        serde_json::from_value(payload).map_err(|e| format!("merge candidates: {e}"))?;
    let mut memberships: HashMap<&str, HashSet<usize>> = HashMap::new();
    for (group_id, filenames) in request.existing_groups.values().enumerate() {
        for filename in filenames {
            memberships.entry(filename).or_default().insert(group_id);
        }
    }

    let mut by_key: HashMap<String, Vec<usize>> = HashMap::new();
    let mut display_titles = HashMap::<String, String>::new();
    for (index, song) in request.songs.iter().enumerate() {
        let title = clean_title(&song.title);
        if title.is_empty() {
            continue;
        }
        let key = format!("{}_{}", clean_artist(&song.artist), title);
        by_key.entry(key.clone()).or_default().push(index);
        display_titles
            .entry(key)
            .or_insert_with(|| clean_display_title(&song.title));
    }

    let mut candidates = Vec::new();
    for (key, indices) in by_key {
        if indices.len() < 2 {
            continue;
        }
        let filenames: HashSet<&str> = indices
            .iter()
            .map(|i| request.songs[*i].filename.as_str())
            .collect();
        let first = match filenames.iter().next() {
            Some(filename) => *filename,
            None => continue,
        };
        let already_together = memberships.get(first).is_some_and(|groups| {
            groups.iter().any(|group| {
                filenames.iter().all(|filename| {
                    memberships
                        .get(filename)
                        .is_some_and(|found| found.contains(group))
                })
            })
        });
        if already_together {
            continue;
        }
        let title = display_titles
            .remove(&key)
            .unwrap_or_else(|| request.songs[indices[0]].title.clone());
        candidates.push(Candidate { title, indices });
    }
    candidates.sort_by_key(|candidate| candidate.title.to_lowercase());
    Ok(
        json!({ "groups": candidates.into_iter().map(|candidate| json!({
        "title": candidate.title,
        "indices": candidate.indices,
    })).collect::<Vec<_>>() }),
    )
}

fn clean_title(title: &str) -> String {
    static BRACKET: OnceLock<Regex> = OnceLock::new();
    static DASH: OnceLock<Regex> = OnceLock::new();
    static BARE: OnceLock<Regex> = OnceLock::new();
    static EXT: OnceLock<Regex> = OnceLock::new();
    static NON_ASCII: OnceLock<Regex> = OnceLock::new();
    static SPACE: OnceLock<Regex> = OnceLock::new();
    let mut value = title.to_lowercase();
    value = BRACKET.get_or_init(|| Regex::new(r"(?i)[\(\[\{].*?(remix|live|acoustic|instrumental|edit|extended|version|mix|feat|ft|cover|demo|slowed|speed|audio|prod|reverb|hardstyle|nightcore|sped|ultra|phonk|techno|euphoric|tiktok|rave|trance|dubstep|bass|boosted|jumpstyle).*?[\)\]\}]").unwrap()).replace_all(&value, "").into_owned();
    value = DASH.get_or_init(|| Regex::new(r"(?i)-\s*(remix|live|acoustic|instrumental|edit|extended|version|mix|feat|ft|cover|demo|slowed|speed|audio|prod|reverb|hardstyle|nightcore|sped|ultra|phonk|techno|euphoric|tiktok|rave|trance|dubstep|bass|boosted|jumpstyle).*$").unwrap()).replace_all(&value, "").into_owned();
    value = BARE.get_or_init(|| Regex::new(r"(?i)\s+(remix|live|acoustic|instrumental|edit|extended|version|mix|feat|ft|cover|demo|slowed|speed|audio|prod|reverb|hardstyle|nightcore|sped|ultra|phonk|techno|euphoric|tiktok|rave|trance|dubstep|bass|boosted|jumpstyle)\s*.*$").unwrap()).replace_all(&value, "").into_owned();
    value = EXT
        .get_or_init(|| {
            Regex::new(
                r"(?i)\.(mp3|m4a|wav|flac|ogg|wma|aac|opus|webm|mkv|mp4|m4v|avi|webmexport)\s*$",
            )
            .unwrap()
        })
        .replace_all(&value, "")
        .into_owned();
    value = NON_ASCII
        .get_or_init(|| Regex::new(r"[^a-z0-9\s]").unwrap())
        .replace_all(&value, "")
        .into_owned();
    SPACE
        .get_or_init(|| Regex::new(r"\s+").unwrap())
        .replace_all(&value, " ")
        .trim()
        .to_string()
}

fn clean_artist(artist: &str) -> String {
    static FEAT: OnceLock<Regex> = OnceLock::new();
    static NON_ASCII: OnceLock<Regex> = OnceLock::new();
    static SPACE: OnceLock<Regex> = OnceLock::new();
    let mut value = artist.to_lowercase();
    value = FEAT
        .get_or_init(|| Regex::new(r"(?i)(feat\.|ft\.).*$").unwrap())
        .replace(&value, "")
        .into_owned();
    value = NON_ASCII
        .get_or_init(|| Regex::new(r"[^a-z0-9\s]").unwrap())
        .replace_all(&value, "")
        .into_owned();
    SPACE
        .get_or_init(|| Regex::new(r"\s+").unwrap())
        .replace_all(&value, " ")
        .trim()
        .to_string()
}

fn clean_display_title(title: &str) -> String {
    static BRACKET: OnceLock<Regex> = OnceLock::new();
    static DASH: OnceLock<Regex> = OnceLock::new();
    static BARE: OnceLock<Regex> = OnceLock::new();
    static EXT: OnceLock<Regex> = OnceLock::new();
    let mut value = title.to_string();
    value = BRACKET.get_or_init(|| Regex::new(r"(?i)\s*[\(\[\{].*?(remix|live|acoustic|instrumental|edit|extended|version|mix|feat|ft|cover|demo|slowed|speed|audio|prod|reverb|hardstyle|nightcore|sped|ultra|phonk|techno|euphoric|tiktok|rave|trance|dubstep|bass|boosted|jumpstyle).*?[\)\]\}]").unwrap()).replace_all(&value, "").into_owned();
    value = DASH.get_or_init(|| Regex::new(r"(?i)\s*-\s*(remix|live|acoustic|instrumental|edit|extended|version|mix|feat|ft|cover|demo|slowed|speed|audio|prod|reverb|hardstyle|nightcore|sped|ultra|phonk|techno|euphoric|tiktok|rave|trance|dubstep|bass|boosted|jumpstyle).*$").unwrap()).replace_all(&value, "").into_owned();
    value = BARE.get_or_init(|| Regex::new(r"(?i)\s+(remix|live|acoustic|instrumental|edit|extended|version|mix|feat|ft|cover|demo|slowed|speed|audio|prod|reverb|hardstyle|nightcore|sped|ultra|phonk|techno|euphoric|tiktok|rave|trance|dubstep|bass|boosted|jumpstyle)\s*.*$").unwrap()).replace_all(&value, "").into_owned();
    value = EXT
        .get_or_init(|| {
            Regex::new(
                r"(?i)\.(mp3|m4a|wav|flac|ogg|wma|aac|opus|webm|mkv|mp4|m4v|avi|webmexport)\s*$",
            )
            .unwrap()
        })
        .replace_all(&value, "")
        .trim()
        .to_string();
    if value.is_empty() {
        title.to_string()
    } else {
        value
    }
}
