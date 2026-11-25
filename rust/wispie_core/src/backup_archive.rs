use std::fs::{self, File};
use std::io::{self, BufReader, BufWriter, ErrorKind, Write};
use std::path::{Path, PathBuf};

use serde_json::{json, Map, Value};
use walkdir::WalkDir;
use zip::write::SimpleFileOptions;
use zip::{CompressionMethod, ZipArchive, ZipWriter};

pub fn create(source: &Path, destination: &Path) -> Result<(), String> {
    let source = source.canonicalize().map_err(|error| error.to_string())?;
    let directory = destination
        .parent()
        .filter(|path| !path.as_os_str().is_empty())
        .unwrap_or_else(|| Path::new("."))
        .canonicalize()
        .map_err(|error| error.to_string())?;
    if directory.starts_with(&source) {
        return Err("archive destination must be outside the staging directory".into());
    }

    crate::file_workflow::atomic_write(destination, |_, output| write_archive(&source, output))
}

fn write_archive(source: &Path, output: &mut File) -> Result<(), String> {
    let mut zip = ZipWriter::new(BufWriter::new(output));
    for entry in WalkDir::new(source).sort_by_file_name() {
        let entry = entry.map_err(|error| error.to_string())?;
        if !entry.file_type().is_file() {
            continue;
        }
        let relative = entry
            .path()
            .strip_prefix(source)
            .map_err(|error| error.to_string())?;
        let entry_name = relative
            .iter()
            .map(|part| part.to_str().ok_or("invalid archive filename"))
            .collect::<Result<Vec<_>, _>>()?
            .join("/");
        let metadata = entry.metadata().map_err(|error| error.to_string())?;
        let options = SimpleFileOptions::default()
            .compression_method(CompressionMethod::Deflated)
            .large_file(metadata.len() >= u64::from(u32::MAX));
        zip.start_file(entry_name, options)
            .map_err(|error| error.to_string())?;
        let mut input = File::open(entry.path()).map_err(|error| error.to_string())?;
        io::copy(&mut input, &mut zip).map_err(|error| error.to_string())?;
    }
    let mut writer = zip.finish().map_err(|error| error.to_string())?;
    writer.flush().map_err(|error| error.to_string())
}

pub fn extract(source: &Path, destination: &Path) -> Result<PathBuf, String> {
    if fs::read_dir(destination)
        .map_err(|error| error.to_string())?
        .next()
        .is_some()
    {
        return Err("archive extraction requires an empty directory".into());
    }
    let input = File::open(source).map_err(|error| error.to_string())?;
    let mut zip = ZipArchive::new(BufReader::new(input)).map_err(|error| error.to_string())?;
    for index in 0..zip.len() {
        let mut entry = zip.by_index(index).map_err(|error| error.to_string())?;
        if !entry.is_file() {
            continue;
        }
        let Some(relative) = entry.enclosed_name() else {
            continue;
        };
        let path = destination.join(relative);
        if path == destination {
            continue;
        }
        if let Some(parent) = path.parent() {
            fs::create_dir_all(parent).map_err(|error| error.to_string())?;
        }
        let mut output = File::create(&path).map_err(|error| error.to_string())?;
        io::copy(&mut entry, &mut output).map_err(|error| error.to_string())?;
    }
    content_root(destination).map_err(|error| error.to_string())
}

fn content_root(directory: &Path) -> io::Result<PathBuf> {
    let mut entries = fs::read_dir(directory)?;
    if let Some(entry) = entries.next().transpose()? {
        if entries.next().is_none() && entry.file_type()?.is_dir() {
            let path = entry.path();
            for marker in [
                "metadata.json",
                "wispie_stats.db",
                "wispie_data.db",
                "app_settings.json",
            ] {
                match fs::metadata(path.join(marker)) {
                    Ok(metadata) if metadata.is_file() => return Ok(path),
                    Ok(_) => {}
                    Err(error) if error.kind() == ErrorKind::NotFound => {}
                    Err(error) => return Err(error),
                }
            }
        }
    }
    Ok(directory.to_path_buf())
}

const STATS_DATABASE: &str = "wispie_stats.db";
const DATA_DATABASE: &str = "wispie_data.db";

pub fn inspect(directory: &Path) -> Result<Value, String> {
    let flags = [
        ("hasSongsJson", "songs.json", None),
        ("hasUserDataJson", "user_data.json", Some("user_data_")),
        (
            "hasShuffleStateJson",
            "shuffle_state.json",
            Some("shuffle_state_"),
        ),
        (
            "hasPlaybackStateJson",
            "playback_state.json",
            Some("playback_state_"),
        ),
        ("hasMergedGroupsJson", "merged_groups.json", None),
        ("hasQueueHistoryJson", "queue_history.json", None),
        ("hasAppSettingsJson", "app_settings.json", None),
    ];
    let mut result: Map<_, _> = flags
        .iter()
        .map(|(flag, _, _)| (flag.to_string(), Value::Bool(false)))
        .collect();
    let mut stats_path = None;
    let mut data_path = None;

    for entry in WalkDir::new(directory).sort_by_file_name() {
        let entry = entry.map_err(|error| error.to_string())?;
        if !entry.file_type().is_file() {
            continue;
        }
        let Some(name) = entry.file_name().to_str() else {
            continue;
        };
        if name == STATS_DATABASE
            || (stats_path.is_none() && name.ends_with("_stats.db") && !name.starts_with("wispie_"))
        {
            stats_path = Some(entry.path().to_path_buf());
        }
        if name == DATA_DATABASE
            || (data_path.is_none() && name.ends_with("_data.db") && !name.starts_with("wispie_"))
        {
            data_path = Some(entry.path().to_path_buf());
        }
        for (flag, exact, prefix) in &flags {
            if name == *exact || prefix.is_some_and(|prefix| name.starts_with(prefix)) {
                let content = File::open(entry.path()).ok().and_then(|file| {
                    serde_json::from_reader::<_, Value>(BufReader::new(file)).ok()
                });
                let populated = match content {
                    Some(Value::Array(items)) => !items.is_empty(),
                    Some(Value::Object(items)) => !items.is_empty(),
                    _ => false,
                };
                if populated {
                    result.insert(flag.to_string(), Value::Bool(true));
                }
            }
        }
    }

    for (path, path_key, path_flag, tables) in [
        (
            stats_path,
            "statsDbPath",
            "hasStatsDb",
            &[("hasPlayHistory", "playsession")][..],
        ),
        (
            data_path,
            "dataDbPath",
            "hasDataDb",
            &[
                ("hasFavorites", "favorite"),
                ("hasSuggestless", "suggestless"),
                ("hasHidden", "hidden"),
                ("hasPlaylists", "playlist"),
                ("hasMergedGroups", "merged_song_group"),
                ("hasRecommendations", "recommendation_preference"),
                ("hasUserdata", "userdata"),
            ][..],
        ),
    ] {
        let names: Vec<_> = tables.iter().map(|(_, name)| *name).collect();
        let mut populated = path
            .as_ref()
            .map_or_else(Vec::new, |path| {
                crate::db::inspect_backup_tables(path, &names)
            })
            .into_iter();
        for (flag, _) in tables {
            result.insert(
                flag.to_string(),
                Value::Bool(populated.next().unwrap_or(false)),
            );
        }
        result.insert(path_flag.to_string(), Value::Bool(path.is_some()));
        result.insert(path_key.to_string(), json!(path));
    }
    Ok(Value::Object(result))
}

pub(crate) fn run(request: &Value) -> Result<Value, String> {
    let path = |key| {
        request
            .get(key)
            .and_then(Value::as_str)
            .map(Path::new)
            .ok_or_else(|| format!("backup archive needs {key}"))
    };
    let source = path("source")?;
    match request.get("op").and_then(Value::as_str) {
        Some("create") => {
            create(source, path("destination")?)?;
            Ok(json!({}))
        }
        Some("extract") => Ok(json!({ "root": extract(source, path("destination")?)? })),
        Some("inspect") => inspect(source),
        _ => Err("unknown backup archive operation".into()),
    }
}
