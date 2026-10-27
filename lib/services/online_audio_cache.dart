// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import 'debug_sandbox.dart';

/// A file already downloaded from an online catalogue.
class OnlineCacheEntry {
  final String provider;
  final String id;
  final File file;
  final int bytes;
  final DateTime lastUsed;

  const OnlineCacheEntry({
    required this.provider,
    required this.id,
    required this.file,
    required this.bytes,
    required this.lastUsed,
  });
}

class OnlineCacheStats {
  final int bytes;
  final int tracks;

  const OnlineCacheStats({required this.bytes, required this.tracks});
}

/// Disk cache for streamed audio.
///
/// Video is deliberately absent: the player's video pane streams into RAM and
/// drops it, because a music video is large, rarely replayed, and would dwarf
/// the audio cache. Audio, in contrast, is small enough to keep — a cached
/// track plays instantly and works offline.
///
/// Growth is bounded two ways: entries unused for [ttl] are dropped on the next
/// sweep, and the whole directory is trimmed back under [trimTargetBytes] by
/// least-recently-used order whenever a download completes. Files are only
/// considered playable when their `.ok` marker exists, so a download interrupted
/// by a kill resumes instead of being mistaken for a complete track.
class OnlineAudioCache {
  OnlineAudioCache._();

  static final OnlineAudioCache instance = OnlineAudioCache._();

  static const String directoryName = 'online_audio';
  static const String providerYouTube = 'youtube';

  /// Long enough that albums get replayed from disk, short enough that a
  /// library of one-off listens does not live on the device forever.
  static const Duration ttl = Duration(days: 14);

  static const int maxBytes = 1024 * 1024 * 1024;

  /// Evicting down to the target rather than to the cap keeps a fresh download
  /// from immediately triggering another trim.
  static const int trimTargetBytes = maxBytes * 8 ~/ 10;

  Future<Directory>? _directory;
  Map<String, OnlineCacheEntry>? _index;
  Future<void>? _sweepInFlight;
  bool _sweptThisSession = false;

  Future<Directory> directory() {
    return _directory ??= () async {
      final support = await getSupportDirectory();
      final dir = Directory(p.join(support.path, directoryName));
      if (!await dir.exists()) await dir.create(recursive: true);
      return dir;
    }();
  }

  /// Playable file for [id], or null when there is no complete copy.
  Future<File?> completeFile(String provider, String id) async {
    final entry = (await _indexOrBuild())[_key(provider, id)];
    if (entry == null) return null;
    if (DateTime.now().difference(entry.lastUsed) > ttl) return null;
    if (!await entry.file.exists()) {
      _index?.remove(_key(provider, id));
      return null;
    }
    return entry.file;
  }

  /// Where a download for these parameters is written, complete or partial.
  Future<File> fileFor({
    required String provider,
    required String id,
    required String itag,
    required String extension,
  }) async {
    final dir = await directory();
    final suffix = extension.isEmpty ? 'bin' : extension;
    return File(
      p.join(dir.path, '$provider~${_sanitize(id)}~${_sanitize(itag)}.$suffix'),
    );
  }

  /// Marks [file] playable once every byte has arrived.
  Future<void> markComplete(File file) async {
    try {
      await File('${file.path}.ok').create();
      await file.setLastModified(DateTime.now());
      _index ??= {};
      _index![_keyFromFileName(p.basename(file.path))] = OnlineCacheEntry(
        provider: _providerOf(p.basename(file.path)),
        id: _idOf(p.basename(file.path)) ?? '',
        file: file,
        bytes: await file.length(),
        lastUsed: DateTime.now(),
      );
      unawaited(_trimIfNeeded());
    } catch (error) {
      debugPrint(
          'OnlineAudioCache: could not mark ${file.path} complete: $error');
    }
  }

  /// Records use so least-recently-used eviction reflects what is played, not
  /// just what was downloaded.
  Future<void> touch(File file) async {
    try {
      await file.setLastModified(DateTime.now());
      final entry = _index?[_keyFromFileName(p.basename(file.path))];
      if (entry != null) {
        _index![_keyFromFileName(p.basename(file.path))] = OnlineCacheEntry(
          provider: entry.provider,
          id: entry.id,
          file: entry.file,
          bytes: entry.bytes,
          lastUsed: DateTime.now(),
        );
      }
    } catch (_) {
      // A cache timestamp is never worth failing playback over.
    }
  }

  /// Runs the TTL and size sweep once per app session, off the playback path.
  Future<void> ensureSwept() async {
    if (_sweptThisSession) return;
    _sweptThisSession = true;
    await sweep();
  }

  Future<void> sweep() {
    return _sweepInFlight ??= _sweep().whenComplete(() {
      _sweepInFlight = null;
    });
  }

  Future<void> _sweep() async {
    final dir = await directory();
    final now = DateTime.now();
    final entries = <({File file, DateTime modified, int bytes})>[];

    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.endsWith('.ok')) {
          // Orphaned marker: its audio file was removed under it.
          if (!await File(entity.path.substring(0, entity.path.length - 3))
              .exists()) {
            await entity.delete();
          }
          continue;
        }
        final stat = await entity.stat();
        final isPartial = name.endsWith('.part');
        if (now.difference(stat.modified) > ttl) {
          await entity.delete();
          if (!isPartial) {
            await File('${entity.path}.ok').deleteIfExists();
          }
          continue;
        }
        entries.add((file: entity, modified: stat.modified, bytes: stat.size));
      }
    } catch (error) {
      debugPrint('OnlineAudioCache: sweep listing failed: $error');
    }

    entries.sort((a, b) => a.modified.compareTo(b.modified));
    var total = entries.fold<int>(0, (sum, entry) => sum + entry.bytes);
    for (final entry in entries) {
      if (total <= trimTargetBytes) break;
      try {
        await entry.file.delete();
        await File('${entry.file.path}.ok').deleteIfExists();
        total -= entry.bytes;
      } catch (_) {
        // Locked by a player that is still using it; the next sweep retries.
      }
    }

    _index = null;
    await _indexOrBuild();
  }

  Future<void> _trimIfNeeded() async {
    final current = await stats();
    if (current.bytes > maxBytes) await sweep();
  }

  Future<OnlineCacheStats> stats() async {
    final dir = await directory();
    var bytes = 0;
    var tracks = 0;
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.endsWith('.ok')) continue;
        bytes += await entity.length();
        if (!name.endsWith('.part')) tracks++;
      }
    } catch (error) {
      debugPrint('OnlineAudioCache: could not size the cache: $error');
    }
    return OnlineCacheStats(bytes: bytes, tracks: tracks);
  }

  Future<int> totalBytes() async => (await stats()).bytes;

  Future<void> clear() async {
    try {
      final dir = await directory();
      if (await dir.exists()) await dir.delete(recursive: true);
      await dir.create(recursive: true);
    } catch (error) {
      debugPrint('OnlineAudioCache: clear failed: $error');
      rethrow;
    } finally {
      _index = null;
    }
  }

  Future<Map<String, OnlineCacheEntry>> _indexOrBuild() async {
    final cached = _index;
    if (cached != null) return cached;

    final dir = await directory();
    final index = <String, OnlineCacheEntry>{};
    try {
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        final name = p.basename(entity.path);
        if (name.endsWith('.ok') || name.endsWith('.part')) continue;
        final id = _idOf(name);
        final provider = _providerOf(name);
        if (id == null || provider.isEmpty) continue;
        if (!await File('${entity.path}.ok').exists()) continue;
        final stat = await entity.stat();
        final key = _key(provider, id);
        final existing = index[key];
        if (existing != null && existing.lastUsed.isAfter(stat.modified)) {
          continue;
        }
        index[key] = OnlineCacheEntry(
          provider: provider,
          id: id,
          file: entity,
          bytes: stat.size,
          lastUsed: stat.modified,
        );
      }
    } catch (error) {
      debugPrint('OnlineAudioCache: could not index the cache: $error');
    }
    _index = index;
    return index;
  }

  static String _key(String provider, String id) => '$provider~$id';

  static String _keyFromFileName(String name) =>
      _key(_providerOf(name), _idOf(name) ?? '');

  static String _providerOf(String name) {
    final separator = name.indexOf('~');
    return separator <= 0 ? '' : name.substring(0, separator);
  }

  static String? _idOf(String name) {
    final parts = name.split('~');
    return parts.length < 2 || parts[1].isEmpty ? null : parts[1];
  }

  static String _sanitize(String value) =>
      value.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
}

extension on File {
  Future<void> deleteIfExists() async {
    try {
      if (await exists()) await delete();
    } catch (_) {
      // Best effort: a marker left behind is cleaned up by the next sweep.
    }
  }
}
