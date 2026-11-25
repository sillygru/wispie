use std::collections::BTreeMap;
use std::fs::{self, File};
use std::io::{BufReader, BufWriter, ErrorKind, Write};
use std::path::{Path, PathBuf};

use serde::Deserialize;
use serde_json::{json, Map, Value};
use walkdir::WalkDir;

const TYPES: &[&str] = &[
    "userStats",
    "userData",
    "userSettings",
    "coverCache",
    "libraryCache",
    "searchIndex",
    "waveformCache",
    "colorCache",
    "lyricsCache",
    "artistArtCache",
    "albumArtCache",
];

const DOCUMENTS: &[(&str, &str, &str)] = &[
    ("songs", "songs.json", "userStats"),
    ("stats", "final_stats.json", "userStats"),
    ("merged", "merged_groups.json", "userStats"),
    ("queue", "queue_history.json", "userStats"),
    ("user", "user_data.json", "userData"),
    ("shuffle", "shuffle_state.json", "userData"),
    ("playback", "playback_state.json", "userData"),
    ("settings", "app_settings.json", "userSettings"),
];

#[derive(Clone, Copy)]
enum FileKind {
    Tree,
    File,
    Database,
}

struct Artifact {
    path: &'static str,
    entry: &'static str,
    kinds: &'static [&'static str],
    mode: FileKind,
    restore_only: bool,
}

const ARTIFACTS: &[Artifact] = &[
    Artifact {
        path: "covers",
        entry: "cache/covers/extracted",
        kinds: &["coverCache", "artistArtCache", "albumArtCache"],
        mode: FileKind::Tree,
        restore_only: false,
    },
    Artifact {
        path: "blurred",
        entry: "cache/covers/blurred",
        kinds: &["coverCache"],
        mode: FileKind::Tree,
        restore_only: false,
    },
    Artifact {
        path: "notification",
        entry: "cache/covers/notification",
        kinds: &["coverCache"],
        mode: FileKind::Tree,
        restore_only: false,
    },
    Artifact {
        path: "covers",
        entry: "cache/artist_art",
        kinds: &["artistArtCache"],
        mode: FileKind::Tree,
        restore_only: true,
    },
    Artifact {
        path: "covers",
        entry: "cache/album_art",
        kinds: &["albumArtCache"],
        mode: FileKind::Tree,
        restore_only: true,
    },
    Artifact {
        path: "library",
        entry: "cache/library/cached_songs.json",
        kinds: &["libraryCache"],
        mode: FileKind::File,
        restore_only: false,
    },
    Artifact {
        path: "index",
        entry: "cache/search/wispie_search_index.db",
        kinds: &["searchIndex"],
        mode: FileKind::Database,
        restore_only: false,
    },
    Artifact {
        path: "waveforms",
        entry: "cache/waveforms",
        kinds: &["waveformCache"],
        mode: FileKind::Tree,
        restore_only: false,
    },
    Artifact {
        path: "palette",
        entry: "cache/color/palette_cache.json",
        kinds: &["colorCache"],
        mode: FileKind::File,
        restore_only: false,
    },
    Artifact {
        path: "lyrics",
        entry: "cache/lyrics",
        kinds: &["lyricsCache"],
        mode: FileKind::Tree,
        restore_only: false,
    },
];

pub type BackupPaths = BTreeMap<String, PathBuf>;

fn selected_artifacts(selected: &[String]) -> impl Iterator<Item = &'static Artifact> + '_ {
    ARTIFACTS.iter().filter(|artifact| {
        selected
            .iter()
            .any(|kind| artifact.kinds.contains(&kind.as_str()))
    })
}

fn copy_file(source: &Path, destination: &Path) -> Result<(), String> {
    if let Some(parent) = destination
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
    {
        fs::create_dir_all(parent).map_err(|error| error.to_string())?;
    }
    crate::file_workflow::atomic_replace(source, destination)
}

fn transfer(source: &Path, destination: &Path, kind: FileKind) -> Result<(), String> {
    let metadata = match fs::metadata(source) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == ErrorKind::NotFound => return Ok(()),
        Err(error) => return Err(error.to_string()),
    };
    match kind {
        FileKind::File if metadata.is_file() => copy_file(source, destination),
        FileKind::Database if metadata.is_file() => {
            crate::db::files::copy(source, destination).map(|_| ())
        }
        FileKind::Tree if metadata.is_dir() => {
            for entry in WalkDir::new(source).follow_links(false) {
                let entry = entry.map_err(|error| error.to_string())?;
                if entry.file_type().is_file() {
                    let relative = entry
                        .path()
                        .strip_prefix(source)
                        .map_err(|error| error.to_string())?;
                    copy_file(entry.path(), &destination.join(relative))?;
                }
            }
            Ok(())
        }
        _ => Ok(()),
    }
}

pub fn stage(
    root: &Path,
    paths: &BackupPaths,
    selected: &[String],
    documents: &Map<String, Value>,
    exported_at: &str,
) -> Result<(), String> {
    let includes = |kind: &str| selected.iter().any(|key| key == kind);
    for (slot, name, kind) in [
        ("stats_db", "wispie_stats.db", "userStats"),
        ("data_db", "wispie_data.db", "userData"),
    ] {
        if let Some(path) = paths.get(slot).filter(|_| includes(kind)) {
            transfer(path, &root.join(name), FileKind::Database)?;
        }
    }
    for (key, filename, kind) in DOCUMENTS {
        if let Some(value) = documents
            .get(*key)
            .filter(|value| !value.is_null() && includes(kind))
        {
            write_json(&root.join(filename), value)?;
        }
    }
    for artifact in selected_artifacts(selected).filter(|artifact| !artifact.restore_only) {
        if let Some(path) = paths.get(artifact.path) {
            transfer(path, &root.join(artifact.entry), artifact.mode)?;
        }
    }
    write_json(
        &root.join("metadata.json"),
        &json!({
            "export_date": exported_at,
            "version": "2.0",
            "options": TYPES.iter().map(|kind| (*kind, includes(kind))).collect::<BTreeMap<_, _>>(),
        }),
    )
}

fn write_json(path: &Path, value: &Value) -> Result<(), String> {
    let file = File::create(path).map_err(|error| error.to_string())?;
    let mut writer = BufWriter::new(file);
    serde_json::to_writer(&mut writer, value).map_err(|error| error.to_string())?;
    writer.flush().map_err(|error| error.to_string())
}

pub fn restore_databases(paths: &BackupPaths, sources: &BackupPaths) -> Result<(), String> {
    for key in ["stats_db", "data_db"] {
        if let (Some(source), Some(destination)) = (sources.get(key), paths.get(key)) {
            transfer(source, destination, FileKind::Database)?;
        }
    }
    Ok(())
}

pub fn restore_artifacts(
    root: &Path,
    paths: &BackupPaths,
    selected: &[String],
) -> Result<(), String> {
    for artifact in selected_artifacts(selected) {
        if let Some(destination) = paths.get(artifact.path) {
            transfer(&root.join(artifact.entry), destination, artifact.mode)?;
        }
    }
    Ok(())
}

pub fn cache_flags(root: &Path) -> BTreeMap<&'static str, bool> {
    let mut flags = BTreeMap::new();
    for artifact in ARTIFACTS {
        let path = root.join(artifact.entry);
        let found = match artifact.mode {
            FileKind::Tree => WalkDir::new(path)
                .into_iter()
                .filter_map(Result::ok)
                .any(|entry| {
                    entry.file_type().is_file() && entry.metadata().is_ok_and(|info| info.len() > 0)
                }),
            _ => fs::metadata(path).is_ok_and(|info| info.is_file() && info.len() > 0),
        };
        for kind in artifact.kinds {
            let current = flags.entry(*kind).or_insert(false);
            *current |= found;
        }
    }
    flags
}

pub fn read_documents(root: &Path, selected: &[String]) -> Result<Map<String, Value>, String> {
    let mut documents = Map::new();
    for (key, filename, _) in DOCUMENTS {
        if !selected.iter().any(|selection| selection == key) {
            continue;
        }
        match File::open(root.join(filename)) {
            Ok(file) => {
                let value = serde_json::from_reader(BufReader::new(file))
                    .map_err(|error| format!("{filename}: {error}"))?;
                documents.insert((*key).to_string(), value);
            }
            Err(error) if error.kind() == ErrorKind::NotFound => {}
            Err(error) => return Err(error.to_string()),
        }
    }
    Ok(documents)
}

#[derive(Deserialize)]
struct Request {
    op: String,
    root: PathBuf,
    #[serde(default)]
    paths: BackupPaths,
    #[serde(default)]
    sources: BackupPaths,
    #[serde(default)]
    selected: Vec<String>,
    #[serde(default)]
    documents: Map<String, Value>,
    #[serde(default)]
    exported_at: String,
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    let request: Request = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    match request.op.as_str() {
        "stage" => {
            stage(
                &request.root,
                &request.paths,
                &request.selected,
                &request.documents,
                &request.exported_at,
            )?;
            Ok(json!({}))
        }
        "restore_artifacts" => {
            restore_artifacts(&request.root, &request.paths, &request.selected)?;
            Ok(json!({}))
        }
        "restore_databases" => {
            restore_databases(&request.paths, &request.sources)?;
            Ok(json!({}))
        }
        "cache_flags" => Ok(json!(cache_flags(&request.root))),
        "read_documents" => Ok(Value::Object(read_documents(
            &request.root,
            &request.selected,
        )?)),
        _ => Err("unknown backup workflow operation".into()),
    }
}
