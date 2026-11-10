//! JPEG sampling with the same IDCT and chroma reconstruction as the Dart palette.

use crate::palette::{sample_coordinate, thumbnail_size};
use image::{Rgb, RgbImage};
use libjpeg_turbo_rs::common::quant_table::NATURAL_ORDER;
use libjpeg_turbo_rs::{probe, read_coefficients, ComponentCoefficients};
use std::collections::HashMap;

pub(super) fn resize(bytes: &[u8]) -> Option<RgbImage> {
    if !bytes.starts_with(&[0xff, 0xd8]) {
        return None;
    }
    let info = probe(bytes).ok()?;
    if info.precision != 8
        || info.lossless
        || info.arithmetic
        || !matches!(info.components, 1 | 3 | 4)
        || info.width.checked_mul(info.height)? > 16_000_000
    {
        return None;
    }
    let jpeg = read_coefficients(bytes).ok()?;
    let (width, height) = (u32::from(jpeg.width), u32::from(jpeg.height));
    if width == 0 || height == 0 || (jpeg.components.len() == 4 && jpeg.adobe_transform.is_none()) {
        return None;
    }
    let max_h = jpeg.components.iter().map(|c| c.h_sampling).max()?;
    let max_v = jpeg.components.iter().map(|c| c.v_sampling).max()?;
    let mut planes = jpeg
        .components
        .iter()
        .map(|component| {
            Some(Plane {
                component,
                quant: jpeg
                    .quant_tables
                    .get(usize::from(component.quant_table_index))?,
                shifts: [
                    shift(component.h_sampling, max_h),
                    shift(component.v_sampling, max_v),
                ],
                samples: HashMap::new(),
            })
        })
        .collect::<Option<Vec<_>>>()?;

    let orientation = info.exif_orientation.unwrap_or(1);
    let (oriented_w, oriented_h) = if orientation >= 5 {
        (height, width)
    } else {
        (width, height)
    };
    let (thumb_w, thumb_h) = thumbnail_size(oriented_w, oriented_h);
    let mut thumb = RgbImage::new(thumb_w, thumb_h);
    for (x, y, pixel) in thumb.enumerate_pixels_mut() {
        let x = sample_coordinate(x, oriented_w, thumb_w);
        let y = sample_coordinate(y, oriented_h, thumb_h);
        let (x, y) = match orientation {
            2 => (width - 1 - x, y),
            3 => (width - 1 - x, height - 1 - y),
            4 => (x, height - 1 - y),
            5 => (y, x),
            6 => (y, height - 1 - x),
            7 => (width - 1 - y, height - 1 - x),
            8 => (width - 1 - y, x),
            _ => (x, y),
        };
        let mut channels = [0; 4];
        for (plane, channel) in planes.iter_mut().zip(&mut channels) {
            *channel = plane.sample(x as usize, y as usize)?;
        }
        let [a, b, c, k] = channels;
        *pixel = Rgb(match planes.len() {
            1 => [a; 3],
            3 if jpeg.adobe_transform.unwrap_or(1) == 1 => ycbcr(a, b, c),
            3 => [a, b, c],
            _ => {
                let cmy = if jpeg.adobe_transform == Some(0) {
                    [a, b, c]
                } else {
                    ycbcr(a, b, c).map(|channel| 255 - channel)
                };
                cmy.map(|channel| ((u16::from(channel) * u16::from(k)) >> 8) as u8)
            }
        });
    }
    Some(thumb)
}

fn shift(samples: u8, max: u8) -> u32 {
    match (samples, max) {
        (n, m) if n == m => 0,
        (1, 4) => 2,
        _ => 1,
    }
}

fn ycbcr(y: u8, cb: u8, cr: u8) -> [u8; 3] {
    let y = i32::from(y) << 8;
    let cb = i32::from(cb) - 128;
    let cr = i32::from(cr) - 128;
    [y + 359 * cr, y - 88 * cb - 183 * cr, y + 454 * cb]
        .map(|channel| (channel >> 8).clamp(0, 255) as u8)
}

struct Plane<'a> {
    component: &'a ComponentCoefficients,
    quant: &'a [u16; 64],
    shifts: [u32; 2],
    samples: HashMap<usize, [u8; 64]>,
}

impl Plane<'_> {
    fn sample(&mut self, x: usize, y: usize) -> Option<u8> {
        let x = x >> self.shifts[0];
        let y = y >> self.shifts[1];
        let stride = self.component.blocks_x;
        if x / 8 >= stride {
            return None;
        }
        let index = (y / 8) * stride + x / 8;
        let coefficients = self.component.blocks.get(index)?;
        let samples = self
            .samples
            .entry(index)
            .or_insert_with(|| inverse_dct(coefficients, self.quant));
        Some(samples[(y % 8) * 8 + x % 8])
    }
}

// Based on package:image's MIT-licensed JPEG IDCT. See palette_jpeg.LICENSE.
fn inverse_dct(coefficients: &[i16; 64], quant: &[u16; 64]) -> [u8; 64] {
    let mut rows = [[0; 8]; 8];
    for (y, row) in rows.iter_mut().enumerate() {
        *row = idct_pass(
            std::array::from_fn(|x| {
                let i = y * 8 + x;
                i64::from(coefficients[NATURAL_ORDER[i]]) * i64::from(quant[i] as i16)
            }),
            4,
        );
    }

    let mut output = [0; 64];
    for x in 0..8 {
        let column = idct_pass(rows.map(|row| row[x]), 0);
        for (y, value) in column.into_iter().enumerate() {
            output[y * 8 + x] = (128 + ((value + 8) >> 4)).clamp(0, 255) as u8;
        }
    }
    output
}

fn idct_pass(input: [i64; 8], scale: u32) -> [i64; 8] {
    let [a, odd1, c, d, e, f, g, odd7] = input;
    let descale = |value| (value + (2048 >> scale)) >> (12 - scale);
    if input[1..].iter().all(|value| *value == 0) {
        return [(5793 * a + (8192 >> scale)) >> (14 - scale); 8];
    }

    let (a, e) = butterfly(descale(5793 * a), descale(5793 * e));
    let (c, g) = (descale(1567 * c - 3784 * g), descale(3784 * c + 1567 * g));
    let (h, d) = butterfly(descale(2896 * (odd1 + odd7)), d << scale);
    let (b, f) = butterfly(descale(2896 * (odd1 - odd7)), f << scale);

    let (a, g) = butterfly(a, g);
    let (e, c) = butterfly(e, c);
    let (b, h) = (
        (3406 * b - 2276 * h + 2048) >> 12,
        (2276 * b + 3406 * h + 2048) >> 12,
    );
    let (d, f) = (
        (4017 * d - 799 * f + 2048) >> 12,
        (799 * d + 4017 * f + 2048) >> 12,
    );

    [a + h, e + f, c + d, g + b, g - b, c - d, e - f, a - h]
}

fn butterfly(a: i64, b: i64) -> (i64, i64) {
    ((a + b + 1) >> 1, (a - b + 1) >> 1)
}
