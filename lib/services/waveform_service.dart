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

  /// The rate the bar decode runs at: four thousand mono samples a second is
  /// all a few hundred bars can show.
  static const int _waveformSampleRate = 4000;

  /// PCM bytes the decode writes per second: 4000 Hz, mono, 16-bit.
  static const int _pcmBytesPerSecond = _waveformSampleRate * 2;

  /// One decode at a time. Parallel FFmpeg sessions fight the audio thread.
  Future<void> _chain = Future.value();

  final Map<String, Future<List<double>>> _inFlight = {};

  /// Progressive decodes keyed by filename, so re-subscribing mid-decode shares
  /// one decode instead of starting a second FFmpeg session for the same song.
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
  Future<void> warm(String filename, String path) async {
    if (filename.isEmpty || path.isEmpty) return;
    try {
      await getWaveform(filename, path);
    } on Object catch (error) {
      debugPrint('WaveformService: warm failed for $filename: $error');
    }
  }

  Future<List<double>> getWaveform(String filename, String path) {
    if (path.isEmpty || path.startsWith('http')) {
      return Future.value(const []);
    }

    final existing = _inFlight[filename];
    if (existing != null) return existing;

    final work = _chain.then((_) => _getWaveform(filename, path));
    _chain = work.then((_) {}, onError: (_) {});
    _inFlight[filename] = work;
    work.whenComplete(() => _inFlight.remove(filename));
    return work;
  }

  Future<List<double>> _getWaveform(String filename, String path) async {
    final cached = _memoryCache[filename];
    if (cached != null) return cached;

    final cacheFile = await _cacheService.waveformFile(filename);
    final onDisk = _readCache(cacheFile);
    if (onDisk != null) {
      _memoryCache[filename] = onDisk;
      return onDisk;
    }

    final samples = await _extractWaveformFast(path);
    if (samples.isEmpty) return const [];

    _memoryCache[filename] = samples;
    if (!await _isolateWriteWaveformCache(cacheFile.path, samples)) {
      debugPrint('WaveformService: could not cache $filename');
    }

    return samples;
  }

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

    final samples = await _extractWaveformProgressive(
      path,
      total,
      state.add,
    );
    if (samples.isEmpty) return;
    _memoryCache[filename] = samples;
    state.add(samples);

    if (!await _isolateWriteWaveformCache(cacheFile.path, samples)) {
      debugPrint('WaveformService: could not cache $filename');
    }
  }

  Future<List<double>> _extractWaveformFast(String path) {
    return _extractWaveformStream(
      path: path,
      total: Duration.zero,
      onPartial: null,
    );
  }

  Future<List<double>> _extractWaveformProgressive(
    String path,
    Duration total,
    void Function(List<double>) onPartial,
  ) {
    return _extractWaveformStream(
      path: path,
      total: total,
      onPartial: onPartial,
    );
  }

  /// Decodes straight to the bar rate inside the native core: no subprocess on
  /// desktop, no FFmpegKit session on mobile, no temp PCM file.
  Future<List<double>> _extractWaveformStream({
    required String path,
    required Duration total,
    void Function(List<double>)? onPartial,
  }) {
    return MediaDecodeGate.run(
      () => _decodeWaveform(path: path, total: total, onPartial: onPartial),
      priority: MediaDecodePriority.high,
    );
  }

  Future<List<double>> _decodeWaveform({
    required String path,
    required Duration total,
    void Function(List<double>)? onPartial,
  }) async {
    final targetSamples = targetWaveformSamples;
    // The player's duration, when known, says how much of the song a prefix
    // covers, so a partial reveal lands where the final shape will.
    final expectedBytes = total.inMilliseconds > 0
        ? (total.inMilliseconds * _pcmBytesPerSecond) ~/ 1000
        : total.inSeconds * _pcmBytesPerSecond;

    final port = ReceivePort();
    final subscription = port.listen((message) {
      if (message is List) onPartial?.call(message.cast<double>());
    });
    try {
      final bytes = await Isolate.run(
        () => NativeAccel.decodePcm(
          path,
          _waveformSampleRate,
          peakSamples: targetSamples,
          expectedBytes: expectedBytes,
          onPartial:
              onPartial == null ? null : (bars) => port.sendPort.send(bars),
        ),
      );
      if (bytes.length < 2) return const [];
      return NativeAccel.waveformPeaks(bytes, targetSamples: targetSamples);
    } on NativeCommandException catch (error) {
      debugPrint('WaveformService: decode failed for $path: ${error.message}');
      return const [];
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
