/// Picks and orders songs for shuffle from the taste scores produced by
/// `song_affinity.dart`.
///
/// Selecting and ordering are the same maths: the song that plays first is
/// drawn from the same distribution as the rest of the queue.
///
/// Rust-backed; the only randomness is supplied by the injected [Random].
library;

import 'dart:math';

import 'native_accel.dart';
import '../../models/shuffle_config.dart';
import 'song_affinity.dart';

/// A song (or a merged group of songs, from the caller's perspective) that
/// shuffle may choose. Generic over [T] so the caller keeps its own payload
/// type — `AudioPlayerManager` passes its merge-group wrapper through.
class ShuffleCandidate<T> {
  final T payload;
  final String artist;
  final String album;
  final SongAffinity affinity;
  final bool isFavorite;
  final bool isSuggestLess;
  final bool isInPlaylist;

  /// Position in recent play history — 0 is the most recently played song.
  /// Null when the song isn't in the history window at all.
  final int? historyIndex;

  const ShuffleCandidate({
    required this.payload,
    required this.artist,
    required this.album,
    required this.affinity,
    this.isFavorite = false,
    this.isSuggestLess = false,
    this.isInPlaylist = false,
    this.historyIndex,
  });
}

/// Where a shuffle was requested from. Smart weights use it to decide how much
/// to trust recent taste and context.
enum ShuffleContext { library, scoped, sort }

/// Resolved knobs the scoring maths reads.
class ShuffleWeights {
  /// Exponent applied to affinity. Above 1 sharpens toward favourites, below 1
  /// flattens the field toward uniform.
  final double affinityExponent;

  /// Additive lift for songs with little or no history. Additive rather than
  /// multiplicative so unheard songs stay reachable even at high
  /// [affinityExponent], where their multiplicative score rounds to nothing.
  final double noveltyBoost;

  /// How hard to push down songs played recently, 0..1.
  final double repeatAversion;

  /// How hard to push down songs the listener habitually abandons, 0..1.
  final double skipAversion;

  /// How hard short-term over-exposure damps a song, 0..1+.
  final double burnoutDamping;

  /// Preferred minimum gap, in queue slots, between songs sharing an artist.
  final int artistSpacing;

  /// Preferred minimum gap, in queue slots, between songs sharing an album.
  final int albumSpacing;

  final double favoriteBoost;
  final double suggestLessPenalty;
  final double playlistBoost;

  /// Number of recent-history slots anti-repeat spans.
  final int historyLimit;

  const ShuffleWeights({
    required this.affinityExponent,
    required this.noveltyBoost,
    required this.repeatAversion,
    required this.skipAversion,
    required this.burnoutDamping,
    required this.artistSpacing,
    required this.albumSpacing,
    required this.favoriteBoost,
    required this.suggestLessPenalty,
    required this.playlistBoost,
    required this.historyLimit,
  });

  /// Weights used when no taste snapshot is ready yet, so a shuffle can still
  /// start and still respect every user-facing setting.
  factory ShuffleWeights.fallback(ShuffleConfig config) {
    final weights = NativeAccel.shuffleFallbackWeights(
      antiRepeatEnabled: config.antiRepeatEnabled,
      streakBreakerEnabled: config.streakBreakerEnabled,
      favoriteMultiplier: config.favoriteMultiplier,
      suggestLessMultiplier: config.suggestLessMultiplier,
      historyLimit: config.historyLimit,
    );
    return ShuffleWeights(
      affinityExponent: (weights['affinityExponent'] as num).toDouble(),
      noveltyBoost: (weights['noveltyBoost'] as num).toDouble(),
      repeatAversion: (weights['repeatAversion'] as num).toDouble(),
      skipAversion: (weights['skipAversion'] as num).toDouble(),
      burnoutDamping: (weights['burnoutDamping'] as num).toDouble(),
      artistSpacing: (weights['artistSpacing'] as num).toInt(),
      albumSpacing: (weights['albumSpacing'] as num).toInt(),
      favoriteBoost: (weights['favoriteBoost'] as num).toDouble(),
      suggestLessPenalty: (weights['suggestLessPenalty'] as num).toDouble(),
      playlistBoost: (weights['playlistBoost'] as num).toDouble(),
      historyLimit: (weights['historyLimit'] as num).toInt(),
    );
  }

  Map<String, Object?> toNative() => {
        'affinityExponent': affinityExponent,
        'noveltyBoost': noveltyBoost,
        'repeatAversion': repeatAversion,
        'skipAversion': skipAversion,
        'burnoutDamping': burnoutDamping,
        'historyLimit': historyLimit,
        'favoriteBoost': favoriteBoost,
        'suggestLessPenalty': suggestLessPenalty,
        'playlistBoost': playlistBoost,
      };
}

/// Weight of a single candidate under [weights]. Deterministic.
double scoreCandidate<T>(
    ShuffleCandidate<T> candidate, ShuffleWeights weights) {
  return NativeAccel.shuffleScores(
    candidates: [_candidateNative(candidate)],
    weights: weights.toNative(),
  ).single;
}

/// Scores every candidate once.
List<double> scoreCandidates<T>(
  List<ShuffleCandidate<T>> candidates,
  ShuffleWeights weights,
) =>
    NativeAccel.shuffleScores(
      candidates: [
        for (final candidate in candidates) _candidateNative(candidate)
      ],
      weights: weights.toNative(),
    );

Map<String, Object?> _candidateNative<T>(ShuffleCandidate<T> candidate) => {
      'affinity': candidate.affinity.affinity,
      'playCount': candidate.affinity.playCount,
      'skipRate': candidate.affinity.skipRate,
      'recentSaturation': candidate.affinity.recentSaturation,
      'historyIndex': candidate.historyIndex,
      'isFavorite': candidate.isFavorite,
      'isSuggestLess': candidate.isSuggestLess,
      'isInPlaylist': candidate.isInPlaylist,
    };

/// Draws one candidate proportional to its score.
ShuffleCandidate<T>? selectSeed<T>(
  List<ShuffleCandidate<T>> candidates,
  ShuffleWeights weights, {
  Random? random,
}) {
  if (candidates.isEmpty) return null;
  final rng = random ?? Random();
  final scores = scoreCandidates(candidates, weights);
  final index =
      NativeAccel.shuffleSelect(scores: scores, draw: rng.nextDouble())!;
  return candidates[index];
}

/// Orders every candidate into a full queue.
///
/// Two stages:
///
/// 1. A weighted permutation via the exponential race (Efraimidis–Spirakis):
///    drawing `-ln(U)/w` per candidate and sorting ascending is equivalent to
///    repeated weighted sampling without replacement, but runs in O(n log n)
///    instead of the O(n²) rescan the previous implementation did.
/// 2. A spacing repair pass that pulls apart runs of the same artist or album.
///    Looking back over a window is what actually spreads a discography out;
///    comparing only against the immediately previous track — as the old
///    streak breaker did — still permits A B A B A.
///
/// [lastArtist] / [lastAlbum] seed the look-back with the currently playing
/// song so the join between it and the new queue is spaced too.
List<ShuffleCandidate<T>> orderQueue<T>(
  List<ShuffleCandidate<T>> candidates,
  ShuffleWeights weights, {
  Random? random,
  String? lastArtist,
  String? lastAlbum,
}) {
  if (candidates.length <= 1) return List.of(candidates);
  return _orderByScores(
    candidates,
    scoreCandidates(candidates, weights),
    artistSpacing: weights.artistSpacing,
    albumSpacing: weights.albumSpacing,
    artistOf: (c) => c.artist,
    albumOf: (c) => c.album,
    random: random,
    lastArtist: lastArtist,
    lastAlbum: lastAlbum,
  );
}

/// [orderQueue] for weights that are already probabilities (smart shuffle).
/// Spacing is passed explicitly because it is derived from the weights, not
/// from [ShuffleWeights].
List<T> orderQueueWeighted<T>(
  List<T> items,
  List<double> weights, {
  required int artistSpacing,
  required int albumSpacing,
  required String Function(T) artistOf,
  required String Function(T) albumOf,
  Random? random,
  String? lastArtist,
  String? lastAlbum,
}) {
  if (items.length <= 1) return List.of(items);
  return _orderByScores(
    items,
    weights,
    artistSpacing: artistSpacing,
    albumSpacing: albumSpacing,
    artistOf: artistOf,
    albumOf: albumOf,
    random: random,
    lastArtist: lastArtist,
    lastAlbum: lastAlbum,
  );
}

List<T> _orderByScores<T>(
  List<T> items,
  List<double> scores, {
  required int artistSpacing,
  required int albumSpacing,
  required String Function(T) artistOf,
  required String Function(T) albumOf,
  Random? random,
  String? lastArtist,
  String? lastAlbum,
}) {
  final rng = random ?? Random();

  final order = NativeAccel.shuffleOrder(
    items: [
      for (var i = 0; i < items.length; i++)
        {
          'score': scores[i],
          'artist': artistOf(items[i]),
          'album': albumOf(items[i]),
        },
    ],
    draws: [for (var i = 0; i < items.length; i++) rng.nextDouble()],
    artistSpacing: artistSpacing,
    albumSpacing: albumSpacing,
    lastArtist: lastArtist,
    lastAlbum: lastAlbum,
  );
  return [for (final index in order) items[index]];
}

/// Draws one item proportional to [weights]. Smart shuffle's seed picker.
T? selectSeedWeighted<T>(
  List<T> items,
  List<double> weights, {
  Random? random,
}) {
  if (items.isEmpty) return null;
  final total = weights.fold(0.0, (a, b) => a + b);
  final rng = random ?? Random();
  final index = NativeAccel.shuffleSelect(
    scores: weights,
    draw: total > 0 ? rng.nextDouble() : null,
    fallbackIndex: total <= 0 ? rng.nextInt(items.length) : null,
  )!;
  return items[index];
}
