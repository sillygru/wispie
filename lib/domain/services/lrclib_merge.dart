import '../models/lrclib_result.dart';

/// Combines the two lookups a streamed track needs: one pinned to the video,
/// one built from the tags.
///
/// They answer different questions. The video lookup knows the exact recording
/// but often returns an auto-generated transcript with no timings; the tag
/// lookup finds the released song, with timings, but can land on a different
/// version. Neither alone is reliably the best answer, so the timed one is
/// preferred and the other fills whatever it lacks.
LrclibResult? mergeLrclibResults(
    LrclibResult? videoLookup, LrclibResult? tagLookup) {
  if (videoLookup == null) return tagLookup;
  if (tagLookup == null) return videoLookup;

  final videoRank = _rank(videoLookup);
  final tagRank = _rank(tagLookup);
  final primary = videoRank >= tagRank ? videoLookup : tagLookup;
  final secondary = identical(primary, videoLookup) ? tagLookup : videoLookup;

  return LrclibResult(
    id: primary.id != 0 ? primary.id : secondary.id,
    trackName:
        primary.trackName.isNotEmpty ? primary.trackName : secondary.trackName,
    artistName: primary.artistName.isNotEmpty
        ? primary.artistName
        : secondary.artistName,
    albumName:
        primary.albumName.isNotEmpty ? primary.albumName : secondary.albumName,
    duration: primary.duration ?? secondary.duration,
    instrumental: primary.instrumental || secondary.instrumental,
    plainLyrics: primary.plainLyrics ?? secondary.plainLyrics,
    syncedLyrics: primary.syncedLyrics ?? secondary.syncedLyrics,
    richLyrics: primary.richLyrics ?? secondary.richLyrics,
  );
}

/// Timed lyrics outrank untimed ones; between two untimed records the longer
/// body wins, because a short one is usually a snippet.
int _rank(LrclibResult result) {
  if (result.hasRichSync) return 3;
  if (result.hasSynced) return 2;
  return 1;
}
