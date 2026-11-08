import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new_min/ffmpeg_kit_config.dart';
import 'package:path/path.dart' as p;

import '../domain/services/cache_policy.dart';
import 'wispie_cache.dart';
import 'ffmpeg_service.dart';
import 'media_decode_gate.dart';

class WaveformService {
  final WispieCache _cacheService;

  WaveformService(this._cacheService);

  /// The fixed bar count every extracted waveform is bucketed into. Widgets use
  /// it to scale a partial emission (which carries fewer bars) to the width it
  /// should occupy, so the waveform reveals left-to-right as it decodes.
  static const int targetWaveformSamples = waveformBarCount;

  /// PCM bytes the decode writes per second: 4000 Hz, mono, 16-bit.
  static const int _pcmBytesPerSecond = 4000 * 2;

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

  /// Streams 16-bit mono PCM directly from FFmpeg's output pipe without writing
  /// uncompressed temp files to disk or polling file sizes.
  Future<List<double>> _extractWaveformStream({
    required String path,
    required Duration total,
    void Function(List<double>)? onPartial,
  }) {
    return MediaDecodeGate.run(
      () => _runWaveformStreamDecode(
        path: path,
        total: total,
        onPartial: onPartial,
      ),
      priority: MediaDecodePriority.high,
    );
  }

  Future<List<double>> _runWaveformStreamDecode({
    required String path,
    required Duration total,
    void Function(List<double>)? onPartial,
  }) async {
    final targetSamples = targetWaveformSamples;
    final expectedBytes = total.inMilliseconds > 0
        ? (total.inMilliseconds * _pcmBytesPerSecond) ~/ 1000
        : (total.inSeconds > 0 ? total.inSeconds * _pcmBytesPerSecond : 0);

    if (FFmpegService.usesSystemProcess) {
      return _decodeViaSystemProcessPipe(
        path: path,
        targetSamples: targetSamples,
        expectedBytes: expectedBytes,
        onPartial: onPartial,
      );
    } else {
      return _decodeViaMobilePipeOrFallback(
        path: path,
        targetSamples: targetSamples,
        expectedBytes: expectedBytes,
        onPartial: onPartial,
      );
    }
  }

  /// Decodes directly from FFmpeg's stdout stream pipe on Desktop/Linux.
  /// 100% event-driven push, zero disk writes, zero polling.
  Future<List<double>> _decodeViaSystemProcessPipe({
    required String path,
    required int targetSamples,
    required int expectedBytes,
    void Function(List<double>)? onPartial,
  }) async {
    final args = [
      '-threads',
      '1',
      '-i',
      path,
      '-vn',
      '-ac',
      '1',
      '-ar',
      '4000',
      '-f',
      's16le',
      '-',
    ];

    final process = await FFmpegService.instance.startFFmpeg(args);
    if (process == null) {
      debugPrint('FFmpegService: Failed to start ffmpeg process for streaming');
      return _failedWaveform(targetSamples);
    }

    final builder = BytesBuilder(copy: false);
    var lastEmittedBytes = 0;
    var lastEmitTime = DateTime.fromMillisecondsSinceEpoch(0);
    const int emitThresholdBytes = 3200;

    // FFmpeg names the real duration on stderr before it decodes, so a track
    // whose player duration is still unknown can reveal as it is read.
    var stderrBytes = 0;
    final stderrText = StringBuffer();
    unawaited(process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (String chunk) {
            if (stderrBytes > 0 || stderrText.length > 8192) return;
            stderrText.write(chunk);
            stderrBytes = _pcmBytesForDurationText(stderrText.toString()) ?? 0;
          },
          onError: (Object _) {},
        )
        .asFuture<void>()
        .catchError((Object _) {}));

    final completer = Completer<void>();
    final sub = process.stdout.listen(
      (chunk) {
        builder.add(chunk);
        final expected = expectedBytes > 0 ? expectedBytes : stderrBytes;
        if (onPartial != null && expected > 0) {
          final currentLen = builder.length;
          final now = DateTime.now();
          if (currentLen - lastEmittedBytes >= emitThresholdBytes &&
              now.difference(lastEmitTime).inMilliseconds >= 32) {
            lastEmitTime = now;
            lastEmittedBytes = currentLen;
            final bytesSnapshot = builder.toBytes();
            final peaks = progressiveWaveformPeaksFromS16Bytes(
              bytesSnapshot,
              targetSamples,
              expected,
            );
            if (peaks.isNotEmpty) onPartial(peaks);
          }
        }
      },
      onError: (e) {
        debugPrint('Waveform pipe stream error: $e');
      },
      onDone: () {
        if (!completer.isCompleted) completer.complete();
      },
      cancelOnError: false,
    );

    final exitCode = await process.exitCode;
    await completer.future;
    await sub.cancel();

    if (exitCode != 0) {
      debugPrint('FFmpeg streaming exited with code $exitCode');
      return _failedWaveform(targetSamples);
    }

    final fullBytes = builder.toBytes();
    if (fullBytes.length < 2) {
      return _failedWaveform(targetSamples);
    }

    return extractWaveformPeaksFromS16Bytes(fullBytes, targetSamples);
  }

  /// Decodes via named pipe on mobile platforms (iOS/Android), or falls back to temp file.
  Future<List<double>> _decodeViaMobilePipeOrFallback({
    required String path,
    required int targetSamples,
    required int expectedBytes,
    void Function(List<double>)? onPartial,
  }) async {
    String? pipePath;
    try {
      pipePath = await FFmpegKitConfig.registerNewFFmpegPipe();
    } catch (_) {
      pipePath = null;
    }

    if (pipePath != null) {
      try {
        final args = [
          '-threads',
          '1',
          '-i',
          path,
          '-vn',
          '-ac',
          '1',
          '-ar',
          '4000',
          '-f',
          's16le',
          '-y',
          pipePath,
        ];

        final builder = BytesBuilder(copy: false);
        var lastEmittedBytes = 0;
        var lastEmitTime = DateTime.fromMillisecondsSinceEpoch(0);
        const int emitThresholdBytes = 3200;

        final sessionCompleter = Completer<bool>();
        await FFmpegKit.executeWithArgumentsAsync(args, (session) async {
          final returnCode = await session.getReturnCode();
          sessionCompleter.complete(returnCode?.isValueSuccess() ?? false);
        });

        final pipeFile = File(pipePath);
        final stream = pipeFile.openRead();

        await for (final chunk in stream) {
          builder.add(chunk);
          if (onPartial != null && expectedBytes > 0) {
            final currentLen = builder.length;
            final now = DateTime.now();
            if (currentLen - lastEmittedBytes >= emitThresholdBytes &&
                now.difference(lastEmitTime).inMilliseconds >= 32) {
              lastEmitTime = now;
              lastEmittedBytes = currentLen;
              final bytesSnapshot = builder.toBytes();
              final peaks = progressiveWaveformPeaksFromS16Bytes(
                bytesSnapshot,
                targetSamples,
                expectedBytes,
              );
              if (peaks.isNotEmpty) onPartial(peaks);
            }
          }
        }

        final isSuccess = await sessionCompleter.future;
        if (!isSuccess) {
          return _failedWaveform(targetSamples);
        }

        final fullBytes = builder.toBytes();
        if (fullBytes.length < 2) {
          return _failedWaveform(targetSamples);
        }
        return extractWaveformPeaksFromS16Bytes(fullBytes, targetSamples);
      } catch (e) {
        debugPrint('Mobile pipe decode error: $e');
      } finally {
        try {
          await FFmpegKitConfig.closeFFmpegPipe(pipePath);
        } catch (_) {}
      }
    }

    // Fallback if named pipe unsupported
    return _decodeWithTempFileFallback(
      path: path,
      targetSamples: targetSamples,
    );
  }

  Future<List<double>> _decodeWithTempFileFallback({
    required String path,
    required int targetSamples,
  }) async {
    File? raw;
    try {
      final tempDir = await _cacheService.scratchDirectory();
      final outputPath = p.join(
        tempDir.path,
        'waveform_${DateTime.now().microsecondsSinceEpoch}.raw',
      );

      final args = [
        '-threads',
        '1',
        '-i',
        path,
        '-vn',
        '-ac',
        '1',
        '-ar',
        '4000',
        '-f',
        's16le',
        '-y',
        outputPath,
      ];

      final result = await FFmpegService.instance.executeFFmpeg(args);
      if (!result.isSuccess) {
        return _failedWaveform(targetSamples);
      }

      raw = File(outputPath);
      if (!await raw.exists()) {
        return _failedWaveform(targetSamples);
      }

      final bytes = await raw.readAsBytes();
      return extractWaveformPeaksFromS16Bytes(bytes, targetSamples);
    } catch (e) {
      debugPrint('Fallback waveform extraction failed: $e');
      return _failedWaveform(targetSamples);
    } finally {
      try {
        if (raw != null && await raw.exists()) await raw.delete();
      } catch (_) {}
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

/// Buckets 16-bit mono PCM [bytes] into [targetSamples] loudness bars.
///
/// Shared by the full and the progressive paths; both run off the UI isolate
/// and neither touches the file here — the caller provides the byte buffer.
List<double> extractWaveformPeaksFromS16Bytes(
  Uint8List bytes,
  int targetSamples,
) {
  if (bytes.length < 2) {
    return _failedWaveform(targetSamples);
  }

  final usable = bytes.length - (bytes.length % 2);
  final Int16List pcm;
  if (bytes.offsetInBytes % 2 == 0) {
    pcm = Int16List.view(bytes.buffer, bytes.offsetInBytes, usable ~/ 2);
  } else {
    pcm = Int16List.view(
      Uint8List.fromList(bytes.sublist(0, usable)).buffer,
    );
  }

  if (pcm.isEmpty) {
    return _failedWaveform(targetSamples);
  }

  return _loudnessBars(pcm, targetSamples);
}

/// Buckets below this RMS level are treated as silence.
const double _silenceFloorDb = -60;

/// Bounds on the dB span mapped onto the full bar height. The floor keeps a
/// brickwalled master from having its last 2 dB of variation blown up into
/// noise; the ceiling keeps a long quiet intro from flattening the rest.
const double _minDynamicRangeDb = 9;
const double _maxDynamicRangeDb = 30;

/// Per-bucket RMS loudness, normalised against the track's own dynamic range.
///
/// Raw sample peaks are useless on modern masters: limiting pins nearly every
/// bucket at full scale, so verses, choruses and breakdowns all read the same.
/// RMS in dB follows perceived loudness, and stretching the track's own
/// 5th..99th percentile span across the bar height makes sections distinct.
List<double> _loudnessBars(Int16List pcm, int targetSamples) {
  final db = Float64List(targetSamples);
  final length = pcm.length;
  for (var i = 0; i < targetSamples; i++) {
    final start = (i * length) ~/ targetSamples;
    var end = ((i + 1) * length) ~/ targetSamples;
    if (end <= start) end = math.min(length, start + 1);
    if (start >= length) {
      db[i] = double.negativeInfinity;
      continue;
    }
    var sumSquares = 0.0;
    for (var j = start; j < end; j++) {
      final v = pcm[j] / 32768.0;
      sumSquares += v * v;
    }
    final meanSquare = sumSquares / (end - start);
    db[i] = meanSquare <= 0
        ? double.negativeInfinity
        : 10 * math.log(meanSquare) / math.ln10;
  }

  final audible = <double>[
    for (final v in db)
      if (v > _silenceFloorDb) v,
  ]..sort();
  final samples = List<double>.filled(targetSamples, 0);
  if (audible.isEmpty) return samples;

  double at(double q) =>
      audible[math.min(audible.length - 1, (audible.length * q).floor())];
  final hi = at(0.99);
  var lo = at(0.05);
  final span = hi - lo;
  if (span < _minDynamicRangeDb) lo = hi - _minDynamicRangeDb;
  if (span > _maxDynamicRangeDb) lo = hi - _maxDynamicRangeDb;
  final range = hi - lo;

  for (var i = 0; i < targetSamples; i++) {
    final v = db[i];
    if (v <= _silenceFloorDb) continue;
    final normalized = ((v - lo) / range).clamp(0.0, 1.0);
    samples[i] = 0.04 + 0.96 * normalized;
  }
  return samples;
}

/// PCM byte count of an FFmpeg `Duration: hh:mm:ss.cc` log line.
int? _pcmBytesForDurationText(String text) {
  final match = RegExp(r'Duration:\s*(\d+):(\d{2}):(\d{2})').firstMatch(text);
  if (match == null) return null;
  final seconds = int.parse(match.group(1)!) * 3600 +
      int.parse(match.group(2)!) * 60 +
      int.parse(match.group(3)!);
  if (seconds <= 0) return null;
  return seconds * WaveformService._pcmBytesPerSecond;
}

/// Buckets the decoded-so-far PCM into the first [targetSamples] * (bytes /
/// [expectedBytes]) bars, so the waveform paints left-to-right as the file
/// decodes instead of waiting for the whole read.
List<double> progressiveWaveformPeaksFromS16Bytes(
  Uint8List bytes,
  int targetSamples,
  int expectedBytes,
) {
  final fraction =
      expectedBytes > 0 ? (bytes.length / expectedBytes).clamp(0.0, 1.0) : 1.0;
  final filled = (fraction * targetSamples).round().clamp(1, targetSamples);
  return extractWaveformPeaksFromS16Bytes(bytes, filled);
}

/// A failed decode yields no bars: synthetic peaks would be cached and drawn
/// as if they were this track's waveform.
List<double> _failedWaveform(int _) => const [];
