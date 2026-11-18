//! Library view math: folder roots, folder contents, sorting and grouping.
//! Ported from `library_logic.dart`. Takes plain song rows so the adapter only
//! maps filenames back to `Song` objects.

use crate::model::SongJson;
use serde::Deserialize;
use serde_json::{json, Value};
use std::collections::HashMap;
use std::path::{Component, Path, PathBuf};

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct ViewRequest {
    op: String,
    songs: Vec<SongJson>,
    root: String,
    configured_folders: Vec<String>,
    order: String,
    play_counts: HashMap<String, i64>,
    last_played: HashMap<String, f64>,
    favorites: Vec<String>,
    suggest_less: Vec<String>,
    playlist: Vec<String>,
    affinities: HashMap<String, AffinityRow>,
    weights: Option<Value>,
    taste: Option<Value>,
    familiarity: f64,
    favorite_multiplier: f64,
    suggest_less_multiplier: f64,
    artist_keys: HashMap<String, String>,
    groups: Vec<GroupRow>,
    artist: String,
    title: String,
    album: String,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct AffinityRow {
    affinity: f64,
    play_count: i64,
    skip_rate: f64,
    recent_saturation: f64,
}

#[derive(Debug, Clone, Default, Deserialize)]
#[serde(default, rename_all = "camelCase")]
struct GroupRow {
    name: String,
    indices: Vec<usize>,
}

pub fn run(request: Value) -> Value {
    let request: ViewRequest = serde_json::from_value(request).unwrap_or_default();
    match request.op.as_str() {
        "root" => json!({ "root": resolve_root(&request) }),
        "folder" => folder_content(&request),
        "sort" => {
            let order = sort_indices(&request, (0..request.songs.len()).collect());
            json!({ "order": order })
        }
        "groupArtist" => groups_json(group_by_artist(&request)),
        "groupAlbum" => groups_json(group_by_album(&request)),
        "groupSongsByAlbum" => groups_json(group_songs_by_album(&request)),
        "namesByTracks" => json!({ "names": names_by_tracks(&request) }),
        "namesByPlays" => json!({ "names": names_by_plays(&request) }),
        "albumNamesByTrackCount" => json!({ "names": names_by_track_count(&request) }),
        "albumNamesByArtistCount" => json!({ "names": names_by_track_count(&request) }),
        "albumName" => json!({ "name": display_album(&request.album) }),
        "multipleAlbums" => json!({ "value": has_multiple_albums(&request.songs) }),
        "totalPlays" => json!({ "value": total_plays(&request.songs, &request.play_counts) }),
        "byPlayCount" => {
            let mut indices: Vec<usize> = (0..request.songs.len()).collect();
            sort_by_play_count(&request, &mut indices);
            json!({ "order": indices })
        }
        "coverSong" => json!({ "index": pick_cover_song(&request) }),
        "splitArtists" => json!({ "artists": split_artist_names(&request.artist) }),
        "looksLikeArtist" => json!({
            "value": looks_like_artist(&request.songs, &request.title),
        }),
        _ => json!({}),
    }
}

// ---------------------------------------------------------------------------
// Roots and folders
// ---------------------------------------------------------------------------

fn resolve_root(request: &ViewRequest) -> Option<String> {
    let mut roots: Vec<String> = Vec::new();
    for folder in &request.configured_folders {
        let normalized = normalize_path(folder);
        if normalized.is_empty() || roots.contains(&normalized) {
            continue;
        }
        roots.push(normalized);
    }

    let matching: Vec<String> = roots
        .iter()
        .filter(|root| request.songs.iter().any(|song| is_under(root, &song.url)))
        .cloned()
        .collect();

    if matching.len() == 1 {
        return Some(matching[0].clone());
    }
    if matching.len() > 1 {
        return common_ancestor(matching.iter().cloned());
    }
    if request.songs.is_empty() {
        return roots.first().cloned();
    }
    common_ancestor(
        request
            .songs
            .iter()
            .filter_map(|song| parent_dir(&song.url)),
    )
}

fn folder_content(request: &ViewRequest) -> Value {
    let root = normalize_path(&request.root);
    let all: Vec<usize> = request
        .songs
        .iter()
        .enumerate()
        .filter(|(_, song)| is_under(&root, &song.url))
        .map(|(index, _)| index)
        .collect();

    let mut sub_folders: Vec<String> = Vec::new();
    let mut sub_folder_songs: Vec<(String, Vec<usize>)> = Vec::new();
    let mut immediate: Vec<usize> = Vec::new();

    for index in &all {
        let url = normalize_path(&request.songs[*index].url);
        let relative = relative_to(&url, &root);
        let parts: Vec<&str> = relative
            .split('/')
            .filter(|part| !part.is_empty())
            .collect();
        if parts.len() <= 1 {
            immediate.push(*index);
            continue;
        }
        let name = parts[0].to_string();
        match sub_folder_songs
            .iter_mut()
            .find(|(folder, _)| *folder == name)
        {
            Some((_, songs)) => songs.push(*index),
            None => {
                sub_folders.push(name.clone());
                sub_folder_songs.push((name, vec![*index]));
            }
        }
    }
    sub_folders.sort();

    let sorted_immediate = sort_indices(request, immediate);
    let map: serde_json::Map<String, Value> = sub_folder_songs
        .into_iter()
        .map(|(name, songs)| (name, json!(songs)))
        .collect();

    json!({
        "subFolders": sub_folders,
        "immediate": sorted_immediate,
        "all": all,
        "subFolderSongs": Value::Object(map),
    })
}

// ---------------------------------------------------------------------------
// Sorting
// ---------------------------------------------------------------------------

fn sort_indices(request: &ViewRequest, indices: Vec<usize>) -> Vec<usize> {
    let mut order = indices;
    match request.order.as_str() {
        "title" => order
            .sort_by(|a, b| lower(&request.songs[*a].title).cmp(&lower(&request.songs[*b].title))),
        "artist" => order.sort_by(|a, b| {
            let left = &request.songs[*a];
            let right = &request.songs[*b];
            lower(&left.artist)
                .cmp(&lower(&right.artist))
                .then_with(|| lower(&left.title).cmp(&lower(&right.title)))
        }),
        "album" => order.sort_by(|a, b| {
            let left = &request.songs[*a];
            let right = &request.songs[*b];
            let album = lower(&left.album).cmp(&lower(&right.album));
            if album != std::cmp::Ordering::Equal {
                return album;
            }
            // Two tagged rows order by release date only: a shared year is a
            // tie, exactly as the Dart comparator treated it.
            if let (Some(x), Some(y)) = (left.song_date_epoch_sec, right.song_date_epoch_sec) {
                return x.partial_cmp(&y).unwrap_or(std::cmp::Ordering::Equal);
            }
            lower(&left.title).cmp(&lower(&right.title))
        }),
        "dateAdded" => order.sort_by(|a, b| {
            let left = date_added(&request.songs[*a]);
            let right = date_added(&request.songs[*b]);
            right
                .partial_cmp(&left)
                .unwrap_or(std::cmp::Ordering::Equal)
        }),
        "playCount" => order.sort_by(|a, b| {
            play_count(request, &request.songs[*b]).cmp(&play_count(request, &request.songs[*a]))
        }),
        "recommended" => return recommended(request, order),
        "songDateNewOld" | "songDateOldNew" => {
            let newest_first = request.order == "songDateNewOld";
            order.sort_by(|a, b| {
                let left = &request.songs[*a];
                let right = &request.songs[*b];
                let (x, y) = (left.song_date_epoch_sec, right.song_date_epoch_sec);
                match (x, y) {
                    (None, None) => {}
                    (None, _) => return std::cmp::Ordering::Greater,
                    (_, None) => return std::cmp::Ordering::Less,
                    (Some(x), Some(y)) if x != y => {
                        return if newest_first {
                            y.partial_cmp(&x).unwrap_or(std::cmp::Ordering::Equal)
                        } else {
                            x.partial_cmp(&y).unwrap_or(std::cmp::Ordering::Equal)
                        }
                    }
                    _ => {}
                }
                lower(&left.title).cmp(&lower(&right.title))
            });
        }
        "recentlyPlayed" => order.sort_by(|a, b| {
            let left = request.last_played.get(&request.songs[*a].filename);
            let right = request.last_played.get(&request.songs[*b].filename);
            match (left, right) {
                (Some(x), Some(y)) if x != y => {
                    return y.partial_cmp(x).unwrap_or(std::cmp::Ordering::Equal)
                }
                (Some(_), None) => return std::cmp::Ordering::Less,
                (None, Some(_)) => return std::cmp::Ordering::Greater,
                _ => {}
            }
            lower(&request.songs[*a].title).cmp(&lower(&request.songs[*b].title))
        }),
        _ => {}
    }
    order
}

fn recommended(request: &ViewRequest, order: Vec<usize>) -> Vec<usize> {
    let Some(weights) = &request.weights else {
        let mut order = order;
        order.sort_by(|a, b| lower(&request.songs[*a].title).cmp(&lower(&request.songs[*b].title)));
        return order;
    };

    if let Some(taste) = &request.taste {
        return smart_order(request, taste, order);
    }

    if request.affinities.is_empty() {
        let mut order = order;
        order.sort_by(|a, b| lower(&request.songs[*a].title).cmp(&lower(&request.songs[*b].title)));
        return order;
    }

    let favorites: std::collections::HashSet<&str> =
        request.favorites.iter().map(String::as_str).collect();
    let suggest_less: std::collections::HashSet<&str> =
        request.suggest_less.iter().map(String::as_str).collect();
    let playlist: std::collections::HashSet<&str> =
        request.playlist.iter().map(String::as_str).collect();

    let mut scored: Vec<(usize, f64)> = order
        .into_iter()
        .map(|index| {
            let song = &request.songs[index];
            let affinity = request
                .affinities
                .get(&song.filename)
                .cloned()
                .unwrap_or_default();
            let candidate = json!({
                "affinity": affinity.affinity,
                "playCount": affinity.play_count,
                "skipRate": affinity.skip_rate,
                "recentSaturation": affinity.recent_saturation,
                "isFavorite": favorites.contains(song.filename.as_str()),
                "isSuggestLess": suggest_less.contains(song.filename.as_str()),
                "isInPlaylist": playlist.contains(song.filename.as_str()),
            });
            (index, crate::shuffle::score(&candidate, weights))
        })
        .collect();

    scored.sort_by(|a, b| {
        b.1.partial_cmp(&a.1)
            .unwrap_or(std::cmp::Ordering::Equal)
            .then_with(|| lower(&request.songs[a.0].title).cmp(&lower(&request.songs[b.0].title)))
    });
    scored.into_iter().map(|(index, _)| index).collect()
}

fn smart_order(request: &ViewRequest, taste: &Value, order: Vec<usize>) -> Vec<usize> {
    let favorites: std::collections::HashSet<&str> =
        request.favorites.iter().map(String::as_str).collect();
    let suggest_less: std::collections::HashSet<&str> =
        request.suggest_less.iter().map(String::as_str).collect();
    let playlist: std::collections::HashSet<&str> =
        request.playlist.iter().map(String::as_str).collect();

    let pool: Vec<Value> = order
        .iter()
        .map(|index| {
            let song = &request.songs[*index];
            json!({
                "filenames": [song.filename],
                "artistKey": request.artist_keys.get(&song.filename).cloned().unwrap_or_default(),
                "albumKey": song.album.trim().to_lowercase(),
                "isFavorite": favorites.contains(song.filename.as_str()),
                "isSuggestLess": suggest_less.contains(song.filename.as_str()),
                "isInPlaylist": playlist.contains(song.filename.as_str()),
            })
        })
        .collect();

    let reply = crate::shuffle::smart_weights(&json!({
        "pool": pool,
        "taste": taste,
        "familiarity": request.familiarity,
        "context": "sort",
        "currentArtistKey": "",
        "historyIndex": {},
        "historyLimit": 0,
        "favoriteMultiplier": request.favorite_multiplier,
        "suggestLessMultiplier": request.suggest_less_multiplier,
    }));
    let weights = reply.get("weights").cloned().unwrap_or_else(|| json!([]));
    let reply = crate::shuffle::diversified_top(&json!({
        "pool": pool,
        "weights": weights,
        "count": order.len(),
    }));
    reply
        .get("indices")
        .and_then(Value::as_array)
        .map(|indices| {
            indices
                .iter()
                .filter_map(Value::as_u64)
                .filter_map(|position| order.get(position as usize).copied())
                .collect()
        })
        .unwrap_or(order)
}

// ---------------------------------------------------------------------------
// Grouping
// ---------------------------------------------------------------------------

fn group_by_artist(request: &ViewRequest) -> Vec<(String, Vec<usize>)> {
    let mut canonical: Vec<(String, String)> = Vec::new();
    let mut groups: Vec<(String, Vec<usize>)> = Vec::new();
    let mut seen: Vec<(String, std::collections::HashSet<String>)> = Vec::new();

    for (index, song) in request.songs.iter().enumerate() {
        let raw = song.artist.trim();
        let parsed = split_artist_names(raw);
        let artists = if parsed.is_empty() {
            vec!["Unknown Artist".to_string()]
        } else {
            parsed
        };
        for artist in artists {
            let clean = artist.trim();
            let lower_key = clean.to_lowercase();
            let display = match canonical.iter().find(|(key, _)| *key == lower_key) {
                Some((_, display)) => display.clone(),
                None => {
                    canonical.push((lower_key.clone(), clean.to_string()));
                    clean.to_string()
                }
            };
            let group_index = match groups.iter().position(|(name, _)| *name == display) {
                Some(position) => position,
                None => {
                    groups.push((display.clone(), Vec::new()));
                    seen.push((display.clone(), std::collections::HashSet::new()));
                    groups.len() - 1
                }
            };
            let seen_group = seen
                .iter_mut()
                .find(|(name, _)| *name == groups[group_index].0)
                .map(|(_, set)| set)
                .unwrap();
            if seen_group.insert(song.filename.clone()) {
                groups[group_index].1.push(index);
            }
        }
    }

    for (_, songs) in groups.iter_mut() {
        songs.sort_by(|a, b| {
            let left = &request.songs[*a];
            let right = &request.songs[*b];
            lower(&left.album)
                .cmp(&lower(&right.album))
                .then_with(|| lower(&left.title).cmp(&lower(&right.title)))
        });
    }
    groups
}

fn group_by_album(request: &ViewRequest) -> Vec<(String, Vec<usize>)> {
    let mut groups: Vec<(String, Vec<usize>)> = Vec::new();
    for (index, song) in request.songs.iter().enumerate() {
        let album = if song.album.is_empty() {
            "Unknown Album".to_string()
        } else {
            song.album.clone()
        };
        match groups.iter_mut().find(|(name, _)| *name == album) {
            Some((_, songs)) => songs.push(index),
            None => groups.push((album, vec![index])),
        }
    }
    for (_, songs) in groups.iter_mut() {
        songs.sort_by(|a, b| lower(&request.songs[*a].title).cmp(&lower(&request.songs[*b].title)));
    }
    groups
}

fn group_songs_by_album(request: &ViewRequest) -> Vec<(String, Vec<usize>)> {
    let mut canonical: Vec<(String, String)> = Vec::new();
    let mut groups: Vec<(String, Vec<usize>)> = Vec::new();
    for (index, song) in request.songs.iter().enumerate() {
        let display = album_display_name(song);
        let key = display.to_lowercase();
        let name = match canonical.iter().find(|(stored, _)| *stored == key) {
            Some((_, name)) => name.clone(),
            None => {
                canonical.push((key, display.clone()));
                display
            }
        };
        match groups.iter_mut().find(|(stored, _)| *stored == name) {
            Some((_, songs)) => songs.push(index),
            None => groups.push((name, vec![index])),
        }
    }
    groups
}

fn groups_json(groups: Vec<(String, Vec<usize>)>) -> Value {
    json!({
        "groups": groups
            .into_iter()
            .map(|(name, indices)| json!({ "name": name, "indices": indices }))
            .collect::<Vec<_>>(),
    })
}

fn names_by_tracks(request: &ViewRequest) -> Vec<String> {
    let mut names: Vec<(String, usize)> = request
        .groups
        .iter()
        .map(|group| (group.name.clone(), group.indices.len()))
        .collect();
    names.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then_with(|| a.0.to_lowercase().cmp(&b.0.to_lowercase()))
    });
    names.into_iter().map(|(name, _)| name).collect()
}

fn names_by_track_count(request: &ViewRequest) -> Vec<String> {
    names_by_tracks(request)
}

fn names_by_plays(request: &ViewRequest) -> Vec<String> {
    let mut names: Vec<(String, i64, usize)> = request
        .groups
        .iter()
        .map(|group| {
            let songs: Vec<SongJson> = group
                .indices
                .iter()
                .filter_map(|index| request.songs.get(*index).cloned())
                .collect();
            (
                group.name.clone(),
                total_plays(&songs, &request.play_counts),
                group.indices.len(),
            )
        })
        .collect();
    names.sort_by(|a, b| {
        b.1.cmp(&a.1)
            .then_with(|| b.2.cmp(&a.2))
            .then_with(|| a.0.to_lowercase().cmp(&b.0.to_lowercase()))
    });
    names.into_iter().map(|(name, _, _)| name).collect()
}

fn album_display_name(song: &SongJson) -> String {
    display_album(&song.album)
}

fn display_album(album: &str) -> String {
    let trimmed = album.trim();
    if trimmed.is_empty() {
        "Unknown Album".to_string()
    } else {
        trimmed.to_string()
    }
}

fn has_multiple_albums(songs: &[SongJson]) -> bool {
    let mut first: Option<String> = None;
    for song in songs {
        let key = album_display_name(song).to_lowercase();
        match &first {
            None => first = Some(key),
            Some(stored) if *stored != key => return true,
            _ => {}
        }
    }
    false
}

fn total_plays(songs: &[SongJson], counts: &HashMap<String, i64>) -> i64 {
    songs
        .iter()
        .map(|song| {
            counts
                .get(&song.filename)
                .copied()
                .unwrap_or(song.play_count)
        })
        .sum()
}

fn sort_by_play_count(request: &ViewRequest, indices: &mut [usize]) {
    indices.sort_by(|a, b| {
        let left = &request.songs[*a];
        let right = &request.songs[*b];
        play_count(request, right)
            .cmp(&play_count(request, left))
            .then_with(|| lower(&left.title).cmp(&lower(&right.title)))
    });
}

fn pick_cover_song(request: &ViewRequest) -> Option<usize> {
    let mut best_local: Option<(usize, i64, String)> = None;
    let mut best_any: Option<(usize, i64, String)> = None;

    for (index, song) in request.songs.iter().enumerate() {
        let cover = song.cover_url.as_deref().unwrap_or("");
        let is_local = !cover.is_empty() && crate::artwork::is_local(cover);
        if !is_local && cover.is_empty() {
            continue;
        }
        let plays = play_count(request, song);
        let title = lower(&song.title);
        let better = |current: &Option<(usize, i64, String)>| match current {
            None => true,
            Some((_, current_plays, current_title)) => {
                plays > *current_plays || (plays == *current_plays && title < *current_title)
            }
        };
        if better(&best_any) {
            best_any = Some((index, plays, title.clone()));
        }
        if is_local && better(&best_local) {
            best_local = Some((index, plays, title));
        }
    }

    best_local.or(best_any).map(|(index, _, _)| index)
}

// ---------------------------------------------------------------------------
// Artists
// ---------------------------------------------------------------------------

/// Splits `Artist 1 & Artist 2`, `ft.`, `feat.`, `and`, `x`, `/`, `;` and `,`.
pub fn split_artist_names(artist: &str) -> Vec<String> {
    let trimmed = artist.trim();
    if trimmed.is_empty() {
        return Vec::new();
    }
    let pattern =
        regex::Regex::new(r"(?i)\s*(?:,|&|/|;|\b(?:and|featuring|x)\b|\b(?:ft|feat|vs)\b\.?)\s*")
            .expect("artist split pattern");
    let parts: Vec<String> = pattern
        .split(trimmed)
        .map(|part| part.trim().to_string())
        .filter(|part| !part.is_empty())
        .collect();
    if parts.is_empty() {
        vec![trimmed.to_string()]
    } else {
        parts
    }
}

fn looks_like_artist(songs: &[SongJson], title: &str) -> bool {
    if songs.is_empty() {
        return false;
    }
    let lower_title = title.to_lowercase();
    songs.iter().any(|song| {
        let lower_artist = song.artist.to_lowercase();
        lower_artist.contains(&lower_title) || lower_title.contains(&lower_artist)
    })
}

// ---------------------------------------------------------------------------
// Paths
// ---------------------------------------------------------------------------

fn lower(value: &str) -> String {
    value.to_lowercase()
}

fn play_count(request: &ViewRequest, song: &SongJson) -> i64 {
    request
        .play_counts
        .get(&song.filename)
        .copied()
        .unwrap_or(song.play_count)
}

fn date_added(song: &SongJson) -> f64 {
    song.created_epoch_sec.or(song.mtime).unwrap_or(0.0)
}

pub fn normalize_path(path: &str) -> String {
    let trimmed = path.trim();
    if trimmed.is_empty() {
        return String::new();
    }
    let mut parts: Vec<String> = Vec::new();
    let mut absolute = false;
    for component in Path::new(trimmed).components() {
        match component {
            Component::RootDir => absolute = true,
            Component::CurDir => {}
            Component::ParentDir => {
                if parts.is_empty() {
                    if !absolute {
                        parts.push("..".to_string());
                    }
                } else if parts.last().is_some_and(|part| part == "..") {
                    parts.push("..".to_string());
                } else {
                    parts.pop();
                }
            }
            Component::Normal(name) => parts.push(name.to_string_lossy().into_owned()),
            Component::Prefix(prefix) => {
                parts.push(prefix.as_os_str().to_string_lossy().into_owned())
            }
        }
    }
    let joined = parts.join("/");
    if absolute {
        if joined.is_empty() {
            "/".to_string()
        } else {
            format!("/{joined}")
        }
    } else if joined.is_empty() {
        ".".to_string()
    } else {
        joined
    }
}

pub fn is_under(root: &str, song_url: &str) -> bool {
    if root.is_empty() || song_url.is_empty() {
        return false;
    }
    let normalized = normalize_path(song_url);
    normalized == root || Path::new(&normalized).starts_with(Path::new(root))
}

fn parent_dir(path: &str) -> Option<String> {
    let normalized = normalize_path(path);
    Path::new(&normalized)
        .parent()
        .map(|parent| parent.to_string_lossy().into_owned())
}

fn relative_to(path: &str, root: &str) -> String {
    Path::new(path)
        .strip_prefix(Path::new(root))
        .map(|value| value.to_string_lossy().into_owned())
        .unwrap_or_else(|_| path.to_string())
}

fn common_ancestor(paths: impl Iterator<Item = String>) -> Option<String> {
    let mut common: Option<Vec<String>> = None;
    for path in paths {
        let normalized = normalize_path(&path);
        let parts: Vec<String> = Path::new(&normalized)
            .components()
            .map(|component| component.as_os_str().to_string_lossy().into_owned())
            .collect();
        match &mut common {
            None => common = Some(parts),
            Some(current) => {
                let limit = current.len().min(parts.len());
                let mut shared = 0;
                while shared < limit && current[shared] == parts[shared] {
                    shared += 1;
                }
                current.truncate(shared);
                if current.is_empty() {
                    return None;
                }
            }
        }
    }
    let parts = common?;
    if parts.is_empty() {
        return None;
    }
    let mut buffer = PathBuf::new();
    for part in parts {
        buffer.push(part);
    }
    Some(buffer.to_string_lossy().into_owned())
}
