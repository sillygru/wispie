import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter/foundation.dart';

import '../domain/services/cache_policy.dart';
import '../domain/services/native_accel.dart';
import 'wispie_cache.dart';
import 'media_decode_gate.dart';

class WaveformService {
  final WispieCache _cacheService;

  WaveformService(this._cacheService);

  /// The fixed bar count every extracted waveform is bucketed into. Widgets use
  /// it to scale a partial emission (which carries fewer bars) to the width it
  /// should occupy, so the waveform reveals left-to-right as it decodes.
  static const int targetWaveformSamples = waveformBarCount;

  /// Warmup and the visible bars share one decode per filename.
  final Map<String, _ProgressiveWaveform> _progressive = {};

  /// Completed waveforms keyed by filename, so an already-decoded song renders
  /// immediately on a later open without another disk read.
  final Map<String, List<double>> _memoryCache = {};

  /// Synchronous lookup of an already-decoded waveform, so the player bar can
  /// paint it on the very first frame without an async/disk round-trip.
  List<double>? cachedWaveformSync(String filename) => _memoryCache[filename];

  /// Fast check if the waveform for [filename] is cached and readable, in memory
  /// or on disk. An unusable entry is deleted so the decode repairs it.
  Future<bool> isWaveformCached(String filename) async {
    if (filename.isEmpty) return false;
    if (_memoryCache.containsKey(filename)) return true;
    final samples = _readCache(await _cacheService.waveformFile(filename));
    if (samples == null) return false;
    // The caller asks this before it subscribes, so the read that proved the
    // entry usable is also the one its first paint can use.
    _memoryCache[filename] = samples;
    return true;
  }

  /// Bars from [file], or null when the entry is missing, truncated or retired.
  /// An unusable file is removed so nothing reads it again.
  List<double>? _readCache(File file) {
    final samples = readWaveformCacheFile(file.path);
    if (samples != null) return samples;
    try {
      if (file.existsSync()) file.deleteSync();
    } on FileSystemException {
      // A file that will not delete is replaced by the next atomic write.
    }
    return null;
  }

  /// Produces and caches [filename]'s waveform in the background.
  ///
  /// Playback calls this so the seek bar already has its bars the first time
  /// the player is opened, instead of decoding while the user watches. Errors
  /// are swallowed: a waveform is decoration, never a reason to fail a play.
  Future<void> warm(String filename, String path, {Duration? duration}) async {
    if (filename.isEmpty || path.isEmpty) return;
    try {
      await getWaveformProgressive(filename, path, duration ?? Duration.zero)
          .last;
    } on Object catch (error) {
      debugPrint('WaveformService: warm failed for $filename: $error');
    }
  }

  Future<List<double>> getWaveform(String filename, String path) =>
      getWaveformProgressive(filename, path, Duration.zero).last;

  /// Emits the waveform for [filename] as it is produced: a cached song yields
  /// its full list once, an uncached one yields partial lists then the whole.
  Stream<List<double>> getWaveformProgressive(
    String filename,
    String path,
    Duration total,
  ) {
    final cached = _memoryCache[filename];
    if (cached != null) return Stream.value(cached);

    final existing = _progressive[filename];
    if (existing != null) return existing.attach();

    final state = _ProgressiveWaveform();
    _progressive[filename] = state;
    unawaited(() async {
      try {
        await _runProgressive(filename, path, total, state);
      } on Object catch (error, stack) {
        // A stream that closes without an event leaves the bar drawing a flat
        // line for the whole session, so a failure is forwarded.
        debugPrint(
            'WaveformService: progressive load failed for $filename: $error');
        state.addError(error, stack);
      } finally {
        // Unregister before closing, so a request landing right after the cache
        // write reads the cache instead of this finished stream.
        _progressive.remove(filename);
        await state.close();
      }
    }());
    return state.attach();
  }

  Future<void> _runProgressive(
    String filename,
    String path,
    Duration total,
    _ProgressiveWaveform state,
  ) async {
    if (path.isEmpty || path.startsWith('http')) {
      state.add(const []);
      return;
    }

    final cacheFile = await _cacheService.waveformFile(filename);
    final onDisk = _readCache(cacheFile);
    if (onDisk != null) {
      _memoryCache[filename] = onDisk;
      state.add(onDisk);
      return;
    }

    final samples = await MediaDecodeGate.run(
      () => _decodeWaveform(path, total, state.add),
      priority: MediaDecodePriority.high,
    );
    state.add(samples);
    if (samples.isEmpty) return;
    _memoryCache[filename] = samples;

    if (!await _isolateWriteWaveformCache(cacheFile.path, samples)) {
      debugPrint('WaveformService: could not cache $filename');
    }
  }

  Future<List<double>> _decodeWaveform(
    String path,
    Duration total,
    void Function(List<double>) onPartial,
  ) async {
    if (total <= Duration.zero) {
      return NativeAccel.decodeWaveformInBackground(
        path,
        targetSamples: targetWaveformSamples,
        duration: total,
      );
    }
    final port = ReceivePort();
    final subscription = port.listen((message) {
      if (message is List) onPartial(message.cast<double>());
    });
    try {
      return await NativeAccel.decodeWaveformInBackground(
        path,
        targetSamples: targetWaveformSamples,
        duration: total,
        partial: port.sendPort,
      );
    } finally {
      await subscription.cancel();
      port.close();
    }
  }

  void dispose() {}
}

Future<bool> _isolateWriteWaveformCache(String path, List<double> samples) {
  return Isolate.run(() => writeWaveformCacheFile(path, samples));
}

/// One in-flight progressive decode, shared by everyone drawing the song. A late
/// subscriber is handed the latest snapshot first, instead of nothing.
class _ProgressiveWaveform {
  final StreamController<List<double>> _controller =
      StreamController<List<double>>.broadcast();
  List<double>? _latest;

  void add(List<double> peaks) {
    if (peaks.isEmpty && _latest != null && _latest!.isNotEmpty) return;
    _latest = peaks;
    if (!_controller.isClosed) _controller.add(peaks);
  }

  void addError(Object error, StackTrace stack) {
    if (!_controller.isClosed) _controller.addError(error, stack);
  }

  Stream<List<double>> attach() {
    final snapshot = _latest;
    if (snapshot == null) return _controller.stream;
    return Stream<List<double>>.multi((sink) {
      sink.add(snapshot);
      final subscription = _controller.stream.listen(
        sink.add,
        onError: sink.addError,
        onDone: sink.close,
      );
      sink.onCancel = subscription.cancel;
    });
  }

  Future<void> close() async {
    if (!_controller.isClosed) await _controller.close();
  }
}
