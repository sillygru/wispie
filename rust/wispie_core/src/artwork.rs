//! Cover-art paths and cache: URL renditions, the tag-frame payload sniff, and
//! the content-addressed optimizer.

use crate::emitter::Emit;
use image::codecs::jpeg::JpegEncoder;
use image::imageops::FilterType;
use image::{ExtendedColorType, ImageEncoder};
use serde_json::json;
use sha1::{Digest, Sha1};
use std::path::{Path, PathBuf};
use std::sync::OnceLock;
use std::time::{SystemTime, UNIX_EPOCH};

const MAX_COVER_DIMENSION: u32 = 1024;
const JPEG_QUALITY: u8 = 88;
const FAST_PATH_BYTES: usize = 250 * 1024;
const MAX_LEADING_JUNK: usize = 512;
const COVER_EXTENSIONS: [&str; 4] = [".jpg", ".webp", ".png", ".jpeg"];

fn still_pattern() -> &'static regex::Regex {
    static STILL: OnceLock<regex::Regex> = OnceLock::new();
    STILL.get_or_init(|| {
        regex::Regex::new(
            r"^https?://i\.ytimg\.com/vi/([A-Za-z0-9_-]+)/(mq|hq|sd|maxres)default(\.\w+)(\?.*)?$",
        )
        .unwrap()
    })
}

fn boxed_pattern() -> &'static regex::Regex {
    static BOXED: OnceLock<regex::Regex> = OnceLock::new();
    BOXED.get_or_init(|| regex::Regex::new(r"=w(\d+)-h(\d+)").unwrap())
}

fn square_pattern() -> &'static regex::Regex {
    static SQUARE: OnceLock<regex::Regex> = OnceLock::new();
    SQUARE.get_or_init(|| regex::Regex::new(r"=s(\d+)").unwrap())
}

/// The `=s120` suffix, only where the size ends at `-` or the end of the URL.
fn sized_square(url: &str) -> Option<(usize, usize, i64)> {
    let caps = square_pattern().captures(url)?;
    let found = caps.get(0)?;
    if found.end() < url.len() && !url[found.end()..].starts_with('-') {
        return None;
    }
    Some((
        found.start(),
        found.end(),
        caps[1].parse::<i64>().unwrap_or(0),
    ))
}

const STILL_LADDER: [&str; 4] = ["mq", "hq", "sd", "maxres"];

fn target_rung(wanted: i64) -> usize {
    if wanted <= 320 {
        0
    } else if wanted <= 480 {
        1
    } else if wanted <= 640 {
        2
    } else {
        3
    }
}

fn rebuild_still(caps: &regex::Captures, target: usize) -> String {
    let suffix = caps.get(4).map(|value| value.as_str()).unwrap_or("");
    format!(
        "https://i.ytimg.com/vi/{}/{}default{}{}",
        &caps[1], STILL_LADDER[target], &caps[3], suffix
    )
}

/// A sharper rendition of a remote thumbnail, or None when it is already big
/// enough or carries no size.
pub fn sharper_url(url: &str, wanted: i64) -> Option<String> {
    if let Some(caps) = still_pattern().captures(url) {
        let current = STILL_LADDER
            .iter()
            .position(|name| *name == &caps[2])
            .unwrap_or(0);
        let target = target_rung(wanted);
        if target <= current {
            return None;
        }
        return Some(rebuild_still(&caps, target));
    }

    let target = wanted.clamp(120, 720);
    if let Some(found) = boxed_pattern().find(url) {
        let caps = boxed_pattern().captures(url)?;
        let width = caps[1].parse::<i64>().unwrap_or(0);
        if width >= target {
            return None;
        }
        let mut result = String::with_capacity(url.len() + 8);
        result.push_str(&url[..found.start()]);
        result.push_str(&format!("=w{target}-h{target}"));
        result.push_str(&url[found.end()..]);
        return Some(result);
    }

    if let Some((start, end, size)) = sized_square(url) {
        if size >= target {
            return None;
        }
        let mut result = String::with_capacity(url.len());
        result.push_str(&url[..start]);
        result.push_str(&format!("=s{target}"));
        result.push_str(&url[end..]);
        return Some(result);
    }
    None
}

/// The rendition closest to `wanted`, moving down as well as up.
pub fn rendition_url(url: &str, wanted: i64) -> Option<String> {
    let Some(caps) = still_pattern().captures(url) else {
        return sharper_url(url, wanted);
    };
    let target = target_rung(wanted);
    let current = STILL_LADDER
        .iter()
        .position(|name| *name == &caps[2])
        .unwrap_or(0);
    if current == target {
        return None;
    }
    Some(rebuild_still(&caps, target))
}

pub fn is_local(value: &str) -> bool {
    let trimmed = value.trim();
    trimmed.starts_with('/')
        || trimmed.starts_with("C:\\")
        || trimmed.starts_with("file://")
        || trimmed.starts_with("content://")
}

fn percent_decode(value: &str) -> Option<String> {
    let bytes = value.as_bytes();
    let mut out: Vec<u8> = Vec::with_capacity(bytes.len());
    let mut index = 0usize;
    while index < bytes.len() {
        if bytes[index] == b'%' {
            if index + 2 >= bytes.len() {
                return None;
            }
            let hex = std::str::from_utf8(&bytes[index + 1..index + 3]).ok()?;
            let byte = u8::from_str_radix(hex, 16).ok()?;
            out.push(byte);
            index += 3;
        } else {
            out.push(bytes[index]);
            index += 1;
        }
    }
    String::from_utf8(out).ok()
}

/// Strips a `file://` scheme so the result can be opened as a path.
pub fn normalize(value: &str) -> String {
    if !value.to_lowercase().starts_with("file://") {
        return value.to_string();
    }
    let rest = &value[7..];
    let authority_path = rest.strip_prefix("//").unwrap_or(rest);
    // `file:///a` leaves `/a`; `file://host/a` leaves `host/a` and keeps the
    // network-path meaning by prefixing `//`.
    let raw = if authority_path.starts_with('/') {
        authority_path.to_string()
    } else if rest.starts_with("//") {
        format!("//{authority_path}")
    } else {
        authority_path.to_string()
    };
    let decoded = match percent_decode(&raw) {
        Some(value) => value,
        None => return value.to_string(),
    };
    #[cfg(windows)]
    {
        let trimmed = decoded.trim_start_matches('/');
        if trimmed.len() > 1 && trimmed.as_bytes()[1] == b':' {
            return trimmed.to_string();
        }
    }
    decoded
}

pub fn to_local_path(value: &str) -> Option<String> {
    if !is_local(value) {
        return None;
    }
    let trimmed = value.trim();
    if trimmed.starts_with("content://") {
        return None;
    }
    Some(normalize(trimmed))
}

fn write_result(out: *mut u8, out_cap: usize, value: &str) -> isize {
    let bytes = value.as_bytes();
    if bytes.len() > out_cap {
        return -2;
    }
    if !out.is_null() {
        unsafe {
            std::ptr::copy_nonoverlapping(bytes.as_ptr(), out, bytes.len());
        }
    }
    bytes.len() as isize
}

/// Cover-path helper for the UI: mode 0 sharper, 1 rendition, 2 normalize,
/// 3 is-local (returns 1/0), 4 to-local-path.
///
/// Returns the written length, -1 for "no value", or -2 when `out_cap` is too
/// small.
///
/// # Safety
/// `url` must reference `url_len` readable bytes and `out` `out_cap` writable
/// bytes.
#[no_mangle]
pub unsafe extern "C" fn wispie_cover_path(
    url: *const u8,
    url_len: usize,
    wanted: u32,
    mode: u8,
    out: *mut u8,
    out_cap: usize,
) -> isize {
    if url.is_null() && url_len != 0 {
        return -1;
    }
    let bytes = if url_len == 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(url, url_len)
    };
    let Ok(value) = std::str::from_utf8(bytes) else {
        return -1;
    };
    let wanted = wanted as i64;

    match mode {
        0 => match sharper_url(value, wanted) {
            Some(result) => write_result(out, out_cap, &result),
            None => -1,
        },
        1 => match rendition_url(value, wanted) {
            Some(result) => write_result(out, out_cap, &result),
            None => -1,
        },
        2 => write_result(out, out_cap, &normalize(value)),
        3 => {
            if is_local(value) {
                1
            } else {
                0
            }
        }
        4 => match to_local_path(value) {
            Some(result) => write_result(out, out_cap, &result),
            None => -1,
        },
        _ => -1,
    }
}

fn signature_at(bytes: &[u8], offset: usize) -> Option<&'static str> {
    let matches = |signature: &[u8]| -> bool {
        offset + signature.len() <= bytes.len()
            && &bytes[offset..offset + signature.len()] == signature
    };
    if matches(&[0xFF, 0xD8, 0xFF]) {
        return Some(".jpg");
    }
    if matches(&[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
        return Some(".png");
    }
    if matches(&[0x47, 0x49, 0x46, 0x38]) {
        return Some(".gif");
    }
    if matches(&[0x52, 0x49, 0x46, 0x46])
        && matches_at(bytes, offset + 8, &[0x57, 0x45, 0x42, 0x50])
    {
        return Some(".webp");
    }
    None
}

fn matches_at(bytes: &[u8], offset: usize, signature: &[u8]) -> bool {
    offset + signature.len() <= bytes.len() && &bytes[offset..offset + signature.len()] == signature
}

/// The image payload in `raw` with leading junk removed, as (offset, extension).
pub fn recover_embedded(raw: &[u8]) -> Option<(usize, &'static str)> {
    if raw.len() < 4 {
        return None;
    }
    if matches_at(raw, 0, &[0x42, 0x4D]) {
        return Some((0, ".bmp"));
    }
    let limit = raw.len().min(MAX_LEADING_JUNK);
    for offset in 0..limit {
        if let Some(extension) = signature_at(raw, offset) {
            return Some((offset, extension));
        }
    }
    None
}

pub fn has_image_signature(head: &[u8]) -> bool {
    signature_at(head, 0).is_some() || matches_at(head, 0, &[0x42, 0x4D])
}

fn sniff_extension(bytes: &[u8]) -> Option<&'static str> {
    if bytes.len() < 4 {
        return None;
    }
    recover_embedded(bytes).map(|(_, extension)| extension)
}

pub fn content_key(bytes: &[u8]) -> String {
    let mut hasher = Sha1::new();
    hasher.update(bytes);
    let digest = hasher.finalize();
    let mut key = String::with_capacity(2 + digest.len() * 2);
    key.push_str("c_");
    for byte in digest {
        key.push_str(&format!("{byte:02x}"));
    }
    key
}

pub fn find_existing(directory: &Path, key: &str) -> Option<String> {
    for extension in COVER_EXTENSIONS {
        let path = directory.join(format!("{key}{extension}"));
        if let Ok(metadata) = std::fs::metadata(&path) {
            if metadata.len() > 0 {
                return Some(path.to_string_lossy().into_owned());
            }
        }
    }
    None
}

fn atomic_write(target: &Path, bytes: &[u8]) -> String {
    let parent = target.parent().unwrap_or(target);
    let base = target
        .file_stem()
        .map(|value| value.to_string_lossy().into_owned())
        .unwrap_or_else(|| "cover".to_string());
    let stamp = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map(|value| value.as_nanos())
        .unwrap_or(0);
    let temp = parent.join(format!("{base}.tmp_{stamp}"));
    if std::fs::write(&temp, bytes).is_err() {
        return temp.to_string_lossy().into_owned();
    }
    match std::fs::rename(&temp, target) {
        Ok(()) => target.to_string_lossy().into_owned(),
        Err(_) => {
            if target.exists() {
                let _ = std::fs::remove_file(&temp);
                target.to_string_lossy().into_owned()
            } else {
                temp.to_string_lossy().into_owned()
            }
        }
    }
}

fn encode_jpeg(image: &image::DynamicImage, quality: u8) -> Option<Vec<u8>> {
    let rgb = image.to_rgb8();
    let mut out: Vec<u8> = Vec::new();
    JpegEncoder::new_with_quality(&mut out, quality)
        .write_image(
            rgb.as_raw(),
            rgb.width(),
            rgb.height(),
            ExtendedColorType::Rgb8,
        )
        .ok()?;
    Some(out)
}

/// Writes `raw` as a content-addressed cover and returns its path.
pub fn save_optimized(
    raw: &[u8],
    directory: &str,
    fallback_extension: Option<&str>,
    max_dimension: u32,
    quality: u8,
) -> Result<String, String> {
    let directory = PathBuf::from(directory);
    let key = content_key(raw);
    if let Some(existing) = find_existing(&directory, &key) {
        return Ok(existing);
    }

    let extension = fallback_extension
        .map(str::to_string)
        .or_else(|| sniff_extension(raw).map(str::to_string))
        .unwrap_or_else(|| ".jpg".to_string());

    let decoded = image::load_from_memory(raw).ok();
    let Some(decoded) = decoded else {
        let target = directory.join(format!("{key}{extension}"));
        return Ok(atomic_write(&target, raw));
    };

    let oversized = decoded.width() > max_dimension || decoded.height() > max_dimension;

    // Already-compressed art within budget skips a re-encode.
    if !oversized && raw.len() <= FAST_PATH_BYTES && (extension == ".jpg" || extension == ".webp") {
        let target = directory.join(format!("{key}{extension}"));
        return Ok(atomic_write(&target, raw));
    }

    let resized = if oversized {
        let wider = decoded.width() >= decoded.height();
        let (target_w, target_h) = if wider {
            (
                max_dimension,
                (decoded.height() as f64 * max_dimension as f64 / decoded.width() as f64).round()
                    as u32,
            )
        } else {
            (
                (decoded.width() as f64 * max_dimension as f64 / decoded.height() as f64).round()
                    as u32,
                max_dimension,
            )
        };
        image::DynamicImage::ImageRgba8(image::imageops::resize(
            &decoded,
            target_w.max(1),
            target_h.max(1),
            FilterType::CatmullRom,
        ))
    } else {
        decoded
    };

    let Some(encoded) = encode_jpeg(&resized, quality) else {
        let target = directory.join(format!("{key}{extension}"));
        return Ok(atomic_write(&target, raw));
    };
    let target = directory.join(format!("{key}.jpg"));
    Ok(atomic_write(&target, &encoded))
}

pub fn sniff_json(bytes: Option<&[u8]>, head_only: bool) -> serde_json::Value {
    let Some(bytes) = bytes else {
        return json!({ "present": false });
    };
    if head_only {
        return json!({ "present": has_image_signature(bytes) });
    }
    match recover_embedded(bytes) {
        Some((offset, extension)) => json!({
            "present": true,
            "offset": offset,
            "extension": extension,
        }),
        None => json!({ "present": false }),
    }
}

pub fn emit_save(
    request: &serde_json::Value,
    bytes: Option<&[u8]>,
    emitter: &crate::emitter::Emitter,
) -> Result<(), String> {
    let bytes = bytes.ok_or_else(|| "cover_save needs image bytes".to_string())?;
    let directory = request
        .get("dir")
        .and_then(|value| value.as_str())
        .ok_or_else(|| "cover_save needs dir".to_string())?;
    let fallback = request
        .get("fallbackExtension")
        .and_then(|value| value.as_str());
    let max_dimension = request
        .get("maxDimension")
        .and_then(|value| value.as_u64())
        .map(|value| value as u32)
        .unwrap_or(MAX_COVER_DIMENSION);
    let quality = request
        .get("quality")
        .and_then(|value| value.as_u64())
        .map(|value| value.min(100) as u8)
        .unwrap_or(JPEG_QUALITY);

    let path = save_optimized(bytes, directory, fallback, max_dimension, quality)?;
    emitter.emit(Emit::Json(json!({ "path": path })));
    Ok(())
}
