// SPDX-License-Identifier: GPL-3.0-only
import '../../models/song.dart';
import 'taste_model.dart';

/// Listening history, reduced to the question the search ranker asks: how much
/// does this listener care about this row?
///
/// Built once per history change (see `searchTasteProvider`), never per
/// keystroke: ranking only does two map lookups per comparison, so a query the
/// user types into costs the same whether or not taste is in play.
class SearchTaste {
  /// filename -> 0..1, from the same affinity model shuffle scores with.
  final Map<String, double> songs;

  /// `tasteArtistKey` -> 0..1, from the smart model's recency-weighted mass.
  final Map<String, double> artists;

  const SearchTaste({this.songs = const {}, this.artists = const {}});

  static const SearchTaste empty = SearchTaste();

  bool get isEmpty => songs.isEmpty && artists.isEmpty;

  /// 0..1 for one row. The artist channel leads, because "the one by an artist
  /// I play constantly" is what a tie between two equally good matches is
  /// really asking; the row's own affinity breaks ties within one artist.
  double scoreOf(Song song) {
    if (isEmpty) return 0;
    final byArtist = artists[tasteArtistKey(song.artist, song.filename)] ?? 0;
    final bySong = songs[song.filename] ?? 0;
    return 0.55 * byArtist + 0.45 * bySong;
  }
}
