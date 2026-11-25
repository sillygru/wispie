//! Parsers for YouTube's InnerTube catalogue responses.
//!
//! The API reshuffles its containers regularly (`gridPlaylistRenderer` became
//! `lockupViewModel` on some layouts), so every reader here walks the JSON
//! instead of hardcoding a path, and ignores shapes it does not recognise.
//! Requests still belong to Dart, which owns the pooled HTTP client and the
//! session cookies; this module only turns a decoded response into rows.

use std::sync::OnceLock;

use regex::{Regex, RegexBuilder};
use serde::Serialize;
use serde_json::{json, Map, Value};

use crate::emitter::{Emit, Emitter};

const MUSIC_TYPE_LABELS: &[&str] = &[
    "song",
    "video",
    "music video",
    "single",
    "album",
    "ep",
    "playlist",
    "artist",
    "profile",
    "podcast",
    "episode",
];

const TRACK_TYPE_LABELS: &[&str] = &["song", "video", "music video"];

const LIKED_BROWSE_PLAYLIST_ID: &str = "LL";

/// A playable row. Durations cross the wire as milliseconds because that is
/// what `Duration` holds on the Dart side.
#[derive(Serialize, Clone)]
pub(crate) struct Item {
    pub(crate) video_id: String,
    pub(crate) title: String,
    pub(crate) artist: String,
    pub(crate) duration_ms: Option<i64>,
    pub(crate) thumbnail_url: Option<String>,
    pub(crate) position: usize,
    pub(crate) view_count_text: Option<String>,
}

impl Item {
    pub(crate) fn new(video_id: String, title: String, artist: String) -> Self {
        Self {
            video_id,
            title,
            artist,
            duration_ms: None,
            thumbnail_url: None,
            position: 0,
            view_count_text: None,
        }
    }
}

/// The place a catalogue row opens instead of playing.
#[derive(Serialize, Clone, Copy, PartialEq)]
#[serde(rename_all = "lowercase")]
enum ContainerKind {
    Album,
    Playlist,
    Artist,
}

#[derive(Serialize, Clone)]
struct Container {
    id: String,
    title: String,
    subtitle: String,
    thumbnail_url: Option<String>,
    kind: ContainerKind,
}

#[derive(Serialize, Clone)]
struct AccountPlaylist {
    id: String,
    title: String,
    item_count: Option<i64>,
    thumbnail_url: Option<String>,
}

pub fn run(payload: &Value, emitter: &Emitter) -> Result<(), String> {
    let action = payload
        .get("action")
        .and_then(|value| value.as_str())
        .ok_or_else(|| "youtube needs an action".to_string())?;
    let reply = match action {
        "select_stream" => {
            let formats: Vec<crate::youtube_stream::StreamFormat> =
                serde_json::from_value(payload["formats"].clone())
                    .map_err(|error| error.to_string())?;
            let video = payload["video"].as_bool().unwrap_or(false);
            json!({ "selection": crate::youtube_stream::select(&formats, video) })
        }
        "page_request" => {
            let fetched = payload["fetched"].as_i64().unwrap_or_default();
            let limit = payload["limit"].as_i64().unwrap_or_default();
            let used = payload["used"]
                .as_array()
                .map(Vec::as_slice)
                .unwrap_or_default();
            let body = page_request(payload.get("json"), fetched, limit, used);
            json!({ "body": body })
        }
        "catalogue_request" => {
            let body = payload["body"]
                .as_object()
                .ok_or("missing catalogue request body")?;
            let client = |field| payload[field].as_str().unwrap_or_default();
            let request = catalogue_request(
                body,
                client("client_name"),
                client("version"),
                client("origin"),
                client("user_agent"),
            );
            json!({ "payload": request })
        }
        "client_version" => json!({
            "version": payload["text"].as_str().and_then(client_version),
        }),
        "account_profile" => json!({ "profile": account_profile(payload.get("json")) }),
        "account_playlists" => json!({ "playlists": account_playlists(payload.get("json")) }),
        "playlist_videos" => json!({ "items": playlist_videos(payload.get("json")) }),
        "music_tracks" => json!({
            "items": music_tracks(
                payload.get("json"),
                payload.get("artist_hint").and_then(|value| value.as_str()),
            )
        }),
        "music_containers" => json!({
            "containers": music_containers(
                payload.get("json"),
                payload
                    .get("shelves_only")
                    .and_then(|value| value.as_bool())
                    .unwrap_or(false),
            )
        }),
        "sort_options" => json!({ "options": sort_options(payload.get("json")) }),
        "artist_header" => json!({ "header": artist_header(payload.get("json")) }),
        "collection_header" => json!({ "header": collection_header(payload.get("json")) }),
        "next_continuation" => json!({ "token": next_continuation(payload.get("json")) }),
        "artist_from_metadata" => json!({ "artist": artist_from_metadata(payload.get("node")) }),
        "clock" => json!({
            "seconds": payload
                .get("value")
                .and_then(|value| value.as_str())
                .and_then(parse_clock),
        }),
        "thumbnail" => json!({
            "url": payload
                .get("url")
                .and_then(|value| value.as_str())
                .map(|url| upscale_thumbnail_url(
                    url,
                    payload.get("size").and_then(|value| value.as_u64()).unwrap_or(720) as i32,
                )),
        }),
        "strip_topic" => json!({
            "value": strip_topic_suffix(
                payload
                    .get("value")
                    .and_then(|value| value.as_str())
                    .unwrap_or_default(),
            ),
        }),
        "strip_vl" => json!({
            "value": strip_vl(
                payload
                    .get("value")
                    .and_then(|value| value.as_str())
                    .unwrap_or_default(),
            ),
        }),
        "playable_title" => json!({
            "playable": is_playable_title(
                payload.get("value").and_then(|value| value.as_str()),
            ),
        }),
        "import_plan" => import_plan(payload)?,
        other => return Err(format!("unknown youtube action {other}")),
    };
    emitter.emit(Emit::Json(reply));
    Ok(())
}

// ---------------------------------------------------------------------------
// Walking
// ---------------------------------------------------------------------------

/// Visits every object in `root`, parents before children, siblings in document
/// order. Every reader below is built on this so a moved container costs a
/// missing row instead of a dead parser.
fn walk<'a>(root: &'a Value, visit: &mut impl FnMut(&'a Map<String, Value>)) {
    match root {
        Value::Object(map) => {
            visit(map);
            for value in map.values() {
                walk_children(value, visit);
            }
        }
        other => walk_children(other, visit),
    }
}

fn walk_children<'a>(node: &'a Value, visit: &mut impl FnMut(&'a Map<String, Value>)) {
    match node {
        Value::Object(_) => walk(node, visit),
        Value::Array(items) => {
            for item in items {
                walk_children(item, visit);
            }
        }
        _ => {}
    }
}

fn walk_map<'a>(map: &'a Map<String, Value>, visit: &mut impl FnMut(&'a Map<String, Value>)) {
    visit(map);
    for value in map.values() {
        walk_children(value, visit);
    }
}

fn map_of(value: Option<&Value>) -> Option<&Map<String, Value>> {
    match value {
        Some(Value::Object(map)) => Some(map),
        _ => None,
    }
}

/// Dart's `??`: a JSON null counts as absent, so the next candidate wins.
fn first_present<'a>(first: Option<&'a Value>, second: Option<&'a Value>) -> Option<&'a Value> {
    match first {
        None | Some(Value::Null) => second,
        other => other,
    }
}

fn field<'a>(node: Option<&'a Map<String, Value>>, key: &str) -> Option<&'a Value> {
    node.and_then(|map| map.get(key))
}

fn chained<'a>(node: Option<&'a Map<String, Value>>, key: &str) -> Option<&'a Map<String, Value>> {
    map_of(field(node, key))
}

fn at<'a>(node: Option<&'a Map<String, Value>>, key: &str) -> Option<&'a Value> {
    field(node, key)
}

/// InnerTube text fields are `{simpleText}`, `{runs: [{text}]}` or, in the newer
/// view models, `{content}`.
fn text_of(node: Option<&Value>) -> Option<String> {
    match node {
        Some(Value::String(text)) => {
            let trimmed = text.trim();
            if trimmed.is_empty() {
                None
            } else {
                Some(trimmed.to_string())
            }
        }
        Some(Value::Object(map)) => {
            for key in ["simpleText", "content", "text"] {
                if let Some(Value::String(value)) = map.get(key) {
                    let trimmed = value.trim();
                    if !trimmed.is_empty() {
                        return Some(trimmed.to_string());
                    }
                }
            }
            if let Some(Value::Array(runs)) = map.get("runs") {
                let mut buffer = String::new();
                for run in runs {
                    if let Value::Object(run) = run {
                        if let Some(text) = run.get("text") {
                            buffer.push_str(&stringify(text));
                        }
                    }
                }
                let trimmed = buffer.trim();
                if !trimmed.is_empty() {
                    return Some(trimmed.to_string());
                }
            }
            None
        }
        _ => None,
    }
}

/// Dart's `value?.toString()`: numbers and booleans print without quotes.
fn stringify(value: &Value) -> String {
    match value {
        Value::String(text) => text.clone(),
        Value::Null => "null".to_string(),
        other => other.to_string(),
    }
}

fn int_of(value: Option<&Value>) -> Option<i64> {
    match value {
        Some(Value::Number(number)) => number
            .as_i64()
            .or_else(|| number.as_f64().map(|float| float.round() as i64)),
        Some(other) => stringify(other).trim().parse::<i64>().ok(),
        None => None,
    }
}

/// Browse ids address a playlist as `VL<playlistId>`; stored ids are bare.
fn strip_vl(raw: &str) -> String {
    let value = raw.trim();
    if value.len() > 2 && value.starts_with("VL") {
        value[2..].to_string()
    } else {
        value.to_string()
    }
}

/// `Artist - Topic` is YouTube's auto-generated artist channel.
pub(crate) fn strip_topic_suffix(raw: &str) -> String {
    const SUFFIX: &str = " - topic";
    let value = raw.trim();
    if value.to_lowercase().ends_with(SUFFIX) {
        value[..value.len() - SUFFIX.len()].trim().to_string()
    } else {
        value.to_string()
    }
}

fn artist_of(node: Option<&Value>) -> String {
    text_of(node)
        .map(|text| strip_topic_suffix(&text))
        .unwrap_or_default()
}

fn is_playable_title(title: Option<&str>) -> bool {
    let Some(title) = title else {
        return false;
    };
    let lower = title.trim().to_lowercase();
    if lower.is_empty() {
        return false;
    }
    !lower.contains("deleted video") && !lower.contains("private video")
}

/// `3:52`, `1:02:03` -> seconds. Live streams and premieres read `LIVE`, so the
/// missing colon is what excludes them.
fn parse_clock(raw: &str) -> Option<i64> {
    let parts: Vec<&str> = raw.trim().split(':').collect();
    if parts.len() < 2 || parts.len() > 3 {
        return None;
    }
    let mut seconds = 0i64;
    for part in parts {
        let value = part.trim().parse::<i64>().ok()?;
        if value < 0 {
            return None;
        }
        seconds = seconds * 60 + value;
    }
    if seconds > 0 {
        Some(seconds)
    } else {
        None
    }
}

fn clock_pattern() -> &'static Regex {
    static CLOCK: OnceLock<Regex> = OnceLock::new();
    CLOCK.get_or_init(|| Regex::new(r"^\d{1,2}:\d{2}(?::\d{2})?$").expect("clock pattern"))
}

fn view_count_pattern() -> &'static Regex {
    static VIEWS: OnceLock<Regex> = OnceLock::new();
    VIEWS.get_or_init(|| {
        RegexBuilder::new(r"^[\d.,]+\s*[KMB]?\s*(?:plays?|views?)$")
            .case_insensitive(true)
            .build()
            .expect("view count pattern")
    })
}

fn relative_time_pattern() -> &'static Regex {
    static RELATIVE: OnceLock<Regex> = OnceLock::new();
    RELATIVE.get_or_init(|| {
        RegexBuilder::new(r"\b(?:ago|premiere[sd]?|watching)\b")
            .case_insensitive(true)
            .build()
            .expect("relative time pattern")
    })
}

fn best_image_url(node: Option<&Value>) -> Option<String> {
    let mut best: Option<String> = None;
    let mut best_size = -1i64;
    if let Some(node) = node {
        walk(node, &mut |map| {
            let Some(Value::String(url)) = map.get("url") else {
                return;
            };
            if url.is_empty() {
                return;
            }
            let size = int_of(map.get("width"))
                .or_else(|| int_of(map.get("height")))
                .unwrap_or(0);
            if size >= best_size {
                best = Some(url.clone());
                best_size = size;
            }
        });
    }
    best
}

fn count_of_text(text: &str) -> Option<i64> {
    static COUNT: OnceLock<Regex> = OnceLock::new();
    let pattern = COUNT.get_or_init(|| {
        RegexBuilder::new(r"([\d.,\s]+)\s*(video|track|song|item)")
            .case_insensitive(true)
            .build()
            .expect("count pattern")
    });
    let captures = pattern.captures(text)?;
    let digits: String = captures
        .get(1)?
        .as_str()
        .chars()
        .filter(char::is_ascii_digit)
        .collect();
    digits.parse::<i64>().ok()
}

fn count_in_node(node: Option<&Value>) -> Option<i64> {
    let node = node?;
    let mut found = None;
    walk(node, &mut |map| {
        if found.is_some() {
            return;
        }
        for value in map.values() {
            let text = match value {
                Value::String(text) => text.clone(),
                other => text_of(Some(other)).unwrap_or_default(),
            };
            if let Some(count) = count_of_text(&text) {
                found = Some(count);
                return;
            }
        }
    });
    found
}

fn clock_in_node(node: Option<&Value>) -> Option<i64> {
    let node = node?;
    let mut found = None;
    walk(node, &mut |map| {
        if found.is_some() {
            return;
        }
        for value in map.values() {
            let text = match value {
                Value::String(text) => text.clone(),
                other => text_of(Some(other)).unwrap_or_default(),
            };
            if clock_pattern().is_match(&text) {
                if let Some(parsed) = parse_clock(&text) {
                    found = Some(parsed);
                    return;
                }
            }
        }
    });
    found
}

fn in_music_types(label: &str) -> bool {
    MUSIC_TYPE_LABELS.contains(&label.to_lowercase().as_str())
}

fn in_track_types(label: &str) -> bool {
    TRACK_TYPE_LABELS.contains(&label.to_lowercase().as_str())
}

fn is_year(part: &str) -> bool {
    part.len() == 4 && part.chars().all(|c| c.is_ascii_digit())
}

fn container_kind_of(id: &str) -> Option<ContainerKind> {
    if id.starts_with("MPRE") {
        Some(ContainerKind::Album)
    } else if id.starts_with("VL") {
        Some(ContainerKind::Playlist)
    } else if id.starts_with("UC") {
        Some(ContainerKind::Artist)
    } else {
        None
    }
}

/// A row's artwork at a row's size. Catalogue URLs are tiny (`=w60-h60`), so
/// they are rewritten to the rendition a list row can actually use.
fn large_thumbnail(node: Option<&Value>) -> Option<String> {
    best_image_url(node).map(|url| upscale_thumbnail_url(&url, 320))
}

fn upscale_thumbnail_url(url: &str, size: i32) -> String {
    if url.is_empty() {
        return url.to_string();
    }
    static BOXED: OnceLock<Regex> = OnceLock::new();
    static SQUARE: OnceLock<Regex> = OnceLock::new();
    let boxed = BOXED.get_or_init(|| Regex::new(r"=w\d+-h\d+").expect("boxed size"));
    if boxed.is_match(url) {
        return boxed
            .replace(url, format!("=w{size}-h{size}").as_str())
            .to_string();
    }
    // Rust's regex has no look-ahead, so the delimiting `-` (or end of URL) is
    // captured and put back instead of asserted.
    let square = SQUARE.get_or_init(|| Regex::new(r"=s(\d+)(-|$)").expect("square size"));
    let Some(found) = square.captures(url) else {
        return url.to_string();
    };
    let whole = found.get(0).expect("match");
    let current = found
        .get(1)
        .and_then(|value| value.as_str().parse::<i32>().ok());
    if let Some(current) = current {
        if current >= size {
            return url.to_string();
        }
    }
    let delimiter = found.get(2).map(|value| value.as_str()).unwrap_or_default();
    format!(
        "{}=s{}{}{}",
        &url[..whole.start()],
        size,
        delimiter,
        &url[whole.end()..]
    )
}

/// A row's columns: `flexColumns[i].musicResponsiveListItemFlexColumnRenderer.text`.
fn flex_column(renderer: &Map<String, Value>, index: usize) -> Option<&Value> {
    let columns = match renderer.get("flexColumns") {
        Some(Value::Array(columns)) if columns.len() > index => columns,
        _ => return None,
    };
    chained(
        map_of(columns.get(index)),
        "musicResponsiveListItemFlexColumnRenderer",
    )
    .and_then(|flex| flex.get("text"))
}

fn play_button_content(renderer: &Map<String, Value>) -> Option<&Map<String, Value>> {
    chained(
        map_of(renderer.get("overlay")),
        "musicItemThumbnailOverlayRenderer",
    )
    .and_then(|overlay| chained(Some(overlay), "content"))
    .and_then(|content| chained(Some(content), "musicPlayButtonRenderer"))
}

/// The watch endpoint a renderer opens, or null when it opens a browse page.
fn watch_video_id(renderer: &Map<String, Value>) -> Option<String> {
    for candidate in [
        chained(map_of(renderer.get("navigationEndpoint")), "watchEndpoint"),
        play_button_content(renderer),
    ] {
        let Some(watch) = candidate else {
            continue;
        };
        if let Some(direct) = watch.get("videoId").map(stringify) {
            if !direct.is_empty() {
                return Some(direct);
            }
        }
        let nested = chained(map_of(watch.get("playNavigationEndpoint")), "watchEndpoint")
            .and_then(|endpoint| endpoint.get("videoId"))
            .map(stringify);
        if let Some(nested) = nested.filter(|nested| !nested.is_empty()) {
            return Some(nested);
        }
        let queued = at(map_of(watch.get("playlistItemData")), "videoId")
            .map(stringify)
            .filter(|queued| !queued.is_empty());
        if queued.is_some() {
            return queued;
        }
    }
    None
}

/// True unless the row labels itself as a container. Rows that label nothing are
/// kept: an untyped row predates the label and has always been playable.
fn is_track_row(renderer: &Map<String, Value>) -> bool {
    let Some(byline) = text_of(flex_column(renderer, 1)) else {
        return true;
    };
    let label = byline
        .split('•')
        .next()
        .unwrap_or_default()
        .trim()
        .to_lowercase();
    if !in_music_types(&label) {
        return true;
    }
    in_track_types(&label)
}

/// The music byline (`Artist • Album • 3:52`, or `Song • 4:11`), any part of
/// which may be absent.
struct Byline {
    artist: String,
    duration_ms: Option<i64>,
    view_count_text: Option<String>,
}

fn music_byline(node: Option<&Value>) -> Byline {
    let Some(text) = text_of(node) else {
        return Byline {
            artist: String::new(),
            duration_ms: None,
            view_count_text: None,
        };
    };
    let mut artist = String::new();
    let mut duration = None;
    let mut view_count = None;
    for raw in text.split('•') {
        let part = raw.trim();
        if part.is_empty() {
            continue;
        }
        if clock_pattern().is_match(part) {
            if duration.is_none() {
                duration = parse_clock(part);
            }
            continue;
        }
        if in_music_types(part) {
            continue;
        }
        if view_count_pattern().is_match(part) {
            if view_count.is_none() {
                view_count = Some(part.to_string());
            }
            continue;
        }
        if relative_time_pattern().is_match(part) || is_year(part) {
            continue;
        }
        if artist.is_empty() {
            artist = strip_topic_suffix(part);
        }
    }
    Byline {
        artist,
        duration_ms: duration.map(|seconds| seconds * 1000),
        view_count_text: view_count,
    }
}

/// The `Play <title> - <artist>` label on a row's play button: the only copy of
/// the artist on a search hit.
fn artist_from_play_label(node: Option<&Value>) -> String {
    let Some(node) = node else {
        return String::new();
    };
    let mut artist = String::new();
    walk(node, &mut |map| {
        if !artist.is_empty() {
            return;
        }
        let Some(label) = at(map_of(map.get("accessibilityData")), "label")
            .and_then(|label| text_of(Some(label)))
        else {
            return;
        };
        let Some(rest) = label.strip_prefix("Play ") else {
            return;
        };
        let parts: Vec<&str> = rest.split(" - ").collect();
        if parts.len() < 2 {
            return;
        }
        let stripped = strip_topic_suffix(parts[parts.len() - 1].trim());
        if !stripped.is_empty() {
            artist = stripped;
        }
    });
    artist
}

/// The page a row opens, if it opens one. A radio playlist (`RD...`) is a
/// playback queue rather than a place, so only `VL` ids count.
fn browse_id_of(renderer: &Map<String, Value>) -> Option<String> {
    let navigation = map_of(renderer.get("navigationEndpoint"));
    if let Some(browse) =
        chained(navigation, "browseEndpoint").and_then(|node| node.get("browseId"))
    {
        let browse = stringify(browse);
        if !browse.is_empty() {
            return Some(browse);
        }
    }

    // A search shelf row holds its page on the title text, not on the row. The
    // subtitle is never read: there it names the artist, not the row.
    if let Some(text_id) = browse_id_in_text(renderer.get("title"))
        .or_else(|| browse_id_in_text(flex_column(renderer, 0)))
    {
        return Some(text_id);
    }

    if let Some(playlist) = chained(navigation, "watchEndpoint")
        .and_then(|node| node.get("playlistId"))
        .map(stringify)
        .filter(|playlist| playlist.starts_with("VL"))
    {
        return Some(playlist);
    }

    let button = chained(play_button_content(renderer), "playNavigationEndpoint");
    if let Some(browse) = chained(button, "browseEndpoint").and_then(|node| node.get("browseId")) {
        let browse = stringify(browse);
        if !browse.is_empty() {
            return Some(browse);
        }
    }
    if let Some(playlist) = chained(button, "watchEndpoint")
        .and_then(|node| node.get("playlistId"))
        .map(stringify)
        .filter(|playlist| playlist.starts_with("VL"))
    {
        return Some(playlist);
    }

    let command = chained(
        chained(map_of(renderer.get("rendererContext")), "commandContext"),
        "onTap",
    );
    let inner = chained(command, "innertubeCommand");
    if let Some(browse) = chained(inner, "browseEndpoint").and_then(|node| node.get("browseId")) {
        let browse = stringify(browse);
        if !browse.is_empty() {
            return Some(browse);
        }
    }
    None
}

/// The first page link inside a text node, skipping ids the app cannot open.
fn browse_id_in_text(node: Option<&Value>) -> Option<String> {
    let node = node?;
    let mut found = None;
    walk(node, &mut |map| {
        if found.is_some() {
            return;
        }
        let Some(browse) = chained(map_of(map.get("navigationEndpoint")), "browseEndpoint")
            .and_then(|endpoint| endpoint.get("browseId"))
        else {
            return;
        };
        let browse = stringify(browse);
        if browse.is_empty() || container_kind_of(&browse).is_none() {
            return;
        }
        found = Some(browse);
    });
    found
}

// ---------------------------------------------------------------------------
// Items
// ---------------------------------------------------------------------------

fn item_from_playlist_video(renderer: &Map<String, Value>) -> Option<Item> {
    if matches!(renderer.get("isPlayable"), Some(Value::Bool(false))) {
        return None;
    }
    let id = renderer.get("videoId").map(stringify).unwrap_or_default();
    let title = text_of(renderer.get("title"));
    if id.is_empty() || !is_playable_title(title.as_deref()) {
        return None;
    }
    let mut item = Item::new(
        id,
        title.unwrap_or_default(),
        artist_of(first_present(
            renderer.get("shortBylineText"),
            renderer.get("longBylineText"),
        )),
    );
    item.duration_ms = text_of(renderer.get("lengthText"))
        .and_then(|text| parse_clock(&text))
        .map(|seconds| seconds * 1000);
    item.thumbnail_url = large_thumbnail(renderer.get("thumbnail"));
    Some(item)
}

fn item_from_video_renderer(renderer: &Map<String, Value>) -> Option<Item> {
    let id = renderer.get("videoId").map(stringify).unwrap_or_default();
    let title = text_of(renderer.get("title"));
    if id.is_empty() || !is_playable_title(title.as_deref()) {
        return None;
    }
    let mut item = Item::new(
        id,
        title.unwrap_or_default(),
        artist_of(first_present(
            first_present(
                renderer.get("shortBylineText"),
                renderer.get("longBylineText"),
            ),
            renderer.get("ownerText"),
        )),
    );
    item.duration_ms = text_of(first_present(
        renderer.get("lengthText"),
        renderer.get("thumbnailOverlayTimeStatusRenderer"),
    ))
    .and_then(|text| parse_clock(&text))
    .map(|seconds| seconds * 1000);
    item.thumbnail_url = large_thumbnail(renderer.get("thumbnail"));
    Some(item)
}

fn item_from_lockup(lockup_value: &Value, lockup: &Map<String, Value>) -> Option<Item> {
    let content_type = lockup
        .get("contentType")
        .map(|value| stringify(value).to_uppercase())
        .unwrap_or_default();
    if !content_type.contains("VIDEO") {
        return None;
    }
    let id = lockup.get("contentId").map(stringify).unwrap_or_default();
    if id.is_empty() {
        return None;
    }
    let metadata = map_of(lockup.get("metadata"))
        .and_then(|node| node.get("lockupMetadataViewModel"))
        .and_then(|node| map_of(Some(node)));
    let title = text_of(field(metadata, "title"));
    if !is_playable_title(title.as_deref()) {
        return None;
    }
    let mut item = Item::new(
        id,
        title.unwrap_or_default(),
        artist_from_metadata(field(metadata, "metadata")),
    );
    item.duration_ms = clock_in_node(Some(lockup_value)).map(|seconds| seconds * 1000);
    item.thumbnail_url = large_thumbnail(lockup.get("contentImage"));
    Some(item)
}

fn item_from_music_two_row(value: &Value, renderer: &Map<String, Value>) -> Option<Item> {
    let id = watch_video_id(renderer).unwrap_or_default();
    if id.is_empty() {
        return None;
    }
    let title = text_of(renderer.get("title"));
    if !is_playable_title(title.as_deref()) {
        return None;
    }
    let byline = music_byline(renderer.get("subtitle"));
    let mut item = Item::new(id, title.unwrap_or_default(), byline.artist);
    item.duration_ms = byline.duration_ms;
    item.view_count_text = byline.view_count_text;
    item.thumbnail_url = large_thumbnail(Some(value));
    Some(item)
}

fn item_from_music_responsive(value: &Value, renderer: &Map<String, Value>) -> Option<Item> {
    let id = watch_video_id(renderer)
        .or_else(|| at(map_of(renderer.get("playlistItemData")), "videoId").map(stringify))
        .unwrap_or_default();
    if id.is_empty() {
        return None;
    }
    // A search page mixes albums, playlists, artists, profiles, podcasts and
    // episodes into the same row renderer, and all of them carry a play button.
    if !is_track_row(renderer) {
        return None;
    }
    let title = text_of(flex_column(renderer, 0));
    if !is_playable_title(title.as_deref()) {
        return None;
    }

    // The metadata columns shift with the shelf, so each one is read for
    // whatever it happens to hold.
    let mut artist = String::new();
    let mut duration = None;
    let mut view_count = None;
    for column in 1..=4 {
        let byline = music_byline(flex_column(renderer, column));
        if artist.is_empty() {
            artist = byline.artist;
        }
        if duration.is_none() {
            duration = byline.duration_ms;
        }
        if view_count.is_none() {
            view_count = byline.view_count_text;
        }
    }
    if artist.is_empty() {
        artist = artist_from_play_label(renderer.get("overlay"));
    }
    if duration.is_none() {
        duration = clock_in_node(renderer.get("overlay")).map(|seconds| seconds * 1000);
    }

    let mut item = Item::new(id, title.unwrap_or_default(), artist);
    item.duration_ms = duration;
    item.view_count_text = view_count;
    item.thumbnail_url = large_thumbnail(Some(value));
    Some(item)
}

/// Channel name from a view model's metadata rows: the first row holds the
/// channel and then views/age, so counts and relative times are skipped.
fn artist_from_metadata(node: Option<&Value>) -> String {
    static METADATA_RELATIVE: OnceLock<Regex> = OnceLock::new();
    static METADATA_COUNT: OnceLock<Regex> = OnceLock::new();
    let relative = METADATA_RELATIVE.get_or_init(|| {
        RegexBuilder::new(r"\b(views?|watching|ago|premiere[sd]?)\b")
            .case_insensitive(true)
            .build()
            .expect("metadata relative")
    });
    let count = METADATA_COUNT.get_or_init(|| {
        RegexBuilder::new(r"^[\d.,]+[KMB]?$")
            .case_insensitive(true)
            .build()
            .expect("metadata count")
    });

    let Some(Value::Array(rows)) = field(map_of(node), "metadataRows") else {
        return String::new();
    };
    for row in rows {
        let Some(Value::Array(parts)) = field(map_of(Some(row)), "metadataParts") else {
            continue;
        };
        for part in parts {
            let Some(text) = at(map_of(Some(part)), "text").and_then(|text| text_of(Some(text)))
            else {
                continue;
            };
            if text.is_empty() || relative.is_match(&text) || count.is_match(&text) {
                continue;
            }
            return strip_topic_suffix(&text);
        }
    }
    String::new()
}

// ---------------------------------------------------------------------------
// Containers
// ---------------------------------------------------------------------------

fn container_from_music_card(value: &Value, renderer: &Map<String, Value>) -> Option<Container> {
    let id = browse_id_of(renderer)?;
    let kind = container_kind_of(&id)?;
    let title = text_of(renderer.get("title"))?;
    if title.is_empty() {
        return None;
    }

    // Only a card that labels itself a place; a song card links its artist in
    // the subtitle and must not turn into that artist.
    let subtitle = text_of(renderer.get("subtitle")).unwrap_or_default();
    let label = subtitle
        .split('•')
        .next()
        .unwrap_or_default()
        .trim()
        .to_lowercase();
    if !in_music_types(&label) || in_track_types(&label) {
        return None;
    }

    let parts: Vec<String> = subtitle
        .split('•')
        .map(|part| part.trim())
        .filter(|part| !part.is_empty() && !in_music_types(part))
        .map(|part| part.to_string())
        .collect();
    Some(Container {
        id,
        title,
        subtitle: parts.join(" • "),
        thumbnail_url: large_thumbnail(Some(value)),
        kind,
    })
}

fn container_from_music_two_row(value: &Value, renderer: &Map<String, Value>) -> Option<Container> {
    let id = browse_id_of(renderer)?;
    let kind = container_kind_of(&id)?;
    let title = text_of(renderer.get("title"))?;
    if title.is_empty() {
        return None;
    }
    Some(Container {
        id,
        title,
        subtitle: text_of(renderer.get("subtitle")).unwrap_or_default(),
        thumbnail_url: large_thumbnail(Some(value)),
        kind,
    })
}

fn container_from_music_responsive(
    value: &Value,
    renderer: &Map<String, Value>,
) -> Option<Container> {
    if is_track_row(renderer) {
        return None;
    }
    let id = browse_id_of(renderer)?;
    let kind = container_kind_of(&id)?;
    let title = text_of(flex_column(renderer, 0))?;
    if title.is_empty() {
        return None;
    }

    // The section above the row already names the kind, so `Album` is dropped
    // from the byline and the row reads `Aurora • 2016`.
    let mut parts: Vec<String> = Vec::new();
    for column in 1..=2 {
        let Some(text) = text_of(flex_column(renderer, column)) else {
            continue;
        };
        for raw in text.split('•') {
            let part = raw.trim();
            if part.is_empty() || in_music_types(part) {
                continue;
            }
            parts.push(part.to_string());
        }
    }
    Some(Container {
        id,
        title,
        subtitle: parts.join(" • "),
        thumbnail_url: large_thumbnail(Some(value)),
        kind,
    })
}

// ---------------------------------------------------------------------------
// Account
// ---------------------------------------------------------------------------

fn account_profile(json: Option<&Value>) -> Option<Value> {
    let json = json?;
    let mut profile = None;
    walk(json, &mut |node| {
        if profile.is_some() {
            return;
        }
        let Some(header) = map_of(node.get("activeAccountHeaderRenderer")) else {
            return;
        };
        let Some(title) = text_of(header.get("accountName")) else {
            return;
        };
        let channel_id = chained(map_of(header.get("navigationEndpoint")), "browseEndpoint")
            .and_then(|endpoint| endpoint.get("browseId"))
            .map(stringify)
            .unwrap_or_default();
        profile = Some(json!({
            "channel_id": channel_id,
            "title": title,
            "avatar_url": best_image_url(header.get("accountPhoto")),
        }));
    });
    profile
}

fn account_playlists(json: Option<&Value>) -> Vec<AccountPlaylist> {
    let Some(json) = json else {
        return Vec::new();
    };
    let mut result: Vec<AccountPlaylist> = Vec::new();
    let mut seen: Vec<String> = Vec::new();
    walk(json, &mut |node| {
        let playlist = match first_present(
            node.get("gridPlaylistRenderer"),
            node.get("playlistRenderer"),
        ) {
            Some(Value::Object(renderer)) => playlist_from_renderer(renderer),
            _ => map_of(node.get("lockupViewModel")).and_then(playlist_from_lockup),
        };
        let Some(playlist) = playlist else {
            return;
        };
        if playlist.id == LIKED_BROWSE_PLAYLIST_ID || seen.contains(&playlist.id) {
            return;
        }
        seen.push(playlist.id.clone());
        result.push(playlist);
    });
    result
}

fn playlist_from_renderer(renderer: &Map<String, Value>) -> Option<AccountPlaylist> {
    let id = playlist_id_of(renderer)?;
    let title = text_of(renderer.get("title"))?;
    let count = int_of(renderer.get("videoCount"))
        .or_else(|| text_of(renderer.get("videoCountText")).and_then(|text| count_of_text(&text)));
    Some(AccountPlaylist {
        id,
        title,
        item_count: count,
        thumbnail_url: best_image_url(renderer.get("thumbnail")),
    })
}

fn playlist_from_lockup(lockup: &Map<String, Value>) -> Option<AccountPlaylist> {
    let content_type = lockup
        .get("contentType")
        .map(|value| stringify(value).to_uppercase())
        .unwrap_or_default();
    if !content_type.contains("PLAYLIST") {
        return None;
    }
    let id = strip_vl(&lockup.get("contentId").map(stringify).unwrap_or_default());
    if id.is_empty() {
        return None;
    }
    let metadata = chained(map_of(lockup.get("metadata")), "lockupMetadataViewModel");
    let title = text_of(field(metadata, "title"))?;
    Some(AccountPlaylist {
        id,
        title,
        item_count: count_in_node(field(metadata, "metadata")),
        thumbnail_url: best_image_url(lockup.get("contentImage")),
    })
}

fn playlist_id_of(node: &Map<String, Value>) -> Option<String> {
    if let Some(Value::String(direct)) = node.get("playlistId") {
        if !direct.is_empty() {
            let id = strip_vl(direct);
            if !id.is_empty() {
                return Some(id);
            }
        }
    }
    let navigation = map_of(node.get("navigationEndpoint"));
    if let Some(Value::String(browse)) =
        chained(navigation, "browseEndpoint").and_then(|endpoint| endpoint.get("browseId"))
    {
        let id = strip_vl(browse);
        if !id.is_empty() {
            return Some(id);
        }
    }
    if let Some(Value::String(watch)) =
        chained(navigation, "watchEndpoint").and_then(|endpoint| endpoint.get("playlistId"))
    {
        if !watch.is_empty() {
            return Some(watch.clone());
        }
    }

    let command = chained(
        chained(map_of(node.get("rendererContext")), "commandContext"),
        "onTap",
    );
    let inner = chained(command, "innertubeCommand");
    if let Some(Value::String(watch)) =
        chained(inner, "watchEndpoint").and_then(|endpoint| endpoint.get("playlistId"))
    {
        if !watch.is_empty() {
            return Some(watch.clone());
        }
    }
    if let Some(Value::String(browse)) =
        chained(inner, "browseEndpoint").and_then(|endpoint| endpoint.get("browseId"))
    {
        let id = strip_vl(browse);
        if !id.is_empty() {
            return Some(id);
        }
    }
    None
}

// ---------------------------------------------------------------------------
// Page lists
// ---------------------------------------------------------------------------

fn playlist_videos(json: Option<&Value>) -> Vec<Item> {
    let Some(json) = json else {
        return Vec::new();
    };
    let mut result: Vec<Item> = Vec::new();
    let mut seen: Vec<String> = Vec::new();
    walk(json, &mut |node| {
        let item = match first_present(
            node.get("playlistVideoRenderer"),
            node.get("compactVideoRenderer"),
        ) {
            Some(Value::Object(renderer)) => item_from_playlist_video(renderer),
            _ => match node.get("videoRenderer") {
                Some(Value::Object(renderer)) => item_from_video_renderer(renderer),
                _ => match node.get("lockupViewModel") {
                    Some(value @ Value::Object(lockup)) => item_from_lockup(value, lockup),
                    _ => None,
                },
            },
        };
        let Some(item) = item else {
            return;
        };
        if seen.contains(&item.video_id) {
            return;
        }
        let position = result.len();
        seen.push(item.video_id.clone());
        let mut item = item;
        item.position = position;
        result.push(item);
    });
    result
}

fn music_tracks(json: Option<&Value>, artist_hint: Option<&str>) -> Vec<Item> {
    let Some(json) = json else {
        return Vec::new();
    };
    let mut result: Vec<Item> = Vec::new();
    let mut seen: Vec<String> = Vec::new();
    walk(json, &mut |node| {
        let item = match node.get("musicResponsiveListItemRenderer") {
            Some(value @ Value::Object(renderer)) => item_from_music_responsive(value, renderer),
            _ => match node.get("musicTwoRowItemRenderer") {
                Some(value @ Value::Object(renderer)) => item_from_music_two_row(value, renderer),
                _ => None,
            },
        };
        let Some(mut item) = item else {
            return;
        };
        if item.artist.is_empty() {
            if let Some(hint) = artist_hint.filter(|hint| !hint.is_empty()) {
                item.artist = strip_topic_suffix(hint);
            }
        }
        if seen.contains(&item.video_id) {
            return;
        }
        let position = result.len();
        seen.push(item.video_id.clone());
        item.position = position;
        result.push(item);
    });
    result
}

fn music_containers(json: Option<&Value>, shelves_only: bool) -> Vec<Container> {
    let Some(json) = json else {
        return Vec::new();
    };
    let mut result: Vec<Container> = Vec::new();
    let mut seen: Vec<String> = Vec::new();
    let mut visit = |node: &Map<String, Value>| {
        let container = match node.get("musicCardShelfRenderer") {
            Some(value @ Value::Object(card)) => container_from_music_card(value, card),
            _ => match node.get("musicTwoRowItemRenderer") {
                Some(value @ Value::Object(renderer)) => {
                    container_from_music_two_row(value, renderer)
                }
                _ => match node.get("musicResponsiveListItemRenderer") {
                    Some(value @ Value::Object(renderer)) => {
                        container_from_music_responsive(value, renderer)
                    }
                    _ => None,
                },
            },
        };
        let Some(container) = container else {
            return;
        };
        if seen.contains(&container.id) {
            return;
        }
        seen.push(container.id.clone());
        result.push(container);
    };

    if shelves_only {
        // The same page also carries discovery carousels (`you might also
        // like`), whose rows are answers to nothing the listener asked for.
        walk(json, &mut |node| {
            let card = node.get("musicCardShelfRenderer");
            let shelf = map_of(node.get("musicShelfRenderer"));
            if card.is_none() && shelf.is_none() {
                return;
            }
            if card.is_some() {
                visit(node);
            }
            if let Some(shelf) = shelf {
                walk_map(shelf, &mut visit);
            }
        });
    } else {
        walk(json, &mut visit);
    }
    result
}

fn sort_options(json: Option<&Value>) -> Vec<Value> {
    let Some(json) = json else {
        return Vec::new();
    };
    let mut result: Vec<(String, String, bool)> = Vec::new();
    let mut seen: Vec<String> = Vec::new();
    walk(json, &mut |node| {
        for (key, value) in node {
            if !key.to_lowercase().contains("sortfilterbutton") {
                continue;
            }
            let Some(renderer) = map_of(Some(value)) else {
                continue;
            };
            let label = text_of(renderer.get("title")).or_else(|| text_of(renderer.get("label")));
            let Some(label) = label.filter(|label| !label.is_empty()) else {
                continue;
            };
            if seen.contains(&label) {
                continue;
            }
            seen.push(label.clone());
            let selected = matches!(renderer.get("isSelected"), Some(Value::Bool(true)))
                || matches!(renderer.get("selected"), Some(Value::Bool(true)))
                || at(map_of(renderer.get("icon")), "iconType")
                    .map(|value| stringify(value) == "CHECK")
                    .unwrap_or(false);
            let params = renderer.get("params").map(stringify).unwrap_or_default();
            result.push((label, params, selected));
        }
    });
    // The chip YouTube marks as current leads, so the default label is the order
    // the songs arrived in.
    if let Some(index) = result.iter().position(|option| option.2) {
        if index > 0 {
            let selected = result.remove(index);
            result.insert(0, selected);
        }
    }
    result
        .into_iter()
        .map(|(label, params, selected)| {
            json!({ "label": label, "params": params, "selected": selected })
        })
        .collect()
}

fn artist_header(json: Option<&Value>) -> Value {
    const KEYS: &[&str] = &[
        "musicImmersiveHeaderRenderer",
        "musicVisualHeaderRenderer",
        "musicResponsiveHeaderRenderer",
        "musicDetailHeaderRenderer",
    ];
    let empty = json!({ "name": "", "thumbnail_url": null });
    let Some(json) = json else {
        return empty;
    };
    let mut header = None;
    walk(json, &mut |node| {
        if header.is_some() {
            return;
        }
        for key in KEYS {
            let Some(header_node) = map_of(node.get(*key)) else {
                continue;
            };
            let name = match text_of(header_node.get("title")) {
                Some(name) if !name.is_empty() => name,
                _ => continue,
            };
            header = Some(json!({
                "name": strip_topic_suffix(&name),
                "thumbnail_url": best_image_url(header_node.get("thumbnail"))
                    .or_else(|| best_image_url(header_node.get("foregroundThumbnail"))),
            }));
            return;
        }
    });
    header.unwrap_or(empty)
}

fn collection_header(json: Option<&Value>) -> Value {
    const KEYS: &[&str] = &[
        "musicResponsiveHeaderRenderer",
        "musicDetailHeaderRenderer",
        "musicEditablePlaylistDetailHeaderRenderer",
    ];
    let empty = json!({ "title": "", "artist": "", "thumbnail_url": null });
    let Some(json) = json else {
        return empty;
    };
    let mut header = None;
    walk(json, &mut |node| {
        if header.is_some() {
            return;
        }
        for key in KEYS {
            let Some(header_node) = map_of(node.get(*key)) else {
                continue;
            };
            let title = match text_of(header_node.get("title")) {
                Some(title) if !title.is_empty() => title,
                _ => continue,
            };
            let mut artist = String::new();
            for field_name in ["straplineTextOne", "subtitle", "subtitle2"] {
                let Some(byline) = text_of(header_node.get(field_name)) else {
                    continue;
                };
                for raw in byline.split('•') {
                    let part = raw.trim();
                    if part.is_empty()
                        || in_music_types(part)
                        || is_year(part)
                        || view_count_pattern().is_match(part)
                        || relative_time_pattern().is_match(part)
                    {
                        continue;
                    }
                    artist = strip_topic_suffix(part);
                    break;
                }
                if !artist.is_empty() {
                    break;
                }
            }
            header = Some(json!({
                "title": title,
                "artist": artist,
                "thumbnail_url": best_image_url(header_node.get("thumbnail")),
            }));
            return;
        }
    });
    header.unwrap_or(empty)
}

/// Continuation token for the next page, from either the current
/// `continuationItemRenderer` shape or the older `nextContinuationData` one.
fn next_continuation(json: Option<&Value>) -> Option<String> {
    let json = json?;
    let mut token = None;
    walk(json, &mut |node| {
        if token.is_some() {
            return;
        }
        if let Some(renderer) = map_of(node.get("continuationItemRenderer")) {
            let from_endpoint = chained(
                chained(Some(renderer), "continuationEndpoint"),
                "continuationCommand",
            )
            .and_then(|command| command.get("token"));
            if let Some(Value::String(value)) = from_endpoint {
                if !value.is_empty() {
                    token = Some(value.clone());
                    return;
                }
            }
            let from_button = chained(
                chained(chained(Some(renderer), "button"), "buttonRenderer"),
                "command",
            )
            .and_then(|command| chained(Some(command), "continuationCommand"))
            .and_then(|command| command.get("token"));
            if let Some(Value::String(value)) = from_button {
                if !value.is_empty() {
                    token = Some(value.clone());
                    return;
                }
            }
        }
        if let Some(legacy) = map_of(node.get("nextContinuationData")) {
            if let Some(Value::String(value)) = legacy.get("continuation") {
                if !value.is_empty() {
                    token = Some(value.clone());
                }
            }
        }
    });
    token
}

// ---------------------------------------------------------------------------
// Import planning
// ---------------------------------------------------------------------------

pub(crate) fn item_from_wire(value: &Value) -> Option<Item> {
    let map = map_of(Some(value))?;
    let video_id = map.get("video_id").map(stringify)?;
    let mut item = Item::new(
        video_id,
        map.get("title").map(stringify).unwrap_or_default(),
        map.get("artist").map(stringify).unwrap_or_default(),
    );
    item.duration_ms = int_of(map.get("duration_ms"));
    item.thumbnail_url = map
        .get("thumbnail_url")
        .and_then(|value| value.as_str())
        .map(|url| url.to_string());
    item.position = int_of(map.get("position")).unwrap_or(0).max(0) as usize;
    item.view_count_text = map
        .get("view_count_text")
        .and_then(|value| value.as_str())
        .map(|text| text.to_string());
    Some(item)
}

/// Additive on purpose: a sync never removes a track the user might have meant
/// to keep, so a playlist reorganised on YouTube can only grow here.
fn import_plan(payload: &Value) -> Result<Value, String> {
    let remote = payload
        .get("items")
        .and_then(|value| value.as_array())
        .ok_or_else(|| "import plan needs items".to_string())?;
    let local: Vec<String> = payload
        .get("local_ids")
        .and_then(|value| value.as_array())
        .map(|ids| ids.iter().map(stringify).collect())
        .unwrap_or_default();
    let max_new = payload
        .get("max_new_items")
        .and_then(|value| value.as_u64())
        .unwrap_or(600) as usize;

    let mut seen: Vec<String> = Vec::new();
    let mut to_add: Vec<Item> = Vec::new();
    let mut already_local: Vec<Item> = Vec::new();
    let mut skipped = 0usize;
    for entry in remote {
        let Some(item) = item_from_wire(entry) else {
            continue;
        };
        if seen.contains(&item.video_id) {
            continue;
        }
        seen.push(item.video_id.clone());
        if local.contains(&item.video_id) {
            already_local.push(item);
            continue;
        }
        if to_add.len() >= max_new {
            skipped += 1;
            continue;
        }
        to_add.push(item);
    }
    Ok(json!({
        "to_add": to_add,
        "already_local": already_local,
        "skipped_for_limit": skipped,
    }))
}

pub fn page_request(
    response: Option<&Value>,
    fetched: i64,
    limit: i64,
    used: &[Value],
) -> Option<Value> {
    if fetched >= limit {
        return None;
    }
    let token = next_continuation(response)?;
    if used
        .iter()
        .any(|value| value.as_str() == Some(token.as_str()))
    {
        return None;
    }
    Some(json!({ "continuation": token }))
}

pub fn catalogue_request(
    body: &Map<String, Value>,
    client_name: &str,
    version: &str,
    origin: &str,
    user_agent: &str,
) -> Value {
    let context = json!({
        "client": {
            "clientName": client_name,
            "clientVersion": version,
            "hl": "en",
            "gl": "US",
            "userAgent": user_agent,
            "originalUrl": format!("{origin}/"),
            "platform": "DESKTOP",
        },
        "user": { "lockedSafetyMode": false },
        "request": { "useSsl": true },
    });
    let mut payload = Map::new();
    payload.insert("context".to_string(), context);
    payload.extend(body.clone());
    Value::Object(payload)
}

fn client_version(text: &str) -> Option<&str> {
    static VERSION: OnceLock<Regex> = OnceLock::new();
    let pattern = VERSION.get_or_init(|| {
        Regex::new(r#"INNERTUBE_CLIENT_VERSION"?\s*:\s*"?([0-9.]+)"#)
            .expect("constant version regex")
    });
    pattern.captures(text)?.get(1).map(|value| value.as_str())
}
