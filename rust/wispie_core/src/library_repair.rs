//! Library repair: reconcile rows restored from another device with the
//! filesystem actually under them. Ported from `library_repair_policy.dart` and
//! `LibraryRepairService`.
//!
//! The database writes stay in Dart; the probing (thousands of stats, one
//! basename walk and the cover signature checks) and every decision happen here.

use crate::formats;
use crate::model::SongJson;
use serde_json::{json, Value};
use sha1::{Digest, Sha1};
use std::collections::HashMap;
use std::path::{Path, PathBuf};
use std::time::UNIX_EPOCH;

const COVER_EXTENSIONS: [&str; 6] = [".jpg", ".jpeg", ".png", ".webp", ".bmp", "_ffmpeg.jpg"];
const SIGNATURE_PROBE_LEN: usize = 16;

pub struct SongProbe {
    pub audio_exists: bool,
    pub reresolved_url: Option<String>,
    pub valid_cover_path: Option<String>,
    pub mtime: Option<f64>,
}

/// The wire shape of one probe, for callers checking a single decision.
#[derive(Debug, Clone, Default, serde::Deserialize)]
#[serde(default, rename_all = "camelCase")]
pub struct ProbeInput {
    pub audio_exists: bool,
    pub reresolved_url: Option<String>,
    pub valid_cover_path: Option<String>,
    pub mtime: Option<f64>,
}

impl From<ProbeInput> for SongProbe {
    fn from(input: ProbeInput) -> Self {
        Self {
            audio_exists: input.audio_exists,
            reresolved_url: input.reresolved_url,
            valid_cover_path: input.valid_cover_path,
            mtime: input.mtime,
        }
    }
}

impl SongProbe {
    fn resolvable(&self) -> bool {
        self.audio_exists || self.reresolved_url.is_some()
    }
}

pub struct RepairDecision {
    pub action: &'static str,
    pub row: Option<SongJson>,
    pub cover_repointed: bool,
    pub cover_cleared: bool,
    pub url_reresolved: bool,
}

/// The placeholder shape a fast scan writes before enrichment runs.
pub fn is_placeholder(song: &SongJson) -> bool {
    let stem = Path::new(&song.filename)
        .file_stem()
        .and_then(|value| value.to_str())
        .unwrap_or("");
    song.artist == "Unknown Artist" && song.album == "Unknown Album" && song.title == stem
}

fn min_nullable(a: Option<f64>, b: Option<f64>) -> Option<f64> {
    match (a, b) {
        (None, other) | (other, None) => other,
        (Some(left), Some(right)) => Some(left.min(right)),
    }
}

/// Combines a row scanned on this device with the same row from an import.
pub fn merge_song_rows(local: &SongJson, imported: &SongJson) -> SongJson {
    let local_placeholder = is_placeholder(local);
    let imported_placeholder = is_placeholder(imported);
    let source = if imported_placeholder && !local_placeholder {
        local
    } else {
        imported
    };

    SongJson {
        title: source.title.clone(),
        artist: source.artist.clone(),
        album: source.album.clone(),
        filename: local.filename.clone(),
        url: local.url.clone(),
        cover_url: local
            .cover_url
            .clone()
            .filter(|value| !value.is_empty())
            .or_else(|| imported.cover_url.clone()),
        has_lyrics: local.has_lyrics || imported.has_lyrics,
        play_count: local.play_count.max(imported.play_count),
        duration: local.duration.or(imported.duration),
        mtime: local.mtime.or(imported.mtime),
        created_epoch_sec: min_nullable(local.created_epoch_sec, imported.created_epoch_sec),
        song_date_epoch_sec: local.song_date_epoch_sec.or(imported.song_date_epoch_sec),
    }
}

/// What `current` needs, given what the filesystem said about it.
pub fn decide_repair(
    current: &SongJson,
    probe: &SongProbe,
    drop_unresolvable: bool,
) -> RepairDecision {
    if !probe.resolvable() {
        return RepairDecision {
            action: if drop_unresolvable { "drop" } else { "keep" },
            row: None,
            cover_repointed: false,
            cover_cleared: false,
            url_reresolved: false,
        };
    }

    let new_url = if probe.audio_exists {
        current.url.clone()
    } else {
        probe.reresolved_url.clone().unwrap_or_default()
    };
    let url_changed = new_url != current.url;

    let has_current_cover = current
        .cover_url
        .as_deref()
        .is_some_and(|value| !value.is_empty());
    let new_cover = probe.valid_cover_path.clone();
    let cover_repointed = new_cover.is_some() && new_cover != current.cover_url;
    let cover_cleared = new_cover.is_none() && has_current_cover;
    let mtime_changed = probe.mtime.is_some() && probe.mtime != current.mtime;

    if !url_changed && !cover_repointed && !cover_cleared && !mtime_changed {
        return RepairDecision {
            action: "keep",
            row: None,
            cover_repointed: false,
            cover_cleared: false,
            url_reresolved: false,
        };
    }

    let mut row = current.clone();
    if url_changed {
        row.url = new_url;
    }
    row.cover_url = if cover_cleared {
        None
    } else {
        new_cover.or_else(|| current.cover_url.clone())
    };
    if probe.mtime.is_some() {
        row.mtime = probe.mtime;
    }

    RepairDecision {
        action: "update",
        row: Some(row),
        cover_repointed,
        cover_cleared,
        url_reresolved: url_changed,
    }
}

/// Probes, merges and decides in one pass.
pub fn plan(request: &Value) -> Value {
    let rows: Vec<SongJson> = songs_from(request, "rows");
    let pre_import = songs_from(request, "preImportSongs");
    let imported = songs_from(request, "importedRows");
    let covers_dir = request
        .get("coversDir")
        .and_then(Value::as_str)
        .unwrap_or("");
    let folders: Vec<String> = request
        .get("musicFolders")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default();
    let drop_unresolvable = request
        .get("dropUnresolvable")
        .and_then(Value::as_bool)
        .unwrap_or(true);

    let merged = merged_rows(rows, pre_import, imported);
    if merged.is_empty() {
        return json!({
            "rowsExamined": 0,
            "updates": [],
            "dropped": [],
            "changedCovers": [],
            "coversRepointed": 0,
            "coversCleared": 0,
            "urlsReresolved": 0,
            "pruningSkipped": false,
        });
    }

    let readable: Vec<PathBuf> = folders
        .iter()
        .filter(|folder| Path::new(folder).is_dir())
        .map(PathBuf::from)
        .collect();
    let can_prune = drop_unresolvable && !readable.is_empty();

    let mut basenames: Option<HashMap<String, String>> = None;
    let mut updates: Vec<Value> = Vec::new();
    let mut dropped: Vec<String> = Vec::new();
    let mut changed_covers: Vec<String> = Vec::new();
    let mut covers_repointed = 0;
    let mut covers_cleared = 0;
    let mut urls_reresolved = 0;

    for row in &merged {
        let audio_exists = Path::new(&row.url).is_file();
        let mut reresolved = None;
        let mut mtime = None;
        if audio_exists {
            mtime = file_mtime(&row.url);
        } else {
            let index = basenames.get_or_insert_with(|| build_basename_index(&readable));
            reresolved = index.get(&row.filename).cloned();
            if let Some(found) = &reresolved {
                mtime = file_mtime(found);
            }
        }

        let probe = SongProbe {
            audio_exists,
            reresolved_url: reresolved,
            valid_cover_path: resolve_cover(row.cover_url.as_deref(), covers_dir, &row.filename),
            mtime,
        };
        let decision = decide_repair(row, &probe, can_prune);
        match decision.action {
            "drop" => dropped.push(row.filename.clone()),
            "update" => {
                if decision.cover_repointed {
                    covers_repointed += 1;
                    if let Some(path) = decision.row.as_ref().and_then(|row| row.cover_url.clone())
                    {
                        changed_covers.push(path);
                    }
                }
                if decision.cover_cleared {
                    covers_cleared += 1;
                }
                if decision.url_reresolved {
                    urls_reresolved += 1;
                }
                if let Some(row) = decision.row {
                    updates.push(json!(row));
                }
            }
            _ => {}
        }
    }

    json!({
        "rowsExamined": merged.len(),
        "updates": updates,
        "dropped": dropped,
        "changedCovers": changed_covers,
        "coversRepointed": covers_repointed,
        "coversCleared": covers_cleared,
        "urlsReresolved": urls_reresolved,
        "pruningSkipped": drop_unresolvable && !can_prune,
    })
}

fn songs_from(request: &Value, key: &str) -> Vec<SongJson> {
    request
        .get(key)
        .and_then(Value::as_array)
        .map(|rows| {
            rows.iter()
                .filter_map(|row| serde_json::from_value(row.clone()).ok())
                .collect()
        })
        .unwrap_or_default()
}

fn merged_rows(
    rows: Vec<SongJson>,
    pre_import: Vec<SongJson>,
    imported: Vec<SongJson>,
) -> Vec<SongJson> {
    let mut order: Vec<String> = Vec::new();
    let mut by_filename: HashMap<String, SongJson> = HashMap::new();
    for song in rows {
        if !by_filename.contains_key(&song.filename) {
            order.push(song.filename.clone());
        }
        by_filename.insert(song.filename.clone(), song);
    }
    for song in imported {
        let merged = match by_filename.get(&song.filename) {
            Some(existing) => merge_song_rows(existing, &song),
            None => song,
        };
        if !by_filename.contains_key(&merged.filename) {
            order.push(merged.filename.clone());
        }
        by_filename.insert(merged.filename.clone(), merged);
    }
    for song in pre_import {
        let merged = match by_filename.get(&song.filename) {
            Some(existing) => merge_song_rows(&song, existing),
            None => song,
        };
        if !by_filename.contains_key(&merged.filename) {
            order.push(merged.filename.clone());
        }
        by_filename.insert(merged.filename.clone(), merged);
    }
    order
        .into_iter()
        .filter_map(|filename| by_filename.remove(&filename))
        .collect()
}

fn file_mtime(path: &str) -> Option<f64> {
    std::fs::metadata(path)
        .ok()?
        .modified()
        .ok()?
        .duration_since(UNIX_EPOCH)
        .ok()
        .map(|duration| duration.as_millis() as f64 / 1000.0)
}

/// basename -> absolute path for everything playable under `folders`.
///
/// Last one wins on a collision, matching the `song` table's own basename key.
fn build_basename_index(folders: &[PathBuf]) -> HashMap<String, String> {
    let mut index = HashMap::new();
    for folder in folders {
        let walker = walkdir::WalkDir::new(folder)
            .follow_links(false)
            .into_iter()
            .filter_map(Result::ok)
            .filter(|entry| entry.file_type().is_file())
            .filter(|entry| formats::is_supported_path(entry.path()));
        for entry in walker {
            if let Some(name) = entry.path().file_name().and_then(|value| value.to_str()) {
                index.insert(
                    name.to_string(),
                    entry.path().to_string_lossy().into_owned(),
                );
            }
        }
    }
    index
}

fn resolve_cover(stored: Option<&str>, covers_dir: &str, filename: &str) -> Option<String> {
    if let Some(stored) = stored.filter(|value| !value.is_empty()) {
        if usable_cover(Path::new(stored)) {
            return Some(stored.to_string());
        }
    }

    let key = cover_key(filename);
    for extension in COVER_EXTENSIONS {
        let candidate = Path::new(covers_dir).join(format!("{key}{extension}"));
        if Some(candidate.to_string_lossy().as_ref()) == stored {
            continue;
        }
        if usable_cover(&candidate) {
            return Some(candidate.to_string_lossy().into_owned());
        }
    }
    None
}

fn usable_cover(path: &Path) -> bool {
    let Ok(metadata) = std::fs::metadata(path) else {
        return false;
    };
    if !metadata.is_file() || metadata.len() == 0 {
        return false;
    }
    let Ok(bytes) = std::fs::read(path) else {
        return false;
    };
    let head = &bytes[..bytes.len().min(SIGNATURE_PROBE_LEN)];
    crate::artwork::has_image_signature(head)
}

fn cover_key(filename: &str) -> String {
    let name = Path::new(filename)
        .file_name()
        .and_then(|value| value.to_str())
        .unwrap_or(filename);
    let digest = Sha1::digest(name.as_bytes());
    digest.iter().map(|byte| format!("{byte:02x}")).collect()
}
