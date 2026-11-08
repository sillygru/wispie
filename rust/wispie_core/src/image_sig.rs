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

/// Whether `head` starts with magic bytes a decoder accepts.
/// Catches covers cached before payload recovery: right size, decode as nothing.
pub fn has_image_signature(head: &[u8]) -> bool {
    signature_at(head, 0).is_some() || matches(head, 0, &[0x42, 0x4D])
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
