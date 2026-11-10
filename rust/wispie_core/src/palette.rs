//! Cover decoding, reduction, blur and deterministic colour clustering.

use image::{Rgb, RgbImage};
use serde_json::json;
use std::path::Path;

pub fn run(path: &str) -> Result<serde_json::Value, String> {
    let bytes = std::fs::read(Path::new(path)).map_err(|error| format!("read cover: {error}"))?;
    run_bytes(&bytes)
}

fn run_bytes(bytes: &[u8]) -> Result<serde_json::Value, String> {
    let decoded =
        image::load_from_memory(bytes).map_err(|error| format!("decode cover: {error}"))?;
    let height = 100u32;
    let width =
        ((decoded.width() as f64 * height as f64 / decoded.height() as f64).round() as u32).max(1);
    let source = decoded.to_rgb8();
    let resized = resize_nearest(&source, width, height);
    let blurred = blur(&resized, 2);
    let pixels: Vec<[u8; 3]> = blurred.pixels().map(|p| p.0).collect();
    let mut clusters = kmeans(&pixels, 5, 20);
    clusters.sort_by_key(|cluster| std::cmp::Reverse(cluster.1));
    let total: usize = clusters.iter().map(|cluster| cluster.1).sum();
    let selected = select_accent(&clusters, total);
    let mut mixed = [0u64; 3];
    let mixed_count = clusters.len().min(10);
    for (rgb, _) in clusters.iter().take(10) {
        for channel in 0..3 {
            mixed[channel] += rgb[channel] as u64;
        }
    }
    let mixed = if mixed_count == 0 {
        [0, 0, 0]
    } else {
        mixed.map(|value| (value / mixed_count as u64) as u8)
    };
    let swatches: Vec<_> = clusters
        .into_iter()
        .map(|(rgb, population)| json!({"r":rgb[0],"g":rgb[1],"b":rgb[2],"population":population}))
        .collect();
    Ok(json!({
        "swatches": swatches,
        "accent": {"r": selected.0[0], "g": selected.0[1], "b": selected.0[2]},
        "isNeutral": selected.1,
        "mixedColor": {"r": mixed[0], "g": mixed[1], "b": mixed[2]},
    }))
}

fn select_accent(clusters: &[([u8; 3], usize)], total: usize) -> ([u8; 3], bool) {
    let mut best: Option<([u8; 3], f64, f64)> = None;
    for (rgb, population) in clusters {
        let chroma = (*rgb.iter().max().unwrap() - *rgb.iter().min().unwrap()) as f64 / 255.0;
        if chroma < 0.08 {
            continue;
        }
        let score = chroma * (*population as f64 / total.max(1) as f64).sqrt();
        if best.is_none_or(|(_, best_score, _)| score > best_score) {
            best = Some((*rgb, score, chroma));
        }
    }
    let Some((rgb, _, chroma)) = best else {
        return ([224, 224, 224], true);
    };
    (normalize_accent(rgb, chroma), false)
}

fn normalize_accent(rgb: [u8; 3], chroma: f64) -> [u8; 3] {
    let [r, g, b] = rgb.map(|channel| channel as f64 / 255.0);
    let max = r.max(g).max(b);
    let min = r.min(g).min(b);
    let delta = max - min;
    let lightness = (max + min) / 2.0;
    let saturation = if delta == 0.0 {
        0.0
    } else {
        delta / (1.0 - (2.0 * lightness - 1.0).abs())
    };
    let hue = if delta == 0.0 {
        0.0
    } else if max == r {
        ((g - b) / delta).rem_euclid(6.0) / 6.0
    } else if max == g {
        ((b - r) / delta + 2.0) / 6.0
    } else {
        ((r - g) / delta + 4.0) / 6.0
    };
    let saturation = if chroma >= 0.08 {
        saturation.max(0.28)
    } else {
        saturation
    };
    let lightness = lightness.clamp(0.62, 0.78);
    hsl_to_rgb(hue, saturation.clamp(0.0, 1.0), lightness)
}

fn hsl_to_rgb(hue: f64, saturation: f64, lightness: f64) -> [u8; 3] {
    let m2 = if lightness <= 0.5 {
        lightness * (1.0 + saturation)
    } else {
        lightness + saturation - lightness * saturation
    };
    let m1 = 2.0 * lightness - m2;
    [
        hue_to_rgb(m1, m2, hue + 1.0 / 3.0),
        hue_to_rgb(m1, m2, hue),
        hue_to_rgb(m1, m2, hue - 1.0 / 3.0),
    ]
}

fn hue_to_rgb(m1: f64, m2: f64, mut hue: f64) -> u8 {
    if hue < 0.0 {
        hue += 1.0;
    } else if hue > 1.0 {
        hue -= 1.0;
    }
    let value = if 6.0 * hue < 1.0 {
        m1 + (m2 - m1) * hue * 6.0
    } else if 2.0 * hue < 1.0 {
        m2
    } else if 3.0 * hue < 2.0 {
        m1 + (m2 - m1) * (2.0 / 3.0 - hue) * 6.0
    } else {
        m1
    };
    (value * 255.0).round() as u8
}

fn resize_nearest(source: &RgbImage, width: u32, height: u32) -> RgbImage {
    let mut out = RgbImage::new(width, height);
    let dx = source.width() as f64 / width as f64;
    let dy = source.height() as f64 / height as f64;
    for y in 0..height {
        let source_y = (y as f64 * dy) as u32;
        for x in 0..width {
            let source_x = (x as f64 * dx) as u32;
            out.put_pixel(x, y, *source.get_pixel(source_x, source_y));
        }
    }
    out
}

fn blur(source: &RgbImage, radius: i32) -> RgbImage {
    let sigma = radius as f64 * (2.0 / 3.0);
    let denom = 2.0 * sigma * sigma;
    let mut kernel: Vec<f64> = (-radius..=radius)
        .map(|x| (-(x * x) as f64 / denom).exp())
        .collect();
    let total: f64 = kernel.iter().sum();
    for v in &mut kernel {
        *v /= total;
    }
    let mut temp = source.clone();
    let mut output = source.clone();
    let reflect = |max: i32, x: i32| {
        if x < 0 {
            -x
        } else if x >= max {
            max - (x - max) - 1
        } else {
            x
        }
    };
    for y in 0..source.height() as i32 {
        for x in 0..source.width() as i32 {
            let mut sum = [0.0; 3];
            for (offset, weight) in (-radius..=radius).zip(&kernel) {
                let sx = reflect(source.width() as i32, x + offset) as u32;
                let p = source.get_pixel(sx, y as u32).0;
                for c in 0..3 {
                    sum[c] += *weight * p[c] as f64;
                }
            }
            temp.put_pixel(
                x as u32,
                y as u32,
                Rgb(sum.map(|v| v.clamp(0.0, 255.0) as u8)),
            );
        }
    }
    for y in 0..source.height() as i32 {
        for x in 0..source.width() as i32 {
            let mut sum = [0.0; 3];
            for (offset, weight) in (-radius..=radius).zip(&kernel) {
                let sy = reflect(source.height() as i32, y + offset) as u32;
                let p = temp.get_pixel(x as u32, sy).0;
                for c in 0..3 {
                    sum[c] += *weight * p[c] as f64;
                }
            }
            output.put_pixel(
                x as u32,
                y as u32,
                Rgb(sum.map(|v| v.clamp(0.0, 255.0) as u8)),
            );
        }
    }
    output
}

fn seed_for(pixels: &[[u8; 3]]) -> u32 {
    let mut hash = pixels.len() as u32;
    let step = (pixels.len() / 256).max(1);
    for p in pixels.iter().step_by(step) {
        hash = 31_u32
            .wrapping_mul(hash)
            .wrapping_add(((p[0] as u32) << 16) | ((p[1] as u32) << 8) | p[2] as u32)
            & 0x1fffffff;
    }
    hash
}
struct DartRandom {
    state: u64,
}

impl DartRandom {
    fn new(seed: u32) -> Self {
        let mut n = seed as u64;
        n = (!n).wrapping_add(n.wrapping_shl(21));
        n ^= n >> 24;
        n = n.wrapping_mul(265);
        n ^= n >> 14;
        n = n.wrapping_mul(21);
        n ^= n >> 28;
        n = n.wrapping_add(n.wrapping_shl(31));
        if n == 0 {
            n = 0x5a17;
        }
        let mut result = Self { state: n };
        for _ in 0..4 {
            result.next_state();
        }
        result
    }

    fn next_state(&mut self) {
        self.state = 0xffff_da61_u64
            .wrapping_mul(self.state & 0xffff_ffff)
            .wrapping_add(self.state >> 32);
    }

    fn next_int(&mut self, max: u32) -> u32 {
        let limit = 1u64 << 32;
        loop {
            self.next_state();
            let value = self.state as u32;
            let result = value % max;
            if value as u64 - result as u64 + max as u64 <= limit {
                return result;
            }
        }
    }

    fn next_double(&mut self) -> f64 {
        ((self.next_int(1 << 26) as u64 * (1 << 27) + self.next_int(1 << 27) as u64) as f64)
            / ((1u64 << 53) as f64)
    }
}
fn distance(a: [u8; 3], b: [u8; 3]) -> f64 {
    let r = a[0] as f64 - b[0] as f64;
    let g = a[1] as f64 - b[1] as f64;
    let b = a[2] as f64 - b[2] as f64;
    (r * r + g * g + b * b).sqrt()
}
fn kmeans(pixels: &[[u8; 3]], k: usize, max_iterations: usize) -> Vec<([u8; 3], usize)> {
    if pixels.is_empty() || k == 0 {
        return vec![];
    }
    let mut rng = DartRandom::new(seed_for(pixels));
    let first = rng.next_int(pixels.len() as u32) as usize;
    let mut centroids = vec![pixels[first]];
    let mut nearest = vec![f64::INFINITY; pixels.len()];
    while centroids.len() < k.min(pixels.len()) {
        let last = *centroids.last().unwrap();
        let mut total = 0.0;
        for (i, p) in pixels.iter().enumerate() {
            let d = distance(*p, last).powi(2);
            nearest[i] = nearest[i].min(d);
            total += nearest[i];
        }
        if total <= 0.0 {
            break;
        }
        let mut target = rng.next_double() * total;
        let mut chosen = pixels.len() - 1;
        for (i, d) in nearest.iter().enumerate() {
            target -= *d;
            if target <= 0.0 {
                chosen = i;
                break;
            }
        }
        centroids.push(pixels[chosen]);
    }
    let mut counts = vec![0usize; centroids.len()];
    for _ in 0..max_iterations {
        let mut sums = vec![[0u64; 3]; centroids.len()];
        counts.fill(0);
        for p in pixels {
            let mut best = 0;
            let mut min = f64::INFINITY;
            for (i, c) in centroids.iter().enumerate() {
                let d = distance(*p, *c);
                if d < min {
                    min = d;
                    best = i;
                }
            }
            counts[best] += 1;
            for ch in 0..3 {
                sums[best][ch] += p[ch] as u64;
            }
        }
        let mut moved = false;
        for i in 0..centroids.len() {
            if counts[i] == 0 {
                continue;
            }
            let next = [
                (sums[i][0] / counts[i] as u64) as u8,
                (sums[i][1] / counts[i] as u64) as u8,
                (sums[i][2] / counts[i] as u64) as u8,
            ];
            if distance(centroids[i], next) > 1.0 {
                moved = true;
            }
            centroids[i] = next;
        }
        if !moved {
            break;
        }
    }
    let mut out = vec![([0, 0, 0], 0); centroids.len()];
    for p in pixels {
        let mut best = 0;
        let mut min = f64::INFINITY;
        for (i, c) in centroids.iter().enumerate() {
            let d = distance(*p, *c);
            if d < min {
                min = d;
                best = i;
            }
        }
        out[best].0 = centroids[best];
        out[best].1 += 1;
    }
    out.into_iter().filter(|(_, n)| *n > 0).collect()
}
