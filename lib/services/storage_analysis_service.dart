import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:path/path.dart' as p;
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/services/cache_policy.dart';
import 'backup_service.dart';
import 'cover_refresh_service.dart';
import 'database_service.dart';
import 'online_audio_cache.dart';
import 'wispie_cache.dart';
import 'wispie_paths.dart';

/// Sizes and destructive actions behind the storage screen.
///
/// All cache figures come from one [WispieCache] scan, so no bucket is counted
/// twice and an empty card really means empty.
class StorageAnalysisService {
  static final StorageAnalysisService instance = StorageAnalysisService._();
  StorageAnalysisService._();

  Future<int> getDatabaseSize() async {
    try {
      final docDir = await getWispieDirectory();
      var total = 0;
      for (final name in ['wispie_stats', 'wispie_data']) {
        for (final suffix in ['', '-journal', '-wal', '-shm']) {
          final file = File(p.join(docDir.path, '$name$suffix'));
          if (await file.exists()) total += await file.length();
        }
      }
      return total;
    } catch (error) {
      debugPrint('Error calculating database size: $error');
      return 0;
    }
  }

  Future<int> getBackupsSize() async {
    try {
      final dir = await BackupService.instance.backupsDir;
      var total = 0;
      await for (final entity in dir.list(recursive: true)) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } catch (error) {
      debugPrint('Error calculating backups size: $error');
      return 0;
    }
  }

  Future<int> getSearchIndexSize() async {
    for (final suffix in ['', '-journal', '-wal', '-shm']) {
      try {
        final docDir = await getWispieDirectory();
        final file = File(p.join(docDir.path, 'wispie_search_index.db$suffix'));
        if (await file.exists()) return await file.length();
      } catch (error) {
        debugPrint('Error calculating search index size: $error');
      }
    }
    return 0;
  }

  Future<CacheUsage> getCacheUsage({bool refresh = false}) =>
      WispieCache.instance.usage(refresh: refresh);

  /// Empties one cache bucket, keeping anything the user owns intact.
  Future<void> clearBucket(CacheBucket bucket) async {
    if (bucket == CacheBucket.onlineAudio) {
      await OnlineAudioCache.instance.clear();
      WispieCache.instance.invalidateUsage();
      return;
    }

    await WispieCache.instance.clearBucket(bucket);

    if (bucket == CacheBucket.covers) {
      // Rows still point at the files just deleted; null them so the lazy
      // extraction path refills them instead of drawing holes forever.
      await DatabaseService.instance.clearCoverUrls();
      await DatabaseService.instance.clearAllCoverMisses();
      CoverRefreshService.instance.invalidateMisses();
      _clearDecodedImageCache();
    }
  }

  /// Prunes orphans, empty files and over-budget buckets.
  Future<CacheMaintenanceReport> cleanUp() async {
    final report = await WispieCache.instance.runMaintenance(force: true);
    _clearDecodedImageCache();
    return report;
  }

  Future<void> clearWispieCache() async {
    await WispieCache.instance.clearCache();
    _clearDecodedImageCache();
  }

  /// Drops decoded bitmaps so freshly re-extracted covers aren't masked by the
  /// old ones still held against the same paths.
  void _clearDecodedImageCache() {
    try {
      PaintingBinding.instance.imageCache.clear();
      PaintingBinding.instance.imageCache.clearLiveImages();
    } catch (_) {
      // No binding (probes): nothing decoded to drop.
    }
  }

  Future<void> clearBackups() async {
    try {
      final dir = await BackupService.instance.backupsDir;
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
    } catch (error) {
      debugPrint('Error clearing backups: $error');
      rethrow;
    }
  }

  Future<void> clearSearchIndex() async {
    try {
      final docDir = await getWispieDirectory();
      for (final suffix in ['', '-journal', '-wal', '-shm']) {
        final file = File(p.join(docDir.path, 'wispie_search_index.db$suffix'));
        if (await file.exists()) await file.delete();
      }
    } catch (error) {
      debugPrint('Error clearing search index: $error');
      rethrow;
    }
  }

  /// Clears the databases. The cache is left to the next maintenance pass.
  Future<void> clearDatabase() async {
    try {
      await DatabaseService.instance.close();
      final docDir = await getWispieDirectory();
      for (final name in ['wispie_stats', 'wispie_data']) {
        for (final suffix in ['', '-journal', '-wal', '-shm']) {
          final file = File(p.join(docDir.path, '$name$suffix'));
          if (await file.exists()) await file.delete();
        }
      }
    } catch (error) {
      debugPrint('Error clearing database: $error');
      rethrow;
    }
  }

  Future<void> clearAllUserData() async {
    try {
      await DatabaseService.instance.close();
      await clearDatabase();
      await clearWispieCache();
      await WispieCache.instance.clearBucket(CacheBucket.palettes);
      await clearBackups();
      await clearSearchIndex();
      await OnlineAudioCache.instance.clear();

      final prefs = await SharedPreferences.getInstance();
      await prefs.clear();
    } catch (error) {
      debugPrint('Error clearing user data: $error');
      rethrow;
    }
  }
}
