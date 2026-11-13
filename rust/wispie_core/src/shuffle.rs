use serde_json::{json, Value};

pub fn score_candidates(request: &Value) -> Value {
    let weights = request.get("weights").unwrap_or(&Value::Null);
    let candidates = request
        .get("candidates")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    json!({"scores": candidates.iter().map(|candidate| score(candidate, weights)).collect::<Vec<_>>()})
}

pub fn select_seed(request: &Value) -> Value {
    let scores = request
        .get("scores")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    if scores.is_empty() {
        return json!({"index": Value::Null});
    }
    let total = scores
        .iter()
        .map(|value| value.as_f64().unwrap_or(0.0))
        .sum::<f64>();
    let index = if total <= 0.0 {
        request
            .get("fallbackIndex")
            .and_then(Value::as_u64)
            .unwrap_or(0) as usize
            % scores.len()
    } else {
        sample_index(
            &scores,
            request.get("draw").and_then(Value::as_f64).unwrap_or(0.0),
        )
    };
    json!({"index": index})
}

pub fn fallback_weights(request: &Value) -> Value {
    let anti_repeat = boolean(request, "antiRepeatEnabled");
    let streak = boolean(request, "streakBreakerEnabled");
    json!({
        "affinityExponent": 1.2,
        "noveltyBoost": 0.25,
        "repeatAversion": if anti_repeat { 0.8 } else { 0.0 },
        "skipAversion": 0.45,
        "burnoutDamping": 1.0,
        "artistSpacing": if streak { 5 } else { 0 },
        "albumSpacing": if streak { 4 } else { 0 },
        "favoriteBoost": number(request, "favoriteMultiplier"),
        "suggestLessPenalty": number(request, "suggestLessMultiplier"),
        "playlistBoost": 1.0,
        "historyLimit": integer(request, "historyLimit"),
    })
}

pub fn order_queue(request: &Value) -> Value {
    let items = request
        .get("items")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    if items.len() <= 1 {
        return json!({"order": (0..items.len()).collect::<Vec<_>>()});
    }
    let draws = request
        .get("draws")
        .and_then(Value::as_array)
        .cloned()
        .unwrap_or_default();
    let mut keys = Vec::with_capacity(items.len());
    for (index, item) in items.iter().enumerate() {
        let score = item
            .get("score")
            .and_then(Value::as_f64)
            .filter(|value| value.is_finite() && *value > 0.0)
            .unwrap_or(1e-12);
        let draw = draws.get(index).and_then(Value::as_f64).unwrap_or(0.5);
        let unit = draw.max(1e-12);
        keys.push(-unit.ln() / score);
    }
    let sort_keys = keys
        .iter()
        .map(|key| key.to_bits() as i64)
        .collect::<Vec<_>>();
    let mut order = (0..items.len()).collect::<Vec<_>>();
    crate::queue_ops::dart_sort::sort_by_key(&mut order, &sort_keys);
    let ordered_artists = items
        .iter()
        .map(|item| norm(string(item, "artist")))
        .collect::<Vec<_>>();
    let ordered_albums = items
        .iter()
        .map(|item| norm(string(item, "album")))
        .collect::<Vec<_>>();
    apply_spacing(
        &mut order,
        &ordered_artists,
        &ordered_albums,
        integer(request, "artistSpacing"),
        integer(request, "albumSpacing"),
        request.get("lastArtist").and_then(Value::as_str),
        request.get("lastAlbum").and_then(Value::as_str),
    );
    json!({"order": order})
}

pub fn smart_weights(request: &Value) -> Value {
    let pool = array(request, "pool");
    if pool.is_empty() {
        return json!({"weights": []});
    }
    let taste = request.get("taste").unwrap_or(&Value::Null);
    let familiarity = number(request, "familiarity");
    let f = if familiarity.is_finite() {
        familiarity.clamp(0.0, 1.0)
    } else {
        0.65
    };
    let mut artist_keys = Vec::<String>::new();
    let mut artist_indices = std::collections::HashMap::<String, usize>::new();
    let mut members = Vec::<Vec<usize>>::new();
    let mut favorited = std::collections::HashSet::<String>::new();
    for (index, candidate) in pool.iter().enumerate() {
        let key = string(candidate, "artistKey").to_owned();
        let artist_index = *artist_indices.entry(key.clone()).or_insert_with(|| {
            artist_keys.push(key.clone());
            members.push(Vec::new());
            artist_keys.len() - 1
        });
        members[artist_index].push(index);
        if boolean(candidate, "isFavorite") {
            favorited.insert(key);
        }
    }

    let mut buckets = Vec::with_capacity(artist_keys.len());
    let mut present = [false; 3];
    for key in &artist_keys {
        let artist = object(taste, "artists").get(key).unwrap_or(&Value::Null);
        let bucket = if number(artist, "trendMass") > 0.0 {
            0
        } else if favorited.contains(key) || number(artist, "longMass") > 0.0 {
            1
        } else {
            2
        };
        buckets.push(bucket);
        present[bucket] = true;
    }
    let raw_shares = [
        lerp(0.60, 0.97, f),
        lerp(0.25, 0.03, f),
        lerp(0.15, 0.0, f).max(1e-4),
    ];
    let share_total = (0..3)
        .filter(|bucket| present[*bucket])
        .map(|bucket| raw_shares[bucket])
        .sum::<f64>();
    let shares = raw_shares.map(|share| share / share_total);

    let g = lerp(0.7, 1.5, f);
    let current_artist_key = string(request, "currentArtistKey");
    let artist_co_row = object(taste, "artistCoPlay")
        .get(current_artist_key)
        .unwrap_or(&Value::Null);
    let mut artist_mass = vec![0.0; artist_keys.len()];
    let mut bucket_total = [0.0; 3];
    let mut bucket_count = [0usize; 3];
    for (artist_index, key) in artist_keys.iter().enumerate() {
        let bucket = buckets[artist_index];
        let artist = object(taste, "artists").get(key).unwrap_or(&Value::Null);
        let favorites = members[artist_index]
            .iter()
            .filter(|index| boolean(&pool[**index], "isFavorite"))
            .count();
        let mut mass = match bucket {
            0 => number(artist, "trendMass").powf(g),
            1 => (number(artist, "longMass") + 0.5 * favorites as f64).powf(g),
            _ => (members[artist_index].len() as f64).sqrt(),
        };
        mass *= 1.0 + 0.5 * number(artist_co_row, key);
        if !mass.is_finite() || mass < 0.0 {
            mass = 0.0;
        }
        artist_mass[artist_index] = mass;
        bucket_total[bucket] += mass;
        bucket_count[bucket] += 1;
    }

    let prior = lerp(0.35, 0.08, f);
    let freshness_boost = lerp(0.06, 0.30, 1.0 - f);
    let anti_repeat = string(request, "context") != "sort" && integer(request, "historyLimit") > 0;
    let history = object(request, "historyIndex");
    let songs = object(taste, "songs");
    let newness = object(taste, "newness");
    let mut weights = vec![0.0; pool.len()];
    for (artist_index, candidates) in members.iter().enumerate() {
        let bucket = buckets[artist_index];
        let p_artist = if bucket_total[bucket] > 0.0 && artist_mass[artist_index] > 0.0 {
            artist_mass[artist_index] / bucket_total[bucket]
        } else {
            1.0 / bucket_count[bucket] as f64
        };
        let signals = candidates
            .iter()
            .map(|index| signals_of(&pool[*index], songs, newness))
            .collect::<Vec<_>>();
        let max_trend = signals
            .iter()
            .map(|signal| signal.trend)
            .fold(0.0, f64::max);
        let max_long = signals.iter().map(|signal| signal.long).fold(0.0, f64::max);
        let mut raw = Vec::with_capacity(candidates.len());
        for (offset, index) in candidates.iter().enumerate() {
            let candidate = &pool[*index];
            let signal = &signals[offset];
            let mut score = (if max_trend > 0.0 {
                0.6 * signal.trend / max_trend
            } else {
                0.0
            }) + (if max_long > 0.0 {
                0.4 * signal.long / max_long
            } else {
                0.0
            }) + prior;
            score *= 1.0 + freshness_boost * signal.freshness;
            score *= (1.0 - signal.skip_rate * 0.3).clamp(0.2, 1.0);
            score /= 1.0 + signal.saturation;
            if anti_repeat {
                if let Some(history_index) = min_history(candidate, history) {
                    let proximity =
                        1.0 - history_index as f64 / integer(request, "historyLimit") as f64;
                    score *= 1.0 - (0.85 * proximity).clamp(0.0, 0.98);
                }
            }
            if boolean(candidate, "isFavorite") {
                score *= number(request, "favoriteMultiplier");
            }
            if boolean(candidate, "isSuggestLess") {
                score *= number(request, "suggestLessMultiplier");
            }
            if boolean(candidate, "isInPlaylist") {
                score *= 1.1;
            }
            raw.push(if score.is_finite() && score > 0.0 {
                score
            } else {
                0.0
            });
        }
        let sum = raw.iter().sum::<f64>();
        for (offset, index) in candidates.iter().enumerate() {
            let p_song = if sum > 0.0 {
                raw[offset] / sum
            } else {
                1.0 / candidates.len() as f64
            };
            let weight = shares[bucket] * p_artist * p_song;
            weights[*index] = if weight.is_finite() && weight > 1e-12 {
                weight
            } else {
                1e-12
            };
        }
    }
    json!({"weights": weights})
}

pub fn smart_spacing(request: &Value) -> Value {
    if !boolean(request, "streakBreakerEnabled") || array(request, "pool").is_empty() {
        return json!({"artist": 0, "album": 0});
    }
    let pool = array(request, "pool");
    let weights = array(request, "weights");
    let taste = request.get("taste").unwrap_or(&Value::Null);
    let buckets = classify_artists(pool, taste);
    let mut artist_mass = Vec::<(String, f64)>::new();
    let mut album_mass = Vec::<(String, f64)>::new();
    for (index, candidate) in pool.iter().enumerate() {
        if buckets
            .get(string(candidate, "artistKey"))
            .copied()
            .unwrap_or(2)
            == 2
        {
            continue;
        }
        let weight = weights.get(index).and_then(Value::as_f64).unwrap_or(0.0);
        add_mass(&mut artist_mass, string(candidate, "artistKey"), weight);
        add_mass(&mut album_mass, string(candidate, "albumKey"), weight);
    }
    let n_artists = effective_count(artist_mass.iter().map(|(_, value)| *value));
    let n_albums = effective_count(album_mass.iter().map(|(_, value)| *value));
    json!({"artist": n_artists.saturating_sub(1).min(5), "album": n_albums.saturating_sub(1).min(4)})
}

pub fn diversified_top(request: &Value) -> Value {
    let pool = array(request, "pool");
    let weights = array(request, "weights");
    let count = integer(request, "count").max(0) as usize;
    if count == 0 || pool.is_empty() {
        return json!({"indices": []});
    }
    let n = count.min(pool.len());
    let mut artist_mass = Vec::<(String, f64)>::new();
    let mut total = 0.0;
    for (index, candidate) in pool.iter().enumerate() {
        let weight = weights.get(index).and_then(Value::as_f64).unwrap_or(0.0);
        add_mass(&mut artist_mass, string(candidate, "artistKey"), weight);
        total += weight;
    }
    let mut ranks = (0..pool.len()).collect::<Vec<_>>();
    let sort_keys = (0..pool.len())
        .map(|index| {
            let weight = weights.get(index).and_then(Value::as_f64).unwrap_or(0.0);
            i64::MAX - weight.to_bits() as i64
        })
        .collect::<Vec<_>>();
    crate::queue_ops::dart_sort::sort_by_key(&mut ranks, &sort_keys);
    let mut taken = Vec::<(String, usize)>::new();
    let mut chosen = Vec::new();
    let mut overflow = Vec::new();
    for index in ranks {
        if chosen.len() == n {
            break;
        }
        let key = string(&pool[index], "artistKey");
        let mass = mass_of(&artist_mass, key);
        let share = if total > 0.0 { mass / total } else { 0.0 };
        let cap = 2usize.max((n as f64 * share).ceil() as usize + 1);
        let used = count_of(&taken, key);
        if used < cap {
            chosen.push(index);
            set_count(&mut taken, key, used + 1);
        } else {
            overflow.push(index);
        }
    }
    for index in overflow {
        if chosen.len() == n {
            break;
        }
        chosen.push(index);
    }
    json!({"indices": chosen})
}

fn score(candidate: &Value, weights: &Value) -> f64 {
    let affinity = number(candidate, "affinity").clamp(0.0, 1.0);
    let mut score = affinity.powf(number(weights, "affinityExponent"));
    score += number(weights, "noveltyBoost") / (1.0 + number(candidate, "playCount"));
    let skip =
        (1.0 - number(candidate, "skipRate") * number(weights, "skipAversion")).clamp(0.05, 1.0);
    score *= skip;
    score /= 1.0 + number(candidate, "recentSaturation") * number(weights, "burnoutDamping");

    let history_index = candidate.get("historyIndex").and_then(Value::as_i64);
    let history_limit = integer(weights, "historyLimit");
    let repeat_aversion = number(weights, "repeatAversion");
    if repeat_aversion > 0.0
        && history_index.is_some_and(|index| index < history_limit)
        && history_limit > 0
    {
        let proximity = 1.0 - history_index.unwrap() as f64 / history_limit as f64;
        let penalty = (repeat_aversion * proximity).clamp(0.0, 0.98);
        score *= 1.0 - penalty;
    }
    if boolean(candidate, "isFavorite") {
        score *= number(weights, "favoriteBoost");
    }
    if boolean(candidate, "isSuggestLess") {
        score *= number(weights, "suggestLessPenalty");
    }
    if boolean(candidate, "isInPlaylist") {
        score *= number(weights, "playlistBoost");
    }
    if score.is_nan() || score <= 0.0 {
        0.0001
    } else {
        score.max(0.0001)
    }
}

fn sample_index(scores: &[Value], draw: f64) -> usize {
    let total = scores
        .iter()
        .map(|value| value.as_f64().unwrap_or(0.0))
        .sum::<f64>();
    if total <= 0.0 {
        return 0;
    }
    let target = draw * total;
    let mut cumulative = 0.0;
    for (index, value) in scores.iter().enumerate() {
        cumulative += value.as_f64().unwrap_or(0.0);
        if target <= cumulative {
            return index;
        }
    }
    scores.len() - 1
}

fn apply_spacing(
    order: &mut Vec<usize>,
    artists: &[String],
    albums: &[String],
    artist_spacing: i64,
    album_spacing: i64,
    last_artist: Option<&str>,
    last_album: Option<&str>,
) {
    if artist_spacing <= 0 && album_spacing <= 0 {
        return;
    }
    let mut artist_at = std::collections::HashMap::<String, i64>::new();
    let mut album_at = std::collections::HashMap::<String, i64>::new();
    if let Some(value) = last_artist.map(norm) {
        if !value.is_empty() {
            artist_at.insert(value, -1);
        }
    }
    if let Some(value) = last_album.map(norm) {
        if !value.is_empty() {
            album_at.insert(value, -1);
        }
    }
    for i in 0..order.len() {
        let current = order[i];
        let mut best_deficit = deficit(
            current,
            i as i64,
            artists,
            albums,
            &artist_at,
            &album_at,
            artist_spacing,
            album_spacing,
        );
        if best_deficit > 0 {
            let end = order.len().min(i + 26);
            let mut best_index = i;
            for (j, candidate) in order.iter().enumerate().take(end).skip(i + 1) {
                if best_deficit == 0 {
                    break;
                }
                let candidate_deficit = deficit(
                    *candidate,
                    i as i64,
                    artists,
                    albums,
                    &artist_at,
                    &album_at,
                    artist_spacing,
                    album_spacing,
                );
                if candidate_deficit < best_deficit {
                    best_deficit = candidate_deficit;
                    best_index = j;
                }
            }
            if best_index != i {
                let promoted = order.remove(best_index);
                order.insert(i, promoted);
            }
        }
        let placed = order[i];
        if !artists[placed].is_empty() {
            artist_at.insert(artists[placed].clone(), i as i64);
        }
        if !albums[placed].is_empty() {
            album_at.insert(albums[placed].clone(), i as i64);
        }
    }
}

#[allow(clippy::too_many_arguments)]
fn deficit(
    candidate: usize,
    position: i64,
    artists: &[String],
    albums: &[String],
    artist_at: &std::collections::HashMap<String, i64>,
    album_at: &std::collections::HashMap<String, i64>,
    artist_spacing: i64,
    album_spacing: i64,
) -> i64 {
    let mut total = 0;
    if artist_spacing > 0 && !artists[candidate].is_empty() {
        if let Some(at) = artist_at.get(artists[candidate].as_str()) {
            total += (artist_spacing - (position - at)).max(0);
        }
    }
    if album_spacing > 0 && !albums[candidate].is_empty() {
        if let Some(at) = album_at.get(albums[candidate].as_str()) {
            total += (album_spacing - (position - at)).max(0);
        }
    }
    total
}

fn norm(value: &str) -> String {
    value.trim().to_lowercase()
}

fn number(value: &Value, key: &str) -> f64 {
    value.get(key).and_then(Value::as_f64).unwrap_or(0.0)
}

fn integer(value: &Value, key: &str) -> i64 {
    value.get(key).and_then(Value::as_i64).unwrap_or(0)
}

fn boolean(value: &Value, key: &str) -> bool {
    value.get(key).and_then(Value::as_bool).unwrap_or(false)
}

fn string<'a>(value: &'a Value, key: &str) -> &'a str {
    value.get(key).and_then(Value::as_str).unwrap_or("")
}

fn array<'a>(value: &'a Value, key: &str) -> &'a [Value] {
    value
        .get(key)
        .and_then(Value::as_array)
        .map_or(&[], Vec::as_slice)
}

fn object<'a>(value: &'a Value, key: &str) -> &'a serde_json::Map<String, Value> {
    value
        .get(key)
        .and_then(Value::as_object)
        .unwrap_or_else(|| empty_object())
}

fn empty_object() -> &'static serde_json::Map<String, Value> {
    static EMPTY: std::sync::OnceLock<serde_json::Map<String, Value>> = std::sync::OnceLock::new();
    EMPTY.get_or_init(serde_json::Map::new)
}

fn lerp(a: f64, b: f64, factor: f64) -> f64 {
    a + (b - a) * factor
}

fn classify_artists(pool: &[Value], taste: &Value) -> std::collections::HashMap<String, usize> {
    let mut favorites = std::collections::HashSet::new();
    for candidate in pool {
        if boolean(candidate, "isFavorite") {
            favorites.insert(string(candidate, "artistKey").to_owned());
        }
    }
    let mut buckets = std::collections::HashMap::new();
    for candidate in pool {
        let key = string(candidate, "artistKey");
        let artist = object(taste, "artists").get(key).unwrap_or(&Value::Null);
        let bucket = if number(artist, "trendMass") > 0.0 {
            0
        } else if favorites.contains(key) || number(artist, "longMass") > 0.0 {
            1
        } else {
            2
        };
        buckets.insert(key.to_owned(), bucket);
    }
    buckets
}

struct Signals {
    trend: f64,
    long: f64,
    saturation: f64,
    skip_rate: f64,
    freshness: f64,
}

fn signals_of(
    candidate: &Value,
    songs: &serde_json::Map<String, Value>,
    newness: &serde_json::Map<String, Value>,
) -> Signals {
    let filename = array(candidate, "filenames")
        .first()
        .and_then(Value::as_str)
        .unwrap_or("");
    let song = songs.get(filename).unwrap_or(&Value::Null);
    Signals {
        trend: number(song, "trendMass"),
        long: number(song, "longMass"),
        saturation: number(song, "saturation"),
        skip_rate: number(song, "skipRate"),
        freshness: newness.get(filename).and_then(Value::as_f64).unwrap_or(0.0),
    }
}

fn min_history(candidate: &Value, history: &serde_json::Map<String, Value>) -> Option<i64> {
    array(candidate, "filenames")
        .iter()
        .filter_map(Value::as_str)
        .filter_map(|filename| history.get(filename).and_then(Value::as_i64))
        .min()
}

fn add_mass(values: &mut Vec<(String, f64)>, key: &str, mass: f64) {
    if let Some((_, current)) = values.iter_mut().find(|(existing, _)| existing == key) {
        *current += mass;
    } else {
        values.push((key.to_owned(), mass));
    }
}

fn mass_of(values: &[(String, f64)], key: &str) -> f64 {
    values
        .iter()
        .find_map(|(existing, mass)| (existing == key).then_some(*mass))
        .unwrap_or(0.0)
}

fn count_of(values: &[(String, usize)], key: &str) -> usize {
    values
        .iter()
        .find_map(|(existing, count)| (existing == key).then_some(*count))
        .unwrap_or(0)
}

fn set_count(values: &mut Vec<(String, usize)>, key: &str, count: usize) {
    if let Some((_, current)) = values.iter_mut().find(|(existing, _)| existing == key) {
        *current = count;
    } else {
        values.push((key.to_owned(), count));
    }
}

fn effective_count(masses: impl Iterator<Item = f64>) -> usize {
    let masses = masses.collect::<Vec<_>>();
    let total = masses.iter().sum::<f64>();
    if total <= 0.0 {
        return 0;
    }
    let entropy = masses
        .into_iter()
        .filter(|mass| *mass > 0.0)
        .map(|mass| {
            let probability = mass / total;
            -probability * probability.ln()
        })
        .sum::<f64>();
    entropy.exp().floor() as usize
}
