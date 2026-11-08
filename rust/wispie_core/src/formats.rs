//! Playable media, mirroring `media_formats.dart` and `Song.videoExtensions`.
//! A probe asserts both sides agree, so drift fails a check.

use std::path::Path;

pub const SUPPORTED: &[&str] = &[
    ".mp3", ".m4a", ".wav", ".flac", ".ogg", ".wma", ".aac", ".m4b", ".mp4", ".opus", ".m4v",
    ".mov", ".mkv", ".webm", ".avi", ".3gp",
];

pub const VIDEO: &[&str] = &[
    ".mp4", ".m4v", ".mov", ".mkv", ".webm", ".avi", ".3gp", ".av1",
];

/// Lowercased extension with its dot, matching `package:path`'s `p.extension`.
pub fn extension(path: &Path) -> Option<String> {
    let ext = path.extension()?.to_str()?;
    if ext.is_empty() {
        return None;
    }
    Some(format!(".{}", ext.to_ascii_lowercase()))
}

pub fn is_supported_path(path: &Path) -> bool {
    match extension(path) {
        Some(ext) => SUPPORTED.contains(&ext.as_str()),
        None => false,
    }
}

pub fn is_video_path(path: &Path) -> bool {
    match extension(path) {
        Some(ext) => VIDEO.contains(&ext.as_str()),
        None => false,
    }
}
