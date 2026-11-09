//! Image signature sniffing, mirroring `embedded_cover_bytes.dart`.
//! Payloads are re-anchored on their magic bytes: a mis-parsed frame leaves junk in front.

/// How far in a signature is still believed to be the image start.
const MAX_LEADING_JUNK: usize = 512;

/// How many leading bytes of a cached cover are judged.
pub const SIGNATURE_PROBE_LEN: usize = 16;

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum ImageKind {
    Jpeg,
    Png,
    Gif,
    Webp,
    Bmp,
}

impl ImageKind {
    pub fn extension(self) -> &'static str {
        match self {
            ImageKind::Jpeg => ".jpg",
            ImageKind::Png => ".png",
            ImageKind::Gif => ".gif",
            ImageKind::Webp => ".webp",
            ImageKind::Bmp => ".bmp",
        }
    }
}

fn matches(bytes: &[u8], offset: usize, signature: &[u8]) -> bool {
    match bytes.get(offset..offset + signature.len()) {
        Some(slice) => slice == signature,
        None => false,
    }
}

/// The format whose signature starts exactly at `offset`.
fn signature_at(bytes: &[u8], offset: usize) -> Option<ImageKind> {
    if matches(bytes, offset, &[0xFF, 0xD8, 0xFF]) {
        return Some(ImageKind::Jpeg);
    }
    if matches(
        bytes,
        offset,
        &[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A],
    ) {
        return Some(ImageKind::Png);
    }
    if matches(bytes, offset, &[0x47, 0x49, 0x46, 0x38]) {
        return Some(ImageKind::Gif);
    }
    if matches(bytes, offset, &[0x52, 0x49, 0x46, 0x46])
        && matches(bytes, offset + 8, &[0x57, 0x45, 0x42, 0x50])
    {
        return Some(ImageKind::Webp);
    }
    None
}

/// How many trailing bytes [has_complete_image] needs to judge an image.
pub const TAIL_PROBE_LEN: usize = 256;

fn contains(haystack: &[u8], needle: &[u8]) -> bool {
    haystack
        .windows(needle.len())
        .any(|window| window == needle)
}

/// Whether the bytes bracketed by `head` and `tail` describe a *finished* image.
///
/// A signature alone is not enough: a truncated frame grab starts with a real
/// JPEG signature and decodes into a green smear. Requiring the matching end
/// marker is what tells a cover from a false positive in compressed audio.
pub fn has_complete_image(head: &[u8], tail: &[u8], length: u64) -> bool {
    if length < 16 {
        return false;
    }
    if matches(head, 0, &[0xFF, 0xD8, 0xFF]) {
        return contains(tail, &[0xFF, 0xD9]);
    }
    if matches(head, 0, &[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
        return contains(tail, b"IEND");
    }
    if matches(head, 0, &[0x47, 0x49, 0x46, 0x38]) {
        return contains(tail, &[0x3B]);
    }
    if matches(head, 0, &[0x52, 0x49, 0x46, 0x46]) && matches(head, 8, &[0x57, 0x45, 0x42, 0x50]) {
        if head.len() < 12 {
            return false;
        }
        let riff = u32::from_le_bytes([head[4], head[5], head[6], head[7]]) as u64;
        return riff != 0 && riff + 8 <= length;
    }
    matches(head, 0, &[0x42, 0x4D]) && length >= 54
}

/// The payload offset past any leading junk, plus its format.
pub fn recover_embedded_cover(raw: &[u8]) -> Option<(usize, ImageKind)> {
    if raw.len() < 4 {
        return None;
    }

    // BMP's two-byte signature is weak, so it is only trusted at offset 0.
    if matches(raw, 0, &[0x42, 0x4D]) {
        return Some((0, ImageKind::Bmp));
    }

    let limit = raw.len().min(MAX_LEADING_JUNK);
    (0..limit).find_map(|offset| signature_at(raw, offset).map(|kind| (offset, kind)))
}
