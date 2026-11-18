// SPDX-License-Identifier: GPL-3.0-only
import '../../data/rust/wispie_core.dart';
import '../../models/song.dart';
import 'taste_model.dart';

/// Listening history, reduced to the question the search ranker asks: how much
/// does this listener care about this row?
///
/// Built once per history change (see `searchTasteProvider`), never per
/// keystroke. The weighting lives in the native core; this holds the two maps
/// and batches the lookup so ranking still costs no per-song request.
class SearchTaste {
  /// filename -> 0..1, from the same affinity model shuffle scores with.
  final Map<String, double> songs;

  /// `tasteArtistKey` -> 0..1, from the smart model's recency-weighted mass.
  final Map<String, double> artists;

  const SearchTaste({this.songs = const {}, this.artists = const {}});

  static const SearchTaste empty = SearchTaste();

  bool get isEmpty => songs.isEmpty && artists.isEmpty;

  /// 0..1 for each row, in the order given.
  List<double> scoresFor(List<Song> rows) {
    if (isEmpty || rows.isEmpty) {
      return List<double>.filled(rows.length, 0);
    }
    final keys = tasteArtistKeys([
      for (final song in rows) (artist: song.artist, filename: song.filename),
    ]);
    final reply = WispieCore.helper({
      'action': 'taste_scores',
      'items': [
        for (var index = 0; index < rows.length; index++)
          [rows[index].filename, keys[index]],
      ],
      'songScores': songs,
      'artistScores': artists,
    });
    return [
      for (final value in (reply['scores'] as List).cast<num>())
        value.toDouble(),
    ];
  }
}
