// Repeatable check for the word-aware lyric line switching.
//
//   dart run tool/lyrics_activity_probe.dart
//
// Exits non-zero if any case regresses, so it can be re-run after touching
// `lyrics_activity.dart`.
import 'dart:io';

import 'package:wispie/domain/models/rich_lyrics.dart';
import 'package:wispie/domain/services/lyrics_activity.dart';
import 'package:wispie/models/song.dart';

Duration _at(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());

RichLyricWord _word(double start, double end, String text) =>
    RichLyricWord(start: _at(start), end: _at(end), text: text);

RichLyricLine _rich(
        double start, double end, String text, List<RichLyricWord> words) =>
    RichLyricLine(start: _at(start), end: _at(end), text: text, words: words);

LyricLine _line(double start, String text) =>
    LyricLine(time: _at(start), text: text, isSynced: true);

int _failures = 0;

void _expect(String label, LyricsActivity activity, Set<int> expected) {
  final actual = activity.active;
  final ok = actual.length == expected.length &&
      actual.containsAll(expected) &&
      expected.containsAll(actual);
  if (!ok) _failures++;
  stdout.writeln(
    '${ok ? 'ok  ' : 'FAIL'} $label -> ${actual.toList()..sort()}',
  );
}

void main() {
  // A line marked 1.5s before its first word is sung: the previous line must
  // keep singing until that word arrives.
  final early = buildLyricTimings(
    [_line(10.0, 'one'), _line(11.5, 'two')],
    <RichLyricLine?>[
      _rich(10.0, 12.0, 'one', [_word(10.8, 12.0, 'one')]),
      _rich(11.5, 13.5, 'two', [_word(12.4, 13.5, 'two')]),
    ],
  );
  _expect('holds the line past its own end', lyricsActivityAt(early, _at(11.6)),
      {0});
  _expect('switches on the next first word', lyricsActivityAt(early, _at(12.5)),
      {1});
  _expect('idle before the first word', lyricsActivityAt(early, _at(10.4)),
      <int>{});

  // Word data that does not march forward is ignored, line timing takes over.
  final broken = buildLyricTimings(
    [_line(10.0, 'one'), _line(12.0, 'two')],
    <RichLyricLine?>[
      _rich(10.0, 12.0, 'one',
          [_word(11.5, 11.8, 'one'), _word(10.2, 10.4, 'one')]),
      _rich(12.0, 13.5, 'two', [_word(12.2, 13.5, 'two')]),
    ],
  );
  _expect('untrusted words fall back to line start',
      lyricsActivityAt(broken, _at(9.5)), <int>{});
  _expect('untrusted words hold the previous line',
      lyricsActivityAt(broken, _at(12.1)), {0});
  _expect(
      'next real word takes over', lyricsActivityAt(broken, _at(12.3)), {1});

  // A harmony line overlapping the lead: both wipe, the newest is the anchor.
  final harmony = buildLyricTimings(
    [_line(10.0, 'lead'), _line(11.0, 'backing')],
    <RichLyricLine?>[
      _rich(10.0, 12.0, 'lead', [_word(10.0, 12.0, 'lead')]),
      _rich(11.0, 11.5, 'backing', [_word(11.0, 11.5, 'backing')]),
    ],
  );
  final both = lyricsActivityAt(harmony, _at(11.2));
  _expect('both voices sound together', both, {0, 1});
  if (both.anchor != 1 || both.distanceFrom(0) != 0) {
    _failures++;
    stdout.writeln(
        'FAIL both voices anchor=${both.anchor} distance=${both.distanceFrom(0)}');
  }

  // Two lines sharing one start are one moment and run together.
  final together = buildLyricTimings(
    [_line(10.0, 'a'), _line(10.0, 'b'), _line(14.0, 'c')],
    const [],
  );
  _expect('same start runs together', lyricsActivityAt(together, _at(11.0)),
      {0, 1});
  _expect(
      'next distinct start wins', lyricsActivityAt(together, _at(14.5)), {2});

  // Instruments: the last line stays lit until the next one arrives.
  final gap = buildLyricTimings([_line(10.0, 'a'), _line(20.0, 'b')], const []);
  _expect('gap holds the last line', lyricsActivityAt(gap, _at(15.0)), {0});

  stdout.writeln(_failures == 0 ? 'all cases passed' : '$_failures failure(s)');
  if (_failures != 0) exitCode = 1;
}
