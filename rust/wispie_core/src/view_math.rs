//! Frame math for the player's beat-reactive surfaces.
//!
//! These helpers run once per rendered frame, so they cross the ABI as
//! primitives over caller-owned buffers rather than as JSON: a decode/encode
//! round trip would cost more than the arithmetic it wraps.

pub const BAR_COUNT: usize = 4;
pub const SPECTRUM_FLOOR: f64 = 0.05;

const BAND_COUNT: usize = 4;
const BAND_FPS: f64 = 30.0;
const ATTACK_TAU: f64 = 0.010;
const RELEASE_TAU: f64 = 0.055;
const GAMMA: f64 = 1.15;
const BEAT_WEIGHTS: [f64; BAR_COUNT] = [0.18, 0.09, 0.0, 0.0];
const PUNCH_ATTACK_MS: f64 = 18.0;
const PUNCH_DECAY_FRACTION: f64 = 0.30;
const PUNCH_MIN_DECAY_MS: f64 = 70.0;
const PUNCH_MAX_DECAY_MS: f64 = 180.0;
const BREATH_DEPTH: f64 = 0.03;
const BREATH_HZ: f64 = 0.21;

const SNAP_THRESHOLD_MS: f64 = 250.0;
const EASE_FACTOR: f64 = 0.15;

const VIDEO_TOLERANCE_MS: f64 = 250.0;
const VIDEO_JUMP_MS: f64 = 1500.0;
const VIDEO_COOLDOWN_MS: f64 = 5000.0;

pub fn advance_with_tau(level: f64, target: f64, dt_seconds: f64, tau: f64) -> f64 {
    if dt_seconds <= 0.0 {
        return level;
    }
    let k = 1.0 - (-dt_seconds / tau).exp();
    level + (target - level) * k
}

pub fn tau_for(level: f64, target: f64) -> f64 {
    if target > level {
        ATTACK_TAU
    } else {
        RELEASE_TAU
    }
}

pub fn shape(raw: f64) -> f64 {
    let clamped = if raw.is_nan() {
        0.0
    } else {
        raw.clamp(0.0, 1.0)
    };
    SPECTRUM_FLOOR + (1.0 - SPECTRUM_FLOOR) * clamped.powf(GAMMA)
}

fn peak_scale(decay_ms: f64) -> f64 {
    let peak_time = PUNCH_ATTACK_MS * (1.0 + decay_ms / PUNCH_ATTACK_MS).ln();
    let peak = (1.0 - (-peak_time / PUNCH_ATTACK_MS).exp()) * (-peak_time / decay_ms).exp();
    if peak <= 0.0 {
        1.0
    } else {
        1.0 / peak
    }
}

pub fn punch(since_beat_ms: f64, period_ms: f64) -> f64 {
    if since_beat_ms < 0.0 {
        return 0.0;
    }
    let decay_ms = (period_ms * PUNCH_DECAY_FRACTION).clamp(PUNCH_MIN_DECAY_MS, PUNCH_MAX_DECAY_MS);
    // Past a few decay constants the punch is invisible; two exponentials
    // would only add zero.
    if since_beat_ms > decay_ms * 5.0 {
        return 0.0;
    }
    let attack = 1.0 - (-since_beat_ms / PUNCH_ATTACK_MS).exp();
    let decay = (-since_beat_ms / decay_ms).exp();
    attack * decay * peak_scale(decay_ms)
}

pub fn breath(bar: usize, elapsed_seconds: f64) -> f64 {
    let phase = 2.0 * std::f64::consts::PI * (BREATH_HZ * elapsed_seconds + bar as f64 * 0.37);
    1.0 + BREATH_DEPTH * phase.sin()
}

fn band_at(bands: &[u8], band: usize, position_ms: f64) -> f64 {
    let frame_count = bands.len() / BAND_COUNT;
    if frame_count == 0 {
        return 0.0;
    }
    let exact = position_ms / 1000.0 * BAND_FPS;
    if !exact.is_finite() {
        return 0.0;
    }
    if exact <= 0.0 {
        return bands[band] as f64 / 255.0;
    }
    let lower = exact.floor() as usize;
    if lower >= frame_count - 1 {
        let last = (frame_count - 1) * BAND_COUNT + band;
        return bands[last] as f64 / 255.0;
    }
    let a = bands[lower * BAND_COUNT + band] as f64 / 255.0;
    let b = bands[(lower + 1) * BAND_COUNT + band] as f64 / 255.0;
    a + (b - a) * (exact - lower as f64)
}

/// Index of the last beat at or before `position_ms`, or -1 before the first.
fn beat_index_at(beats: &[i32], position_ms: f64) -> i32 {
    if beats.is_empty() || position_ms < beats[0] as f64 {
        return -1;
    }
    let mut low = 0usize;
    let mut high = beats.len() - 1;
    while low < high {
        let mid = (low + high + 1) >> 1;
        if beats[mid] as f64 <= position_ms {
            low = mid;
        } else {
            high = mid - 1;
        }
    }
    low as i32
}

fn beat_period_ms(beats: &[i32], bpm: f64, index: i32) -> f64 {
    if beats.len() < 2 {
        return if bpm > 0.0 { 60000.0 / bpm } else { 500.0 };
    }
    let last = beats.len() - 2;
    let i = (index.max(0) as usize).min(last);
    (beats[i + 1] - beats[i]) as f64
}

/// Bar targets for `position_ms`, or false when the map carries no band data.
pub fn targets(
    bands: &[u8],
    beats: &[i32],
    strengths: &[f32],
    bpm: f64,
    position_ms: f64,
    out: &mut [f64; BAR_COUNT],
) -> bool {
    if bands.len() / BAND_COUNT == 0 {
        return false;
    }

    for (index, slot) in out.iter_mut().enumerate() {
        *slot = shape(band_at(bands, index, position_ms));
    }

    if beats.is_empty() || strengths.len() < beats.len() {
        return true;
    }

    let index = beat_index_at(beats, position_ms.round());
    if index < 0 {
        return true;
    }

    let period = beat_period_ms(beats, bpm, index);
    let hit = punch(position_ms - beats[index as usize] as f64, period)
        * strengths[index as usize] as f64;
    if hit <= 0.0 {
        return true;
    }

    for (bar, slot) in out.iter_mut().enumerate() {
        let weight = BEAT_WEIGHTS[bar];
        if weight == 0.0 {
            continue;
        }
        // Added into the headroom above the target, so a bar already near full
        // cannot clip the beat away entirely.
        *slot += (1.0 - *slot) * hit * weight;
    }
    true
}

/// Smooths the bars toward their targets for one frame.
///
/// Mirrors the caller's blend of idle targets, synced bands and the pause
/// fade, so the whole per-frame loop stays in one place.
///
/// # Safety
/// `levels`, `synced` and `idle` must each reference `BAR_COUNT` readable
/// doubles; `levels` is written in place.
#[no_mangle]
pub unsafe extern "C" fn wispie_spectrum_frame(
    levels: *mut f64,
    synced: *const f64,
    idle: *const f64,
    elapsed_seconds: f64,
    dt_seconds: f64,
    grid_blend: f64,
    pause_blend: f64,
    idle_tau: f64,
) {
    if levels.is_null() || synced.is_null() || idle.is_null() {
        return;
    }
    let levels = std::slice::from_raw_parts_mut(levels, BAR_COUNT);
    let synced = std::slice::from_raw_parts(synced, BAR_COUNT);
    let idle = std::slice::from_raw_parts(idle, BAR_COUNT);

    for (bar, level) in levels.iter_mut().enumerate() {
        let mut target = idle[bar];
        if grid_blend > 0.0 {
            let band = synced[bar] * breath(bar, elapsed_seconds);
            target += (band - target) * grid_blend;
        }
        target += (SPECTRUM_FLOOR - target) * pause_blend;
        // Cross-fade the response along with the targets: idle walks with one
        // time constant, synced bars snap up and glide down.
        let asymmetric = tau_for(*level, target);
        let tau = if grid_blend <= 0.0 {
            idle_tau
        } else {
            idle_tau + (asymmetric - idle_tau) * grid_blend
        };
        *level = advance_with_tau(*level, target, dt_seconds, tau).clamp(0.0, 1.0);
    }
}

/// Bar targets for `position_ms`, written into `out`.
///
/// Returns 1 when the map had usable band data, 0 when the caller should keep
/// its idle animation.
///
/// # Safety
/// `bands` must reference `band_len` readable bytes, `beats` `beat_count`
/// readable i32s, `strengths` the same count of f32s, and `out` must reference
/// `BAR_COUNT` writable doubles.
#[no_mangle]
pub unsafe extern "C" fn wispie_spectrum_targets(
    bands: *const u8,
    band_len: usize,
    beats: *const i32,
    beat_count: usize,
    strengths: *const f32,
    bpm: f64,
    position_ms: f64,
    out: *mut f64,
) -> i32 {
    if out.is_null() || (bands.is_null() && band_len != 0) {
        return 0;
    }
    let bands = if band_len == 0 {
        &[][..]
    } else {
        std::slice::from_raw_parts(bands, band_len)
    };
    let beats = if beat_count == 0 || beats.is_null() {
        &[][..]
    } else {
        std::slice::from_raw_parts(beats, beat_count)
    };
    let strengths = if beat_count == 0 || strengths.is_null() {
        &[][..]
    } else {
        std::slice::from_raw_parts(strengths, beat_count)
    };
    let mut values = [0.0f64; BAR_COUNT];
    let usable = targets(bands, beats, strengths, bpm, position_ms, &mut values);
    if usable {
        std::slice::from_raw_parts_mut(out, BAR_COUNT).copy_from_slice(&values);
        1
    } else {
        0
    }
}

/// One scalar from the bar curve. Op codes: 0 advance, 1 tau, 2 shape,
/// 3 punch, 4 breath, 5 advance with an explicit tau.
#[no_mangle]
pub extern "C" fn wispie_spectrum_scalar(op: u8, a: f64, b: f64, c: f64, d: f64) -> f64 {
    match op {
        0 => advance_with_tau(a, b, c, tau_for(a, b)),
        1 => tau_for(a, b),
        2 => shape(a),
        3 => punch(a, b),
        4 => breath(a.max(0.0) as usize, b),
        5 => advance_with_tau(a, b, c, d),
        _ => 0.0,
    }
}

/// Re-anchor toward `position_ms`, snapping across a seek or track change.
#[no_mangle]
pub extern "C" fn wispie_playhead_ease(current_ms: f64, position_ms: f64) -> f64 {
    let drift = position_ms - current_ms;
    if drift.abs() > SNAP_THRESHOLD_MS {
        position_ms
    } else {
        current_ms + (drift * EASE_FACTOR).round()
    }
}

/// The position the listener is hearing: the decoded anchor plus elapsed wall
/// time, minus the output latency.
#[no_mangle]
pub extern "C" fn wispie_playhead_visual(
    anchor_ms: f64,
    wall_ms: f64,
    playing: u8,
    now_ms: f64,
    latency_ms: f64,
) -> f64 {
    let predicted = if playing == 0 {
        anchor_ms
    } else {
        anchor_ms + (now_ms - wall_ms)
    };
    predicted - latency_ms
}

/// 0 leaves the video alone, 1 seeks it. See `video_sync_policy.dart`.
#[no_mangle]
pub extern "C" fn wispie_video_sync(
    audio_ms: f64,
    video_ms: f64,
    playing: u8,
    buffering: u8,
    seeking: u8,
    since_last_seek_ms: f64,
) -> i32 {
    if playing == 0 || buffering != 0 || seeking != 0 {
        return 0;
    }
    let drift = (video_ms - audio_ms).abs();
    if drift <= VIDEO_TOLERANCE_MS {
        return 0;
    }
    if drift > VIDEO_JUMP_MS || since_last_seek_ms >= VIDEO_COOLDOWN_MS {
        return 1;
    }
    0
}

/// The ratio the video actually occupies once its rotation is applied.
#[no_mangle]
pub extern "C" fn wispie_video_aspect(raw_aspect: f64, rotation_correction: i32) -> f64 {
    if !raw_aspect.is_finite() || raw_aspect <= 0.0 {
        return 1.0;
    }
    let quarter_turns = (rotation_correction / 90).rem_euclid(4);
    if quarter_turns == 1 || quarter_turns == 3 {
        1.0 / raw_aspect
    } else {
        raw_aspect
    }
}
