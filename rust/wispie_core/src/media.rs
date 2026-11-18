//! In-process audio decode for waveform and beat analysis.
//!
//! FFmpeg used to produce the PCM: a subprocess on desktop, an FFmpegKit
//! session on mobile. iOS allows neither, so the decode runs in this process
//! instead, over the containers the library indexes.

use std::fs::File;

use serde_json::json;
use symphonia::core::codecs::audio::AudioDecoderOptions;
use symphonia::core::codecs::registry::CodecRegistry;
use symphonia::core::common::Tier;
use symphonia::core::errors::Error as SymphoniaError;
use symphonia::core::formats::probe::Hint;
use symphonia::core::formats::{FormatOptions, TrackType};
use symphonia::core::io::MediaSourceStream;
use symphonia::core::meta::MetadataOptions;
use symphonia_opus::OpusDecoder;

use crate::emitter::{Emit, Emitter};
use crate::waveform;

/// Decoded PCM accumulated before a progressive peak event is sent. One event
/// per this much audio reveals the bar while a long track decodes without
/// flooding the port.
const PROGRESS_BYTES: usize = 1 << 20;

pub fn run(payload: &serde_json::Value, emitter: &Emitter) -> Result<(), String> {
    let path = payload
        .get("path")
        .and_then(|value| value.as_str())
        .ok_or_else(|| "media decode needs a path".to_string())?;
    let sample_rate = payload
        .get("sampleRate")
        .and_then(|value| value.as_u64())
        .and_then(|value| u32::try_from(value).ok())
        .filter(|rate| (1_000..=192_000).contains(rate))
        .ok_or_else(|| "media decode needs a valid sample rate".to_string())?;

    let peak_targets = payload.get("peaks").and_then(|value| {
        Some((
            value.get("samples")?.as_u64()? as usize,
            value.get("expectedBytes")?.as_u64()? as usize,
        ))
    });

    let pcm = decode_to_mono(path, sample_rate, peak_targets, emitter)?;
    if pcm.len() < 2 {
        return Err("media decode produced no audio".to_string());
    }
    emitter.emit(Emit::Bytes(pcm));
    Ok(())
}

/// Decodes `path` to little-endian mono s16 at `dst_rate`.
///
/// Downsampling averages each output window rather than dropping samples: a
/// 48 kHz kick drum point-sampled to 4 kHz aliases into noise the waveform then
/// draws as detail that is not there.
fn decode_to_mono(
    path: &str,
    dst_rate: u32,
    peak_targets: Option<(usize, usize)>,
    emitter: &Emitter,
) -> Result<Vec<u8>, String> {
    let file = File::open(path).map_err(|error| format!("open media: {error}"))?;
    let stream = MediaSourceStream::new(Box::new(file), Default::default());

    let mut hint = Hint::new();
    if let Some(extension) = std::path::Path::new(path)
        .extension()
        .and_then(|value| value.to_str())
    {
        hint.with_extension(&extension.to_lowercase());
    }

    let mut format = symphonia::default::get_probe()
        .probe(
            &hint,
            stream,
            FormatOptions::default(),
            MetadataOptions::default(),
        )
        .map_err(|error| format!("probe media: {error}"))?;

    let track = format
        .default_track(TrackType::Audio)
        .ok_or_else(|| "no audio track".to_string())?;
    let track_id = track.id;
    let params = track
        .codec_params
        .as_ref()
        .and_then(|params| params.audio())
        .cloned()
        .ok_or_else(|| "track carries no audio codec parameters".to_string())?;

    let mut codecs = CodecRegistry::new();
    symphonia::default::register_enabled_codecs(&mut codecs);
    codecs.register_audio_decoder_at_tier::<OpusDecoder>(Tier::Fallback);
    let mut decoder = codecs
        .make_audio_decoder(&params, &AudioDecoderOptions::default())
        .map_err(|error| format!("unsupported codec: {error}"))?;

    let mut resampler = Resampler::new(dst_rate);
    let mut samples: Vec<i16> = Vec::new();
    let mut interleaved: Vec<i16> = Vec::new();
    let mut last_emit = 0usize;

    loop {
        let packet = match format.next_packet() {
            Ok(Some(packet)) => packet,
            Ok(None) | Err(SymphoniaError::IoError(_)) | Err(SymphoniaError::ResetRequired) => {
                break
            }
            Err(error) => return Err(format!("read media: {error}")),
        };
        if packet.track_id != track_id {
            continue;
        }

        let decoded = match decoder.decode(&packet) {
            Ok(decoded) => decoded,
            // One corrupt packet must not discard every beat after it.
            Err(SymphoniaError::DecodeError(_)) => continue,
            Err(SymphoniaError::IoError(_)) => break,
            Err(error) => return Err(format!("decode media: {error}")),
        };

        let channels = decoded.spec().channels().count().max(1);
        resampler.set_source_rate(decoded.spec().rate());
        interleaved.clear();
        interleaved.resize(decoded.samples_interleaved(), 0);
        decoded.copy_to_slice_interleaved::<i16, _>(&mut interleaved[..]);

        for frame in interleaved.chunks(channels) {
            let sum: i32 = frame.iter().map(|sample| i32::from(*sample)).sum();
            resampler.push(sum as f32 / channels as f32 / 32768.0, &mut samples);
        }

        if let Some((targets, expected)) = peak_targets {
            if samples.len() * 2 - last_emit >= PROGRESS_BYTES {
                last_emit = samples.len() * 2;
                let bytes = to_bytes(&samples);
                if let Ok(peaks) = waveform::run(&bytes, targets, expected) {
                    emitter.emit(Emit::Json(json!({
                        "bytes": bytes.len(),
                        "bars": peaks.get("bars").cloned().unwrap_or_else(|| json!([])),
                    })));
                }
            }
        }
    }

    resampler.flush(&mut samples);
    Ok(to_bytes(&samples))
}

fn to_bytes(samples: &[i16]) -> Vec<u8> {
    let mut bytes = Vec::with_capacity(samples.len() * 2);
    for sample in samples {
        bytes.extend_from_slice(&sample.to_le_bytes());
    }
    bytes
}

/// Mono, resampled to the analyser's rate and fed one frame at a time so a
/// four minute track never sits in a second buffer.
///
/// Downsampling first averages whole groups of source frames, then interpolates
/// the remainder. The averaging is what keeps content above the output's
/// Nyquist out of the band the visuals read: point sampling a 48 kHz kick into
/// 22 kHz folds the cymbals down onto the hats.
struct Resampler {
    dst_rate: u32,
    source_rate: u32,
    pre: u32,
    pre_acc: f64,
    pre_count: u32,
    step: f64,
    index: u64,
    previous: f32,
    next_output: f64,
    window_start: f64,
    acc: f64,
    count: u32,
    anti_alias: Option<LowPass>,
}

impl Resampler {
    fn new(dst_rate: u32) -> Self {
        Self {
            dst_rate,
            source_rate: 0,
            pre: 1,
            pre_acc: 0.0,
            pre_count: 0,
            step: 1.0,
            index: 0,
            previous: 0.0,
            next_output: 0.0,
            window_start: 0.0,
            acc: 0.0,
            count: 0,
            anti_alias: None,
        }
    }

    fn set_source_rate(&mut self, src_rate: u32) {
        let src_rate = if src_rate == 0 {
            self.dst_rate
        } else {
            src_rate
        };
        let ratio = f64::from(src_rate) / f64::from(self.dst_rate);
        let pre = if ratio >= 2.0 {
            ratio.floor().max(1.0) as u32
        } else {
            1
        };
        // Called for every packet: only a change of rate may reset the state,
        // or each packet boundary would restart the filter and the phase.
        if src_rate == self.source_rate {
            return;
        }
        self.source_rate = src_rate;
        self.pre = pre;
        self.step = ratio / f64::from(pre);
        // A box window this narrow barely attenuates what folds back, so a
        // steep filter runs first. A wide window (the 4 kHz bar decode) already
        // averages a dozen frames and needs no help.
        self.anti_alias = if (1.1..4.0).contains(&ratio) {
            Some(LowPass::new(
                0.45 * f64::from(self.dst_rate) / f64::from(src_rate),
            ))
        } else {
            None
        };
        self.pre_acc = 0.0;
        self.pre_count = 0;
        self.index = 0;
        self.next_output = 0.0;
        self.window_start = 0.0;
        self.acc = 0.0;
        self.count = 0;
    }

    fn push(&mut self, sample: f32, out: &mut Vec<i16>) {
        let sample = match self.anti_alias.as_mut() {
            Some(filter) => filter.apply(sample),
            None => sample,
        };
        if self.pre > 1 {
            self.pre_acc += f64::from(sample);
            self.pre_count += 1;
            if self.pre_count < self.pre {
                return;
            }
            let averaged = (self.pre_acc / f64::from(self.pre)) as f32;
            self.pre_acc = 0.0;
            self.pre_count = 0;
            self.emit(averaged, out);
        } else {
            self.emit(sample, out);
        }
    }

    fn emit(&mut self, sample: f32, out: &mut Vec<i16>) {
        if self.step < 1.5 {
            self.emit_interpolated(sample, out);
        } else {
            self.emit_averaged(sample, out);
        }
        self.previous = sample;
        self.index += 1;
    }

    fn emit_interpolated(&mut self, sample: f32, out: &mut Vec<i16>) {
        let position = self.index as f64;
        // Only times already covered by [previous, sample] may be emitted;
        // sampling past the newest frame would clamp and staircase the output.
        while self.next_output <= position {
            let fraction = (self.next_output - position + 1.0).clamp(0.0, 1.0) as f32;
            out.push(to_sample(
                self.previous + (sample - self.previous) * fraction,
            ));
            self.next_output += self.step;
        }
    }

    fn emit_averaged(&mut self, sample: f32, out: &mut Vec<i16>) {
        let center = self.index as f64 + 0.5;
        while center >= self.window_start + self.step {
            out.push(self.take_window());
        }
        self.acc += f64::from(sample);
        self.count += 1;
    }

    fn take_window(&mut self) -> i16 {
        let value = if self.count == 0 {
            0.0
        } else {
            self.acc / f64::from(self.count)
        };
        self.window_start += self.step;
        self.acc = 0.0;
        self.count = 0;
        to_sample(value as f32)
    }

    fn flush(&mut self, out: &mut Vec<i16>) {
        if self.step > 1.0 && self.count > 0 {
            out.push(self.take_window());
        }
    }
}

/// Blackman-windowed sinc low-pass, run at the source rate before decimation.
struct LowPass {
    taps: Vec<f32>,
    history: [f32; 128],
    cursor: usize,
}

impl LowPass {
    fn new(cutoff: f64) -> Self {
        let count = 63usize;
        let middle = (count - 1) as f64 / 2.0;
        let mut taps = Vec::with_capacity(count);
        let mut sum = 0.0f64;
        for index in 0..count {
            let offset = index as f64 - middle;
            let angle = std::f64::consts::PI * 2.0 * cutoff * offset;
            let sinc = if angle.abs() < 1.0e-9 {
                1.0
            } else {
                angle.sin() / angle
            };
            let phase = 2.0 * std::f64::consts::PI * index as f64 / (count - 1) as f64;
            let window = 0.42 - 0.5 * phase.cos() + 0.08 * (2.0 * phase).cos();
            let value = 2.0 * cutoff * sinc * window;
            taps.push(value as f32);
            sum += value;
        }
        if sum.abs() > 1.0e-9 {
            for tap in &mut taps {
                *tap = (*tap as f64 / sum) as f32;
            }
        }
        Self {
            taps,
            history: [0.0; 128],
            cursor: 0,
        }
    }

    fn apply(&mut self, sample: f32) -> f32 {
        self.history[self.cursor] = sample;
        self.cursor = (self.cursor + 1) & 127;
        let start = (self.cursor + 128 - self.taps.len()) & 127;
        let mut sum = 0.0f32;
        for (index, tap) in self.taps.iter().enumerate() {
            sum += tap * self.history[(start + index) & 127];
        }
        sum
    }
}

fn to_sample(value: f32) -> i16 {
    (f64::from(value.clamp(-1.0, 1.0)) * 32767.0)
        .round()
        .clamp(-32768.0, 32767.0) as i16
}
