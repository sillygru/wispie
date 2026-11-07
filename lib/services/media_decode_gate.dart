import 'dart:async';

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

/// Operational state of the serialization gate.
enum MediaDecodeGatePhase {
  idle,
  executing,
}

/// Serializes the app's expensive full-file decodes across services.
class MediaDecodeGate {
  MediaDecodeGate._();

  static final List<_DecodeJob> _waiting = [];
  static MediaDecodeGatePhase _phase = MediaDecodeGatePhase.idle;

  static MediaDecodeGatePhase get phase => _phase;
  static bool get isExecuting => _phase == MediaDecodeGatePhase.executing;

  /// Runs [body] once every previously queued decode has finished.
  static Future<T> run<T>(
    Future<T> Function() body, {
    MediaDecodePriority priority = MediaDecodePriority.normal,
  }) {
    final job = _DecodeJob<T>(body, priority: priority);
    if (priority == MediaDecodePriority.high) {
      final firstNormal = _waiting.indexWhere(
        (queued) => queued.priority != MediaDecodePriority.high,
      );
      _waiting.insert(firstNormal == -1 ? _waiting.length : firstNormal, job);
    } else {
      _waiting.add(job);
    }
    _drain();
    return job.result.future;
  }

  static void _drain() {
    if (_phase == MediaDecodeGatePhase.executing || _waiting.isEmpty) return;
    _phase = MediaDecodeGatePhase.executing;
    final job = _waiting.removeAt(0);
    unawaited(() async {
      try {
        job.result.complete(await job.body());
      } catch (e, st) {
        job.result.completeError(e, st);
      } finally {
        _phase = MediaDecodeGatePhase.idle;
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
