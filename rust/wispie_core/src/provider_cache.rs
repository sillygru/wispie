use std::collections::HashMap;
use std::fs::{self, File, OpenOptions};
use std::io::{BufReader, ErrorKind};
use std::path::{Path, PathBuf};
use std::sync::{Mutex, OnceLock};
use std::time::{Duration, SystemTime};

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use sha1::{Digest, Sha1};

pub const AUDIO_TTL: Duration = Duration::from_secs(14 * 24 * 60 * 60);
pub const MAX_AUDIO_BYTES: u64 = 1024 * 1024 * 1024;
pub const TRIM_AUDIO_BYTES: u64 = MAX_AUDIO_BYTES * 8 / 10;
const RESPONSE_TTL: Duration = Duration::from_secs(7 * 24 * 60 * 60);
const RESPONSE_PREFIX: &str = "youtube_";

#[derive(Clone)]
struct AudioEntry {
    path: PathBuf,
    modified: SystemTime,
    bytes: u64,
}

type Index = HashMap<(String, String), AudioEntry>;
static INDICES: OnceLock<Mutex<HashMap<PathBuf, Index>>> = OnceLock::new();

fn with_indices<T>(operation: impl FnOnce(&mut HashMap<PathBuf, Index>) -> T) -> T {
    let mut indices = INDICES
        .get_or_init(|| Mutex::new(HashMap::new()))
        .lock()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    operation(&mut indices)
}

pub fn audio_path(root: &Path, provider: &str, id: &str, itag: &str, extension: &str) -> PathBuf {
    let sanitize = |value: &str| {
        value
            .chars()
            .map(|letter| {
                if letter.is_ascii_alphanumeric() || matches!(letter, '_' | '-') {
                    letter
                } else {
                    '_'
                }
            })
            .collect::<String>()
    };
    let extension = if extension.is_empty() {
        "bin"
    } else {
        extension
    };
    root.join(format!(
        "{}~{}~{}.{}",
        sanitize(provider),
        sanitize(id),
        sanitize(itag),
        sanitize(extension)
    ))
}

fn audio_ids(name: &str) -> Option<(String, String)> {
    let (provider, rest) = name.split_once('~')?;
    let id = rest.split('~').next()?;
    (!provider.is_empty() && !id.is_empty()).then(|| (provider.to_string(), id.to_string()))
}

fn marker(path: &Path) -> PathBuf {
    let mut name = path.as_os_str().to_os_string();
    name.push(".ok");
    PathBuf::from(name)
}

fn entries(root: &Path) -> Result<Vec<AudioEntry>, String> {
    let mut files = Vec::new();
    for item in fs::read_dir(root).map_err(|error| error.to_string())? {
        let item = item.map_err(|error| error.to_string())?;
        if !item.file_type().is_ok_and(|kind| kind.is_file()) {
            continue;
        }
        if let Ok(metadata) = item.metadata() {
            if let Ok(modified) = metadata.modified() {
                files.push(AudioEntry {
                    path: item.path(),
                    modified,
                    bytes: metadata.len(),
                });
            }
        }
    }
    Ok(files)
}

fn name(path: &Path) -> &str {
    path.file_name()
        .and_then(|name| name.to_str())
        .unwrap_or_default()
}

fn index(root: &Path, indices: &mut HashMap<PathBuf, Index>) -> Result<(), String> {
    if indices.contains_key(root) {
        return Ok(());
    }
    let mut loaded = Index::new();
    for row in entries(root)? {
        let filename = name(&row.path);
        if filename.ends_with(".ok") || filename.ends_with(".part") || !marker(&row.path).is_file()
        {
            continue;
        }
        if let Some(key) = audio_ids(filename) {
            if loaded
                .get(&key)
                .is_none_or(|old| old.modified <= row.modified)
            {
                loaded.insert(key, row);
            }
        }
    }
    indices.insert(root.to_path_buf(), loaded);
    Ok(())
}

pub fn complete_audio(root: &Path, provider: &str, id: &str) -> Result<Option<PathBuf>, String> {
    with_indices(|indices| {
        index(root, indices)?;
        let selected = &mut indices.get_mut(root).expect("loaded audio cache");
        let key = (provider.to_string(), id.to_string());
        let Some(row) = selected.get(&key) else {
            return Ok(None);
        };
        if !row.path.is_file() || !marker(&row.path).is_file() {
            selected.remove(&key);
            return Ok(None);
        }
        let fresh = row.modified.elapsed().unwrap_or_default() <= AUDIO_TTL;
        Ok(fresh.then(|| row.path.clone()))
    })
}

pub fn mark_audio(root: &Path, path: &Path) -> Result<Option<String>, String> {
    if path.parent() != Some(root) || !path.is_file() {
        return Err("download file is outside the cache or missing".into());
    }
    with_indices(|indices| {
        let file = File::open(path).map_err(|error| error.to_string())?;
        let now = SystemTime::now();
        file.set_modified(now).map_err(|error| error.to_string())?;
        OpenOptions::new()
            .write(true)
            .create(true)
            .truncate(false)
            .open(marker(path))
            .map_err(|error| error.to_string())?;
        index(root, indices)?;
        let Some(key) = audio_ids(name(path)) else {
            return Ok(None);
        };
        let id = key.1.clone();
        let bytes = file.metadata().map_err(|error| error.to_string())?.len();
        indices.get_mut(root).expect("loaded audio cache").insert(
            key,
            AudioEntry {
                path: path.to_path_buf(),
                modified: now,
                bytes,
            },
        );
        Ok(Some(id))
    })
}

pub fn touch_audio(root: &Path, path: &Path) -> Result<(), String> {
    if path.parent() != Some(root) {
        return Err("file is outside the audio cache".into());
    }
    with_indices(|indices| {
        let now = SystemTime::now();
        File::open(path)
            .and_then(|file| file.set_modified(now))
            .map_err(|error| error.to_string())?;
        if let Some(row) =
            audio_ids(name(path)).and_then(|key| indices.get_mut(root)?.get_mut(&key))
        {
            if row.path == path {
                row.modified = now;
            }
        }
        Ok(())
    })
}

pub fn sweep_audio(root: &Path) -> Result<(), String> {
    with_indices(|indices| {
        let mut keep = Vec::new();
        for row in entries(root)? {
            if let Some(file) = name(&row.path).strip_suffix(".ok") {
                if !root.join(file).is_file() {
                    let _ = fs::remove_file(row.path);
                }
            } else if row.modified.elapsed().unwrap_or_default() > AUDIO_TTL
                && fs::remove_file(&row.path).is_ok()
            {
                let _ = fs::remove_file(marker(&row.path));
            } else {
                keep.push(row);
            }
        }
        keep.sort_unstable_by_key(|row| row.modified);
        let mut total = keep.iter().map(|row| row.bytes).sum::<u64>();
        for row in keep {
            if total <= TRIM_AUDIO_BYTES {
                break;
            }
            if fs::remove_file(&row.path).is_ok() {
                total = total.saturating_sub(row.bytes);
                let _ = fs::remove_file(marker(&row.path));
            }
        }
        indices.remove(root);
        Ok(())
    })
}

#[derive(Serialize)]
pub struct AudioStats {
    pub bytes: u64,
    pub tracks: u64,
}

pub fn audio_stats(root: &Path) -> Result<AudioStats, String> {
    let mut stats = AudioStats {
        bytes: 0,
        tracks: 0,
    };
    for row in entries(root)? {
        let filename = name(&row.path);
        if filename.ends_with(".ok") {
            continue;
        }
        stats.bytes = stats.bytes.saturating_add(row.bytes);
        stats.tracks += u64::from(!filename.ends_with(".part"));
    }
    Ok(stats)
}

pub fn clear_audio(root: &Path) -> Result<(), String> {
    with_indices(|indices| {
        indices.remove(root);
        match fs::remove_dir_all(root) {
            Ok(()) => {}
            Err(error) if error.kind() == ErrorKind::NotFound => {}
            Err(error) => return Err(error.to_string()),
        }
        fs::create_dir_all(root).map_err(|error| error.to_string())
    })
}

fn response_path(root: &Path, key: &str) -> PathBuf {
    root.join(format!(
        "{RESPONSE_PREFIX}{:x}.json",
        Sha1::digest(key.as_bytes())
    ))
}

pub fn response_read(
    root: &Path,
    key: &str,
    now_ms: i64,
    max_age_ms: i64,
    allow_stale: bool,
) -> Option<Value> {
    let file = File::open(response_path(root, key)).ok()?;
    let decoded = serde_json::from_reader::<_, Value>(BufReader::new(file)).ok()?;
    let at = (decoded["at"].as_f64()? * 1000.0).round() as i64;
    let body = decoded["body"].as_object()?;
    (allow_stale || now_ms.saturating_sub(at) < max_age_ms).then(|| json!(body))
}

pub fn response_write(root: &Path, key: &str, now_ms: i64, body: &Value) -> Result<(), String> {
    let entry = json!({ "key": key, "at": now_ms as f64 / 1000.0, "body": body });
    crate::file_workflow::atomic_write(&response_path(root, key), |_, file| {
        serde_json::to_writer(file, &entry).map_err(|error| error.to_string())
    })
}

pub fn response_remove(root: &Path, key: &str) -> Result<(), String> {
    match fs::remove_file(response_path(root, key)) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.to_string()),
    }
}

pub fn prune_responses(root: &Path, clear: bool) -> Result<(), String> {
    for row in entries(root)? {
        if name(&row.path).starts_with(RESPONSE_PREFIX)
            && (clear || row.modified.elapsed().unwrap_or_default() > RESPONSE_TTL)
        {
            let _ = fs::remove_file(row.path);
        }
    }
    Ok(())
}

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
enum Request {
    AudioPath {
        provider: String,
        id: String,
        itag: String,
        extension: String,
    },
    AudioComplete {
        provider: String,
        id: String,
    },
    AudioMark {
        path: PathBuf,
    },
    AudioTouch {
        path: PathBuf,
    },
    AudioSweep,
    AudioTrim,
    AudioStats,
    AudioClear,
    ResponseRead {
        key: String,
        now_ms: i64,
        max_age_ms: i64,
        #[serde(default)]
        allow_stale: bool,
    },
    ResponseWrite {
        key: String,
        now_ms: i64,
        body: Value,
    },
    ResponseRemove {
        key: String,
    },
    ResponseSweep,
    ResponseClear,
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    #[derive(Deserialize)]
    struct Parameters {
        root: PathBuf,
        #[serde(flatten)]
        request: Request,
    }
    let Parameters { root, request } =
        serde_json::from_value(payload).map_err(|error| error.to_string())?;
    let root = root.as_path();
    match request {
        Request::AudioPath {
            provider,
            id,
            itag,
            extension,
        } => Ok(json!({
            "path": audio_path(root, &provider, &id, &itag, &extension)
        })),
        Request::AudioComplete { provider, id } => Ok(json!({
            "path": complete_audio(root, &provider, &id)?
        })),
        Request::AudioMark { path } => Ok(json!({ "id": mark_audio(root, &path)? })),
        Request::AudioTouch { path } => touch_audio(root, &path).map(|()| json!({})),
        Request::AudioSweep => sweep_audio(root).map(|()| json!({})),
        Request::AudioTrim => {
            if audio_stats(root)?.bytes > MAX_AUDIO_BYTES {
                sweep_audio(root)?;
            }
            Ok(json!({}))
        }
        Request::AudioStats => Ok(json!(audio_stats(root)?)),
        Request::AudioClear => clear_audio(root).map(|()| json!({})),
        Request::ResponseRead {
            key,
            now_ms,
            max_age_ms,
            allow_stale,
        } => Ok(json!({
            "body": response_read(root, &key, now_ms, max_age_ms, allow_stale)
        })),
        Request::ResponseWrite { key, now_ms, body } => {
            response_write(root, &key, now_ms, &body).map(|()| json!({}))
        }
        Request::ResponseRemove { key } => response_remove(root, &key).map(|()| json!({})),
        Request::ResponseSweep => prune_responses(root, false).map(|()| json!({})),
        Request::ResponseClear => prune_responses(root, true).map(|()| json!({})),
    }
}
