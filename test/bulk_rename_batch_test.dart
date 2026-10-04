import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus_platform_interface/package_info_data.dart';
import 'package:package_info_plus_platform_interface/package_info_platform_interface.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wispie/domain/services/bulk_rename_planner.dart';
import 'package:wispie/models/song.dart';
import 'package:wispie/providers/providers.dart';
import 'package:wispie/services/bulk_rename_journal.dart';
import 'package:wispie/services/database_service.dart';
import 'package:wispie/services/file_manager_service.dart';

import 'test_helpers.dart';

const _appVersion = '3.26.5-beta+310';

class _MockPackageInfoPlatform extends PackageInfoPlatform {
  @override
  Future<PackageInfoData> getAll({String? baseUrl}) async {
    return PackageInfoData(
      appName: 'wispie',
      packageName: 'com.example.wispie',
      version: '3.26.5-beta',
      buildNumber: '310',
      buildSignature: '',
    );
  }
}

/// Real files, controlled failures.
///
/// A fake for the whole service would not catch the thing that matters here:
/// that a half-finished batch leaves the library and the disk agreeing with each
/// other. So the rename is genuine and only the *trigger* for failure is faked.
class _FlakyFileManager extends FileManagerService {
  final Set<String> refuseToRename = {};

  @override
  Future<void> renameFileOnDisk(Song song, String newFilename) async {
    if (refuseToRename.contains(song.filename)) {
      throw const FileSystemException('simulated: file is locked');
    }
    await super.renameFileOnDisk(song, newFilename);
  }
}

/// Refuses the sweep's second row migration, standing in for the process going
/// away part-way through one.
class _CrashAfterFirstCommitDatabase extends DatabaseService {
  _CrashAfterFirstCommitDatabase() : super.forTest();

  int calls = 0;

  @override
  Future<void> renameFiles(List<({String from, String to})> renames) async {
    calls++;
    if (calls > 1) throw StateError('process died mid-sweep');
    await super.renameFiles(renames);
  }
}

/// A batch that stops early or hits failures must still leave the database
/// describing the files that actually moved.
///
/// This is the failure mode the phase split exists to prevent: renaming files
/// first and then bailing out would leave every row pointing at a name that no
/// longer exists, and a song missing from its own library is worse than a slow
/// rename.
void main() {
  late TestEnvironment testEnv;
  late Directory musicDir;
  late _FlakyFileManager fileManager;

  setUpAll(() {
    testEnv = TestEnvironment();
    testEnv.setUp();
    PackageInfoPlatform.instance = _MockPackageInfoPlatform();
  });

  tearDownAll(() {
    testEnv.tearDown();
  });

  setUp(() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('last_scan_version', _appVersion);
    await prefs.setBool('startup_cache_maintenance_pending', false);

    final support = await getApplicationSupportDirectory();
    musicDir = Directory(p.join(support.path, 'music'));
    if (await musicDir.exists()) await musicDir.delete(recursive: true);
    await musicDir.create(recursive: true);

    fileManager = _FlakyFileManager();
    await BulkRenameJournal.instance.clear();

    final db = DatabaseService.forTest();
    DatabaseService.instance = db;
    await db.init();
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

  /// Real files on disk with matching database rows, one per index.
  Future<List<Song>> seed(int count) async {
    final songs = <Song>[];
    for (var i = 1; i <= count; i++) {
      final name = 'song$i.mp3';
      File(p.join(musicDir.path, name)).writeAsBytesSync(const [1]);
      songs.add(Song(
        title: 'Title $i',
        artist: 'Artist',
        album: 'Album',
        filename: name,
        url: p.join(musicDir.path, name),
      ));
    }
    await DatabaseService.instance.insertSongsBatch(songs);
    return songs;
  }

  /// Three real files on disk with a matching database row.
  Future<List<Song>> seedThree() => seed(3);

  Future<List<BulkRenamePlan>> planFor(List<Song> songs) async {
    final plans = BulkRenamePlanner.plan(
      songs: songs,
      segments: BulkRenameSegment.presets[0],
    );
    return BulkRenamePlanner.excludeExistingTargets(
      plans,
      exists: (path) => File(path).exists(),
    );
  }

  Future<ProviderContainer> boot() async {
    final container = ProviderContainer(overrides: [
      fileManagerServiceProvider.overrideWithValue(fileManager),
    ]);
    addTearDown(container.dispose);
    await container.read(songsProvider.future);
    return container;
  }

  /// Asserts that the library, the database and the disk all agree on which
  /// songs exist under which name.
  Future<void> expectLibraryMatchesDisk(List<String> expectedNames) async {
    final fromDb = (await DatabaseService.instance.getAllSongs())
        .map((s) => s.filename)
        .toSet();
    final fromDisk = musicDir.listSync().map((e) => p.basename(e.path)).toSet();

    expect(fromDb.toSet(), expectedNames.toSet(),
        reason: 'the song table and the filesystem disagree');
    expect(fromDisk, expectedNames.toSet(),
        reason: 'the filesystem holds a name the library does not know');
  }

  test('a full batch renames files, rows and the library together', () async {
    final songs = await seedThree();
    final container = await boot();
    final phases = <String>[];

    final result = await container.read(songsProvider.notifier).bulkRenameSongs(
          await planFor(songs),
          onProgress: (label, done, total) => phases.add('$label $done/$total'),
        );

    expect(result.successCount, 3);
    expect(result.failures, isEmpty);
    expect(result.stoppedEarly, isFalse);

    await expectLibraryMatchesDisk(
        ['Title 1.mp3', 'Title 2.mp3', 'Title 3.mp3']);

    final inLibrary = (container.read(songsProvider).value ?? const <Song>[])
        .map((s) => s.filename);
    expect(inLibrary.toSet(), {'Title 1.mp3', 'Title 2.mp3', 'Title 3.mp3'});

    // Progress is reported per phase, not as one long single-number bar.
    expect(phases.first, 'Renaming files 0/3');
    expect(phases, contains('Updating library 1/1'));
  });

  test('cancelling mid-batch stops the files but still migrates what moved',
      () async {
    final songs = await seedThree();
    final container = await boot();

    // Cancel once the first file has been handled.
    var handled = 0;
    final result = await container.read(songsProvider.notifier).bulkRenameSongs(
          await planFor(songs),
          isCancelled: () => handled >= 1,
          onProgress: (label, done, total) {
            if (label == 'Renaming files' && done > handled) handled = done;
          },
        );

    expect(result.stoppedEarly, isTrue,
        reason: 'a cancelled batch must say so rather than claim it finished');
    expect(result.successCount, 1,
        reason: 'exactly one file had been handled when the cancel landed');

    // The whole point of splitting the phases: whatever was renamed is
    // consistent everywhere, and the untouched songs keep their own names.
    await expectLibraryMatchesDisk(['Title 1.mp3', 'song2.mp3', 'song3.mp3']);
  });

  test('a file that refuses to rename is reported and the rest continue',
      () async {
    final songs = await seedThree();
    fileManager.refuseToRename.add('song2.mp3');
    final container = await boot();

    final result = await container
        .read(songsProvider.notifier)
        .bulkRenameSongs(await planFor(songs));

    expect(result.successCount, 2);
    expect(result.failures, hasLength(1));
    expect(result.failures.single.filename, 'song2.mp3');

    await expectLibraryMatchesDisk(['Title 1.mp3', 'song2.mp3', 'Title 3.mp3']);
  });

  test('a plan with nothing actionable does nothing', () async {
    await seedThree();
    final container = await boot();

    final result =
        await container.read(songsProvider.notifier).bulkRenameSongs(const []);

    expect(result.isEmpty, isTrue);
    await expectLibraryMatchesDisk(['song1.mp3', 'song2.mp3', 'song3.mp3']);
  });

  /// The database has to keep up with the files rather than being written once at
  /// the end. A sweep is long enough that the app being closed part-way through is
  /// an ordinary event, not an edge case, and every uncommitted row would be a song
  /// that exists on disk under a name the library does not know.
  group('the database follows the files', () {
    test('a sweep killed part-way leaves the committed slice intact', () async {
      final songs = await seed(30);

      final crashing = _CrashAfterFirstCommitDatabase();
      DatabaseService.instance = crashing;
      await crashing.init();
      await crashing.clearSongs();
      await crashing.insertSongsBatch(songs);
      final container = await boot();

      await expectLater(
        container
            .read(songsProvider.notifier)
            .bulkRenameSongs(await planFor(songs)),
        throwsStateError,
      );

      // The loop commits a slice at a time, so the first songs are in the
      // database even though the sweep never reached its closing write.
      final rows = await crashing.getAllSongs();
      final renamed =
          rows.where((s) => s.filename.startsWith('Title ')).toList();
      expect(renamed, isNotEmpty,
          reason: 'nothing was written until the sweep had finished');
      for (final song in renamed) {
        expect(File(song.url).existsSync(), isTrue,
            reason:
                '${song.filename} is renamed in the database but not on disk');
      }

      // The tail is renamed on disk but not yet in the database, and the journal
      // is the record that says so.
      expect(BulkRenameJournal.instance.entries, isNotEmpty);
      expect(musicDir.listSync().length, 30);
    });

    test('nothing is committed for a file whose rename failed', () async {
      final songs = await seed(30);
      fileManager.refuseToRename.add('song7.mp3');
      final container = await boot();

      final result = await container
          .read(songsProvider.notifier)
          .bulkRenameSongs(await planFor(songs));

      expect(result.successCount, 29);
      expect(result.failures.single.filename, 'song7.mp3');

      final rows = await DatabaseService.instance.getAllSongs();
      final names = rows.map((s) => s.filename).toSet();
      expect(names, contains('song7.mp3'),
          reason:
              'a file that never moved must keep its row under its own name');
      expect(names, isNot(contains('Title 7.mp3')));

      // And the file it refused to touch is still where the library says it is.
      final row = rows.firstWhere((s) => s.filename == 'song7.mp3');
      expect(File(row.url).existsSync(), isTrue);
    });
  });

  test('a finished sweep leaves no journal behind', () async {
    final songs = await seedThree();
    final container = await boot();

    await container.read(songsProvider.notifier).bulkRenameSongs(
          await planFor(songs),
        );

    expect(BulkRenameJournal.instance.isEmpty, isTrue,
        reason:
            'a stale entry would make the next launch re-check a finished rename');
  });

  group('a sweep the app was closed in the middle of', () {
    /// What a process death between the two writes leaves behind: the file at its
    /// new name, and a journal entry saying the rows have not followed.
    Future<void> interruptSweep(List<Song> songs, int howMany) async {
      for (final song in songs.take(howMany)) {
        // Preset 0 renames to the title alone, so this is the name a real sweep
        // would have landed on for these songs.
        final renamed = '${song.title}.mp3';
        await File(song.url).rename(p.join(musicDir.path, renamed));
        await BulkRenameJournal.instance.record(PendingRename(
          from: song.filename,
          to: renamed,
          url: p.join(musicDir.path, renamed),
        ));
      }
    }

    test('is finished on the next launch, not left half-renamed', () async {
      final songs = await seedThree();
      await interruptSweep(songs, 2);

      await boot();

      await expectLibraryMatchesDisk(
          ['Title 1.mp3', 'Title 2.mp3', 'song3.mp3']);

      final rows = await DatabaseService.instance.getAllSongs();
      final second = rows.firstWhere((s) => s.filename == 'Title 2.mp3');
      expect(second.url, p.join(musicDir.path, 'Title 2.mp3'),
          reason: 'the row was renamed but still points at the old path');

      expect(BulkRenameJournal.instance.isEmpty, isTrue);
    });

    test('leaves an untouched song alone when its rename never landed',
        () async {
      await seedThree();
      // The journal is written before the file is touched, so it also records
      // renames that never happened.
      await BulkRenameJournal.instance.record(PendingRename(
        from: 'song1.mp3',
        to: 'Title 1.mp3',
        url: p.join(musicDir.path, 'Title 1.mp3'),
      ));

      await boot();

      await expectLibraryMatchesDisk(['song1.mp3', 'song2.mp3', 'song3.mp3']);
      expect(BulkRenameJournal.instance.isEmpty, isTrue);
    });
  });
}
