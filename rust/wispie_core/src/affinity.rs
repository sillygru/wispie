use serde::Serialize;
use serde_json::json;
use std::collections::HashSet;

#[link(name = "m")]
unsafe extern "C" {
    fn pow(base: f64, exponent: f64) -> f64;
}

fn decay_factor(age_days: f64, half_life_days: f64) -> f64 {
    if half_life_days <= 0.0 || age_days <= 0.0 {
        1.0
    } else {
        // Dart's VM math implementation uses the platform libm pow routine.
        unsafe { pow(0.5, age_days / half_life_days) }
    }
}

const EVENT_STRIDE: usize = 20;
#[derive(Default)]
struct Params {
    half_life_days: f64,
    saturation_half_life_days: f64,
    saturation_target: f64,
    full_listen_ratio: f64,
    skip_ratio: f64,
    partial_ratio: f64,
    full_listen_credit: f64,
    skip_penalty: f64,
    partial_penalty: f64,
    percentile: f64,
    favorite_floor: f64,
}

impl Params {
    fn from_request(request: &serde_json::Value) -> Self {
        let values = &request["params"];
        let get = |key: &str, default: f64| values[key].as_f64().unwrap_or(default);
        Self {
            half_life_days: get("halfLifeDays", 90.0),
            saturation_half_life_days: get("saturationHalfLifeDays", 2.0),
            saturation_target: get("saturationTarget", 6.0),
            full_listen_ratio: get("fullListenRatio", 0.85),
            skip_ratio: get("skipRatio", 0.10),
            partial_ratio: get("partialRatio", 0.25),
            full_listen_credit: get("fullListenCredit", 1.0),
            skip_penalty: get("skipPenalty", -0.6),
            partial_penalty: get("partialPenalty", -0.2),
            percentile: get("normalizationPercentile", 0.95),
            favorite_floor: get("favoriteFloor", 0.6),
        }
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct Row {
    filename: String,
    affinity: f64,
    recent_saturation: f64,
    completion_rate: f64,
    skip_rate: f64,
    play_count: usize,
    last_played_at: Option<f64>,
}

pub fn run(request: &serde_json::Value, bytes: &[u8]) -> Result<serde_json::Value, String> {
    let filenames: Vec<String> =
        serde_json::from_value(request.get("filenames").cloned().unwrap_or_default())
            .map_err(|error| format!("affinity filenames: {error}"))?;
    let favorites: HashSet<String> =
        serde_json::from_value(request.get("favorites").cloned().unwrap_or_default())
            .map_err(|error| format!("affinity favorites: {error}"))?;
    let now = request
        .get("nowSeconds")
        .and_then(serde_json::Value::as_f64)
        .ok_or_else(|| "affinity request has no nowSeconds".to_string())?;
    let params = Params::from_request(request);
    let (rows, remainder) = bytes.as_chunks::<EVENT_STRIDE>();
    if !remainder.is_empty() {
        return Err("affinity event payload is not a whole number of rows".to_string());
    }

    let mut raw = vec![0.0; filenames.len()];
    let mut completion = vec![0.0; filenames.len()];
    let mut skips = vec![0.0; filenames.len()];
    let mut decay_total = vec![0.0; filenames.len()];
    let mut saturation = vec![0.0; filenames.len()];
    let mut counts = vec![0usize; filenames.len()];
    let mut last_played = vec![None::<f64>; filenames.len()];

    for row in rows {
        let key = u32::from_le_bytes(row[0..4].try_into().unwrap()) as usize;
        if key >= filenames.len() {
            return Err("affinity event filename index is out of range".to_string());
        }
        let timestamp = f64::from_le_bytes(row[4..12].try_into().unwrap());
        let ratio = f64::from_le_bytes(row[12..20].try_into().unwrap()).clamp(0.0, 1.0);
        let age_days = ((now - timestamp) / 86400.0).max(0.0);
        let decay = decay_factor(age_days, params.half_life_days);
        let quality = if ratio >= params.full_listen_ratio {
            params.full_listen_credit
        } else if ratio >= params.partial_ratio {
            let span = params.full_listen_ratio - params.partial_ratio;
            if span <= 0.0 {
                params.full_listen_credit
            } else {
                (ratio - params.partial_ratio) / span * params.full_listen_credit
            }
        } else if ratio >= params.skip_ratio {
            params.partial_penalty
        } else {
            params.skip_penalty
        };
        raw[key] += quality * decay;
        completion[key] += ratio * decay;
        decay_total[key] += decay;
        if ratio < params.skip_ratio {
            skips[key] += decay;
        }
        saturation[key] += decay_factor(age_days, params.saturation_half_life_days);
        counts[key] += 1;
        last_played[key] = Some(last_played[key].unwrap_or(f64::NEG_INFINITY).max(timestamp));
    }

    let mut positive: Vec<f64> = raw.iter().copied().filter(|score| *score > 0.0).collect();
    positive.sort_by(f64::total_cmp);
    let reference = percentile(&positive, params.percentile);
    let rows: Vec<Row> = filenames
        .into_iter()
        .enumerate()
        .filter_map(|(i, filename)| {
            if counts[i] == 0 && !favorites.contains(&filename) {
                return None;
            }
            let mut affinity = if reference > 0.0 {
                (raw[i] / reference).clamp(0.0, 1.0)
            } else if raw[i] > 0.0 {
                1.0
            } else {
                0.0
            };
            if favorites.contains(&filename) {
                affinity = affinity.max(params.favorite_floor);
            }
            let weight = decay_total[i];
            Some(Row {
                filename,
                affinity,
                recent_saturation: if params.saturation_target > 0.0 {
                    saturation[i] / params.saturation_target
                } else {
                    0.0
                },
                completion_rate: if weight > 0.0 {
                    completion[i] / weight
                } else {
                    0.0
                },
                skip_rate: if weight > 0.0 { skips[i] / weight } else { 0.0 },
                play_count: counts[i],
                last_played_at: last_played[i],
            })
        })
        .collect();
    Ok(json!({ "rows": rows }))
}

fn percentile(sorted: &[f64], percentile: f64) -> f64 {
    if sorted.is_empty() {
        return 0.0;
    }
    if sorted.len() == 1 {
        return sorted[0];
    }
    let rank = percentile.clamp(0.0, 1.0) * (sorted.len() - 1) as f64;
    let lower = rank.floor() as usize;
    let upper = rank.ceil() as usize;
    if lower == upper {
        sorted[lower]
    } else {
        let t = rank - lower as f64;
        sorted[lower] * (1.0 - t) + sorted[upper] * t
    }
}
