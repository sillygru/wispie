//! Batch work that is not a scan: enrichment, cover sweeps and folder facts.

use crate::cover;
use crate::emitter::{Emit, Emitter};
use crate::formats;
use crate::image_sig::recover_embedded_cover;
use crate::meta;
use crate::model::{CompactRequest, FactsRequest, FolderFact, ListRequest, SongJson, SongsRequest};
use crate::scan;
use crate::CANCEL;
use rayon::prelude::*;
use std::collections::HashMap;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::atomic::Ordering;

const ENRICH_BATCH: usize = 50;
const COVER_BATCH: usize = 10;

/// Same guards the Dart walk uses: past these it is a mistake, not a folder.
const MAX_FILES: usize = 20_000;
const MAX_DEPTH: usize = 12;

fn threads(requested: usize) -> usize {
    if requested > 0 {
        return requested;
    }
    std::thread::available_parallelism()
        .map(|n| n.get())
        .unwrap_or(4)
}

fn safely<T>(body: impl FnOnce() -> Option<T>) -> Option<T> {
    std::panic::catch_unwind(std::panic::AssertUnwindSafe(body))
        .ok()
        .flatten()
}

fn done_event(scanned: u64, cancelled: bool) -> Emit {
    Emit::Done {
        unreadable: 0,
        unreachable: Vec::new(),
        scanned,
        cancelled,
        formats: None,
    }
}

pub fn enrich(request: SongsRequest, emitter: &Emitter) -> Result<(), String> {
    let covers_dir = PathBuf::from(&request.covers_dir);
    let total = request.songs.len() as u64;
    let chunk = (threads(request.concurrency) * 8).max(1);
    let mut batch: Vec<SongJson> = Vec::new();
    let mut processed = 0u64;
    let mut cancelled = false;

    for slice in request.songs.chunks(chunk) {
        if CANCEL.load(Ordering::Relaxed) {
            cancelled = true;
            break;
        }
        let enriched: Vec<Option<SongJson>> = slice
            .par_iter()
            .map(|song| safely(|| enrich_one(song, &covers_dir)))
            .collect();
        batch.extend(enriched.into_iter().flatten());
        processed += slice.len() as u64;
        emitter.emit(Emit::Progress {
            done: processed,
            total,
        });
        if batch.len() >= ENRICH_BATCH {
            emitter.emit(Emit::Songs(std::mem::take(&mut batch)));
        }
    }

    if !batch.is_empty() {
        emitter.emit(Emit::Songs(batch));
    }
    emitter.emit(done_event(processed, cancelled));
    Ok(())
}

/// Tags and, when the row has no art, the cover — from one open of the file.
/// Returns a row only when the read actually changed it.
fn enrich_one(song: &SongJson, covers_dir: &Path) -> Option<SongJson> {
    let path = Path::new(&song.url);
    if !path.exists() || formats::is_video_path(path) {
        return None;
    }

    let needs_cover = song.cover_url.as_deref().map(str::is_empty).unwrap_or(true);
    let placeholder = song.is_placeholder();
    if !placeholder && !needs_cover {
        return None;
    }

    let tags = meta::read_tags(path, needs_cover).ok()?;
    let mut updated = song.clone();
    let mut changed = false;

    // An untagged file keeps its filename title, so only real values replace.
    if placeholder {
        if let Some(value) = tags.title {
            updated.title = value;
            changed = true;
        }
        if let Some(value) = tags.artist {
            updated.artist = value;
            changed = true;
        }
        if let Some(value) = tags.album {
            updated.album = value;
            changed = true;
        }
        if let Some(year) = tags.year.and_then(meta::year_start_epoch_sec) {
            updated.song_date_epoch_sec = Some(year);
            changed = true;
        }
        if tags.has_lyrics {
            updated.has_lyrics = true;
            changed = true;
        }
    }
    if updated.duration.is_none() {
        if let Some(duration) = tags.duration_secs {
            updated.duration = Some(duration);
            changed = true;
        }
    }

    if needs_cover && !covers_dir.as_os_str().is_empty() {
        if let Some(found) = cover_for(path, tags.picture.as_deref(), covers_dir) {
            updated.cover_url = Some(found);
            changed = true;
        }
    }

    if changed {
        Some(updated)
    } else {
        None
    }
}

/// Embedded art, then a folder cover, then the byte scan.
fn cover_for(path: &Path, picture: Option<&[u8]>, covers_dir: &Path) -> Option<String> {
    if let Some(picture) = picture {
        if let Some((offset, kind)) = recover_embedded_cover(picture) {
            if let Ok(saved) =
                cover::save_optimized_cover(&picture[offset..], covers_dir, Some(kind.extension()))
            {
                return Some(saved);
            }
        }
    }
    if let Some(folder) = path.parent() {
        if let Some(found) = cover::find_cover_in_folder(folder) {
            return Some(found);
        }
    }
    cover::manual_extract(path, covers_dir)
}

pub fn extract_covers(request: SongsRequest, emitter: &Emitter) -> Result<(), String> {
    let covers_dir = PathBuf::from(&request.covers_dir);
    let total = request.songs.len() as u64;
    let chunk = (threads(request.concurrency) * 2).max(1);
    let mut batch: Vec<SongJson> = Vec::new();
    let mut processed = 0u64;
    let mut cancelled = false;

    for slice in request.songs.chunks(chunk) {
        if CANCEL.load(Ordering::Relaxed) {
            cancelled = true;
            break;
        }
        let extracted: Vec<Option<SongJson>> = slice
            .par_iter()
            .map(|song| safely(|| extract_one(song, &covers_dir)))
            .collect();
        batch.extend(extracted.into_iter().flatten());
        processed += slice.len() as u64;
        emitter.emit(Emit::Progress {
            done: processed,
            total,
        });
        if batch.len() >= COVER_BATCH {
            emitter.emit(Emit::Songs(std::mem::take(&mut batch)));
        }
    }

    if !batch.is_empty() {
        emitter.emit(Emit::Songs(batch));
    }
    emitter.emit(done_event(processed, cancelled));
    Ok(())
}

fn extract_one(song: &SongJson, covers_dir: &Path) -> Option<SongJson> {
    // A row can carry a cover path whose file was wiped or truncated; those are
    // re-extracted instead of being trusted for another launch.
    if let Some(cover) = song.cover_url.as_deref().filter(|cover| !cover.is_empty()) {
        if cover::is_valid_cover_file(Path::new(cover), false) {
            return None;
        }
    }
    let found = cover::extract_cover_without_ffmpeg(Path::new(&song.url), covers_dir, false)?;
    let mut updated = song.clone();
    updated.cover_url = Some(found);
    Some(updated)
}

/// Whole rows for files that reached the library outside a scan (imports, a
/// file opened from the OS). Same reader the scan uses, so they cannot disagree.
pub fn read_song(request: SongsRequest, emitter: &Emitter) -> Result<(), String> {
    let covers_dir = PathBuf::from(&request.covers_dir);
    let total = request.songs.len() as u64;
    let songs: Vec<SongJson> = request
        .songs
        .par_iter()
        .map(|song| safely(|| scan::hydrate(song, &covers_dir)).unwrap_or_else(|| song.clone()))
        .collect();
    emitter.emit(Emit::Songs(songs));
    emitter.emit(done_event(total, false));
    Ok(())
}

pub fn rebuild_covers(request: SongsRequest, emitter: &Emitter) -> Result<(), String> {
    let covers_dir = PathBuf::from(&request.covers_dir);
    let force = request.force;
    let total = request.songs.len() as u64;
    let chunk = (threads(request.concurrency) * 2).max(1);
    let mut covers: HashMap<String, String> = HashMap::new();
    let mut processed = 0u64;

    for slice in request.songs.chunks(chunk) {
        if CANCEL.load(Ordering::Relaxed) {
            break;
        }
        let resolved: Vec<(String, String)> = slice
            .par_iter()
            .filter_map(|song| safely(|| resolve_cover(song, &covers_dir, force)))
            .collect();
        covers.extend(resolved);
        processed += slice.len() as u64;
        emitter.emit(Emit::Progress {
            done: processed,
            total,
        });
    }

    // Only real resolutions are reported; silence means "could not tell".
    emitter.emit(Emit::Covers(covers));
    emitter.emit(done_event(processed, false));
    Ok(())
}

fn resolve_cover(song: &SongJson, covers_dir: &Path, force: bool) -> Option<(String, String)> {
    let path = Path::new(&song.url);
    if formats::is_video_path(path) || !path.exists() {
        return None;
    }

    let cached = if force {
        None
    } else {
        // The row's own cover is the cheapest truth: it may be content-addressed
        // or a folder cover, neither of which a filename hash could find.
        song.cover_url
            .as_deref()
            .map(Path::new)
            .filter(|cover| cover::is_valid_cover_file(cover, false))
            .map(|cover| cover.to_string_lossy().to_string())
            .or_else(|| cover::find_cached_cover(covers_dir, &song.filename, false))
    };
    let resolved =
        cached.or_else(|| cover::extract_cover_without_ffmpeg(path, covers_dir, false))?;
    Some((song.url.clone(), resolved))
}

pub fn read_facts(request: FactsRequest, emitter: &Emitter) -> Result<(), String> {
    let total = request.paths.len() as u64;
    let chunk = (threads(request.concurrency) * 8).max(1);
    let mut processed = 0u64;
    let mut cancelled = false;

    for slice in request.paths.chunks(chunk) {
        if CANCEL.load(Ordering::Relaxed) {
            cancelled = true;
            break;
        }
        let facts: Vec<FolderFact> = slice
            .par_iter()
            .map(|path| safely(|| Some(read_fact(path))))
            .flatten()
            .collect();
        emitter.emit(Emit::Facts(facts));
        processed += slice.len() as u64;
        emitter.emit(Emit::Progress {
            done: processed,
            total,
        });
    }

    emitter.emit(done_event(processed, cancelled));
    Ok(())
}

pub fn list_media(request: ListRequest, emitter: &Emitter) -> Result<(), String> {
    let files = walk_media(Path::new(&request.root), request.recursive);
    let scanned = files.len() as u64;
    emitter.emit(Emit::Paths(files));
    emitter.emit(done_event(scanned, false));
    Ok(())
}

/// Every media file under `root`, sorted, without following links.
fn walk_media(root: &Path, recursive: bool) -> Vec<String> {
    if !root.exists() {
        return Vec::new();
    }

    let mut files: Vec<String> = Vec::new();
    let mut pending: Vec<(PathBuf, usize)> = vec![(root.to_path_buf(), 0)];

    while let Some((dir, depth)) = pending.pop() {
        if files.len() >= MAX_FILES {
            break;
        }
        let Ok(entries) = fs::read_dir(&dir) else {
            continue;
        };
        for entry in entries.flatten() {
            let path = entry.path();
            let Ok(kind) = entry.file_type() else {
                continue;
            };
            if kind.is_file() {
                if formats::is_supported_path(&path) {
                    files.push(path.to_string_lossy().to_string());
                    if files.len() >= MAX_FILES {
                        break;
                    }
                }
            } else if recursive && kind.is_dir() && depth < MAX_DEPTH {
                let hidden = path
                    .file_name()
                    .and_then(|name| name.to_str())
                    .map(|name| name.starts_with('.'))
                    .unwrap_or(false);
                if !hidden {
                    pending.push((path, depth + 1));
                }
            }
        }
    }

    files.sort();
    files
}

/// Rewrites legacy cover files to their content-addressed names.
/// Only real rewrites come back, so the caller touches the rows that change.
pub fn compact_covers(request: CompactRequest, emitter: &Emitter) -> Result<(), String> {
    let covers_dir = PathBuf::from(&request.covers_dir);
    if !covers_dir.as_os_str().is_empty() && !covers_dir.exists() {
        fs::create_dir_all(&covers_dir)
            .map_err(|e| format!("cannot create covers directory: {e}"))?;
    }

    let total = request.paths.len() as u64;
    let chunk = (threads(request.concurrency) * 4).max(1);
    let mut compacted: HashMap<String, String> = HashMap::new();
    let mut processed = 0u64;
    let mut cancelled = false;

    for slice in request.paths.chunks(chunk) {
        if CANCEL.load(Ordering::Relaxed) {
            cancelled = true;
            break;
        }
        let rewritten: Vec<(String, String)> = slice
            .par_iter()
            .filter_map(|old| safely(|| compact_one(old, &covers_dir)))
            .collect();
        compacted.extend(rewritten);
        processed += slice.len() as u64;
        emitter.emit(Emit::Progress {
            done: processed,
            total,
        });
    }

    emitter.emit(Emit::Compacted(compacted));
    emitter.emit(done_event(processed, cancelled));
    Ok(())
}

fn compact_one(old: &str, covers_dir: &Path) -> Option<(String, String)> {
    let path = Path::new(old);
    let already_keyed = path
        .file_name()
        .and_then(|name| name.to_str())
        .map(|name| name.starts_with("c_"))
        .unwrap_or(false);
    if already_keyed {
        return None;
    }

    let bytes = fs::read(path).ok()?;
    if bytes.is_empty() {
        return None;
    }

    let saved = cover::save_optimized_cover(&bytes, covers_dir, None).ok()?;
    if saved == old {
        None
    } else {
        Some((old.to_string(), saved))
    }
}

/// An unreadable file reports nothing about itself rather than failing.
fn read_fact(path: &str) -> FolderFact {
    let mut fact = FolderFact {
        path: path.to_string(),
        title: None,
        artist: None,
        album: None,
        duration: None,
    };

    if let Ok(tags) = meta::read_tags(Path::new(path), false) {
        fact.title = tags.title;
        fact.artist = tags.artist;
        fact.album = tags.album;
        fact.duration = tags.duration_secs;
    }
    fact
}
