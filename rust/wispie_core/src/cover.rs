//! Cover cache: content-addressed dedupe, optimisation and byte-level recovery.
//! Writes are atomic and keyed by hash, so concurrent writers cannot disagree.

use crate::formats;
use crate::image_sig::{has_image_signature, recover_embedded_cover, SIGNATURE_PROBE_LEN};
use crate::meta;
use image::codecs::jpeg::JpegEncoder;
use image::imageops::FilterType;
use image::{DynamicImage, ExtendedColorType};
use sha1::{Digest, Sha1};
use std::fs::{self, File};
use std::io::{Read, Seek, SeekFrom};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};

pub const MAX_COVER_DIMENSION: u32 = 1024;
pub const JPEG_QUALITY: u8 = 88;
pub const FAST_PATH_BYTE_LIMIT: u64 = 250 * 1024;

pub const COVER_EXTENSION_CANDIDATES: &[&str] =
    &[".jpg", ".jpeg", ".png", ".webp", ".bmp", "_ffmpeg.jpg"];

const FOLDER_COVER_NAMES: &[&str] = &[
    "cover.jpg",
    "cover.png",
    "folder.jpg",
    "folder.png",
    "album.jpg",
    "album.png",
];

const SCAN_WHOLE_FILE_LIMIT: u64 = 50 * 1024 * 1024;
const FIRST_SCAN_LIMIT: u64 = 15 * 1024 * 1024;
const FOOTER_SCAN_LIMIT: u64 = 10 * 1024 * 1024;
const MAX_IMAGE_BYTES: u64 = 15 * 1024 * 1024;

static TEMP_SEQ: AtomicU64 = AtomicU64::new(0);

pub fn cover_key_for_filename(filename: &str) -> String {
    let base = Path::new(filename)
        .file_name()
        .and_then(|s| s.to_str())
        .unwrap_or(filename);
    let mut hasher = Sha1::new();
    hasher.update(base.as_bytes());
    hex(&hasher.finalize())
}

fn hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push_str(&format!("{:02x}", byte));
    }
    out
}

/// Every path a cached cover for `filename` could occupy, in preference order.
/// `_ffmpeg.jpg` is where the FFmpeg fallback writes; omitting it loses real art.
pub fn cover_candidate_paths(covers_dir: &Path, filename: &str) -> Vec<PathBuf> {
    let key = cover_key_for_filename(filename);
    COVER_EXTENSION_CANDIDATES
        .iter()
        .map(|ext| covers_dir.join(format!("{key}{ext}")))
        .collect()
}

/// Whether `path` holds a cache-worthy cover.
/// The signature check is the cheap half and catches pre-recovery covers.
pub fn is_valid_cover_file(path: &Path, require_decodable: bool) -> bool {
    let metadata = match fs::metadata(path) {
        Ok(m) => m,
        Err(_) => return false,
    };
    if metadata.len() == 0 {
        return false;
    }

    let mut head = [0u8; SIGNATURE_PROBE_LEN];
    let read = match File::open(path).and_then(|mut f| f.read(&mut head)) {
        Ok(n) => n,
        Err(_) => return false,
    };
    if !has_image_signature(&head[..read]) {
        return false;
    }
    if !require_decodable {
        return true;
    }

    match fs::read(path) {
        Ok(bytes) => image::load_from_memory(&bytes)
            .map(|decoded| decoded.width() > 0 && decoded.height() > 0)
            .unwrap_or(false),
        Err(_) => false,
    }
}

pub fn find_cached_cover(
    covers_dir: &Path,
    filename: &str,
    require_decodable: bool,
) -> Option<String> {
    cover_candidate_paths(covers_dir, filename)
        .into_iter()
        .find(|path| is_valid_cover_file(path, require_decodable))
        .map(|path| path.to_string_lossy().to_string())
}

pub fn find_cover_in_folder(folder: &Path) -> Option<String> {
    FOLDER_COVER_NAMES
        .iter()
        .map(|name| folder.join(name))
        .find(|candidate| candidate.exists())
        .map(|path| path.to_string_lossy().to_string())
}

fn compute_content_key(bytes: &[u8]) -> String {
    let mut hasher = Sha1::new();
    hasher.update(bytes);
    format!("c_{}", hex(&hasher.finalize()))
}

fn find_existing_cover(covers_dir: &Path, content_key: &str) -> Option<String> {
    for ext in [".jpg", ".webp", ".png", ".jpeg"] {
        let path = covers_dir.join(format!("{content_key}{ext}"));
        if let Ok(metadata) = fs::metadata(&path) {
            if metadata.len() > 0 {
                return Some(path.to_string_lossy().to_string());
            }
        }
    }
    None
}

fn sniff_extension(raw: &[u8]) -> Option<&'static str> {
    if raw.len() < 4 || !has_image_signature(raw) {
        return None;
    }
    recover_embedded_cover(raw).map(|(_, kind)| kind.extension())
}

/// Optimises and writes `raw`, reusing an identical cached image.
pub fn save_optimized_cover(
    raw: &[u8],
    covers_dir: &Path,
    fallback_extension: Option<&str>,
) -> Result<String, String> {
    if raw.is_empty() {
        return Err("empty cover payload".to_string());
    }

    let key = compute_content_key(raw);
    if let Some(existing) = find_existing_cover(covers_dir, &key) {
        return Ok(existing);
    }

    let ext = fallback_extension
        .map(|e| e.to_string())
        .or_else(|| sniff_extension(raw).map(|e| e.to_string()))
        .unwrap_or_else(|| ".jpg".to_string());

    let Ok(decoded) = image::load_from_memory(raw) else {
        // Undecodable payloads are still cached: the file may be a format the
        // decoder lacks, and dropping it would lose the only copy.
        return Ok(write_raw(&covers_dir.join(format!("{key}{ext}")), raw));
    };

    let oversized = decoded.width() > MAX_COVER_DIMENSION || decoded.height() > MAX_COVER_DIMENSION;

    if !oversized && raw.len() as u64 <= FAST_PATH_BYTE_LIMIT && (ext == ".jpg" || ext == ".webp") {
        return Ok(write_atomic(&covers_dir.join(format!("{key}{ext}")), raw));
    }

    let to_encode = if oversized {
        shrink_to_fit(&decoded)
    } else {
        decoded
    };

    let encoded = encode_jpeg(&to_encode)?;
    Ok(write_atomic(
        &covers_dir.join(format!("{key}.jpg")),
        &encoded,
    ))
}

fn shrink_to_fit(decoded: &DynamicImage) -> DynamicImage {
    let (width, height) = (decoded.width(), decoded.height());
    let is_wider = width >= height;
    let target_width = if is_wider {
        MAX_COVER_DIMENSION
    } else {
        ((width as f64 * MAX_COVER_DIMENSION as f64 / height as f64).round()) as u32
    };
    let target_height = if is_wider {
        ((height as f64 * MAX_COVER_DIMENSION as f64 / width as f64).round()) as u32
    } else {
        MAX_COVER_DIMENSION
    };

    let rgb = decoded.to_rgb8();
    let resized = image::imageops::resize(
        &rgb,
        target_width.max(1),
        target_height.max(1),
        FilterType::CatmullRom,
    );
    DynamicImage::ImageRgb8(resized)
}

fn encode_jpeg(image: &DynamicImage) -> Result<Vec<u8>, String> {
    let rgb = image.to_rgb8();
    let mut buffer = Vec::new();
    let mut encoder = JpegEncoder::new_with_quality(&mut buffer, JPEG_QUALITY);
    encoder
        .encode(
            rgb.as_raw(),
            rgb.width(),
            rgb.height(),
            ExtendedColorType::Rgb8,
        )
        .map_err(|e| e.to_string())?;
    Ok(buffer)
}

fn write_raw(target: &Path, bytes: &[u8]) -> String {
    if let Err(e) = fs::write(target, bytes) {
        log_note(&format!("cover write failed {}: {e}", target.display()));
    }
    target.to_string_lossy().to_string()
}

fn write_atomic(target: &Path, bytes: &[u8]) -> String {
    let parent = target.parent().unwrap_or_else(|| Path::new("."));
    let stem = target
        .file_stem()
        .and_then(|s| s.to_str())
        .unwrap_or("cover");
    let temp = parent.join(format!(
        "{stem}.tmp_{}_{}",
        std::process::id(),
        TEMP_SEQ.fetch_add(1, Ordering::Relaxed)
    ));

    if let Err(e) = fs::write(&temp, bytes) {
        log_note(&format!("cover temp write failed {}: {e}", temp.display()));
        return target.to_string_lossy().to_string();
    }

    match fs::rename(&temp, target) {
        Ok(()) => target.to_string_lossy().to_string(),
        Err(_) => {
            if target.exists() {
                let _ = fs::remove_file(&temp);
                target.to_string_lossy().to_string()
            } else {
                temp.to_string_lossy().to_string()
            }
        }
    }
}

/// Embedded picture, folder cover, then the manual byte scan.
/// `None` means only the FFmpeg fallback could still succeed.
pub fn extract_cover_without_ffmpeg(
    file_path: &Path,
    covers_dir: &Path,
    skip_folder_cover: bool,
) -> Option<String> {
    if formats::is_video_path(file_path) || !file_path.exists() {
        return None;
    }

    if let Ok(tags) = meta::read_tags(file_path, true) {
        if let Some(picture) = tags.picture {
            if let Some((offset, kind)) = recover_embedded_cover(&picture) {
                if let Ok(path) =
                    save_optimized_cover(&picture[offset..], covers_dir, Some(kind.extension()))
                {
                    return Some(path);
                }
            }
        }
    }

    // A handful of `exists` calls is far cheaper than reading the whole file.
    if !skip_folder_cover {
        if let Some(folder) = file_path.parent() {
            if let Some(cover) = find_cover_in_folder(folder) {
                return Some(cover);
            }
        }
    }

    manual_extract(file_path, covers_dir)
}

fn read_at(file: &mut File, position: u64, length: usize) -> Option<Vec<u8>> {
    file.seek(SeekFrom::Start(position)).ok()?;
    let mut buffer = vec![0u8; length];
    let mut filled = 0;
    while filled < length {
        match file.read(&mut buffer[filled..]) {
            Ok(0) => break,
            Ok(n) => filled += n,
            Err(_) => return None,
        }
    }
    buffer.truncate(filled);
    Some(buffer)
}

/// Byte-level recovery for files whose tag parser gave up.
/// Scans the head (or whole small file) for APIC, `covr` or a bare signature.
pub fn manual_extract(file_path: &Path, covers_dir: &Path) -> Option<String> {
    let mut file = File::open(file_path).ok()?;
    let length = file.metadata().ok()?.len();
    if length == 0 {
        return None;
    }

    let scan_everything = length < SCAN_WHOLE_FILE_LIMIT;
    let first_length = if scan_everything {
        length
    } else {
        FIRST_SCAN_LIMIT
    } as usize;
    let head = read_at(&mut file, 0, first_length)?;

    if formats::extension(file_path).as_deref() == Some(".m4a") {
        if let Some(found) = scan_for_covr(&head, &mut file, 0, covers_dir) {
            return Some(found);
        }
    }

    if let Some(found) = scan_for_apic(&head, &mut file, 0, covers_dir) {
        return Some(found);
    }

    if let Some(found) = scan_buffer_for_signatures(&head, &mut file, 0, covers_dir) {
        return Some(found);
    }

    if !scan_everything && length > first_length as u64 {
        let footer_length = FOOTER_SCAN_LIMIT.min(length - first_length as u64) as usize;
        let footer_start = length - footer_length as u64;
        let footer = read_at(&mut file, footer_start, footer_length)?;
        if let Some(found) =
            scan_buffer_for_signatures(&footer, &mut file, footer_start, covers_dir)
        {
            return Some(found);
        }
    }

    None
}

fn scan_for_apic(
    bytes: &[u8],
    file: &mut File,
    base_offset: u64,
    covers_dir: &Path,
) -> Option<String> {
    if bytes.len() < 20 {
        return None;
    }
    for i in 0..=bytes.len() - 20 {
        if &bytes[i..i + 4] != b"APIC" {
            continue;
        }
        let tag_size = ((bytes[i + 4] as u32) << 21)
            | ((bytes[i + 5] as u32) << 14)
            | ((bytes[i + 6] as u32) << 7)
            | (bytes[i + 7] as u32);
        if tag_size as u64 > 5000 && (tag_size as u64) < MAX_IMAGE_BYTES {
            let end = (i as u64 + tag_size as u64 + 20).min(bytes.len() as u64) as usize;
            let sub_chunk = &bytes[i..end];
            if let Some(found) =
                scan_buffer_for_signatures(sub_chunk, file, base_offset + i as u64, covers_dir)
            {
                return Some(found);
            }
        }
    }
    None
}

fn scan_for_covr(
    bytes: &[u8],
    file: &mut File,
    base_offset: u64,
    covers_dir: &Path,
) -> Option<String> {
    if bytes.len() < 24 {
        return None;
    }
    for i in 0..=bytes.len() - 24 {
        if &bytes[i..i + 4] != b"covr" {
            continue;
        }
        let inner_end = (i + 128).min(bytes.len().saturating_sub(16));
        for j in (i + 4)..inner_end {
            if &bytes[j..j + 4] != b"data" {
                continue;
            }
            let data_size = ((bytes[j - 4] as u32) << 24)
                | ((bytes[j - 3] as u32) << 16)
                | ((bytes[j - 2] as u32) << 8)
                | (bytes[j - 1] as u32);
            let image_size = data_size as i64 - 16;
            if image_size > 1024 && (image_size as u64) < MAX_IMAGE_BYTES {
                let start = base_offset + j as u64 + 12;
                let image = read_at(file, start, image_size as usize)?;
                let extension = match bytes[j + 11] {
                    14 => ".png",
                    27 => ".bmp",
                    _ => ".jpg",
                };
                return save_optimized_cover(&image, covers_dir, Some(extension)).ok();
            }
        }
    }
    None
}

fn scan_buffer_for_signatures(
    bytes: &[u8],
    file: &mut File,
    base_offset: u64,
    covers_dir: &Path,
) -> Option<String> {
    if bytes.len() < 8 {
        return None;
    }
    for i in 0..=bytes.len() - 8 {
        let extension = if bytes[i] == 0xFF && bytes[i + 1] == 0xD8 {
            Some(".jpg")
        } else if bytes[i] == 0x89
            && bytes[i + 1] == 0x50
            && bytes[i + 2] == 0x4E
            && bytes[i + 3] == 0x47
        {
            Some(".png")
        } else if bytes[i] == 0x52
            && bytes[i + 1] == 0x49
            && bytes[i + 2] == 0x46
            && bytes[i + 3] == 0x46
            && bytes[i + 8] == 0x57
            && bytes[i + 9] == 0x45
            && bytes[i + 10] == 0x42
            && bytes[i + 11] == 0x50
        {
            Some(".webp")
        } else {
            None
        };

        if let Some(extension) = extension {
            if let Some(found) =
                extract_image_at(file, base_offset + i as u64, extension, covers_dir)
            {
                return Some(found);
            }
        }
    }
    None
}

fn extract_image_at(
    file: &mut File,
    position: u64,
    extension: &str,
    covers_dir: &Path,
) -> Option<String> {
    let data = read_at(file, position, MAX_IMAGE_BYTES as usize)?;
    let mut actual_end = data.len();

    if extension == ".jpg" {
        let mut last_eoi = None;
        for k in 0..data.len().saturating_sub(1) {
            if data[k] == 0xFF && data[k + 1] == 0xD9 {
                last_eoi = Some(k + 2);
                if k + 4 < data.len() && (data[k + 2] != 0xFF || data[k + 3] == 0x00) {
                    actual_end = k + 2;
                    break;
                }
            }
        }
        if let Some(eoi) = last_eoi {
            if actual_end == data.len() {
                actual_end = eoi;
            }
        }
        if actual_end == data.len() && data.len() < 50 * 1024 {
            return None;
        }
    } else if extension == ".png" {
        const PNG_END: [u8; 8] = [0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82];
        if let Some(index) = data.windows(PNG_END.len()).position(|w| w == PNG_END) {
            actual_end = index + PNG_END.len();
        }
    }

    if actual_end > 1024 && actual_end <= data.len() {
        return save_optimized_cover(&data[..actual_end], covers_dir, Some(extension)).ok();
    }
    None
}

fn log_note(message: &str) {
    #[cfg(debug_assertions)]
    eprintln!("wispie_core: {message}");
    #[cfg(not(debug_assertions))]
    let _ = message;
}
