/// Two-stage smart shuffle weights.
///
/// An artist is picked first, from a bucket (recent, lapsed, discovery), then a
/// song is picked inside that artist. Every weight is a probability, so an
/// artist's share of the shuffle is set by its bucket and does not shrink as the
/// library grows. Summed over the pool, the weights are 1.
///
/// Rust-backed, with no clock reads. Consumes [TasteSnapshot] from `taste_model.dart`.
library;

import 'dart:math';

import 'native_accel.dart';
import 'shuffle_selector.dart'
    show ShuffleContext, orderQueueWeighted, selectSeedWeighted;
import 'taste_model.dart';

const double _minWeight = 1e-12;

/// A song, or a merge group of songs, that smart shuffle may choose.
///
/// The first of [filenames] is the version being scored; the rest only let
/// queue anti-repeat treat the group as one track. Merging never shares
/// favourites, play counts or playlist membership between versions.
class SmartCandidate<T> {
  final T item;
  final List<String> filenames;
  final String artistKey;
  final String albumKey;
  final bool isFavorite;
  final bool isSuggestLess;
  final bool isInPlaylist;

  const SmartCandidate({
    required this.item,
    required this.filenames,
    required this.artistKey,
    required this.albumKey,
    this.isFavorite = false,
    this.isSuggestLess = false,
    this.isInPlaylist = false,
  });
}

/// Queue spacing in slots, derived from how many artists and albums carry the
/// probability mass.
typedef SmartSpacing = ({int artist, int album});

/// Probability of every candidate in [pool]. Keys are the candidates' items.
///
/// [context] only changes one thing: anti-repeat is skipped for `sort`. Bucket
/// shares are the same for every context, so scoped pools stay correct without
/// special casing.
Map<T, double> computeSmartWeights<T>({
  required List<SmartCandidate<T>> pool,
  required TasteSnapshot taste,
  required double familiarity,
  required ShuffleContext context,
  String? currentArtist,
  String? currentFilename,
  Map<String, int> historyIndex = const {},
  int historyLimit = 0,
  double favoriteMultiplier = 1.0,
  double suggestLessMultiplier = 1.0,
}) {
  final rows = _poolNative(pool);
  final values = NativeAccel.smartWeights(
    pool: rows,
    taste: _tasteNative(taste),
    familiarity: familiarity,
    context: context.name,
    currentArtistKey: currentArtist == null
        ? ''
        : tasteArtistKey(currentArtist, currentFilename ?? ''),
    historyIndex: historyIndex,
    historyLimit: historyLimit,
    favoriteMultiplier: favoriteMultiplier,
    suggestLessMultiplier: suggestLessMultiplier,
  );
  return {for (var i = 0; i < pool.length; i++) pool[i].item: values[i]};
}

List<Map<String, Object?>> _poolNative<T>(List<SmartCandidate<T>> pool) => [
      for (final candidate in pool)
        {
          'filenames': candidate.filenames,
          'artistKey': candidate.artistKey,
          'albumKey': candidate.albumKey,
          'isFavorite': candidate.isFavorite,
          'isSuggestLess': candidate.isSuggestLess,
          'isInPlaylist': candidate.isInPlaylist,
        },
    ];

Map<String, Object?> _tasteNative(TasteSnapshot taste) => {
      'songs': {
        for (final entry in taste.songs.entries)
          entry.key: {
            'trendMass': entry.value.trendMass,
            'longMass': entry.value.longMass,
            'saturation': entry.value.saturation,
            'skipRate': entry.value.skipRate,
          },
      },
      'artists': {
        for (final entry in taste.artists.entries)
          entry.key: {
            'trendMass': entry.value.trendMass,
            'longMass': entry.value.longMass,
          },
      },
      'artistCoPlay': taste.artistCoPlay,
      'newness': taste.newness,
    };

/// Adaptive queue spacing from the effective number of artists and albums in
/// the recent and lapsed mass. One dominant artist gives 0, so a single-artist
/// shuffle is not forced to interleave other artists.
SmartSpacing smartSpacing<T>({
  required Map<T, double> weights,
  required List<SmartCandidate<T>> pool,
  required TasteSnapshot taste,
  required bool streakBreakerEnabled,
}) {
  final values = NativeAccel.smartSpacing(
    pool: _poolNative(pool),
    weights: [for (final candidate in pool) weights[candidate.item] ?? 0.0],
    taste: _tasteNative(taste),
    streakBreakerEnabled: streakBreakerEnabled,
  );
  return (artist: values['artist']!, album: values['album']!);
}

/// Top [count] candidates by weight, with no artist holding more than
/// `max(2, ceil(N * P(artist)) + 1)` of them. Overflow fills the remaining
/// slots in rank order, so the list is always full when the pool allows it.
List<T> diversifiedTop<T>(
  List<SmartCandidate<T>> pool,
  Map<T, double> weights, {
  required int count,
}) {
  final indices = NativeAccel.diversifiedTop(
    pool: _poolNative(pool),
    weights: [for (final candidate in pool) weights[candidate.item] ?? 0.0],
    count: count,
  );
  return [for (final index in indices) pool[index].item];
}

/// Smart play order over [pool]: two-stage weights, adaptive spacing, then the
/// weighted race. Returns the pool items in play order.
List<T> orderSmartQueue<T>({
  required List<SmartCandidate<T>> pool,
  required TasteSnapshot taste,
  required double familiarity,
  required ShuffleContext context,
  required bool streakBreakerEnabled,
  String? currentArtist,
  String? currentFilename,
  Map<String, int> historyIndex = const {},
  int historyLimit = 0,
  double favoriteMultiplier = 1.0,
  double suggestLessMultiplier = 1.0,
  String? lastArtist,
  String? lastAlbum,
  Random? random,
}) {
  if (pool.length <= 1) return [for (final c in pool) c.item];
  final weights = computeSmartWeights<T>(
    pool: pool,
    taste: taste,
    familiarity: familiarity,
    context: context,
    currentArtist: currentArtist,
    currentFilename: currentFilename,
    historyIndex: historyIndex,
    historyLimit: historyLimit,
    favoriteMultiplier: favoriteMultiplier,
    suggestLessMultiplier: suggestLessMultiplier,
  );
  final spacing = smartSpacing<T>(
    weights: weights,
    pool: pool,
    taste: taste,
    streakBreakerEnabled: streakBreakerEnabled,
  );
  final order = orderQueueWeighted<int>(
    [for (var i = 0; i < pool.length; i++) i],
    [for (final c in pool) weights[c.item] ?? _minWeight],
    artistSpacing: spacing.artist,
    albumSpacing: spacing.album,
    artistOf: (i) => pool[i].artistKey,
    albumOf: (i) => pool[i].albumKey,
    random: random,
    lastArtist: lastArtist,
    lastAlbum: lastAlbum,
  );
  return [for (final i in order) pool[i].item];
}

/// Draws the opening song of a smart shuffle from the same two-stage weights.
T? selectSmartSeed<T>({
  required List<SmartCandidate<T>> pool,
  required TasteSnapshot taste,
  required double familiarity,
  required ShuffleContext context,
  String? currentArtist,
  String? currentFilename,
  Map<String, int> historyIndex = const {},
  int historyLimit = 0,
  double favoriteMultiplier = 1.0,
  double suggestLessMultiplier = 1.0,
  Random? random,
}) {
  if (pool.isEmpty) return null;
  final weights = computeSmartWeights<T>(
    pool: pool,
    taste: taste,
    familiarity: familiarity,
    context: context,
    currentArtist: currentArtist,
    currentFilename: currentFilename,
    historyIndex: historyIndex,
    historyLimit: historyLimit,
    favoriteMultiplier: favoriteMultiplier,
    suggestLessMultiplier: suggestLessMultiplier,
  );
  return selectSeedWeighted<T>(
    [for (final c in pool) c.item],
    [for (final c in pool) weights[c.item] ?? _minWeight],
    random: random,
  );
}
