import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/services/shuffle_selector.dart';
import 'package:wispie/domain/services/song_affinity.dart';
import 'package:wispie/models/shuffle_config.dart';

ShuffleCandidate<String> _c(
  String name, {
  double affinity = 0.5,
  int playCount = 0,
  double skipRate = 0.0,
  double saturation = 0.0,
  int? historyIndex,
  bool fav = false,
  bool suggestLess = false,
  bool playlist = false,
}) {
  return ShuffleCandidate<String>(
    payload: name,
    artist: 'artist_$name',
    album: 'album_$name',
    affinity: SongAffinity(
      affinity: affinity,
      recentSaturation: saturation,
      completionRate: 0.5,
      skipRate: skipRate,
      playCount: playCount,
      lastPlayedAt: null,
    ),
    isFavorite: fav,
    isSuggestLess: suggestLess,
    isInPlaylist: playlist,
    historyIndex: historyIndex,
  );
}

final List<ShuffleCandidate<String>> _fixed = [
  _c('a', affinity: 0.95, playCount: 40, skipRate: 0.05, historyIndex: 0),
  _c('b', affinity: 0.7, playCount: 12, saturation: 3.0, fav: true),
  _c('c', affinity: 0.4, playCount: 2, skipRate: 0.6, playlist: true),
  _c('d', affinity: 0.1, playCount: 0, suggestLess: true),
  _c('e', affinity: 0.0, playCount: 0, historyIndex: 15),
  _c('f',
      affinity: 0.85, playCount: 7, historyIndex: 3, fav: true, playlist: true),
];

// Scores captured from the pre-Phase-3 selector. Legacy personalities must
// keep producing exactly these numbers.
const Map<String, List<double>> _golden = {
  'defaultMode': [
    0.1850215232745476,
    0.20131071293914668,
    0.3039388698946803,
    0.06261914688960386,
    0.06499999999999997,
    0.21727438206893654,
  ],
  'explorer': [
    0.04932552698103591,
    0.19222524186558262,
    0.8109177594258989,
    0.27962143411069945,
    0.12124999999999997,
    0.0764258640897483,
  ],
  'consistent': [
    0.3965069359756097,
    0.2765538461538461,
    0.12366666666666667,
    0.012000000000000002,
    0.0245625,
    0.4675295624999999,
  ],
  'custom': [
    0.13611539656464305,
    0.19376508313043525,
    0.23200166067413674,
    0.017740669461678776,
    0.0001,
    0.200587117691195,
  ],
};

void main() {
  final configs = <String, ShuffleConfig>{
    'defaultMode':
        const ShuffleConfig(personality: ShufflePersonality.defaultMode),
    'explorer': const ShuffleConfig(personality: ShufflePersonality.explorer),
    'consistent':
        const ShuffleConfig(personality: ShufflePersonality.consistent),
    'custom': const ShuffleConfig(
      personality: ShufflePersonality.custom,
      mostPlayedWeight: 40,
      leastPlayedWeight: 10,
      favoritesWeight: 30,
      suggestLessWeight: 50,
      playlistSongsWeight: 20,
    ),
  };

  group('legacy golden scores', () {
    for (final name in _golden.keys) {
      test(name, () {
        final weights = ShuffleWeights.forPersonality(configs[name]!);
        final actual = [for (final c in _fixed) scoreCandidate(c, weights)];
        final expected = _golden[name]!;
        expect(actual.length, expected.length);
        for (var i = 0; i < expected.length; i++) {
          expect(actual[i], closeTo(expected[i], 1e-12),
              reason: 'candidate $i');
        }
      });
    }
  });
}
