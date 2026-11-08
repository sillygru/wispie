//! Wire types. Field names match `Song.toJson`/`Song.fromJson` in Dart exactly,
//! so a row round-trips through the boundary without a translation table.

use serde::{Deserialize, Serialize};
use std::collections::HashMap;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct SongJson {
    #[serde(default)]
    pub title: String,
    #[serde(default)]
    pub artist: String,
    #[serde(default)]
    pub album: String,
    #[serde(default)]
    pub filename: String,
    #[serde(default)]
    pub url: String,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub cover_url: Option<String>,
    #[serde(default)]
    pub has_lyrics: bool,
    #[serde(default)]
    pub play_count: i64,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub duration: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub mtime: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub created_epoch_sec: Option<f64>,
    #[serde(default, skip_serializing_if = "Option::is_none")]
    pub song_date_epoch_sec: Option<f64>,
}

impl SongJson {
    pub fn is_placeholder(&self) -> bool {
        let stem = std::path::Path::new(&self.url)
            .file_stem()
            .and_then(|s| s.to_str())
            .unwrap_or("");
        self.title == stem
            && self.artist == "Unknown Artist"
            && self.album == "Unknown Album"
            && self.cover_url.is_none()
            && self.duration.is_none()
    }
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct ScanRequest {
    pub roots: Vec<String>,
    #[serde(rename = "excludedFolders")]
    pub excluded_folders: Vec<String>,
    #[serde(rename = "coversDir")]
    pub covers_dir: String,
    #[serde(rename = "includeVideos")]
    pub include_videos: bool,
    #[serde(rename = "minFileSizeBytes")]
    pub min_file_size_bytes: u64,
    #[serde(rename = "fastMode")]
    pub fast_mode: bool,
    pub existing: Vec<SongJson>,
    #[serde(rename = "playCounts")]
    pub play_counts: HashMap<String, i64>,
    #[serde(rename = "batchSize")]
    pub batch_size: usize,
    pub concurrency: usize,
}

impl Default for ScanRequest {
    fn default() -> Self {
        Self {
            roots: Vec::new(),
            excluded_folders: Vec::new(),
            covers_dir: String::new(),
            include_videos: false,
            min_file_size_bytes: 0,
            fast_mode: false,
            existing: Vec::new(),
            play_counts: HashMap::new(),
            batch_size: 200,
            concurrency: 0,
        }
    }
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct SongsRequest {
    #[serde(rename = "coversDir")]
    pub covers_dir: String,
    pub songs: Vec<SongJson>,
    pub force: bool,
    pub concurrency: usize,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct FactsRequest {
    pub paths: Vec<String>,
    pub concurrency: usize,
}

#[derive(Debug, Clone, Deserialize)]
#[serde(default)]
pub struct ListRequest {
    pub root: String,
    pub recursive: bool,
    pub concurrency: usize,
}

impl Default for ListRequest {
    fn default() -> Self {
        Self {
            root: String::new(),
            recursive: true,
            concurrency: 0,
        }
    }
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default)]
pub struct CompactRequest {
    #[serde(rename = "coversDir")]
    pub covers_dir: String,
    pub paths: Vec<String>,
    pub concurrency: usize,
}

#[derive(Debug, Clone, Serialize)]
pub struct FolderFact {
    pub path: String,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub title: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub artist: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub album: Option<String>,
    #[serde(skip_serializing_if = "Option::is_none")]
    pub duration: Option<f64>,
}
