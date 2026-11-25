use crate::file_workflow::atomic_write;
use serde::{Deserialize, Serialize};
use std::fs::{self, File};
use std::io;
use std::path::{Path, PathBuf};
use walkdir::WalkDir;

pub const VERSION: u32 = 3;

#[derive(Default, Serialize)]
pub struct Migration {
    pub moved: usize,
    pub dropped: usize,
    pub failed: usize,
    pub legacy_found: bool,
}

fn retired_waveform(name: &str) -> bool {
    name.starts_with("waveform_") && name.ends_with(".json")
}

fn legacy_destination(relative: &Path) -> Option<PathBuf> {
    let name = relative.file_name()?.to_str()?;
    if retired_waveform(name) {
        return None;
    }
    let first = relative.iter().next()?.to_str()?;
    if relative.parent()?.as_os_str().is_empty() {
        let bucket = if name.starts_with("waveform_v3_") && name.ends_with(".wfm") {
            "waveforms"
        } else if name.starts_with("beatmap_") {
            "beatmaps"
        } else if name.starts_with("youtube_") {
            "youtube"
        } else {
            return None;
        };
        return Some(Path::new(bucket).join(name));
    }
    let bucket = match first {
        "blurred_cache" => "blurred",
        "notification_cover_cache" => "notification",
        "lyrics_cache" => "lyrics",
        _ => return None,
    };
    Some(Path::new(bucket).join(relative.strip_prefix(first).ok()?))
}

fn remove(path: &Path, delete: impl FnOnce(&Path) -> io::Result<()>) -> bool {
    match delete(path) {
        Ok(()) => true,
        Err(error) => error.kind() == io::ErrorKind::NotFound,
    }
}

fn migrate_file(source: &Path, destination: &Path) -> bool {
    let Ok(source_metadata) = fs::metadata(source) else {
        return false;
    };
    if destination
        .metadata()
        .is_ok_and(|target| target.is_file() && (target.len() > 0 || source_metadata.len() == 0))
    {
        return remove(source, |path| fs::remove_file(path));
    }

    let Some(parent) = destination.parent() else {
        return false;
    };
    if fs::create_dir_all(parent).is_err() {
        return false;
    }
    if fs::rename(source, destination).is_ok() {
        return true;
    }

    let copied = atomic_write(destination, |_, out| {
        let mut input = File::open(source).map_err(|error| error.to_string())?;
        if io::copy(&mut input, out).map_err(|error| error.to_string())? != source_metadata.len() {
            return Err("cache file changed during migration".to_string());
        }
        Ok(())
    });
    copied.is_ok() && remove(source, |path| fs::remove_file(path))
}

fn existing(path: &Path, directory: bool, result: &mut Migration) -> bool {
    match path.symlink_metadata() {
        Ok(metadata) if directory && metadata.is_dir() || !directory && metadata.is_file() => {
            result.legacy_found = true;
            true
        }
        Err(error) if error.kind() != io::ErrorKind::NotFound => {
            result.failed += 1;
            false
        }
        _ => false,
    }
}

fn migrate_tree(
    source: &Path,
    root: &Path,
    destination: impl Fn(&Path) -> Option<PathBuf>,
    result: &mut Migration,
) {
    if !existing(source, true, result) {
        return;
    }
    let failures_before = result.failed;
    for entry in WalkDir::new(source).min_depth(1).follow_links(false) {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => {
                result.failed += 1;
                continue;
            }
        };
        if !entry.file_type().is_file() {
            continue;
        }
        let path = entry.path();
        let Ok(relative) = path.strip_prefix(source) else {
            result.failed += 1;
            continue;
        };
        match destination(relative) {
            Some(ref target) if migrate_file(path, &root.join(target)) => result.moved += 1,
            Some(_) => result.failed += 1,
            None if remove(path, |path| fs::remove_file(path)) => result.dropped += 1,
            None => result.failed += 1,
        }
    }
    if result.failed == failures_before && !remove(source, |path| fs::remove_dir_all(path)) {
        result.failed += 1;
    }
}

pub fn migrate(support: &Path, root: &Path, orphan_dirs: &[PathBuf]) -> Migration {
    let mut result = Migration::default();
    for name in ["gru_cache_v3", "gru_cache_v2"] {
        migrate_tree(&support.join(name), root, legacy_destination, &mut result);
    }
    migrate_tree(
        &support.join("artwork_cache"),
        root,
        |relative| Some(Path::new("remote_art").join(relative.file_name()?)),
        &mut result,
    );
    for (name, target) in [
        ("palette_cache.json", "palettes/palettes.json"),
        ("youtube_feed.json", "youtube/feed.json"),
    ] {
        let source = support.join(name);
        if existing(&source, false, &mut result) {
            if migrate_file(&source, &root.join(target)) {
                result.moved += 1;
            } else {
                result.failed += 1;
            }
        }
    }
    for path in ["palettes", "waveform_temp", "beat_analysis_temp"]
        .map(|name| support.join(name))
        .iter()
        .chain(orphan_dirs)
    {
        if existing(path, true, &mut result) && !remove(path, |path| fs::remove_dir_all(path)) {
            result.failed += 1;
        }
    }
    match root.join("waveforms").read_dir() {
        Ok(entries) => {
            for entry in entries {
                match entry {
                    Ok(entry) if entry.file_type().is_ok_and(|kind| kind.is_file()) => {
                        let name = entry.file_name();
                        let name = name.to_string_lossy();
                        if retired_waveform(&name) || name.ends_with(".part") {
                            if remove(&entry.path(), |path| fs::remove_file(path)) {
                                result.dropped += 1;
                            } else {
                                result.failed += 1;
                            }
                        }
                    }
                    Err(_) => result.failed += 1,
                    _ => {}
                }
            }
        }
        Err(error) if error.kind() != io::ErrorKind::NotFound => result.failed += 1,
        Err(_) => {}
    }
    result
}

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
enum Request {
    Migrate {
        support: PathBuf,
        root: PathBuf,
        orphan_dirs: Vec<PathBuf>,
    },
    Prune {
        root: PathBuf,
        covers: PathBuf,
        songs: Vec<CacheTrack>,
        extra_covers: Vec<PathBuf>,
        extra_notification: Vec<String>,
    },
}

pub(crate) fn run(payload: serde_json::Value) -> Result<serde_json::Value, String> {
    let request: Request = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    match request {
        Request::Migrate {
            support,
            root,
            orphan_dirs,
        } => serde_json::to_value(migrate(&support, &root, &orphan_dirs)),
        Request::Prune {
            root,
            covers,
            songs,
            extra_covers,
            extra_notification,
        } => serde_json::to_value(prune(
            &root,
            &covers,
            &songs,
            &extra_covers,
            &extra_notification,
        )),
    }
    .map_err(|error| error.to_string())
}

const MIB: u64 = 1024 * 1024;

#[derive(Deserialize)]
pub struct CacheTrack {
    pub filename: String,
    pub url: String,
    pub cover: String,
}

#[derive(Default, Serialize)]
pub struct Pruned {
    pub orphans: usize,
    pub evicted: usize,
    pub bytes: u64,
}

fn normalize(path: &Path) -> PathBuf {
    use std::path::Component;
    let mut normalized = PathBuf::new();
    for part in path.components() {
        match part {
            Component::CurDir => {}
            Component::ParentDir
                if matches!(
                    normalized.components().next_back(),
                    Some(Component::Normal(_))
                ) =>
            {
                normalized.pop();
            }
            Component::ParentDir if normalized.has_root() => {}
            _ => normalized.push(part),
        }
    }
    normalized
}

fn cache_key(text: &str) -> String {
    use sha1::{Digest, Sha1};
    format!("{:x}", Sha1::digest(text))
}

fn notification_filename(cover: &str) -> String {
    let mut name: String = cover
        .rsplit(['/', '\\'])
        .next()
        .unwrap_or_default()
        .chars()
        .map(|c| {
            if c.is_ascii_alphanumeric() || c == '_' || c == '-' {
                c
            } else {
                '_'
            }
        })
        .collect();
    if name.is_empty() || name == "_" {
        name = "cover".to_string();
    }
    name.push_str(".jpg");
    name
}

pub fn prune(
    root: &Path,
    cover_dir: &Path,
    songs: &[CacheTrack],
    extra_covers: &[PathBuf],
    extra_notification: &[String],
) -> Pruned {
    use std::collections::HashSet;
    let mut result = Pruned::default();
    if songs.is_empty() {
        return result;
    }

    let mut covers: HashSet<PathBuf> = extra_covers.iter().map(|path| normalize(path)).collect();
    let mut notifications: HashSet<PathBuf> = extra_notification
        .iter()
        .map(|key| PathBuf::from(format!("{key}.jpg")))
        .collect();
    let mut remote_art = HashSet::new();
    let mut blurred = HashSet::new();
    let mut waveforms = HashSet::new();
    let mut beatmaps = HashSet::new();
    let mut lyrics = HashSet::new();

    for song in songs {
        if !song.filename.is_empty() {
            let key = cache_key(&song.filename);
            blurred.insert(PathBuf::from(format!("blurred_{key}.jpg")));
            waveforms.insert(PathBuf::from(format!("waveform_v3_{key}.wfm")));
            beatmaps.insert(PathBuf::from(format!("beatmap_{key}.json")));
            lyrics.insert(PathBuf::from(format!("rich_{key}.json")));
            lyrics.insert(PathBuf::from(format!("remote_{key}.lrc")));
        }
        if !song.url.is_empty() {
            let key = cache_key(&song.url);
            lyrics.insert(PathBuf::from(format!("{key}.json")));
        }
        if !song.cover.is_empty() {
            notifications.insert(PathBuf::from(notification_filename(&song.cover)));
            if song.cover.starts_with("http") {
                let key = cache_key(&song.cover);
                remote_art.insert(PathBuf::from(format!("art_{key}.img")));
            } else if !song.cover.starts_with("content://") {
                covers.insert(normalize(Path::new(&song.cover)));
            }
        }
    }

    for (dir, keep, budget_mib, full_path) in [
        (cover_dir.to_path_buf(), Some(&covers), 0, true),
        (root.join("remote_art"), Some(&remote_art), 96, false),
        (root.join("blurred"), Some(&blurred), 128, false),
        (root.join("notification"), Some(&notifications), 32, false),
        (root.join("waveforms"), Some(&waveforms), 64, false),
        (root.join("beatmaps"), Some(&beatmaps), 64, false),
        (root.join("lyrics"), Some(&lyrics), 32, false),
        (root.join("youtube"), None, 32, false),
    ] {
        let mut files = Vec::new();
        let mut total = 0;
        for entry in WalkDir::new(dir)
            .min_depth(1)
            .into_iter()
            .filter_map(Result::ok)
        {
            if !entry.file_type().is_file() {
                continue;
            }
            let Ok(stat) = entry.metadata() else {
                continue;
            };
            let bytes = stat.len();
            let orphan = keep.is_some_and(|keep| {
                if full_path {
                    !keep.contains(&normalize(entry.path()))
                } else {
                    !keep.contains(Path::new(entry.file_name()))
                }
            });
            if bytes == 0 || orphan {
                if fs::remove_file(entry.path()).is_ok() {
                    result.orphans += 1;
                    result.bytes += bytes;
                }
            } else if budget_mib > 0 {
                total += bytes;
                files.push((stat.modified().ok(), entry.into_path(), bytes));
            }
        }

        let budget = budget_mib * MIB;
        if total > budget {
            files.sort_unstable();
            for (_, file, bytes) in files {
                if total <= budget * 4 / 5 {
                    break;
                }
                if fs::remove_file(file).is_ok() {
                    total -= bytes;
                    result.evicted += 1;
                    result.bytes += bytes;
                }
            }
        }
    }
    result
}
