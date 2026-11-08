//! Event plumbing across the C ABI: JSON payloads, one kind per shape.
//! Add fields freely; consumers ignore keys they do not know.

use crate::model::{FolderFact, SongJson};
use serde_json::json;
use std::collections::HashMap;
use std::ffi::{c_void, CString};

pub const EVENT_ITEMS: i32 = 0;
pub const EVENT_PROGRESS: i32 = 1;
pub const EVENT_DONE: i32 = 2;
pub const EVENT_ERROR: i32 = 3;

pub type RawCallback = extern "C" fn(*mut c_void, i32, *const u8, usize);

pub struct Emitter {
    callback: RawCallback,
    user_data: *mut c_void,
}

pub struct Formats {
    pub supported: Vec<&'static str>,
    pub video: Vec<&'static str>,
}

pub enum Emit {
    Songs(Vec<SongJson>),
    Covers(HashMap<String, String>),
    Facts(Vec<FolderFact>),
    Paths(Vec<String>),
    Compacted(HashMap<String, String>),
    Json(serde_json::Value),
    Progress {
        done: u64,
        total: u64,
    },
    Done {
        unreadable: u64,
        unreachable: Vec<String>,
        scanned: u64,
        cancelled: bool,
        formats: Option<Formats>,
    },
    Error {
        message: String,
    },
}

impl Emitter {
    pub fn new(callback: RawCallback, user_data: *mut c_void) -> Self {
        Self {
            callback,
            user_data,
        }
    }

    /// Sends one event; the payload is only valid for the duration of the call.
    pub fn emit(&self, event: Emit) {
        let (kind, payload) = match event {
            Emit::Songs(songs) => (EVENT_ITEMS, json!({ "songs": songs })),
            Emit::Covers(covers) => (EVENT_ITEMS, json!({ "covers": covers })),
            Emit::Facts(facts) => (EVENT_ITEMS, json!({ "facts": facts })),
            Emit::Paths(paths) => (EVENT_ITEMS, json!({ "paths": paths })),
            Emit::Compacted(compacted) => (EVENT_ITEMS, json!({ "compacted": compacted })),
            Emit::Json(value) => (EVENT_ITEMS, value),
            Emit::Progress { done, total } => {
                (EVENT_PROGRESS, json!({ "done": done, "total": total }))
            }
            Emit::Done {
                unreadable,
                unreachable,
                scanned,
                cancelled,
                formats,
            } => (
                EVENT_DONE,
                json!({
                    "unreadable": unreadable,
                    "unreachable": unreachable,
                    "scanned": scanned,
                    "cancelled": cancelled,
                    "formats": formats.map(|f| json!({
                        "supported": f.supported,
                        "video": f.video,
                    })),
                }),
            ),
            Emit::Error { message } => (EVENT_ERROR, json!({ "message": message })),
        };

        let Ok(encoded) = serde_json::to_string(&payload) else {
            return;
        };
        let Ok(cstring) = CString::new(encoded) else {
            return;
        };
        let bytes = cstring.as_bytes();

        // A Dart exception must never unwind back into Rust.
        let _ = std::panic::catch_unwind(std::panic::AssertUnwindSafe(|| {
            (self.callback)(self.user_data, kind, bytes.as_ptr(), bytes.len());
        }));
    }
}
