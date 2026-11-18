//! Which filename on this device does a song seen elsewhere correspond to?
//! Ported from `song_identity.dart`. Only identical content ids link names;
//! tags, durations and name similarity are never evidence.

use serde::Deserialize;
use serde_json::{json, Value};
use std::sync::{OnceLock, RwLock};

#[derive(Debug, Clone, Deserialize)]
pub struct IdentityRow {
    pub filename: String,
    pub cid: String,
    /// Carried on the wire for the Dart row; only the id and status decide links.
    #[serde(default)]
    #[allow(dead_code)]
    pub mtime: Option<f64>,
    #[serde(default)]
    pub status: String,
}

impl IdentityRow {
    fn live(&self) -> bool {
        self.status == "live"
    }
}

fn live_files_for<'a>(rows: &'a [IdentityRow], cid: &str) -> Vec<&'a str> {
    let mut names: Vec<&str> = rows
        .iter()
        .filter(|row| row.live() && row.cid == cid)
        .map(|row| row.filename.as_str())
        .collect();
    names.sort_unstable();
    names
}

/// The local file holding the same audio, or `None` when the name belongs to a
/// different recording here and the audio is absent.
pub fn resolve(rows: &[IdentityRow], filename: &str, remote_cid: Option<&str>) -> Option<String> {
    let local = rows.iter().find(|row| row.filename == filename);
    let cid = remote_cid
        .map(str::to_owned)
        .or_else(|| local.map(|row| row.cid.clone()));
    let Some(cid) = cid else {
        return Some(filename.to_string());
    };

    let live = live_files_for(rows, &cid);
    if live.contains(&filename) {
        return Some(filename.to_string());
    }
    let name_taken = local.is_some_and(|row| row.live() && row.cid != cid);
    if let Some(first) = live.first() {
        return Some((*first).to_string());
    }
    if name_taken {
        None
    } else {
        Some(filename.to_string())
    }
}

/// Orphans whose audio is present exactly once, as `(orphan, live)` pairs.
pub fn plan_heals(rows: &[IdentityRow]) -> Vec<(String, String)> {
    let mut cids: Vec<&str> = Vec::new();
    let mut orphans: Vec<Vec<&str>> = Vec::new();
    for row in rows.iter().filter(|row| row.status == "orphan") {
        match cids.iter().position(|cid| *cid == row.cid.as_str()) {
            Some(index) => orphans[index].push(row.filename.as_str()),
            None => {
                cids.push(row.cid.as_str());
                orphans.push(vec![row.filename.as_str()]);
            }
        }
    }

    let mut moves = Vec::new();
    for (index, cid) in cids.iter().enumerate() {
        let live = live_files_for(rows, cid);
        if live.len() != 1 {
            continue;
        }
        let mut names = orphans[index].clone();
        names.sort_unstable();
        for orphan in names {
            moves.push((orphan.to_string(), live[0].to_string()));
        }
    }
    moves
}

/// The rows are staged once per built index: resolving a sync record then costs
/// one small request, not the whole table again.
struct Prepared {
    generation: u64,
    rows: Vec<IdentityRow>,
}

fn prepared_slot() -> &'static RwLock<Option<Prepared>> {
    static PREPARED: OnceLock<RwLock<Option<Prepared>>> = OnceLock::new();
    PREPARED.get_or_init(|| RwLock::new(None))
}

pub fn prepare_json(request: &Value) -> Value {
    let rows = rows_from(request);
    let generation = request
        .get("generation")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    let count = rows.len();
    let mut slot = prepared_slot()
        .write()
        .unwrap_or_else(|poisoned| poisoned.into_inner());
    *slot = Some(Prepared { generation, rows });
    json!({ "count": count })
}

pub fn resolve_json(request: &Value) -> Result<Value, String> {
    let guard = prepared_slot()
        .read()
        .map_err(|_| "identity rows poisoned".to_string())?;
    let prepared = staged(&guard, request)?;
    let filename = request
        .get("filename")
        .and_then(Value::as_str)
        .unwrap_or("");
    let remote = request.get("remoteCid").and_then(Value::as_str);
    let cid = remote.map(str::to_owned).or_else(|| {
        prepared
            .rows
            .iter()
            .find(|row| row.filename == filename)
            .map(|row| row.cid.clone())
    });
    let live = cid
        .as_deref()
        .map(|cid| live_files_for(&prepared.rows, cid))
        .unwrap_or_default();
    Ok(json!({
        "filename": resolve(&prepared.rows, filename, remote),
        "live": live,
    }))
}

pub fn heals_json(request: &Value) -> Result<Value, String> {
    let guard = prepared_slot()
        .read()
        .map_err(|_| "identity rows poisoned".to_string())?;
    let prepared = staged(&guard, request)?;
    let moves: Vec<Value> = plan_heals(&prepared.rows)
        .into_iter()
        .map(|(from, to)| json!({ "from": from, "to": to }))
        .collect();
    Ok(json!({ "moves": moves }))
}

fn staged<'a>(slot: &'a Option<Prepared>, request: &Value) -> Result<&'a Prepared, String> {
    let prepared = slot
        .as_ref()
        .ok_or_else(|| "identity rows not prepared".to_string())?;
    let generation = request
        .get("generation")
        .and_then(Value::as_u64)
        .unwrap_or(0);
    if prepared.generation != generation {
        return Err("stale identity rows".to_string());
    }
    Ok(prepared)
}

fn rows_from(request: &Value) -> Vec<IdentityRow> {
    request
        .get("rows")
        .and_then(Value::as_array)
        .map(|rows| {
            rows.iter()
                .filter_map(|row| serde_json::from_value(row.clone()).ok())
                .collect()
        })
        .unwrap_or_default()
}
