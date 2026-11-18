import 'dart:async';

import '../data/rust/wispie_core.dart';

/// How urgently a gated decode needs the CPU. A running decode is never
/// preempted — FFmpeg sessions cannot be cheaply interrupted — so priority only
/// reorders the *waiting* queue.
enum MediaDecodePriority {
  /// User-facing work: the seek bar's waveform extraction. Jumps ahead of any
  /// queued normal work so the bar appears as soon as the file can be decoded.
  high,

  /// Background / speculative work: beat analysis (current and next-track
  /// prefetch) and the FFmpeg cover-extraction fallback.
  normal,
}

/// Serializes the app's expensive full-file decodes across services.
///
/// Every decode that runs through this gate executes one at a time, so the
/// second one starts only when the first has written its output and freed the
/// CPU. The ordering rule lives in the native core; the futures themselves are
/// Dart's, so the queue and its drain stay here.
class MediaDecodeGate {
  MediaDecodeGate._();

  static final List<_DecodeJob> _waiting = [];
  static bool _running = false;

  /// Runs [body] once every previously queued decode has finished.
  ///
  /// [priority] reorders the queue, not the running job: [high] work (the
  /// waveform the user is looking at) is served before [normal] work (a beat
  /// prefetch nobody is waiting on yet). Within one priority the queue stays
  /// FIFO.
  ///
  /// Errors from [body] propagate to the caller, but never poison the gate — a
  /// failed decode must not silently drop everything queued behind it.
  static Future<T> run<T>(
    Future<T> Function() body, {
    MediaDecodePriority priority = MediaDecodePriority.normal,
  }) {
    final job = _DecodeJob<T>(body, priority: priority);
    final index = (WispieCore.helper({
      'action': 'decode_gate_insert',
      'priorities': [
        for (final queued in _waiting)
          queued.priority == MediaDecodePriority.high ? 'high' : 'normal',
      ],
      'priority': priority == MediaDecodePriority.high ? 'high' : 'normal',
    })['index'] as num)
        .toInt();
    _waiting.insert(index, job);
    _drain();
    return job.result.future;
  }

  static void _drain() {
    if (_running || _waiting.isEmpty) return;
    _running = true;
    final job = _waiting.removeAt(0);
    unawaited(() async {
      try {
        job.result.complete(await job.body());
      } catch (e, st) {
        job.result.completeError(e, st);
      } finally {
        _running = false;
        _drain();
      }
    }());
  }
}

class _DecodeJob<T> {
  final Future<T> Function() body;
  final MediaDecodePriority priority;
  final Completer<T> result = Completer<T>();

  _DecodeJob(this.body, {required this.priority});
}
