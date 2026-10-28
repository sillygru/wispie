// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/services/youtube_library.dart';
import 'cache_service.dart';

/// Disk- and memory-backed cache for InnerTube responses.
///
/// The YouTube tab is opened constantly and most of what it shows changes
/// slowly: the home feed, the account's playlists and a playlist's tracks. Each
/// request is expensive (a signed POST plus a client-version lookup on a cold
/// start), so responses are kept per request key.
///
/// Fresh entries are served without touching the network. Expired entries are
/// still returned when a refresh fails, so going offline leaves the last feed
/// on screen instead of an error page.
class YouTubeResponseCache implements YouTubeResponseStore {
  YouTubeResponseCache._();

  static final YouTubeResponseCache instance = YouTubeResponseCache._();

  static const String _prefix = 'youtube_';

  final Map<String, _Entry> _memory = {};
  bool _swept = false;

  /// Responses older than this are useless: the client version they were made
  /// with has usually rotated by then.
  static const Duration _maxAgeOnDisk = Duration(days: 7);

  @override
  Future<Map<String, dynamic>?> read(
    String key,
    Duration maxAge, {
    bool allowStale = false,
  }) async {
    await _sweepOnce();
    final memory = _memory[key];
    if (memory != null) {
      if (allowStale || memory.age < maxAge) return memory.body;
    }
    try {
      final file = await _fileFor(key);
      if (!await file.exists()) return null;
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      final at = (decoded['at'] as num?)?.toDouble();
      final body = decoded['body'];
      if (at == null || body is! Map) return null;
      final entry = _Entry(
        body: Map<String, dynamic>.from(body),
        age: DateTime.now().difference(
          DateTime.fromMillisecondsSinceEpoch((at * 1000).round()),
        ),
      );
      _memory[key] = entry;
      return allowStale || entry.age < maxAge ? entry.body : null;
    } on Object catch (error) {
      debugPrint('YouTube cache: could not read $key: $error');
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> body) async {
    await _sweepOnce();
    _memory[key] = _Entry(body: body, age: Duration.zero);
    try {
      final file = await _fileFor(key);
      final now = DateTime.now().millisecondsSinceEpoch / 1000.0;
      await file.writeAsString(
        jsonEncode({'key': key, 'at': now, 'body': body}),
        flush: false,
      );
    } on Object catch (error) {
      debugPrint('YouTube cache: could not write $key: $error');
    }
  }

  /// Drops one response. A client version YouTube rejected must not come back
  /// from memory on the retry, or the retry repeats the same 400.
  @override
  Future<void> remove(String key) async {
    _memory.remove(key);
    try {
      final file = await _fileFor(key);
      if (await file.exists()) await file.delete();
    } on Object catch (error) {
      debugPrint('YouTube cache: could not remove $key: $error');
    }
  }

  /// Drops every response, in memory and on disk. Used on sign-out and when the
  /// account changes, so the next session never reads another account's feed.
  Future<void> clear() async {
    _memory.clear();
    try {
      final directory = await _directory();
      if (!await directory.exists()) return;
      await for (final entity in directory.list()) {
        if (entity is File && p.basename(entity.path).startsWith(_prefix)) {
          await entity.delete();
        }
      }
    } on Object catch (error) {
      debugPrint('YouTube cache: could not clear: $error');
    }
  }

  Future<void> _sweepOnce() async {
    if (_swept) return;
    _swept = true;
    try {
      final directory = await _directory();
      if (!await directory.exists()) return;
      final cutoff = DateTime.now().subtract(_maxAgeOnDisk);
      await for (final entity in directory.list()) {
        if (entity is! File) continue;
        if (!p.basename(entity.path).startsWith(_prefix)) continue;
        try {
          if ((await entity.stat()).modified.isBefore(cutoff)) {
            await entity.delete();
          }
        } catch (_) {
          // A file disappearing under us is the outcome we wanted anyway.
        }
      }
    } on Object catch (error) {
      debugPrint('YouTube cache: sweep failed: $error');
    }
  }

  Future<File> _fileFor(String key) async {
    final digest = sha1.convert(utf8.encode(key)).toString();
    final directory = await _directory();
    if (!await directory.exists()) await directory.create(recursive: true);
    return File(p.join(directory.path, '$_prefix$digest.json'));
  }

  Future<Directory> _directory() async {
    await CacheService.instance.init();
    final file = await CacheService.instance.getV3File('youtube');
    return file.parent;
  }
}

class _Entry {
  final Map<String, dynamic> body;
  final Duration age;

  const _Entry({required this.body, required this.age});
}
