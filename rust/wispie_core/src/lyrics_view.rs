//! Lyric timing offsets, active lines, and LRCLIB queries.
//!
//! All of it is pure: no clock, no I/O, no Flutter types.

pub const TIMING_MAX_SECONDS: f64 = 60.0;
pub const TIMING_QUANTIZE_STEP: f64 = 0.01;

const WORD_LEAD_TOLERANCE_US: i64 = 1_000_000;
const WORD_SPAN_LIMIT_US: i64 = 120_000_000;

pub fn clamp_offset(seconds: f64) -> f64 {
    seconds.clamp(-TIMING_MAX_SECONDS, TIMING_MAX_SECONDS)
}

/// Holds an offset on a grid step and inside the ±60s range.
///
/// Dividing by the reciprocal, rather than multiplying back by the step, keeps
/// every stored value exactly the number the readout prints.
pub fn quantize_offset(seconds: f64, step: f64) -> f64 {
    if step <= 0.0 {
        return clamp_offset(seconds);
    }
    let steps = (seconds / step).round();
    clamp_offset(steps / (1.0 / step).round())
}

pub fn nudge_offset(current: f64, steps: f64) -> f64 {
    quantize_offset(current + steps, TIMING_QUANTIZE_STEP)
}

pub fn offset_micros(seconds: f64) -> i64 {
    (seconds * 1_000_000.0).round() as i64
}

pub fn apply_offset(position_us: i64, offset_seconds: f64) -> i64 {
    position_us - offset_micros(offset_seconds)
}

pub fn undo_offset(lyric_us: i64, offset_seconds: f64) -> i64 {
    lyric_us + offset_micros(offset_seconds)
}

pub fn sync_offset_us(position_us: i64, active_line_us: Option<i64>) -> Option<f64> {
    let active = active_line_us?;
    Some(quantize_offset(
        (position_us - active) as f64 / 1_000_000.0,
        TIMING_QUANTIZE_STEP,
    ))
}

/// One line's timing, resolved from its words where they can be trusted.
#[derive(Clone, Copy, Debug)]
pub struct LineTiming {
    pub timed: bool,
    pub line_start_us: i64,
    pub word_start_us: Option<i64>,
    pub word_end_us: Option<i64>,
    pub simulated: bool,
}

impl LineTiming {
    fn trusts_words(self, simulate_enabled: bool) -> bool {
        self.word_start_us.is_some()
            && self.word_end_us.is_some()
            && (!self.simulated || simulate_enabled)
    }

    pub fn start_for(self, simulate_enabled: bool) -> i64 {
        if self.trusts_words(simulate_enabled) {
            self.word_start_us.unwrap_or(self.line_start_us)
        } else {
            self.line_start_us
        }
    }

    pub fn end_for(self, simulate_enabled: bool) -> Option<i64> {
        if self.trusts_words(simulate_enabled) {
            self.word_end_us
        } else {
            None
        }
    }
}

/// Packs a line so the view can select timings without crossing the ABI again.
///
/// Columns: timed, line start, start with simulated words, start without,
/// end with simulated words (-1 none), end without, simulated flag. Both
/// readings are resolved here so the Dart side only ever selects a column.
pub fn pack_timing(timing: LineTiming) -> [i64; 7] {
    [
        i64::from(timing.timed),
        timing.line_start_us,
        timing.start_for(true),
        timing.start_for(false),
        timing.end_for(true).unwrap_or(-1),
        timing.end_for(false).unwrap_or(-1),
        i64::from(timing.simulated),
    ]
}

/// Words must march forward, belong to their line's moment, and last a
/// plausible time. Anything else is a mis-parse.
pub fn words_are_trustworthy(line_start_us: i64, starts: &[i64], ends: &[i64]) -> bool {
    if starts.is_empty() || starts.len() != ends.len() {
        return false;
    }
    let mut previous = 0i64;
    let mut advances = false;
    for (start, end) in starts.iter().zip(ends.iter()) {
        if *start < 0 || *end < *start {
            return false;
        }
        if *start < previous {
            return false;
        }
        if *end > *start {
            advances = true;
        }
        previous = *start;
    }
    if !advances {
        return false;
    }
    if starts[0] < line_start_us - WORD_LEAD_TOLERANCE_US {
        return false;
    }
    ends[ends.len() - 1] - starts[0] <= WORD_SPAN_LIMIT_US
}

pub fn resolve_timing(
    line_start_us: i64,
    timed: bool,
    starts: Option<&[i64]>,
    ends: Option<&[i64]>,
    simulated: bool,
) -> LineTiming {
    let (start, end, usable) = match (starts, ends) {
        (Some(starts), Some(ends)) if words_are_trustworthy(line_start_us, starts, ends) => {
            (Some(starts[0]), Some(ends[ends.len() - 1]), true)
        }
        _ => (None, None, false),
    };
    LineTiming {
        timed,
        line_start_us,
        word_start_us: if usable { start } else { None },
        word_end_us: if usable { end } else { None },
        simulated,
    }
}

// ---------------------------------------------------------------------------
// LRCLIB query cleanup
// ---------------------------------------------------------------------------

const NOISE_WORDS: [&str; 13] = [
    "official",
    "audio",
    "video",
    "lyric",
    "visualizer",
    "visualiser",
    "explicit",
    "remaster",
    "hd",
    "hq",
    "4k",
    "mv",
    "prod",
];

fn bracket_group() -> &'static regex::Regex {
    static GROUPS: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
    GROUPS.get_or_init(|| regex::Regex::new(r"[\(\[]([^\)\]]*)[\)\]]").unwrap())
}

fn artist_prefix() -> &'static regex::Regex {
    static PREFIX: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
    PREFIX.get_or_init(|| regex::Regex::new(r"^(.*?)\s*[-\u{2013}\u{2014}:|]\s*(.+)$").unwrap())
}

fn edge_separators() -> &'static regex::Regex {
    static EDGES: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
    EDGES.get_or_init(|| {
        regex::Regex::new(r"^[-\u{2013}\u{2014}:|\s]+|[-\u{2013}\u{2014}:|\s]+$").unwrap()
    })
}

fn upload_prefix() -> &'static regex::Regex {
    static UPLOAD: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
    UPLOAD.get_or_init(|| regex::Regex::new(r"^(.{2,60}?)\s+[-\u{2013}\u{2014}]\s+(.+)$").unwrap())
}

fn non_word() -> &'static regex::Regex {
    static NON_WORD: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
    NON_WORD.get_or_init(|| regex::Regex::new(r"[^\w\s]").unwrap())
}

fn whitespace() -> &'static regex::Regex {
    static SPACE: std::sync::OnceLock<regex::Regex> = std::sync::OnceLock::new();
    SPACE.get_or_init(|| regex::Regex::new(r"\s+").unwrap())
}

fn normalize(value: &str) -> String {
    let lowered = value.to_lowercase();
    let stripped = non_word().replace_all(&lowered, " ");
    whitespace().replace_all(stripped.trim(), " ").to_string()
}

fn collapse(value: &str) -> String {
    let spaced = whitespace().replace_all(value, " ");
    edge_separators().replace_all(&spaced, "").to_string()
}

pub fn clean_search_title(title: &str, artist: Option<&str>) -> String {
    let mut result = bracket_group()
        .replace_all(title, |caps: &regex::Captures| {
            let inner = caps[1].to_lowercase();
            if NOISE_WORDS.iter().any(|word| inner.contains(*word)) {
                String::new()
            } else {
                caps[0].to_string()
            }
        })
        .to_string();

    let artist = artist.map(str::trim).unwrap_or("");
    if !artist.is_empty() {
        if let Some(caps) = artist_prefix().captures(&result) {
            if normalize(&caps[1]) == normalize(artist) {
                result = caps[2].to_string();
            }
        }
    }

    let cleaned = collapse(&result);
    if cleaned.is_empty() {
        title.trim().to_string()
    } else {
        cleaned
    }
}

/// One way to ask a lyrics provider for a track.
pub struct LyricsQuery {
    pub title: String,
    pub artist: Option<String>,
}

pub fn queries_for(title: &str, artist: &str, remote: bool) -> Vec<LyricsQuery> {
    let raw_title = title.trim();
    if raw_title.is_empty() {
        return Vec::new();
    }
    let raw_artist = artist.trim();
    let mut queries: Vec<LyricsQuery> = Vec::new();
    let mut seen: Vec<String> = Vec::new();

    let mut add = |candidate_title: &str, candidate_artist: Option<&str>| {
        let clean_title = candidate_title.trim();
        if clean_title.is_empty() {
            return;
        }
        let clean_artist = candidate_artist.unwrap_or("").trim();
        let key = format!("{}|{}", normalize(clean_title), normalize(clean_artist));
        if seen.contains(&key) {
            return;
        }
        seen.push(key);
        queries.push(LyricsQuery {
            title: clean_title.to_string(),
            artist: (!clean_artist.is_empty()).then(|| clean_artist.to_string()),
        });
    };

    if remote {
        if let Some(caps) = upload_prefix().captures(raw_title) {
            let prefix = caps[1].trim();
            let rest = caps[2].trim();
            let rest_title = clean_search_title(rest, None);
            add(&rest_title, Some(prefix));
            add(&rest_title, None);
            if !raw_artist.is_empty() {
                add(&rest_title, Some(raw_artist));
            }
        }
    }

    let plain = clean_search_title(raw_title, Some(raw_artist));
    add(&plain, Some(raw_artist));
    if remote {
        add(&plain, None);
    }
    queries
}
