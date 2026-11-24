import 'dart:io';
import '../data/rust/native_database.dart';
import 'sync/hlc.dart';
import 'sync_service.dart';
import 'package:path/path.dart';
import 'package:flutter/foundation.dart';
import '../domain/services/search_service.dart';
import '../models/song.dart';
import '../services/scanner_service.dart';
import '../services/database_service.dart';
import '../services/wispie_paths.dart';

/// Available optimization types for database maintenance
enum OptimizationType {
  statsDatabase,
  userDataDatabase,
  coverCache,
  searchIndex,
}

/// Configuration for selective database optimization
class OptimizationOptions {
  final bool automaticMode;
  final Set<OptimizationType> selectedTypes;

  const OptimizationOptions({
    this.automaticMode = true,
    this.selectedTypes = const {},
  });

  bool isEnabled(OptimizationType type) {
    return automaticMode || selectedTypes.contains(type);
  }
}

/// Result of a database optimization operation
class OptimizationResult {
  final bool success;
  final String message;
  final Map<String, dynamic> details;
  final List<String> issuesFound;
  final List<String> fixesApplied;

  OptimizationResult({
    required this.success,
    required this.message,
    this.details = const {},
    this.issuesFound = const [],
    this.fixesApplied = const [],
  });
}

/// Service for optimizing and repairing database files
///
/// This service handles database maintenance tasks:
/// - Vacuum databases to reclaim space
/// - Fix orphaned records
/// - Remove duplicate entries
/// - Rebuild cover and search index caches
class DatabaseOptimizerService {
  static final DatabaseOptimizerService _instance =
      DatabaseOptimizerService._internal();
  factory DatabaseOptimizerService() => _instance;
  DatabaseOptimizerService._internal();

  /// Analyzes and optimizes database files based on selected options
  Future<OptimizationResult> optimizeDatabases({
    OptimizationOptions options = const OptimizationOptions(),
    void Function(String message, double progress)? onProgress,
  }) async {
    final issuesFound = <String>[];
    final fixesApplied = <String>[];
    final details = <String, dynamic>{};

    try {
      final wispieDir = await getWispieDirectory();
      final statsDbPath = join(wispieDir.path, 'wispie_stats.db');
      final userDataDbPath = join(wispieDir.path, 'wispie_data.db');

      // Calculate total steps and progress increments
      final enabledTypes = <OptimizationType>[];
      if (options.isEnabled(OptimizationType.statsDatabase)) {
        enabledTypes.add(OptimizationType.statsDatabase);
      }
      if (options.isEnabled(OptimizationType.userDataDatabase)) {
        enabledTypes.add(OptimizationType.userDataDatabase);
      }
      if (options.isEnabled(OptimizationType.coverCache)) {
        enabledTypes.add(OptimizationType.coverCache);
      }
      if (options.isEnabled(OptimizationType.searchIndex)) {
        enabledTypes.add(OptimizationType.searchIndex);
      }

      if (enabledTypes.isEmpty) {
        return OptimizationResult(
          success: true,
          message: 'No optimizations selected.',
          details: details,
          issuesFound: issuesFound,
          fixesApplied: fixesApplied,
        );
      }

      final totalSteps = enabledTypes.length;
      var currentStep = 0;

      // Optimize stats database (vacuum, remove short sessions/followups)
      if (options.isEnabled(OptimizationType.statsDatabase)) {
        currentStep++;
        final progress = currentStep / totalSteps;
        onProgress?.call('Optimizing stats database...', progress);
        final statsResult = await _optimizeStatsDatabase(statsDbPath);
        issuesFound.addAll(statsResult['issues'] as List<String>);
        fixesApplied.addAll(statsResult['fixes'] as List<String>);
        details['stats_db'] = statsResult['details'];
      }

      // Optimize user data database (orphans, duplicates, vacuum)
      if (options.isEnabled(OptimizationType.userDataDatabase)) {
        currentStep++;
        final progress = currentStep / totalSteps;
        onProgress?.call('Optimizing user data database...', progress);
        final userDataResult = await _optimizeUserDataDatabase(userDataDbPath);
        issuesFound.addAll(userDataResult['issues'] as List<String>);
        fixesApplied.addAll(userDataResult['fixes'] as List<String>);
        details['user_data_db'] = userDataResult['details'];
      }

      // Rebuild cover caches
      if (options.isEnabled(OptimizationType.coverCache)) {
        currentStep++;
        var progress = currentStep / totalSteps;
        onProgress?.call('Preparing to rebuild cover cache...', progress);
        try {
          final songs = await DatabaseService.instance.getAllSongs();

          if (songs.isNotEmpty) {
            final scanner = ScannerService();
            // Force rebuild when not in automatic mode
            final coverMap = await scanner.rebuildCoverCache(
              songs,
              onProgress: (p) {
                onProgress?.call('Rebuilding covers... ${(p * 100).toInt()}%',
                    progress + (p * (1 / totalSteps)));
              },
              force: !options.automaticMode,
            );

            // Update stored songs with the actual cover URLs from the rebuild
            onProgress?.call('Updating song cover references...',
                progress + (0.8 * (1 / totalSteps)));
            int coversUpdated = 0;
            final updatedSongs = songs.map((song) {
              // A song missing from the map is one the rebuild couldn't read,
              // not one without art — its existing cover stands.
              final newCoverUrl = coverMap[song.url];
              if (newCoverUrl != null && newCoverUrl != song.coverUrl) {
                coversUpdated++;
                return Song(
                  title: song.title,
                  artist: song.artist,
                  album: song.album,
                  filename: song.filename,
                  url: song.url,
                  coverUrl: newCoverUrl,
                  hasLyrics: song.hasLyrics,
                  playCount: song.playCount,
                  duration: song.duration,
                  mtime: song.mtime,
                  createdEpochSec: song.createdEpochSec,
                  songDateEpochSec: song.songDateEpochSec,
                );
              }
              return song;
            }).toList();

            await DatabaseService.instance.insertSongsBatch(updatedSongs);

            fixesApplied.add('Rebuilt cover cache for ${songs.length} songs');
            if (coversUpdated > 0) {
              fixesApplied.add('Updated $coversUpdated song cover references');
            }
            details['covers_rebuilt'] = songs.length;
            details['covers_updated'] = coversUpdated;
          }
        } catch (e) {
          issuesFound.add('Error rebuilding covers: $e');
          debugPrint('Error rebuilding covers: $e');
        }
      }

      // Optimize/rebuild search index
      if (options.isEnabled(OptimizationType.searchIndex)) {
        currentStep++;
        final progress = currentStep / totalSteps;
        onProgress?.call('Optimizing search index...', progress);
        final searchIndexResult = await _optimizeSearchIndex();
        issuesFound.addAll(searchIndexResult['issues'] as List<String>);
        fixesApplied.addAll(searchIndexResult['fixes'] as List<String>);
        details['search_index'] = searchIndexResult['details'];
      }

      onProgress?.call('Finalizing...', 1.0);

      final success = issuesFound.isEmpty || fixesApplied.isNotEmpty;
      final message = success
          ? 'Database optimization completed successfully. ${fixesApplied.length} fixes applied.'
          : 'Database optimization found issues but could not fix all of them.';

      return OptimizationResult(
        success: success,
        message: message,
        details: details,
        issuesFound: issuesFound,
        fixesApplied: fixesApplied,
      );
    } catch (e) {
      return OptimizationResult(
        success: false,
        message: 'Database optimization failed: $e',
        issuesFound: issuesFound,
        fixesApplied: fixesApplied,
        details: details,
      );
    }
  }

  /// Optimizes the stats database (playevent table)
  /// Uses DatabaseService singleton for operations, separate connection only for VACUUM
  Future<Map<String, dynamic>> _optimizeStatsDatabase(String dbPath) async {
    final issues = <String>[];
    final fixes = <String>[];
    final details = <String, dynamic>{};

    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      details['exists'] = false;
      return {'issues': issues, 'fixes': fixes, 'details': details};
    }

    try {
      // Ensure DatabaseService is initialized before proceeding
      try {
        await DatabaseService.instance.ensureInitialized();
      } catch (e) {
        issues.add('DatabaseService not initialized: $e');
        return {'issues': issues, 'fixes': fixes, 'details': details};
      }

      // Run integrity check via separate connection (safer for diagnostics)
      Database? checkDb;
      try {
        checkDb = await openDatabase(dbPath, readOnly: true);
        final result =
            await checkDb.coreCommand('maintenance', {'op': 'integrity'});
        final isOk = result['ok'] == true;

        if (!isOk) {
          issues.add('Stats database integrity check failed');
          fixes.add(
              'Stats database integrity issues detected (manual intervention may be needed)');
        }
        await checkDb.close();
        checkDb = null;
      } catch (e) {
        issues.add('Could not check database integrity: $e');
        await checkDb?.close();
      }

      // Delete tiny immediate follow-up events after near-full repeats
      final shortFollowUpResult = await _deleteShortFollowUpsViaService();
      if (shortFollowUpResult['deleted'] > 0) {
        fixes.add(
            'Deleted ${shortFollowUpResult['deleted']} tiny immediate follow-up play events');
      }
      details['short_followups_cleanup'] = shortFollowUpResult['details'];

      // Delete sessions under 1 minute
      final shortSessionsResult = await _deleteShortSessionsViaService();
      if (shortSessionsResult['deletedSessions'] > 0) {
        fixes.add(
            'Deleted ${shortSessionsResult['deletedSessions']} sessions under 1 minute');
      }
      if (shortSessionsResult['deletedEvents'] > 0) {
        fixes.add(
            'Deleted ${shortSessionsResult['deletedEvents']} associated/orphaned play events');
      }
      details['short_sessions_cleanup'] = shortSessionsResult['details'];

      // Vacuum requires exclusive access - use separate connection
      Database? vacuumDb;
      try {
        vacuumDb = await openDatabase(dbPath);
        await vacuumDb.coreCommand('maintenance', {'op': 'vacuum'});
        fixes.add('Vacuumed stats database');
        details['vacuumed'] = true;
      } catch (e) {
        issues.add('Error vacuuming stats database: $e');
        details['vacuumed'] = false;
      } finally {
        await vacuumDb?.close();
      }
    } catch (e) {
      issues.add('Error optimizing stats database: $e');
    }

    return {'issues': issues, 'fixes': fixes, 'details': details};
  }

  /// Deletes sessions shorter than 60 seconds and their associated events via DatabaseService
  Future<Map<String, dynamic>> _deleteShortSessionsViaService() async {
    final statsDb = DatabaseService.instance.getStatsDatabase();
    if (statsDb == null) {
      return {
        'deletedSessions': 0,
        'deletedEvents': 0,
        'details': {'error': 'Stats database not available'}
      };
    }
    return await _deleteShortSessions(statsDb);
  }

  Future<Map<String, dynamic>> _deleteShortSessions(
    Database statsDb, {
    double minDurationSeconds = 60.0,
  }) async {
    try {
      final result = await statsDb.coreCommand('maintenance', {
        'op': 'short_sessions',
        'minimum': minDurationSeconds,
        'hlc': Hlc.instance.now(),
      });
      if ((result['deletedEvents'] as int) +
              (result['deletedSessions'] as int) >
          0) {
        SyncService.instance.notifyLocalWrite();
      }
      return result;
    } catch (e) {
      debugPrint('Error deleting short sessions: $e');
      return {
        'deletedSessions': 0,
        'deletedEvents': 0,
        'details': {'error': e.toString()}
      };
    }
  }

  /// Deletes tiny immediate follow-up events after near-full/multi-full plays via DatabaseService.
  Future<Map<String, dynamic>> _deleteShortFollowUpsViaService() async {
    final statsDb = DatabaseService.instance.getStatsDatabase();
    if (statsDb == null) {
      return {
        'deleted': 0,
        'details': {'error': 'Stats database not available'}
      };
    }
    return await _deleteShortFollowUps(statsDb);
  }

  /// Deletes tiny immediate follow-up events after near-full/multi-full plays.
  Future<Map<String, dynamic>> _deleteShortFollowUps(Database statsDb) async {
    try {
      final result = await statsDb.coreCommand('maintenance', {
        'op': 'followups',
        'hlc': Hlc.instance.now(),
      });
      if ((result['deleted'] as int) > 0) {
        SyncService.instance.notifyLocalWrite();
      }
      return result;
    } catch (e) {
      debugPrint('Error deleting tiny short follow-up events: $e');
      return {
        'deleted': 0,
        'details': {'error': e.toString()}
      };
    }
  }

  /// Optimizes the user data database (orphaned records, duplicates, vacuum)
  /// Uses DatabaseService singleton for operations, separate connection only for integrity check and VACUUM
  Future<Map<String, dynamic>> _optimizeUserDataDatabase(String dbPath) async {
    final issues = <String>[];
    final fixes = <String>[];
    final details = <String, dynamic>{};

    // Ensure DatabaseService is initialized
    try {
      await DatabaseService.instance.ensureInitialized();
    } catch (e) {
      issues.add('DatabaseService not initialized: $e');
      return {'issues': issues, 'fixes': fixes, 'details': details};
    }

    final dbFile = File(dbPath);
    if (!await dbFile.exists()) {
      // Database doesn't exist - DatabaseService will create it on init
      fixes.add('User data database will be created by DatabaseService');
      details['created_new'] = true;
      return {'issues': issues, 'fixes': fixes, 'details': details};
    }

    // Run integrity check via separate connection (safer for diagnostics)
    Database? checkDb;
    try {
      checkDb = await openDatabase(dbPath, readOnly: true);
      final result =
          await checkDb.coreCommand('maintenance', {'op': 'integrity'});
      final isOk = result['ok'] == true;

      if (!isOk) {
        issues.add('User data database integrity check failed');
        await checkDb.close();
        // Recover by backing up and creating new
        await _recoverCorruptedUserDataDatabase(dbPath);
        fixes.add('Recovered corrupted user data database (backup created)');
        details['recovered'] = true;
        return {'issues': issues, 'fixes': fixes, 'details': details};
      }
      await checkDb.close();
      checkDb = null;
    } catch (e) {
      issues.add('Could not check database integrity: $e');
      await checkDb?.close();
    }

    try {
      // Get the user data database from the singleton
      final userDataDb = DatabaseService.instance.getUserDataDatabase();
      if (userDataDb == null) {
        issues.add('User data database not available through DatabaseService');
        return {'issues': issues, 'fixes': fixes, 'details': details};
      }

      // Step 1: Fix orphaned records
      final orphanResult = await _fixOrphanedRecords(userDataDb);
      if (orphanResult['issuesFound'] > 0) {
        issues.add('Found ${orphanResult['issuesFound']} orphaned records');
        fixes.add('Removed ${orphanResult['issuesFixed']} orphaned records');
      }
      details['orphaned_records'] = orphanResult;

      // Step 2: Fix duplicate entries
      final duplicateResult = await _fixDuplicateRecords(userDataDb);
      if (duplicateResult['issuesFound'] > 0) {
        issues.add('Found ${duplicateResult['issuesFound']} duplicate entries');
        fixes
            .add('Removed ${duplicateResult['issuesFixed']} duplicate entries');
      }
      details['duplicates'] = duplicateResult;

      // Step 3: Vacuum requires exclusive access - use separate connection
      Database? vacuumDb;
      try {
        vacuumDb = await openDatabase(dbPath);
        await vacuumDb.coreCommand('maintenance', {'op': 'vacuum'});
        fixes.add('Vacuumed user data database');
        details['vacuumed'] = true;
      } catch (e) {
        issues.add('Error vacuuming user data database: $e');
        details['vacuumed'] = false;
      } finally {
        await vacuumDb?.close();
      }
    } catch (e) {
      issues.add('Error optimizing user data database: $e');
    }

    return {'issues': issues, 'fixes': fixes, 'details': details};
  }

  Future<Map<String, dynamic>> _fixOrphanedRecords(Database db) =>
      _repairUserData(db, 'orphans');

  Future<Map<String, dynamic>> _fixDuplicateRecords(Database db) =>
      _repairUserData(db, 'duplicates');

  Future<Map<String, dynamic>> _repairUserData(Database db, String op) async {
    try {
      return await db.coreCommand('maintenance', {'op': op});
    } catch (e) {
      debugPrint('Error repairing database ($op): $e');
      return {'issuesFound': 0, 'issuesFixed': 0};
    }
  }

  /// Recovers a corrupted user data database by backing it up and creating a new one
  Future<void> _recoverCorruptedUserDataDatabase(String dbPath) async {
    final backupPath =
        '$dbPath.corrupted.${DateTime.now().millisecondsSinceEpoch}';
    final database = DatabaseService.instance;
    await database.close();
    try {
      await databaseFileCommand('quarantine', dbPath, destination: backupPath);
    } finally {
      await database.init();
      await SyncService.instance.rebuildAfterDatabaseReplace();
    }

    debugPrint(
        'Recovered user data database. Corrupted file backed up to $backupPath');
  }

  /// Optimizes the search index by rebuilding it from cached songs
  Future<Map<String, dynamic>> _optimizeSearchIndex() async {
    final issues = <String>[];
    final fixes = <String>[];
    final details = <String, dynamic>{};

    try {
      // Ensure DatabaseService is initialized before loading songs
      try {
        await DatabaseService.instance.ensureInitialized();
      } catch (e) {
        issues.add(
            'DatabaseService not initialized when optimizing search index: $e');
        return {'issues': issues, 'fixes': fixes, 'details': details};
      }

      // Load cached songs
      final songs = await DatabaseService.instance.getAllSongs();

      if (songs.isEmpty) {
        issues.add('No songs found to build search index');
        details['songs_count'] = 0;
        return {'issues': issues, 'fixes': fixes, 'details': details};
      }

      details['songs_count'] = songs.length;

      // Initialize and rebuild search index
      final searchService = SearchService();
      await searchService.init();

      final startTime = DateTime.now();
      await searchService.rebuildIndex(songs);
      final duration = DateTime.now().difference(startTime);

      final stats = await searchService.getIndexStats();

      fixes.add(
          'Rebuilt search index with ${songs.length} songs in ${duration.inMilliseconds}ms');
      details['index_entries'] = stats.totalEntries;
      details['entries_with_lyrics'] = stats.entriesWithLyrics;
      details['rebuild_duration_ms'] = duration.inMilliseconds;
    } catch (e) {
      issues.add('Error optimizing search index: $e');
      debugPrint('Error optimizing search index: $e');
    }

    return {'issues': issues, 'fixes': fixes, 'details': details};
  }

  /// Re-index all search data without full database optimization
  Future<OptimizationResult> reindexSearchOnly() async {
    final issuesFound = <String>[];
    final fixesApplied = <String>[];
    final details = <String, dynamic>{};

    try {
      // Only rebuild search index
      final searchIndexResult = await _optimizeSearchIndex();
      issuesFound.addAll(searchIndexResult['issues'] as List<String>);
      fixesApplied.addAll(searchIndexResult['fixes'] as List<String>);
      details['search_index'] = searchIndexResult['details'];

      final success = issuesFound.isEmpty || fixesApplied.isNotEmpty;
      final message = success
          ? 'Search re-indexing completed successfully. ${fixesApplied.length} operations performed.'
          : 'Search re-indexing found issues but could not complete all operations.';

      return OptimizationResult(
        success: success,
        message: message,
        details: details,
        issuesFound: issuesFound,
        fixesApplied: fixesApplied,
      );
    } catch (e) {
      return OptimizationResult(
        success: false,
        message: 'Search re-indexing failed: $e',
        issuesFound: issuesFound,
        fixesApplied: fixesApplied,
        details: details,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Test-visible wrappers (internal use only)
  // ---------------------------------------------------------------------------

  @visibleForTesting
  Future<Map<String, dynamic>> fixOrphanedRecordsForTest(Database db) =>
      _fixOrphanedRecords(db);

  @visibleForTesting
  Future<Map<String, dynamic>> fixDuplicateRecordsForTest(Database db) =>
      _fixDuplicateRecords(db);

  @visibleForTesting
  Future<Map<String, dynamic>> deleteShortSessionsForTest(
    Database statsDb, {
    double minDurationSeconds = 60.0,
  }) =>
      _deleteShortSessions(statsDb, minDurationSeconds: minDurationSeconds);

  @visibleForTesting
  Future<Map<String, dynamic>> deleteShortFollowUpsForTest(Database statsDb) =>
      _deleteShortFollowUps(statsDb);
}
