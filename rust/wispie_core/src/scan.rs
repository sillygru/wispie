//! The library scan: one walk, then parallel parsing.
//! Reconciliation lives here too, so a rescan costs one `stat` per file.

use crate::cover;
use crate::emitter::{Emit, Emitter};
use crate::formats;
use crate::lyrics_files;
use crate::meta;
use crate::model::{ScanRequest, SongJson};
use crate::CANCEL;
use rayon::prelude::*;
use serde::Deserialize;
use serde_json::json;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::Ordering;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};
use walkdir::WalkDir;

/// Files are handed to the pool in groups this many times the worker count, so a
/// single slow file cannot leave every other core idle.
const CHUNK_PER_THREAD: usize = 4;

struct Context<'a> {
    covers_dir: PathBuf,
    play_counts: &'a HashMap<String, i64>,
    fast_mode: bool,
    min_file_size: u64,
    by_url: HashMap<&'a str, &'a SongJson>,
    by_filename: HashMap<&'a str, &'a SongJson>,
    folder_covers: Mutex<HashMap<PathBuf, Option<String>>>,
    lyrics: lyrics_files::LyricsIndex,
}

enum Piece {
    Song(Box<SongJson>),
    Unreadable,
    Skip,
}

pub fn run(request: ScanRequest, emitter: &Emitter) -> Result<(), String> {
    let covers_dir = PathBuf::from(&request.covers_dir);
    if !covers_dir.as_os_str().is_empty() && !covers_dir.exists() {
        if let Err(e) = fs::create_dir_all(&covers_dir) {
            return Err(format!("cannot create covers directory: {e}"));
        }
    }

    // Lyric files come out of the same walk as the songs, plus whatever the
    // configured lyrics folders hold, so linking costs no second pass.
    let (files, unreachable, lyric_files) = collect(
        &request.roots,
        &request.excluded_folders,
        request.include_videos,
        true,
    );
    let mut lyrics = lyrics_files::index_paths(lyric_files);
    lyrics_files::merge(
        &mut lyrics,
        lyrics_files::index_roots(&request.lyrics_roots, &request.excluded_folders),
    );

    let mut context = Context {
        covers_dir,
        play_counts: &request.play_counts,
        fast_mode: request.fast_mode,
        min_file_size: request.min_file_size_bytes,
        by_url: HashMap::with_capacity(request.existing.len()),
        by_filename: HashMap::with_capacity(request.existing.len()),
        folder_covers: Mutex::new(HashMap::new()),
        lyrics,
    };
    for song in &request.existing {
        context.by_url.insert(song.url.as_str(), song);
        context.by_filename.insert(song.filename.as_str(), song);
    }

    let total = files.len();
    emitter.emit(Emit::Progress {
        done: 0,
        total: total as u64,
    });

    let batch_size = request.batch_size.clamp(1, 5000);
    let chunk_size = chunk_size(request.concurrency);

    let mut batch: Vec<SongJson> = Vec::with_capacity(batch_size.min(total.max(1)));
    let mut unreadable = 0u64;
    let mut scanned = 0u64;
    let mut processed = 0u64;
    let mut cancelled = false;

    for chunk in files.chunks(chunk_size) {
        if CANCEL.load(Ordering::Relaxed) {
            cancelled = true;
            break;
        }

        let pieces: Vec<Piece> = chunk
            .par_iter()
            .map(|path| {
                // One malformed file must never take the scan down with it.
                std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
                    process_file(path, &context)
                }))
                .unwrap_or(Piece::Skip)
            })
            .collect();

        for piece in pieces {
            match piece {
                Piece::Song(song) => {
                    if song.is_placeholder() {
                        unreadable += 1;
                    }
                    batch.push(*song);
                    scanned += 1;
                }
                Piece::Unreadable => unreadable += 1,
                Piece::Skip => {}
            }
        }

        processed += chunk.len() as u64;
        emitter.emit(Emit::Progress {
            done: processed.min(total as u64),
            total: total as u64,
        });

        if batch.len() >= batch_size {
            emitter.emit(Emit::Songs(std::mem::take(&mut batch)));
        }
    }

    if !batch.is_empty() {
        emitter.emit(Emit::Songs(batch));
    }

    emitter.emit(Emit::Done {
        unreadable,
        unreachable,
        scanned,
        cancelled,
        formats: None,
    });
    Ok(())
}

fn chunk_size(concurrency: usize) -> usize {
    let threads = if concurrency > 0 {
        concurrency
    } else {
        std::thread::available_parallelism()
            .map(|n| n.get())
            .unwrap_or(4)
    };
    (threads * CHUNK_PER_THREAD).max(1)
}

/// Every media file to look at, plus the roots that could not be listed.
/// An unlistable root is reported, never treated as empty.
fn collect(
    roots: &[String],
    excluded_folders: &[String],
    include_videos: bool,
    collect_lyrics: bool,
) -> (Vec<PathBuf>, Vec<String>, Vec<PathBuf>) {
    let mut files = Vec::new();
    let mut unreachable = Vec::new();
    let mut lyrics = Vec::new();

    for root in roots {
        let path = Path::new(root);
        if !path.exists() {
            unreachable.push(root.clone());
            continue;
        }

        let mut root_failed = false;
        let entries = WalkDir::new(path)
            .follow_links(false)
            .into_iter()
            .filter_entry(|entry| !is_excluded(entry.path(), excluded_folders));
        for entry in entries {
            match entry {
                Ok(entry) => {
                    if !entry.file_type().is_file() {
                        continue;
                    }
                    let file_path = entry.path();
                    if collect_lyrics && lyrics_files::is_lyrics_path(file_path) {
                        lyrics.push(file_path.to_path_buf());
                        continue;
                    }
                    if !formats::is_supported_path(file_path) {
                        continue;
                    }
                    if !include_videos && formats::is_video_path(file_path) {
                        continue;
                    }
                    files.push(file_path.to_path_buf());
                }
                Err(_) => {
                    root_failed = true;
                    break;
                }
            }
        }

        if root_failed {
            unreachable.push(root.clone());
        }
    }

    files.sort();
    files.dedup();
    lyrics.sort();
    lyrics.dedup();
    (files, unreachable, lyrics)
}

#[derive(Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct LibraryChangesRequest {
    database_path: PathBuf,
    roots: Vec<String>,
    excluded_folders: Vec<String>,
    include_videos: bool,
    min_file_size_bytes: u64,
    prevent_duplicate_tracks: bool,
}

pub(crate) struct LibraryFile {
    pub path: PathBuf,
    pub mtime: Option<f64>,
}

pub fn library_changes(request: LibraryChangesRequest, emitter: &Emitter) -> Result<(), String> {
    let mut baseline = crate::db::library_file_baseline(&request.database_path)?;
    baseline.retain(|_, file| {
        request.roots.iter().any(|root| file.path.starts_with(root))
            && !is_excluded(&file.path, &request.excluded_folders)
            && (request.include_videos || !formats::is_video_path(&file.path))
    });
    let mut current = HashMap::with_capacity(baseline.len());
    // The library writes one row per filename. Match the scanner's folder
    // order so two copies of the same name do not look like changes on launch.
    for root in &request.roots {
        let (files, unreachable, _) = collect(
            std::slice::from_ref(root),
            &request.excluded_folders,
            request.include_videos,
            false,
        );
        if !unreachable.is_empty() || !Path::new(root).is_dir() {
            emitter.emit(Emit::Json(json!({ "changes": null })));
            return Ok(());
        }
        for path in files {
            let Some(filename) = path.file_name().and_then(|name| name.to_str()) else {
                continue;
            };
            if request.prevent_duplicate_tracks && current.contains_key(filename) {
                continue;
            }
            let Ok(metadata) = fs::metadata(&path) else {
                emitter.emit(Emit::Json(json!({ "changes": null })));
                return Ok(());
            };
            if metadata.is_file() && metadata.len() >= request.min_file_size_bytes {
                current.insert(
                    filename.to_owned(),
                    LibraryFile {
                        path,
                        mtime: mtime_secs(&metadata),
                    },
                );
            }
        }
    }
    let mut new = 0;
    let mut changed = 0;
    for (filename, file) in current {
        match baseline.remove(&filename) {
            None => new += 1,
            Some(previous) => {
                if previous.path != file.path || !same_mtime(previous.mtime, file.mtime) {
                    changed += 1;
                }
            }
        }
    }
    emitter.emit(Emit::Json(json!({
        "changes": { "new": new, "changed": changed, "deleted": baseline.len() }
    })));
    Ok(())
}

/// Whether a `.lrc`/`.ttml` file named after [filename] was found.
fn has_sidecar(context: &Context, filename: &str) -> bool {
    lyrics_files::lookup(&context.lyrics, filename).is_some()
}

pub(crate) fn is_excluded(path: &Path, excluded_folders: &[String]) -> bool {
    excluded_folders.iter().any(|excluded| {
        let excluded = Path::new(excluded);
        path == excluded || path.starts_with(excluded)
    })
}

fn now_epoch_sec() -> f64 {
    SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|d| d.as_secs_f64())
        .unwrap_or(0.0)
}

fn mtime_secs(metadata: &fs::Metadata) -> Option<f64> {
    metadata
        .modified()
        .ok()
        .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
        .map(|d| d.as_secs_f64())
}

fn same_mtime(previous: Option<f64>, current: Option<f64>) -> bool {
    match (previous, current) {
        // Timestamps written by platform adapters can be truncated to millis.
        (Some(previous), Some(current)) => (previous - current).abs() < 0.001,
        _ => previous == current,
    }
}

/// Everything one file says about itself, for a row that reached the library
/// outside a scan (an import, a file opened from the OS).
pub fn hydrate(existing: &SongJson, covers_dir: &Path) -> Option<SongJson> {
    let path = Path::new(&existing.url);
    if !path.exists() {
        return None;
    }
    let metadata = fs::metadata(path).ok()?;
    let play_counts = HashMap::new();
    let context = Context {
        covers_dir: covers_dir.to_path_buf(),
        play_counts: &play_counts,
        fast_mode: false,
        min_file_size: 0,
        by_url: HashMap::new(),
        by_filename: HashMap::new(),
        folder_covers: Mutex::new(HashMap::new()),
        lyrics: path
            .parent()
            .map(|parent| lyrics_files::index_directories([parent]))
            .unwrap_or_default(),
    };

    let mut song = build_song(
        path,
        existing.url.clone(),
        existing.filename.clone(),
        mtime_secs(&metadata),
        Some(existing),
        &context,
    )?;
    // Video rows carry metadata from the FFmpeg pass, which is not re-read here.
    if formats::is_video_path(path) {
        song.title = existing.title.clone();
        song.artist = existing.artist.clone();
        song.album = existing.album.clone();
        song.duration = existing.duration;
        song.has_lyrics = existing.has_lyrics;
        song.song_date_epoch_sec = existing.song_date_epoch_sec;
        song.cover_url = existing.cover_url.clone();
    }
    Some(song)
}

fn process_file(path: &Path, context: &Context) -> Piece {
    let metadata = match fs::metadata(path) {
        Ok(m) => m,
        Err(_) => return Piece::Unreadable,
    };

    if context.min_file_size > 0 && metadata.len() < context.min_file_size {
        return Piece::Skip;
    }

    let mtime = mtime_secs(&metadata);

    let url = path.to_string_lossy().to_string();
    let filename = match path.file_name().and_then(|s| s.to_str()) {
        Some(name) => name.to_string(),
        None => return Piece::Skip,
    };

    // Path first, then basename: the row's primary key is the basename, so a
    // file that merely moved folders still matches the row it should reuse.
    let existing = context
        .by_url
        .get(url.as_str())
        .or_else(|| context.by_filename.get(filename.as_str()))
        .copied();

    if let Some(existing) = existing {
        if let Some(current) = mtime {
            if same_mtime(existing.mtime, mtime) {
                return Piece::Song(Box::new(reuse_song(
                    existing, url, filename, current, context,
                )));
            }
        }
    }

    if context.fast_mode {
        return Piece::Song(Box::new(fast_song(existing, url, filename, mtime, context)));
    }

    match build_song(path, url, filename, mtime, existing, context) {
        Some(song) => Piece::Song(Box::new(song)),
        None => Piece::Unreadable,
    }
}

fn reuse_song(
    existing: &SongJson,
    url: String,
    filename: String,
    mtime: f64,
    context: &Context,
) -> SongJson {
    SongJson {
        title: existing.title.clone(),
        artist: existing.artist.clone(),
        album: existing.album.clone(),
        // The file we just walked to is where it is now; a row matched by
        // basename may still carry the folder it used to be in.
        url,
        filename: existing.filename.clone().pipe_if_empty(&filename),
        cover_url: existing.cover_url.clone(),
        has_lyrics: existing.has_lyrics || has_sidecar(context, &filename),
        play_count: context
            .play_counts
            .get(&filename)
            .copied()
            .unwrap_or(existing.play_count),
        duration: existing.duration,
        mtime: Some(mtime),
        created_epoch_sec: Some(existing.created_epoch_sec.unwrap_or_else(now_epoch_sec)),
        song_date_epoch_sec: existing.song_date_epoch_sec,
    }
}

trait PipeIfEmpty {
    fn pipe_if_empty(self, fallback: &str) -> String;
}

impl PipeIfEmpty for String {
    fn pipe_if_empty(self, fallback: &str) -> String {
        if self.is_empty() {
            fallback.to_string()
        } else {
            self
        }
    }
}

/// Fast mode reads no metadata and extracts no art, so it has nothing better to
/// offer than what a previous pass already found.
fn fast_song(
    existing: Option<&SongJson>,
    url: String,
    filename: String,
    mtime: Option<f64>,
    context: &Context,
) -> SongJson {
    let stem = Path::new(&url)
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_string();

    SongJson {
        title: existing.map(|s| s.title.clone()).unwrap_or(stem),
        artist: existing
            .map(|s| s.artist.clone())
            .unwrap_or_else(|| "Unknown Artist".to_string()),
        album: existing
            .map(|s| s.album.clone())
            .unwrap_or_else(|| "Unknown Album".to_string()),
        cover_url: existing.and_then(|s| s.cover_url.clone()),
        has_lyrics: existing.map(|s| s.has_lyrics).unwrap_or(false)
            || has_sidecar(context, &filename),
        play_count: context
            .play_counts
            .get(&filename)
            .copied()
            .or_else(|| existing.map(|s| s.play_count))
            .unwrap_or(0),
        duration: existing.and_then(|s| s.duration),
        mtime,
        created_epoch_sec: Some(
            existing
                .and_then(|s| s.created_epoch_sec)
                .unwrap_or_else(now_epoch_sec),
        ),
        song_date_epoch_sec: existing.and_then(|s| s.song_date_epoch_sec),
        filename,
        url,
    }
}

/// Everything one file says about itself, plus whatever art can be found for it.
fn build_song(
    path: &Path,
    url: String,
    filename: String,
    mtime: Option<f64>,
    existing: Option<&SongJson>,
    context: &Context,
) -> Option<SongJson> {
    let is_video = formats::is_video_path(path);

    let mut title = path
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("")
        .to_string();
    let mut artist = "Unknown Artist".to_string();
    let mut album = "Unknown Album".to_string();
    let mut duration = None;
    let mut has_lyrics = false;
    let mut song_date = None;

    // A cached cover is checked first, and video files require a decodable one:
    // a video's cached cover is a frame grab, and a truncated grab is not art.
    let mut cover_url = cover::find_cached_cover(&context.covers_dir, &filename, is_video);

    // Video containers are not tag-parsed: parsers give up on large MKV/WebM.
    // Their metadata arrives later from the FFmpeg thumbnail pass.
    if !is_video {
        if let Ok(tags) = meta::read_tags(path, cover_url.is_none()) {
            if let Some(value) = tags.title {
                title = value;
            }
            if let Some(value) = tags.artist {
                artist = value;
            }
            if let Some(value) = tags.album {
                album = value;
            }
            song_date = match tags.year.and_then(meta::year_start_epoch_sec) {
                Some(year) => Some(year),
                None => existing.and_then(|s| s.song_date_epoch_sec),
            };
            duration = tags.duration_secs;
            has_lyrics = tags.has_lyrics;

            if cover_url.is_none() {
                if let Some(picture) = tags.picture {
                    if let Some((offset, kind)) = crate::image_sig::recover_embedded_cover(&picture)
                    {
                        if let Ok(saved) = cover::save_optimized_cover(
                            &picture[offset..],
                            &context.covers_dir,
                            Some(kind.extension()),
                        ) {
                            cover_url = Some(saved);
                        }
                    }
                }
            }
        }
    }

    if cover_url.is_none() {
        if let Some(parent) = path.parent() {
            cover_url = folder_cover(context, parent);
        }
    }

    if !is_video && cover_url.is_none() {
        cover_url = cover::manual_extract(path, &context.covers_dir);
    }

    // A sidecar is lyrics whether or not the file has a tag for them.
    has_lyrics = has_lyrics || has_sidecar(context, &filename);

    Some(SongJson {
        title,
        artist,
        album,
        filename,
        url,
        cover_url,
        has_lyrics,
        play_count: 0,
        duration,
        mtime,
        created_epoch_sec: existing.and_then(|s| s.created_epoch_sec),
        song_date_epoch_sec: song_date,
    })
}

/// Folder covers are cached per directory; a release folder repeats the lookup.
fn folder_cover(context: &Context, folder: &Path) -> Option<String> {
    let mut cache = match context.folder_covers.lock() {
        Ok(cache) => cache,
        Err(poisoned) => poisoned.into_inner(),
    };
    if let Some(cached) = cache.get(folder) {
        return cached.clone();
    }
    let found = cover::find_cover_in_folder(folder);
    cache.insert(folder.to_path_buf(), found.clone());
    found
}
