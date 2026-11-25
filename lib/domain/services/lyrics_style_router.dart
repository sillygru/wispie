import 'dart:math' as math;

import '../../models/song.dart';

class ExpertConfig {
  final String styleName;
  final double linguisticTempoScale;

  const ExpertConfig({
    required this.styleName,
    required this.linguisticTempoScale,
  });
}

/// Picks the prosodic style for simulated word timings.
class LyricsStyleRouter {
  static const _pop =
      ExpertConfig(styleName: 'POP_ELECTRONIC', linguisticTempoScale: 1);
  static const _rap =
      ExpertConfig(styleName: 'RAP_HIPHOP', linguisticTempoScale: 1.15);
  static const _rock =
      ExpertConfig(styleName: 'ROCK_DISTORTED', linguisticTempoScale: 0.95);
  static const _ballad =
      ExpertConfig(styleName: 'SLOW_BALLAD', linguisticTempoScale: 0.90);

  static const _rockKeywords = [
    'deftones',
    'bleachers',
    'die for you',
    'one more hour',
    'katseye',
    'rock',
    'metal',
  ];
  static final _whitespace = RegExp(
      r'[\u0009-\u000D\u0020\u0085\u00A0\u1680\u2000-\u200A\u2028\u2029\u202F\u205F\u3000]+');

  static (String, ExpertConfig) detectStyle(
    List<LyricLine> lines, {
    Song? song,
  }) {
    final synced = lines.where((line) => line.isSynced).toList();
    if (synced.isEmpty) return (_pop.styleName, _pop);

    final rates = <double>[];
    var totalWords = 0;
    var durationSum = 0.0;
    for (final (index, line) in synced.indexed) {
      final end =
          index + 1 < synced.length ? synced[index + 1].time : song?.duration;
      final duration = end == null
          ? 3.0
          : math.max(0.1, (end - line.time).inMicroseconds / 1000000);
      final words =
          line.text.split(_whitespace).where((word) => word.isNotEmpty);
      final chars = words.fold(0, (count, word) => count + word.length);
      rates.add(chars / duration);
      totalWords += words.length;
      durationSum += duration;
    }

    rates.sort();
    final tempo = rates[((rates.length - 1) * 0.75).round()];
    final last = synced.last.time;
    final songDuration = song?.duration;
    final end = songDuration != null && songDuration > last
        ? songDuration
        : last + const Duration(seconds: 3);
    final totalDuration =
        math.max(1.0, (end - synced.first.time).inMicroseconds / 1000000);

    if (tempo > 14.5 || totalWords / totalDuration > 2.75) {
      return (_rap.styleName, _rap);
    }
    final metadata = song == null
        ? ''
        : '${song.title} ${song.artist} ${song.album} ${song.filename}'
            .toLowerCase();
    if (_rockKeywords.any(metadata.contains)) {
      return (_rock.styleName, _rock);
    }
    if (tempo < 9.8 && durationSum / synced.length > 3) {
      return (_ballad.styleName, _ballad);
    }
    return (_pop.styleName, _pop);
  }
}
