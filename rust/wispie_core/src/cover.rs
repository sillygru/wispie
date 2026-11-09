//! Cover cache: content-addressed dedupe, optimisation and byte-level recovery.
//! Writes are atomic and keyed by hash, so concurrent writers cannot disagree.

use crate::formats;
use crate::image_sig::{
    has_complete_image, recover_embedded_cover, ImageKind, SIGNATURE_PROBE_LEN, TAIL_PROBE_LEN,
};
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

/// Below this a "cover" is a decoding accident, not artwork.
const MIN_COVER_DIMENSION: u32 = 24;

/// How many image candidates one file may offer before the byte scan gives up.
/// Compressed audio is full of byte pairs that look like a JPEG start.
const MAX_IMAGE_CANDIDATES: usize = 8;

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
///
/// The cheap half reads the first and last bytes: a cover that starts with a
/// signature but has no end marker is a truncated grab (a green smear on
/// screen), and one that starts mid-frame is the tail of a picture frame.
pub fn is_valid_cover_file(path: &Path, require_decodable: bool) -> bool {
    let metadata = match fs::metadata(path) {
        Ok(m) => m,
        Err(_) => return false,
    };
    let length = metadata.len();
    if length == 0 {
        return false;
    }

    let mut file = match File::open(path) {
        Ok(file) => file,
        Err(_) => return false,
    };
    let mut head = [0u8; SIGNATURE_PROBE_LEN];
    let read = match file.read(&mut head) {
        Ok(n) => n,
        Err(_) => return false,
    };
    let tail_length = (length.min(TAIL_PROBE_LEN as u64)) as usize;
    let tail = match read_at(&mut file, length - tail_length as u64, tail_length) {
        Some(tail) => tail,
        None => return false,
    };
    if !has_complete_image(&head[..read], &tail, length) {
        return false;
    }
    if !require_decodable {
        return true;
    }

    match fs::read(path) {
        Ok(bytes) => image::load_from_memory(&bytes)
            .map(|decoded| decoded.width() >= MIN_COVER_DIMENSION)
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

fn detected_extension(raw: &[u8]) -> Option<&'static str> {
    use image::ImageFormat;
    match image::guess_format(raw).ok()? {
        ImageFormat::Jpeg => Some(".jpg"),
        ImageFormat::Png => Some(".png"),
        ImageFormat::WebP => Some(".webp"),
        ImageFormat::Bmp => Some(".bmp"),
        ImageFormat::Gif => Some(".gif"),
        _ => None,
    }
}

fn normalize_extension(extension: &str) -> &'static str {
    match extension.to_ascii_lowercase().as_str() {
        ".jpg" | ".jpeg" => ".jpg",
        ".png" => ".png",
        ".webp" => ".webp",
        ".bmp" => ".bmp",
        ".gif" => ".gif",
        _ => ".jpg",
    }
}

/// Optimises and writes `raw`, reusing an identical cached image.
///
/// Undecodable payloads are rejected rather than stored: a false image
/// signature inside compressed audio must never become a cached cover, because
/// every later pass would then trust it as real art.
pub fn save_optimized_cover(
    raw: &[u8],
    covers_dir: &Path,
    fallback_extension: Option<&str>,
) -> Result<String, String> {
    if raw.is_empty() {
        return Err("empty cover payload".to_string());
    }

    let decoded = image::load_from_memory(raw)
        .map_err(|error| format!("cover payload does not decode: {error}"))?;
    if decoded.width() < MIN_COVER_DIMENSION || decoded.height() < MIN_COVER_DIMENSION {
        return Err(format!(
            "cover payload too small: {}x{}",
            decoded.width(),
            decoded.height()
        ));
    }

    let key = compute_content_key(raw);
    if let Some(existing) = find_existing_cover(covers_dir, &key) {
        return Ok(existing);
    }

    let ext = detected_extension(raw)
        .or_else(|| fallback_extension.map(normalize_extension))
        .unwrap_or(".jpg");

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
///
/// Every candidate is located and bounded in memory: scanning compressed audio
/// for a bare signature finds plenty of false starts, and re-reading the file
/// from each one turns one artless song into gigabytes of I/O.
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
    if let Some(found) = scan_for_image(&head, 0, &mut file, covers_dir) {
        return Some(found);
    }

    if !scan_everything && length > first_length as u64 {
        let footer_length = FOOTER_SCAN_LIMIT.min(length - first_length as u64) as usize;
        let footer_start = length - footer_length as u64;
        let footer = read_at(&mut file, footer_start, footer_length)?;
        if let Some(found) = scan_for_image(&footer, footer_start, &mut file, covers_dir) {
            return Some(found);
        }
    }

    None
}

fn scan_for_image(
    bytes: &[u8],
    base_offset: u64,
    file: &mut File,
    covers_dir: &Path,
) -> Option<String> {
    let mut from = 0usize;
    let mut tried = 0usize;
    while tried < MAX_IMAGE_CANDIDATES {
        let (start, kind) = find_candidate(bytes, from)?;
        tried += 1;

        let Some((end, extension)) = image_end(bytes, start, kind) else {
            from = start + 2;
            continue;
        };
        if end - start > MAX_IMAGE_BYTES as usize {
            from = start + 2;
            continue;
        }

        let owned;
        let payload: &[u8] = if end <= bytes.len() {
            &bytes[start..end]
        } else {
            // The image runs past this buffer; read exactly it, not a window.
            owned = read_at(file, base_offset + start as u64, end - start)?;
            &owned
        };

        if let Ok(saved) = save_optimized_cover(payload, covers_dir, Some(extension)) {
            return Some(saved);
        }
        from = end.min(bytes.len());
    }
    None
}

/// The next offset whose bytes begin a real image container.
fn find_candidate(bytes: &[u8], from: usize) -> Option<(usize, ImageKind)> {
    let mut index = from;
    while index + 12 <= bytes.len() {
        if bytes[index] == 0xFF && bytes[index + 1] == 0xD8 && bytes[index + 2] == 0xFF {
            // A real JPEG start is followed by an APP/DQT/SOF marker rather
            // than by the next byte of an audio frame.
            let marker = bytes[index + 3];
            if (0xC0..=0xFE).contains(&marker) && marker != 0xD8 {
                return Some((index, ImageKind::Jpeg));
            }
        }
        if &bytes[index..index + 8] == b"\x89PNG\r\n\x1a\n" {
            return Some((index, ImageKind::Png));
        }
        if &bytes[index..index + 4] == b"RIFF" && &bytes[index + 8..index + 12] == b"WEBP" {
            return Some((index, ImageKind::Webp));
        }
        index += 1;
    }
    None
}

fn image_end(bytes: &[u8], start: usize, kind: ImageKind) -> Option<(usize, &'static str)> {
    match kind {
        ImageKind::Jpeg => jpeg_end(bytes, start).map(|end| (end, ".jpg")),
        ImageKind::Png => png_end(bytes, start).map(|end| (end, ".png")),
        ImageKind::Webp => webp_end(bytes, start).map(|end| (end, ".webp")),
        _ => None,
    }
}

/// Walks JPEG segments up to the end marker, so the payload ends exactly where
/// the image does. Inside the scan data `FF D9` can only be a real marker:
/// literal `FF` bytes are stuffed as `FF 00`.
fn jpeg_end(bytes: &[u8], start: usize) -> Option<usize> {
    let mut position = start + 2;
    while position + 1 < bytes.len() {
        if bytes[position] != 0xFF {
            return None;
        }
        let marker = bytes[position + 1];
        if marker == 0xD9 {
            return Some(position + 2);
        }
        if marker == 0xDA {
            return bytes[position + 2..]
                .windows(2)
                .position(|window| window == [0xFF, 0xD9])
                .map(|offset| position + 4 + offset);
        }
        if marker == 0x01 || (0xD0..=0xD7).contains(&marker) {
            position += 2;
            continue;
        }
        if position + 4 > bytes.len() {
            return None;
        }
        let length = u16::from_be_bytes([bytes[position + 2], bytes[position + 3]]) as usize;
        if length < 2 {
            return None;
        }
        position += 2 + length;
    }
    None
}

fn png_end(bytes: &[u8], start: usize) -> Option<usize> {
    let mut position = start + 8;
    loop {
        if position + 8 > bytes.len() {
            return None;
        }
        let length = u32::from_be_bytes([
            bytes[position],
            bytes[position + 1],
            bytes[position + 2],
            bytes[position + 3],
        ]) as usize;
        let kind = &bytes[position + 4..position + 8];
        let next = position + 12 + length;
        if kind == b"IEND" {
            return Some(next);
        }
        if next <= position || next > bytes.len() {
            return None;
        }
        position = next;
    }
}

fn webp_end(bytes: &[u8], start: usize) -> Option<usize> {
    if start + 12 > bytes.len() {
        return None;
    }
    let size = u32::from_le_bytes([
        bytes[start + 4],
        bytes[start + 5],
        bytes[start + 6],
        bytes[start + 7],
    ]) as usize;
    if size == 0 {
        return None;
    }
    Some(start + 8 + size)
}

fn log_note(message: &str) {
    #[cfg(debug_assertions)]
    eprintln!("wispie_core: {message}");
    #[cfg(not(debug_assertions))]
    let _ = message;
}
