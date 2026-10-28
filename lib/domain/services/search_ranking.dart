// SPDX-License-Identifier: GPL-3.0-only
import '../models/search_result.dart';
import 'search_taste.dart';

/// Ranking for search results, kept free of the index and of Flutter.
///
/// The order is deliberate and each step answers a different question: which
/// field matched (a song before an artist entry), how good the match was inside
/// that field (a whole word before a fragment), whether this device cares about
/// the row, and only then where in the text it landed. Taste never outranks
/// match quality: a favourite that half-matches must not beat an exact hit.
List<SearchResult> rankSearchResults({
  required List<SearchResult> results,
  required String query,
  SearchTaste taste = SearchTaste.empty,
}) {
  final lowerQuery = query.toLowerCase().trim();
  if (lowerQuery.isEmpty) return results;
  final tokens = searchTokens(lowerQuery);

  final ranked = [...results];
  ranked.sort((a, b) {
    final priority = matchPriority(a).compareTo(matchPriority(b));
    if (priority != 0) return priority;

    final wordScore = wordMatchScore(a, tokens).compareTo(
      wordMatchScore(b, tokens),
    );
    if (wordScore != 0) return wordScore;

    final tasteScore = taste.scoreOf(b.song).compareTo(taste.scoreOf(a.song));
    if (tasteScore != 0) return tasteScore;

    final position = matchPosition(a, lowerQuery).compareTo(
      matchPosition(b, lowerQuery),
    );
    if (position != 0) return position;

    return a.song.title.toLowerCase().compareTo(b.song.title.toLowerCase());
  });
  return ranked;
}

/// Query split into the words the ranker compares against.
List<String> searchTokens(String query) => query
    .toLowerCase()
    .split(RegExp(r'\s+'))
    .where((token) => token.isNotEmpty)
    .toList();

/// 0 for a title hit, then artist, album and lyrics.
int matchPriority(SearchResult result) {
  if (result.matchedTitle) return 0;
  if (result.matchedArtist) return 1;
  if (result.matchedAlbum) return 2;
  if (result.hasLyricsMatch) return 3;
  return 4;
}

/// The field the result matched on, lowercased.
String matchedTextOf(SearchResult result) {
  if (result.hasLyricsMatch && result.lyricsMatch != null) {
    return result.lyricsMatch!.fullLine.toLowerCase();
  }
  if (result.matchedTitle) return result.song.title.toLowerCase();
  if (result.matchedArtist) return result.song.artist.toLowerCase();
  if (result.matchedAlbum) return result.song.album.toLowerCase();
  return '';
}

/// 0 when every query token is a whole word, 1 when every token begins a
/// word, 2 otherwise.
///
/// The middle tier is what makes typing feel clairvoyant: `swee` already puts
/// "Sweet Child O' Mine" above a title where the same letters sit inside
/// another word, which a plain substring check cannot tell apart.
int wordMatchScore(SearchResult result, List<String> tokens) {
  final text = matchedTextOf(result);
  if (text.isEmpty) return 2;
  final words = text
      .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      .where((word) => word.isNotEmpty)
      .toList();
  if (words.isEmpty) return 2;

  var score = 0;
  for (final token in tokens) {
    if (words.contains(token)) continue;
    if (words.any((word) => word.startsWith(token))) {
      if (score < 1) score = 1;
      continue;
    }
    return 2;
  }
  return score;
}

/// Earliest index of the query in the matched text, or a large value when the
/// tokens are present but the phrase is not.
int matchPosition(SearchResult result, String lowerQuery) {
  final text = matchedTextOf(result);
  if (text.isEmpty) return 999999;
  final index = text.indexOf(lowerQuery);
  return index == -1 ? 999999 : index;
}
