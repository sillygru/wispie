import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../data/rust/wispie_core.dart';
import 'database_service.dart';
import 'sync_service.dart';

/// Stamps play events with this install's session metadata and batches them
/// into the stats database. The stamp shape, the pending cap and the flush gate
/// are native rules; the database write is the platform adapter.
class StatsService {
  final String _sessionId;
  late final String _platform;
  final List<Map<String, dynamic>> _pendingStats = [];
  bool _isBackground = false;
  Future<bool>? _activeFlush;

  StatsService() : _sessionId = const Uuid().v4() {
    if (Platform.isAndroid) {
      _platform = 'android';
    } else if (Platform.isIOS) {
      _platform = 'ios';
    } else if (Platform.isMacOS) {
      _platform = 'macos';
    } else if (Platform.isWindows) {
      _platform = 'windows';
    } else if (Platform.isLinux) {
      _platform = 'linux';
    } else {
      _platform = 'unknown';
    }
  }

  void setBackground(bool value) {
    _isBackground = value;
    if (!value) {
      // Immediately flush when coming back to foreground
      flush();
    }
  }

  Future<void> trackStats(Map<String, dynamic> stats) async {
    final event = WispieCore.helper({
      'action': 'stats_stamp',
      'stats': stats,
      'platform': _platform,
      'sessionId': _sessionId,
      'deviceId': SyncService.instance.deviceId,
      'timestamp': DateTime.now().millisecondsSinceEpoch / 1000.0,
    })['event'] as Map<String, dynamic>;

    _pendingStats.add(event);

    // Drop oldest events if we are in a sustained flush-failure state.
    final drop = WispieCore.helper({
      'action': 'stats_trim',
      'pending': _pendingStats.length,
    })['drop'] as int;
    if (drop > 0) {
      _pendingStats.removeRange(0, drop);
    }

    final shouldFlush = WispieCore.helper({
      'action': 'stats_flush',
      'background': _isBackground,
      'pending': _pendingStats.length,
    })['flush'] as bool;
    if (shouldFlush) {
      await flush();
    }
  }

  Future<void> flush() async {
    while (true) {
      final activeFlush = _activeFlush;
      if (activeFlush != null) {
        final success = await activeFlush;
        if (!success || _pendingStats.isEmpty) return;
        continue;
      }

      if (_pendingStats.isEmpty) return;

      final future = _flushPending();
      _activeFlush = future;
      bool success = false;
      try {
        success = await future;
      } finally {
        if (identical(_activeFlush, future)) {
          _activeFlush = null;
        }
      }

      if (!success || _pendingStats.isEmpty) return;
    }
  }

  Future<bool> _flushPending() async {
    while (_pendingStats.isNotEmpty) {
      final batch = List<Map<String, dynamic>>.from(_pendingStats);

      try {
        await DatabaseService.instance.init();
        await DatabaseService.instance.insertPlayEventsBatch(batch);
        _pendingStats.removeRange(0, batch.length);
        debugPrint('Flushed ${batch.length} batched stats events.');
      } catch (e) {
        debugPrint('Error flushing stats batch: $e');
        return false;
      }
    }
    return true;
  }

  void dispose() {
    flush(); // Final flush on dispose
  }
}
