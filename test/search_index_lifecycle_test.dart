import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/domain/models/search_filter.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:wispie/data/repositories/search_index_repository.dart';
import 'package:wispie/domain/services/search_service.dart';
import 'package:wispie/models/song.dart';
import 'test_helpers.dart';

void main() {
  late TestEnvironment testEnv;

  setUpAll(() async {
    testEnv = TestEnvironment();
    testEnv.setUp();
  });

  tearDownAll(() async {
    await testEnv.tearDown();
  });

  test(
      'SearchService continues working after updating metadata or disposing temporary service',
      () async {
    final mainSearchService = SearchService();
    await mainSearchService.init();

    const initialSong = Song(
      title: 'Original Title',
      artist: 'Original Artist',
      album: 'Original Album',
      filename: 'test_song.mp3',
      url: '/music/test_song.mp3',
      duration: Duration(seconds: 180),
    );

    await mainSearchService.rebuildIndex([initialSong]);

    final initialResults = await mainSearchService.search(
      query: 'Original',
      filterState: const SearchFilterState(all: true),
      allSongs: [initialSong],
    );
    expect(initialResults.length, equals(1));
    expect(initialResults.first.song.title, equals('Original Title'));

    // Simulate metadata edit via temporary SearchService
    final tempSearchService = SearchService();
    await tempSearchService.init();

    const updatedSong = Song(
      title: 'Updated Title',
      artist: 'Updated Artist',
      album: 'Updated Album',
      filename: 'test_song.mp3',
      url: '/music/test_song.mp3',
      duration: Duration(seconds: 180),
    );

    await tempSearchService.updateSong(updatedSong);
    await tempSearchService.dispose();

    // Verify main search service still functions without throwing closed db error
    final updatedResults = await mainSearchService.search(
      query: 'Updated',
      filterState: const SearchFilterState(all: true),
      allSongs: [updatedSong],
    );

    expect(updatedResults.length, equals(1));
    expect(updatedResults.first.song.title, equals('Updated Title'));
  });

  /// A rename has to *move* the index row, not rebuild it.
  ///
  /// The distinction is not cosmetic. `upsertSong` looks up `lyrics_content` by
  /// the song's current filename, so re-upserting under a new name finds nothing
  /// and shells out to ffprobe to re-read lyrics the index was already holding.
  /// On a batch that is one subprocess per song.
  group('search index rename', () {
    Song track(String filename, String title) => Song(
          title: title,
          artist: 'The Weeknd',
          album: 'After Hours',
          filename: filename,
          url: '/music/$filename',
        );

    Future<Database> openIndex() => openDatabase(p.join(
        SearchIndexRepository.testDocumentsPath!, 'wispie_search_index.db'));

    /// The row as it actually stands. Asserting through `search` alone hides
    /// the difference, because a missing row and a missing term both return
    /// nothing.
    Future<Map<String, Object?>> rowFor(String filename) async {
      final db = await openIndex();
      final rows = await db
          .query('search_index', where: 'filename = ?', whereArgs: [filename]);
      await db.close();
      expect(rows.length, 1, reason: 'expected exactly one row for $filename');
      return rows.first;
    }

    test('lyrics content moves with the row instead of being re-derived',
        () async {
      final service = SearchService();
      await service.init();

      final original = track('track 01.mp3', 'Blinding Lights');
      await service.rebuildIndex([original]);

      final seed = await openIndex();
      await seed.update(
        'search_index',
        {'lyrics_content': 'neon streets cold heart'},
        where: 'filename = ?',
        whereArgs: [original.filename],
      );
      await seed.close();

      const renamedName = '01 - The Weeknd - Blinding Lights.mp3';
      await service.renameFiles([(from: original.filename, to: renamedName)]);

      // Re-upserting under a new key would land here with a null
      // `lyrics_content`, having failed to find it under the new name and given
      // up before shelling out to ffprobe for a file that does not exist.
      expect((await rowFor(renamedName))['lyrics_content'],
          'neon streets cold heart');
    });

    test('the old row is gone, not left behind as a duplicate', () async {
      final service = SearchService();
      await service.init();

      final original = track('dup.mp3', 'Duplicate Probe');
      await service.rebuildIndex([original]);
      await service.renameFiles([(from: original.filename, to: 'moved.mp3')]);

      // Counted on the rows themselves. Going through `search` cannot tell the
      // two apart: a stale row is filtered out of the results anyway, because
      // the stale filename is no longer in the library.
      final db = await openIndex();
      final rows = await db.query('search_index', columns: ['filename']);
      await db.close();
      expect(rows.map((r) => r['filename']), ['moved.mp3']);
    });

    test('a whole batch moves in one call', () async {
      final service = SearchService();
      await service.init();

      final songs = [track('x1.mp3', 'Alpha'), track('x2.mp3', 'Beta')];
      await service.rebuildIndex(songs);

      await service.renameFiles([
        (from: 'x1.mp3', to: 'Artist - Alpha.mp3'),
        (from: 'x2.mp3', to: 'Artist - Beta.mp3'),
      ]);

      final results = await service.search(
        query: 'beta',
        filterState: const SearchFilterState(all: true),
        allSongs: [songs[1].copyWith(filename: 'Artist - Beta.mp3')],
      );
      expect(results.length, 1);
      expect(results.first.song.filename, 'Artist - Beta.mp3');
    });
  });
}
