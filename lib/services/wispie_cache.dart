// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../domain/models/cover_key.dart';
import '../domain/services/cache_migration.dart';
import '../domain/services/cache_policy.dart';
import '../models/song.dart';
import 'color_extraction_service.dart';
import 'database_service.dart';
import 'debug_sandbox.dart';
import 'wispie_paths.dart';

/// The one owner of disk cache: layout, sizes, pruning and eviction.
///
/// Every derived file the app writes (waveforms, beat maps, blurred backdrops,
/// notification art, lyrics, downloaded artwork, InnerTube responses) lives
/// under one root, in one bucket per kind. Sizes are reported from a single
/// scan, orphans are pruned against the library, and each bucket is trimmed to
/// its own budget so one runaway kind cannot evict another.
class WispieCache {
  WispieCache._();

  static final WispieCache instance = WispieCache._();

  static const String rootDirName = 'wispie_cache';
  static const String coverDirName = 'extracted_covers';
  static const String onlineAudioDirName = 'online_audio';

  static const String _maintenanceAtKey = 'wispie_cache_maintenance_at';
  static const String _layoutVersionKey = 'wispie_cache_layout_version';
  static const String _maintenancePendingKey =
      'wispie_cache_maintenance_pending';
  static const Duration maintenanceInterval = Duration(days: 1);

  /// Trimming to 80% of budget keeps a fresh write from immediately re-triggering
  /// a sweep.
  static const int _trimNumerator = 4;
  static const int _trimDenominator = 5;

  late Directory _support;
  late Directory _root;
  Directory? _notificationDir;

  bool _ready = false;
  Future<void>? _initializing;
  CacheUsage? _usage;
  Future<CacheUsage>? _usageInFlight;
  Future<CacheMaintenanceReport>? _maintenance;
  int _notificationGeneration = 0;

  bool get isReady => _ready;

  /// Bumped whenever cached notification art disappears behind a caller's back.
  int get notificationGeneration => _notificationGeneration;

  Future<void> init() {
    if (_ready) return Future<void>.value();
    return _initializing ??= _initialize().whenComplete(() {
      _initializing = null;
    });
  }

  Future<void> _initialize() async {
    try {
      _support = await getSupportDirectory();
      _root = Directory(p.join(_support.path, rootDirName));
      await _root.create(recursive: true);
    } catch (error) {
      debugPrint('WispieCache: no writable cache root: $error');
      _root = Directory(p.join(Directory.systemTemp.path, rootDirName));
      _support = _root;
    }

    try {
      for (final bucket in CacheBucket.values) {
        if (bucket == CacheBucket.covers || bucket == CacheBucket.onlineAudio) {
          continue;
        }
        await _dirFor(bucket).create(recursive: true);
      }
      await _migrateLegacyLayout();
      await _wipeScratch();
      await _ensureUserFolders();
    } catch (error) {
      debugPrint('WispieCache: init cleanup failed: $error');
    } finally {
      _ready = true;
    }
  }

  /// Absolute directory for [bucket], created on first use.
  Future<Directory> directory(CacheBucket bucket) async {
    await init();
    return _ensureDir(bucket);
  }

  Future<Directory> _ensureDir(CacheBucket bucket) async {
    final dir = _dirFor(bucket);
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  Directory _dirFor(CacheBucket bucket) {
    switch (bucket) {
      case CacheBucket.covers:
        return Directory(p.join(_support.path, coverDirName));
      case CacheBucket.onlineAudio:
        return Directory(p.join(_support.path, onlineAudioDirName));
      default:
        return Directory(p.join(_root.path, bucket.dirName));
    }
  }

  // ------------------------------------------------------------- song files --

  Future<File> waveformFile(String songFilename) async => File(p.join(
      (await directory(CacheBucket.waveforms)).path,
      waveformCacheName(songFilename)));

  Future<File> beatMapFile(String songFilename) async => File(p.join(
      (await directory(CacheBucket.beatMaps)).path,
      beatMapCacheName(songFilename)));

  Future<File> blurredFile(String songFilename) async => File(p.join(
      (await directory(CacheBucket.blurred)).path,
      blurredCacheName(songFilename)));

  Future<File> remoteLyricsFile(String songFilename) async => File(p.join(
      (await directory(CacheBucket.lyrics)).path,
      remoteLyricsCacheName(songFilename)));

  Future<File> richLyricsFile(String songFilename) async => File(p.join(
      (await directory(CacheBucket.lyrics)).path,
      richLyricsCacheName(songFilename)));

  Future<File> songLyricsFile(String url) async => File(p.join(
      (await directory(CacheBucket.lyrics)).path, songLyricsCacheName(url)));

  Future<File> remoteArtFile(String url) async => File(p.join(
      (await directory(CacheBucket.remoteArt)).path, remoteArtCacheName(url)));

  Future<File> paletteIndexFile() async => File(
      p.join((await directory(CacheBucket.palettes)).path, paletteIndexName));

  /// Media proxies are scratch: valid only for the run that wrote them.
  Future<Directory> proxyDirectory() => directory(CacheBucket.iosProxies);

  /// Decode scratch space for waveform/beat analysis.
  Future<Directory> scratchDirectory() => directory(CacheBucket.scratch);

  // -------------------------------------------------------- notification art --

  Future<Directory> notificationCoverDirectory() async {
    final cached = _notificationDir;
    if (cached != null) return cached;
    final dir = await directory(CacheBucket.notification);
    return _notificationDir = dir;
  }

  /// For synchronous callers with a fallback that must not await.
  Directory? notificationCoverDirectorySync() => _notificationDir;

  Future<File> notificationCoverFile(String coverKey) async =>
      File(p.join((await notificationCoverDirectory()).path, '$coverKey.jpg'));

  Future<void> invalidateNotificationCover(String cacheKey) async {
    try {
      final file = await notificationCoverFile(cacheKey);
      if (await file.exists()) await file.delete();
      _notificationGeneration++;
      _usage = null;
    } catch (_) {
      // A cover we cannot delete is refreshed by the next full prune.
    }
  }

  Future<void> invalidateBlurred(String songFilename) async {
    try {
      final file = await blurredFile(songFilename);
      if (await file.exists()) await file.delete();
      _usage = null;
    } catch (_) {
      // A stale blur is harmless.
    }
  }

  // ---------------------------------------------------------------- reporting --

  /// Per-bucket sizes, cached until something clears or prunes.
  Future<CacheUsage> usage({bool refresh = false}) async {
    await init();
    if (!refresh) {
      final cached = _usage;
      if (cached != null) return cached;
      final inFlight = _usageInFlight;
      if (inFlight != null) return inFlight;
    }

    final future = _measure();
    _usageInFlight = future;
    try {
      return await future;
    } finally {
      if (identical(_usageInFlight, future)) _usageInFlight = null;
    }
  }

  Future<CacheUsage> _measure() async {
    final paths = <int, String>{
      for (final bucket in CacheBucket.values)
        bucket.index: _dirFor(bucket).path,
    };
    final raw = await Isolate.run(() => _scanUsage(paths));
    final buckets = <CacheBucket, CacheBucketUsage>{};
    for (final bucket in CacheBucket.values) {
      final entry = raw[bucket.index];
      buckets[bucket] = CacheBucketUsage(
        files: entry == null ? 0 : entry[0],
        bytes: entry == null ? 0 : entry[1],
      );
    }
    final usage = CacheUsage(buckets);
    _usage = usage;
    return usage;
  }

  void invalidateUsage() => _usage = null;

  // ------------------------------------------------------------- maintenance --

  /// Called on every launch; sweeps at most once a day unless the library
  /// changed or [force] is set.
  Future<CacheMaintenanceReport> runMaintenance({bool force = false}) {
    return _maintenance ??=
        _maintenanceRun(force: force).whenComplete(() => _maintenance = null);
  }

  Future<CacheMaintenanceReport> _maintenanceRun({required bool force}) async {
    await init();
    if (!force && !await _isDue()) return const CacheMaintenanceReport();

    var report = const CacheMaintenanceReport();
    try {
      final songs = await DatabaseService.instance.getSongs();
      if (songs.isNotEmpty) {
        report = await prune(
          songs: songs,
          extraCoverPaths: await _artistAlbumCoverPaths(),
        );
      }
    } catch (error) {
      debugPrint('WispieCache: prune failed: $error');
    }

    await _wipeScratch();
    await _ensureUserFolders();

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(
          _maintenanceAtKey, DateTime.now().millisecondsSinceEpoch);
      await prefs.setBool(_maintenancePendingKey, false);
    } catch (_) {}

    return report;
  }

  Future<bool> _isDue() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool(_maintenancePendingKey) ?? false) return true;
      final last = prefs.getInt(_maintenanceAtKey) ?? 0;
      if (last == 0) return true;
      return DateTime.now().millisecondsSinceEpoch - last >=
          maintenanceInterval.inMilliseconds;
    } catch (_) {
      return false;
    }
  }

  /// Ask for a sweep on the next launch: the library's identity changed.
  Future<void> markLibraryChanged() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_maintenancePendingKey, true);
    } catch (error) {
      debugPrint('WispieCache: could not mark maintenance pending: $error');
    }
  }

  Future<Set<String>> _artistAlbumCoverPaths() async {
    try {
      final artistArt = await DatabaseService.instance.getArtistArtMap();
      final albumArt = await DatabaseService.instance.getAlbumArtMap();
      return {
        ...artistArt.values.where((path) => path.isNotEmpty),
        ...albumArt.values.where((path) => path.isNotEmpty),
      };
    } catch (_) {
      return const {};
    }
  }

  /// Deletes cache files no song refers to, then trims over-budget buckets.
  ///
  /// The keep-set is built from `song.coverUrl` and the library, so it must not
  /// run while those paths are untrustworthy (after a restore, before repair).
  Future<CacheMaintenanceReport> prune({
    required List<Song> songs,
    Iterable<String> extraCoverPaths = const [],
    Iterable<String> extraNotificationKeys = const [],
  }) async {
    await init();
    if (songs.isEmpty) return const CacheMaintenanceReport();

    final payload = <String, dynamic>{
      'covers': _dirFor(CacheBucket.covers).path,
      'root': _root.path,
      'songs': [
        for (final song in songs)
          {
            'filename': song.filename,
            'url': song.url,
            'cover': song.coverUrl ?? '',
          }
      ],
      'extraCovers': extraCoverPaths.toList(),
      'extraNotification': extraNotificationKeys.toList(),
    };

    final result = await Isolate.run(() => _sweepCache(payload));
    final report = CacheMaintenanceReport(
      orphansDeleted: result['orphans'] ?? 0,
      evictedFiles: result['evicted'] ?? 0,
      reclaimedBytes: result['bytes'] ?? 0,
    );

    if (report.freedAnything) {
      _notificationGeneration++;
      _notificationDir = null;
      _usage = null;
    }

    try {
      await ColorExtractionService.pruneCacheToImagePaths({
        for (final song in songs)
          if ((song.coverUrl ?? '').isNotEmpty) song.coverUrl!,
      });
    } catch (_) {}

    return report;
  }

  // ------------------------------------------------------------------ clear ---

  /// Empties one bucket. Covers also drop the library's cover pointers so the
  /// lazy extraction path can refill them.
  Future<void> clearBucket(CacheBucket bucket) async {
    await init();
    final dir = _dirFor(bucket);
    await _emptyDirectory(dir);
    await dir.create(recursive: true);
    if (bucket == CacheBucket.covers) {
      try {
        await DatabaseService.instance.clearCoverUrls();
        await DatabaseService.instance.clearAllCoverMisses();
      } catch (_) {}
    }
    if (bucket == CacheBucket.palettes) {
      try {
        await ColorExtractionService.clearCache();
      } catch (_) {}
    }
    if (bucket == CacheBucket.notification) _notificationDir = null;
    _notificationGeneration++;
    _usage = null;
  }

  /// Empties every evictable and scratch bucket; permanent ones survive.
  Future<void> clearCache() async {
    await init();
    for (final bucket in CacheBucket.values) {
      if (bucket.retention == CacheRetention.permanent) continue;
      await _emptyDirectory(_dirFor(bucket));
    }
    _notificationDir = null;
    _notificationGeneration++;
    _usage = null;
  }

  Future<void> _wipeScratch() async {
    for (final bucket in CacheBucket.values) {
      if (!bucket.isScratch) continue;
      await _emptyDirectory(_dirFor(bucket));
    }
  }

  Future<void> _emptyDirectory(Directory dir) async {
    try {
      if (!await dir.exists()) return;
      await for (final entity in dir.list(followLinks: false)) {
        await entity.delete(recursive: true);
      }
    } catch (error) {
      debugPrint('WispieCache: could not empty ${dir.path}: $error');
    }
  }

  // ------------------------------------------------------------- rename moves --

  /// Moves filename-keyed entries to the renamed song's identity.
  ///
  /// Content-addressed covers are left alone: their name has nothing to do with
  /// the song, so they survive a rename for free.
  Future<String?> transferSongCaches({
    required Song before,
    required Song after,
  }) async {
    await init();
    if (before.filename == after.filename) return null;

    final oldKey = CoverKey(before.filename);
    final newKey = CoverKey(after.filename);

    await _move(await waveformFile(before.filename),
        await waveformFile(after.filename));
    await _move(
        await beatMapFile(before.filename), await beatMapFile(after.filename));
    await _move(
        await blurredFile(before.filename), await blurredFile(after.filename));
    await _move(
        await songLyricsFile(before.url), await songLyricsFile(after.url));
    await _move(await richLyricsFile(before.filename),
        await richLyricsFile(after.filename));
    await _move(await remoteLyricsFile(before.filename),
        await remoteLyricsFile(after.filename));

    final coverUrl = await _moveFfmpegCover(oldKey.hash, newKey.hash, before);
    if (coverUrl != null) {
      for (final key in {
        notificationCoverKey(before.coverUrl ?? ''),
        notificationCoverKey(coverUrl),
      }) {
        await invalidateNotificationCover(key);
      }
    }
    _usage = null;
    return coverUrl;
  }

  /// Only the FFmpeg fallback cover is named after the song.
  Future<String?> _moveFfmpegCover(
    String oldHash,
    String newHash,
    Song before,
  ) async {
    final coversDir = await directory(CacheBucket.covers);
    final oldCover = File(p.join(coversDir.path, '${oldHash}_ffmpeg.jpg'));
    if (before.coverUrl != oldCover.path || !await oldCover.exists()) {
      return null;
    }
    final newCover = File(p.join(coversDir.path, '${newHash}_ffmpeg.jpg'));
    await _move(oldCover, newCover);
    return newCover.path;
  }

  Future<void> _move(File from, File to) async {
    try {
      if (!await from.exists()) return;
      if (await to.exists()) {
        await from.delete();
        return;
      }
      await to.parent.create(recursive: true);
      await from.rename(to.path);
    } catch (error) {
      debugPrint('WispieCache: could not move ${from.path}: $error');
    }
  }

  // ------------------------------------------------------------- migration ----

  /// One-time. The stored layout version means an install that has already
  /// migrated pays one preference read per launch, not a filesystem sweep.
  Future<void> _migrateLegacyLayout() async {
    if (!await _needsLayoutMigration()) return;

    final orphanDirs = <String>[];
    try {
      final temp = await getTemporaryDirectory();
      for (final name in const [
        'audio_cache',
        'image_cache',
        'libCacheManager',
        'libCachedImageData',
      ]) {
        orphanDirs.add(p.join(temp.path, name));
      }
    } catch (_) {}

    try {
      final result = await migrateLegacyCacheLayout(
        supportPath: _support.path,
        cacheRootPath: _root.path,
        orphanDirs: orphanDirs,
      );
      if (result.migratedAnything) {
        debugPrint('WispieCache: migrated ${result.moved} files, '
            'dropped ${result.dropped}');
      }

      await _migrateLegacyBackups();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_layoutVersionKey, cacheLayoutVersion);
    } catch (error) {
      // Left unmarked so the next launch retries rather than half-migrated.
      debugPrint('WispieCache: migration failed: $error');
    }
  }

  Future<bool> _needsLayoutMigration() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return needsCacheLayoutMigration(prefs.getInt(_layoutVersionKey));
    } catch (_) {
      // Cannot read the marker, so assume the worst; the pass is idempotent.
      return true;
    }
  }

  /// Old builds kept backups beside the databases; Android now uses the public
  /// wispie folder so they survive an uninstall.
  Future<void> _migrateLegacyBackups() async {
    try {
      final home = await getWispieHomeDirectory();
      final legacy =
          Directory(p.join((await getWispieDirectory()).path, 'backups'));
      final target = Directory(p.join(home.path, 'backups'));
      if (p.equals(legacy.path, target.path) || !await legacy.exists()) return;

      await target.create(recursive: true);
      await for (final entity in legacy.list()) {
        if (entity is! File || !entity.path.endsWith('.zip')) continue;
        final destination = File(p.join(target.path, p.basename(entity.path)));
        if (await destination.exists()) continue;
        await _move(entity, destination);
      }
    } catch (error) {
      debugPrint('WispieCache: backup migration failed: $error');
    }
  }

  Future<void> _ensureUserFolders() async {
    try {
      final home = Directory((await getWispieHomeDirectory()).path);
      await Directory(p.join(home.path, 'backups')).create(recursive: true);
      final songs = await ensureWispieSongsDirectory();
      if (songs != null) {
        await songs.create(recursive: true);
      }
    } catch (error) {
      debugPrint('WispieCache: could not prepare user folders: $error');
    }
  }
}

Map<int, List<int>> _scanUsage(Map<int, String> paths) {
  final result = <int, List<int>>{};
  for (final entry in paths.entries) {
    var files = 0;
    var bytes = 0;
    final dir = Directory(entry.value);
    if (dir.existsSync()) {
      try {
        for (final entity
            in dir.listSync(recursive: true, followLinks: false)) {
          if (entity is! File) continue;
          try {
            bytes += entity.lengthSync();
            files++;
          } catch (_) {}
        }
      } catch (_) {}
    }
    result[entry.key] = [files, bytes];
  }
  return result;
}

/// One filesystem pass: prune orphans, drop zero-byte files, trim over-budget
/// buckets least-recently-used.
Map<String, int> _sweepCache(Map<String, dynamic> payload) {
  final songs = (payload['songs'] as List).cast<Map>();
  final coversDir = payload['covers'] as String;
  final rootPath = payload['root'] as String;

  final keep = <CacheBucket, Set<String>>{
    for (final bucket in [
      CacheBucket.covers,
      CacheBucket.remoteArt,
      CacheBucket.blurred,
      CacheBucket.notification,
      CacheBucket.waveforms,
      CacheBucket.beatMaps,
      CacheBucket.lyrics,
    ])
      bucket: <String>{},
  };

  for (final raw in payload['extraCovers'] as List) {
    keep[CacheBucket.covers]!.add(p.normalize(raw as String));
  }
  for (final raw in payload['extraNotification'] as List) {
    keep[CacheBucket.notification]!.add('$raw.jpg');
  }

  for (final row in songs) {
    final filename = (row['filename'] as String?) ?? '';
    final url = (row['url'] as String?) ?? '';
    final cover = (row['cover'] as String?) ?? '';

    if (filename.isNotEmpty) {
      keep[CacheBucket.waveforms]!.add(waveformCacheName(filename));
      keep[CacheBucket.beatMaps]!.add(beatMapCacheName(filename));
      keep[CacheBucket.blurred]!.add(blurredCacheName(filename));
      keep[CacheBucket.lyrics]!.add(richLyricsCacheName(filename));
      keep[CacheBucket.lyrics]!.add(remoteLyricsCacheName(filename));
    }
    if (url.isNotEmpty) {
      keep[CacheBucket.lyrics]!.add(songLyricsCacheName(url));
    }
    if (cover.isNotEmpty) {
      keep[CacheBucket.notification]!.add(notificationCoverName(cover));
      if (cover.startsWith('http')) {
        keep[CacheBucket.remoteArt]!.add(remoteArtCacheName(cover));
      } else if (!cover.startsWith('content://')) {
        keep[CacheBucket.covers]!.add(p.normalize(cover));
      }
    }
  }

  final dirs = <CacheBucket, String>{
    CacheBucket.covers: coversDir,
    CacheBucket.remoteArt: p.join(rootPath, CacheBucket.remoteArt.dirName),
    CacheBucket.blurred: p.join(rootPath, CacheBucket.blurred.dirName),
    CacheBucket.notification:
        p.join(rootPath, CacheBucket.notification.dirName),
    CacheBucket.waveforms: p.join(rootPath, CacheBucket.waveforms.dirName),
    CacheBucket.beatMaps: p.join(rootPath, CacheBucket.beatMaps.dirName),
    CacheBucket.lyrics: p.join(rootPath, CacheBucket.lyrics.dirName),
    CacheBucket.youtube: p.join(rootPath, CacheBucket.youtube.dirName),
  };

  var orphans = 0;
  var evicted = 0;
  var reclaimed = 0;

  for (final entry in dirs.entries) {
    final bucket = entry.key;
    final dir = Directory(entry.value);
    if (!dir.existsSync()) continue;

    final keepNames = keep[bucket];
    final files = <({File file, int bytes, DateTime modified})>[];

    for (final entity in dir.listSync(recursive: true, followLinks: false)) {
      if (entity is! File) continue;
      int bytes;
      DateTime modified;
      try {
        final stat = entity.statSync();
        bytes = stat.size;
        modified = stat.modified;
      } catch (_) {
        continue;
      }

      if (bytes == 0) {
        try {
          entity.deleteSync();
          orphans++;
        } catch (_) {}
        continue;
      }

      if (keepNames != null) {
        final key = bucket == CacheBucket.covers
            ? p.normalize(entity.path)
            : p.basename(entity.path);
        if (!keepNames.contains(key)) {
          try {
            entity.deleteSync();
            orphans++;
            reclaimed += bytes;
          } catch (_) {}
          continue;
        }
      }

      files.add((file: entity, bytes: bytes, modified: modified));
    }

    if (!bucket.isEvictable || bucket.budgetBytes <= 0) continue;
    var total = files.fold<int>(0, (sum, file) => sum + file.bytes);
    if (total <= bucket.budgetBytes) continue;

    final target = bucket.budgetBytes *
        WispieCache._trimNumerator ~/
        WispieCache._trimDenominator;
    files.sort((a, b) => a.modified.compareTo(b.modified));
    for (final file in files) {
      if (total <= target) break;
      try {
        file.file.deleteSync();
        total -= file.bytes;
        evicted++;
        reclaimed += file.bytes;
      } catch (_) {
        // In use by a running decode; the next sweep retries.
      }
    }
  }

  return {'orphans': orphans, 'evicted': evicted, 'bytes': reclaimed};
}
