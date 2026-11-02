import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/services/cache_policy.dart';
import 'wispie_cache.dart';
import 'wispie_paths.dart';

/// The kinds of content a backup archive can carry.
enum BackupContentType {
  userStats,
  userData,
  userSettings,
  coverCache,
  libraryCache,
  searchIndex,
  waveformCache,
  colorCache,
  lyricsCache,
  artistArtCache,
  albumArtCache,
}

/// One piece of cached content: where it lives on disk and where it is stored
/// inside a backup archive.
///
/// [types] is a set because several content types share one directory: covers,
/// artist art and album art all live in the cover store, and storing it once
/// keeps archives from carrying the same images three times.
class BackupArtifact {
  final Set<BackupContentType> types;

  /// Path inside the archive, relative to the archive root.
  final String archivePath;

  /// Absolute path of the live location this artifact is read from and
  /// restored to.
  final String sourcePath;

  /// Whether [sourcePath] is a directory (copied recursively) or a single file.
  final bool isDirectory;

  /// Optional filter applied when a directory holds more than this bucket.
  final bool Function(File file)? filter;

  /// False for entries kept only to read old archives, so new backups do not
  /// duplicate their content.
  final bool stage;

  const BackupArtifact({
    required this.types,
    required this.archivePath,
    required this.sourcePath,
    required this.isDirectory,
    this.filter,
    this.stage = true,
  });

  bool covers(BackupContentType type) => types.contains(type);

  bool coversAny(Set<BackupContentType> wanted) => wanted.any(types.contains);
}

/// Builds the manifest of cache artifacts for the current device paths.
Future<List<BackupArtifact>> cacheArtifacts() async {
  final docDir = await getWispieDirectory();
  final cache = WispieCache.instance;
  final covers = (await cache.directory(CacheBucket.covers)).path;
  final blurred = (await cache.directory(CacheBucket.blurred)).path;
  final notification = (await cache.directory(CacheBucket.notification)).path;
  final lyrics = (await cache.directory(CacheBucket.lyrics)).path;
  final waveforms = (await cache.directory(CacheBucket.waveforms)).path;
  final palettes = (await cache.paletteIndexFile()).path;

  const coverTypes = {
    BackupContentType.coverCache,
    BackupContentType.artistArtCache,
    BackupContentType.albumArtCache,
  };

  return [
    BackupArtifact(
      types: coverTypes,
      archivePath: 'cache/covers/extracted',
      sourcePath: covers,
      isDirectory: true,
    ),
    BackupArtifact(
      types: const {BackupContentType.coverCache},
      archivePath: 'cache/covers/blurred',
      sourcePath: blurred,
      isDirectory: true,
    ),
    BackupArtifact(
      types: const {BackupContentType.coverCache},
      archivePath: 'cache/covers/notification',
      sourcePath: notification,
      isDirectory: true,
    ),
    // Read-only duplicates for archives written before covers were stored once.
    BackupArtifact(
      types: const {BackupContentType.artistArtCache},
      archivePath: 'cache/artist_art',
      sourcePath: covers,
      isDirectory: true,
      stage: false,
    ),
    BackupArtifact(
      types: const {BackupContentType.albumArtCache},
      archivePath: 'cache/album_art',
      sourcePath: covers,
      isDirectory: true,
      stage: false,
    ),
    BackupArtifact(
      types: const {BackupContentType.libraryCache},
      archivePath: 'cache/library/cached_songs.json',
      sourcePath: p.join(docDir.path, 'cached_songs.json'),
      isDirectory: false,
    ),
    BackupArtifact(
      types: const {BackupContentType.searchIndex},
      archivePath: 'cache/search/wispie_search_index.db',
      sourcePath: p.join(docDir.path, 'wispie_search_index.db'),
      isDirectory: false,
    ),
    BackupArtifact(
      types: const {BackupContentType.waveformCache},
      archivePath: 'cache/waveforms',
      sourcePath: waveforms,
      isDirectory: true,
    ),
    BackupArtifact(
      types: const {BackupContentType.colorCache},
      archivePath: 'cache/color/palette_cache.json',
      sourcePath: palettes,
      isDirectory: false,
    ),
    BackupArtifact(
      types: const {BackupContentType.lyricsCache},
      archivePath: 'cache/lyrics',
      sourcePath: lyrics,
      isDirectory: true,
    ),
  ];
}

/// Copies an artifact's live content into [stagingRoot] under its archive path.
Future<int> stageArtifact(BackupArtifact artifact, String stagingRoot) async {
  if (!artifact.stage) return 0;
  final target = p.join(stagingRoot, artifact.archivePath);

  if (!artifact.isDirectory) {
    final source = File(artifact.sourcePath);
    if (!await source.exists()) return 0;
    await Directory(p.dirname(target)).create(recursive: true);
    await source.copy(target);
    return 1;
  }

  final sourceDir = Directory(artifact.sourcePath);
  if (!await sourceDir.exists()) return 0;

  var staged = 0;
  await for (final entity
      in sourceDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    if (artifact.filter != null && !artifact.filter!(entity)) continue;

    final relative = p.relative(entity.path, from: sourceDir.path);
    final destination = File(p.join(target, relative));
    await destination.parent.create(recursive: true);
    await entity.copy(destination.path);
    staged++;
  }
  return staged;
}

/// Copies an artifact back from an extracted archive at [archiveRoot] to its
/// live location. Existing files are overwritten; unrelated files are kept.
Future<int> restoreArtifact(BackupArtifact artifact, String archiveRoot) async {
  final source = p.join(archiveRoot, artifact.archivePath);

  if (!artifact.isDirectory) {
    final file = File(source);
    if (!await file.exists()) return 0;
    await Directory(p.dirname(artifact.sourcePath)).create(recursive: true);
    await file.copy(artifact.sourcePath);
    return 1;
  }

  final sourceDir = Directory(source);
  if (!await sourceDir.exists()) return 0;

  var restored = 0;
  await for (final entity
      in sourceDir.list(recursive: true, followLinks: false)) {
    if (entity is! File) continue;

    final relative = p.relative(entity.path, from: sourceDir.path);
    final destination = File(p.join(artifact.sourcePath, relative));
    await destination.parent.create(recursive: true);
    await entity.copy(destination.path);
    restored++;
  }
  WispieCache.instance.invalidateUsage();
  return restored;
}

/// Whether an extracted archive at [archiveRoot] carries any content for [type].
Future<bool> archiveHasContent(
  List<BackupArtifact> artifacts,
  BackupContentType type,
  String archiveRoot,
) async {
  for (final artifact in artifacts.where((a) => a.covers(type))) {
    final path = p.join(archiveRoot, artifact.archivePath);
    if (artifact.isDirectory) {
      final dir = Directory(path);
      if (await dir.exists()) {
        final hasFiles = await dir.list(recursive: true).any((e) {
          if (e is! File) return false;
          try {
            return e.lengthSync() > 0;
          } catch (_) {
            return false;
          }
        });
        if (hasFiles) return true;
      }
    } else {
      final file = File(path);
      if (await file.exists()) {
        try {
          if (await file.length() > 0) return true;
        } catch (_) {}
      }
    }
  }
  return false;
}

/// Extracts an archive entry name into [root], rejecting entries that would
/// escape it (zip-slip).
File? safeArchiveTarget(String root, String entryName) {
  final normalized = p.normalize(entryName);
  if (p.isAbsolute(normalized) ||
      normalized.split(RegExp(r'[/\\]')).contains('..')) {
    debugPrint('Skipping unsafe archive entry: $entryName');
    return null;
  }
  final target = File(p.join(root, normalized));
  if (!p.isWithin(root, target.path)) {
    debugPrint('Skipping unsafe archive entry: $entryName');
    return null;
  }
  return target;
}
