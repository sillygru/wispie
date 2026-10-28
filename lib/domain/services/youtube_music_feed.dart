// SPDX-License-Identifier: GPL-3.0-only
import 'dart:math' as math;

import 'song_affinity.dart';
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

/// Half-life of the per-title recency discount, in days.
const double kYouTubeRecencyHalfLifeDays = 45.0;

/// How much an artist's long-run (90-day) taste mass counts next to the
/// 30-day trend. Low on purpose: the complaint this answers is "artists I have
/// not listened to in months", so a heavy history alone must not carry an
/// artist back into the feed.
const double kYouTubeLongTasteShare = 0.15;

/// Share of the final artist weight that comes from the library itself.
///
/// Taste leads; ownership still seeds the feed, which is the whole answer for a
/// listener who has imported a library but barely played it yet.
const double kYouTubeLibraryShare = 0.25;

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
  final raw = <String, double>{};
  final display = <String, String>{};
  final knownVideoIds = <String>{};
  final knownTrackKeys = <String>{};

  for (final signal in signals) {
    final key = artistKey(signal.artist);
    // A placeholder byline is not a taste signal, and searching it would return
    // whatever YouTube has for those words.
    if (isPlausibleArtist(signal.artist)) {
      // Ownership and a favorite are intent, so they do not age; repeats do.
      final weight =
          1 + signal.playCount * _recencyOf(signal) + (signal.favorite ? 6 : 0);
      raw[key] = (raw[key] ?? 0) + weight;
      display.putIfAbsent(key, () => displayArtist(signal.artist));
    }
    final videoId = signal.videoId;
    if (videoId != null && videoId.isNotEmpty) knownVideoIds.add(videoId);
    if (titleKey(signal.title).isNotEmpty) {
      knownTrackKeys.add(trackKey(signal.artist, signal.title));
    }
  }

  final library = _normalized(raw);
  final taste = _normalized({
    for (final entry in artistTaste.entries)
      if (entry.value > 0) artistKey(entry.key): entry.value,
  });
  // A taste artist whose local rows are gone still needs a searchable name, or
  // the strongest thing this device ever played could never be seeded.
  for (final entry in artistTaste.entries) {
    final key = artistKey(entry.key);
    final name = entry.key.trim();
    if (key.isNotEmpty && name.isNotEmpty) {
      display.putIfAbsent(key, () => name);
    }
  }

  if (library.isEmpty && taste.isEmpty) {
    return YouTubeTasteProfile(
      knownVideoIds: knownVideoIds,
      knownTrackKeys: knownTrackKeys,
    );
  }

  final blended = <String, double>{};
  for (final key in {...library.keys, ...taste.keys}) {
    final weight = taste.isEmpty
        ? library[key] ?? 0
        : (1 - kYouTubeLibraryShare) * (taste[key] ?? 0) +
            kYouTubeLibraryShare * (library[key] ?? 0);
    // An artist the listener has not touched in months sinks here rather than
    // borrowing a slot the top four artists should own.
    if (weight >= 0.05) blended[key] = weight;
  }

  final weights = _normalized(blended);
  final topArtists = (weights.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value)))
      .take(maxArtists)
      .map((entry) => display[entry.key])
      .whereType<String>()
      .toList();

  return YouTubeTasteProfile(
    artistWeights: weights,
    topArtists: topArtists,
    knownVideoIds: knownVideoIds,
    knownTrackKeys: knownTrackKeys,
  );
}

/// Multiplier for one row's repeat plays, decaying on
/// [kYouTubeRecencyHalfLifeDays].
///
/// A row with no known last listen keeps full weight: without a timestamp the
/// play count is all there is. The floor keeps a genuinely abandoned favourite
/// from vanishing from the ranking entirely.
double _recencyOf(YouTubeTasteSignal signal) {
  final ageDays = signal.ageDays;
  if (ageDays == null || signal.playCount <= 0) return 1.0;
  return 0.1 + 0.9 * decayFactor(ageDays, kYouTubeRecencyHalfLifeDays);
}

/// Scales [values] so the strongest entry is 1, dropping empty ones.
Map<String, double> _normalized(Map<String, double> values) {
  final usable = {
    for (final entry in values.entries)
      if (entry.key.isNotEmpty && entry.value > 0) entry.key: entry.value,
  };
  if (usable.isEmpty) return const {};
  final strongest = usable.values.reduce(math.max);
  if (strongest <= 0) return const {};
  return {
    for (final entry in usable.entries) entry.key: entry.value / strongest,
  };
}

/// A normalized artist name: lowercase, without YouTube's channel decoration.
///
/// `Artist - Topic`, `ArtistVEVO` and `Artist Official` are the same listener
/// as `Artist`, and matching them separately would make half the taste history
/// invisible.
String artistKey(String raw) {
  var value = stripTopicSuffix(raw).toLowerCase();
  value = value.replaceAll(RegExp(r'\s*-?\s*vevo$'), '');
  value = value.replaceAll(
    RegExp(r'\s*[-–]\s*(official|music|records|label|channel)$'),
    '',
  );
  value = value.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
  value = value.replaceFirst(RegExp(r'^the '), '');
  return value.trim();
}

/// The name to show, with YouTube's channel decoration removed.
String displayArtist(String raw) {
  var value = stripTopicSuffix(raw).trim();
  value = value.replaceAll(RegExp(r'\s*-?\s*vevo$', caseSensitive: false), '');
  return value.trim();
}

/// Dedupe key for a track, independent of video id and title decoration.
String trackKey(String artist, String title) =>
    '${artistKey(artist)}|${titleKey(title)}';

/// Lowercase, bracket-stripped title with punctuation collapsed.
String titleKey(String raw) {
  final cleaned = cleanMusicTitle(raw).toLowerCase();
  return cleaned.replaceAll(RegExp(r'[^a-z0-9]+'), ' ').trim();
}

/// Noise markers: these never appear in the title of a track worth suggesting
/// from a catalogue that also hosts every other kind of video.
///
/// The YouTube Music home shelves are music-first but not music-only — podcasts,
/// karaoke/tribute uploads and auto-generated "playlist" collections all show up
/// there — so their titles and bylines are the last line of defence.
const List<String> _videoNoise = [
  'official trailer',
  'trailer',
  'teaser',
  'gameplay',
  'walkthrough',
  'let\'s play',
  'speedrun',
  'unboxing',
  'haul',
  'vlog',
  'prank',
  'reaction',
  'tutorial',
  'how to ',
  'review',
  'press conference',
  'behind the scenes',
  'making of',
  'bloopers',
  'podcast',
  'full episode',
  'karaoke',
  // Not `tribute` on its own: "Tribute" is a real song title.
  'tribute version',
  'originally performed',
  'playlist',
  'compilation',
  'megamix',
  'interview',
  'highlights',
  'match recap',
  'news update',
  'breaking news',
  'shorts',
  'asmr',
];

/// Bylines that name the row's shape rather than an artist. YouTube Music uses
/// these as the artist cell for episodes, albums and videos.
const Set<String> _containerArtists = {
  'episode',
  'episodes',
  'song',
  'songs',
  'video',
  'videos',
  'album',
  'albums',
  'single',
  'playlist',
  'artist',
  'movie',
  'movies',
  'podcast',
  'new release',
  'various artists',
  'unknown',
  'unknown artist',
};

/// True when a byline is a real artist name rather than a row label.
bool isPlausibleArtist(String raw) {
  final value = artistKey(raw);
  if (value.isEmpty) return false;
  return !_containerArtists.contains(value);
}

/// Markers that a title is a music upload even when the channel name is a label
/// or an upload account.
final RegExp _musicMarker = RegExp(
  r'\b(official\s+(music\s+)?(video|audio)|lyric\s+video|lyrics|visuali[sz]er|'
  r'music\s+video|audio\s+only|remaster(ed)?|feat\.?|ft\.?|'
  r'instrumental|acoustic|live\s+at|official\s+audio)\b',
  caseSensitive: false,
);

const String _bracketGroup = r'\(([^)]*)\)|\[([^\]]*)\]';
const String _clockText = r'^\d{1,2}:\d{2}(?::\d{2})?$';

/// How much a title reads like a music upload, 0..1.
double musicEvidence(YouTubePlaylistItem item) {
  var score = 0.0;
  final channel = item.artist.trim();
  if (RegExp(r'-\s*topic$', caseSensitive: false).hasMatch(channel)) {
    score += 0.5;
  } else if (RegExp(r'vevo$', caseSensitive: false).hasMatch(channel)) {
    score += 0.5;
  }
  if (_musicMarker.hasMatch(item.title)) score += 0.35;
  if (item.title.contains(' - ') || item.title.contains(' – ')) score += 0.15;

  final duration = item.duration;
  if (duration != null) {
    final seconds = duration.inSeconds;
    // A single track occupies this window; anything outside it is a set, a
    // stream, a Short or a full programme.
    if (seconds >= 75 && seconds <= 8 * 60) {
      score += 0.25;
    } else if (seconds < 60) {
      score -= 0.1;
    }
  }
  // A byline that is a real artist line rather than a channel name (`Some
  // Channel` has a space and no separator; `Artist • Album` was already split).
  if (channel.isNotEmpty && !channel.contains(' - ')) score += 0.05;
  return score.clamp(0.0, 1.0);
}

/// Verdict for a single candidate, with the reason kept for the probe.
class MusicFeedVerdict {
  final bool accepted;
  final String reason;

  const MusicFeedVerdict(this.accepted, this.reason);
}

/// Whether [item] belongs in a music feed at all.
///
/// Both pools are music-scoped at the source: [YouTubeFeedSource.accountFeed]
/// is YouTube Music's home and [YouTubeFeedSource.libraryArtist] is a music
/// catalogue search, neither of which can return a gaming video. That is the
/// real guarantee, and it is why this is a cleanup rather than a classifier:
/// drop the stray podcast row, the Short and the full programme, keep the songs.
MusicFeedVerdict judgeMusicCandidate(YouTubeFeedCandidate candidate) {
  final item = candidate.item;
  final title = item.title.toLowerCase();
  final byline = item.artist.toLowerCase();
  for (final marker in _videoNoise) {
    if (title.contains(marker) || byline.contains(marker)) {
      return MusicFeedVerdict(false, 'noise:$marker');
    }
  }
  if (!isPlausibleArtist(item.artist)) {
    return const MusicFeedVerdict(false, 'no-artist');
  }

  final duration = item.duration;
  if (duration != null) {
    if (duration.inSeconds < 55) {
      return const MusicFeedVerdict(false, 'too-short');
    }
    if (duration.inSeconds > 15 * 60) {
      return const MusicFeedVerdict(false, 'too-long');
    }
  }
  return const MusicFeedVerdict(true, 'music');
}

/// Relevance of a candidate: mostly the listener's own history.
double scoreMusicCandidate(
  YouTubeFeedCandidate candidate,
  YouTubeTasteProfile taste,
) {
  final affinity = taste.artistWeights[artistKey(candidate.item.artist)] ?? 0;
  final evidence = musicEvidence(candidate.item);
  final sourcePrior =
      candidate.source == YouTubeFeedSource.libraryArtist ? 1.0 : 0.35;
  // Affinity dominates: a shelf YouTube suggests has to beat what this device
  // actually plays, not merely attach to it.
  return 0.68 * affinity + 0.18 * evidence + 0.14 * sourcePrior;
}

/// Ranks and filters a candidate pool into the feed.
///
/// [limit] rows, at most [maxPerArtist] per artist, never a track already in the
/// library and never a repeated title. Order comes from
/// [scoreMusicCandidate], so an artist the listener actually plays outranks
/// anything the account's shelves merely offer.
List<YouTubePlaylistItem> rankYouTubeMusicFeed({
  required YouTubeTasteProfile taste,
  required Iterable<YouTubeFeedCandidate> candidates,
  int limit = 18,
  int maxPerArtist = 2,
}) {
  final scored = <_ScoredCandidate>[];
  final seenVideos = <String>{};
  final seenTracks = <String>{};

  for (final candidate in candidates) {
    final item = candidate.item;
    if (item.videoId.isEmpty) continue;
    if (taste.knownVideoIds.contains(item.videoId)) continue;
    if (!seenVideos.add(item.videoId)) continue;
    final key = trackKey(item.artist, item.title);
    if (taste.knownTrackKeys.contains(key)) continue;
    if (!seenTracks.add(key)) continue;
    if (!judgeMusicCandidate(candidate).accepted) continue;
    scored.add(
      _ScoredCandidate(
        candidate: candidate,
        score: scoreMusicCandidate(candidate, taste),
        order: scored.length,
      ),
    );
  }

  scored.sort((a, b) {
    final byScore = b.score.compareTo(a.score);
    // Ties keep catalogue order, so the same pool always produces the same
    // feed and the strongest pool keeps its own ordering.
    return byScore != 0 ? byScore : a.order.compareTo(b.order);
  });

  final perArtist = <String, int>{};
  final result = <YouTubePlaylistItem>[];
  for (final entry in scored) {
    if (result.length >= limit) break;
    final artist = artistKey(entry.candidate.item.artist);
    final count = perArtist[artist] ?? 0;
    if (count >= maxPerArtist) continue;
    perArtist[artist] = count + 1;
    result.add(entry.candidate.item);
  }
  return List.unmodifiable(result);
}

/// Removes the upload decoration from a title: `(Official Video)`, `[4K]`,
/// `(Lyric Video)`, `Official Audio` and the like.
///
/// Only the technical markers are removed. `(Live at Wembley)` and `(Acoustic)`
/// say something about the recording, so they stay.
String cleanMusicTitle(String raw) {
  var value = raw.replaceAll('_', ' ').trim();
  final group = RegExp(_bracketGroup);
  value = value.replaceAllMapped(group, (match) {
    final body = (match.group(1) ?? match.group(2) ?? '').toLowerCase();
    final noise = RegExp(
      r'\b(official|oficial|videoclip|video|clip|audio|audio\s+only|lyrics?|'
      r'lyric\s+video|visuali[sz]er|hd|hq|4k|8k|mv|m/v|explicit|'
      r'music\s+video|remaster(ed)?|with\s+lyrics)\b',
    ).hasMatch(body);
    return noise ? '' : match.group(0)!;
  });
  value = value.replaceAll(
    RegExp(
        r'\s*[|/\-–]\s*(official\s+)?(music\s+)?(video|audio|lyric\s+video)\s*$',
        caseSensitive: false),
    '',
  );
  value = value.replaceAll(RegExp(r'\s{2,}'), ' ');
  value = value.replaceAll(RegExp(r'[\s\-|/]+$'), '');
  return value.trim();
}

/// `Artist - Song` split into its parts. A title like this is the most common
/// shape for an upload that carries no artist field.
({String artist, String title}) splitTitleAndArtist(
  YouTubePlaylistItem item,
) {
  final title = cleanMusicTitle(item.title);
  final artist = displayArtist(item.artist);
  final match = RegExp(r'^(.{2,60}?)\s+[-–]\s+(.+)$').firstMatch(title);
  if (match == null) return (artist: artist, title: title);

  final left = match.group(1)!.trim();
  final right = match.group(2)!.trim();
  if (left.isEmpty || right.isEmpty) return (artist: artist, title: title);

  // Only trust the split when the channel agrees with it, or when there is no
  // channel at all. `Song - Part 2` is a title, not artist and track.
  final leftKey = artistKey(left);
  final artistKeyOfChannel = artistKey(artist);
  final agrees = artistKeyOfChannel.isNotEmpty &&
      (artistKeyOfChannel == leftKey ||
          artistKeyOfChannel.contains(leftKey) ||
          leftKey.contains(artistKeyOfChannel));

  if (artistKeyOfChannel.isEmpty) return (artist: left, title: right);
  if (!agrees) return (artist: artist, title: title);
  return (artist: artist, title: right);
}

/// Normalizes one catalogue row for display and for dedupe.
YouTubePlaylistItem normalizeMusicTrack(YouTubePlaylistItem item) {
  final split = splitTitleAndArtist(item);
  return YouTubePlaylistItem(
    videoId: item.videoId,
    title: split.title,
    artist: split.artist,
    duration: item.duration,
    thumbnailUrl: item.thumbnailUrl,
    position: item.position,
    viewCountText: item.viewCountText,
  );
}

class _ScoredCandidate {
  final YouTubeFeedCandidate candidate;
  final double score;
  final int order;

  const _ScoredCandidate({
    required this.candidate,
    required this.score,
    required this.order,
  });
}

/// True when [text] looks like a clock (`3:52`). Exposed so callers can read a
/// duration out of a byline without duplicating the pattern.
bool isClockText(String text) => RegExp(_clockText).hasMatch(text.trim());
