//! Pre-scan folder probe: can this folder be listed, and can bytes actually be
//! read from a few files? Distinguishes an empty folder from permission denied.
//!
//! Ported from `storage_probe_service.dart`.

use crate::formats;
use serde_json::{json, Value};
use std::fs;
use std::io::Read;
use std::path::{Path, PathBuf};

const LIST_CAP: usize = 40;
const READ_SAMPLE: usize = 5;

pub fn run(payload: &Value) -> Value {
    let path = payload.get("path").and_then(Value::as_str).unwrap_or("");
    probe(path)
}

fn probe(path: &str) -> Value {
    let root = Path::new(path);

    match fs::metadata(root) {
        Ok(meta) if meta.is_dir() => {}
        Ok(_) => return unlisted(path, false, "directory does not exist"),
        Err(error) => return unlisted(path, false, &describe(&error)),
    }

    let mut files: Vec<PathBuf> = Vec::new();
    if let Err(error) = collect(root, &mut files) {
        return unlisted(path, true, &describe(&error));
    }

    if files.is_empty() {
        return json!({
            "path": path,
            "exists": true,
            "listed": true,
            "filesFound": 0,
            "sampled": 0,
            "readable": 0,
        });
    }

    let sample = &files[..files.len().min(READ_SAMPLE)];
    let mut readable = 0usize;
    let mut read_error: Option<String> = None;
    for file in sample {
        match fs::File::open(file) {
            Ok(mut handle) => {
                let mut byte = [0u8; 1];
                // An empty file still opened and read: EOF is not a block.
                match handle.read_exact(&mut byte) {
                    Ok(()) => readable += 1,
                    Err(error) if error.kind() == std::io::ErrorKind::UnexpectedEof => {
                        readable += 1
                    }
                    Err(error) => {
                        read_error.get_or_insert(format!(
                            "{} ({})",
                            describe(&error),
                            file.display()
                        ));
                    }
                }
            }
            Err(error) => {
                read_error.get_or_insert(format!("{} ({})", describe(&error), file.display()));
            }
        }
    }

    let mut result = json!({
        "path": path,
        "exists": true,
        "listed": true,
        "filesFound": files.len(),
        "sampled": sample.len(),
        "readable": readable,
    });
    if let Some(message) = read_error {
        result["readError"] = Value::String(message);
    }
    result
}

fn unlisted(path: &str, exists: bool, reason: &str) -> Value {
    json!({
        "path": path,
        "exists": exists,
        "listed": false,
        "listError": reason,
        "filesFound": 0,
        "sampled": 0,
        "readable": 0,
    })
}

/// Recursive listing without following links, stopping at the cap the probe
/// needs. A read error anywhere in the walk leaves the folder unlisted, which is
/// what the Dart walk did when its stream emitted.
fn collect(root: &Path, out: &mut Vec<PathBuf>) -> std::io::Result<()> {
    let mut pending: Vec<PathBuf> = vec![root.to_path_buf()];
    while let Some(dir) = pending.pop() {
        let mut subdirs: Vec<PathBuf> = Vec::new();
        for entry in fs::read_dir(&dir)? {
            let entry = entry?;
            let kind = entry.file_type()?;
            if kind.is_file() {
                let path = entry.path();
                if formats::is_supported_path(&path) {
                    out.push(path);
                    if out.len() >= LIST_CAP {
                        return Ok(());
                    }
                }
            } else if kind.is_dir() {
                subdirs.push(entry.path());
            }
        }
        pending.extend(subdirs);
    }
    Ok(())
}

fn describe(error: &std::io::Error) -> String {
    match error.kind() {
        std::io::ErrorKind::PermissionDenied => format!("FileSystemException: {}", error),
        std::io::ErrorKind::NotFound => {
            "FileSystemException: no such file or directory".to_string()
        }
        _ => format!("FileSystemException: {error}"),
    }
}
