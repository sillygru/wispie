// SPDX-License-Identifier: GPL-3.0-only
import '../../data/rust/native_command.dart';
import 'youtube_item_wire.dart';
import 'youtube_library.dart';

/// One row of the listener's own library, reduced to what the feed needs.
class YouTubeTasteSignal {
  final String artist;
  final String title;
  final int playCount;
  final bool favorite;

  /// Set when the row is itself a YouTube track, so the feed never suggests it
  /// back to the listener.
  final String? videoId;

  /// Days since the last real listen, or null when the row was never played.
  /// An artist the listener stopped queueing months ago must fall out of the
  /// feed, which a lifetime play count cannot express.
  final double? ageDays;

  const YouTubeTasteSignal({
    required this.artist,
    required this.title,
    this.playCount = 0,
    this.favorite = false,
    this.videoId,
    this.ageDays,
  });
}

/// What this device plays, in the shape the feed ranker needs.
class YouTubeTasteProfile {
  /// [artistKey] -> 0..1, strongest artist at 1.
  final Map<String, double> artistWeights;

  /// Display names of the strongest artists, in the order they should be
  /// searched.
  final List<String> topArtists;

  /// Video ids already known locally.
  final Set<String> knownVideoIds;

  /// `artist|title` keys already known locally.
  final Set<String> knownTrackKeys;

  const YouTubeTasteProfile({
    this.artistWeights = const {},
    this.topArtists = const [],
    this.knownVideoIds = const {},
    this.knownTrackKeys = const {},
  });

  bool get isEmpty => artistWeights.isEmpty;
}

/// Which pool a candidate came from.
///
/// The account's shelves are allowed to *suggest*; the listener's own history
/// decides. That ordering is the whole point: signed-in state used to hand the
/// feed to YouTube's home page, which follows watch history and subscriptions
/// rather than what is actually played here.
enum YouTubeFeedSource {
  /// YouTube Music's own home shelves.
  accountFeed,

  /// A music-catalogue search seeded with an artist from the local library.
  libraryArtist,
}

class YouTubeFeedCandidate {
  final YouTubePlaylistItem item;
  final YouTubeFeedSource source;

  const YouTubeFeedCandidate({required this.item, required this.source});
}

/// How much an artist's long-run (90-day) taste mass counts next to the
/// 30-day trend. Low on purpose: the complaint this answers is "artists I have
/// not listened to in months", so a heavy history alone must not carry an
/// artist back into the feed.
const double kYouTubeLongTasteShare = 0.15;

/// Builds the taste snapshot from library rows.
///
/// Two channels are blended. The library channel counts play history plus a
/// favorite bonus, discounted by how long ago each title was last played, and
/// normalized so the strongest artist is 1. The [artistTaste] channel is the
/// smart-shuffle model's own recency-weighted mass per artist, keyed like
/// [artistKey]. When it is empty — a fresh install, or a library nobody has
/// played — the library channel decides alone, so a new listener still gets a
/// feed built from what they actually own.
YouTubeTasteProfile buildYouTubeTasteProfile(
  Iterable<YouTubeTasteSignal> signals, {
  int maxArtists = 4,
  Map<String, double> artistTaste = const {},
}) {
  final reply = _feed('taste_profile', {
    'signals': [
      for (final signal in signals)
        {
          'artist': signal.artist,
          'title': signal.title,
          'play_count': signal.playCount,
          'favorite': signal.favorite,
          'video_id': signal.videoId,
          'age_days': signal.ageDays,
        },
    ],
    'max_artists': maxArtists,
    'artist_taste': artistTaste,
  });
  return YouTubeTasteProfile(
    artistWeights: {
      for (final entry in (reply['artist_weights'] as Map).entries)
        entry.key as String: (entry.value as num).toDouble(),
    },
    topArtists: [
      for (final name in reply['top_artists'] as List? ?? const [])
        name as String,
    ],
    knownVideoIds: {
      for (final id in reply['known_video_ids'] as List? ?? const [])
        id as String,
    },
    knownTrackKeys: {
      for (final key in reply['known_track_keys'] as List? ?? const [])
        key as String,
    },
  );
}

Map<String, dynamic> _feed(String action, Map<String, Object?> request) =>
    runCoreCommand('music_feed', {'action': action, ...request});

Map<String, Object?> _tasteWire(YouTubeTasteProfile taste) => {
      'artist_weights': taste.artistWeights,
      'known_video_ids': taste.knownVideoIds.toList(),
      'known_track_keys': taste.knownTrackKeys.toList(),
    };

String _sourceWire(YouTubeFeedSource source) => switch (source) {
      YouTubeFeedSource.accountFeed => 'account_feed',
      YouTubeFeedSource.libraryArtist => 'library_artist',
    };

/// A normalized artist name: lowercase, without YouTube's channel decoration.
///
/// `Artist - Topic`, `ArtistVEVO` and `Artist Official` are the same listener
/// as `Artist`, and matching them separately would make half the taste history
/// invisible.
String artistKey(String raw) =>
    _feed('artist_key', {'value': raw})['value'] as String? ?? '';

/// The name to show, with YouTube's channel decoration removed.
String displayArtist(String raw) =>
    _feed('display_artist', {'value': raw})['value'] as String? ?? '';

/// Dedupe key for a track, independent of video id and title decoration.
String trackKey(String artist, String title) =>
    _feed('track_key', {'artist': artist, 'title': title})['value']
        as String? ??
    '';

/// Lowercase, bracket-stripped title with punctuation collapsed.
String titleKey(String raw) =>
    _feed('title_key', {'value': raw})['value'] as String? ?? '';

/// True when a byline is a real artist name rather than a row label.
bool isPlausibleArtist(String raw) =>
    _feed('plausible_artist', {'value': raw})['plausible'] == true;

/// How much a title reads like a music upload, 0..1.
double musicEvidence(YouTubePlaylistItem item) =>
    (_feed('evidence', {'item': youtubeItemToWire(item)})['evidence'] as num?)
        ?.toDouble() ??
    0;

/// Verdict for a single candidate, with the reason kept for the probe.
class MusicFeedVerdict {
  final bool accepted;
  final String reason;

  const MusicFeedVerdict(this.accepted, this.reason);
}

/// Whether [item] belongs in a music feed at all.
///
/// Both pools are music-scoped at the source, so this is a cleanup rather than a
/// classifier: drop the stray podcast row, the Short and the full programme,
/// keep the songs.
MusicFeedVerdict judgeMusicCandidate(YouTubeFeedCandidate candidate) {
  final reply = _feed('judge', {
    'item': youtubeItemToWire(candidate.item),
    'source': _sourceWire(candidate.source),
  });
  return MusicFeedVerdict(
    reply['accepted'] == true,
    reply['reason'] as String? ?? '',
  );
}

/// Relevance of a candidate: mostly the listener's own history.
double scoreMusicCandidate(
  YouTubeFeedCandidate candidate,
  YouTubeTasteProfile taste,
) =>
    (_feed('score', {
      'item': youtubeItemToWire(candidate.item),
      'source': _sourceWire(candidate.source),
      'taste': _tasteWire(taste),
    })['score'] as num?)
        ?.toDouble() ??
    0;

/// Ranks and filters a candidate pool into the feed.
///
/// [limit] rows, at most [maxPerArtist] per artist, never a track already in the
/// library and never a repeated title. Order comes from [scoreMusicCandidate],
/// so an artist the listener actually plays outranks anything the account's
/// shelves merely offer.
List<YouTubePlaylistItem> rankYouTubeMusicFeed({
  required YouTubeTasteProfile taste,
  required Iterable<YouTubeFeedCandidate> candidates,
  int limit = 18,
  int maxPerArtist = 2,
}) {
  final reply = _feed('rank', {
    'taste': _tasteWire(taste),
    'candidates': [
      for (final candidate in candidates)
        {
          'item': youtubeItemToWire(candidate.item),
          'source': _sourceWire(candidate.source),
        },
    ],
    'limit': limit,
    'max_per_artist': maxPerArtist,
  });
  return List.unmodifiable([
    for (final row in reply['items'] as List? ?? const [])
      youtubeItemFromWire(row as Map<String, dynamic>),
  ]);
}

/// Removes the upload decoration from a title: `(Official Video)`, `[4K]`,
/// `(Lyric Video)`, `Official Audio` and the like.
///
/// Only the technical markers are removed. `(Live at Wembley)` and `(Acoustic)`
/// say something about the recording, so they stay.
String cleanMusicTitle(String raw) =>
    _feed('clean_title', {'value': raw})['value'] as String? ?? raw;

/// `Artist - Song` split into its parts. A title like this is the most common
/// shape for an upload that carries no artist field.
({String artist, String title}) splitTitleAndArtist(YouTubePlaylistItem item) {
  final reply = _feed('split', {'item': youtubeItemToWire(item)});
  return (
    artist: reply['artist'] as String? ?? '',
    title: reply['title'] as String? ?? '',
  );
}

/// Normalizes one catalogue row for display and for dedupe.
YouTubePlaylistItem normalizeMusicTrack(YouTubePlaylistItem item) {
  final row =
      _feed('normalize_track', {'item': youtubeItemToWire(item)})['item'];
  if (row is! Map<String, dynamic>) return item;
  return youtubeItemFromWire(row);
}

/// True when [text] looks like a clock (`3:52`). Exposed so callers can read a
/// duration out of a byline without duplicating the pattern.
bool isClockText(String text) =>
    _feed('clock_text', {'value': text})['clock'] == true;
