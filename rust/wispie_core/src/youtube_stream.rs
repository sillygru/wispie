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
