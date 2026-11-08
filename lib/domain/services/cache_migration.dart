// SPDX-License-Identifier: GPL-3.0-only
import 'dart:io';

import 'package:path/path.dart' as p;

import 'cache_policy.dart';

/// What a migration pass found and did.
class CacheMigrationResult {
  const CacheMigrationResult({
    this.moved = 0,
    this.dropped = 0,
    this.failed = 0,
    this.legacyFound = false,
  });

  final int moved;

  /// Files deliberately not carried over: scratch, retired formats, cache
  /// leftovers no bucket owns.
  final int dropped;

  /// Files that should have moved and did not. Any of them keeps the tree and
  /// the layout marker so the next launch retries.
  final int failed;

  final bool legacyFound;

  bool get migratedAnything => moved > 0 || dropped > 0 || legacyFound;

  /// True when nothing was left behind.
  bool get complete => failed == 0;

  @override
  String toString() => 'moved $moved, dropped $dropped, failed $failed'
      '${legacyFound ? '' : ' (no legacy layout)'}';
}

const String legacyCacheRootV3 = 'gru_cache_v3';
const String legacyCacheRootV2 = 'gru_cache_v2';
const String legacyPaletteFile = 'palette_cache.json';
const String legacyFeedFile = 'youtube_feed.json';
const String legacyArtworkDir = 'artwork_cache';
const String legacyPaletteDir = 'palettes';
const String legacyProxyDir = 'ios_media_proxy';
const String legacyWaveformTempDir = 'waveform_temp';
const String legacyBeatTempDir = 'beat_analysis_temp';

/// Bumped whenever the layout or what counts as legacy changes, so a migrated
/// install pays one preference read per launch instead of a filesystem sweep.
const int cacheLayoutVersion = 3;

/// True when [storedVersion] predates the current layout. A missing marker means
/// this install has never migrated.
bool needsCacheLayoutMigration(int? storedVersion) =>
    (storedVersion ?? 0) < cacheLayoutVersion;

/// Moves a pre-`wispie_cache` layout into the current one. Dart-only, so the
/// probe can run it against a fake tree. A move is verified before its source is dropped.
Future<CacheMigrationResult> migrateLegacyCacheLayout({
  required String supportPath,
  required String cacheRootPath,
  List<String> orphanDirs = const [],
}) async {
  var moved = 0;
  var dropped = 0;
  var failed = 0;
  var legacyFound = false;

  for (final legacyName in const [legacyCacheRootV3, legacyCacheRootV2]) {
    final legacy = Directory(p.join(supportPath, legacyName));
    if (!await legacy.exists()) continue;
    legacyFound = true;

    var leftovers = 0;
    for (final file in await _filesUnder(legacy)) {
      final relative = p.relative(file.path, from: legacy.path);
      final target = _targetRelative(relative);
      if (target == null) {
        if (await _deleteFile(file)) {
          dropped++;
        } else {
          leftovers++;
        }
        continue;
      }
      if (await _moveInto(cacheRootPath, target, file)) {
        moved++;
      } else {
        leftovers++;
      }
    }
    failed += leftovers;

    // Only a tree that gave up everything can go.
    if (leftovers == 0 && !await _deleteDirectory(legacy)) failed++;
  }

  final artwork = Directory(p.join(supportPath, legacyArtworkDir));
  if (await artwork.exists()) {
    legacyFound = true;
    var leftovers = 0;
    for (final file in await _filesUnder(artwork)) {
      if (await _moveInto(
        cacheRootPath,
        p.join(CacheBucket.remoteArt.dirName, p.basename(file.path)),
        file,
      )) {
        moved++;
      } else {
        leftovers++;
      }
    }
    failed += leftovers;
    if (leftovers == 0 && !await _deleteDirectory(artwork)) failed++;
  }

  for (final legacyFile in const [legacyPaletteFile, legacyFeedFile]) {
    final source = File(p.join(supportPath, legacyFile));
    if (!await source.exists()) continue;
    legacyFound = true;
    final target = legacyFile == legacyPaletteFile
        ? p.join(CacheBucket.palettes.dirName, paletteIndexName)
        : p.join(CacheBucket.youtube.dirName, 'feed.json');
    if (await _moveInto(cacheRootPath, target, source)) {
      moved++;
    } else {
      failed++;
    }
  }

  for (final legacyDir in const [
    legacyPaletteDir,
    legacyWaveformTempDir,
    legacyBeatTempDir,
  ]) {
    final dir = Directory(p.join(supportPath, legacyDir));
    if (!await dir.exists()) continue;
    legacyFound = true;
    if (!await _deleteDirectory(dir)) failed++;
  }

  for (final path in orphanDirs) {
    final dir = Directory(path);
    if (!await dir.exists()) continue;
    legacyFound = true;
    if (!await _deleteDirectory(dir)) failed++;
  }

  dropped += await _dropRetiredWaveforms(cacheRootPath);

  return CacheMigrationResult(
    moved: moved,
    dropped: dropped,
    failed: failed,
    legacyFound: legacyFound,
  );
}

/// Deletes waveform entries in a retired format, and staging files from a write
/// that was interrupted, so neither is mistaken for a usable entry.
Future<int> _dropRetiredWaveforms(String cacheRootPath) async {
  final dir = Directory(
    p.join(cacheRootPath, CacheBucket.waveforms.dirName),
  );
  if (!await dir.exists()) return 0;

  var dropped = 0;
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    final name = p.basename(entity.path);
    if (!isRetiredWaveformCacheName(name) &&
        !name.endsWith(cacheStagingSuffix)) {
      continue;
    }
    if (await _deleteFile(entity)) dropped++;
  }
  return dropped;
}

/// Where a legacy cache file belongs, or null when it has no place any more.
String? _targetRelative(String relative) {
  final segments = p.split(relative);
  final name = segments.last;
  final first = segments.first;

  // A proxy is only valid for the run that wrote it, and a JSON waveform cannot
  // be read by this build.
  if (first == legacyProxyDir) return null;
  if (isRetiredWaveformCacheName(name)) return null;

  if (segments.length > 1) {
    final bucket = _bucketForLegacyDir(first);
    if (bucket == null) return null;
    return p.join(bucket, p.joinAll(segments.skip(1)));
  }

  if (isWaveformCacheFileName(name)) {
    return p.join(CacheBucket.waveforms.dirName, name);
  }
  if (name.startsWith('beatmap_')) {
    return p.join(CacheBucket.beatMaps.dirName, name);
  }
  if (name.startsWith('youtube_')) {
    return p.join(CacheBucket.youtube.dirName, name);
  }
  return null;
}

String? _bucketForLegacyDir(String name) {
  switch (name) {
    case 'blurred_cache':
      return CacheBucket.blurred.dirName;
    case 'notification_cover_cache':
      return CacheBucket.notification.dirName;
    case 'lyrics_cache':
      return CacheBucket.lyrics.dirName;
  }
  return null;
}

/// Snapshot before moving anything: mutating a tree during an async listing of
/// itself skips entries or throws.
Future<List<File>> _filesUnder(Directory dir) async {
  final files = <File>[];
  try {
    await for (final entity in dir.list(recursive: true, followLinks: false)) {
      if (entity is File) files.add(entity);
    }
  } on FileSystemException {
    // A subdirectory that vanished mid-listing still leaves the rest to move.
  }
  return files;
}

/// Moves [file] to `rootPath/relative`, returning false only when it is still
/// where it was, so every failure is retryable.
Future<bool> _moveInto(String rootPath, String relative, File file) async {
  final target = File(p.join(rootPath, relative));
  try {
    await target.parent.create(recursive: true);
  } on FileSystemException {
    return false;
  }

  final sourceBytes = await _lengthOf(file);
  if (await target.exists()) {
    final targetBytes = await _lengthOf(target);
    if (targetBytes > 0 || sourceBytes <= 0) return _deleteFile(file);
  }

  try {
    await file.rename(target.path);
    return true;
  } on FileSystemException {
    // Cross-device or locked: fall back to a copy, which needs verifying.
  }

  try {
    await file.copy(target.path);
  } on FileSystemException {
    return false;
  }
  if (sourceBytes >= 0 && await _lengthOf(target) != sourceBytes) {
    // A short copy is not a migration; the original stays where it is.
    return false;
  }
  return _deleteFile(file);
}

Future<int> _lengthOf(File file) async {
  try {
    return await file.length();
  } on FileSystemException {
    return -1;
  }
}

Future<bool> _deleteFile(File file) async {
  try {
    await file.delete();
    return true;
  } on FileSystemException {
    return !await file.exists();
  }
}

Future<bool> _deleteDirectory(Directory dir) async {
  try {
    await dir.delete(recursive: true);
    return true;
  } on FileSystemException {
    return !await dir.exists();
  }
}
