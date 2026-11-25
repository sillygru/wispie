// SPDX-License-Identifier: GPL-3.0-only
import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../data/rust/native_command.dart';
import 'debug_sandbox.dart';

class OnlineCacheStats {
  final int bytes;
  final int tracks;

  const OnlineCacheStats({required this.bytes, required this.tracks});
}

/// Connects the player and download notifications to the native audio cache.
class OnlineAudioCache {
  OnlineAudioCache._();

  static final OnlineAudioCache instance = OnlineAudioCache._();
  static const String directoryName = 'online_audio';
  static const String providerYouTube = 'youtube';

  Future<Directory>? _directory;
  Future<void>? _sweepInFlight;
  Future<void>? _sessionSweep;
  final _completed = StreamController<String>.broadcast();

  Stream<String> get completions => _completed.stream;

  Future<Directory> directory() {
    return _directory ??= () async {
      final support = await getSupportDirectory();
      return Directory(p.join(support.path, directoryName))
          .create(recursive: true);
    }();
  }

  Future<Map<String, dynamic>> _command(
    String operation, [
    Map<String, Object?> fields = const {},
  ]) async {
    final root = (await directory()).path;
    return compute(
      (request) => runCoreCommand('provider_cache', request),
      {'op': operation, 'root': root, ...fields},
    );
  }

  Future<File?> completeFile(String provider, String id) async {
    try {
      final result = await _command('audio_complete', {
        'provider': provider,
        'id': id,
      });
      final path = result['path'] as String?;
      return path == null ? null : File(path);
    } catch (error) {
      debugPrint('OnlineAudioCache: lookup failed for $id: $error');
      return null;
    }
  }

  Future<File> fileFor({
    required String provider,
    required String id,
    required String itag,
    required String extension,
  }) async {
    final result = await _command('audio_path', {
      'provider': provider,
      'id': id,
      'itag': itag,
      'extension': extension,
    });
    return File(result['path'] as String);
  }

  Future<void> markComplete(File file) async {
    try {
      final result = await _command('audio_mark', {'path': file.path});
      if (result['id'] case final String id) _completed.add(id);
      unawaited(_trim());
    } catch (error) {
      debugPrint(
          'OnlineAudioCache: could not mark ${file.path} complete: $error');
    }
  }

  Future<void> _trim() async {
    try {
      await _command('audio_trim');
    } catch (error) {
      debugPrint('OnlineAudioCache: trim failed: $error');
    }
  }

  Future<void> touch(File file) async {
    try {
      await _command('audio_touch', {'path': file.path});
    } catch (_) {
      // A timestamp failure must not interrupt playback.
    }
  }

  Future<void> ensureSwept() {
    final existing = _sessionSweep;
    if (existing != null) return existing;
    final pending = sweep();
    _sessionSweep = pending;
    return pending.catchError((Object error, StackTrace stackTrace) {
      if (identical(_sessionSweep, pending)) _sessionSweep = null;
      Error.throwWithStackTrace(error, stackTrace);
    });
  }

  Future<void> sweep() =>
      _sweepInFlight ??= _sweep().whenComplete(() => _sweepInFlight = null);

  Future<void> _sweep() async {
    await _command('audio_sweep');
  }

  Future<OnlineCacheStats> stats() async {
    try {
      final reply = await _command('audio_stats');
      return OnlineCacheStats(
        bytes: reply['bytes'] as int,
        tracks: reply['tracks'] as int,
      );
    } catch (error) {
      debugPrint('OnlineAudioCache: could not size the cache: $error');
      return const OnlineCacheStats(bytes: 0, tracks: 0);
    }
  }

  Future<int> totalBytes() async => (await stats()).bytes;

  Future<void> clear() async {
    await _command('audio_clear');
  }
}
