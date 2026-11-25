import 'dart:async';

import '../data/rust/native_command.dart';

/// A running decode is never preempted. Priority reorders waiting jobs only.
enum MediaDecodePriority { high, normal }

/// Runs plugin and native decode calls through the same process-wide gate.
class MediaDecodeGate {
  MediaDecodeGate._();

  static Completer<void> _localRelease = Completer<void>();
  static bool _runningHere = false;

  static Future<T> run<T>(
    Future<T> Function() body, {
    MediaDecodePriority priority = MediaDecodePriority.normal,
  }) async {
    final request = runCoreCommand('decode_gate', {
      'op': 'enqueue',
      'high': priority == MediaDecodePriority.high,
    });
    final ticket = request['ticket'] as int;
    var started = request['started'] as bool;
    while (!started) {
      if (_runningHere) {
        await _localRelease.future;
      } else {
        // The native lease can also be released by a different isolate.
        await Future<void>.delayed(const Duration(milliseconds: 30));
      }
      started = runCoreCommand('decode_gate', {
        'op': 'try_start',
        'ticket': ticket,
      })['started'] as bool;
    }

    _runningHere = true;
    try {
      return await body();
    } finally {
      runCoreCommand('decode_gate', {'op': 'release', 'ticket': ticket});
      _runningHere = false;
      final released = _localRelease;
      _localRelease = Completer<void>();
      released.complete();
    }
  }
}
