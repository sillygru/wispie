import '../../models/song.dart';
import '../models/lrclib_result.dart';
import 'native_accel.dart';

/// Sorts usable LRCLIB candidates best-first, keeping incoming tie order.
List<LrclibResult> rankLrclibResults(
  List<LrclibResult> results,
  Song song, {
  bool preferPlain = false,
}) {
  final order = NativeAccel.rankLrclibResults(
    [for (final result in results) _resultPayload(result)],
    _songPayload(song),
    preferPlain: preferPlain,
  );
  return [for (final index in order) results[index]];
}

/// Returns the ranking score used to order an LRCLIB candidate.
double scoreLrclibResult(
  LrclibResult result,
  Song song, {
  bool preferPlain = false,
}) =>
    NativeAccel.scoreLrclibResult(
      _resultPayload(result),
      _songPayload(song),
      preferPlain: preferPlain,
    );

Map<String, Object?> _resultPayload(LrclibResult result) => {
      'trackName': result.trackName,
      'artistName': result.artistName,
      'albumName': result.albumName,
      'durationUs': result.duration?.inMicroseconds,
      'instrumental': result.instrumental,
      'hasPlain': result.hasPlain,
      'hasSynced': result.hasSynced,
      'hasRichSync': result.hasRichSync,
    };

Map<String, Object?> _songPayload(Song song) => {
      'title': song.title,
      'artist': song.artist,
      'album': song.album,
      'durationUs': song.duration?.inMicroseconds,
    };
