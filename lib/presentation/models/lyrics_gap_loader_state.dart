import '../../domain/services/lyrics_activity.dart';
import '../../models/song.dart';

const _musicalGapSymbols = {
  '♪',
  '♫',
  '♩',
  '♬',
  '♭',
  '♮',
  '♯',
  '𝄞',
  '🎵',
  '🎶',
  '🎼',
};

bool containsMusicalSymbol(String text) {
  for (final rune in text.runes) {
    if (_musicalGapSymbols.contains(String.fromCharCode(rune))) return true;
  }
  return false;
}

/// Lines that are only musical symbols (or whitespace) should not be shown.
/// The gap loader handles the instrumental break instead.
List<LyricLine> filterMusicalSymbolLines(List<LyricLine> lyrics) {
  return lyrics.where((line) => !containsMusicalSymbol(line.text)).toList();
}

class LyricsGapLoaderState {
  final bool shouldShow;
  final int insertBeforeLyricIndex;

  /// How far through the visible window we are, 0 at the moment the loader
  /// appears and 1 when the next lyric lands. Drives the dot fill, so the
  /// animation is a function of playback position rather than wall clock.
  final double progress;

  const LyricsGapLoaderState({
    required this.shouldShow,
    required this.insertBeforeLyricIndex,
    required this.progress,
  });

  static const hidden = LyricsGapLoaderState(
    shouldShow: false,
    insertBeforeLyricIndex: -1,
    progress: 0,
  );
}

/// Resolves the window `[windowStart, windowEnd]` into visibility and progress.
///
/// Visibility is decided by the window's *length*, not by how much of it is
/// left: once the loader is on screen it stays until the lyric arrives, so its
/// exit animation has room to play instead of popping out early.
LyricsGapLoaderState _stateForWindow({
  required Duration position,
  required Duration windowStart,
  required Duration windowEnd,
  required Duration minimumWindow,
  required int insertBeforeLyricIndex,
}) {
  final span = windowEnd.inMicroseconds - windowStart.inMicroseconds;
  if (span < minimumWindow.inMicroseconds ||
      position < windowStart ||
      position >= windowEnd) {
    return LyricsGapLoaderState.hidden;
  }

  final elapsed = position.inMicroseconds - windowStart.inMicroseconds;
  return LyricsGapLoaderState(
    shouldShow: true,
    insertBeforeLyricIndex: insertBeforeLyricIndex,
    progress: (elapsed / span).clamp(0.0, 1.0),
  );
}

LyricsGapLoaderState computeLyricsGapLoaderState({
  required LyricTimings timings,
  required Duration position,
  required Duration delay,
  required Duration minimumWindow,
  bool simulateEnabled = true,
}) {
  // Walks the lines in place: this runs on every playhead frame.
  var activeIdx = -1;
  var nextIdx = -1;
  var firstIdx = -1;
  for (var i = 0; i < timings.length; i++) {
    if (!timings.isTimed(i)) continue;
    if (firstIdx < 0) firstIdx = i;
    if (timings.startFor(i, simulateEnabled) <= position) {
      activeIdx = i;
    } else {
      nextIdx = i;
      break;
    }
  }

  if (firstIdx < 0) return LyricsGapLoaderState.hidden;

  // Intro gap: the silence starts at zero, so the window opens at [delay].
  if (activeIdx < 0) {
    return _stateForWindow(
      position: position,
      windowStart: delay,
      windowEnd: timings.startFor(firstIdx, simulateEnabled),
      minimumWindow: minimumWindow,
      insertBeforeLyricIndex: firstIdx,
    );
  }

  if (nextIdx < 0) return LyricsGapLoaderState.hidden;

  // Silence starts when the line stops sounding: its last word, or its start
  // when it carries no word timing.
  final soundingEnd = timings.endFor(activeIdx, simulateEnabled) ??
      timings.startFor(activeIdx, simulateEnabled);
  return _stateForWindow(
    position: position,
    windowStart: soundingEnd + delay,
    windowEnd: timings.startFor(nextIdx, simulateEnabled),
    minimumWindow: minimumWindow,
    insertBeforeLyricIndex: nextIdx,
  );
}
