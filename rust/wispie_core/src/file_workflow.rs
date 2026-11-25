use std::fs::{self, File};
use std::io::{ErrorKind, Write};
use std::path::Path;

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

pub use crate::meta::{edit_tags, TagEdit};

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

#[derive(Deserialize, Serialize)]
pub struct PendingRename {
    pub from: String,
    pub to: String,
    pub url: String,
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
        Some("edit_tags") => {
            let edit = serde_json::from_value::<TagEdit>(payload.clone())
                .map_err(|error| error.to_string())?;
            edit_tags(target, edit, bytes.filter(|image| !image.is_empty()))?;
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
