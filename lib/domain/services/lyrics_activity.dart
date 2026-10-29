/// Which lyric lines are being sung at a playhead position.
///
/// Line timing alone is not enough: a word-synced source often marks a line
/// before its first word is audible (TTML paragraphs overlap for harmonies),
/// so switching on the line's own start cuts the previous line short. The first
/// word is the real cue. Word data that does not hold together falls back to
/// the line's timing, per line, so one bad line cannot spoil the rest.
///
/// Pure: no widgets, no I/O, no clock.
library;

import 'dart:math' as math;

import '../../models/song.dart';
import '../models/rich_lyrics.dart';

/// How long one line's words are trusted to be out of step with its own start.
const Duration _wordLeadTolerance = Duration(seconds: 1);

/// A single line's timing, resolved from its words where they can be trusted.
class LyricLineTiming {
  /// The line carries a timestamp of its own. Untimed lines never light up.
  final bool timed;
  final Duration lineStart;

  /// First and last word, or null when the line has no usable words.
  final Duration? wordStart;
  final Duration? wordEnd;

  /// The words were estimated from the line rather than supplied by the source.
  final bool simulated;

  const LyricLineTiming({
    required this.timed,
    required this.lineStart,
    this.wordStart,
    this.wordEnd,
    this.simulated = false,
  });

  bool _trustsWords(bool simulateEnabled) =>
      wordStart != null && wordEnd != null && (!simulated || simulateEnabled);

  /// When the line starts sounding.
  Duration startFor(bool simulateEnabled) =>
      _trustsWords(simulateEnabled) ? wordStart! : lineStart;

  /// When the line stops sounding, or null when only the next line can say —
  /// line-synced data has no end of its own.
  Duration? endFor(bool simulateEnabled) =>
      _trustsWords(simulateEnabled) ? wordEnd : null;
}

/// Resolves every line's timing once per lyric load, so the per-tick work stays
/// a scan of already-cheap values.
List<LyricLineTiming> buildLyricTimings(
  List<LyricLine> lyrics,
  List<RichLyricLine?> wordLines,
) {
  return [
    for (var index = 0; index < lyrics.length; index++)
      _timingFor(
        lyrics[index],
        index < wordLines.length ? wordLines[index] : null,
      ),
  ];
}

LyricLineTiming _timingFor(LyricLine line, RichLyricLine? words) {
  final usable = words != null && _wordsAreTrustworthy(line, words);
  return LyricLineTiming(
    timed: line.isSynced,
    lineStart: line.time,
    wordStart: usable ? words.words.first.start : null,
    wordEnd: usable ? words.words.last.end : null,
    simulated: words?.isSimulated ?? false,
  );
}

/// Words must march forward, belong to their line's moment, and last a
/// plausible time. Anything else is a mis-parse to be ignored.
bool _wordsAreTrustworthy(LyricLine line, RichLyricLine words) {
  final timed = words.words;
  if (timed.isEmpty) return false;

  var previous = Duration.zero;
  var advances = false;
  for (final word in timed) {
    if (word.start < Duration.zero || word.end < word.start) return false;
    if (word.start < previous) return false;
    if (word.end > word.start) advances = true;
    previous = word.start;
  }
  if (!advances) return false;
  if (words.words.first.start < line.time - _wordLeadTolerance) return false;
  return words.words.last.end - words.words.first.start <=
      const Duration(minutes: 2);
}

/// The lines sounding at one instant.
class LyricsActivity {
  /// Lines inside their own sounding window. Normally one; a harmony line that
  /// overlaps the lead lights both.
  final Set<int> active;

  /// Newest line that has started, or -1 before the first.
  final int latest;

  const LyricsActivity({required this.active, required this.latest});

  static const LyricsActivity idle =
      LyricsActivity(active: <int>{}, latest: -1);

  bool isActive(int index) => active.contains(index);

  /// Sung or singing: everything up to the newest start, plus anything still
  /// sounding inside it.
  bool isPlayed(int index) => latest >= 0 && index <= latest;

  /// Active rows sit at zero, so a harmony line is as lit as the lead.
  int distanceFrom(int index) => isActive(index) ? 0 : index - latest;

  /// The line to scroll to: the newest one still sounding.
  int get anchor =>
      active.isEmpty ? latest : active.reduce((a, b) => math.max(a, b));

  @override
  bool operator ==(Object other) =>
      other is LyricsActivity &&
      other.latest == latest &&
      _sameLines(other.active, active);

  @override
  int get hashCode =>
      Object.hash(latest, Object.hashAll(active.toList()..sort()));

  static bool _sameLines(Set<int> a, Set<int> b) =>
      a.length == b.length && a.every(b.contains);
}

/// Lines sounding at [position].
///
/// A line runs from its start until its last word ends; when it has no words it
/// runs until the next line starts. With nothing sounding the newest line is
/// held, which is what keeps the last lyric lit through an instrumental break.
LyricsActivity lyricsActivityAt(
  List<LyricLineTiming> timings,
  Duration position, {
  bool simulateEnabled = true,
}) {
  final active = <int>{};
  var latest = -1;
  var latestStart = Duration.zero;

  for (var index = 0; index < timings.length; index++) {
    final timing = timings[index];
    if (!timing.timed) continue;
    final start = timing.startFor(simulateEnabled);
    if (start > position) continue;
    latest = index;
    latestStart = start;

    final end = timing.endFor(simulateEnabled) ??
        _nextStart(timings, index, simulateEnabled);
    if (end == null || position < end) active.add(index);
  }

  if (active.isEmpty && latest >= 0) {
    // Lines that start together are one moment, so hold all of them.
    for (var index = 0; index < timings.length; index++) {
      final timing = timings[index];
      if (!timing.timed) continue;
      if (timing.startFor(simulateEnabled) == latestStart) active.add(index);
    }
  }

  return LyricsActivity(active: active, latest: latest);
}

/// The next line that starts *after* this one. Lines sharing a start are one
/// moment and run together.
Duration? _nextStart(
  List<LyricLineTiming> timings,
  int index,
  bool simulateEnabled,
) {
  final start = timings[index].startFor(simulateEnabled);
  for (var next = index + 1; next < timings.length; next++) {
    final timing = timings[next];
    if (!timing.timed) continue;
    final candidate = timing.startFor(simulateEnabled);
    if (candidate > start) return candidate;
  }
  return null;
}
