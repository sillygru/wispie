use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum ResponseAction {
    Refresh,
    Wait,
    Raise,
}

pub fn response_action(
    status: u16,
    can_refresh: bool,
    refreshed: bool,
    retry_after: Option<i64>,
    attempt: usize,
) -> ResponseAction {
    if status == 401 && can_refresh && !refreshed {
        ResponseAction::Refresh
    } else if matches!(status, 429 | 503)
        && attempt < 2
        && retry_after.is_some_and(|seconds| (0..=30).contains(&seconds))
    {
        ResponseAction::Wait
    } else {
        ResponseAction::Raise
    }
}

pub fn chunk_end(offset: i64, size: i64, chunk: i64) -> Option<i64> {
    (offset >= 0 && offset < size && chunk > 0).then(|| offset.saturating_add(chunk).min(size))
}

pub fn upload_conflict(status: u16, received: Option<i64>, size: i64) -> Option<i64> {
    received.filter(|&offset| status == 409 && (0..=size).contains(&offset))
}

#[derive(Serialize)]
#[serde(tag = "step", rename_all = "snake_case")]
pub enum UploadStep {
    Commit,
    Send { start: i64, end: i64 },
    InvalidRange,
}

pub fn upload_step(offset: i64, size: i64, chunk: i64) -> UploadStep {
    if offset == size && size >= 0 {
        UploadStep::Commit
    } else if let Some(end) = chunk_end(offset, size, chunk) {
        UploadStep::Send { start: offset, end }
    } else {
        UploadStep::InvalidRange
    }
}

pub fn range(have: i64) -> Option<String> {
    (have > 0).then(|| format!("bytes={have}-"))
}

#[derive(Serialize)]
pub struct Download {
    pub offset: i64,
    pub total: Option<i64>,
    pub append: bool,
}

pub fn download(have: i64, status: u16, length: i64) -> Download {
    let append = status == 206;
    let offset = if append { have } else { 0 };
    Download {
        offset,
        total: (length >= 0).then(|| offset.saturating_add(length)),
        append,
    }
}

#[derive(Clone, Copy, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Endpoint {
    Info,
    Refresh,
    Prelogin,
    RegisterBegin,
    RegisterFinish,
    Login,
    Logout,
    RecoverBegin,
    RecoverFinish,
    ChangePassword,
    ReplaceRecovery,
    Account,
    DeleteAccount,
    State,
    PullDeltas,
    PushDelta,
    Snapshot,
    UploadInit,
    UploadStatus,
    UploadChunk,
    UploadCommit,
    UploadAbort,
}

#[derive(Serialize)]
pub struct Route {
    pub method: &'static str,
    pub path: String,
    pub auth: bool,
}

pub fn route(endpoint: Endpoint, id: Option<&str>) -> Result<Route, String> {
    let (method, path, auth) = match endpoint {
        Endpoint::Info => ("GET", "/info", false),
        Endpoint::Refresh => ("POST", "/auth/refresh", false),
        Endpoint::Prelogin => ("POST", "/auth/prelogin", false),
        Endpoint::RegisterBegin => ("POST", "/auth/register/begin", false),
        Endpoint::RegisterFinish => ("POST", "/auth/register/finish", false),
        Endpoint::Login => ("POST", "/auth/login", false),
        Endpoint::Logout => ("POST", "/auth/logout", true),
        Endpoint::RecoverBegin => ("POST", "/auth/recover/begin", false),
        Endpoint::RecoverFinish => ("POST", "/auth/recover/finish", true),
        Endpoint::ChangePassword => ("POST", "/account/password", true),
        Endpoint::ReplaceRecovery => ("POST", "/account/recovery-key", true),
        Endpoint::Account => ("GET", "/account", true),
        Endpoint::DeleteAccount => ("DELETE", "/account", true),
        Endpoint::State => ("GET", "/sync/state", true),
        Endpoint::PullDeltas => ("GET", "/sync/deltas", true),
        Endpoint::PushDelta => ("POST", "/sync/deltas", true),
        Endpoint::Snapshot => ("GET", "/sync/snapshot", true),
        Endpoint::UploadInit => ("POST", "/sync/uploads", true),
        Endpoint::UploadStatus => ("GET", "/sync/uploads/{id}", true),
        Endpoint::UploadChunk => ("PUT", "/sync/uploads/{id}", true),
        Endpoint::UploadCommit => ("POST", "/sync/uploads/{id}/commit", true),
        Endpoint::UploadAbort => ("DELETE", "/sync/uploads/{id}", true),
    };
    let path = if path.contains("{id}") {
        path.replace(
            "{id}",
            id.filter(|id| !id.is_empty())
                .ok_or("upload id is missing")?,
        )
    } else {
        path.to_string()
    };
    Ok(Route { method, path, auth })
}

#[derive(Serialize)]
pub struct DeltaFrame {
    pub seq: u64,
    pub start: usize,
    pub end: usize,
}

pub fn delta_frames(data: &[u8]) -> Result<Vec<DeltaFrame>, String> {
    let mut position = 0;
    let mut frames = Vec::new();
    while position < data.len() {
        let header = data
            .get(position..)
            .and_then(|tail| tail.get(..12))
            .ok_or("Truncated delta stream")?;
        let seq = u64::from_be_bytes(header[..8].try_into().expect("sequence header width"));
        let size = u32::from_be_bytes(header[8..].try_into().expect("size header width")) as usize;
        let start = position + header.len();
        let end = start
            .checked_add(size)
            .filter(|&end| end <= data.len())
            .ok_or("Truncated delta frame")?;
        frames.push(DeltaFrame { seq, start, end });
        position = end;
    }
    Ok(frames)
}

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
enum Request {
    Route {
        endpoint: Endpoint,
        id: Option<String>,
    },
    DeltaFrames,
    Error {
        status: u16,
        #[serde(default)]
        can_refresh: bool,
        #[serde(default)]
        refreshed: bool,
        retry_after: Option<i64>,
        #[serde(default)]
        attempt: usize,
    },
    Chunk {
        offset: i64,
        size: i64,
        chunk: i64,
    },
    UploadStep {
        offset: i64,
        size: i64,
        chunk: i64,
    },
    UploadConflict {
        status: u16,
        received: Option<i64>,
        size: i64,
    },
    Range {
        have: i64,
    },
    Download {
        have: i64,
        status: u16,
        length: i64,
    },
}

pub(crate) fn run(payload: Value, bytes: Option<&[u8]>) -> Result<Value, String> {
    let request: Request = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    let result = match request {
        Request::Route { endpoint, id } => json!(route(endpoint, id.as_deref())?),
        Request::DeltaFrames => json!(delta_frames(bytes.ok_or("delta stream needs bytes")?)?),
        Request::Error {
            status,
            can_refresh,
            refreshed,
            retry_after,
            attempt,
        } => json!(response_action(
            status,
            can_refresh,
            refreshed,
            retry_after,
            attempt
        )),
        Request::Chunk {
            offset,
            size,
            chunk,
        } => json!(chunk_end(offset, size, chunk)),
        Request::UploadStep {
            offset,
            size,
            chunk,
        } => json!(upload_step(offset, size, chunk)),
        Request::UploadConflict {
            status,
            received,
            size,
        } => json!(upload_conflict(status, received, size)),
        Request::Range { have } => json!(range(have)),
        Request::Download {
            have,
            status,
            length,
        } => json!(download(have, status, length)),
    };
    Ok(json!({ "result": result }))
}
