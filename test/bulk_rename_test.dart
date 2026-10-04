import "dart:io";

import "package:flutter_test/flutter_test.dart";
import "package:path/path.dart" as p;
import "package:path_provider/path_provider.dart";
import 'package:wispie/domain/models/cover_key.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/services/cache_service.dart';
import 'package:wispie/services/database_service.dart';
import 'package:wispie/services/file_manager_service.dart';

import 'test_helpers.dart';

/// End-to-end for a batch rename: the file moves on disk, every piece of user
/// data keyed on its old filename follows, and the derived caches — waveform,
/// beat map, blurred art, lyrics — follow instead of being thrown away.
///
/// The cache half is why this test exists. `filename` is the app's primary key,
/// so a rename is safe for data the moment the database rows move; caches are
/// the part that silently degrades, because each one is keyed on a *hash* of
/// the filename and nothing notices that the hash no longer matches anything.
///
/// The per-table rules themselves are pinned once, in `song_replace_db_test`.
/// What matters here is the wiring: that the file service actually reaches the
/// database, and that the batch entry point is the same code.
void main() {
  late TestEnvironment testEnv;
  late Directory musicDir;
  late FileManagerService fileManager;

  const oldFilename = '01 - Only You.mp3';
  const newFilename = 'The Weeknd - After Hours - Only You.mp3';

  setUpAll(() {
    testEnv = TestEnvironment();
    testEnv.setUp();
  });

  tearDownAll(() {
    testEnv.tearDown();
  });

  setUp(() async {
    await DatabaseService.instance.init();
    fileManager = FileManagerService();

    final support = await getApplicationSupportDirectory();
    musicDir = Directory(p.join(support.path, 'music'));
    // Renaming leaves files behind by design; a leftover target would make the
    // next test's rename look like a collision.
    if (await musicDir.exists()) await musicDir.delete(recursive: true);
    await musicDir.create(recursive: true);

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
  });

  Song seedSong({String filename = oldFilename}) {
    final file = File(p.join(musicDir.path, filename))
      ..writeAsBytesSync(const [1, 2, 3]);
    return Song(
      title: 'Only You',
      artist: 'The Weeknd',
      album: 'After Hours',
      filename: filename,
      url: file.path,
    );
  }

  /// Writes each filename-keyed cache the app keeps for a song.
  Future<void> seedCachesFor(Song song) async {
    final cache = CacheService.instance;
    await cache.init();

    await cache
        .getWaveformCacheFile(song.filename)
        .then((f) => f.writeAsString('[0.5]'));
    await cache
        .getBeatMapCacheFile(song.filename)
        .then((f) => f.writeAsString('[120]'));
    await cache
        .getBlurredCacheFile(song.filename)
        .then((f) => f.writeAsBytesSync(const [9]));

    final support = await getApplicationSupportDirectory();
    final lyricsDir =
        Directory(p.join(support.path, 'gru_cache_v3', 'lyrics_cache'))
          ..createSync(recursive: true);
    // The lyrics cache is keyed on the full path, not the filename.
    File(p.join(lyricsDir.path, '${sha1Of(song.url)}.json'))
        .writeAsStringSync('{"hasLyrics":true,"lyrics":"la la"}');
  }

  /// Seeds one of everything keyed on a song filename, so a rename can be shown
  /// to move all of it.
  Future<void> seedUserDataFor(Song song) async {
    final db = DatabaseService.instance;
    await db.insertSongsBatch([song]);
    await db.addFavorite(song.filename);
    await db.addSuggestLess(song.filename);
    await db.addHidden(song.filename);
    await db.markCoverMiss(song.filename, 1700000000);
    await db.setLyricsTimingOffset(song.filename, -1.5);
    await db.saveTranslatedLyrics(song.filename, 'es', 'Solo tu');
    await db.addSongToPlaylist('pl-1', song.filename);
    await db.addSongToPlaylist('pl-2', song.filename);
    // Saved queues are keyed (snapshot_id, position), so each song needs its own
    // snapshot or they overwrite each other's single entry.
    await db.saveQueueSnapshot('snap-${song.filename}', 'Trip', 1700000000,
        'playlist', [song.filename]);
    await db.insertPlayEvent({
      'session_id': 'session-${song.filename}',
      'song_filename': song.filename,
      'timestamp': 1700000000.0,
      'duration_played': 200.0,
      'total_length': 200.0,
      'play_ratio': 1.0,
      'platform': 'test',
    });
  }

  Future<List<String>> filenamesIn(String table, String column) async {
    final rows = await DatabaseService.instance
        .getUserDataDatabase()!
        .query(table, columns: [column]);
    return rows.map((r) => r[column] as String).toList();
  }

  test('the file itself moves, keeping its extension', () async {
    final song = seedSong();

    await fileManager.renameSongToFilename(song, newFilename);

    expect(File(song.url).existsSync(), isFalse);
    expect(File(p.join(musicDir.path, newFilename)).existsSync(), isTrue);
  });

  test('a rename stem does not double the extension', () async {
    // The single-file entry point takes a stem; the batch entry point takes a
    // whole filename. Mixing the two up is how a .mp3.mp3 got shipped.
    final song = seedSong();

    await fileManager.renameSong(song, 'Renamed By Stem');

    expect(
      File(p.join(musicDir.path, 'Renamed By Stem.mp3')).existsSync(),
      isTrue,
    );
  });

  test('a case-only change still lands', () async {
    // Every mobile and desktop volume worth shipping on is case-insensitive,
    // where this rename has to go through a temp name to take effect.
    final song = seedSong(filename: 'only you.mp3');

    await fileManager.renameSongToFilename(song, 'Only You.mp3');

    // Asserted against the directory listing rather than existsSync: on a
    // case-insensitive volume both spellings resolve to one file, so only the
    // stored name distinguishes them.
    final entries = musicDir.listSync().map((e) => p.basename(e.path)).toList();
    expect(entries, ['Only You.mp3']);
    expect(entries.where((e) => e.startsWith('.wispie_rename_')), isEmpty);
  });

  test('a rename that would land on a taken name is refused', () async {
    // The collision check has to skip the case-only case to work at all, which
    // makes it easy to leave off the real check entirely. This is the one that
    // matters: overwriting a file is the worst outcome a rename can produce.
    final song = seedSong();
    File(p.join(musicDir.path, newFilename)).writeAsBytesSync(const [1]);

    await expectLater(
      fileManager.renameSongToFilename(song, newFilename),
      throwsA(anything),
    );
    expect(File(song.url).existsSync(), isTrue,
        reason: 'the source must survive a refused rename');
  });

  test('renaming one file moves the disk entry and the rows together',
      () async {
    // `renameSongToFilename` is the whole public contract of the single-file
    // path: it is the only place the disk rename and the database migration are
    // joined, so a missing call in either one loses user data silently.
    final song = seedSong();
    await seedUserDataFor(song);

    await fileManager.renameSongToFilename(song, newFilename);

    expect(File(p.join(musicDir.path, newFilename)).existsSync(), isTrue);
    expect(await filenamesIn('favorite', 'filename'), [newFilename]);
    // Both playlists the song was in, under the new name.
    expect(await filenamesIn('playlist_song', 'song_filename'),
        [newFilename, newFilename]);
    expect((await DatabaseService.instance.getPlayCounts())[newFilename], 1);
    expect(
      (await DatabaseService.instance.getAllSongs()).map((s) => s.filename),
      [newFilename],
    );
  });

  test('waveform, beat map and blurred art follow the new name', () async {
    final song = seedSong();
    await seedCachesFor(song);
    final before = song.copyWith(filename: newFilename);

    await CacheService.instance.transferSongCaches(before: song, after: before);

    final cache = CacheService.instance;

    expect(
        await cache.getWaveformCacheFile(newFilename).then((f) => f.exists()),
        isTrue);
    expect(await cache.getBeatMapCacheFile(newFilename).then((f) => f.exists()),
        isTrue);
    expect(await cache.getBlurredCacheFile(newFilename).then((f) => f.exists()),
        isTrue);

    expect(
        await cache.getWaveformCacheFile(oldFilename).then((f) => f.exists()),
        isFalse);
    expect(await cache.getBeatMapCacheFile(oldFilename).then((f) => f.exists()),
        isFalse);
    expect(await cache.getBlurredCacheFile(oldFilename).then((f) => f.exists()),
        isFalse);
  });

  test('the lyrics cache moves instead of being dropped', () async {
    // The rename path used to delete this outright, even though the content is
    // untouched by a rename and the cache is now keyed on the new path.
    final song = seedSong();
    await seedCachesFor(song);
    final before = song.copyWith(
        filename: newFilename, url: p.join(musicDir.path, newFilename));

    await CacheService.instance.transferSongCaches(before: song, after: before);

    final support = await getApplicationSupportDirectory();
    final lyricsDir =
        Directory(p.join(support.path, 'gru_cache_v3', 'lyrics_cache'));
    final carried = File(p.join(lyricsDir.path, '${sha1Of(before.url)}.json'));
    final abandoned = File(p.join(lyricsDir.path, '${sha1Of(song.url)}.json'));

    expect(carried.existsSync(), isTrue);
    expect(abandoned.existsSync(), isFalse);
  });

  test('a content-addressed cover is left exactly where it is', () async {
    final support = await getApplicationSupportDirectory();
    final coversDir = Directory(p.join(support.path, 'extracted_covers'))
      ..createSync(recursive: true);
    final cover = File(p.join(coversDir.path, 'c_deadbeef.jpg'))
      ..writeAsBytesSync(const [7]);
    final song = seedSong().copyWith(coverUrl: cover.path);

    final moved = await CacheService.instance.transferSongCaches(
      before: song,
      after: song.copyWith(filename: newFilename),
    );

    expect(moved, isNull,
        reason: 'a content cover is not filename-keyed, so nothing moves');
    expect(cover.existsSync(), isTrue);
  });

  test('a video cover is named after the song, so it moves and is reported',
      () async {
    final support = await getApplicationSupportDirectory();
    final coversDir = Directory(p.join(support.path, 'extracted_covers'))
      ..createSync(recursive: true);
    final oldCover = File(
      p.join(coversDir.path, '${CoverKey(oldFilename).hash}_ffmpeg.jpg'),
    )..writeAsBytesSync(const [3]);
    final song = seedSong().copyWith(coverUrl: oldCover.path);

    final moved = await CacheService.instance.transferSongCaches(
      before: song,
      after: song.copyWith(filename: newFilename),
    );

    expect(moved,
        p.join(coversDir.path, '${CoverKey(newFilename).hash}_ffmpeg.jpg'));
    expect(File(moved!).existsSync(), isTrue);
    expect(oldCover.existsSync(), isFalse);
  });

  test('a cache file that is already populated is not clobbered', () async {
    final song = seedSong();
    await seedCachesFor(song);
    final cache = CacheService.instance;

    // Something else already wrote this song's waveform under the new name.
    final occupied = await cache.getWaveformCacheFile(newFilename);
    await occupied.writeAsString('[existing]');

    await cache.transferSongCaches(
      before: song,
      after: song.copyWith(filename: newFilename),
    );

    expect(await occupied.readAsString(), '[existing]');
  });

  /// The batch path has to be indistinguishable from the single-file one, only
  /// amortised. These pin that for a whole batch at once, because the difference
  /// is a matter of which code path runs — `renameFile` opens a transaction per
  /// song, `renameFiles` opens one for the lot.
  group('renameFiles', () {
    test('every filename-keyed table moves for the whole batch', () async {
      final songs = [
        seedSong(filename: 'a.mp3').copyWith(title: 'One'),
        seedSong(filename: 'b.mp3').copyWith(title: 'Two'),
        seedSong(filename: 'c.mp3').copyWith(title: 'Three'),
      ];
      for (final song in songs) {
        await seedUserDataFor(song);
      }
      // One group of all three. A merged group is culled once it drops to a
      // single song, so splitting these across groups would delete itself.
      await DatabaseService.instance.createMergedGroup(
        ['a.mp3', 'b.mp3', 'c.mp3'],
        priorityFilename: 'a.mp3',
      );

      await DatabaseService.instance.renameFiles([
        (from: 'a.mp3', to: 'Artist - One.mp3'),
        (from: 'b.mp3', to: 'Artist - Two.mp3'),
        (from: 'c.mp3', to: 'Artist - Three.mp3'),
      ]);

      for (final name in [
        'Artist - One.mp3',
        'Artist - Two.mp3',
        'Artist - Three.mp3'
      ]) {
        expect(await filenamesIn('favorite', 'filename'), contains(name));
        expect(await filenamesIn('suggestless', 'filename'), contains(name));
        expect(await filenamesIn('hidden', 'filename'), contains(name));
        expect(await filenamesIn('cover_miss', 'filename'), contains(name));
        expect(await filenamesIn('lyrics_timing_offset', 'filename'),
            contains(name));
        expect(
            await filenamesIn('translated_lyrics', 'filename'), contains(name));
        expect(await filenamesIn('merged_song', 'filename'), contains(name));
        expect(await filenamesIn('playlist_song', 'song_filename'),
            contains(name));
        expect(await filenamesIn('queue_snapshot_song', 'song_filename'),
            contains(name));
      }

      // The priority is a filename like any other, so it has to follow too.
      expect(await filenamesIn('merged_song_group', 'priority_filename'),
          ['Artist - One.mp3']);

      final songs2 = await DatabaseService.instance.getAllSongs();
      expect(songs2.map((s) => s.filename).toSet(), {
        'Artist - One.mp3',
        'Artist - Two.mp3',
        'Artist - Three.mp3',
      });

      final playCounts = await DatabaseService.instance.getPlayCounts();
      expect(playCounts.keys.toSet(), {
        'Artist - One.mp3',
        'Artist - Two.mp3',
        'Artist - Three.mp3',
      });
      expect(playCounts['Artist - One.mp3'], 1);
    });

    test('the row for the file being renamed survives a name already in use',
        () async {
      // The song table is keyed on the filename, so a stale row sitting at the
      // target name would trip the primary key and take the whole batch down.
      // The row that describes the file actually being renamed has to win: it
      // carries that file's cover and date-added.
      final db = DatabaseService.instance;
      await db.insertSongsBatch([
        seedSong(filename: 'a.mp3')
            .copyWith(title: 'Mine', coverUrl: '/covers/mine.jpg'),
        seedSong(filename: 'Artist - One.mp3')
            .copyWith(title: 'Stale', coverUrl: '/covers/stale.jpg'),
      ]);

      await db.renameFiles([(from: 'a.mp3', to: 'Artist - One.mp3')]);

      final songs = await db.getAllSongs();
      expect(songs.map((s) => s.filename), ['Artist - One.mp3']);
      expect(songs.single.title, 'Mine');
      expect(songs.single.coverUrl, '/covers/mine.jpg');
    });

    test('replaying a rename that already happened changes nothing', () async {
      // A bulk rename journals its intent before touching the disk so that a
      // sweep killed part-way can be finished on the next launch. The launch
      // cannot tell whether the rows it is about to move were already moved by
      // the run that died, so the same pair comes back through this call a second
      // time — and the second time there is no row at the old name to move.
      //
      // Getting that wrong costs the song's row outright, leaving its favourites,
      // playlists and stats keyed to a filename nothing will ever ask about.
      final db = DatabaseService.instance;
      final song = seedSong(filename: 'a.mp3')
          .copyWith(title: 'One', coverUrl: '/covers/mine.jpg');
      await seedUserDataFor(song);

      const pair = (from: 'a.mp3', to: 'Artist - One.mp3');
      await db.renameFiles([pair]);

      final afterFirst = await db.getAllSongs();
      expect(afterFirst.map((s) => s.filename), ['Artist - One.mp3']);

      // Twice more, to be sure the second one settles rather than only shifting
      // the problem along.
      await db.renameFiles([pair]);
      await db.renameFiles([pair]);

      final afterReplay = await db.getAllSongs();
      expect(afterReplay.map((s) => s.filename), ['Artist - One.mp3']);
      expect(afterReplay.single.title, 'One');
      expect(afterReplay.single.coverUrl, '/covers/mine.jpg',
          reason:
              'the row a replay must not destroy is the only copy of the cover');

      // The user data is what makes the loss unrecoverable, so check it is still
      // attached to something.
      expect(await filenamesIn('favorite', 'filename'), ['Artist - One.mp3']);
      expect(await filenamesIn('playlist_song', 'song_filename'),
          everyElement('Artist - One.mp3'));
      expect((await db.getPlayCounts()).keys.toSet(), {'Artist - One.mp3'});
    });

    test('a song already in the playlist under its new name is not duplicated',
        () async {
      // playlist_song is keyed on its own id, so nothing stops a rename from
      // putting the same song in a playlist twice. The two rows have to be
      // merged instead.
      final db = DatabaseService.instance;
      final song = seedSong(filename: 'a.mp3');
      await db.insertSongsBatch([song]);
      await db.addSongToPlaylist('pl-1', 'a.mp3');
      await db.addSongToPlaylist('pl-1', 'Artist - One.mp3');

      await db.renameFiles([(from: 'a.mp3', to: 'Artist - One.mp3')]);

      final rows = await db.getUserDataDatabase()!.query(
        'playlist_song',
        where: 'playlist_id = ?',
        whereArgs: ['pl-1'],
      );
      expect(rows.length, 1);
      expect(rows.single['song_filename'], 'Artist - One.mp3');
    });
  });
}

/// The same hash the cache files are named with, written out here so the test
/// does not have to reach into the service under test to build its expectation.
String sha1Of(String value) => CoverKey(value).hash;
