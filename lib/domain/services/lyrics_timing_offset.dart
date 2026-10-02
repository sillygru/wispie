/// Arithmetic for the per-song lyrics timing offset.
///
/// Pure functions and value objects, no Flutter and no I/O, so the rules that
/// decide what the user is allowed to dial in can be tested directly instead of
/// through the slider. The reason this file exists at all is resolution: a
/// single linear slider stretched across the full -60..60s span puts roughly a
/// second of offset behind every pixel of drag, which makes the 1-3s corrections
/// that most synced lyrics actually need impossible to land. The fix is a set
/// of [LyricsTimingPrecision] rungs — each with its own step size and its own
/// window — whose windows together still cover the whole 120s span.
///
/// Sign convention, and the one thing worth reading before changing anything
/// here: the offset shifts the *lyric clock*, not the playhead. See
/// [applyLyricsTimingOffset]. A positive offset therefore makes the words
/// appear later, because the lyric timeline is read as running behind the song.
library;

/// Hard ceiling on a lyrics timing offset, in seconds.
///
/// The user-facing range is a 120s span, so this is 60 either side of zero. It
/// is defined once here because the slider, the nudges, the sync snap and the
/// database write all have to agree on it.
const double kLyricsTimingMaxSeconds = 60;

/// The grid offsets are stored and nudged on.
///
/// 10ms is below the threshold where a human can hear or see a lyric land
/// differently, so it is as fine as the control needs to get.
const double kLyricsTimingQuantizeStep = 0.01;

/// Selects how wide a slice of the offset range is on screen, and how finely it
/// can be moved.
///
/// Coarse exists to reach the far end of the range and to cover large
/// corrections; fine is where a song that is nearly right gets made right. The
/// union of the three windows is exactly the full 120s span, so switching rungs
/// trades reach for resolution and never costs reach:
///
/// | rung   | window | step  | divisions |
/// |--------|--------|-------|-----------|
/// | coarse | 120s   | 0.10s | 1200      |
/// | medium | 20s    | 0.05s | 400       |
/// | fine   | 10s    | 0.01s | 1000      |
enum LyricsTimingPrecision {
  coarse(step: 0.10, halfSpanSeconds: 60),
  medium(step: 0.05, halfSpanSeconds: 10),
  fine(step: 0.01, halfSpanSeconds: 5);

  const LyricsTimingPrecision({
    required this.step,
    required this.halfSpanSeconds,
  });

  /// Grid resolution in seconds. Every value here divides a second exactly, so
  /// there is no rounding wobble when the value is snapped.
  final double step;

  /// Half the window width, centred on the current offset.
  final double halfSpanSeconds;

  double get spanSeconds => halfSpanSeconds * 2;

  /// Slider segments. Exact because [spanSeconds] is always a whole multiple of
  /// [step], which is what keeps one segment worth exactly one [step].
  int get divisions => (spanSeconds / step).round();

  /// Compact chip label — the step size is what the rung *is* to the user.
  String get label => '${step.toStringAsFixed(2)}s';
}

/// The bounds a slider is currently drawn against, anchored on an offset rather
/// than on zero.
class LyricsTimingWindow {
  const LyricsTimingWindow({
    required this.lower,
    required this.upper,
    required this.step,
  });

  final double lower;
  final double upper;
  final double step;

  double get span => upper - lower;

  /// Exact by construction: every [LyricsTimingPrecision] span is a whole
  /// multiple of its step.
  int get divisions => (span / step).round();

  bool contains(double seconds) => seconds >= lower && seconds <= upper;

  /// Nearest point on this window's grid, held inside its bounds.
  ///
  /// Used as the slider's `value` so the value can never be handed to a [Slider]
  /// outside the `min`/`max` it was built against.
  double snap(double seconds) {
    final steps = ((seconds - lower) / step).round();
    final snapped = lower + steps * step;
    if (snapped < lower) return lower;
    if (snapped > upper) return upper;
    return snapped;
  }

  @override
  bool operator ==(Object other) =>
      other is LyricsTimingWindow &&
      other.lower == lower &&
      other.upper == upper &&
      other.step == step;

  @override
  int get hashCode => Object.hash(lower, upper, step);
}

/// Builds the window for a rung, centred on the offset already dialled in.
///
/// Anchoring on the value rather than on zero is what lets the fine rung be a
/// ±5s window: switching from coarse to fine around a +12s offset leaves the
/// offset untouched and simply gives it a magnified view. It also means a value
/// can never fall outside the window it is shown in, which is what stops the
/// slider from fighting a clamp the user cannot see.
LyricsTimingWindow anchorLyricsTimingWindow({
  required double currentSeconds,
  required LyricsTimingPrecision precision,
}) {
  final span = precision.spanSeconds;
  final centre = quantizeLyricsTimingOffset(currentSeconds);
  // Coarse's span equals the whole 120s range, so the upper bound collapses to
  // the lower one and this pins it to exactly -60..60 no matter where the
  // offset started. The other rungs slide along inside that range.
  final lower = (centre - precision.halfSpanSeconds).clamp(
    -kLyricsTimingMaxSeconds,
    kLyricsTimingMaxSeconds - span,
  );
  return LyricsTimingWindow(
    lower: lower,
    upper: lower + span,
    step: precision.step,
  );
}

/// Holds an offset on [step] and inside ±[kLyricsTimingMaxSeconds].
///
/// Dividing by the reciprocal rather than multiplying back by [step] is
/// deliberate: `235 * 0.01` is 2.3500000000000005 in binary floating point,
/// whereas `235 / 100.0` is the nearest double to 2.35. Dividing keeps every
/// stored value exactly the number the readout prints, so a session of nudges
/// cannot walk the value sideways.
double quantizeLyricsTimingOffset(
  double seconds, {
  double step = kLyricsTimingQuantizeStep,
}) {
  final steps = (seconds / step).round();
  return clampLyricsTimingOffset(steps / (1 / step).round());
}

double clampLyricsTimingOffset(double seconds) =>
    seconds.clamp(-kLyricsTimingMaxSeconds, kLyricsTimingMaxSeconds);

/// Moves an offset by [steps] grid steps — the nudges use this with -1, -0.1
/// and -0.01 so a nudge lands exactly where the readout will say it did.
double nudgeLyricsTimingOffset(double current, double steps) =>
    quantizeLyricsTimingOffset(current + steps);

Duration lyricsTimingOffsetDuration(double seconds) => Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );

/// Shifts a playhead onto the lyric clock.
///
/// The offset lives here rather than in the parsed timestamps so the original
/// lyrics stay reusable — retiming is a view concern and re-reading the file to
/// change it would be wasteful. Subtracting is what makes a positive offset
/// delay the words.
Duration applyLyricsTimingOffset(Duration position, double offsetSeconds) =>
    position - lyricsTimingOffsetDuration(offsetSeconds);

/// The inverse: the playhead position that puts [lyricTime] under the playhead.
///
/// Seeking a lyric line has to add the offset back or every tap jumps by the
/// amount the user just corrected.
Duration undoLyricsTimingOffset(Duration lyricTime, double offsetSeconds) =>
    lyricTime + lyricsTimingOffsetDuration(offsetSeconds);

/// The offset that makes [activeLineTime] land exactly on [position], or null
/// when there is no timed line to snap to.
///
/// This turns the common case — the words are close but consistently a couple of
/// seconds late — into one tap at the right moment instead of a drag.
double? syncOffsetFromPlayhead({
  required Duration position,
  required Duration? activeLineTime,
}) {
  if (activeLineTime == null) return null;
  final micros = position.inMicroseconds - activeLineTime.inMicroseconds;
  return quantizeLyricsTimingOffset(
    micros / Duration.microsecondsPerSecond,
  );
}

/// Readout text. Two decimals because the fine rung's step is 10ms — a single
/// decimal would report every fine adjustment as no change at all.
String formatLyricsTimingOffset(double seconds, {bool showUnit = false}) {
  final quantized = quantizeLyricsTimingOffset(seconds);
  if (quantized == 0) return 'In sync';
  final sign = quantized > 0 ? '+' : '-';
  final magnitude = quantized.abs().toStringAsFixed(2);
  return showUnit ? '$sign$magnitude s' : '$sign$magnitude';
}
