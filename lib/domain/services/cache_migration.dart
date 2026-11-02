// SPDX-License-Identifier: GPL-3.0-only
import 'dart:io';

import 'package:path/path.dart' as p;

/// What a migration pass found and did.
class CacheMigrationResult {
  const CacheMigrationResult({
    this.moved = 0,
    this.dropped = 0,
    this.legacyFound = false,
  });

  final int moved;
  final int dropped;
  final bool legacyFound;

  bool get migratedAnything => moved > 0 || dropped > 0 || legacyFound;
}

const String legacyCacheRootV3 = 'gru_cache_v3';
const String legacyCacheRootV2 = 'gru_cache_v2';
const String legacyPaletteFile = 'palette_cache.json';
const String legacyFeedFile = 'youtube_feed.json';
const String legacyArtworkDir = 'artwork_cache';
const String legacyPaletteDir = 'palettes';
const String legacyWaveformTempDir = 'waveform_temp';
const String legacyBeatTempDir = 'beat_analysis_temp';

/// Bumped if the layout changes again. An install that already stored this
/// version skips the pass entirely instead of re-statting every legacy path on
/// each launch.
const int cacheLayoutVersion = 2;

/// True when [storedVersion] predates the current layout. A missing marker means
/// this install has never migrated.
bool needsCacheLayoutMigration(int? storedVersion) =>
    (storedVersion ?? 0) < cacheLayoutVersion;

/// Moves a pre-`wispie_cache` layout into the current one.
///
/// Dart-only so the probe can run it against a fake tree. Files that no bucket
/// owns (old proxies) and files in a retired format are deleted; everything else
/// is moved, never copied twice.
Future<CacheMigrationResult> migrateLegacyCacheLayout({
  required String supportPath,
  required String cacheRootPath,
  List<String> orphanDirs = const [],
}) async {
  var moved = 0;
  var dropped = 0;
  var legacyFound = false;

  for (final legacyName in [legacyCacheRootV3, legacyCacheRootV2]) {
    final legacy = Directory(p.join(supportPath, legacyName));
    if (!await legacy.exists()) continue;
    legacyFound = true;

    // Snapshot first: moving files during an async listing of the same tree
    // skips entries or throws.
    final files = <File>[];
    await for (final entity
        in legacy.list(recursive: true, followLinks: false)) {
      if (entity is File) files.add(entity);
    }

    for (final file in files) {
      final relative = p.relative(file.path, from: legacy.path);
      final target = _targetRelative(relative, p.basename(file.path));
      if (target == null) {
        if (await _deleteFile(file)) dropped++;
        continue;
      }
      if (await _moveInto(cacheRootPath, target, file)) moved++;
    }
    await _deleteDirectory(legacy);
  }

  final artwork = Directory(p.join(supportPath, legacyArtworkDir));
  if (await artwork.exists()) {
    legacyFound = true;
    final files = <File>[];
    await for (final entity in artwork.list(followLinks: false)) {
      if (entity is File) files.add(entity);
    }
    for (final file in files) {
      if (await _moveInto(
          cacheRootPath, p.join('remote_art', p.basename(file.path)), file)) {
        moved++;
      }
    }
    await _deleteDirectory(artwork);
  }

  for (final legacyFile in [legacyPaletteFile, legacyFeedFile]) {
    final source = File(p.join(supportPath, legacyFile));
    if (!await source.exists()) continue;
    legacyFound = true;
    final target = legacyFile == legacyPaletteFile
        ? p.join('palettes', 'palettes.json')
        : p.join('youtube', 'feed.json');
    if (await _moveInto(cacheRootPath, target, source)) moved++;
  }

  for (final legacyDir in [
    legacyPaletteDir,
    legacyWaveformTempDir,
    legacyBeatTempDir
  ]) {
    final dir = Directory(p.join(supportPath, legacyDir));
    if (!await dir.exists()) continue;
    legacyFound = true;
    await _deleteDirectory(dir);
  }

  for (final path in orphanDirs) {
    final dir = Directory(path);
    if (!await dir.exists()) continue;
    legacyFound = true;
    await _deleteDirectory(dir);
  }

  dropped += await _dropRetiredWaveforms(cacheRootPath);

  return CacheMigrationResult(
    moved: moved,
    dropped: dropped,
    legacyFound: legacyFound,
  );
}

/// Deletes waveform files in the retired JSON format.
///
/// They are unreadable now, and leaving them for the library prune wastes the
/// space until a library happens to be present.
Future<int> _dropRetiredWaveforms(String cacheRootPath) async {
  final dir = Directory(p.join(cacheRootPath, 'waveforms'));
  if (!await dir.exists()) return 0;

  var dropped = 0;
  await for (final entity in dir.list(followLinks: false)) {
    if (entity is! File) continue;
    if (entity.path.endsWith('.wfm')) continue;
    if (await _deleteFile(entity)) dropped++;
  }
  return dropped;
}

/// Where a legacy cache file belongs, or null when it has no place any more.
String? _targetRelative(String relative, String name) {
  if (relative.startsWith('ios_media_proxy')) return null;

  for (final mapping in const [
    ('blurred_cache', 'blurred'),
    ('notification_cover_cache', 'notification'),
    ('lyrics_cache', 'lyrics'),
  ]) {
    if (relative.startsWith(mapping.$1)) {
      final rest = relative
          .substring(mapping.$1.length)
          .replaceFirst(RegExp(r'^[/\\]'), '');
      return rest.isEmpty ? null : p.join(mapping.$2, rest);
    }
  }

  if (name.startsWith('waveform_')) return p.join('waveforms', name);
  if (name.startsWith('beatmap_')) return p.join('beatmaps', name);
  if (name.startsWith('youtube_')) return p.join('youtube', name);
  return null;
}

Future<bool> _moveInto(String rootPath, String relative, File file) async {
  final target = File(p.join(rootPath, relative));
  try {
    await target.parent.create(recursive: true);
    if (await target.exists()) {
      await file.delete();
      return false;
    }
    await file.rename(target.path);
    return true;
  } catch (_) {
    // Cross-device or locked: fall back to a copy, then drop the original.
    try {
      await file.copy(target.path);
      await file.delete();
      return true;
    } catch (_) {
      return false;
    }
  }
}

Future<bool> _deleteFile(File file) async {
  try {
    await file.delete();
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> _deleteDirectory(Directory dir) async {
  try {
    await dir.delete(recursive: true);
  } catch (_) {}
}
