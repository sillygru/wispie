// SPDX-License-Identifier: GPL-3.0-only
import 'package:flutter/foundation.dart';

import '../data/rust/native_command.dart';
import '../domain/services/cache_policy.dart';
import '../domain/services/youtube_library.dart';
import 'wispie_cache.dart';

/// Supplies the app cache directory and clock to the native response store.
class YouTubeResponseCache implements YouTubeResponseStore {
  YouTubeResponseCache._();

  static final YouTubeResponseCache instance = YouTubeResponseCache._();

  Future<void>? _sweep;

  Future<Map<String, dynamic>> _request(
    String op, [
    Map<String, Object?> data = const {},
  ]) async {
    final root =
        (await WispieCache.instance.directory(CacheBucket.youtube)).path;
    return compute(
      (request) => runCoreCommand('provider_cache', request),
      {'op': op, 'root': root, ...data},
    );
  }

  @override
  Future<Map<String, dynamic>?> read(
    String key,
    Duration maxAge, {
    bool allowStale = false,
  }) async {
    await (_sweep ??= _maintenance('response_sweep'));
    try {
      final result = await _request('response_read', {
        'key': key,
        'now_ms': DateTime.now().millisecondsSinceEpoch,
        'max_age_ms': maxAge.inMilliseconds,
        'allow_stale': allowStale,
      });
      return result['body'] as Map<String, dynamic>?;
    } catch (error) {
      debugPrint('YouTube cache read failed: $error');
      return null;
    }
  }

  @override
  Future<void> write(String key, Map<String, dynamic> body) async {
    await (_sweep ??= _maintenance('response_sweep'));
    await _maintenance('response_write', {
      'key': key,
      'body': body,
      'now_ms': DateTime.now().millisecondsSinceEpoch,
    });
  }

  @override
  Future<void> remove(String key) =>
      _maintenance('response_remove', {'key': key});

  Future<void> clear() => _maintenance('response_clear');

  Future<void> _maintenance(
    String operation, [
    Map<String, Object?> data = const {},
  ]) async {
    try {
      await _request(operation, data);
    } catch (error) {
      debugPrint('YouTube cache operation $operation failed: $error');
    }
  }
}
