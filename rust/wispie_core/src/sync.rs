//! Encrypted sync contract: key derivation, sealed boxes, the recovery key, the
//! proof-of-work nonce, the blob framing and the song-reference rewriter.
//!
//! Ported from `sync/crypto.dart`, `sync/blob_codec.dart` and `sync/song_refs.dart`.
//! Every byte here is a contract with already-shipped clients and the Go server,
//! so the derived keys, the sealed layout, the chunk nonces and the blob header
//! must stay exactly as they are.

use argon2::{Algorithm, Argon2, Params, Version};
use base64::Engine;
use chacha20poly1305::{
    aead::{Aead, Payload},
    KeyInit, XChaCha20Poly1305, XNonce,
};
use flate2::{read::GzDecoder, write::GzEncoder, Compression};
use hmac::{Hmac, Mac};
use serde_json::{json, Map, Value};
use sha2::{Digest, Sha256};
use std::collections::HashSet;
use std::io::{Read, Write};
use unicode_normalization::UnicodeNormalization;

const CTX_AUTH: &str = "wispie/auth/v1";
const CTX_KEK: &str = "wispie/kek/v1";
const CTX_DATA: &str = "wispie/data/v1";
const CTX_RECOVERY_AUTH: &str = "wispie/rauth/v1";
const CTX_RECOVERY_KEK: &str = "wispie/rkek/v1";
const AAD_ACCOUNT_KEY: &str = "wispie/ak/v1|";
const AAD_ACCOUNT_KEY_RECOVERY: &str = "wispie/ak-rk/v1|";

const NONCE_BYTES: usize = 24;
const TAG_BYTES: usize = 16;

const BLOB_MAGIC: [u8; 4] = [0x57, 0x53, 0x50, 0x42];
const BLOB_VERSION: u8 = 1;
const PLAIN_CHUNK: usize = 65536;
const CIPHER_CHUNK: usize = PLAIN_CHUNK + TAG_BYTES;
const BLOB_PREFIX_LEN: usize = 26;
const BLOB_HEADER_LEN: usize = BLOB_PREFIX_LEN + NONCE_BYTES;

const RECOVERY_ALPHABET: &[u8; 32] = b"0123456789ABCDEFGHJKMNPQRSTVWXYZ";
const RECOVERY_BYTES: usize = 20;

const NAME_FIELD: &[(&str, &str)] = &[
    ("favorites", "filename"),
    ("suggestless", "filename"),
    ("hidden", "filename"),
    ("merged_songs", "filename"),
    ("merged_groups", "priority_filename"),
    ("playlist_songs", "song_filename"),
    ("play_events", "song_filename"),
];

const TOMBSTONE_NAME_PART: &[(&str, usize)] = &[
    ("favorites", 0),
    ("suggestless", 0),
    ("hidden", 0),
    ("merged_songs", 0),
    ("playlist_songs", 1),
];

const NAME_SEP: char = '\u{0}';

/// A blob is bytes, not JSON: base64 would double the copy for no reason.
pub enum Reply {
    Json(Value),
    Bytes(Vec<u8>),
}

pub fn run(payload: &Value, bytes: &[u8]) -> Result<Reply, String> {
    match text(payload, "action")? {
        "blob_encode" => return blob_encode(payload, bytes).map(Reply::Bytes),
        "blob_decode" => return blob_decode(payload, bytes).map(Reply::Bytes),
        _ => {}
    }
    json_reply(payload).map(Reply::Json)
}

fn json_reply(payload: &Value) -> Result<Value, String> {
    match text(payload, "action")? {
        "normalize" => {
            let value = text(payload, "text")?;
            let username = payload
                .get("username")
                .and_then(Value::as_bool)
                .unwrap_or(false);
            let normalized = if username {
                value.trim().nfkc().collect::<String>().to_lowercase()
            } else {
                value.nfkc().collect::<String>()
            };
            Ok(json!({ "value": normalized }))
        }
        "random" => {
            let count = integer(payload, "bytes")?.max(0) as usize;
            Ok(json!({ "hex": hex(&random(count)?) }))
        }
        "argon2" => argon2(payload),
        "derive" => {
            let key = unhex(text(payload, "keyHex")?)?;
            let derived = derive(&key, text(payload, "context")?)?;
            Ok(json!({ "keyHex": hex(&derived) }))
        }
        "derive_role" => {
            let key = unhex(text(payload, "keyHex")?)?;
            let context = match text(payload, "role")? {
                "auth" => CTX_AUTH,
                "kek" => CTX_KEK,
                "data" => CTX_DATA,
                "recovery_auth" => CTX_RECOVERY_AUTH,
                "recovery_kek" => CTX_RECOVERY_KEK,
                other => return Err(format!("crypto: unknown key role: {other}")),
            };
            let derived = derive(&key, context)?;
            Ok(json!({ "keyHex": hex(&derived) }))
        }
        "seal" => {
            let key = unhex(text(payload, "keyHex")?)?;
            let plain = unhex(text(payload, "plainHex")?)?;
            let aad = text(payload, "aad")?.to_string();
            let nonce = match payload.get("nonceHex").and_then(Value::as_str) {
                Some(value) => unhex(value)?,
                None => random(NONCE_BYTES)?,
            };
            let sealed = seal(&key, &plain, aad.as_bytes(), &nonce)?;
            Ok(json!({ "sealedHex": hex(&sealed), "nonceHex": hex(&nonce) }))
        }
        "open" => {
            let key = unhex(text(payload, "keyHex")?)?;
            let sealed = unhex(text(payload, "sealedHex")?)?;
            let aad = text(payload, "aad")?.to_string();
            let plain = open(&key, &sealed, aad.as_bytes())?;
            Ok(json!({ "plainHex": hex(&plain) }))
        }
        "wrap_account_key" => {
            let kek = unhex(text(payload, "keyHex")?)?;
            let account_key = unhex(text(payload, "accountKeyHex")?)?;
            let id = text(payload, "accountId")?;
            let aad = format!("{AAD_ACCOUNT_KEY}{id}");
            let nonce = random(NONCE_BYTES)?;
            Ok(json!({
                "sealedHex": hex(&seal(&kek, &account_key, aad.as_bytes(), &nonce)?),
            }))
        }
        "unwrap_account_key" => {
            let kek = unhex(text(payload, "keyHex")?)?;
            let sealed = unhex(text(payload, "sealedHex")?)?;
            let id = text(payload, "accountId")?;
            let aad = format!("{AAD_ACCOUNT_KEY}{id}");
            Ok(json!({ "accountKeyHex": hex(&open(&kek, &sealed, aad.as_bytes())?) }))
        }
        "wrap_account_key_recovery" => {
            let kek = unhex(text(payload, "keyHex")?)?;
            let account_key = unhex(text(payload, "accountKeyHex")?)?;
            let id = text(payload, "accountId")?;
            let aad = format!("{AAD_ACCOUNT_KEY_RECOVERY}{id}");
            let nonce = random(NONCE_BYTES)?;
            Ok(json!({
                "sealedHex": hex(&seal(&kek, &account_key, aad.as_bytes(), &nonce)?),
            }))
        }
        "unwrap_account_key_recovery" => {
            let kek = unhex(text(payload, "keyHex")?)?;
            let sealed = unhex(text(payload, "sealedHex")?)?;
            let id = text(payload, "accountId")?;
            let aad = format!("{AAD_ACCOUNT_KEY_RECOVERY}{id}");
            Ok(json!({ "accountKeyHex": hex(&open(&kek, &sealed, aad.as_bytes())?) }))
        }
        "pow" => {
            let challenge = text(payload, "challenge")?;
            let bits = integer(payload, "bits")?.max(0) as u32;
            Ok(json!({ "nonce": solve_pow(challenge, bits) }))
        }
        "recovery_encode" => {
            let key = unhex(text(payload, "keyHex")?)?;
            Ok(json!({ "text": recovery_encode(&key)? }))
        }
        "recovery_decode" => {
            let key = recovery_decode(text(payload, "text")?)?;
            Ok(json!({ "keyHex": hex(&key) }))
        }
        "refs_collect" => {
            let records = payload
                .get("records")
                .ok_or_else(|| "refs_collect needs records".to_string())?;
            let names = collect_song_names(records);
            Ok(json!({ "names": names.into_iter().collect::<Vec<_>>() }))
        }
        "refs_remap" => {
            let records = payload
                .get("records")
                .ok_or_else(|| "refs_remap needs records".to_string())?;
            let mapping = payload
                .get("mapping")
                .and_then(Value::as_object)
                .cloned()
                .unwrap_or_default();
            Ok(json!({ "records": remap_song_names(records, &mapping) }))
        }
        other => Err(format!("unknown sync action: {other}")),
    }
}

fn argon2(payload: &Value) -> Result<Value, String> {
    let password = text(payload, "password")?.nfkc().collect::<String>();
    let salt = unhex(text(payload, "saltHex")?)?;
    let params = Params::new(
        integer(payload, "mKiB")?.max(1) as u32,
        integer(payload, "iterations")?.max(1) as u32,
        integer(payload, "parallelism")?.max(1) as u32,
        Some(32),
    )
    .map_err(|error| format!("crypto: argon2 params: {error}"))?;
    let argon = Argon2::new(Algorithm::Argon2id, Version::V0x13, params);
    let mut out = [0u8; 32];
    argon
        .hash_password_into(password.as_bytes(), &salt, &mut out)
        .map_err(|error| format!("crypto: argon2: {error}"))?;
    Ok(json!({ "keyHex": hex(&out) }))
}

fn derive(key: &[u8], context: &str) -> Result<Vec<u8>, String> {
    let mut mac = <Hmac<Sha256> as Mac>::new_from_slice(key)
        .map_err(|error| format!("crypto: hmac key: {error}"))?;
    mac.update(context.as_bytes());
    Ok(mac.finalize().into_bytes().to_vec())
}

fn seal(key: &[u8], plain: &[u8], aad: &[u8], nonce: &[u8]) -> Result<Vec<u8>, String> {
    if nonce.len() != NONCE_BYTES {
        return Err("crypto: nonce must be 24 bytes".to_string());
    }
    let cipher = XChaCha20Poly1305::new_from_slice(key)
        .map_err(|error| format!("crypto: data key: {error}"))?;
    let encrypted = cipher
        .encrypt(XNonce::from_slice(nonce), Payload { msg: plain, aad })
        .map_err(|_| "crypto: authentication failed".to_string())?;
    let mut out = Vec::with_capacity(NONCE_BYTES + encrypted.len());
    out.extend_from_slice(nonce);
    out.extend_from_slice(&encrypted);
    Ok(out)
}

fn open(key: &[u8], sealed: &[u8], aad: &[u8]) -> Result<Vec<u8>, String> {
    if sealed.len() < NONCE_BYTES + TAG_BYTES {
        return Err("crypto: sealed box too short".to_string());
    }
    let (nonce, body) = sealed.split_at(NONCE_BYTES);
    let cipher = XChaCha20Poly1305::new_from_slice(key)
        .map_err(|error| format!("crypto: data key: {error}"))?;
    cipher
        .decrypt(XNonce::from_slice(nonce), Payload { msg: body, aad })
        .map_err(|_| "crypto: authentication failed".to_string())
}

fn solve_pow(challenge: &str, bits: u32) -> String {
    let mut counter: u64 = 0;
    loop {
        let nonce = base64::engine::general_purpose::URL_SAFE_NO_PAD.encode(counter.to_be_bytes());
        let mut digest = Sha256::new();
        digest.update(challenge.as_bytes());
        digest.update(nonce.as_bytes());
        let bytes = digest.finalize();
        if leading_zero_bits(&bytes) >= bits {
            return nonce;
        }
        counter = counter.wrapping_add(1);
    }
}

fn leading_zero_bits(digest: &[u8]) -> u32 {
    let mut count = 0;
    for byte in digest {
        if *byte == 0 {
            count += 8;
            continue;
        }
        return count + byte.leading_zeros();
    }
    count
}

fn recovery_encode(key: &[u8]) -> Result<String, String> {
    if key.len() != RECOVERY_BYTES {
        return Err(format!(
            "crypto: recovery key must be {RECOVERY_BYTES} bytes"
        ));
    }
    let mut values: Vec<u8> = Vec::new();
    let mut bits = 0u32;
    let mut acc: u32 = 0;
    for byte in key {
        acc = (acc << 8) | *byte as u32;
        bits += 8;
        while bits >= 5 {
            values.push(((acc >> (bits - 5)) & 31) as u8);
            bits -= 5;
        }
        acc &= (1u32 << bits) - 1;
    }
    values.push(recovery_check(&values));

    let mut text = String::new();
    for (index, value) in values.iter().enumerate() {
        if index > 0 && index % 5 == 0 {
            text.push('-');
        }
        text.push(RECOVERY_ALPHABET[*value as usize] as char);
    }
    Ok(text)
}

fn recovery_check(values: &[u8]) -> u8 {
    let mut sum = 0u32;
    for (index, value) in values.iter().enumerate() {
        sum += ((index as u32 % 30) + 1) * *value as u32;
    }
    (sum % 31) as u8
}

fn recovery_decode(input: &str) -> Result<Vec<u8>, String> {
    let cleaned: Vec<char> = input
        .to_uppercase()
        .chars()
        .filter(|ch| !ch.is_whitespace() && *ch != '-')
        .collect();
    let mut values: Vec<u8> = Vec::with_capacity(cleaned.len());
    for ch in cleaned {
        let mapped = match ch {
            'O' => '0',
            'I' | 'L' => '1',
            other => other,
        };
        let index = RECOVERY_ALPHABET
            .iter()
            .position(|candidate| *candidate as char == mapped)
            .ok_or_else(|| "crypto: invalid recovery key".to_string())?;
        values.push(index as u8);
    }
    if values.len() != 33 {
        return Err("crypto: invalid recovery key length".to_string());
    }
    let check = values.pop().unwrap();
    if recovery_check(&values) != check {
        return Err("crypto: recovery key check failed".to_string());
    }

    let mut out = Vec::with_capacity(RECOVERY_BYTES);
    let mut bits = 0u32;
    let mut acc: u32 = 0;
    for value in values {
        acc = (acc << 5) | value as u32;
        bits += 5;
        if bits >= 8 {
            out.push(((acc >> (bits - 8)) & 255) as u8);
            bits -= 8;
            acc &= (1u32 << bits) - 1;
        }
    }
    Ok(out)
}

/// Padme padding (Nikitin et al.): leaks only O(log log L) bits of length.
fn padme_length(length: usize) -> usize {
    if length < 2 {
        return length;
    }
    let exponent = usize::BITS - 1 - length.leading_zeros();
    let shift = u32::BITS - exponent.leading_zeros();
    let last_bits = exponent as i64 - shift as i64;
    if last_bits <= 0 {
        return length;
    }
    let mask = (1usize << last_bits) - 1;
    (length + mask) & !mask
}

fn frame(json: &[u8]) -> Result<Vec<u8>, String> {
    let mut encoder = GzEncoder::new(Vec::new(), Compression::default());
    encoder
        .write_all(json)
        .map_err(|error| format!("blob: gzip: {error}"))?;
    let gz = encoder
        .finish()
        .map_err(|error| format!("blob: gzip: {error}"))?;
    let mut framed = vec![0u8; padme_length(8 + gz.len())];
    framed[..8].copy_from_slice(&(gz.len() as u64).to_be_bytes());
    framed[8..8 + gz.len()].copy_from_slice(&gz);
    Ok(framed)
}

fn unframe(framed: &[u8]) -> Result<Vec<u8>, String> {
    if framed.len() < 8 {
        return Err("blob: frame too short".to_string());
    }
    let mut length_bytes = [0u8; 8];
    length_bytes.copy_from_slice(&framed[..8]);
    let length = u64::from_be_bytes(length_bytes) as usize;
    if length > framed.len().saturating_sub(8) || framed.len() != padme_length(8 + length) {
        return Err("blob: bad frame length".to_string());
    }
    if framed[8 + length..].iter().any(|byte| *byte != 0) {
        return Err("blob: bad padding".to_string());
    }
    let mut decoder = GzDecoder::new(&framed[8..8 + length]);
    let mut out = Vec::new();
    decoder
        .read_to_end(&mut out)
        .map_err(|_| "blob: bad gzip".to_string())?;
    Ok(out)
}

fn chunk_nonce(base: &[u8], index: u64, last: bool) -> [u8; NONCE_BYTES] {
    let mut nonce = [0u8; NONCE_BYTES];
    nonce[..15].copy_from_slice(&base[..15]);
    nonce[15..23].copy_from_slice(&index.to_be_bytes());
    nonce[23] = u8::from(last);
    nonce
}

fn blob_encode(payload: &Value, payload_json: &[u8]) -> Result<Vec<u8>, String> {
    let key = unhex(text(payload, "dataKeyHex")?)?;
    let account = unhex(text(payload, "accountIdHex")?)?;
    let kind = integer(payload, "kind")? as u8;
    let epoch = integer(payload, "epoch")? as u32;
    let blob_id = match payload.get("blobIdHex").and_then(Value::as_str) {
        Some(value) => unhex(value)?,
        None => random(16)?,
    };
    let base = match payload.get("nonceHex").and_then(Value::as_str) {
        Some(value) => unhex(value)?,
        None => random(NONCE_BYTES)?,
    };
    if blob_id.len() != 16 || base.len() != NONCE_BYTES {
        return Err("blob: bad blob id or nonce".to_string());
    }

    let mut header = vec![0u8; BLOB_HEADER_LEN];
    header[..4].copy_from_slice(&BLOB_MAGIC);
    header[4] = BLOB_VERSION;
    header[5] = kind;
    header[6..10].copy_from_slice(&epoch.to_be_bytes());
    header[10..26].copy_from_slice(&blob_id);
    header[26..].copy_from_slice(&base);

    let mut aad = account;
    aad.extend_from_slice(&header);

    let plain = frame(payload_json)?;
    let cipher = XChaCha20Poly1305::new_from_slice(&key)
        .map_err(|error| format!("crypto: data key: {error}"))?;
    let count = plain.len().div_ceil(PLAIN_CHUNK);

    let mut blob = header;
    for index in 0..count {
        let start = index * PLAIN_CHUNK;
        let end = (start + PLAIN_CHUNK).min(plain.len());
        let nonce = chunk_nonce(&base, index as u64, index + 1 == count);
        let encrypted = cipher
            .encrypt(
                XNonce::from_slice(&nonce),
                Payload {
                    msg: &plain[start..end],
                    aad: &aad,
                },
            )
            .map_err(|_| "crypto: blob authentication failed".to_string())?;
        blob.extend_from_slice(&encrypted);
    }

    Ok(blob)
}

fn blob_decode(payload: &Value, blob: &[u8]) -> Result<Vec<u8>, String> {
    let key = unhex(text(payload, "dataKeyHex")?)?;
    let account = unhex(text(payload, "accountIdHex")?)?;
    let kind = integer(payload, "kind")? as u8;
    let epoch = integer(payload, "epoch")? as u32;

    if blob.len() < BLOB_HEADER_LEN {
        return Err("blob: truncated header".to_string());
    }
    let header = &blob[..BLOB_HEADER_LEN];
    if header[..4] != BLOB_MAGIC {
        return Err("blob: bad magic".to_string());
    }
    if header[4] != BLOB_VERSION {
        return Err("blob: unsupported version".to_string());
    }
    if header[5] != kind {
        return Err("blob: unexpected blob kind".to_string());
    }
    let mut epoch_bytes = [0u8; 4];
    epoch_bytes.copy_from_slice(&header[6..10]);
    if u32::from_be_bytes(epoch_bytes) != epoch {
        return Err("blob: unexpected epoch".to_string());
    }
    let base = &header[BLOB_PREFIX_LEN..];

    let mut aad = account;
    aad.extend_from_slice(header);

    let cipher = XChaCha20Poly1305::new_from_slice(&key)
        .map_err(|error| format!("crypto: data key: {error}"))?;

    let mut body = &blob[BLOB_HEADER_LEN..];
    let mut plain = Vec::new();
    let mut index: u64 = 0;
    let mut open_chunk = |chunk: &[u8], last: bool| -> Result<(), String> {
        if chunk.len() < TAG_BYTES {
            return Err("blob: truncated chunk".to_string());
        }
        let nonce = chunk_nonce(base, index, last);
        let clear = cipher
            .decrypt(
                XNonce::from_slice(&nonce),
                Payload {
                    msg: chunk,
                    aad: &aad,
                },
            )
            .map_err(|_| "crypto: blob authentication failed".to_string())?;
        plain.extend_from_slice(&clear);
        index += 1;
        Ok(())
    };

    while body.len() > CIPHER_CHUNK {
        let (chunk, rest) = body.split_at(CIPHER_CHUNK);
        open_chunk(chunk, false)?;
        body = rest;
    }
    open_chunk(body, true)?;

    unframe(&plain)
}

fn queue_names(raw: Option<&Value>) -> Vec<String> {
    let Some(Value::String(text)) = raw else {
        return Vec::new();
    };
    match serde_json::from_str::<Value>(text) {
        Ok(Value::Array(rows)) => rows.iter().map(display).collect(),
        _ => Vec::new(),
    }
}

fn display(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        other => other.to_string(),
    }
}

fn current_queue(raw: Option<&Value>) -> Option<Map<String, Value>> {
    let Some(Value::String(text)) = raw else {
        return None;
    };
    match serde_json::from_str::<Value>(text) {
        Ok(Value::Object(map)) => Some(map),
        _ => None,
    }
}

fn current_queue_names(queue: &Map<String, Value>) -> Vec<String> {
    let mut names = Vec::new();
    if let Some(Value::String(current)) = queue.get("current") {
        names.push(current.clone());
    }
    for key in ["effective", "original"] {
        if let Some(Value::Array(rows)) = queue.get(key) {
            names.extend(rows.iter().map(display));
        }
    }
    names
}

fn remap_queue(queue: &Map<String, Value>, mapping: &Map<String, Value>) -> String {
    let remap_list = |value: Option<&Value>| -> Option<Vec<String>> {
        match value {
            Some(Value::Array(rows)) => Some(
                rows.iter()
                    .filter_map(|row| mapped_name(&display(row), mapping))
                    .collect(),
            ),
            _ => None,
        }
    };
    let mut out = queue.clone();
    if let Some(Value::String(current)) = queue.get("current") {
        out.insert(
            "current".to_string(),
            match mapped_name(current, mapping) {
                Some(name) => Value::String(name),
                None => Value::Null,
            },
        );
    }
    if let Some(list) = remap_list(queue.get("effective")) {
        out.insert("effective".to_string(), json!(list));
    }
    if let Some(list) = remap_list(queue.get("original")) {
        out.insert("original".to_string(), json!(list));
    }
    Value::Object(out).to_string()
}

/// A name the mapping does not resolve, or resolves to null, drops the record.
/// The caller always builds the mapping from `refs_collect` over the same
/// records, so a missing entry means "no local filename for this one".
fn mapped_name(name: &str, mapping: &Map<String, Value>) -> Option<String> {
    match mapping.get(name) {
        Some(Value::String(target)) => Some(target.clone()),
        _ => None,
    }
}

fn collect_song_names(records: &Value) -> HashSet<String> {
    let mut names = HashSet::new();
    for (array, field) in NAME_FIELD.iter().copied() {
        let Some(Value::Array(rows)) = records.get(array) else {
            continue;
        };
        for row in rows {
            if let Some(Value::String(name)) = row.get(field) {
                if !name.is_empty() {
                    names.insert(name.clone());
                }
            }
        }
    }

    if let Some(Value::Array(rows)) = records.get("queue_snapshots") {
        for row in rows {
            names.extend(queue_names(row.get("songs_json")));
        }
    }

    if let Some(Value::Array(rows)) = records.get("current_queue") {
        for row in rows {
            if let Some(queue) = current_queue(row.get("queue_json")) {
                names.extend(current_queue_names(&queue));
            }
        }
    }

    if let Some(Value::Array(rows)) = records.get("tombstones") {
        for row in rows {
            let entity = row.get("entity").map(display).unwrap_or_default();
            let Some(part) = tombstone_part(&entity) else {
                continue;
            };
            let key = row.get("key").map(display).unwrap_or_default();
            let parts: Vec<&str> = key.split(NAME_SEP).collect();
            if let Some(name) = parts.get(part) {
                if !name.is_empty() {
                    names.insert((*name).to_string());
                }
            }
        }
    }
    names
}

fn tombstone_part(entity: &str) -> Option<usize> {
    TOMBSTONE_NAME_PART
        .iter()
        .find(|(name, _)| *name == entity)
        .map(|(_, part)| *part)
}

fn remap_song_names(records: &Value, mapping: &Map<String, Value>) -> Value {
    let Value::Object(entries) = records else {
        return records.clone();
    };
    let mut out = Map::new();
    for (array, value) in entries {
        let Value::Array(rows) = value else {
            out.insert(array.clone(), value.clone());
            continue;
        };

        let field = NAME_FIELD
            .iter()
            .find(|(name, _)| *name == array.as_str())
            .map(|(_, field)| *field);

        if let Some(field) = field {
            let mut kept = Vec::with_capacity(rows.len());
            for row in rows {
                let Some(Value::String(name)) = row.get(field) else {
                    kept.push(row.clone());
                    continue;
                };
                match mapped_name(name, mapping) {
                    Some(target) => {
                        let mut updated = row.clone();
                        updated[field] = Value::String(target);
                        kept.push(updated);
                    }
                    // A priority name with no local match stays as-is; the group
                    // itself is still valid.
                    None if array == "merged_groups" => kept.push(row.clone()),
                    None => {}
                }
            }
            out.insert(array.clone(), Value::Array(kept));
        } else if array == "queue_snapshots" {
            let mapped: Vec<Value> = rows
                .iter()
                .map(|row| {
                    if !matches!(row.get("songs_json"), Some(Value::String(_))) {
                        return row.clone();
                    }
                    let names: Vec<String> = queue_names(row.get("songs_json"))
                        .iter()
                        .filter_map(|name| mapped_name(name, mapping))
                        .collect();
                    let mut updated = row.clone();
                    updated["songs_json"] = Value::String(json!(names).to_string());
                    updated
                })
                .collect();
            out.insert(array.clone(), Value::Array(mapped));
        } else if array == "current_queue" {
            let mapped: Vec<Value> = rows
                .iter()
                .map(|row| match current_queue(row.get("queue_json")) {
                    Some(queue) => {
                        let mut updated = row.clone();
                        updated["queue_json"] = Value::String(remap_queue(&queue, mapping));
                        updated
                    }
                    None => row.clone(),
                })
                .collect();
            out.insert(array.clone(), Value::Array(mapped));
        } else if array == "tombstones" {
            let mut kept = Vec::with_capacity(rows.len());
            for row in rows {
                let entity = row.get("entity").map(display).unwrap_or_default();
                let Some(part) = tombstone_part(&entity) else {
                    kept.push(row.clone());
                    continue;
                };
                let key = row.get("key").map(display).unwrap_or_default();
                let mut parts: Vec<String> = key.split(NAME_SEP).map(str::to_string).collect();
                if part >= parts.len() {
                    kept.push(row.clone());
                    continue;
                }
                if let Some(target) = mapped_name(&parts[part], mapping) {
                    parts[part] = target;
                    let separator = NAME_SEP.to_string();
                    let mut updated = row.clone();
                    updated["key"] = Value::String(parts.join(&separator));
                    kept.push(updated);
                }
            }
            out.insert(array.clone(), Value::Array(kept));
        } else {
            out.insert(array.clone(), value.clone());
        }
    }
    Value::Object(out)
}

fn text<'a>(payload: &'a Value, key: &str) -> Result<&'a str, String> {
    payload
        .get(key)
        .and_then(Value::as_str)
        .ok_or_else(|| format!("missing text: {key}"))
}

fn integer(payload: &Value, key: &str) -> Result<i64, String> {
    payload
        .get(key)
        .and_then(Value::as_i64)
        .ok_or_else(|| format!("missing integer: {key}"))
}

fn random(count: usize) -> Result<Vec<u8>, String> {
    let mut bytes = vec![0u8; count];
    getrandom::getrandom(&mut bytes).map_err(|error| format!("crypto: random: {error}"))?;
    Ok(bytes)
}

fn hex(bytes: &[u8]) -> String {
    let mut out = String::with_capacity(bytes.len() * 2);
    for byte in bytes {
        out.push_str(&format!("{byte:02x}"));
    }
    out
}

fn unhex(text: &str) -> Result<Vec<u8>, String> {
    if !text.len().is_multiple_of(2) {
        return Err("crypto: odd-length hex".to_string());
    }
    let mut out = Vec::with_capacity(text.len() / 2);
    let bytes = text.as_bytes();
    for chunk in bytes.chunks(2) {
        let pair = std::str::from_utf8(chunk).map_err(|_| "crypto: bad hex".to_string())?;
        out.push(u8::from_str_radix(pair, 16).map_err(|_| "crypto: bad hex".to_string())?);
    }
    Ok(out)
}
