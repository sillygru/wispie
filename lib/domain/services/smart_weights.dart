/// Two-stage smart shuffle weights.
///
/// An artist is picked first, from a bucket (recent, lapsed, discovery), then a
/// song is picked inside that artist. Every weight is a probability, so an
/// artist's share of the shuffle is set by its bucket and does not shrink as the
/// library grows. Summed over the pool, the weights are 1.
///
/// Pure: no I/O and no clock. Consumes [TasteSnapshot] from `taste_model.dart`.
library;

import 'dart:math';

import 'shuffle_selector.dart'
    show ShuffleContext, orderQueueWeighted, selectSeedWeighted;
import 'taste_model.dart';

const double _minWeight = 1e-12;
const double _defaultFamiliarity = 0.65;
const double _playlistBoost = 1.1;
const double _favoriteArtistMass = 0.5;
const double _coPlayArtistBoost = 0.5;
const double _coPlaySongBoost = 0.6;

/// A song, or a merge group of songs, that smart shuffle may choose.
///
/// [filenames] holds every member. Their taste is summed, so a merge group
/// competes as one song. [isFavorite], [isSuggestLess] and [isInPlaylist] are
/// true if any member carries the flag.
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

enum _Bucket { recent, lapsed, discovery }

/// Queue spacing in slots, derived from how many artists and albums carry the
/// probability mass.
typedef SmartSpacing = ({int artist, int album});

double _lerp(double a, double b, double f) => a + (b - a) * f;

double _familiarity(double f) =>
    f.isFinite ? f.clamp(0.0, 1.0).toDouble() : _defaultFamiliarity;

Map<String, _Bucket> _classifyArtists<T>(
  List<SmartCandidate<T>> pool,
  TasteSnapshot taste,
) {
  final favoritedArtists = <String>{
    for (final c in pool)
      if (c.isFavorite) c.artistKey,
  };
  return {
    for (final c in pool)
      c.artistKey: _bucketOf(
        c.artistKey,
        taste,
        favoritedArtists.contains(c.artistKey),
      ),
  };
}

_Bucket _bucketOf(String key, TasteSnapshot taste, bool favorited) {
  final artist = taste.artists[key];
  if ((artist?.trendMass ?? 0.0) > 0) return _Bucket.recent;
  if (favorited || (artist?.longMass ?? 0.0) > 0) return _Bucket.lapsed;
  return _Bucket.discovery;
}

/// Bucket shares over the non-empty buckets, summing to 1. The discovery floor
/// keeps unheard artists reachable at maximum familiarity.
Map<_Bucket, double> _bucketShares(double f, Set<_Bucket> present) {
  final raw = {
    _Bucket.recent: _lerp(0.60, 0.97, f),
    _Bucket.lapsed: _lerp(0.25, 0.03, f),
    _Bucket.discovery: max(_lerp(0.15, 0.0, f), 1e-4),
  };
  final total = present.fold(0.0, (sum, b) => sum + raw[b]!);
  return {for (final b in present) b: raw[b]! / total};
}

/// Probability of every candidate in [pool]. Keys are the candidates' items.
///
/// [context] only changes two things: anti-repeat is skipped for `sort`, and
/// radio adds co-play boosts from [currentFilename]. Bucket shares are the same
/// for every context, so scoped pools stay correct without special casing.
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
  if (pool.isEmpty) return {};

  final f = _familiarity(familiarity);
  final members = <String, List<int>>{};
  for (var i = 0; i < pool.length; i++) {
    (members[pool[i].artistKey] ??= []).add(i);
  }

  final buckets = _classifyArtists(pool, taste);
  final shares = _bucketShares(f, buckets.values.toSet());

  final g = _lerp(0.7, 1.5, f);
  final artistCoRow = currentArtist == null
      ? null
      : taste
          .artistCoPlay[tasteArtistKey(currentArtist, currentFilename ?? '')];
  final artistMass = <String, double>{};
  final bucketTotal = <_Bucket, double>{};
  final bucketCount = <_Bucket, int>{};

  for (final entry in members.entries) {
    final key = entry.key;
    final bucket = buckets[key]!;
    final artist = taste.artists[key];
    final favorites = entry.value.where((i) => pool[i].isFavorite).length;

    var mass = switch (bucket) {
      _Bucket.recent => pow(artist?.trendMass ?? 0.0, g).toDouble(),
      _Bucket.lapsed => pow(
          (artist?.longMass ?? 0.0) + _favoriteArtistMass * favorites,
          g,
        ).toDouble(),
      _Bucket.discovery => sqrt(entry.value.length.toDouble()),
    };
    if (artistCoRow != null) {
      mass *= 1 + _coPlayArtistBoost * (artistCoRow[key] ?? 0.0);
    }
    if (!mass.isFinite || mass < 0) mass = 0.0;

    artistMass[key] = mass;
    bucketTotal[bucket] = (bucketTotal[bucket] ?? 0.0) + mass;
    bucketCount[bucket] = (bucketCount[bucket] ?? 0) + 1;
  }

  final prior = _lerp(0.35, 0.08, f);
  final radioRow = context == ShuffleContext.radio && currentFilename != null
      ? taste.coPlay[currentFilename]
      : null;
  final antiRepeat = context != ShuffleContext.sort && historyLimit > 0;

  final out = <T, double>{};
  for (final entry in members.entries) {
    final key = entry.key;
    final bucket = buckets[key]!;
    final total = bucketTotal[bucket]!;
    final pArtist = total > 0 && artistMass[key]! > 0
        ? artistMass[key]! / total
        : 1.0 / bucketCount[bucket]!;

    final indices = entry.value;
    final signals = [for (final i in indices) _signalsOf(pool[i], taste)];
    var maxTrend = 0.0;
    var maxLong = 0.0;
    for (final s in signals) {
      maxTrend = max(maxTrend, s.trend);
      maxLong = max(maxLong, s.long);
    }

    final raw = <double>[];
    for (var k = 0; k < indices.length; k++) {
      final c = pool[indices[k]];
      final sig = signals[k];
      var s = (maxTrend > 0 ? 0.6 * sig.trend / maxTrend : 0.0) +
          (maxLong > 0 ? 0.4 * sig.long / maxLong : 0.0) +
          prior;
      s *= (1 - sig.skipRate * 0.3).clamp(0.2, 1.0).toDouble();
      s /= 1 + sig.saturation;

      if (antiRepeat) {
        final idx = _minHistory(c.filenames, historyIndex);
        if (idx != null) {
          final proximity = 1 - idx / historyLimit;
          s *= 1 - (0.85 * proximity).clamp(0.0, 0.98).toDouble();
        }
      }
      if (c.isFavorite) s *= favoriteMultiplier;
      if (c.isSuggestLess) s *= suggestLessMultiplier;
      if (c.isInPlaylist) s *= _playlistBoost;
      if (radioRow != null) {
        var co = 0.0;
        for (final name in c.filenames) {
          co = max(co, radioRow[name] ?? 0.0);
        }
        s *= 1 + _coPlaySongBoost * co;
      }
      raw.add(s.isFinite && s > 0 ? s : 0.0);
    }

    final sum = raw.fold(0.0, (a, b) => a + b);
    for (var k = 0; k < indices.length; k++) {
      final pSong = sum > 0 ? raw[k] / sum : 1.0 / indices.length;
      final w = shares[bucket]! * pArtist * pSong;
      out[pool[indices[k]].item] =
          w.isFinite && w > _minWeight ? w : _minWeight;
    }
  }
  return out;
}

class _Signals {
  double trend = 0.0;
  double long = 0.0;
  double saturation = 0.0;
  double skipRate = 0.0;
}

/// Sums member taste into one candidate. Skip rate is weighted by play count
/// so a rarely played version does not drag the group.
_Signals _signalsOf<T>(SmartCandidate<T> c, TasteSnapshot taste) {
  final out = _Signals();
  var plays = 0;
  var skipWeighted = 0.0;
  for (final f in c.filenames) {
    final song = taste.songs[f];
    if (song == null) continue;
    out.trend += song.trendMass;
    out.long += song.longMass;
    out.saturation += song.saturation;
    plays += song.playCount;
    skipWeighted += song.skipRate * song.playCount;
  }
  if (plays > 0) out.skipRate = skipWeighted / plays;
  return out;
}

int? _minHistory(List<String> filenames, Map<String, int> historyIndex) {
  int? best;
  for (final f in filenames) {
    final idx = historyIndex[f];
    if (idx != null && (best == null || idx < best)) best = idx;
  }
  return best;
}

/// Adaptive queue spacing from the effective number of artists and albums in
/// the recent and lapsed mass. One dominant artist gives 0, so a single-artist
/// shuffle is not forced to interleave other artists.
SmartSpacing smartSpacing<T>({
  required Map<T, double> weights,
  required List<SmartCandidate<T>> pool,
  required TasteSnapshot taste,
  required bool streakBreakerEnabled,
}) {
  if (!streakBreakerEnabled || pool.isEmpty) return (artist: 0, album: 0);

  final buckets = _classifyArtists(pool, taste);
  final artistMass = <String, double>{};
  final albumMass = <String, double>{};
  for (final c in pool) {
    if (buckets[c.artistKey] == _Bucket.discovery) continue;
    final w = weights[c.item] ?? 0.0;
    artistMass[c.artistKey] = (artistMass[c.artistKey] ?? 0.0) + w;
    albumMass[c.albumKey] = (albumMass[c.albumKey] ?? 0.0) + w;
  }

  final nArtists = _effectiveCount(artistMass.values);
  final nAlbums = _effectiveCount(albumMass.values);
  return (
    artist: max(0, min(5, nArtists - 1)),
    album: max(0, min(4, nAlbums - 1)),
  );
}

/// exp(entropy) of the distribution, floored. Zero when there is no mass.
int _effectiveCount(Iterable<double> masses) {
  final total = masses.fold(0.0, (a, b) => a + b);
  if (total <= 0) return 0;
  var entropy = 0.0;
  for (final m in masses) {
    if (m <= 0) continue;
    final p = m / total;
    entropy -= p * log(p);
  }
  return exp(entropy).floor();
}

/// Top [count] candidates by weight, with no artist holding more than
/// `max(2, ceil(N * P(artist)) + 1)` of them. Overflow fills the remaining
/// slots in rank order, so the list is always full when the pool allows it.
List<T> diversifiedTop<T>(
  List<SmartCandidate<T>> pool,
  Map<T, double> weights, {
  required int count,
}) {
  if (count <= 0 || pool.isEmpty) return [];
  final n = min(count, pool.length);

  final ranked = List<SmartCandidate<T>>.of(pool)
    ..sort(
        (a, b) => (weights[b.item] ?? 0.0).compareTo(weights[a.item] ?? 0.0));

  final artistMass = <String, double>{};
  var total = 0.0;
  for (final c in pool) {
    final w = weights[c.item] ?? 0.0;
    artistMass[c.artistKey] = (artistMass[c.artistKey] ?? 0.0) + w;
    total += w;
  }

  final taken = <String, int>{};
  final out = <T>[];
  final overflow = <T>[];
  for (final c in ranked) {
    if (out.length == n) break;
    final share = total > 0 ? artistMass[c.artistKey]! / total : 0.0;
    final cap = max(2, (n * share).ceil() + 1);
    if ((taken[c.artistKey] ?? 0) < cap) {
      out.add(c.item);
      taken[c.artistKey] = (taken[c.artistKey] ?? 0) + 1;
    } else {
      overflow.add(c.item);
    }
  }
  for (final item in overflow) {
    if (out.length == n) break;
    out.add(item);
  }
  return out;
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
