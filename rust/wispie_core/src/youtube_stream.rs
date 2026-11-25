use serde::{Deserialize, Serialize};

const PREFERRED_AUDIO: &[&str] = &["140", "139", "251", "250", "249"];

/// A rendition with a direct URL accepted by the client.
#[derive(Deserialize)]
pub struct StreamFormat {
    pub index: usize,
    #[serde(default)]
    pub adaptive: bool,
    #[serde(default)]
    pub mime: String,
    pub itag: Option<String>,
    #[serde(default)]
    pub bitrate: i64,
    #[serde(default)]
    pub height: i64,
}

#[derive(Serialize)]
pub struct StreamSelection<'a> {
    pub index: usize,
    pub mime: &'a str,
    pub itag: &'a str,
}

pub fn select(formats: &[StreamFormat], video: bool) -> Option<StreamSelection<'_>> {
    if !video {
        let audio = formats
            .iter()
            .filter(|format| format.adaptive && format.mime.starts_with("audio/"))
            .min_by_key(|format| {
                let rank = PREFERRED_AUDIO
                    .iter()
                    .position(|tag| Some(*tag) == format.itag.as_deref())
                    .unwrap_or(PREFERRED_AUDIO.len());
                (rank, std::cmp::Reverse(format.bitrate))
            });
        if let Some(format) = audio {
            return Some(StreamSelection {
                index: format.index,
                mime: &format.mime,
                itag: format.itag.as_deref().unwrap_or("140"),
            });
        }
    }

    let muxed = formats
        .iter()
        .filter(|format| !format.mime.starts_with("audio/") && format.mime.contains("mp4a"));
    if video {
        let format = muxed
            .filter(|format| format.height <= 720)
            .min_by_key(|format| std::cmp::Reverse(format.height))?;
        return Some(StreamSelection {
            index: format.index,
            mime: &format.mime,
            itag: format.itag.as_deref().unwrap_or("18"),
        });
    }

    let format = muxed.min_by_key(|format| format.bitrate)?;
    Some(StreamSelection {
        index: format.index,
        mime: "audio/mp4",
        itag: format.itag.as_deref().unwrap_or("18"),
    })
}

pub fn profile_order(count: usize, preferred: usize) -> impl Iterator<Item = usize> {
    (0..count).map(move |step| (preferred % count + step) % count)
}

pub fn expires_ms(now_ms: i64, signed_seconds: Option<i64>) -> i64 {
    signed_seconds.map_or_else(
        || now_ms.saturating_add(15 * 60 * 1000),
        |seconds| seconds.saturating_mul(1000).saturating_sub(5 * 60 * 1000),
    )
}

pub fn playability(reason: Option<&str>, state: Option<&str>) -> &'static str {
    if matches!(state, None | Some("OK" | "LIVE_STREAM_OFFLINE")) {
        return "accepted";
    }
    let reason = reason.unwrap_or_default().to_lowercase();
    if reason.contains("bot") || reason.contains("sign in") {
        "blocked"
    } else {
        "unavailable"
    }
}

pub fn retry_catalogue_version(status: u16, attempt: usize, pinned: bool) -> bool {
    status == 400 && attempt == 0 && !pinned
}

#[derive(Serialize)]
pub struct ProxyStream {
    pub url: String,
    pub mime: String,
    pub itag: String,
    pub content_length: Option<i64>,
}

pub fn proxy_requests(base: &str, id: &str) -> [String; 2] {
    let base = base.trim().trim_end_matches('/');
    [
        format!("{base}/api/v1/videos/{id}?local=true"),
        format!("{base}/streams/{id}"),
    ]
}

pub fn proxy_streams(reply: &serde_json::Value, want_video: bool) -> Vec<ProxyStream> {
    use serde_json::Value;
    let text = |value: &Value| match value {
        Value::Null => None,
        Value::String(text) => Some(text.clone()),
        other => Some(other.to_string()),
    };
    ["adaptiveFormats", "audioStreams", "formats"]
        .iter()
        .filter_map(|key| reply[key].as_array())
        .flatten()
        .filter_map(|row| {
            let url = text(&row["url"]).filter(|url| !url.is_empty())?;
            let mime = text(&row["mimeType"])
                .or_else(|| text(&row["type"]))
                .unwrap_or_default();
            if mime.starts_with("video/") != want_video {
                return None;
            }
            let size = row
                .get("contentLength")
                .filter(|size| !size.is_null())
                .or_else(|| row.get("clen"));
            let content_length = size.and_then(|size| {
                size.as_i64()
                    .or_else(|| size.as_f64().map(|value| value.round() as i64))
                    .or_else(|| size.as_str().and_then(|value| value.parse().ok()))
            });
            Some(ProxyStream {
                url,
                mime: if mime.is_empty() {
                    "audio/mp4".into()
                } else {
                    mime
                },
                itag: text(&row["itag"]).unwrap_or_else(|| "proxy".into()),
                content_length,
            })
        })
        .collect()
}
