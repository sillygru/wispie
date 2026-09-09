import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/providers/indexer_provider.dart';
import 'package:wispie/services/passive_art_fetcher_service.dart';

void main() {
  group('sortKeysByCount', () {
    test('orders most tracks first, name on ties', () {
      final keys = ['c', 'a', 'b', 'd'];
      PassiveArtFetcherService.sortKeysByCount(keys, {
        'a': 5,
        'b': 10,
        'c': 5,
        'd': 1,
      });
      expect(keys, ['b', 'a', 'c', 'd']);
    });

    test('unknown keys count as zero and sort last', () {
      final keys = ['known', 'new'];
      PassiveArtFetcherService.sortKeysByCount(keys, {'known': 3});
      expect(keys, ['known', 'new']);
    });

    test('empty input stays empty', () {
      final keys = <String>[];
      PassiveArtFetcherService.sortKeysByCount(keys, {});
      expect(keys, isEmpty);
    });
  });

  group('IndexerOperation split art progress', () {
    const op = IndexerOperation(
      id: 'rebuild_artist_album_art',
      name: 'Fetch Artist & Album Covers',
      description: 'x',
    );

    test('no split progress before counts load', () {
      expect(op.hasSplitArtProgress, isFalse);
      expect(op.artistProgress, 0.0);
      expect(op.albumProgress, 0.0);
    });

    test('copyWith carries split channels and math holds', () {
      final updated = op.copyWith(
        artistProcessed: 3,
        artistTotal: 4,
        albumProcessed: 1,
        albumTotal: 2,
        processedCount: 4,
        totalCount: 6,
        targetCount: 6,
      );
      expect(updated.hasSplitArtProgress, isTrue);
      expect(updated.artistProgress, 0.75);
      expect(updated.albumProgress, 0.5);
      expect(updated.artistProgressText, '3/4');
      expect(updated.albumProgressText, '1/2');
      // Combined counters stay in sync for shared subtitle logic.
      expect(updated.processedCount, 4);
      expect(updated.totalCount, 6);
      expect(updated.progressText, '4/6');
    });
  });
}
