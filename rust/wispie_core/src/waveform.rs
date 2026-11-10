use serde_json::json;

const SILENCE_FLOOR_DB: f64 = -60.0;
const MIN_DYNAMIC_RANGE_DB: f64 = 9.0;
const MAX_DYNAMIC_RANGE_DB: f64 = 30.0;

pub fn run(
    bytes: &[u8],
    target_samples: usize,
    expected_bytes: usize,
) -> Result<serde_json::Value, String> {
    if target_samples == 0 || target_samples > 8192 || bytes.len() < 2 {
        return Ok(json!({ "bars": [] }));
    }
    let filled = if expected_bytes > 0 {
        (((bytes.len() as f64 / expected_bytes as f64).clamp(0.0, 1.0) * target_samples as f64)
            .round() as usize)
            .clamp(1, target_samples)
    } else {
        target_samples
    };
    let usable = bytes.len() & !1;
    let (pairs, _) = bytes[..usable].as_chunks::<2>();
    let pcm: Vec<i16> = pairs.iter().map(|v| i16::from_le_bytes(*v)).collect();
    if pcm.is_empty() {
        return Ok(json!({ "bars": [] }));
    }
    let mut db = vec![f64::NEG_INFINITY; filled];
    for (i, value) in db.iter_mut().enumerate() {
        let start = i * pcm.len() / filled;
        let mut end = (i + 1) * pcm.len() / filled;
        if end <= start {
            end = (start + 1).min(pcm.len());
        }
        if start >= pcm.len() {
            continue;
        }
        let sum = pcm[start..end]
            .iter()
            .map(|sample| {
                let normalized = *sample as f64 / 32768.0;
                normalized * normalized
            })
            .sum::<f64>();
        let mean = sum / (end - start) as f64;
        if mean > 0.0 {
            *value = 10.0 * mean.ln() / std::f64::consts::LN_10;
        }
    }
    let mut audible: Vec<f64> = db
        .iter()
        .copied()
        .filter(|v| *v > SILENCE_FLOOR_DB)
        .collect();
    audible.sort_by(f64::total_cmp);
    let mut bars = vec![0.0; filled];
    if audible.is_empty() {
        return Ok(json!({ "bars": bars }));
    }
    let at = |q: f64| audible[((audible.len() as f64 * q).floor() as usize).min(audible.len() - 1)];
    let hi = at(0.99);
    let mut lo = at(0.05);
    let span = hi - lo;
    if span < MIN_DYNAMIC_RANGE_DB {
        lo = hi - MIN_DYNAMIC_RANGE_DB;
    }
    if span > MAX_DYNAMIC_RANGE_DB {
        lo = hi - MAX_DYNAMIC_RANGE_DB;
    }
    let range = hi - lo;
    for (i, value) in db.iter().enumerate() {
        if *value <= SILENCE_FLOOR_DB {
            continue;
        }
        bars[i] = 0.04 + 0.96 * ((*value - lo) / range).clamp(0.0, 1.0);
    }
    Ok(json!({ "bars": bars }))
}
