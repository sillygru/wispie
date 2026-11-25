use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

pub const PUSH_ATTEMPTS: usize = 3;

#[derive(Clone, Copy, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Mode {
    Sync,
    Overwrite,
    Merge,
    NewDevice,
}

#[derive(Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Step {
    NotReady,
    EpochPaused,
    ReadCloud,
    Guard,
    DetectSettings,
    PullCategories,
    Pull,
    ApplyManualQueue,
    Push,
    RefreshAfterPush,
    Compact,
    RecordHighest,
    StampLastSync,
    CollectTombstones,
    PrepareReset,
    UploadReset,
    MarkPushed,
    ResetCheckpoint,
    AdoptIfNeeded,
    MarkInitialDone,
    Sync,
    Wipe,
    PullBulk,
    RefreshSettings,
}

pub fn steps(mode: Mode, ready: bool, paused: bool) -> &'static [Step] {
    use Step::*;
    match mode {
        Mode::Sync if !ready => &[NotReady],
        Mode::Sync if paused => &[EpochPaused],
        Mode::Sync => &[
            ReadCloud,
            Guard,
            DetectSettings,
            PullCategories,
            Pull,
            ApplyManualQueue,
            Push,
            RefreshAfterPush,
            Compact,
            RecordHighest,
            StampLastSync,
            CollectTombstones,
        ],
        Mode::Overwrite => &[
            ReadCloud,
            PrepareReset,
            DetectSettings,
            UploadReset,
            MarkPushed,
            ResetCheckpoint,
            MarkInitialDone,
            StampLastSync,
        ],
        Mode::Merge => &[ReadCloud, AdoptIfNeeded, MarkInitialDone, Sync],
        Mode::NewDevice => &[
            ReadCloud,
            Wipe,
            ResetCheckpoint,
            PullBulk,
            RefreshSettings,
            MarkInitialDone,
            ReadCloud,
            RecordHighest,
            StampLastSync,
        ],
    }
}

pub fn reset_checkpoint(mode: Mode, cloud_epoch: i64) -> Vec<(&'static str, Value)> {
    let mut writes = Vec::new();
    let overwritten = matches!(mode, Mode::Overwrite);
    for (key, value) in [
        ("sync_epoch", json!(cloud_epoch)),
        ("sync_cursor_seq", json!(0)),
        (
            "sync_snapshot_applied",
            if overwritten {
                json!(true)
            } else {
                Value::Null
            },
        ),
        ("sync_highest_epoch", json!(cloud_epoch)),
        ("sync_highest_head", json!(0)),
        ("sync_epoch_changed", Value::Null),
    ] {
        writes.push((key, value));
    }
    if matches!(mode, Mode::Overwrite | Mode::NewDevice) {
        writes.push(("sync_pending_category_pull", Value::Null));
    }
    if matches!(mode, Mode::NewDevice) {
        writes.push(("sync_settings_seen", Value::Null));
    }
    writes
}

#[derive(Clone, Copy, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Operation {
    Pull,
    Push,
}

#[derive(Clone, Copy, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum Retry {
    RefreshSnapshot,
    RefreshHead,
    PauseEpoch,
    Raise,
}

pub fn retry(operation: Operation, status: u16, code: &str, attempt: usize) -> Retry {
    match (operation, status, code) {
        (Operation::Pull, 410, _) if attempt == 0 => Retry::RefreshSnapshot,
        (Operation::Push, 412, "epoch_changed") => Retry::PauseEpoch,
        (Operation::Push, 409, "head_moved") if attempt < PUSH_ATTEMPTS => Retry::RefreshHead,
        _ => Retry::Raise,
    }
}

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
enum Request {
    Plan {
        mode: Mode,
        ready: bool,
        paused_epoch: Option<i64>,
    },
    ResetCheckpoint {
        mode: Mode,
        cloud_epoch: i64,
    },
    Retry {
        operation: Operation,
        status: u16,
        code: String,
        attempt: usize,
    },
    ApplyQueue {
        manual: bool,
        prefer_cloud: bool,
        enabled: bool,
    },
    Adopt {
        cloud_epoch: i64,
        local_epoch: i64,
        ready: bool,
    },
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    let request: Request = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    match request {
        Request::Plan {
            mode,
            ready,
            paused_epoch,
        } => Ok(json!({
            "steps": steps(mode, ready, paused_epoch.is_some()),
            "push_attempts": PUSH_ATTEMPTS,
        })),
        Request::ResetCheckpoint { mode, cloud_epoch } => Ok(json!({
            "writes": reset_checkpoint(mode, cloud_epoch)
        })),
        Request::Retry {
            operation,
            status,
            code,
            attempt,
        } => Ok(json!({
            "action": retry(operation, status, &code, attempt),
        })),
        Request::ApplyQueue {
            manual,
            prefer_cloud,
            enabled,
        } => Ok(json!({"apply": manual && prefer_cloud && enabled})),
        Request::Adopt {
            cloud_epoch,
            local_epoch,
            ready,
        } => Ok(json!({"adopt": cloud_epoch != local_epoch || !ready})),
    }
}
