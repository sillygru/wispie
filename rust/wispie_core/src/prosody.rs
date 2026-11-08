//! Word-level lyric timing.
//!
//! A word's share of the line comes from how long it takes to sing: syllables,
//! function words a little shorter, comma and phrase endings longer. Nothing is
//! learned, so the whole model is the handful of constants below.

use crate::emitter::{Emit, Emitter};
use crate::model::ProsodyLine;
use serde_json::json;

const COMMA_SCALE: f64 = 0.3;
const STOP_SCALE: f64 = 0.754378752619989;
const MIN_WORD_US: i64 = 20_000;

/// Long words take slightly less time per syllable than short ones.
const SYL_EXP: f64 = 0.80;
const PICKUP: f64 = 0.95;
const FINAL: f64 = 1.50;
const PENULT: f64 = 1.30;
const COMMA_WORD: f64 = 1.05;
const STOP_WORD: f64 = 1.10;

const FUNCTION_WORDS: &[&str] = &[
    "a", "an", "the", "to", "in", "on", "at", "by", "for", "of", "with", "and", "or", "but", "if",
    "as", "is", "am", "are", "was", "were", "be", "been", "being", "it", "its", "it's", "i", "i'm",
    "i've", "i'll", "you", "you're", "you've", "you'll", "he", "he's", "she", "she's", "they",
    "they're", "we", "we're", "my", "your", "his", "her", "our", "their", "me", "us", "them",
    "that", "this", "no", "so", "do", "don't", "did", "didn't", "not", "can", "can't", "won",
    "won't", "from", "up", "out", "off", "then", "than", "into", "just", "like", "got", "too", "e",
    "de", "da", "em", "um", "uma", "na", "se", "te",
];

pub struct Word {
    pub start_us: i64,
    pub end_us: i64,
    pub text: String,
}

pub fn run(lines: Vec<ProsodyLine>, emitter: &Emitter) -> Result<(), String> {
    let timed: Vec<serde_json::Value> = lines
        .iter()
        .map(|line| {
            json!({
                "words": estimate_line(line)
                    .into_iter()
                    .map(|word| json!({
                        "startUs": word.start_us,
                        "endUs": word.end_us,
                        "text": word.text,
                    }))
                    .collect::<Vec<_>>(),
            })
        })
        .collect();

    emitter.emit(Emit::Json(json!({ "lines": timed })));
    Ok(())
}

pub fn estimate_line(line: &ProsodyLine) -> Vec<Word> {
    let tokens = split_tokens(&line.text);
    let n = tokens.len();
    if n == 0 {
        return Vec::new();
    }
    if n == 1 {
        return vec![Word {
            start_us: line.start_us,
            end_us: line.end_us,
            text: tokens[0].clone(),
        }];
    }

    let line_dur_us = line.end_us - line.start_us;
    let line_dur_s = (line_dur_us as f64 / 1_000_000.0).max(0.1);
    let line_chars: usize = tokens.iter().map(|t| t.encode_utf16().count()).sum();
    let line_cps = line_chars as f64 / line_dur_s;

    // Pauses shorten as the line runs faster than the song's own pace.
    let cadence = 1.0 / (1.0 + ((line_cps - line.song_cps) * 0.25).clamp(-10.0, 10.0).exp());
    let comma_base = ((60_000.0 + 260_000.0 * cadence) * COMMA_SCALE * 1.15).round() as i64;
    let stop_base = ((120_000.0 + 380_000.0 * cadence) * STOP_SCALE * 1.15).round() as i64;

    let mut weights = Vec::with_capacity(n);
    let mut pauses = Vec::with_capacity(n);
    for (idx, token) in tokens.iter().enumerate() {
        let mut weight = (syllables(token) as f64).powf(SYL_EXP);

        let pause = if idx + 1 < n {
            if ends_with_any(token, &[',', ';', '-', '~']) {
                weight *= COMMA_WORD;
                comma_base
            } else if ends_with_any(token, &['.', '!', '?']) {
                weight *= STOP_WORD;
                stop_base
            } else {
                0
            }
        } else {
            0
        };

        let is_func = FUNCTION_WORDS.contains(&clean_of(token).as_str());
        if idx == 0 && n > 2 && is_func {
            weight *= PICKUP;
        }
        if idx == n - 1 {
            weight *= FINAL;
        } else if idx == n - 2 {
            weight *= PENULT;
        }

        weights.push(weight);
        pauses.push(pause);
    }

    let mut total_weight: f64 = weights.iter().sum();
    if total_weight <= 0.0 {
        total_weight = n as f64;
        weights = vec![1.0; n];
    }

    let mut cumulative = Vec::with_capacity(n + 1);
    cumulative.push(0.0);
    for weight in &weights {
        cumulative.push(cumulative[cumulative.len() - 1] + weight);
    }

    let allocatable_us = (line_dur_us - pauses.iter().sum::<i64>()).max(0);

    let mut boundaries = Vec::with_capacity(n + 1);
    boundaries.push(line.start_us);
    let mut pause_before = 0i64;
    for i in 1..n {
        pause_before += pauses[i - 1];
        let share = (allocatable_us as f64 * (cumulative[i] / total_weight)).round() as i64;
        boundaries.push(line.start_us + share + pause_before);
    }
    boundaries.push(line.start_us + line_dur_us);

    for i in 1..boundaries.len() {
        if boundaries[i] <= boundaries[i - 1] + MIN_WORD_US {
            boundaries[i] = boundaries[i - 1] + MIN_WORD_US;
        }
    }

    (0..n)
        .map(|i| Word {
            start_us: boundaries[i],
            end_us: boundaries[i + 1],
            text: tokens[i].clone(),
        })
        .collect()
}

fn is_word_char(ch: char) -> bool {
    ch.is_ascii_alphanumeric() || ch == '_'
}

fn ends_with_any(text: &str, marks: &[char]) -> bool {
    match text.chars().last() {
        Some(last) => marks.contains(&last),
        None => false,
    }
}

/// JS `\s` set, which is what Dart's non-unicode `RegExp(r'\s+')` matches.
fn is_dart_space(ch: char) -> bool {
    matches!(
        ch,
        '\t' | '\n' | '\u{0B}' | '\u{0C}' | '\r' | ' ' | '\u{A0}' | '\u{1680}' | '\u{2000}'
            ..='\u{200A}'
                | '\u{2028}'
                | '\u{2029}'
                | '\u{202F}'
                | '\u{205F}'
                | '\u{3000}'
                | '\u{FEFF}'
    )
}

/// Lowercase, then drop everything outside `[\w']`.
fn clean_of(token: &str) -> String {
    token
        .to_lowercase()
        .chars()
        .filter(|ch| is_word_char(*ch) || *ch == '\'')
        .collect()
}

fn split_tokens(text: &str) -> Vec<String> {
    let mut raw = Vec::new();
    let mut current = String::new();
    for ch in text.chars() {
        if is_dart_space(ch) {
            if !current.is_empty() {
                raw.push(std::mem::take(&mut current));
            }
        } else {
            current.push(ch);
        }
    }
    if !current.is_empty() {
        raw.push(current);
    }

    let mut tokens = Vec::new();
    for word in raw {
        if word.contains('-') && word.encode_utf16().count() > 1 {
            let parts: Vec<&str> = word.split('-').filter(|p| !p.is_empty()).collect();
            if parts.len() > 1 {
                for (i, part) in parts.iter().enumerate() {
                    if i < parts.len() - 1 {
                        tokens.push(format!("{part}-"));
                    } else {
                        tokens.push((*part).to_string());
                    }
                }
                continue;
            }
        }
        tokens.push(word);
    }
    tokens
}

fn vowel_runs(clean: &str) -> usize {
    let mut runs = 0usize;
    let mut in_vowel = false;
    for ch in clean.chars() {
        let vowel = matches!(ch, 'a' | 'e' | 'i' | 'o' | 'u' | 'y');
        if vowel && !in_vowel {
            runs += 1;
            in_vowel = true;
        } else if !vowel {
            in_vowel = false;
        }
    }
    runs
}

fn syllables(word: &str) -> usize {
    let mut count = 0usize;
    let mut latin = String::new();
    for ch in word.chars() {
        let code = ch as u32;
        let cjk = (0x4E00..=0x9FFF).contains(&code)
            || (0x3040..=0x309F).contains(&code)
            || (0x30A0..=0x30FF).contains(&code)
            || (0xAC00..=0xD7AF).contains(&code);
        if cjk {
            count += 1;
        } else {
            latin.push(ch);
        }
    }

    let latin = clean_of(&latin);
    if !latin.is_empty() {
        let mut groups = vowel_runs(&latin);
        if groups > 1 && latin.ends_with('e') && !latin.ends_with("le") {
            groups -= 1;
        }
        count += groups.max(1);
    }
    count.max(1)
}
