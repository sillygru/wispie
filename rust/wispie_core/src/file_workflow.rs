use std::fs::{self, File};
use std::io::{ErrorKind, Write};
use std::path::{Component, Path, PathBuf};

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

pub use crate::meta::{edit_tags, TagEdit};

pub const RENAME_SLICE_LENGTH: usize = 25;

const RENAME_JOURNAL: &str = "bulk_rename_journal.json";

pub fn atomic_replace(source: &Path, destination: &Path) -> Result<(), String> {
    atomic_write(destination, |staging, _| {
        fs::copy(source, staging).map_err(|error| error.to_string())?;
        Ok(())
    })
}

pub(crate) fn atomic_write(
    destination: &Path,
    write: impl FnOnce(&Path, &mut File) -> Result<(), String>,
) -> Result<(), String> {
    let mut random = [0; 8];
    getrandom::getrandom(&mut random).map_err(|error| error.to_string())?;
    let staging =
        destination.with_file_name(format!(".wispie-{:016x}.tmp", u64::from_le_bytes(random)));
    let mut file = File::create_new(&staging).map_err(|error| error.to_string())?;
    let mut result = write(&staging, &mut file)
        .and_then(|()| file.sync_all().map_err(|error| error.to_string()));
    drop(file);
    if result.is_ok() {
        result = fs::rename(&staging, destination).map_err(|error| error.to_string());
    }
    if result.is_err() {
        let _ = fs::remove_file(staging);
    }
    result
}

#[derive(Clone, Deserialize, Serialize, PartialEq, Eq)]
pub struct PendingRename {
    pub from: String,
    pub to: String,
    pub url: String,
    #[serde(default, skip_serializing_if = "Vec::is_empty")]
    pub sidecars: Vec<PathBuf>,
}

pub fn read_rename_journal(directory: &Path) -> Result<Vec<PendingRename>, String> {
    let bytes = match fs::read(directory.join(RENAME_JOURNAL)) {
        Ok(bytes) => bytes,
        Err(error) if error.kind() == ErrorKind::NotFound => return Ok(Vec::new()),
        Err(error) => return Err(error.to_string()),
    };
    let entries = serde_json::from_slice::<Vec<Value>>(&bytes).unwrap_or_default();
    Ok(entries
        .into_iter()
        .filter_map(|entry| serde_json::from_value(entry).ok())
        .collect())
}

pub fn write_rename_journal(directory: &Path, entries: &[PendingRename]) -> Result<(), String> {
    atomic_write(&directory.join(RENAME_JOURNAL), |_, file| {
        let encoded = serde_json::to_vec(entries).map_err(|error| error.to_string())?;
        file.write_all(&encoded).map_err(|error| error.to_string())
    })
}

pub fn move_song(source: &Path, new_filename: &str) -> Result<(), String> {
    let mut components = Path::new(new_filename).components();
    if !matches!(components.next(), Some(Component::Normal(_))) || components.next().is_some() {
        return Err("song rename needs a single filename".into());
    }
    fs::rename(source, source.with_file_name(new_filename)).map_err(|error| error.to_string())
}

static JOURNAL_WRITE: std::sync::Mutex<()> = std::sync::Mutex::new(());

pub fn record_rename(directory: &Path, entry: PendingRename) -> Result<(), String> {
    let _write = JOURNAL_WRITE.lock().map_err(|error| error.to_string())?;
    let mut entries = read_rename_journal(directory)?;
    if !entries.contains(&entry) {
        entries.push(entry);
        write_rename_journal(directory, &entries)?;
    }
    Ok(())
}

pub fn acknowledge_renames(directory: &Path, acknowledged: &[PendingRename]) -> Result<(), String> {
    let _write = JOURNAL_WRITE.lock().map_err(|error| error.to_string())?;
    let mut entries = read_rename_journal(directory)?;
    let before = entries.len();
    entries.retain(|entry| !acknowledged.contains(entry));
    if entries.len() != before {
        write_rename_journal(directory, &entries)?;
    }
    Ok(())
}

pub fn recoverable_renames(directory: &Path) -> Result<Vec<PendingRename>, String> {
    Ok(read_rename_journal(directory)?
        .into_iter()
        .filter(|entry| Path::new(&entry.url).is_file())
        .collect())
}

pub fn rename_sidecars(target: &Path, sources: &[PathBuf]) {
    let Some(stem) = target.file_stem() else {
        return;
    };
    for source in sources {
        let Some(extension) = source.extension() else {
            continue;
        };
        let mut new_name = stem.to_os_string();
        new_name.push(".");
        new_name.push(extension);
        let destination = source.with_file_name(new_name);
        if source.is_file() && !destination.exists() {
            let _ = fs::rename(source, destination);
        }
    }
}

#[derive(Deserialize)]
pub struct CacheMove {
    pub from: PathBuf,
    pub to: PathBuf,
}

pub fn transfer_rename_caches(entries: &[CacheMove], cover: Option<&CacheMove>) -> Option<PathBuf> {
    for entry in entries {
        let _ = move_cached_file(entry);
    }
    cover
        .filter(|entry| move_cached_file(entry).is_ok() && entry.to.is_file())
        .map(|entry| entry.to.clone())
}

fn move_cached_file(entry: &CacheMove) -> std::io::Result<()> {
    if entry.from == entry.to || !entry.from.is_file() {
        return Ok(());
    }
    if entry.to.is_file() {
        return fs::remove_file(&entry.from);
    }
    if let Some(parent) = entry
        .to
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
    {
        fs::create_dir_all(parent)?;
    }
    fs::rename(&entry.from, &entry.to)
}

pub(crate) fn run(payload: &Value, bytes: Option<&[u8]>) -> Result<Value, String> {
    let path = |key| {
        payload
            .get(key)
            .and_then(Value::as_str)
            .map(Path::new)
            .ok_or_else(|| format!("file workflow needs {key}"))
    };
    let target = path("path")?;
    match payload.get("op").and_then(Value::as_str) {
        Some("replace") => {
            atomic_replace(path("source")?, target)?;
            Ok(json!({}))
        }
        Some("move_song") => {
            let filename = payload["new_filename"]
                .as_str()
                .ok_or("missing new filename")?;
            move_song(target, filename)?;
            Ok(json!({}))
        }
        Some("recoverable_renames") => {
            let entries = match payload.get("entries") {
                Some(entries) => serde_json::from_value::<Vec<PendingRename>>(entries.clone())
                    .map_err(|error| error.to_string())?
                    .into_iter()
                    .filter(|entry| Path::new(&entry.url).is_file())
                    .collect(),
                None => recoverable_renames(target)?,
            };
            Ok(json!({"entries": entries}))
        }
        Some("rename_sidecars") => {
            let sidecars = serde_json::from_value::<Vec<PathBuf>>(payload["sidecars"].clone())
                .map_err(|error| error.to_string())?;
            rename_sidecars(target, &sidecars);
            Ok(json!({}))
        }
        Some("transfer_rename_caches") => {
            let entries = serde_json::from_value::<Vec<CacheMove>>(payload["entries"].clone())
                .map_err(|error| error.to_string())?;
            let cover = serde_json::from_value::<Option<CacheMove>>(payload["cover"].clone())
                .map_err(|error| error.to_string())?;
            Ok(json!({ "cover": transfer_rename_caches(&entries, cover.as_ref()) }))
        }
        Some("edit_tags") => {
            let edit = serde_json::from_value::<TagEdit>(payload.clone())
                .map_err(|error| error.to_string())?;
            edit_tags(target, edit, bytes.filter(|image| !image.is_empty()))?;
            Ok(json!({}))
        }
        Some("rename_slice_length") => Ok(json!({"length": RENAME_SLICE_LENGTH})),
        Some("record_rename") => {
            let entry = serde_json::from_value(payload["entry"].clone())
                .map_err(|error| error.to_string())?;
            record_rename(target, entry)?;
            Ok(json!({}))
        }
        Some("acknowledge_renames") => {
            let entries = serde_json::from_value::<Vec<PendingRename>>(payload["entries"].clone())
                .map_err(|error| error.to_string())?;
            acknowledge_renames(target, &entries)?;
            Ok(json!({}))
        }
        Some("read_rename_journal") => Ok(json!({ "entries": read_rename_journal(target)? })),
        Some("write_rename_journal") => {
            let entries = serde_json::from_value::<Vec<PendingRename>>(payload["entries"].clone())
                .map_err(|error| error.to_string())?;
            write_rename_journal(target, &entries)?;
            Ok(json!({}))
        }
        _ => Err("unknown file workflow operation".into()),
    }
}
