/// Arithmetic for the per-song lyrics timing offset.
///
/// The offset math lives in the core. Slider precision and bounds are UI rules.
///
/// Sign convention: the offset shifts the *lyric clock*, not the playhead, so a
/// positive offset makes the words appear later.
library;

import '../../data/rust/wispie_core.dart';

/// Hard ceiling on a lyrics timing offset, in seconds.
const double kLyricsTimingMaxSeconds = 60;

/// The grid offsets are stored and nudged on.
const double kLyricsTimingQuantizeStep = 0.01;

/// Selects how wide a slice of the offset range is on screen, and how finely it
/// can be moved.
enum LyricsTimingPrecision {
  coarse(step: 0.10, halfSpanSeconds: 60),
  medium(step: 0.05, halfSpanSeconds: 10),
  fine(step: 0.01, halfSpanSeconds: 5);

  const LyricsTimingPrecision({
    required this.step,
    required this.halfSpanSeconds,
  });

  final double step;
  final double halfSpanSeconds;

  double get spanSeconds => halfSpanSeconds * 2;

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

  int get divisions => (span / step).round();

  bool contains(double seconds) => seconds >= lower && seconds <= upper;

  /// Nearest point on this window's grid, held inside its bounds.
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
LyricsTimingWindow anchorLyricsTimingWindow({
  required double currentSeconds,
  required LyricsTimingPrecision precision,
}) {
  final span = precision.spanSeconds;
  final centre = quantizeLyricsTimingOffset(currentSeconds);
  final lower = (centre - precision.halfSpanSeconds)
      .clamp(-kLyricsTimingMaxSeconds, kLyricsTimingMaxSeconds - span)
      .toDouble();
  return LyricsTimingWindow(
    lower: lower,
    upper: lower + span,
    step: precision.step,
  );
}

double _quantize(double seconds, double step) => (WispieCore.helper({
      'action': 'timing_quantize',
      'seconds': seconds,
      'step': step,
    })['value'] as num)
        .toDouble();

/// Holds an offset on [step] and inside ±[kLyricsTimingMaxSeconds].
double quantizeLyricsTimingOffset(
  double seconds, {
  double step = kLyricsTimingQuantizeStep,
}) =>
    _quantize(seconds, step);

double clampLyricsTimingOffset(double seconds) => (WispieCore.helper({
      'action': 'timing_clamp',
      'seconds': seconds,
    })['value'] as num)
        .toDouble();

/// Moves an offset by [steps] grid steps.
double nudgeLyricsTimingOffset(double current, double steps) =>
    (WispieCore.helper({
      'action': 'timing_nudge',
      'current': current,
      'steps': steps,
    })['value'] as num)
        .toDouble();

Duration lyricsTimingOffsetDuration(double seconds) => Duration(
      microseconds: (seconds * Duration.microsecondsPerSecond).round(),
    );

/// Shifts a playhead onto the lyric clock.
Duration applyLyricsTimingOffset(Duration position, double offsetSeconds) =>
    Duration(
      microseconds: (WispieCore.helper({
        'action': 'timing_apply',
        'positionUs': position.inMicroseconds,
        'offset': offsetSeconds,
      })['valueUs'] as num)
          .toInt(),
    );

/// The inverse: the playhead position that puts [lyricTime] under the playhead.
Duration undoLyricsTimingOffset(Duration lyricTime, double offsetSeconds) =>
    Duration(
      microseconds: (WispieCore.helper({
        'action': 'timing_undo',
        'lyricUs': lyricTime.inMicroseconds,
        'offset': offsetSeconds,
      })['valueUs'] as num)
          .toInt(),
    );

/// The offset that makes [activeLineTime] land exactly on [position].
double? syncOffsetFromPlayhead({
  required Duration position,
  required Duration? activeLineTime,
}) {
  final value = WispieCore.helper({
    'action': 'timing_sync',
    'positionUs': position.inMicroseconds,
    'activeUs': activeLineTime?.inMicroseconds,
  })['value'];
  return value == null ? null : (value as num).toDouble();
}
