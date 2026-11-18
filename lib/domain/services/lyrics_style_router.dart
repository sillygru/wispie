import '../../data/rust/wispie_core.dart';
import '../../models/song.dart';

class ExpertConfig {
  final String styleName;
  final double linguisticTempoScale;

  const ExpertConfig({
    required this.styleName,
    required this.linguisticTempoScale,
  });
}

/// Picks the prosodic style the simulated word timings should use.
///
/// The detector (character rate, words per second, title keywords) lives in the
/// native core; this shapes the answer.
class LyricsStyleRouter {
  static (String, ExpertConfig) detectStyle(
    List<LyricLine> lines, {
    Song? song,
  }) {
    final reply = WispieCore.helper({
      'action': 'lyrics_style',
      'lines': [
        for (final line in lines)
          [line.time.inMicroseconds, line.isSynced, line.text],
      ],
      if (song != null)
        'song': {
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'filename': song.filename,
          'durationUs': song.duration?.inMicroseconds,
        },
    });
    final name = reply['style'] as String;
    final config = ExpertConfig(
      styleName: name,
      linguisticTempoScale: (reply['scale'] as num).toDouble(),
    );
    return (name, config);
  }
}
