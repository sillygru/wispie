//! Offline beat grid and band-envelope analysis.

use crate::emitter::{Emit, Emitter};
use serde::Serialize;
use serde_json::json;
use std::fs;

const SAMPLE_RATE: usize = 22_050;
const FFT_SIZE: usize = 2_048;
const HOP: usize = 512;
const FPS: f64 = SAMPLE_RATE as f64 / HOP as f64;
const BAND_COUNT: usize = 40;
const MIN_BPM: f64 = 40.0;
const MAX_BPM: f64 = 240.0;
const TEMPO_CENTRE_SEC: f64 = 0.45;
const HARMONIC_2: f64 = 0.5;
const HARMONIC_3: f64 = 0.25;
const SUBDIVISION: f64 = 0.2;
const DP_TIGHTNESS: f64 = 100.0;
const MIN_PERCUSSIVE_FLUX: f32 = 0.5;
const STRENGTH_GATE: f32 = 0.18;
const LOG_GAMMA: f64 = 1000.0;
const VISUAL_EDGES_HZ: [f64; 5] = [20.0, 150.0, 800.0, 4_000.0, 11_025.0];

pub fn run_file(path: &str, max_bytes: Option<usize>, emitter: &Emitter) -> Result<(), String> {
    let mut bytes = fs::read(path).map_err(|error| format!("read beat PCM: {error}"))?;
    if let Some(limit) = max_bytes {
        bytes.truncate(limit);
    }
    let usable = bytes.len() & !1;
    run_bytes(&bytes[..usable], emitter)
}

fn run_bytes(bytes: &[u8], emitter: &Emitter) -> Result<(), String> {
    if bytes.len() < 4 {
        return Err("beat PCM is too short".to_string());
    }
    let usable = bytes.len() & !1;
    let (pairs, _) = bytes[..usable].as_chunks::<2>();
    let samples: Vec<f32> = pairs
        .iter()
        .map(|pair| i16::from_le_bytes(*pair) as f32 / 32768.0)
        .collect();
    emitter.emit(Emit::Json(analyze(&samples)));
    Ok(())
}

#[derive(Serialize)]
struct BeatResult {
    duration_ms: i64,
    bpm: f64,
    beats_ms: Vec<i32>,
    beat_strength: Vec<f32>,
    downbeats: Vec<u8>,
    bands: Vec<u8>,
}

fn analyze(samples: &[f32]) -> serde_json::Value {
    let duration_ms = (samples.len() as f64 / SAMPLE_RATE as f64 * 1000.0).round() as i64;
    let frame_count = 1 + samples.len() / HOP;
    if frame_count < (FPS * 2.0) as usize {
        return result_json(BeatResult {
            duration_ms,
            bpm: 0.0,
            beats_ms: vec![],
            beat_strength: vec![],
            downbeats: vec![],
            bands: vec![],
        });
    }

    let spectra = envelopes(samples, frame_count);
    let packed_bands = pack_bands(&spectra.bands, frame_count);
    if !is_percussive(&spectra.onset) {
        return result_json(BeatResult {
            duration_ms,
            bpm: 0.0,
            beats_ms: vec![],
            beat_strength: vec![],
            downbeats: vec![],
            bands: packed_bands,
        });
    }
    let Some(normalized) = normalize_onset(&spectra.onset) else {
        return result_json(BeatResult {
            duration_ms,
            bpm: 0.0,
            beats_ms: vec![],
            beat_strength: vec![],
            downbeats: vec![],
            bands: packed_bands,
        });
    };
    let accent = accent_envelope(&normalized, &spectra.bass_onset);
    let loudness = local_loudness(&spectra.bands);
    let Some(period) = estimate_period(&normalized) else {
        return result_json(BeatResult {
            duration_ms,
            bpm: 0.0,
            beats_ms: vec![],
            beat_strength: vec![],
            downbeats: vec![],
            bands: packed_bands,
        });
    };
    let local_score = smooth_for_dp(&normalized, period);
    let beat_frames = track_beats(&local_score, period);
    if beat_frames.is_empty() {
        return result_json(BeatResult {
            duration_ms,
            bpm: 0.0,
            beats_ms: vec![],
            beat_strength: vec![],
            downbeats: vec![],
            bands: packed_bands,
        });
    }
    let snapped = snap_to_onsets(&beat_frames, &accent, period);
    let mut beats_ms = Vec::with_capacity(snapped.len());
    for i in 0..snapped.len() {
        let source = if snapped[i] == beat_frames[i] {
            &local_score
        } else {
            &accent
        };
        let refined = refine_peak(source, snapped[i]);
        let mut ms = (refined * HOP as f64 / SAMPLE_RATE as f64 * 1000.0).round() as i32;
        if let Some(previous) = beats_ms.last() {
            if ms <= *previous {
                ms = *previous + 1;
            }
        }
        beats_ms.push(ms);
    }
    let strength = beat_strengths(&accent, &loudness, &snapped, period);
    let downbeats = find_downbeats(&strength);
    let bpm = bpm_from_beats(&beats_ms, period);
    result_json(BeatResult {
        duration_ms,
        bpm,
        beats_ms,
        beat_strength: strength,
        downbeats,
        bands: packed_bands,
    })
}

fn result_json(result: BeatResult) -> serde_json::Value {
    json!({
        "durationMs": result.duration_ms,
        "bpm": result.bpm,
        "beatsMs": result.beats_ms,
        "beatStrength": result.beat_strength,
        "downbeats": result.downbeats,
        "bands": result.bands,
        "bandFps": 30.0,
    })
}

struct Envelopes {
    onset: Vec<f32>,
    bass_onset: Vec<f32>,
    bands: Vec<Vec<f32>>,
}

fn envelopes(samples: &[f32], frame_count: usize) -> Envelopes {
    let mut re = vec![0.0; FFT_SIZE];
    let mut im = vec![0.0; FFT_SIZE];
    let window: Vec<f64> = (0..FFT_SIZE)
        .map(|i| 0.5 - 0.5 * (2.0 * std::f64::consts::PI * i as f64 / FFT_SIZE as f64).cos())
        .collect();
    let cos: Vec<f64> = (0..FFT_SIZE / 2)
        .map(|i| (-2.0 * std::f64::consts::PI * i as f64 / FFT_SIZE as f64).cos())
        .collect();
    let sin: Vec<f64> = (0..FFT_SIZE / 2)
        .map(|i| (-2.0 * std::f64::consts::PI * i as f64 / FFT_SIZE as f64).sin())
        .collect();
    let bits = FFT_SIZE.trailing_zeros();
    let rev: Vec<usize> = (0..FFT_SIZE)
        .map(|i| i.reverse_bits() >> (usize::BITS - bits))
        .collect();
    let bin_count = FFT_SIZE / 2 + 1;
    let mut magnitude = vec![0.0; bin_count];
    let onset_edges = log_edges(BAND_COUNT, 40.0, 11_025.0, bin_count);
    let visual_edges = fixed_edges(&VISUAL_EDGES_HZ, bin_count);
    let bin_width = SAMPLE_RATE as f64 / FFT_SIZE as f64;
    let mut bass_bands = 0;
    while bass_bands < BAND_COUNT && onset_edges[bass_bands + 1] as f64 * bin_width <= 160.0 {
        bass_bands += 1;
    }

    let mut onset = vec![0.0f32; frame_count];
    let mut bass_onset = vec![0.0f32; frame_count];
    let mut bands = vec![vec![0.0f32; frame_count]; 4];
    let mut previous = vec![0.0f64; BAND_COUNT];
    let mut current = vec![0.0f64; BAND_COUNT];
    let scale = 2.0 / FFT_SIZE as f64;
    for frame in 0..frame_count {
        let start = frame as isize * HOP as isize - (FFT_SIZE / 2) as isize;
        for i in 0..FFT_SIZE {
            let index = start + i as isize;
            re[i] = if index < 0 || index as usize >= samples.len() {
                0.0
            } else {
                samples[index as usize] as f64 * window[i]
            };
            im[i] = 0.0;
        }
        fft(&mut re, &mut im, &cos, &sin, &rev);
        for bin in 0..bin_count {
            magnitude[bin] = (re[bin] * re[bin] + im[bin] * im[bin]).sqrt() * scale;
        }
        for b in 0..BAND_COUNT {
            current[b] =
                (1.0 + LOG_GAMMA * mean_bins(&magnitude, onset_edges[b], onset_edges[b + 1])).ln();
        }
        if frame > 0 {
            let mut flux = 0.0;
            let mut bass_flux = 0.0;
            for b in 0..BAND_COUNT {
                let delta = current[b] - previous[b];
                if delta > 0.0 {
                    flux += delta;
                    if b < bass_bands {
                        bass_flux += delta;
                    }
                }
            }
            onset[frame] = flux as f32;
            bass_onset[frame] = bass_flux as f32;
        }
        for b in 0..4 {
            bands[b][frame] = (1.0
                + LOG_GAMMA * mean_bins(&magnitude, visual_edges[b], visual_edges[b + 1]))
            .ln() as f32;
        }
        std::mem::swap(&mut previous, &mut current);
    }
    Envelopes {
        onset,
        bass_onset,
        bands,
    }
}

fn fft(re: &mut [f64], im: &mut [f64], cos: &[f64], sin: &[f64], rev: &[usize]) {
    let n = re.len();
    for (i, &j) in rev.iter().enumerate() {
        if j > i {
            re.swap(i, j);
            im.swap(i, j);
        }
    }
    let mut len = 2;
    while len <= n {
        let half = len / 2;
        let step = n / len;
        let mut start = 0;
        while start < n {
            let mut twiddle = 0;
            for offset in 0..half {
                let top = start + offset;
                let bottom = top + half;
                let vr = re[bottom] * cos[twiddle] - im[bottom] * sin[twiddle];
                let vi = re[bottom] * sin[twiddle] + im[bottom] * cos[twiddle];
                let ur = re[top];
                let ui = im[top];
                re[top] = ur + vr;
                im[top] = ui + vi;
                re[bottom] = ur - vr;
                im[bottom] = ui - vi;
                twiddle += step;
            }
            start += len;
        }
        len <<= 1;
    }
}

fn mean_bins(values: &[f64], start: usize, end: usize) -> f64 {
    if end <= start {
        0.0
    } else {
        values[start..end].iter().sum::<f64>() / (end - start) as f64
    }
}
fn log_edges(count: usize, low: f64, high: f64, bin_count: usize) -> Vec<usize> {
    let width = SAMPLE_RATE as f64 / FFT_SIZE as f64;
    let lo = low.ln();
    let hi = high.ln();
    let mut out = vec![0; count + 1];
    for i in 0..=count {
        let hz = (lo + (hi - lo) * i as f64 / count as f64).exp();
        let mut bin = (hz / width).round() as usize;
        if i > 0 && bin <= out[i - 1] {
            bin = out[i - 1] + 1;
        }
        out[i] = bin.min(bin_count);
    }
    out
}
fn fixed_edges(hz: &[f64], bin_count: usize) -> Vec<usize> {
    let width = SAMPLE_RATE as f64 / FFT_SIZE as f64;
    let mut out = vec![0; hz.len()];
    for i in 0..hz.len() {
        let mut bin = (hz[i] / width).round() as usize;
        if i > 0 && bin <= out[i - 1] {
            bin = out[i - 1] + 1;
        }
        out[i] = bin.min(bin_count);
    }
    out
}

fn is_percussive(onset: &[f32]) -> bool {
    if onset.is_empty() {
        return false;
    }
    let mut sorted = onset.to_vec();
    sorted.sort_by(f32::total_cmp);
    sorted[((sorted.len() as f64 * 0.95).floor() as usize).min(sorted.len() - 1)]
        >= MIN_PERCUSSIVE_FLUX
}
fn normalize_onset(onset: &[f32]) -> Option<Vec<f32>> {
    let size = (FPS * 0.4).round() as usize;
    let size = size.max(3);
    let mut ring = vec![0.0f64; size];
    let mut count = 0;
    let mut index = 0;
    let mut sum = 0.0;
    let mut out = vec![0.0f32; onset.len()];
    for (i, &v) in onset.iter().enumerate() {
        if count < size {
            count += 1
        } else {
            sum -= ring[index];
        }
        ring[index] = v as f64;
        sum += v as f64;
        index = (index + 1) % size;
        let x = v as f64 - sum / count as f64;
        out[i] = x.max(0.0) as f32;
    }
    let mean = out.iter().map(|v| *v as f64).sum::<f64>() / out.len() as f64;
    let variance = out
        .iter()
        .map(|v| {
            let d = *v as f64 - mean;
            d * d
        })
        .sum::<f64>()
        / out.len() as f64;
    let std = variance.sqrt();
    if std < 1e-9 {
        return None;
    }
    for v in &mut out {
        *v = (*v as f64 / std) as f32;
    }
    Some(out)
}

fn percentile(values: &[f32], q: f64) -> f32 {
    if values.is_empty() {
        return 0.0;
    }
    let mut sorted = values.to_vec();
    sorted.sort_by(f32::total_cmp);
    sorted[((sorted.len() as f64 * q).floor() as usize).min(sorted.len() - 1)]
}
fn estimate_period(raw: &[f32]) -> Option<f64> {
    let mut onset = vec![0.0f32; raw.len()];
    for i in 0..raw.len() {
        let a = if i > 0 { raw[i - 1] } else { 0.0 };
        let c = if i + 1 < raw.len() { raw[i + 1] } else { 0.0 };
        onset[i] = 0.25 * a + 0.5 * raw[i] + 0.25 * c;
    }
    let min_lag = 2.max((FPS * 60.0 / MAX_BPM).floor() as usize);
    let max_lag = (onset.len() / 2).min((FPS * 60.0 / MIN_BPM).ceil() as usize);
    if max_lag <= min_lag {
        return None;
    }
    let max_acf = (onset.len() - 1).min(max_lag * 3);
    let mut acf = vec![0.0; max_acf + 1];
    for lag in 0..=max_acf {
        if lag > 0 && lag < min_lag / 2 {
            continue;
        }
        let sum = (lag..onset.len())
            .map(|i| onset[i] as f64 * onset[i - lag] as f64)
            .sum::<f64>();
        acf[lag] = sum / (onset.len() - lag) as f64;
    }
    let zero = acf[0];
    if zero <= 0.0 {
        return None;
    }
    for v in &mut acf {
        *v /= zero;
    }
    let centre = TEMPO_CENTRE_SEC * FPS;
    let mut best = None;
    let mut best_score = f64::NEG_INFINITY;
    for lag in min_lag..=max_lag {
        let own = acf[lag];
        let harmonic = |l: usize| {
            if l > max_acf {
                0.0
            } else {
                acf[l].min(own.max(0.0))
            }
        };
        let correlation = own
            + HARMONIC_2 * harmonic(lag * 2)
            + HARMONIC_3 * harmonic(lag * 3)
            + SUBDIVISION * acf_at(&acf, lag as f64 / 2.0).max(0.0);
        let octaves = (lag as f64 / centre).ln() / std::f64::consts::LN_2;
        let prior = (-0.5 * (octaves).powi(2)).exp();
        let score = correlation * prior;
        if score > best_score {
            best_score = score;
            best = Some(lag as f64);
        }
    }
    if best_score <= 0.0 {
        None
    } else {
        best
    }
}
fn acf_at(acf: &[f64], lag: f64) -> f64 {
    let lower = lag.floor() as usize;
    if lower + 1 >= acf.len() {
        return 0.0;
    }
    let t = lag - lower as f64;
    acf[lower] * (1.0 - t) + acf[lower + 1] * t
}
fn smooth_for_dp(onset: &[f32], period: f64) -> Vec<f32> {
    let std = period / 32.0;
    let radius = (period.round() as usize).max(1);
    let weights: Vec<f64> = (-(radius as isize)..=radius as isize)
        .map(|i| (-0.5 * (i as f64 / std).powi(2)).exp())
        .collect();
    let mut out = vec![0.0; onset.len()];
    for i in 0..onset.len() {
        let from = i.saturating_sub(radius);
        let to = (i + radius).min(onset.len() - 1);
        let mut sum = 0.0;
        for j in from..=to {
            sum += onset[j] as f64 * weights[(j as isize - i as isize + radius as isize) as usize];
        }
        out[i] = sum as f32;
    }
    out
}
fn track_beats(score: &[f32], period: f64) -> Vec<usize> {
    let n = score.len();
    let start = -(2.0 * period).round() as isize;
    let end = -(period / 2.0).round() as isize;
    if end <= start {
        return vec![];
    }
    let window = (start..=end)
        .map(|offset| -DP_TIGHTNESS * ((-offset as f64 / period).ln()).powi(2))
        .collect::<Vec<_>>();
    let mut backlink = vec![-1isize; n];
    let mut cum = vec![0.0; n];
    let limit = n.min(period.round() as usize);
    let threshold = score[..limit].iter().copied().fold(0.0f32, f32::max) as f64 * 0.01;
    for i in 0..n {
        let mut best = f64::NEG_INFINITY;
        let mut best_index = None;
        for (w, &cost) in window.iter().enumerate() {
            let candidate = i as isize + start + w as isize;
            if candidate < 0 {
                continue;
            }
            let value = cum[candidate as usize] + cost;
            if value > best {
                best = value;
                best_index = Some(candidate as usize);
            }
        }
        if let Some(prev) = best_index {
            cum[i] = score[i] as f64 + best;
            backlink[i] = prev as isize;
        } else {
            cum[i] = if score[i] as f64 > threshold {
                score[i] as f64
            } else {
                0.0
            };
        }
    }
    let mut maxima = Vec::new();
    for i in 1..n.saturating_sub(1) {
        if cum[i] > cum[i - 1] && cum[i] >= cum[i + 1] {
            maxima.push(cum[i]);
        }
    }
    if maxima.is_empty() {
        return vec![];
    }
    maxima.sort_by(f64::total_cmp);
    let threshold = maxima[maxima.len() / 2] * 0.5;
    let last = (1..n.saturating_sub(1))
        .rev()
        .find(|&i| cum[i] > cum[i - 1] && cum[i] >= cum[i + 1] && cum[i] >= threshold);
    let Some(mut cursor) = last else {
        return vec![];
    };
    let mut beats = Vec::new();
    loop {
        beats.push(cursor);
        if backlink[cursor] < 0 {
            break;
        }
        cursor = backlink[cursor] as usize;
    }
    beats.reverse();
    if beats.is_empty() {
        return beats;
    }
    let mean = beats.iter().map(|&b| score[b] as f64).sum::<f64>() / beats.len() as f64;
    let cutoff = 0.1 * mean;
    let first = beats
        .iter()
        .position(|&b| score[b] as f64 >= cutoff)
        .unwrap_or(beats.len());
    let last = beats
        .iter()
        .rposition(|&b| score[b] as f64 >= cutoff)
        .map(|v| v + 1)
        .unwrap_or(first);
    beats[first..last].to_vec()
}
fn refine_peak(signal: &[f32], index: usize) -> f64 {
    if index == 0 || index + 1 >= signal.len() {
        return index as f64;
    }
    let l = signal[index - 1] as f64;
    let c = signal[index] as f64;
    let r = signal[index + 1] as f64;
    let d = l - 2.0 * c + r;
    if d.abs() < 1e-12 {
        return index as f64;
    }
    let delta = 0.5 * (l - r) / d;
    if delta.abs() > 0.5 {
        return index as f64;
    }
    index as f64 + delta
}
fn accent_envelope(normalized: &[f32], bass: &[f32]) -> Vec<f32> {
    let full = percentile(normalized, 0.95);
    let low = percentile(bass, 0.95);
    (0..normalized.len())
        .map(|i| {
            0.6 * (if full > 0.0 {
                (normalized[i] / full).min(1.5)
            } else {
                0.0
            }) + 0.4
                * (if low > 1e-6 {
                    (bass[i] / low).min(1.5)
                } else {
                    0.0
                })
        })
        .collect()
}
fn search_radius(period: f64) -> usize {
    ((period * 0.1).round() as usize).clamp(1, 3)
}
fn snap_to_onsets(beats: &[usize], accent: &[f32], period: f64) -> Vec<usize> {
    let radius = search_radius(period).min(2);
    beats
        .iter()
        .map(|&b| {
            let mut best = b;
            let mut value = accent[b];
            for (f, &accent_value) in accent
                .iter()
                .enumerate()
                .take((b + radius).min(accent.len() - 1) + 1)
                .skip(b.saturating_sub(radius))
            {
                if accent_value > value {
                    value = accent_value;
                    best = f;
                }
            }
            if best != b && value > accent[b] * 1.25 && value > 0.2 {
                best
            } else {
                b
            }
        })
        .collect()
}
fn local_loudness(bands: &[Vec<f32>]) -> Vec<f64> {
    let frames = bands.first().map_or(0, Vec::len);
    let mut energy = vec![0.0f64; frames];
    for band in bands {
        for (i, v) in band.iter().enumerate() {
            energy[i] += *v as f64;
        }
    }
    let mut sorted = energy.clone();
    sorted.sort_by(f64::total_cmp);
    let reference = sorted[((frames as f64 * 0.9).floor() as usize).min(frames.saturating_sub(1))];
    if reference <= 0.0 {
        return vec![1.0; frames];
    }
    let mut prefix = vec![0.0; frames + 1];
    for i in 0..frames {
        prefix[i + 1] = prefix[i] + energy[i];
    }
    let radius = (FPS * 0.4).round() as usize;
    (0..frames)
        .map(|i| {
            let lo = i.saturating_sub(radius);
            let hi = (i + radius + 1).min(frames);
            let local = (prefix[hi] - prefix[lo]) / (hi - lo) as f64;
            (local / reference).clamp(0.0, 1.0).powf(1.5)
        })
        .collect()
}
fn beat_strengths(accent: &[f32], loudness: &[f64], beats: &[usize], period: f64) -> Vec<f32> {
    if beats.is_empty() {
        return vec![];
    }
    let radius = search_radius(period);
    let mut raw = vec![0.0f32; beats.len()];
    for i in 0..beats.len() {
        let b = beats[i];
        let from = b.saturating_sub(radius);
        let to = (b + radius).min(accent.len() - 1);
        let peak = accent[from..=to].iter().copied().fold(0.0f32, f32::max);
        let left = beats[i.saturating_sub(2)];
        let right = beats[(i + 2).min(beats.len() - 1)];
        let background = if right - left > radius * 4 {
            let mut window = accent[left..=right].to_vec();
            window.sort_by(f32::total_cmp);
            window[window.len() / 2]
        } else {
            0.0
        };
        raw[i] = (peak - 0.6 * background).max(0.0) * loudness[b] as f32;
    }
    let mut sorted = raw.clone();
    sorted.sort_by(f32::total_cmp);
    let reference = sorted[((raw.len() as f64 * 0.85).floor() as usize).min(raw.len() - 1)];
    if reference <= 0.0 {
        return vec![0.0; beats.len()];
    }
    raw.iter()
        .map(|v| {
            let s = (*v / reference).clamp(0.0, 1.0);
            if s <= STRENGTH_GATE {
                0.0
            } else {
                (s - STRENGTH_GATE) / (1.0 - STRENGTH_GATE)
            }
        })
        .collect()
}
fn find_downbeats(strength: &[f32]) -> Vec<u8> {
    let mut flags = vec![0; strength.len()];
    if strength.len() < 8 {
        return flags;
    }
    let mut best = 0;
    let mut best_score = f64::NEG_INFINITY;
    for phase in 0..4 {
        let score = (phase..strength.len())
            .step_by(4)
            .map(|i| strength[i] as f64)
            .sum::<f64>();
        if score > best_score {
            best_score = score;
            best = phase;
        }
    }
    for i in (best..strength.len()).step_by(4) {
        flags[i] = 1;
    }
    flags
}
fn bpm_from_beats(beats: &[i32], period: f64) -> f64 {
    if beats.len() < 2 {
        return 60.0 * SAMPLE_RATE as f64 / (period * HOP as f64);
    }
    let mut intervals: Vec<i32> = beats.windows(2).map(|w| w[1] - w[0]).collect();
    intervals.sort_unstable();
    let median = intervals[intervals.len() / 2];
    if median <= 0 {
        0.0
    } else {
        60000.0 / median as f64
    }
}
fn pack_bands(bands: &[Vec<f32>], frame_count: usize) -> Vec<u8> {
    let mut smoothed = vec![vec![0.0f32; frame_count]; 4];
    for b in 0..4 {
        let mut level = 0.0f32;
        for i in 0..frame_count {
            let value = bands[b][i];
            let coefficient = if value > level { 1.0 } else { 0.5 };
            level += (value - level) * coefficient;
            smoothed[b][i] = level;
        }
    }
    let mut refs = [0.0f32; 4];
    for b in 0..4 {
        let mut sorted = smoothed[b].clone();
        sorted.sort_by(f32::total_cmp);
        refs[b] = sorted[((frame_count as f64 * 0.99).floor() as usize).min(frame_count - 1)];
    }
    let duration = frame_count as f64 * HOP as f64 / SAMPLE_RATE as f64;
    let out_frames = ((duration * 30.0).floor() as usize).max(1);
    let mut packed = vec![0; out_frames * 4];
    for frame in 0..out_frames {
        let position = frame as f64 / 30.0 * FPS;
        let lower = (position.floor() as usize).min(frame_count - 1);
        let upper = (lower + 1).min(frame_count - 1);
        let fraction = position - lower as f64;
        for b in 0..4 {
            let reference = refs[b];
            if reference <= 0.0 {
                continue;
            }
            let a = smoothed[b][lower] as f64;
            let c = smoothed[b][upper] as f64;
            packed[frame * 4 + b] = (((a + (c - a) * fraction) / reference as f64).clamp(0.0, 1.0)
                * 255.0)
                .round() as u8;
        }
    }
    packed
}
