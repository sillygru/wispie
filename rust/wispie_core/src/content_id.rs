//! Content ids for audio files: the hash of a container's audio region, never
//! its name, tags, cover or padding. Ported from `audio_content_id.dart`.
//!
//! Format is `<kind>:<32 hex chars>`, where the kind records how the id was
//! derived so ids from different strategies cannot collide. The region is
//! sampled from its length plus eight spread blocks, so the cost per file is
//! constant regardless of its size.

use crate::emitter::{Emit, Emitter};
use serde_json::{json, Value};
use std::collections::HashSet;
use std::fs::File;
use std::io::{Read, Seek, SeekFrom};
use std::path::Path;
use std::time::UNIX_EPOCH;

const BLOCK_SIZE: u64 = 16 * 1024;
const BLOCK_COUNT: u64 = 8;
const OGG_BODY_SAMPLE: usize = 2048;

struct Region {
    kind: &'static str,
    start: u64,
    end: u64,
}

impl Region {
    fn length(&self) -> u64 {
        self.end.saturating_sub(self.start)
    }
}

/// The content id of `path`, or none when it cannot be read or is empty.
pub fn compute(path: &str) -> Option<String> {
    let mut file = File::open(path).ok()?;
    let size = file.metadata().ok()?.len();
    if size == 0 {
        return None;
    }

    let audio_start = skip_id3v2(&mut file, size);
    let magic = read_at(&mut file, audio_start, 12);

    if ascii(&magic, 0, "fLaC") {
        if let Some(id) = flac(&mut file, size, audio_start) {
            return Some(id);
        }
    }
    if audio_start == 0 && ascii(&magic, 0, "OggS") {
        return ogg(&mut file, size);
    }
    if audio_start == 0 && ascii(&magic, 4, "ftyp") {
        if let Some(region) = mp4(&mut file, size) {
            return hash_region(&mut file, &region);
        }
    }
    if audio_start == 0 && ascii(&magic, 0, "RIFF") && ascii(&magic, 8, "WAVE") {
        if let Some(region) = riff(&mut file, size, false, "data") {
            return hash_region(&mut file, &region);
        }
    }
    if audio_start == 0 && ascii(&magic, 0, "FORM") && ascii(&magic, 8, "AIF") {
        if let Some(region) = riff(&mut file, size, true, "SSND") {
            return hash_region(&mut file, &region);
        }
    }
    if looks_like_mpeg_audio(&magic) || audio_start > 0 {
        let end = strip_trailing_tags(&mut file, size, audio_start);
        if end > audio_start {
            return hash_region(
                &mut file,
                &Region {
                    kind: "m1",
                    start: audio_start,
                    end,
                },
            );
        }
    }
    hash_region(
        &mut file,
        &Region {
            kind: "r1",
            start: 0,
            end: size,
        },
    )
}

fn read_at(file: &mut File, offset: u64, length: usize) -> Vec<u8> {
    if file.seek(SeekFrom::Start(offset)).is_err() {
        return Vec::new();
    }
    let mut buffer = vec![0u8; length];
    let mut filled = 0;
    while filled < length {
        match file.read(&mut buffer[filled..]) {
            Ok(0) | Err(_) => break,
            Ok(read) => filled += read,
        }
    }
    buffer.truncate(filled);
    buffer
}

fn ascii(bytes: &[u8], at: usize, text: &str) -> bool {
    let end = at + text.len();
    bytes.len() >= end && &bytes[at..end] == text.as_bytes()
}

fn looks_like_mpeg_audio(bytes: &[u8]) -> bool {
    bytes.len() >= 2 && bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0
}

fn skip_id3v2(file: &mut File, size: u64) -> u64 {
    let mut position = 0u64;
    for _ in 0..8 {
        let header = read_at(file, position, 10);
        if header.len() < 10 || !ascii(&header, 0, "ID3") {
            break;
        }
        let tag_size = ((header[6] as u64 & 0x7F) << 21)
            | ((header[7] as u64 & 0x7F) << 14)
            | ((header[8] as u64 & 0x7F) << 7)
            | (header[9] as u64 & 0x7F);
        let footer = if header[5] & 0x10 != 0 { 10 } else { 0 };
        let next = position + 10 + tag_size + footer;
        if next >= size {
            break;
        }
        position = next;
    }
    position
}

fn strip_trailing_tags(file: &mut File, size: u64, start: u64) -> u64 {
    let mut end = size;
    if end.saturating_sub(start) > 128 {
        let tail = read_at(file, end - 128, 3);
        if ascii(&tail, 0, "TAG") {
            end -= 128;
        }
    }
    if end.saturating_sub(start) > 32 {
        let footer = read_at(file, end - 32, 32);
        if ascii(&footer, 0, "APETAGEX") {
            let tag_size = u32::from_le_bytes([footer[12], footer[13], footer[14], footer[15]]);
            let flags = u32::from_le_bytes([footer[20], footer[21], footer[22], footer[23]]);
            let has_header = flags & 0x8000_0000 != 0;
            let cut = tag_size as u64 + if has_header { 32 } else { 0 };
            if cut > 0 && end.saturating_sub(cut) > start {
                end -= cut;
            }
        }
    }
    end
}

fn flac(file: &mut File, size: u64, start: u64) -> Option<String> {
    let mut position = start + 4;
    for _ in 0..256 {
        let header = read_at(file, position, 4);
        if header.len() < 4 {
            return None;
        }
        let last = header[0] & 0x80 != 0;
        let kind = header[0] & 0x7F;
        let length = (header[1] as u64) << 16 | (header[2] as u64) << 8 | header[3] as u64;
        if kind == 0 && length >= 34 {
            let info = read_at(file, position + 4, 34);
            if info.len() == 34 {
                let md5 = &info[18..34];
                if md5.iter().any(|byte| *byte != 0) {
                    return Some(format!("f1:{}", hex(md5)));
                }
            }
        }
        position += 4 + length;
        if last {
            break;
        }
        if position >= size {
            return None;
        }
    }
    if position >= size {
        return None;
    }
    hash_region(
        file,
        &Region {
            kind: "p1",
            start: position,
            end: size,
        },
    )
}

fn mp4(file: &mut File, size: u64) -> Option<Region> {
    let mut best: Option<Region> = None;
    let mut position = 0u64;
    for _ in 0..10000 {
        if position + 8 > size {
            break;
        }
        let header = read_at(file, position, 16);
        if header.len() < 8 {
            break;
        }
        let mut atom_size = u32::from_be_bytes([header[0], header[1], header[2], header[3]]) as u64;
        let mut atom_header = 8u64;
        if atom_size == 1 {
            if header.len() < 16 {
                break;
            }
            atom_size = u64::from_be_bytes([
                header[8], header[9], header[10], header[11], header[12], header[13], header[14],
                header[15],
            ]);
            atom_header = 16;
        } else if atom_size == 0 {
            atom_size = size - position;
        }
        if atom_size < atom_header {
            break;
        }
        let end = (position + atom_size).min(size);
        if ascii(&header, 4, "mdat") {
            let region = Region {
                kind: "a1",
                start: position + atom_header,
                end,
            };
            match &best {
                Some(current) if current.length() >= region.length() => {}
                _ => best = Some(region),
            }
        }
        position = end;
    }
    best.filter(|region| region.length() > 0)
}

fn riff(file: &mut File, size: u64, big_endian: bool, data_id: &str) -> Option<Region> {
    let mut position = 12u64;
    for _ in 0..1000 {
        if position + 8 > size {
            break;
        }
        let header = read_at(file, position, 8);
        if header.len() < 8 {
            break;
        }
        let raw = [header[4], header[5], header[6], header[7]];
        let length = if big_endian {
            u32::from_be_bytes(raw)
        } else {
            u32::from_le_bytes(raw)
        } as u64;
        if ascii(&header, 0, data_id) {
            let start = position + 8;
            let end = (start + length).min(size);
            return if end > start {
                Some(Region {
                    kind: "w1",
                    start,
                    end,
                })
            } else {
                None
            };
        }
        position += 8 + length + (length & 1);
    }
    None
}

fn ogg(file: &mut File, size: u64) -> Option<String> {
    let mut position = 0u64;
    let mut audio_start: Option<u64> = None;
    for _ in 0..4096 {
        if position + 27 > size {
            break;
        }
        let header = read_at(file, position, 27);
        if header.len() < 27 || !ascii(&header, 0, "OggS") {
            break;
        }
        let granule = i64::from_le_bytes(header[6..14].try_into().ok()?);
        let segments = header[26] as usize;
        let table = read_at(file, position + 27, segments);
        if granule > 0 {
            audio_start = Some(position);
            break;
        }
        let body: u64 = table.iter().map(|value| *value as u64).sum();
        position += 27 + segments as u64 + body;
    }
    let audio_start = audio_start?;
    if audio_start >= size {
        return None;
    }

    let tail_length = (size - audio_start).min(64 * 1024);
    let tail = read_at(file, size - tail_length, tail_length as usize);
    let mut final_granule: Option<i64> = None;
    if tail.len() >= 27 {
        for index in (0..=tail.len() - 27).rev() {
            if tail[index] == 0x4F && ascii(&tail, index, "OggS") {
                let granule = i64::from_le_bytes(tail[index + 6..index + 14].try_into().ok()?);
                if granule > 0 {
                    final_granule = Some(granule);
                    break;
                }
            }
        }
    }
    let final_granule = final_granule?;

    let mut hasher = Sha256::new();
    hasher.update(b"o1");
    hasher.update(&final_granule.to_be_bytes());
    let span = size - audio_start;
    for index in 0..BLOCK_COUNT {
        // Dart's negative result is clamped to `audio_start`; saturating keeps
        // the same block for a region shorter than one sample block.
        let from = audio_start + span.saturating_sub(BLOCK_SIZE) * index / (BLOCK_COUNT - 1);
        let Some((offset, body)) = next_ogg_page(file, from.max(audio_start), size) else {
            continue;
        };
        hasher.update(&(offset - audio_start).to_be_bytes());
        hasher.update(&body);
    }
    let digest = hasher.finish();
    Some(format!("o1:{}", hex(&digest[..16])))
}

fn next_ogg_page(file: &mut File, from: u64, size: u64) -> Option<(u64, Vec<u8>)> {
    const WINDOW: u64 = 8 * 1024;
    let mut position = from;
    while position + 27 < size {
        let buffer = read_at(file, position, WINDOW.min(size - position) as usize);
        let mut found = None;
        if buffer.len() >= 27 {
            for index in 0..=buffer.len() - 27 {
                if buffer[index] == 0x4F && ascii(&buffer, index, "OggS") && buffer[index + 4] == 0
                {
                    found = Some(position + index as u64);
                    break;
                }
            }
        }
        if let Some(at) = found {
            let header = read_at(file, at, 27);
            let segments = *header.get(26)? as usize;
            let table = read_at(file, at + 27, segments);
            let body_length: usize = table.iter().map(|value| *value as usize).sum();
            let body = read_at(
                file,
                at + 27 + segments as u64,
                body_length.min(OGG_BODY_SAMPLE),
            );
            return Some((at, body));
        }
        if buffer.len() < 28 {
            break;
        }
        position += buffer.len() as u64 - 27;
    }
    None
}

fn hash_region(file: &mut File, region: &Region) -> Option<String> {
    if region.length() == 0 {
        return None;
    }
    let mut hasher = Sha256::new();
    hasher.update(region.kind.as_bytes());
    hasher.update(&region.length().to_be_bytes());
    if region.length() <= BLOCK_SIZE * BLOCK_COUNT {
        let data = read_at(file, region.start, region.length() as usize);
        hasher.update(&data);
    } else {
        for index in 0..BLOCK_COUNT {
            let at = region.start + (region.length() - BLOCK_SIZE) * index / (BLOCK_COUNT - 1);
            let block = read_at(file, at, BLOCK_SIZE as usize);
            hasher.update(&block);
        }
    }
    let digest = hasher.finish();
    Some(format!("{}:{}", region.kind, hex(&digest[..16])))
}

fn hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push_str(&format!("{byte:02x}"));
    }
    out
}

/// Result of probing one path on disk.
pub struct FileProbe {
    pub path: String,
    pub exists: bool,
    pub mtime: Option<f64>,
    pub content_id: Option<String>,
}

/// Stats every path and hashes the ones in `hash_paths`.
pub fn probe_files(
    paths: &[String],
    hash_paths: &std::collections::HashSet<String>,
) -> Vec<FileProbe> {
    paths
        .iter()
        .map(|path| {
            let metadata = match std::fs::metadata(Path::new(path)) {
                Ok(metadata) if metadata.is_file() => metadata,
                _ => {
                    return FileProbe {
                        path: path.clone(),
                        exists: false,
                        mtime: None,
                        content_id: None,
                    }
                }
            };
            let mtime = metadata
                .modified()
                .ok()
                .and_then(|time| time.duration_since(UNIX_EPOCH).ok())
                .map(|duration| duration.as_millis() as f64 / 1000.0);
            let content_id = if hash_paths.contains(path) {
                compute(path)
            } else {
                None
            };
            FileProbe {
                path: path.clone(),
                exists: true,
                mtime,
                content_id,
            }
        })
        .collect()
}

/// Probes every path once: existence, mtime and, when asked, the content id.
pub fn emit_probe(request: &Value, emitter: &Emitter) -> Result<(), String> {
    let paths: Vec<String> = request
        .get("paths")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default();
    let hash_paths: HashSet<String> = request
        .get("hashPaths")
        .and_then(Value::as_array)
        .map(|values| {
            values
                .iter()
                .filter_map(Value::as_str)
                .map(str::to_owned)
                .collect()
        })
        .unwrap_or_default();
    let files: Vec<Value> = probe_files(&paths, &hash_paths)
        .into_iter()
        .map(|probe| {
            json!({
                "path": probe.path,
                "exists": probe.exists,
                "mtime": probe.mtime,
                "contentId": probe.content_id,
            })
        })
        .collect();
    emitter.emit(Emit::Json(json!({ "files": files })));
    Ok(())
}

// ---------------------------------------------------------------------------
// SHA-256
// ---------------------------------------------------------------------------

/// Minimal SHA-256 so the core gains no dependency just to hash sampled blocks.
struct Sha256 {
    state: [u32; 8],
    buffer: [u8; 64],
    buffered: usize,
    length: u64,
}

const K: [u32; 64] = [
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
];

impl Sha256 {
    fn new() -> Self {
        Self {
            state: [
                0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a, 0x510e527f, 0x9b05688c, 0x1f83d9ab,
                0x5be0cd19,
            ],
            buffer: [0; 64],
            buffered: 0,
            length: 0,
        }
    }

    fn update(&mut self, mut data: &[u8]) {
        self.length += data.len() as u64;
        if self.buffered > 0 {
            let take = (64 - self.buffered).min(data.len());
            self.buffer[self.buffered..self.buffered + take].copy_from_slice(&data[..take]);
            self.buffered += take;
            data = &data[take..];
            if self.buffered == 64 {
                let block = self.buffer;
                self.compress(&block);
                self.buffered = 0;
            }
        }
        while data.len() >= 64 {
            let mut block = [0u8; 64];
            block.copy_from_slice(&data[..64]);
            self.compress(&block);
            data = &data[64..];
        }
        if !data.is_empty() {
            self.buffer[..data.len()].copy_from_slice(data);
            self.buffered = data.len();
        }
    }

    fn finish(mut self) -> [u8; 32] {
        let bits = self.length * 8;
        self.update(&[0x80]);
        while self.buffered != 56 {
            self.update(&[0]);
        }
        // `update` counted the padding; the length field is the pre-padding size.
        self.buffer[56..64].copy_from_slice(&bits.to_be_bytes());
        let block = self.buffer;
        self.buffered = 0;
        self.compress(&block);

        let mut out = [0u8; 32];
        for (index, word) in self.state.iter().enumerate() {
            out[index * 4..index * 4 + 4].copy_from_slice(&word.to_be_bytes());
        }
        out
    }

    fn compress(&mut self, block: &[u8; 64]) {
        let mut w = [0u32; 64];
        for index in 0..16 {
            w[index] = u32::from_be_bytes([
                block[index * 4],
                block[index * 4 + 1],
                block[index * 4 + 2],
                block[index * 4 + 3],
            ]);
        }
        for index in 16..64 {
            let s0 = w[index - 15].rotate_right(7)
                ^ w[index - 15].rotate_right(18)
                ^ (w[index - 15] >> 3);
            let s1 = w[index - 2].rotate_right(17)
                ^ w[index - 2].rotate_right(19)
                ^ (w[index - 2] >> 10);
            w[index] = w[index - 16]
                .wrapping_add(s0)
                .wrapping_add(w[index - 7])
                .wrapping_add(s1);
        }

        let [mut a, mut b, mut c, mut d, mut e, mut f, mut g, mut h] = self.state;
        for index in 0..64 {
            let s1 = e.rotate_right(6) ^ e.rotate_right(11) ^ e.rotate_right(25);
            let choice = (e & f) ^ (!e & g);
            let temp1 = h
                .wrapping_add(s1)
                .wrapping_add(choice)
                .wrapping_add(K[index])
                .wrapping_add(w[index]);
            let s0 = a.rotate_right(2) ^ a.rotate_right(13) ^ a.rotate_right(22);
            let majority = (a & b) ^ (a & c) ^ (b & c);
            let temp2 = s0.wrapping_add(majority);
            h = g;
            g = f;
            f = e;
            e = d.wrapping_add(temp1);
            d = c;
            c = b;
            b = a;
            a = temp1.wrapping_add(temp2);
        }

        for (slot, value) in self.state.iter_mut().zip([a, b, c, d, e, f, g, h]) {
            *slot = slot.wrapping_add(value);
        }
    }
}
