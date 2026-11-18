// SPDX-License-Identifier: GPL-3.0-only
import '../models/search_result.dart';
import 'native_accel.dart';
import 'search_taste.dart';

/// Ranking for search results, kept free of the index and of Flutter.
///
/// The order is deliberate: which field matched, how good the match was inside
/// that field, whether this device cares about the row, and only then where in
/// the text it landed. The ordering itself runs in the native core.
List<SearchResult> rankSearchResults({
  required List<SearchResult> results,
  required String query,
  SearchTaste taste = SearchTaste.empty,
}) {
  final lowerQuery = query.toLowerCase().trim();
  if (lowerQuery.isEmpty) return results;

  final tastes = taste.scoresFor([for (final result in results) result.song]);
  final order = NativeAccel.rankSearch(
    query: lowerQuery,
    results: [
      for (var index = 0; index < results.length; index++)
        (
          title: results[index].song.title,
          artist: results[index].song.artist,
          album: results[index].song.album,
          matchedTitle: results[index].matchedTitle,
          matchedArtist: results[index].matchedArtist,
          matchedAlbum: results[index].matchedAlbum,
          lyricsLine: results[index].lyricsMatch?.fullLine,
          taste: tastes[index],
        ),
    ],
  );
  return [for (final index in order) results[index]];
}

/// 0 for a title hit, then artist, album and lyrics.
int matchPriority(SearchResult result) {
  if (result.matchedTitle) return 0;
  if (result.matchedArtist) return 1;
  if (result.matchedAlbum) return 2;
  if (result.hasLyricsMatch) return 3;
  return 4;
}
