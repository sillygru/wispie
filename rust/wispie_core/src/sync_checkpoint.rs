use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

const COMPACTION_INTERVAL_MS: i64 = 24 * 60 * 60 * 1000;

#[derive(Default, Deserialize)]
pub struct LocalCheckpoint {
    pub epoch: i64,
    pub cursor: i64,
    pub highest_epoch: i64,
    pub highest_head: i64,
    #[serde(default)]
    pub snapshot_applied: bool,
    #[serde(default)]
    pub last_compaction_ms: i64,
}

#[derive(Deserialize)]
pub struct CloudCheckpoint {
    pub epoch: i64,
    pub head: i64,
    pub snapshot_base: Option<i64>,
    #[serde(default)]
    pub compaction_recommended: bool,
}

#[derive(Serialize, PartialEq, Eq)]
#[serde(rename_all = "snake_case")]
pub enum CheckpointGuard {
    Ready,
    EpochChanged,
    Rollback,
}

impl LocalCheckpoint {
    pub fn guard(&self, cloud: &CloudCheckpoint) -> CheckpointGuard {
        if cloud.epoch != self.epoch {
            CheckpointGuard::EpochChanged
        } else if (cloud.epoch, cloud.head) < (self.highest_epoch, self.highest_head) {
            CheckpointGuard::Rollback
        } else {
            CheckpointGuard::Ready
        }
    }

    pub fn highest_update(&self, cloud: &CloudCheckpoint) -> Option<(i64, i64)> {
        let observed = (cloud.epoch, cloud.head.max(self.cursor));
        (observed > (self.highest_epoch, self.highest_head)).then_some(observed)
    }

    pub fn needs_snapshot(&self, cloud: &CloudCheckpoint) -> bool {
        cloud
            .snapshot_base
            .is_some_and(|base| self.cursor < base || !self.snapshot_applied)
    }

    pub fn should_compact(
        &self,
        cloud: &CloudCheckpoint,
        all_categories: bool,
        now_ms: i64,
    ) -> bool {
        // Replacing the snapshot with a subset would erase the other categories.
        cloud.compaction_recommended
            && all_categories
            && now_ms.saturating_sub(self.last_compaction_ms) >= COMPACTION_INTERVAL_MS
    }
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    #[derive(Deserialize)]
    struct Request {
        local: LocalCheckpoint,
        cloud: CloudCheckpoint,
        now_ms: i64,
        all_categories: bool,
    }
    let Request {
        local,
        cloud,
        now_ms,
        all_categories,
    } = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    let highest = local.highest_update(&cloud);
    Ok(json!({
        "guard": local.guard(&cloud),
        "highest_epoch": highest.map(|(epoch, _)| epoch),
        "highest_head": highest.map(|(_, head)| head),
        "use_snapshot": local.needs_snapshot(&cloud),
        "compact": local.should_compact(&cloud, all_categories, now_ms),
    }))
}
