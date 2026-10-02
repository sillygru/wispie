import 'package:flutter_test/flutter_test.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/services/database_service.dart';

import 'test_helpers.dart';

/// Pins the promise a song replacement makes: nothing the app knew about the
/// song is stranded on the old filename.
///
/// `filename` is the primary key for every piece of user data, so a filename
/// change that misses a table does not merely lose that data — it hides it
/// behind a key nothing will ask about again, which looks exactly like never
/// having had it. Play history is the case that matters most: it is the whole
/// reason to replace a file rather than delete one and add another.
void main() {
  late TestEnvironment testEnv;

  const original = 'Only You.mp3';
  const replacement = 'Only You.flac';

  setUpAll(() {
    testEnv = TestEnvironment();
    testEnv.setUp();
  });

  tearDownAll(() {
    testEnv.tearDown();
  });

  Future<void> wipeEverything() async {
    final db = DatabaseService.instance;
    await db.clearSongs();
    await db.clearStats();
    for (final table in const [
      'favorite',
      'suggestless',
      'hidden',
      'cover_miss',
      'lyrics_timing_offset',
      'translated_lyrics',
      'merged_song',
      'merged_song_group',
      'playlist_song',
      'playlist',
      'queue_snapshot_song',
      'queue_snapshot',
    ]) {
      await db.getUserDataDatabase()!.delete(table);
    }
  }

  Future<List<String>> columnOf(
    String table,
    String column,
    String value,
  ) async {
    final rows = await DatabaseService.instance
        .getUserDataDatabase()!
        .query(table, where: '$column = ?', whereArgs: [value]);
    return rows.map((r) => r[column] as String).toList();
  }

  Song song(String filename) => Song(
        title: 'Only You',
        artist: 'The Weeknd',
        album: 'After Hours',
        filename: filename,
        url: '/music/$filename',
      );

  setUp(() async {
    await DatabaseService.instance.init();
    await wipeEverything();
  });

  /// Seeds one of everything keyed on a song filename, so a single rename can
  /// be shown to move all of it.
  Future<void> seedFullHistoryForOriginal() async {
    final db = DatabaseService.instance;

    await db.insertSongsBatch([song(original), song('Only You (Live).mp3')]);

    await db.addFavorite(original);
    await db.addSuggestLess(original);
    await db.addHidden(original);
    await db.markCoverMiss(original, 1700000000);
    await db.setLyricsTimingOffset(original, -1.5);
    await db.saveTranslatedLyrics(original, 'es', 'Solo tu');
    await db.addSongToPlaylist('pl-1', original);
    await db.saveQueueSnapshot('snap-1', 'Road trip', 1700000000, 'playlist',
        [original, 'Only You (Live).mp3']);
    await db.createMergedGroup([original, 'Only You (Live).mp3'],
        priorityFilename: original);

    // Distinct sessions, because play events coalesce per session.
    for (var i = 0; i < 3; i++) {
      await db.insertPlayEvent({
        'session_id': 'session-$i',
        'song_filename': original,
        'timestamp': 1700000000.0 + i,
        'duration_played': 200.0,
        'total_length': 200.0,
        'play_ratio': 1.0,
        'platform': 'test',
      });
    }
  }

  test('play history moves to the replacement file', () async {
    await seedFullHistoryForOriginal();

    await DatabaseService.instance.renameFile(original, replacement);

    final playCounts = await DatabaseService.instance.getPlayCounts();
    expect(playCounts[replacement], 3);
    expect(playCounts.containsKey(original), isFalse);

    // The timestamp is history too — a recency sort has to agree with the count.
    final lastPlayed = await DatabaseService.instance.getLastPlayedTimestamps();
    expect(lastPlayed[replacement], 1700000002.0);
    expect(lastPlayed.containsKey(original), isFalse);
  });

  test('every filename-keyed record moves, and none is left behind', () async {
    await seedFullHistoryForOriginal();

    await DatabaseService.instance.renameFile(original, replacement);

    final db = DatabaseService.instance;

    expect(await db.getSongByFilename(replacement), isNotNull);
    expect(await db.getSongByFilename(original), isNull);

    expect(
        await columnOf('favorite', 'filename', replacement), ['Only You.flac']);
    expect(await columnOf('suggestless', 'filename', replacement),
        ['Only You.flac']);
    expect(
        await columnOf('hidden', 'filename', replacement), ['Only You.flac']);
    expect(await columnOf('cover_miss', 'filename', replacement),
        ['Only You.flac']);
    expect(await columnOf('merged_song', 'filename', replacement),
        ['Only You.flac']);
    expect(await columnOf('playlist_song', 'song_filename', replacement),
        ['Only You.flac']);
    expect(
      await columnOf('queue_snapshot_song', 'song_filename', replacement),
      ['Only You.flac'],
    );
    expect(
      await columnOf('merged_song_group', 'priority_filename', replacement),
      ['Only You.flac'],
    );
    for (final entry in const {
      'favorite': 'filename',
      'suggestless': 'filename',
      'hidden': 'filename',
      'cover_miss': 'filename',
      'merged_song': 'filename',
      'playlist_song': 'song_filename',
      'queue_snapshot_song': 'song_filename',
      'merged_song_group': 'priority_filename',
    }.entries) {
      expect(
        await columnOf(entry.key, entry.value, original),
        isEmpty,
        reason: '${entry.key} still points at the old filename',
      );
    }
  });

  test('lyrics timing and translations survive the swap', () async {
    await seedFullHistoryForOriginal();

    await DatabaseService.instance.renameFile(original, replacement);

    final rows = await DatabaseService.instance.getUserDataDatabase()!.query(
        'lyrics_timing_offset',
        where: 'filename = ?',
        whereArgs: [replacement]);
    expect(rows.single['offset_seconds'], -1.5);

    final translations = await DatabaseService.instance
        .getUserDataDatabase()!
        .query('translated_lyrics',
            where: 'filename = ?', whereArgs: [replacement]);
    expect(translations.single['target_lang'], 'es');
    expect(translations.single['translated_content'], 'Solo tu');

    expect(
      await columnOf('lyrics_timing_offset', 'filename', original),
      isEmpty,
    );
    expect(await columnOf('translated_lyrics', 'filename', original), isEmpty);
  });

  test('a saved queue keeps every position', () async {
    await seedFullHistoryForOriginal();

    await DatabaseService.instance.renameFile(original, replacement);

    expect(
      await DatabaseService.instance.getQueueSnapshotSongs('snap-1'),
      ['Only You.flac', 'Only You (Live).mp3'],
    );
  });

  test('disposing of the original afterwards cannot take the new file with it',
      () async {
    // This is the sequence a "delete the original" replacement runs: migrate
    // everything, then delete the file it replaced. Deleting a filename must
    // never reach past the rows that already moved on.
    await seedFullHistoryForOriginal();
    final db = DatabaseService.instance;
    await db.renameFile(original, replacement);

    await db.deleteFile(original);

    expect(await db.getSongByFilename(replacement), isNotNull);
    expect((await db.getPlayCounts())[replacement], 3);
    expect(
      await db.getQueueSnapshotSongs('snap-1'),
      contains('Only You.flac'),
    );
    expect(
        await columnOf('favorite', 'filename', replacement), ['Only You.flac']);
  });

  group('collisions', () {
    test('an existing translation in the same language is not duplicated',
        () async {
      final db = DatabaseService.instance;
      await db.saveTranslatedLyrics(original, 'es', 'Solo tu');
      await db.saveTranslatedLyrics(replacement, 'es', 'Solo tú');
      await db.saveTranslatedLyrics(original, 'fr', 'Toi seul');

      await db.renameFile(original, replacement);

      final rows = await db.getUserDataDatabase()!.query('translated_lyrics',
          where: 'filename = ?', whereArgs: [replacement]);
      expect(rows.length, 2);

      // The other language still arrives; the clashing one keeps the row that
      // was already there rather than duplicating it.
      final byLanguage = {
        for (final r in rows)
          r['target_lang'] as String: r['translated_content'],
      };
      expect(byLanguage['es'], 'Solo tú');
      expect(byLanguage['fr'], 'Toi seul');
      expect(
          await columnOf('translated_lyrics', 'filename', original), isEmpty);
    });

    test('play history merges into a file already carrying some', () async {
      final db = DatabaseService.instance;
      for (final filename in [original, replacement]) {
        await db.insertPlayEvent({
          'session_id': 'session-$filename',
          'song_filename': filename,
          'timestamp': 1700000000.0,
          'duration_played': 200.0,
          'total_length': 200.0,
          'play_ratio': 1.0,
          'platform': 'test',
        });
      }

      await db.renameFile(original, replacement);

      final playCounts = await db.getPlayCounts();
      expect(playCounts[replacement], 2);
      expect(playCounts.containsKey(original), isFalse);
    });
  });
}
