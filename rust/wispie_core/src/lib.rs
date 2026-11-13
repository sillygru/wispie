//! C ABI for the Wispie native core.
//!
//! One entry point: `wispie_core_run` takes a JSON request and streams JSON
//! events. Requests and events are additive-only, so an older Dart binding can
//! talk to a newer library and simply ignore what it does not know.

mod affinity;
mod beat;
mod bulk_rename;
mod cover;
mod emitter;
mod formats;
mod hlc;
mod image_sig;
mod insights;
mod lrclib_match;
mod match_plan;
mod merge_finder;
mod meta;
mod model;
mod palette;
mod palette_jpeg;
mod prosody;
pub(crate) mod queue_ops;
mod remembered_order;
mod replacement;
mod scan;
mod search;
mod settings_search;
mod shuffle;
mod tasks;
mod waveform;

use emitter::{Emit, Emitter, RawCallback};
use model::{CompactRequest, FactsRequest, ListRequest, ProsodyRequest, ScanRequest, SongsRequest};
use std::ffi::{c_char, c_void, CStr};
use std::panic::AssertUnwindSafe;
use std::sync::atomic::{AtomicBool, Ordering};

/// Bumped only when an existing request field or event key changes meaning.
pub const ABI_VERSION: u32 = 5;

pub static CANCEL: AtomicBool = AtomicBool::new(false);

static VERSION: &[u8] = b"0.1.0\0";

#[no_mangle]
pub extern "C" fn wispie_core_abi_version() -> u32 {
    ABI_VERSION
}

#[no_mangle]
pub extern "C" fn wispie_core_hlc_observe(remote: i64) {
    hlc::observe(remote);
}

#[no_mangle]
pub extern "C" fn wispie_core_hlc_set(last: i64) {
    hlc::set(last);
}

#[no_mangle]
pub extern "C" fn wispie_core_hlc_next(wall_millis: i64) -> i64 {
    hlc::next(wall_millis)
}

#[no_mangle]
pub extern "C" fn wispie_core_hlc_now() -> i64 {
    hlc::now()
}

#[no_mangle]
pub extern "C" fn wispie_core_version() -> *const c_char {
    VERSION.as_ptr() as *const c_char
}

#[no_mangle]
pub extern "C" fn wispie_core_cancel() {
    CANCEL.store(true, Ordering::SeqCst);
}

#[no_mangle]
pub extern "C" fn wispie_core_alloc(length: usize) -> *mut u8 {
    if length == 0 {
        return std::ptr::null_mut();
    }
    Box::into_raw(vec![0u8; length].into_boxed_slice()) as *mut u8
}

/// # Safety
/// `pointer` must come from `wispie_core_alloc` with the same `length`.
#[no_mangle]
pub unsafe extern "C" fn wispie_core_free(pointer: *mut u8, length: usize) {
    if pointer.is_null() || length == 0 {
        return;
    }
    let slice = std::ptr::slice_from_raw_parts_mut(pointer, length);
    drop(Box::from_raw(slice));
}

/// Runs one request to completion on the calling thread, emitting events as it goes.
///
/// # Safety
/// `request` must be a NUL-terminated UTF-8 string, and `callback` must stay
/// valid for the duration of the call.
#[no_mangle]
pub unsafe extern "C" fn wispie_core_run(
    request: *const c_char,
    callback: RawCallback,
    user_data: *mut c_void,
) -> i32 {
    if request.is_null() {
        return 1;
    }
    let decoded = match CStr::from_ptr(request).to_str() {
        Ok(value) => value,
        Err(_) => return 1,
    };
    let payload: serde_json::Value = match serde_json::from_str(decoded) {
        Ok(value) => value,
        Err(_) => return 2,
    };

    run_payload(payload, None, callback, user_data)
}

/// Runs a JSON request with a binary payload.
///
/// # Safety
/// `request` must be NUL-terminated UTF-8, `bytes` must reference `length`
/// readable bytes, and `callback` must remain valid for the call duration.
#[no_mangle]
pub unsafe extern "C" fn wispie_core_run_bytes(
    request: *const c_char,
    bytes: *const u8,
    length: usize,
    callback: RawCallback,
    user_data: *mut c_void,
) -> i32 {
    if request.is_null() || (bytes.is_null() && length != 0) {
        return 1;
    }
    let decoded = match CStr::from_ptr(request).to_str() {
        Ok(value) => value,
        Err(_) => return 1,
    };
    let payload: serde_json::Value = match serde_json::from_str(decoded) {
        Ok(value) => value,
        Err(_) => return 2,
    };
    let data = if length == 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(bytes, length)
    };
    run_payload(payload, Some(data), callback, user_data)
}

fn run_payload(
    payload: serde_json::Value,
    bytes: Option<&[u8]>,
    callback: RawCallback,
    user_data: *mut c_void,
) -> i32 {
    CANCEL.store(false, Ordering::SeqCst);
    let emitter = Emitter::new(callback, user_data);

    match std::panic::catch_unwind(AssertUnwindSafe(|| dispatch(payload, bytes, &emitter))) {
        Ok(Ok(())) => 0,
        Ok(Err(message)) => {
            emitter.emit(Emit::Error { message });
            2
        }
        Err(_) => {
            emitter.emit(Emit::Error {
                message: "native core panicked".to_string(),
            });
            3
        }
    }
}

fn dispatch(
    payload: serde_json::Value,
    bytes: Option<&[u8]>,
    emitter: &Emitter,
) -> Result<(), String> {
    let command = payload
        .get("command")
        .and_then(|value| value.as_str())
        .unwrap_or("")
        .to_string();

    match command.as_str() {
        "scan" => scan::run(parse(payload)?, emitter),
        "enrich" => tasks::enrich(parse(payload)?, emitter),
        "extract_covers" => tasks::extract_covers(parse(payload)?, emitter),
        "rebuild_covers" => tasks::rebuild_covers(parse(payload)?, emitter),
        "read_facts" => tasks::read_facts(parse(payload)?, emitter),
        "read_song" => tasks::read_song(parse(payload)?, emitter),
        "list_media" => tasks::list_media(parse(payload)?, emitter),
        "compact_covers" => tasks::compact_covers(parse(payload)?, emitter),
        "prosody" => prosody::run(parse::<ProsodyRequest>(payload)?.lines, emitter),
        "rank_search" => search::rank(parse(payload)?, emitter),
        "search_prepare" => search::prepare(parse(payload)?, emitter),
        "fuzzy_search" => search::fuzzy(parse(payload)?, emitter),
        "beat_analyze" => beat::run_file(
            payload
                .get("path")
                .and_then(|value| value.as_str())
                .unwrap_or(""),
            payload
                .get("maxBytes")
                .and_then(|value| value.as_u64())
                .map(|v| v as usize),
            emitter,
        ),
        "waveform" => waveform::run(
            bytes.ok_or_else(|| "waveform requires a binary payload".to_string())?,
            payload
                .get("targetSamples")
                .and_then(|v| v.as_u64())
                .unwrap_or(2000) as usize,
            payload
                .get("expectedBytes")
                .and_then(|v| v.as_u64())
                .unwrap_or(0) as usize,
        )
        .map(|result| emitter.emit(Emit::Json(result))),
        "affinity" => affinity::run(
            &payload,
            bytes.ok_or_else(|| "affinity requires a binary payload".to_string())?,
        )
        .map(|result| emitter.emit(Emit::Json(result))),
        "shuffle_scores" => {
            emitter.emit(Emit::Json(shuffle::score_candidates(&payload)));
            Ok(())
        }
        "shuffle_select" => {
            emitter.emit(Emit::Json(shuffle::select_seed(&payload)));
            Ok(())
        }
        "shuffle_fallback_weights" => {
            emitter.emit(Emit::Json(shuffle::fallback_weights(&payload)));
            Ok(())
        }
        "shuffle_order" => {
            emitter.emit(Emit::Json(shuffle::order_queue(&payload)));
            Ok(())
        }
        "smart_weights" => {
            emitter.emit(Emit::Json(shuffle::smart_weights(&payload)));
            Ok(())
        }
        "smart_spacing" => {
            emitter.emit(Emit::Json(shuffle::smart_spacing(&payload)));
            Ok(())
        }
        "smart_diversified_top" => {
            emitter.emit(Emit::Json(shuffle::diversified_top(&payload)));
            Ok(())
        }
        "palette" => palette::run(
            payload
                .get("path")
                .and_then(|value| value.as_str())
                .unwrap_or(""),
        )
        .map(|result| emitter.emit(Emit::Json(result))),
        "match_plan" => match_plan::run(payload).map(|result| emitter.emit(Emit::Json(result))),
        "bulk_rename_plan" => bulk_rename::run(payload, emitter),
        "merge_candidates" => {
            merge_finder::run(payload).map(|result| emitter.emit(Emit::Json(result)))
        }
        "replacement_check" => {
            emitter.emit(Emit::Json(replacement::check(&payload)));
            Ok(())
        }
        "replacement_destination" => {
            emitter.emit(Emit::Json(serde_json::json!({
                "destinationPath": replacement::destination(
                    payload
                        .get("originalUrl")
                        .and_then(|value| value.as_str())
                        .unwrap_or(""),
                    payload
                        .get("sourcePath")
                        .and_then(|value| value.as_str())
                        .unwrap_or(""),
                )
            })));
            Ok(())
        }
        "replacement_filename" => {
            emitter.emit(Emit::Json(serde_json::json!({
                "filename": replacement::filename(
                    payload
                        .get("sourcePath")
                        .and_then(|value| value.as_str())
                        .unwrap_or(""),
                )
            })));
            Ok(())
        }
        "remembered_order" => {
            emitter.emit(Emit::Json(remembered_order::reorder(&payload)));
            Ok(())
        }
        "session_top_order_update" => {
            emitter.emit(Emit::Json(queue_ops::update_top_order(&payload)));
            Ok(())
        }
        "session_top_order_prune" => {
            emitter.emit(Emit::Json(queue_ops::prune_top_order(&payload)));
            Ok(())
        }
        "queue_plan_reorder" => {
            emitter.emit(Emit::Json(queue_ops::plan_reorder(&payload)));
            Ok(())
        }
        "queue_plan_jump" => {
            emitter.emit(Emit::Json(queue_ops::plan_jump(&payload)));
            Ok(())
        }
        "queue_plan_move_top" => {
            emitter.emit(Emit::Json(queue_ops::plan_move_upcoming_to_top(&payload)));
            Ok(())
        }
        "queue_plan_play_next" => {
            emitter.emit(Emit::Json(queue_ops::plan_play_next(&payload)));
            Ok(())
        }
        "queue_apply_plan" => {
            emitter.emit(Emit::Json(queue_ops::apply_plan(&payload)));
            Ok(())
        }
        "queue_find" => {
            emitter.emit(Emit::Json(queue_ops::find_in_queue(&payload)));
            Ok(())
        }
        "queue_original_order" => {
            emitter.emit(Emit::Json(queue_ops::original_order(&payload)));
            Ok(())
        }
        "settings_search" => {
            emitter.emit(Emit::Json(settings_search::search(&payload)));
            Ok(())
        }
        "lrclib_rank" => {
            emitter.emit(Emit::Json(lrclib_match::rank(&payload)));
            Ok(())
        }
        "lrclib_score" => {
            emitter.emit(Emit::Json(lrclib_match::score_one(&payload)));
            Ok(())
        }
        "queue_reconcile_sequence" => {
            emitter.emit(Emit::Json(queue_ops::reconcile_sequence(&payload)));
            Ok(())
        }
        "insights" => insights::run(
            payload,
            bytes.ok_or_else(|| "insights requires a binary payload".to_string())?,
        )
        .map(|result| emitter.emit(Emit::Json(result))),
        "formats" => {
            emitter.emit(Emit::Done {
                unreadable: 0,
                unreachable: Vec::new(),
                scanned: 0,
                cancelled: false,
                formats: Some(emitter::Formats {
                    supported: formats::SUPPORTED.to_vec(),
                    video: formats::VIDEO.to_vec(),
                }),
            });
            Ok(())
        }
        other => Err(format!("unknown command: {other}")),
    }
}

fn parse<T: serde::de::DeserializeOwned>(payload: serde_json::Value) -> Result<T, String> {
    serde_json::from_value(payload).map_err(|error| error.to_string())
}

// Keeps the request types referenced even when a command is gated later.
const _: fn() = || {
    fn assert_deserialize<T: serde::de::DeserializeOwned>() {}
    assert_deserialize::<ScanRequest>();
    assert_deserialize::<SongsRequest>();
    assert_deserialize::<FactsRequest>();
    assert_deserialize::<ListRequest>();
    assert_deserialize::<CompactRequest>();
};
