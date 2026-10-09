import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/services/shuffle_selector.dart';
import 'package:wispie/domain/services/smart_weights.dart';
import 'package:wispie/domain/services/taste_model.dart';

TasteSnapshot _taste({
  Map<String, ArtistTaste> artists = const {},
  Map<String, Map<String, double>> artistCoPlay = const {},
  Map<String, Map<String, double>> coPlay = const {},
}) =>
    TasteSnapshot(
      songs: const {},
      artists: artists,
      coPlay: coPlay,
      artistCoPlay: artistCoPlay,
    );

/// Builds one candidate per song. [artists] maps artist key to song count.
List<SmartCandidate<String>> _pool(Map<String, int> artists) => [
      for (final entry in artists.entries)
        for (var i = 0; i < entry.value; i++)
          SmartCandidate<String>(
            item: '${entry.key}#$i',
            filenames: ['${entry.key}#$i'],
            artistKey: entry.key,
            albumKey: '${entry.key}/album${i % 3}',
          ),
    ];

Map<String, double> _artistTotals(
  Map<String, double> weights,
  List<SmartCandidate<String>> pool,
) {
  final out = <String, double>{};
  for (final c in pool) {
    out[c.artistKey] = (out[c.artistKey] ?? 0.0) + (weights[c.item] ?? 0.0);
  }
  return out;
}

double _sum(Iterable<double> xs) => xs.fold(0.0, (a, b) => a + b);

Map<String, double> _weights(
  List<SmartCandidate<String>> pool,
  TasteSnapshot taste, {
  double familiarity = 0.65,
  ShuffleContext context = ShuffleContext.library,
}) =>
    computeSmartWeights<String>(
      pool: pool,
      taste: taste,
      familiarity: familiarity,
      context: context,
    );

void main() {
  final recentA = _taste(artists: {
    'a': const ArtistTaste(trendMass: 8, longMass: 9),
  });

  group('computeSmartWeights invariants', () {
    test('weights are positive, finite and sum to 1', () {
      final pool = _pool({'a': 20, 'b': 10, 'c': 5, 'd': 3});
      final taste = _taste(artists: {
        'a': const ArtistTaste(trendMass: 8, longMass: 9),
        'b': const ArtistTaste(trendMass: 0, longMass: 2),
      });
      final w = _weights(pool, taste);
      expect(w.length, pool.length);
      for (final v in w.values) {
        expect(v.isFinite && v > 0, isTrue);
      }
      expect(_sum(w.values), closeTo(1.0, 1e-6));
    });

    test('degenerate pools stay valid', () {
      expect(_weights([], recentA), isEmpty);

      final one = _pool({'a': 1});
      expect(_weights(one, recentA)['a#0'], closeTo(1.0, 1e-6));

      final untagged = [
        for (var i = 0; i < 4; i++)
          SmartCandidate<String>(
            item: 'u$i',
            filenames: ['u$i'],
            artistKey: tasteArtistKey('', 'u$i'),
            albumKey: tasteArtistKey('', 'u$i'),
          ),
      ];
      expect(_sum(_weights(untagged, recentA).values), closeTo(1.0, 1e-6));

      final oneArtist = _pool({'a': 12});
      expect(_sum(_weights(oneArtist, recentA).values), closeTo(1.0, 1e-6));
      expect(_sum(_weights(oneArtist, _taste()).values), closeTo(1.0, 1e-6));

      final noEvents = _pool({'a': 5, 'b': 5});
      expect(_sum(_weights(noEvents, _taste()).values), closeTo(1.0, 1e-6));
    });

    test('no events gives equal shares to equal-sized artists', () {
      final pool = _pool({'a': 10, 'b': 10, 'c': 10});
      final totals = _artistTotals(_weights(pool, _taste()), pool);
      expect(totals['a'], closeTo(totals['b']!, 1e-9));
      expect(totals['b'], closeTo(totals['c']!, 1e-9));
    });

    test('familiarity 1 gives the recent artist strictly more share', () {
      final pool = _pool({'a': 10, 'b': 10, 'c': 10});
      final taste = _taste(artists: {
        'a': const ArtistTaste(trendMass: 5, longMass: 5),
      });
      final high = _artistTotals(
        _weights(pool, taste, familiarity: 1.0),
        pool,
      )['a']!;
      final low = _artistTotals(
        _weights(pool, taste, familiarity: 0.0),
        pool,
      )['a']!;
      expect(high, greaterThan(low));
    });

    test('recent bucket total is invariant to extra discovery artists', () {
      final taste = _taste(artists: {
        'a': const ArtistTaste(trendMass: 5, longMass: 5),
      });
      final small = _pool({'a': 10, 'x': 5});
      final large = _pool({'a': 10, 'x': 5, 'y': 5, 'z': 5, 'q': 5});
      final recentSmall = _artistTotals(
        _weights(small, taste, familiarity: 0.8),
        small,
      )['a']!;
      final recentLarge = _artistTotals(
        _weights(large, taste, familiarity: 0.8),
        large,
      )['a']!;
      expect(recentLarge, closeTo(recentSmall, 1e-9));
    });

    test('context sort skips anti-repeat', () {
      final pool = _pool({'a': 4});
      final history = {'a#0': 0};
      final library = computeSmartWeights<String>(
        pool: pool,
        taste: recentA,
        familiarity: 1.0,
        context: ShuffleContext.library,
        historyIndex: history,
        historyLimit: 10,
      );
      final sort = computeSmartWeights<String>(
        pool: pool,
        taste: recentA,
        familiarity: 1.0,
        context: ShuffleContext.sort,
        historyIndex: history,
        historyLimit: 10,
      );
      expect(library['a#0']!, lessThan(sort['a#0']!));
    });
  });

  group('adaptive spacing', () {
    test('one recent artist gives artist spacing 0', () {
      final pool = _pool({'a': 30, 'b': 30});
      final taste = _taste(artists: {
        'a': const ArtistTaste(trendMass: 8, longMass: 9),
      });
      final w = _weights(pool, taste, familiarity: 1.0);
      final spacing = smartSpacing<String>(
        weights: w,
        pool: pool,
        taste: taste,
        streakBreakerEnabled: true,
      );
      expect(spacing.artist, 0);
    });

    test('streak breaker off forces zero spacing', () {
      final pool = _pool({'a': 10, 'b': 10, 'c': 10, 'd': 10});
      final taste = _taste(artists: {
        for (final k in ['a', 'b', 'c', 'd'])
          k: const ArtistTaste(trendMass: 5, longMass: 5),
      });
      final w = _weights(pool, taste);
      final spacing = smartSpacing<String>(
        weights: w,
        pool: pool,
        taste: taste,
        streakBreakerEnabled: false,
      );
      expect(spacing.artist, 0);
      expect(spacing.album, 0);
    });
  });

  group('ordering and top-N', () {
    test('orderQueueWeighted is a permutation', () {
      final pool = _pool({'a': 15, 'b': 15, 'c': 10});
      final items = [for (final c in pool) c.item];
      final w = _weights(pool, recentA);
      final weights = [for (final i in items) w[i]!];
      final ordered = orderQueueWeighted<String>(
        items,
        weights,
        artistSpacing: 3,
        albumSpacing: 2,
        artistOf: (s) => s.split('#').first,
        albumOf: (s) => s.split('#').first,
        random: Random(7),
      );
      expect(ordered.length, items.length);
      expect(ordered.toSet(), items.toSet());
    });

    test('selectSeedWeighted returns null only for an empty list', () {
      expect(selectSeedWeighted<String>([], const []), isNull);
      expect(
        selectSeedWeighted<String>(['x'], const [1.0], random: Random(1)),
        'x',
      );
    });

    test('diversifiedTop respects per-artist caps and fills to count', () {
      final pool = _pool({'a': 30, 'b': 10, 'c': 10});
      final w = _weights(
          pool,
          _taste(artists: {
            'a': const ArtistTaste(trendMass: 8, longMass: 9),
          }));
      final top = diversifiedTop<String>(pool, w, count: 30);
      expect(top.length, 30);
      final aCount = top.where((s) => s.startsWith('a#')).length;
      expect(aCount, greaterThanOrEqualTo(25));

      final cap = max(2, (30 * _artistTotals(w, pool)['b']!).ceil() + 1);
      final bCount = top.where((s) => s.startsWith('b#')).length;
      expect(bCount, lessThanOrEqualTo(max(cap, 2)));
    });
  });
}
