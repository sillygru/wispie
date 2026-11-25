use std::collections::BTreeMap;

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

#[derive(Clone, Copy, Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum LyricsKind {
    Exact,
    Rich,
    Fields,
    Text,
}

#[derive(Deserialize)]
pub struct LyricsQuery {
    pub kind: LyricsKind,
    pub track: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub video_id: Option<String>,
    pub duration: Option<i64>,
    pub text: Option<String>,
}

#[derive(Serialize)]
pub struct LyricsRequest {
    pub unified: bool,
    pub path: &'static str,
    pub params: BTreeMap<&'static str, String>,
}

pub fn lyrics_requests(query: LyricsQuery) -> Vec<LyricsRequest> {
    let mut base = BTreeMap::new();
    let exact = matches!(query.kind, LyricsKind::Exact);
    let rich = matches!(query.kind, LyricsKind::Rich);
    let search = !exact && !rich;
    if matches!(query.kind, LyricsKind::Text) {
        let text = query.text.as_deref().unwrap_or_default().trim();
        if text.is_empty() {
            return Vec::new();
        }
        base.insert("q", text.to_string());
    } else {
        let track = query.track.unwrap_or_default();
        let artist = query.artist.unwrap_or_default();
        if track.is_empty() || (exact && artist.is_empty()) {
            return Vec::new();
        }
        base.insert("track_name", track);
        if rich || !artist.is_empty() {
            base.insert("artist_name", artist);
        }
        if let Some(album) = query.album.filter(|album| !album.is_empty()) {
            base.insert("album_name", album);
        }
        if let Some(duration) = query.duration.filter(|_| !search) {
            base.insert("duration", duration.to_string());
        }
    }
    let mut unified = base.clone();
    unified.insert("include_rich_sync", "true".to_string());
    unified.insert("sync_type", "richsync".to_string());
    if search {
        unified.insert("limit", "20".to_string());
    }

    let mut requests = Vec::new();
    if let Some(video) = query.video_id.filter(|id| !search && !id.is_empty()) {
        let mut pinned = unified.clone();
        pinned.insert("video_id", video);
        requests.push(LyricsRequest {
            unified: true,
            path: "/lyrics/get",
            params: pinned,
        });
    }
    requests.push(LyricsRequest {
        unified: true,
        path: if search {
            "/lyrics/search"
        } else {
            "/lyrics/get"
        },
        params: unified,
    });
    if !rich {
        requests.push(LyricsRequest {
            unified: false,
            path: if search { "/api/search" } else { "/api/get" },
            params: base,
        });
    }
    requests
}

pub fn music_utils_status(status: u16) -> &'static str {
    match status {
        200..=299 => "ok",
        404 => "not_found",
        _ => "transient",
    }
}

pub fn reserve_request(
    provider: &str,
    path: &str,
    now_ms: i64,
    last_ms: Option<i64>,
) -> (i64, i64) {
    let spacing = match provider {
        "itunes" => 2000,
        "lastfm" if !path.ends_with("/+images") => 1000,
        _ => 0,
    };
    if spacing == 0 {
        return (now_ms, 0);
    }
    let start = last_ms.map_or(now_ms, |last| now_ms.max(last.saturating_add(spacing)));
    (start, start.saturating_sub(now_ms))
}

#[derive(Deserialize)]
#[serde(tag = "op", rename_all = "snake_case")]
enum Request {
    Lyrics(LyricsQuery),
    MusicUtilsStatus {
        status: u16,
    },
    Pace {
        provider: String,
        #[serde(default)]
        path: String,
        now_ms: i64,
        last_ms: Option<i64>,
    },
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    let request: Request = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    match request {
        Request::Lyrics(query) => Ok(json!({"requests": lyrics_requests(query)})),
        Request::MusicUtilsStatus { status } => Ok(json!({"status": music_utils_status(status)})),
        Request::Pace {
            provider,
            path,
            now_ms,
            last_ms,
        } => {
            let (start, delay) = reserve_request(&provider, &path, now_ms, last_ms);
            Ok(json!({"start_ms": start, "delay_ms": delay}))
        }
    }
}
