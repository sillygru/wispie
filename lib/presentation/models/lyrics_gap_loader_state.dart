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
  required List<LyricLine> lyrics,
  required Duration position,
  required Duration delay,
  required Duration minimumWindow,
}) {
  // Walks the lines in place: this runs on every playhead frame, so building
  // a per-call list of the whole song was pure GC churn.
  var activeIdx = -1;
  var nextIdx = -1;
  var firstIdx = -1;
  for (var i = 0; i < lyrics.length; i++) {
    final line = lyrics[i];
    if (!line.isSynced) continue;
    if (firstIdx < 0) firstIdx = i;
    if (line.time <= position) {
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
      windowEnd: lyrics[firstIdx].time,
      minimumWindow: minimumWindow,
      insertBeforeLyricIndex: firstIdx,
    );
  }

  if (nextIdx < 0) return LyricsGapLoaderState.hidden;

  return _stateForWindow(
    position: position,
    windowStart: lyrics[activeIdx].time + delay,
    windowEnd: lyrics[nextIdx].time,
    minimumWindow: minimumWindow,
    insertBeforeLyricIndex: nextIdx,
  );
}
