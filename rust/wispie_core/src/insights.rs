//! Listening history aggregation used by the stats screen.

use chrono::{Datelike, Duration, NaiveDate};
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::{HashMap, HashSet};

#[derive(Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct Request {
    filenames: Vec<String>,
    songs: Vec<LibrarySong>,
    favorites: HashSet<String>,
    range: String,
    today: DateParts,
    epoch_local_day: DateParts,
    top_count: usize,
}

impl Default for Request {
    fn default() -> Self {
        Self {
            filenames: Vec::new(),
            songs: Vec::new(),
            favorites: HashSet::new(),
            range: "month".to_string(),
            today: DateParts::default(),
            epoch_local_day: DateParts::default(),
            top_count: 10,
        }
    }
}

#[derive(Deserialize, Default, Clone, Copy)]
#[serde(default)]
struct DateParts {
    year: i32,
    month: u32,
    day: u32,
}

#[derive(Default)]
struct Event {
    filename: String,
    timestamp_ms: i64,
    played_ms: i64,
    play_ratio: f64,
    year: i32,
    month: u32,
    day: u32,
    hour: usize,
    weekday: usize,
}

#[derive(Deserialize, Default)]
#[serde(default, rename_all = "camelCase")]
struct LibrarySong {
    filename: String,
    title: String,
    artist: String,
    album: String,
    cover_url: Option<String>,
}

#[derive(Default)]
struct Tally {
    plays: usize,
    millis: f64,
}

pub fn run(payload: Value, bytes: &[u8]) -> Result<Value, String> {
    let request: Request = serde_json::from_value(payload).map_err(|e| format!("insights: {e}"))?;
    const STRIDE: usize = 36;
    let (rows, remainder) = bytes.as_chunks::<STRIDE>();
    if !remainder.is_empty() {
        return Err("insights event payload is not a whole number of rows".to_string());
    }
    let mut events = Vec::with_capacity(rows.len());
    for row in rows {
        let filename_index = u32::from_le_bytes(row[0..4].try_into().unwrap()) as usize;
        let filename = request
            .filenames
            .get(filename_index)
            .ok_or_else(|| "insights event filename index is out of range".to_string())?;
        events.push(Event {
            filename: filename.clone(),
            timestamp_ms: i64::from_le_bytes(row[4..12].try_into().unwrap()),
            played_ms: i64::from_le_bytes(row[12..20].try_into().unwrap()),
            play_ratio: f64::from_le_bytes(row[20..28].try_into().unwrap()),
            year: i32::from_le_bytes(row[28..32].try_into().unwrap()),
            month: row[32] as u32,
            day: row[33] as u32,
            hour: row[34] as usize,
            weekday: row[35] as usize,
        });
    }
    let today = date(request.today)?;
    let epoch_day = date(request.epoch_local_day)?;
    let days = match request.range.as_str() {
        "week" => Some(7),
        "month" => Some(30),
        "quarter" => Some(90),
        "year" => Some(365),
        "allTime" => None,
        other => return Err(format!("unknown insights range: {other}")),
    };
    let window_start = match days {
        Some(days) => today - Duration::days((days - 1) as i64),
        None => epoch_day,
    };
    let window_end = today + Duration::days(1);
    let previous_start = days.map(|days| window_start - Duration::days(days as i64));
    let library: HashMap<String, LibrarySong> = request
        .songs
        .into_iter()
        .map(|song| (song.filename.clone(), song))
        .collect();

    events.sort_by_key(|event| event.timestamp_ms);
    let mut lifetime_days = HashSet::new();
    let mut active_days = HashSet::new();
    let mut unique_songs = HashSet::new();
    let mut discovered = HashSet::new();
    let mut artists = HashMap::<String, Tally>::new();
    let mut albums = HashMap::<(String, String), Tally>::new();
    let mut song_tally = HashMap::<String, Tally>::new();
    let mut hour_ms = [0.0f64; 24];
    let mut hour_plays = [0usize; 24];
    let mut weekday_ms = [0.0f64; 7];
    let mut weekday_plays = [0usize; 7];
    let mut day_ms = HashMap::<NaiveDate, f64>::new();
    let mut day_plays = HashMap::<NaiveDate, usize>::new();
    let mut plays = 0usize;
    let mut skips = 0usize;
    let mut listened_ms = 0.0f64;
    let mut previous_plays = 0usize;
    let mut previous_ms = 0.0f64;
    let mut favorite_plays = 0usize;
    let mut first_ms: Option<i64> = None;
    let mut last_ms: Option<i64> = None;
    for event in &events {
        let event_day = NaiveDate::from_ymd_opt(event.year, event.month, event.day)
            .ok_or_else(|| "invalid event date".to_string())?;
        lifetime_days.insert(event_day);
        first_ms = Some(first_ms.map_or(event.timestamp_ms, |value| value.min(event.timestamp_ms)));
        last_ms = Some(last_ms.map_or(event.timestamp_ms, |value| value.max(event.timestamp_ms)));
        let played = event.played_ms as f64;
        if previous_start.is_some_and(|start| event_day >= start && event_day < window_start) {
            previous_ms += played;
            if counts_as_play(event) {
                previous_plays += 1;
            }
        }
        if event_day < window_start || event_day >= window_end {
            continue;
        }
        listened_ms += played;
        active_days.insert(event_day);
        *day_ms.entry(event_day).or_default() += played;
        *day_plays.entry(event_day).or_default() += 1;
        if event.hour < 24 {
            hour_ms[event.hour] += played;
            hour_plays[event.hour] += 1;
        }
        if event.weekday < 7 {
            weekday_ms[event.weekday] += played;
            weekday_plays[event.weekday] += 1;
        }
        if is_skip(event) {
            skips += 1;
            continue;
        }
        if !counts_as_play(event) {
            continue;
        }
        plays += 1;
        unique_songs.insert(event.filename.as_str());
        tally(&mut song_tally, event.filename.clone(), played);
        let Some(song) = library.get(&event.filename) else {
            continue;
        };
        discovered.insert(event.filename.as_str());
        if request.favorites.contains(&event.filename) {
            favorite_plays += 1;
        }
        if real_name(&song.artist, "Unknown Artist") {
            tally(&mut artists, song.artist.clone(), played);
        }
        if real_name(&song.album, "Unknown Album") {
            tally(
                &mut albums,
                (song.album.clone(), song.artist.clone()),
                played,
            );
        }
    }

    let first_date = events
        .iter()
        .min_by_key(|event| event.timestamp_ms)
        .map(|event| {
            NaiveDate::from_ymd_opt(event.year, event.month, event.day)
                .ok_or_else(|| "invalid event date".to_string())
        })
        .transpose()?;
    let current_streak = current_streak(&lifetime_days, today);
    let longest_streak = longest_streak(&lifetime_days);
    let trend = build_trend(
        &request.range,
        today,
        window_start,
        first_date,
        &day_ms,
        &day_plays,
        &events,
    )?;
    let top_artists = rank_names(
        artists,
        request.top_count,
        |name, tally| json!({"name": name, "plays": tally.plays, "listenedMs": duration_ms(tally.millis)}),
    );
    let top_albums = rank_names(
        albums,
        request.top_count,
        |(name, artist), tally| json!({"name": name, "detail": if real_name(&artist, "Unknown Artist") { Some(artist) } else { None }, "plays": tally.plays, "listenedMs": duration_ms(tally.millis)}),
    );
    let top_songs = rank_names(song_tally, request.top_count, |filename, tally| {
        let song = library.get(&filename);
        let name = song
            .map(|song| song.title.clone())
            .unwrap_or_else(|| display_title(&filename));
        let artist = song.map(|song| song.artist.as_str());
        json!({ "name": name, "detail": artist.filter(|value| real_name(value, "Unknown Artist")), "filename": filename, "coverUrl": song.and_then(|s| s.cover_url.clone()), "plays": tally.plays, "listenedMs": duration_ms(tally.millis), "isFavorite": request.favorites.contains(&filename) })
    });

    Ok(json!({
        "range": request.range,
        "from": parts(window_start), "to": parts(today),
        "plays": plays, "skips": skips, "listenedMs": duration_ms(listened_ms),
        "uniqueSongs": unique_songs.len(), "discoveredInLibrary": discovered.len(),
        "librarySize": library.len(), "activeDays": active_days.len(),
        "currentStreak": current_streak, "longestStreak": longest_streak,
        "favoritePlays": favorite_plays, "firstPlayMs": first_ms, "lastPlayMs": last_ms,
        "byHour": (0..24).map(|i| json!({"index":i,"plays":hour_plays[i],"listenedMs":duration_ms(hour_ms[i])})).collect::<Vec<_>>(),
        "byWeekday": (0..7).map(|i| json!({"index":i,"plays":weekday_plays[i],"listenedMs":duration_ms(weekday_ms[i])})).collect::<Vec<_>>(),
        "trend": trend,
        "topArtists": top_artists, "topAlbums": top_albums, "topSongs": top_songs,
        "listenedTrend": {"current": (listened_ms / 1000.0).round() as i64, "previous": (previous_ms / 1000.0).round() as i64},
        "playsTrend": {"current": plays, "previous": previous_plays},
    }))
}

fn date(value: DateParts) -> Result<NaiveDate, String> {
    NaiveDate::from_ymd_opt(value.year, value.month, value.day)
        .ok_or_else(|| "invalid date".to_string())
}
fn parts(date: NaiveDate) -> Value {
    json!({"year":date.year(),"month":date.month(),"day":date.day()})
}
fn is_skip(event: &Event) -> bool {
    event.played_ms < 10_000 && event.play_ratio < 0.25
}
fn counts_as_play(event: &Event) -> bool {
    event.played_ms > 10_000 || event.play_ratio > 0.25
}
fn real_name(value: &str, sentinel: &str) -> bool {
    !value.trim().is_empty() && value.trim() != sentinel
}
fn tally<K: std::hash::Hash + Eq>(map: &mut HashMap<K, Tally>, key: K, millis: f64) {
    let value = map.entry(key).or_default();
    value.plays += 1;
    value.millis += millis;
}
fn duration_ms(millis: f64) -> i64 {
    millis.round() as i64
}
fn current_streak(days: &HashSet<NaiveDate>, today: NaiveDate) -> usize {
    let mut cursor = if days.contains(&today) {
        today
    } else {
        today - Duration::days(1)
    };
    if !days.contains(&cursor) {
        return 0;
    }
    let mut streak = 0;
    while days.contains(&cursor) {
        streak += 1;
        cursor -= Duration::days(1);
    }
    streak
}
fn longest_streak(days: &HashSet<NaiveDate>) -> usize {
    let mut ordered: Vec<_> = days.iter().copied().collect();
    ordered.sort();
    if ordered.is_empty() {
        return 0;
    }
    let (mut best, mut run) = (1, 1);
    for pair in ordered.windows(2) {
        if pair[1] - pair[0] == Duration::days(1) {
            run += 1;
        } else {
            run = 1;
        }
        best = best.max(run);
    }
    best
}
fn weekday_index(day: NaiveDate) -> usize {
    day.weekday().num_days_from_monday() as usize
}
fn weekday_name(index: usize) -> &'static str {
    [
        "Monday",
        "Tuesday",
        "Wednesday",
        "Thursday",
        "Friday",
        "Saturday",
        "Sunday",
    ][index]
}
fn month_name(month: u32) -> &'static str {
    [
        "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec",
    ][(month - 1) as usize]
}
fn date_caption(day: NaiveDate) -> String {
    format!(
        "{} {} {}",
        weekday_name(weekday_index(day)),
        day.day(),
        month_name(day.month())
    )
}
fn month_caption(day: NaiveDate) -> String {
    format!("{} {}", month_name(day.month()), day.year())
}

fn build_trend(
    range: &str,
    today: NaiveDate,
    start: NaiveDate,
    first: Option<NaiveDate>,
    day_ms: &HashMap<NaiveDate, f64>,
    day_plays: &HashMap<NaiveDate, usize>,
    _events: &[Event],
) -> Result<Vec<Value>, String> {
    let monthly = range == "year" || first.is_some_and(|date| (today - date).num_days() > 120);
    if !monthly {
        let mut points = Vec::new();
        let mut cursor = start;
        while cursor <= today {
            let label = if range == "week" {
                ["M", "T", "W", "T", "F", "S", "S"][weekday_index(cursor)].to_string()
            } else {
                cursor.day().to_string()
            };
            points.push(json!({"start":parts(cursor),"label":label,"caption":date_caption(cursor),"plays":day_plays.get(&cursor).copied().unwrap_or(0),"listenedMs":duration_ms(day_ms.get(&cursor).copied().unwrap_or(0.0))}));
            cursor += Duration::days(1);
        }
        return Ok(points);
    }
    let first_month =
        NaiveDate::from_ymd_opt(start.year(), start.month(), 1).ok_or("invalid month")?;
    let mut cursor = first_month;
    if start.year() <= 1971 {
        if let Some(first) = first {
            let month =
                NaiveDate::from_ymd_opt(first.year(), first.month(), 1).ok_or("invalid month")?;
            if month > cursor {
                cursor = month;
            }
        }
    }
    let last = NaiveDate::from_ymd_opt(today.year(), today.month(), 1).ok_or("invalid month")?;
    let mut points = Vec::new();
    while cursor <= last {
        let next = if cursor.month() == 12 {
            NaiveDate::from_ymd_opt(cursor.year() + 1, 1, 1)
        } else {
            NaiveDate::from_ymd_opt(cursor.year(), cursor.month() + 1, 1)
        }
        .ok_or("invalid next month")?;
        let mut millis = 0.0;
        let mut plays = 0;
        let mut day = cursor;
        while day < next {
            millis += day_ms.get(&day).copied().unwrap_or(0.0);
            plays += day_plays.get(&day).copied().unwrap_or(0);
            day += Duration::days(1);
        }
        points.push(json!({"start":parts(cursor),"label":month_name(cursor.month()),"caption":month_caption(cursor),"plays":plays,"listenedMs":duration_ms(millis)}));
        cursor = next;
    }
    Ok(points)
}

fn display_title(filename: &str) -> String {
    let base = filename.rsplit(['/', '\\']).next().unwrap_or(filename);
    match base.rfind('.') {
        Some(index) if index > 0 => base[..index].to_string(),
        _ => base.to_string(),
    }
}

trait LabelKey {
    fn label(&self) -> String;
}
impl LabelKey for String {
    fn label(&self) -> String {
        self.clone()
    }
}
impl LabelKey for (String, String) {
    fn label(&self) -> String {
        format!("{}|{}", self.0, self.1)
    }
}

fn rank_names<K, F>(map: HashMap<K, Tally>, limit: usize, build: F) -> Vec<Value>
where
    K: Ord + Clone + LabelKey,
    F: Fn(K, Tally) -> Value,
{
    let mut rows: Vec<(K, Tally)> = map.into_iter().collect();
    rows.sort_by(|(key_a, a), (key_b, b)| {
        b.plays
            .cmp(&a.plays)
            .then_with(|| key_a.label().cmp(&key_b.label()))
    });
    rows.into_iter()
        .take(limit)
        .map(|(key, tally)| build(key, tally))
        .collect()
}
