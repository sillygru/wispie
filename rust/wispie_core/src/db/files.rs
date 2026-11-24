use std::fs;
use std::io::ErrorKind;
use std::path::Path;
use std::time::Duration;

use rusqlite::backup::{Backup, StepResult};
use rusqlite::{Connection, OpenFlags};
use serde_json::{json, Value};

use super::text_field;

const DATABASE_SUFFIXES: &[&str] = &["", "-journal", "-wal", "-shm"];

pub(super) fn run(payload: &Value) -> Result<Value, String> {
    let op = text_field(payload, "op")?;
    let path = text_field(payload, "path")?;
    match op {
        "copy" => {
            let copied = copy(
                Path::new(path),
                Path::new(text_field(payload, "destination")?),
            )?;
            Ok(json!({"copied": copied}))
        }
        "size" | "first_size" => {
            let mut size = 0;
            for suffix in DATABASE_SUFFIXES {
                match fs::metadata(format!("{path}{suffix}")) {
                    Ok(metadata) => {
                        size += metadata.len();
                        if op == "first_size" {
                            break;
                        }
                    }
                    Err(error) if error.kind() == ErrorKind::NotFound => {}
                    Err(error) => return Err(error.to_string()),
                }
            }
            Ok(json!({"size": size}))
        }
        "remove" => {
            for suffix in DATABASE_SUFFIXES {
                remove(&format!("{path}{suffix}"))?;
            }
            Ok(json!({}))
        }
        "quarantine" => {
            let destination = text_field(payload, "destination")?;
            for suffix in DATABASE_SUFFIXES {
                match fs::rename(format!("{path}{suffix}"), format!("{destination}{suffix}")) {
                    Ok(()) => {}
                    Err(error) if error.kind() == ErrorKind::NotFound => {}
                    Err(error) => return Err(error.to_string()),
                }
            }
            Ok(json!({}))
        }
        _ => Err(format!("unknown database file operation {op}")),
    }
}

fn remove(path: &str) -> Result<(), String> {
    match fs::remove_file(path) {
        Ok(()) => Ok(()),
        Err(error) if error.kind() == ErrorKind::NotFound => Ok(()),
        Err(error) => Err(error.to_string()),
    }
}

fn copy(source: &Path, destination: &Path) -> Result<bool, String> {
    if !source.try_exists().map_err(|error| error.to_string())? {
        return Ok(false);
    }
    if let Some(parent) = destination
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
    {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    let source = Connection::open_with_flags(
        source,
        OpenFlags::SQLITE_OPEN_READ_ONLY | OpenFlags::SQLITE_OPEN_NO_MUTEX,
    )
    .map_err(|error| format!("open backup source: {error}"))?;

    // SQLite copies a consistent snapshot, including committed WAL pages.
    let mut destination = Connection::open(destination)
        .map_err(|error| format!("open backup destination: {error}"))?;
    destination
        .busy_timeout(Duration::from_secs(5))
        .map_err(|error| error.to_string())?;
    let backup = Backup::new(&source, &mut destination).map_err(|error| error.to_string())?;
    match backup.step(-1).map_err(|error| error.to_string())? {
        StepResult::Done => Ok(true),
        _ => Err("database copy did not complete".to_string()),
    }
}
