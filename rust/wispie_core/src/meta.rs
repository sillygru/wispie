//! Tag reading through `lofty`, replacing `audio_metadata_reader` for the scan.
//! Same containers, no per-frame Dart objects, duration from stream properties.

use lofty::config::WriteOptions;
use lofty::picture::{Picture, PictureType};
use lofty::prelude::*;
use lofty::probe::Probe;
use lofty::tag::{ItemKey, Tag};
use std::io::Cursor;
use std::path::Path;
use std::time::Duration;

#[derive(Debug, Default)]
pub struct Tags {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    pub year: Option<u32>,
    pub duration_secs: Option<f64>,
    pub has_lyrics: bool,
    pub picture: Option<Vec<u8>>,
}

/// Reads everything one file says about itself.
/// A read failure is an error, not an empty tag: unreadable files must be reportable.
pub fn read_tags(path: &Path, want_picture: bool) -> Result<Tags, String> {
    let tagged = Probe::open(path)
        .map_err(|e| e.to_string())?
        .read()
        .map_err(|e| e.to_string())?;

    let mut tags = Tags {
        duration_secs: Some(tagged.properties().duration())
            .filter(|d| *d > Duration::ZERO)
            .map(|d| d.as_secs_f64()),
        ..Tags::default()
    };

    let Some(tag) = tagged.primary_tag().or_else(|| tagged.first_tag()) else {
        return Ok(tags);
    };

    tags.title = non_empty(tag.title().as_deref());
    tags.artist = non_empty(tag.artist().as_deref());
    tags.album = non_empty(tag.album().as_deref());
    tags.year = tag
        .get_string(ItemKey::Year)
        .or_else(|| tag.get_string(ItemKey::RecordingDate))
        .and_then(parse_year);
    tags.has_lyrics = tag
        .get_string(ItemKey::Lyrics)
        .map(|lyrics| !lyrics.trim().is_empty())
        .unwrap_or(false);

    if want_picture {
        if let Some(picture) = tag.pictures().first() {
            tags.picture = Some(picture.data().to_vec());
        }
    }

    Ok(tags)
}

#[derive(serde::Deserialize)]
pub struct TagEdit {
    pub title: Option<String>,
    pub artist: Option<String>,
    pub album: Option<String>,
    #[serde(default)]
    pub remove_picture: bool,
}

/// Updates a staged file before the caller commits it to the library.
pub fn edit_tags(path: &Path, edit: TagEdit, cover: Option<&[u8]>) -> Result<(), String> {
    let mut tagged = Probe::open(path)
        .map_err(|error| error.to_string())?
        .read()
        .map_err(|error| error.to_string())?;
    let primary_type = tagged.primary_tag_type();
    let tag_type = if cover.is_some() || edit.remove_picture {
        primary_type
    } else {
        tagged
            .primary_tag()
            .or_else(|| tagged.first_tag())
            .map_or(primary_type, Tag::tag_type)
    };
    if tagged.tag(tag_type).is_none() {
        if edit.remove_picture
            && cover.is_none()
            && edit.title.is_none()
            && edit.artist.is_none()
            && edit.album.is_none()
        {
            return Ok(());
        }
        let mut tag = tagged
            .first_tag()
            .cloned()
            .unwrap_or_else(|| Tag::new(tag_type));
        tag.re_map(tag_type);
        tagged.insert_tag(tag);
    }

    let tag = tagged.tag_mut(tag_type).ok_or("unsupported tag type")?;
    if let Some(title) = edit.title {
        tag.set_title(title);
    }
    if let Some(artist) = edit.artist {
        tag.set_artist(artist);
    }
    if let Some(album) = edit.album {
        tag.set_album(album);
    }
    if cover.is_some() || edit.remove_picture {
        for index in (0..tag.pictures().len()).rev() {
            tag.remove_picture(index);
        }
    }
    if !edit.remove_picture {
        if let Some(cover) = cover {
            let mut picture =
                Picture::from_reader(&mut Cursor::new(cover)).map_err(|error| error.to_string())?;
            picture.set_pic_type(PictureType::CoverFront);
            tag.push_picture(picture);
        }
    }

    tag.save_to_path(path, WriteOptions::default())
        .map_err(|error| error.to_string())
}

/// Accepts "2021" and "2021-05-01"; anything else is no year at all.
fn parse_year(value: &str) -> Option<u32> {
    let digits: String = value.trim().chars().take(4).collect();
    digits.parse::<u32>().ok().filter(|year| *year > 0)
}

fn non_empty(value: Option<&str>) -> Option<String> {
    let value = value?.trim();
    if value.is_empty() {
        None
    } else {
        Some(value.to_string())
    }
}

/// Jan 1 of `year` in local time, as epoch seconds, matching what Dart stored.
pub fn year_start_epoch_sec(year: u32) -> Option<f64> {
    use chrono::{Local, TimeZone};
    let year = i32::try_from(year).ok()?;
    let start = Local.with_ymd_and_hms(year, 1, 1, 0, 0, 0).single()?;
    Some(start.timestamp() as f64)
}
