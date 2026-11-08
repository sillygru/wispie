// SPDX-License-Identifier: GPL-3.0-only

import '../models/rich_lyrics.dart';
import 'native_accel.dart';

/// Word-level timing inside a lyric line.
///
/// The model (feature extraction, the residual network and the pause split)
/// runs in the native core; there is no Dart implementation behind this.
class LyricsProsodicEstimator {
  const LyricsProsodicEstimator._();

  static List<RichLyricWord> estimateLineWords(
    String text,
    Duration lineStart,
    Duration lineEnd, {
    double songCps = 13.5,
  }) =>
      estimateLinesWords([
        (
          text: text,
          start: lineStart,
          end: lineEnd,
          songCps: songCps,
        ),
      ]).first;

  /// Every timed line in one call, so a whole sheet costs one crossing.
  static List<List<RichLyricWord>> estimateLinesWords(
    List<({String text, Duration start, Duration end, double songCps})> lines,
  ) {
    final timed = NativeAccel.prosodyLines([
      for (final line in lines)
        (
          text: line.text,
          startUs: line.start.inMicroseconds,
          endUs: line.end.inMicroseconds,
          songCps: line.songCps,
        ),
    ]);

    return [
      for (final words in timed)
        [
          for (final word in words)
            RichLyricWord(
              start: Duration(microseconds: word.startUs),
              end: Duration(microseconds: word.endUs),
              text: word.text,
            ),
        ],
    ];
  }
}
