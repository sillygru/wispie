/// Cleans up a local file's title before it becomes an LRCLIB query. Pure — no
/// I/O — so it can be tested directly.
///
/// Files ripped from video sites arrive tagged like
/// "Artist - Title (Official Audio)". LRCLIB's `track_name` is a filter, so the
/// descriptor suffix and the leading "Artist -" prefix make the search miss
/// even when the lyrics are right there. Stripping them is deliberately
/// conservative: only bracketed groups that carry a known noise word are
/// dropped (so "(Remix)" or "(Acoustic)" — which pick out a distinct recording
/// — survive), and the leading prefix is removed only when it actually matches
/// the file's own artist tag.
library;

/// Words that mark a bracketed group as a descriptor rather than part of the
/// song name. Matched as substrings, lower-cased, so "lyric" covers "Lyrics"
/// and "Lyric Video".
const _noiseWords = <String>{
  'official',
  'audio',
  'video',
  'lyric',
  'visualizer',
  'visualiser',
  'explicit',
  'remaster',
  'hd',
  'hq',
  '4k',
  'mv',
  'prod',
};

final _bracketGroup = RegExp(r'[\(\[]([^\)\]]*)[\)\]]');
final _artistPrefix = RegExp(r'^(.*?)\s*[-–—:|]\s*(.+)$');
final _edgeSeparators = RegExp(r'^[-–—:|\s]+|[-–—:|\s]+$');

/// Returns [title] with descriptor brackets and a matching "Artist -" prefix
/// removed. Falls back to the original when cleaning would leave nothing.
String cleanSearchTitle(String title, {String? artist}) {
  var result = title.replaceAllMapped(_bracketGroup, (match) {
    final inner = match.group(1)!.toLowerCase();
    return _noiseWords.any(inner.contains) ? '' : match.group(0)!;
  });

  final a = artist?.trim() ?? '';
  if (a.isNotEmpty) {
    final match = _artistPrefix.firstMatch(result);
    if (match != null && _normalize(match.group(1)!) == _normalize(a)) {
      result = match.group(2)!;
    }
  }

  final cleaned = _collapse(result);
  return cleaned.isEmpty ? title.trim() : cleaned;
}

/// One way to ask a lyrics provider for a track.
class LyricsQuery {
  final String title;

  /// Null when the title alone is the query: passing a wrong artist name is a
  /// hard filter on some providers and turns a near-hit into no hit.
  final String? artist;

  const LyricsQuery(this.title, this.artist);
}

/// The upload title's "Artist - Song" prefix, or null when it does not have one.
final _uploadArtistPrefix = RegExp(r'^(.{2,60}?)\s+[-–—]\s+(.+)$');

/// Every plausible reading of a remote track's tags, best first.
///
/// A streamed track's tags are the uploader's: the title is usually
/// "Artist - Song (Official Video)" and the artist is the channel ("Dan Music",
/// "Aurora - Topic"). Asking the lyrics API once with those tags misses even
/// when the words are available, so each reading is tried: the title's own
/// artist, the channel with the cleaned title, and the title alone. Local files
/// keep a single query — their tags are the release's.
List<LyricsQuery> lyricsQueriesFor({
  required String title,
  required String artist,
  bool remote = false,
}) {
  final rawTitle = title.trim();
  if (rawTitle.isEmpty) return const [];
  final rawArtist = artist.trim();
  final queries = <LyricsQuery>[];
  final seen = <String>{};

  void add(String candidateTitle, String? candidateArtist) {
    final cleanTitle = candidateTitle.trim();
    if (cleanTitle.isEmpty) return;
    final cleanArtist = (candidateArtist ?? '').trim();
    final key = '${_normalize(cleanTitle)}|${_normalize(cleanArtist)}';
    if (!seen.add(key)) return;
    queries
        .add(LyricsQuery(cleanTitle, cleanArtist.isEmpty ? null : cleanArtist));
  }

  final split = remote ? _uploadArtistPrefix.firstMatch(rawTitle) : null;
  if (split != null) {
    final prefix = split.group(1)!.trim();
    final rest = split.group(2)!.trim();
    final restTitle = cleanSearchTitle(rest);
    // The title itself names the recording artist, which beats the channel.
    add(restTitle, prefix);
    add(restTitle, null);
    if (rawArtist.isNotEmpty) add(restTitle, rawArtist);
  }

  // The plain reading of the tags, last: it is right when the upload title is
  // already the release title, and wrong when it carries an "Artist - " prefix
  // the artist tag does not repeat.
  add(cleanSearchTitle(rawTitle, artist: rawArtist), rawArtist);
  if (!remote) return queries;

  add(cleanSearchTitle(rawTitle, artist: rawArtist), null);
  return queries;
}

/// Collapses whitespace and trims stray leading/trailing separators left behind
/// once a bracket or prefix is removed.
String _collapse(String value) {
  final spaced = value.replaceAll(RegExp(r'\s+'), ' ');
  return spaced.replaceAll(_edgeSeparators, '');
}

/// Casefold + strip punctuation + collapse whitespace, so a prefix compares
/// equal to the artist tag regardless of styling.
String _normalize(String value) {
  final lowered = value.toLowerCase();
  final stripped = lowered.replaceAll(RegExp(r'[^\w\s]', unicode: true), ' ');
  return stripped.trim().replaceAll(RegExp(r'\s+'), ' ');
}
