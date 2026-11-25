import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import '../data/rust/native_command.dart';
import 'package:file_picker/file_picker.dart';
import 'package:share_plus/share_plus.dart';
import '../domain/services/cache_policy.dart';
import 'backup_manifest.dart';
import 'wispie_cache.dart';
import 'storage_service.dart';
import 'database_service.dart';
import 'wispie_paths.dart';
import 'import_options.dart';
import 'library_repair_service.dart';
import 'song_identity_service.dart';
import '../models/song.dart';
import '../models/shuffle_config.dart';
import '../data/repositories/search_index_repository.dart';

export 'backup_manifest.dart' show BackupContentType;

class BackupOptions {
  final Set<BackupContentType> contentTypes;

  BackupOptions({Set<BackupContentType>? contentTypes})
      : contentTypes = contentTypes ??
            {
              BackupContentType.userStats,
              BackupContentType.userData,
            };

  bool get includeUserStats =>
      contentTypes.contains(BackupContentType.userStats);
  bool get includeUserData => contentTypes.contains(BackupContentType.userData);
  bool get includeUserSettings =>
      contentTypes.contains(BackupContentType.userSettings);
  bool get includeCoverCache =>
      contentTypes.contains(BackupContentType.coverCache);
  bool get includeLibraryCache =>
      contentTypes.contains(BackupContentType.libraryCache);
  bool get includeSearchIndex =>
      contentTypes.contains(BackupContentType.searchIndex);
  bool get includeWaveformCache =>
      contentTypes.contains(BackupContentType.waveformCache);
  bool get includeColorCache =>
      contentTypes.contains(BackupContentType.colorCache);
  bool get includeLyricsCache =>
      contentTypes.contains(BackupContentType.lyricsCache);
  bool get includeArtistArtCache =>
      contentTypes.contains(BackupContentType.artistArtCache);
  bool get includeAlbumArtCache =>
      contentTypes.contains(BackupContentType.albumArtCache);
}

class BackupDiff {
  final int songCountDiff;
  final int statsRowsDiff;
  final int sizeBytesDiff;

  BackupDiff({
    required this.songCountDiff,
    required this.statsRowsDiff,
    required this.sizeBytesDiff,
  });
}

class BackupInfo {
  final int number;
  final DateTime timestamp;
  final String filename;
  final File file;
  final int sizeBytes;

  BackupInfo({
    required this.number,
    required this.timestamp,
    required this.filename,
    required this.file,
    required this.sizeBytes,
  });

  String get formattedSize {
    if (sizeBytes < 1024) {
      return '${sizeBytes}B';
    }
    if (sizeBytes < 1024 * 1024) {
      return '${(sizeBytes / 1024).toStringAsFixed(1)}KB';
    }
    return '${(sizeBytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  String get displayName {
    return _formatDateTime(timestamp);
  }

  String _formatDateTime(DateTime dt) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec'
    ];
    final month = months[dt.month - 1];
    final day = dt.day;
    final year = dt.year;
    final hour = dt.hour > 12 ? dt.hour - 12 : (dt.hour == 0 ? 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final amPm = dt.hour >= 12 ? 'PM' : 'AM';

    return '$month $day, $year at $hour:$minute $amPm';
  }
}

class BackupService {
  static const String backupsDirName = 'backups';
  static const String statsDbName = 'wispie_stats.db';
  static const String dataDbName = 'wispie_data.db';
  static BackupService? _instance;
  static BackupService get instance => _instance ??= BackupService._();
  BackupService._();

  Future<Directory> get backupsDir async {
    final appDir = await getWispieHomeDirectory();
    final backupsDir = Directory(p.join(appDir.path, backupsDirName));
    if (!await backupsDir.exists()) {
      await backupsDir.create(recursive: true);
    }
    return backupsDir;
  }

  Future<List<BackupInfo>> getBackupsList() async {
    try {
      final dir = await backupsDir;
      final files = await dir
          .list()
          .where((entity) => entity is File && entity.path.endsWith('.zip'))
          .cast<File>()
          .toList();

      final backups = <BackupInfo>[];
      for (final file in files) {
        final filename = p.basename(file.path);
        final backupInfo = _parseBackupFilename(filename);
        if (backupInfo != null) {
          final stat = await file.stat();
          final number = backupInfo.keys.first;
          final timestamp = backupInfo.values.first;
          backups.add(BackupInfo(
            number: number,
            timestamp: timestamp,
            filename: filename,
            file: file,
            sizeBytes: stat.size,
          ));
        }
      }

      backups.sort((a, b) => b.number.compareTo(a.number));
      return backups;
    } catch (e) {
      debugPrint('Error getting backups list: $e');
      return [];
    }
  }

  Map<int, DateTime>? _parseBackupFilename(String filename) {
    final regex =
        RegExp(r'^(\d+)_(\d{4})_(\d{2})_(\d{2})_(\d{2})-(\d{2})\.zip$');
    final match = regex.firstMatch(filename);

    if (match == null) return null;

    try {
      final number = int.parse(match.group(1)!);
      final year = int.parse(match.group(2)!);
      final month = int.parse(match.group(3)!);
      final day = int.parse(match.group(4)!);
      final hour = int.parse(match.group(5)!);
      final minute = int.parse(match.group(6)!);

      final timestamp = DateTime(year, month, day, hour, minute);
      return {number: timestamp};
    } catch (e) {
      debugPrint('Error parsing backup filename $filename: $e');
      return null;
    }
  }

  Future<int> _getNextBackupNumber() async {
    final backups = await getBackupsList();
    if (backups.isEmpty) return 1;
    return backups.first.number + 1;
  }

  /// The content types used for automatic backups.
  /// The content types used for automatic backups.
  Future<BackupOptions> defaultBackupOptions() async {
    final types = await StorageService().loadAutoBackupContentTypes();
    return BackupOptions(contentTypes: types);
  }

  Future<Map<String, String>> _backupPaths(String appDir) async {
    final cache = WispieCache.instance;
    return {
      'stats_db': p.join(appDir, statsDbName),
      'data_db': p.join(appDir, dataDbName),
      'covers': (await cache.directory(CacheBucket.covers)).path,
      'blurred': (await cache.directory(CacheBucket.blurred)).path,
      'notification': (await cache.directory(CacheBucket.notification)).path,
      'lyrics': (await cache.directory(CacheBucket.lyrics)).path,
      'waveforms': (await cache.directory(CacheBucket.waveforms)).path,
      'palette': (await cache.paletteIndexFile()).path,
      'library': p.join(appDir, 'cached_songs.json'),
      'index': p.join(appDir, 'wispie_search_index.db'),
    };
  }

  Future<Map<String, dynamic>> _backupWorkflow(Map<String, Object?> request) =>
      compute((message) => runCoreCommand('backup_workflow', message), request);

  Future<void> _stageBackup(BackupOptions options, Directory stagingDir) async {
    final database = DatabaseService.instance;
    final storage = StorageService();
    final documents = <String, Object?>{};
    if (options.includeUserStats || options.includeUserData) {
      await database.init();
    }
    if (options.includeUserStats) {
      documents['songs'] = [
        for (final song in await database.getAllSongs()) song.toJson(),
      ];
      documents['stats'] = await database.getFunStats();
      documents['merged'] = (await database.getMergedSongGroups()).map(
        (id, group) => MapEntry(id, {
          'filenames': group.filenames,
          'priorityFilename': group.priorityFilename,
        }),
      );
      final queue = await database.exportQueueHistory();
      if (queue.isNotEmpty) documents['queue'] = queue;
    }
    if (options.includeUserData) {
      documents['user'] = await storage.loadUserData();
      documents['shuffle'] = await storage.loadShuffleState();
      documents['playback'] = await storage.loadPlaybackState();
    }
    if (options.includeUserSettings) {
      final settings = await storage.exportAppSettings();
      if (settings.isNotEmpty) documents['settings'] = settings;
    }
    await _backupWorkflow({
      'op': 'stage',
      'root': stagingDir.path,
      'selected': [for (final type in options.contentTypes) type.name],
      'paths': await _backupPaths((await getWispieDirectory()).path),
      'documents': documents,
      'exported_at': DateTime.now().toIso8601String(),
    });
  }

  Future<String> createBackup([BackupOptions? options]) async {
    options ??= await defaultBackupOptions();

    try {
      final dir = await backupsDir;
      final backupNumber = await _getNextBackupNumber();
      final now = DateTime.now();

      final backupFilename =
          '${backupNumber.toString().padLeft(3, '0')}_${now.year.toString().padLeft(4, '0')}_${now.month.toString().padLeft(2, '0')}_${now.day.toString().padLeft(2, '0')}_${now.hour.toString().padLeft(2, '0')}-${now.minute.toString().padLeft(2, '0')}.zip';
      final backupPath = p.join(dir.path, backupFilename);

      final tempDir = await Directory.systemTemp.createTemp('gru_backup_');
      final dataDir = Directory(p.join(tempDir.path, 'data'));
      await dataDir.create(recursive: true);

      try {
        await _stageBackup(options, dataDir);

        await _archiveOperation('create', dataDir.path, backupPath);

        return backupFilename;
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Error creating backup: $e');
      rethrow;
    }
  }

  Future<void> exportUserData({BackupOptions? options}) async {
    options ??= await defaultBackupOptions();

    final tempDir = await getTemporaryDirectory();
    final exportDir = await tempDir.createTemp('wispie_export_');
    final stage = Directory(p.join(exportDir.path, 'data'));
    final zipPath = p.join(exportDir.path, 'wispie_export.zip');

    try {
      await stage.create();
      await _stageBackup(options, stage);
      await _archiveOperation('create', stage.path, zipPath);

      final bytes = await File(zipPath).readAsBytes();
      final xFile = XFile.fromData(
        bytes,
        name: p.basename(zipPath),
        mimeType: 'application/zip',
      );
      await SharePlus.instance.share(
        ShareParams(files: [xFile], text: 'wispie Export'),
      );
    } finally {
      if (await exportDir.exists()) {
        await exportDir.delete(recursive: true);
      }
    }
  }

  Future<Map<String, dynamic>> _archiveOperation(String op, String source,
          [String? destination]) =>
      compute(
        (request) => runCoreCommand('backup_archive', request),
        {
          'op': op,
          'source': source,
          if (destination != null) 'destination': destination,
        },
      );

  Future<String> _extractArchive(File zipFile, Directory target) async {
    final result =
        await _archiveOperation('extract', zipFile.path, target.path);
    return result['root'] as String;
  }

  /// Prompts for a backup archive and validates it.
  ///
  /// Returns null when the user cancels the picker. The caller owns the
  /// extracted content afterwards and must pass the result to either
  /// [performImport] or [discardValidation].
  Future<Map<String, dynamic>?> pickAndValidateBackup() async {
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['zip'],
    );

    final pickedPath = picked?.path;
    if (pickedPath == null || pickedPath.isEmpty) return null;

    return validateBackupFile(File(pickedPath));
  }

  /// Extracts [file] and reports what it actually contains.
  ///
  /// Detection is authoritative: `metadata.json` is only a hint, because it can
  /// disagree with the archive (older versions, hand-edited archives).
  Future<Map<String, dynamic>> validateBackupFile(File file) async {
    final tempDir = await getTemporaryDirectory();
    final decodeDir = await tempDir.createTemp('wispie_import_');

    try {
      final contentPath = await _extractArchive(file, decodeDir);

      final contents = await _archiveOperation('inspect', contentPath);

      final cacheFlags = await _backupWorkflow({
        'op': 'cache_flags',
        'root': contentPath,
      });

      final validation = <String, dynamic>{
        'valid': true,
        'importPath': contentPath,
        'extractRoot': decodeDir.path,
        ...contents,
        'hasCoverCache': cacheFlags['coverCache'],
        'hasLibraryCache': cacheFlags['libraryCache'],
        'hasSearchIndex': cacheFlags['searchIndex'],
        'hasWaveformCache': cacheFlags['waveformCache'],
        'hasColorCache': cacheFlags['colorCache'],
        'hasLyricsCache': cacheFlags['lyricsCache'],
      };

      final hasAnything = validation.entries
          .where((e) => e.key.startsWith('has'))
          .any((e) => e.value == true);
      if (!hasAnything) {
        throw Exception('Invalid backup: no restorable content found');
      }

      return validation;
    } catch (e) {
      if (await decodeDir.exists()) await decodeDir.delete(recursive: true);
      rethrow;
    }
  }

  /// Deletes the content extracted by [validateBackupFile] when the user backs
  /// out of the import dialog.
  Future<void> discardValidation(Map<String, dynamic>? validation) async {
    final root = validation?['extractRoot'] as String?;
    if (root == null) return;
    try {
      final dir = Directory(root);
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (e) {
      debugPrint('Error cleaning up import temp files: $e');
    }
  }

  Set<ImportDataCategory> getAvailableCategories(
      Map<String, dynamic> validation) {
    final categories = <ImportDataCategory>{};

    if (validation['hasSongsJson'] == true) {
      categories.add(ImportDataCategory.songs);
    }
    if (validation['hasShuffleStateJson'] == true) {
      categories.add(ImportDataCategory.shuffleState);
    }
    if (validation['hasPlaybackStateJson'] == true) {
      categories.add(ImportDataCategory.playbackState);
    }
    if (validation['hasQueueHistoryJson'] == true) {
      categories.add(ImportDataCategory.queueHistory);
    }
    if (validation['hasAppSettingsJson'] == true) {
      categories.add(ImportDataCategory.themeSettings);
      categories.add(ImportDataCategory.scannerSettings);
      categories.add(ImportDataCategory.playbackSettings);
      categories.add(ImportDataCategory.uiSettings);
      categories.add(ImportDataCategory.backupSettings);
    }
    // Merged groups are only restorable from the database table; the JSON copy
    // is informational.
    if (validation['hasMergedGroups'] == true) {
      categories.add(ImportDataCategory.mergedGroups);
    }

    if (validation['hasFavorites'] == true) {
      categories.add(ImportDataCategory.favorites);
    }
    if (validation['hasSuggestless'] == true) {
      categories.add(ImportDataCategory.suggestless);
    }
    if (validation['hasHidden'] == true) {
      categories.add(ImportDataCategory.hidden);
    }
    if (validation['hasPlaylists'] == true) {
      categories.add(ImportDataCategory.playlists);
    }
    if (validation['hasRecommendations'] == true) {
      categories.add(ImportDataCategory.recommendations);
    }
    if (validation['hasUserdata'] == true) {
      categories.add(ImportDataCategory.userdata);
    }
    if (validation['hasPlayHistory'] == true) {
      categories.add(ImportDataCategory.playHistory);
    }

    if (validation['hasCoverCache'] == true) {
      categories.add(ImportDataCategory.coverCache);
    }
    if (validation['hasLibraryCache'] == true) {
      categories.add(ImportDataCategory.libraryCache);
    }
    if (validation['hasSearchIndex'] == true) {
      categories.add(ImportDataCategory.searchIndex);
    }
    if (validation['hasWaveformCache'] == true) {
      categories.add(ImportDataCategory.waveformCache);
    }
    if (validation['hasColorCache'] == true) {
      categories.add(ImportDataCategory.colorCache);
    }
    if (validation['hasLyricsCache'] == true) {
      categories.add(ImportDataCategory.lyricsCache);
    }

    return categories;
  }

  /// Applies every selected category from an extracted archive rooted at
  /// [importPath].
  ///
  Future<void> _applyImport({
    required String importPath,
    String? statsDbPath,
    String? dataDbPath,
    required ImportOptions options,
    List<Song>? preImportSongs,
    bool replacedDatabaseFiles = false,
    void Function(double progress, String label)? onProgress,
  }) async {
    final categories = options.categories;
    final storage = StorageService();
    List<Song>? importedRows;

    if (options.hasDatabaseCategories) {
      await DatabaseService.instance.importWithOptions(
        statsDbPath: statsDbPath,
        dataDbPath: dataDbPath,
        options: options,
      );
    }

    final documents = await _backupWorkflow({
      'op': 'read_documents',
      'root': importPath,
      'selected': [
        if (categories.contains(ImportDataCategory.songs)) 'songs',
        if (categories.contains(ImportDataCategory.shuffleState)) 'shuffle',
        if (categories.contains(ImportDataCategory.playbackState)) 'playback',
        if (categories.contains(ImportDataCategory.queueHistory)) 'queue',
        if (options.hasSettingsCategories) 'settings',
      ],
    });
    if (documents['songs'] case final List rows) {
      importedRows = [for (final row in rows) Song.fromJson(row)];
    }
    if (documents['shuffle'] case final Map state) {
      await storage.saveShuffleState(
        ShuffleState.fromJson(state.cast<String, dynamic>()).toJson(),
      );
    }
    if (documents['playback'] case final Map state) {
      await storage.savePlaybackState(state.cast<String, dynamic>());
    }
    if (documents['queue'] case final List rows) {
      await DatabaseService.instance.importQueueHistory(
        rows.cast<Map<String, dynamic>>(),
      );
    }
    if (documents['settings'] case final Map settings) {
      await storage.importSettingsWithOptions(
        settings.cast<String, dynamic>(),
        options,
      );
    }

    if (options.hasCacheCategories) {
      final wantedTypes = categories
          .map((category) => category.cacheContentType)
          .whereType<BackupContentType>()
          .toSet();
      if (wantedTypes.contains(BackupContentType.searchIndex)) {
        await SearchIndexRepository().close();
      }
      await _backupWorkflow({
        'op': 'restore_artifacts',
        'root': importPath,
        'selected': [for (final type in wantedTypes) type.name],
        'paths': await _backupPaths((await getWispieDirectory()).path),
      });
      WispieCache.instance.invalidateUsage();
    }

    // Last, so it sees the restored music folders and any covers the archive
    // brought with it. Without this the library table describes the old device
    // and nothing downstream ever notices.
    // Always runs — repair is idempotent and cheap when nothing needs changing,
    // and every import path (app data, backup restore, Namida) should reconcile
    // the library against the filesystem so orphaned paths don't accumulate.
    // The repair pass is the visible bulk of an import, but it is not the end:
    // its own progress is capped below 1 so the bar cannot read "done" while
    // identity reconciliation is still reading the library.
    await LibraryRepairService.instance.repairLibrary(
      preImportSongs: preImportSongs,
      importedRows: importedRows,
      onProgress: onProgress == null
          ? null
          : (value, label) => onProgress(value.clamp(0.0, 0.85), label),
    );

    // Backup rows are keyed by the names files had when it was taken; files
    // renamed since are matched back by audio content. That is the only thing
    // this pass can do, and it needs a name the library no longer has to do it,
    // so a restore whose names all still exist skips the read of the library
    // entirely. Nothing is lost by skipping: the pass would have moved nothing.
    if (await SongIdentityService.instance
        .hasUnmatchedNames(await DatabaseService.instance.getAllSongs())) {
      onProgress?.call(0.9, 'Matching renamed files…');
      await SongIdentityService.instance.reconcileFromLibrary();
    }
    onProgress?.call(1.0, 'Done');
  }

  /// Imports a previously validated archive, then removes the extracted copy.
  Future<void> performImport({
    required Map<String, dynamic> validation,
    required ImportOptions options,
    void Function(double progress, String label)? onProgress,
  }) async {
    try {
      // Nothing is replaced wholesale on this path, but imported rows still
      // overwrite locally-scanned ones by filename, so the local view of where
      // files and covers are has to be preserved across the merge.
      final preImportSongs =
          options.categories.contains(ImportDataCategory.songs)
              ? await DatabaseService.instance.getAllSongs()
              : null;

      await _applyImport(
        importPath: validation['importPath'] as String,
        statsDbPath: validation['statsDbPath'] as String?,
        dataDbPath: validation['dataDbPath'] as String?,
        options: options,
        preImportSongs: preImportSongs,
        onProgress: onProgress,
      );
      await _invalidateSearchIndexIfStale(options);
    } finally {
      await discardValidation(validation);
    }
  }

  /// The search index is derived from the library, so a library-changing import
  /// must drop it — unless the archive restored an index of its own.
  Future<void> _invalidateSearchIndexIfStale(ImportOptions options) async {
    final categories = options.categories;
    if (categories.contains(ImportDataCategory.searchIndex)) return;
    if (!categories.contains(ImportDataCategory.songs) &&
        !categories.contains(ImportDataCategory.libraryCache)) {
      return;
    }

    try {
      final searchIndexRepo = SearchIndexRepository();
      await searchIndexRepo.close();
      await searchIndexRepo.deleteDatabaseFile();
    } catch (e) {
      debugPrint('Note: Could not delete search index: $e');
    }
  }

  Future<void> restoreFromBackup(
    BackupInfo backupInfo, {
    ImportOptions? options,
    void Function(double progress, String label)? onProgress,
  }) async {
    final importOptions = options ?? ImportOptions.defaultImport;

    try {
      onProgress?.call(0.02, 'Extracting the archive…');
      final tempDir = await Directory.systemTemp.createTemp('gru_restore_');

      try {
        final contentPath = await _extractArchive(backupInfo.file, tempDir);

        final appDir = await getWispieDirectory();

        final contents = await _archiveOperation('inspect', contentPath);
        final statsDbPath = contents['statsDbPath'] as String?;
        final dataDbPath = contents['dataDbPath'] as String?;

        // Wholesale file replacement only makes sense when the archive
        // actually carries databases; otherwise fall through and restore the
        // JSON/settings/cache content as usual.
        var replacedDatabaseFiles = false;
        List<Song>? preImportSongs;

        if (importOptions.restoreDatabases &&
            (statsDbPath != null || dataDbPath != null)) {
          // The library table rides inside wispie_data.db and is about to be
          // overwritten by the archive's copy, taking this device's file paths
          // and extracted covers with it. No import category covers `song`, so
          // nothing else would preserve them — snapshot before the swap.
          if (dataDbPath != null) {
            try {
              preImportSongs = await DatabaseService.instance.getAllSongs();
              replacedDatabaseFiles = true;
            } catch (e) {
              debugPrint('Could not snapshot library before restore: $e');
              // Repair still runs; it just has less to merge against.
              replacedDatabaseFiles = true;
            }
          }

          await DatabaseService.instance.close();
          try {
            await _backupWorkflow({
              'op': 'restore_databases',
              'root': contentPath,
              'paths': {
                'stats_db': p.join(appDir.path, statsDbName),
                'data_db': p.join(appDir.path, dataDbName),
              },
              'sources': {
                if (statsDbPath != null) 'stats_db': statsDbPath,
                if (dataDbPath != null) 'data_db': dataDbPath,
              },
            });
          } finally {
            await DatabaseService.instance.init();
          }
        }

        onProgress?.call(0.08, 'Replacing local data…');

        await _applyImport(
          importPath: contentPath,
          statsDbPath: statsDbPath,
          dataDbPath: dataDbPath,
          options: importOptions,
          preImportSongs: preImportSongs,
          replacedDatabaseFiles: replacedDatabaseFiles,
          onProgress: onProgress,
        );

        onProgress?.call(0.97, 'Rebuilding the search index…');
        await _invalidateSearchIndexIfStale(importOptions);
        onProgress?.call(1.0, 'Done');
      } finally {
        if (await tempDir.exists()) {
          await tempDir.delete(recursive: true);
        }
      }
    } catch (e) {
      debugPrint('Error restoring from backup: $e');
      rethrow;
    }
  }

  Future<void> deleteBackup(BackupInfo backupInfo) async {
    try {
      if (await backupInfo.file.exists()) {
        await backupInfo.file.delete();
      }
    } catch (e) {
      debugPrint('Error deleting backup: $e');
      rethrow;
    }
  }

  Future<BackupDiff> compareBackups(
      BackupInfo oldBackup, BackupInfo newBackup) async {
    final tempDir = await Directory.systemTemp.createTemp('gru_compare_');
    try {
      final oldStats =
          await _archiveOperation('counts', oldBackup.file.path, tempDir.path);
      final newStats =
          await _archiveOperation('counts', newBackup.file.path, tempDir.path);
      return BackupDiff(
        songCountDiff: (newStats['songs'] as int) - (oldStats['songs'] as int),
        statsRowsDiff:
            (newStats['playevents'] as int) - (oldStats['playevents'] as int),
        sizeBytesDiff: newBackup.sizeBytes - oldBackup.sizeBytes,
      );
    } finally {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    }
  }

  Future<void> exportBackup(BackupInfo backupInfo, String exportPath) async {
    try {
      if (await backupInfo.file.exists()) {
        await backupInfo.file.copy(exportPath);
      }
    } catch (e) {
      debugPrint('Error exporting backup: $e');
      rethrow;
    }
  }
}
