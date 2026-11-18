import 'dart:ffi';
import 'dart:math' as math;
import 'dart:typed_data';

import '../../data/rust/wispie_core.dart';
import '../../models/song.dart';
import '../models/rich_lyrics.dart';

/// One lyric sheet's resolved timings, packed by the native core.
///
/// Columns per line: timed, line start, start with simulated words, start
/// without, end with simulated words (-1 none), end without, simulated flag.
/// The word trust rules live in the core, so callers only pick a column.
class LyricTimings {
  LyricTimings._(this.length, this._buffer, this._scratch);

  final int length;
  final Int64List _buffer;
  final NativeScratch? _scratch;

  static final LyricTimings empty = LyricTimings._(0, Int64List(0), null);

  bool isTimed(int index) =>
      index >= 0 && index < length && _buffer[index * _stride] != 0;

  Duration startFor(int index, bool simulateEnabled) {
    if (index < 0 || index >= length) return Duration.zero;
    final column = simulateEnabled ? 2 : 3;
    return Duration(microseconds: _buffer[index * _stride + column]);
  }

  Duration? endFor(int index, bool simulateEnabled) {
    if (index < 0 || index >= length) return null;
    final value = _buffer[index * _stride + (simulateEnabled ? 4 : 5)];
    return value < 0 ? null : Duration(microseconds: value);
  }

  void dispose() => _scratch?.dispose();

  static const int _stride = 7;
}

const int _timingStride = 7;

/// Resolves every line's timing once per lyric load.
LyricTimings buildLyricTimings(
  List<LyricLine> lyrics,
  List<RichLyricLine?> wordLines,
) {
  final rows = <Object?>[];
  for (var index = 0; index < lyrics.length; index++) {
    final line = lyrics[index];
    final words = index < wordLines.length ? wordLines[index] : null;
    rows.add([
      line.time.inMicroseconds,
      line.isSynced,
      words?.isSimulated ?? false,
      words == null
          ? null
          : [
              for (final word in words.words)
                [word.start.inMicroseconds, word.end.inMicroseconds],
            ],
    ]);
  }

  final reply = WispieCore.helper({
    'action': 'lyrics_timings',
    'lines': rows,
  });
  final raw = (reply['timings'] as List).cast<List>();
  final bytes = math.max(1, raw.length * _timingStride) * 8;
  final scratch = NativeScratch(bytes);
  final buffer = scratch.longs;
  for (var index = 0; index < raw.length; index++) {
    final row = raw[index];
    for (var column = 0; column < _timingStride; column++) {
      buffer[index * _timingStride + column] = (row[column] as num).toInt();
    }
  }
  return LyricTimings._(raw.length, buffer, scratch);
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

NativeScratch? _activityOut;
int _activityCapacity = 0;

NativeScratch _outputFor(int needed) {
  final capacity = math.max(64, needed);
  if (_activityOut == null || _activityCapacity < capacity) {
    _activityOut?.dispose();
    _activityOut = NativeScratch(capacity * 4);
    _activityCapacity = capacity;
  }
  return _activityOut!;
}

/// Lines sounding at [position].
///
/// A line runs from its start until its last word ends; when it has no words it
/// runs until the next line starts. With nothing sounding the newest line is
/// held, which is what keeps the last lyric lit through an instrumental break.
LyricsActivity lyricsActivityAt(
  LyricTimings timings,
  Duration position, {
  bool simulateEnabled = true,
}) {
  if (timings.length == 0) return LyricsActivity.idle;
  final capacity = 2 + timings.length;
  final out = _outputFor(capacity);
  final written = WispieCore.lyricsActivity(
    timings: timings._scratch!.pointer.cast<Int64>(),
    count: timings.length,
    positionUs: position.inMicroseconds,
    simulate: simulateEnabled,
    out: out.pointer.cast<Int32>(),
    outCapacity: _activityCapacity,
  );
  if (written < 2) return LyricsActivity.idle;
  final ints = out.ints;
  return LyricsActivity(
    latest: ints[0],
    active: {
      for (var index = 2; index < written; index++) ints[index],
    },
  );
}
