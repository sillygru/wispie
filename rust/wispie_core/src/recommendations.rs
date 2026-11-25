use std::collections::{HashMap, HashSet};

use serde::Deserialize;
use serde_json::{json, Value};

#[derive(Deserialize)]
#[serde(rename_all = "snake_case")]
pub enum Recommendation {
    QuickPicks,
    TopHits,
    FreshFinds,
    ForgottenFavorites,
    QuickRefresh,
    ArtistMix,
}

#[derive(Deserialize)]
pub struct RecommendationTrack {
    pub filename: String,
    #[serde(default)]
    pub artist: String,
    #[serde(default)]
    pub plays: u64,
    pub added: Option<f64>,
    #[serde(default)]
    pub favorite: bool,
    #[serde(default)]
    pub suggest_less: bool,
}

#[derive(Deserialize)]
pub struct RecommendationListen {
    pub filename: String,
    pub artist: Option<String>,
}

#[derive(Deserialize)]
pub struct RecommendationRefresh {
    pub now: f64,
    pub updated: Option<f64>,
    #[serde(default)]
    pub empty: bool,
    #[serde(default)]
    pub force: bool,
    #[serde(default)]
    pub pinned: bool,
    #[serde(default)]
    pub playing: bool,
    #[serde(default)]
    pub removed: bool,
}

impl RecommendationRefresh {
    pub fn should_refresh(&self) -> bool {
        !self.removed
            && !self.pinned
            && !self.playing
            && (self.force
                || self.empty
                || self
                    .updated
                    .is_none_or(|updated| self.now - updated > 86400.0))
    }
}

impl Recommendation {
    pub fn tracks<'a>(
        &self,
        tracks: &'a [RecommendationTrack],
        sessions: &[Vec<RecommendationListen>],
    ) -> Result<Vec<&'a str>, String> {
        let mut pool: Vec<_> = tracks.iter().collect();
        let limit = match self {
            Self::QuickPicks => {
                let mut ranked = with_random_keys(pool)?;
                let score = |track: &RecommendationTrack, roll: u64| {
                    (track.plays as f64 + 1.5).ln() * 2.0 + if track.favorite { 5.0 } else { 0.0 }
                        - if track.suggest_less { 10.0 } else { 0.0 }
                        + (roll as f64 / u64::MAX as f64) * 4.0
                };
                ranked.sort_by(|(a, a_key), (b, b_key)| {
                    score(b, *b_key).total_cmp(&score(a, *a_key))
                });
                return Ok(ranked
                    .into_iter()
                    .take(10)
                    .map(|(track, _)| track.filename.as_str())
                    .collect());
            }
            Self::TopHits => {
                pool.sort_by_key(|track| std::cmp::Reverse(track.plays));
                20
            }
            Self::FreshFinds => {
                pool.sort_by(|a, b| b.added.unwrap_or(0.0).total_cmp(&a.added.unwrap_or(0.0)));
                if pool.iter().take(20).all(|track| track.added.is_none()) {
                    return Ok(Vec::new());
                }
                20
            }
            Self::ForgottenFavorites => {
                let recent: HashSet<_> = sessions
                    .iter()
                    .take(5)
                    .flatten()
                    .map(|listen| listen.filename.as_str())
                    .collect();
                pool.retain(|track| {
                    (track.favorite || track.plays > 10)
                        && !recent.contains(track.filename.as_str())
                });
                return random_selection(pool);
            }
            Self::QuickRefresh => {
                pool.retain(|track| track.plays < 3);
                return random_selection(pool);
            }
            Self::ArtistMix => {
                let mut counts: HashMap<_, (usize, usize)> = HashMap::new();
                for (index, artist) in sessions
                    .iter()
                    .take(10)
                    .flatten()
                    .filter_map(|listen| listen.artist.as_deref())
                    .enumerate()
                {
                    counts.entry(artist).or_insert((0, index)).0 += 1;
                }
                let Some((top, _)) = counts.into_iter().max_by_key(|(_, count)| *count) else {
                    return Ok(Vec::new());
                };
                pool.retain(|track| track.artist == top);
                if pool.len() < 3 {
                    return Ok(Vec::new());
                }
                return random_selection(pool);
            }
        };
        Ok(pool
            .into_iter()
            .take(limit)
            .map(|track| track.filename.as_str())
            .collect())
    }
}

fn with_random_keys<T>(items: Vec<T>) -> Result<Vec<(T, u64)>, String> {
    let mut bytes = vec![0; items.len() * 8];
    getrandom::getrandom(&mut bytes).map_err(|error| error.to_string())?;
    Ok(items
        .into_iter()
        .zip(
            bytes
                .as_chunks::<8>()
                .0
                .iter()
                .copied()
                .map(u64::from_le_bytes),
        )
        .collect())
}

fn random_selection(tracks: Vec<&RecommendationTrack>) -> Result<Vec<&str>, String> {
    let mut ranked = with_random_keys(tracks)?;
    ranked.sort_by_key(|(_, key)| *key);
    Ok(ranked
        .into_iter()
        .take(20)
        .map(|(track, _)| track.filename.as_str())
        .collect())
}

pub(crate) fn run(payload: Value) -> Result<Value, String> {
    #[derive(Deserialize)]
    #[serde(tag = "op", rename_all = "snake_case")]
    enum Request {
        Refresh(RecommendationRefresh),
        Tracks {
            kind: Recommendation,
            songs: Vec<RecommendationTrack>,
            sessions: Vec<Vec<RecommendationListen>>,
        },
    }
    let request = serde_json::from_value(payload).map_err(|error| error.to_string())?;
    match request {
        Request::Refresh(refresh) => Ok(json!({ "refresh": refresh.should_refresh() })),
        Request::Tracks {
            kind,
            songs,
            sessions,
        } => Ok(json!({ "filenames": kind.tracks(&songs, &sessions)? })),
    }
}
