use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use serde_json::{json, Map, Value};

pub const SYNCABLE_SETTINGS_KEYS: &[&str] = &[
    "theme_mode",
    "use_cover_color",
    "apply_cover_color_to_all",
    "sort_order",
    "visualizer_enabled",
    "visualizer_mode",
    "show_song_duration",
    "animated_sound_wave_enabled",
    "show_waveform",
    "fade_out_duration",
    "fade_in_duration",
    "delay_duration",
    "play_fade_duration",
    "pause_fade_duration",
    "keep_screen_awake_on_lyrics",
    "desktop_sidebar_enabled",
    "cover_sizing_mode",
    "beat_reactive_cover_enabled",
    "beat_reactive_particles_enabled",
    "cover_motion_intensity",
    "particle_motion_intensity",
    "cover_motion_custom_intensity",
    "particle_motion_custom_intensity",
    "player_motion_latency_ms",
    "spin_artwork_while_playing",
    "show_quick_picks",
    "show_recent_queues",
    "show_for_you",
    "lyrics_target_language",
    "lyrics_auto_translate",
    "lyrics_translation_mode",
    "auto_hide_bottom_bar_on_scroll",
    "auto_pause_on_volume_zero",
    "auto_resume_on_volume_restore",
];

#[derive(Clone, Copy, Deserialize, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum SyncPayloadKind {
    Delta,
    Snapshot,
}

#[derive(Deserialize)]
pub struct SyncRecord {
    pub entity: String,
    pub record: Map<String, Value>,
}

#[derive(Deserialize)]
pub struct SyncPayloadRequest {
    pub kind: SyncPayloadKind,
    pub max_bytes: Option<usize>,
    pub rows: Vec<SyncRecord>,
    pub device_id: String,
    pub device_name: String,
    pub categories: Vec<String>,
}

#[derive(Serialize)]
pub struct SyncPayload {
    pub v: u32,
    pub kind: SyncPayloadKind,
    pub device_id: String,
    pub device_name: String,
    pub max_hlc: i64,
    pub categories: Vec<String>,
    pub records: BTreeMap<String, Vec<Map<String, Value>>>,
}

#[derive(Serialize)]
pub struct SyncPayloadBatch {
    pub count: usize,
    pub payload: SyncPayload,
}

pub fn assemble(mut request: SyncPayloadRequest) -> Result<Vec<SyncPayloadBatch>, String> {
    request.categories.sort_unstable();
    let mut batches = Vec::new();
    let mut records = BTreeMap::<_, Vec<_>>::new();
    let mut count = 0;
    let mut size = 0usize;
    let mut max_hlc = 0;

    let budget = match request.kind {
        SyncPayloadKind::Delta => Some(request.max_bytes.unwrap_or(3500 * 1024)),
        SyncPayloadKind::Snapshot => None,
    };

    let batch = |records, count, max_hlc| SyncPayloadBatch {
        count,
        payload: SyncPayload {
            v: 1,
            kind: request.kind,
            device_id: request.device_id.clone(),
            device_name: request.device_name.clone(),
            max_hlc,
            categories: request.categories.clone(),
            records,
        },
    };

    for row in request.rows {
        if let Some(budget) = budget {
            // Keep the existing budget unit so older clients split the same payload.
            let encoded = serde_json::to_string(&row.record).map_err(|error| error.to_string())?;
            let record_size = encoded.encode_utf16().count() + 1;
            if count != 0 && size.saturating_add(record_size) > budget {
                batches.push(batch(std::mem::take(&mut records), count, max_hlc));
                size = 0;
                count = 0;
                max_hlc = 0;
            }
            size += record_size;
        }
        max_hlc = max_hlc.max(row.record.get("hlc").and_then(Value::as_i64).unwrap_or(0));
        records.entry(row.entity).or_default().push(row.record);
        count += 1;
    }

    if count != 0 || matches!(request.kind, SyncPayloadKind::Snapshot) {
        batches.push(batch(records, count, max_hlc));
    }
    Ok(batches)
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    let request = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    Ok(json!({ "batches": assemble(request)? }))
}
