import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wispie/services/online_metadata_service.dart';
import 'package:wispie/services/passive_art_fetcher_service.dart';

import 'test_helpers.dart';

void main() {
  late TestEnvironment testEnv;
  final fetcher = PassiveArtFetcherService.instance;

  setUpAll(() {
    testEnv = TestEnvironment();
    testEnv.setUp();
  });

  tearDownAll(() {
    testEnv.tearDown();
  });

  setUp(() async {
    await fetcher.clearAttempted();
  });

  test('artist 404 skip is recorded, persisted and forgettable', () async {
    expect(fetcher.isArtistSkipped('Some Artist'), isFalse);

    fetcher.recordArtistNoResultForTest(
      'Some Artist',
      DateTime.utc(2026, 1, 2, 3, 4, 5),
    );
    expect(fetcher.isArtistSkipped('some artist'), isTrue);

    await fetcher.flushPersistForTest();
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString('art_fetch_noresult_artists_v2');
    expect(raw, isNotNull);
    expect(raw, contains('some artist'));
    expect(raw, contains('2026-01-02'));

    fetcher.forgetArtistAttempt('SOME ARTIST');
    expect(fetcher.isArtistSkipped('some artist'), isFalse);
    await fetcher.flushPersistForTest();
    final after = (await SharedPreferences.getInstance())
        .getString('art_fetch_noresult_artists_v2');
    expect(after == null || !after.contains('some artist'), isTrue);
  });

  test('album 404 skip uses composite key and persists timestamp', () async {
    expect(fetcher.isAlbumSkipped('Album', 'Artist'), isFalse);

    fetcher.recordAlbumNoResultForTest(
      'Album',
      'Artist',
      DateTime.utc(2026, 5, 6),
    );
    expect(fetcher.isAlbumSkipped('album', 'artist'), isTrue);
    expect(fetcher.isAlbumSkipped('album', 'other'), isFalse);

    await fetcher.flushPersistForTest();
    final raw = (await SharedPreferences.getInstance())
        .getString('art_fetch_noresult_albums_v2');
    expect(raw, contains('artist|album'));

    await fetcher.clearAttempted();
    expect(fetcher.isAlbumSkipped('album', 'artist'), isFalse);
    expect(
      (await SharedPreferences.getInstance())
          .getString('art_fetch_noresult_albums_v2'),
      isNull,
    );
  });

  test('unified lookup short-circuits unknown tags without network', () async {
    final artist = await OnlineMetadataService.instance
        .searchArtistCandidatesUnified('unknown artist');
    expect(artist.candidates, isEmpty);
    expect(artist.outcome, CoverLookupOutcome.notFound);

    final album = await OnlineMetadataService.instance
        .searchAlbumCandidatesUnified('unknown album', artistName: 'x');
    expect(album.candidates, isEmpty);
    expect(album.outcome, CoverLookupOutcome.notFound);
  });
}
