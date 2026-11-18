/// Cleans up a local file's title before it becomes an LRCLIB query.
///
/// The descriptor stripping, the artist-prefix check and the multi-reading
/// expansion for streamed tags all live in the native core.
library;

import '../../data/rust/wispie_core.dart';

/// Returns [title] with descriptor brackets and a matching "Artist -" prefix
/// removed. Falls back to the original when cleaning would leave nothing.
String cleanSearchTitle(String title, {String? artist}) => WispieCore.helper({
      'action': 'lrclib_clean',
      'title': title,
      if (artist != null) 'artist': artist,
    })['title'] as String;

/// One way to ask a lyrics provider for a track.
class LyricsQuery {
  final String title;

  /// Null when the title alone is the query: passing a wrong artist name is a
  /// hard filter on some providers and turns a near-hit into no hit.
  final String? artist;

  const LyricsQuery(this.title, this.artist);
}

/// Every plausible reading of a remote track's tags, best first.
List<LyricsQuery> lyricsQueriesFor({
  required String title,
  required String artist,
  bool remote = false,
}) {
  final reply = WispieCore.helper({
    'action': 'lrclib_queries',
    'title': title,
    'artist': artist,
    'remote': remote,
  });
  return [
    for (final query in (reply['queries'] as List).cast<List>())
      LyricsQuery(
        query[0] as String,
        query[1] == null ? null : query[1] as String,
      ),
  ];
}
