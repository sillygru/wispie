/// Turns raw play events into a per-song taste score.
///
/// This is the "what does the listener actually like" half of shuffle; picking
/// and ordering songs from those scores lives in `shuffle_selector.dart`.
///
/// The model is deliberately evidence-based rather than count-based. A play
/// event is not a vote of equal weight: finishing a song is strong positive
/// evidence, abandoning it ten seconds in is *negative* evidence, and evidence
/// from a year ago says less about today's taste than evidence from last week.
/// Raw lifetime play counts collapse all three distinctions.
///
/// Pure by design — no I/O, no clock reads beyond the injected [now] — so the
/// whole model is directly testable.
library;

import 'dart:math';
import 'dart:typed_data';

import 'native_accel.dart';

/// One play event, as stored in the `playevent` table.
class PlayEventRecord {
  /// Primary key for all user data (see CLAUDE.md).
  final String filename;

  /// Epoch seconds, matching the `playevent.timestamp` column.
  final double timestamp;

  /// Fraction of the song actually heard, 0..1.
  final double playRatio;

  const PlayEventRecord({
    required this.filename,
    required this.timestamp,
    required this.playRatio,
  });
}

/// Per-song output of [computeAffinities].
class SongAffinity {
  /// Normalized taste score, 0..1. Comparable across the library.
  final double affinity;

  /// Short-term over-exposure, 0..1+. High when a song has been played a lot
  /// in the last few days. Used to damp today's obsession, never to bury it.
  final double recentSaturation;

  /// Recency-weighted average fraction of the song heard, 0..1.
  final double completionRate;

  /// Recency-weighted fraction of plays abandoned early, 0..1.
  final double skipRate;

  /// Number of events considered (all of them, undecayed).
  final int playCount;

  /// Epoch seconds of the most recent event, or null if never played.
  final double? lastPlayedAt;

  const SongAffinity({
    required this.affinity,
    required this.recentSaturation,
    required this.completionRate,
    required this.skipRate,
    required this.playCount,
    required this.lastPlayedAt,
  });

  /// A song with no listening history at all.
  static const unknown = SongAffinity(
    affinity: 0.0,
    recentSaturation: 0.0,
    completionRate: 0.0,
    skipRate: 0.0,
    playCount: 0,
    lastPlayedAt: null,
  );

  bool get hasHistory => playCount > 0;
}

/// Tunables for [computeAffinities]. Defaults are the shipping values; tests
/// override them to isolate one behaviour at a time.
class AffinityParams {
  /// Days for a play's contribution to lose half its weight.
  final double halfLifeDays;

  /// Days for the short-term saturation signal to halve. Much shorter than
  /// [halfLifeDays] — this tracks "on repeat this week", not taste.
  final double saturationHalfLifeDays;

  /// Decayed play count treated as "saturated". At this level a song's score is
  /// halved by [SongAffinity.recentSaturation] damping downstream.
  final double saturationTarget;

  /// At or above this ratio a play counts as a full, deliberate listen.
  final double fullListenRatio;

  /// Below this ratio a play counts as an outright skip (negative evidence).
  final double skipRatio;

  /// Ratio under which a play carries no positive credit at all.
  final double partialRatio;

  /// Evidence value of a completed listen.
  final double fullListenCredit;

  /// Evidence value (negative) of an immediate skip.
  final double skipPenalty;

  /// Evidence value (negative) of a brief but not-immediate abandon.
  final double partialPenalty;

  /// Percentile of the raw score distribution mapped to affinity 1.0. Using a
  /// high percentile rather than the maximum keeps one runaway song from
  /// flattening everything else into near-zero.
  final double normalizationPercentile;

  /// Affinity floor for songs the user explicitly favorited. Expresses intent
  /// directly, so a favorite ranks even with no play history behind it.
  final double favoriteFloor;

  const AffinityParams({
    this.halfLifeDays = 90.0,
    this.saturationHalfLifeDays = 2.0,
    this.saturationTarget = 6.0,
    this.fullListenRatio = 0.85,
    this.skipRatio = 0.10,
    this.partialRatio = 0.25,
    this.fullListenCredit = 1.0,
    this.skipPenalty = -0.6,
    this.partialPenalty = -0.2,
    this.normalizationPercentile = 0.95,
    this.favoriteFloor = 0.6,
  });
}

/// Exponential decay factor used by the taste model.
double decayFactor(double ageDays, double halfLifeDays) {
  if (halfLifeDays <= 0 || ageDays <= 0) return 1.0;
  return pow(0.5, ageDays / halfLifeDays).toDouble();
}

/// Computes the affinity map in the native core.
Map<String, SongAffinity> computeAffinities({
  required List<PlayEventRecord> events,
  required DateTime now,
  Set<String> favorites = const {},
  AffinityParams params = const AffinityParams(),
}) {
  final indices = <String, int>{};
  final filenames = <String>[];
  int indexFor(String filename) => indices.putIfAbsent(filename, () {
        filenames.add(filename);
        return filenames.length - 1;
      });
  for (final event in events) {
    indexFor(event.filename);
  }
  for (final favorite in favorites) {
    indexFor(favorite);
  }

  final bytes = Uint8List(events.length * 20);
  final data = ByteData.sublistView(bytes);
  for (var i = 0; i < events.length; i++) {
    final event = events[i];
    final offset = i * 20;
    data.setUint32(offset, indexFor(event.filename), Endian.little);
    data.setFloat64(offset + 4, event.timestamp, Endian.little);
    data.setFloat64(offset + 12, event.playRatio, Endian.little);
  }

  final decoded = NativeAccel.affinity(
    filenames: filenames,
    favorites: favorites.toList(growable: false),
    nowSeconds: now.millisecondsSinceEpoch / 1000.0,
    events: bytes,
    params: {
      'halfLifeDays': params.halfLifeDays,
      'saturationHalfLifeDays': params.saturationHalfLifeDays,
      'saturationTarget': params.saturationTarget,
      'fullListenRatio': params.fullListenRatio,
      'skipRatio': params.skipRatio,
      'partialRatio': params.partialRatio,
      'fullListenCredit': params.fullListenCredit,
      'skipPenalty': params.skipPenalty,
      'partialPenalty': params.partialPenalty,
      'normalizationPercentile': params.normalizationPercentile,
      'favoriteFloor': params.favoriteFloor,
    },
  );
  return {
    for (final row in decoded['rows'] as List<dynamic>)
      (row as Map<String, dynamic>)['filename'] as String: SongAffinity(
        affinity: (row['affinity'] as num).toDouble(),
        recentSaturation: (row['recentSaturation'] as num).toDouble(),
        completionRate: (row['completionRate'] as num).toDouble(),
        skipRate: (row['skipRate'] as num).toDouble(),
        playCount: (row['playCount'] as num).toInt(),
        lastPlayedAt: (row['lastPlayedAt'] as num?)?.toDouble(),
      ),
  };
}
