import 'debug_sandbox.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;

import '../domain/models/beat_map.dart';
import '../domain/services/beat_analysis.dart';
import '../models/song.dart';
import 'cache_service.dart';
import 'ffmpeg_service.dart';
import 'media_decode_gate.dart';
import 'online_audio_cache.dart';

/// Produces and caches the [BeatMap] for a song.
///
/// Deliberately a sibling of `WaveformService`: decode with ffmpeg, crunch in an
/// isolate, cache the result as JSON in the v3 cache directory. The expensive
/// part happens exactly once per song, so playback never does DSP.
class BeatAnalysisService {
  final CacheService _cacheService;

  BeatAnalysisService(this._cacheService);

  /// Decoding to 16-bit rather than float halves the temp file (a 4-minute
  /// track is 10 MB instead of 21 MB) and costs nothing that matters — the
  /// analyser works on log magnitudes, where 16-bit precision is far beyond
  /// what any of this resolves.
  static const String _pcmFormat = 's16le';

  /// Analyses can be several seconds of CPU. Running two at once on a phone
  /// just makes both slower and heats the device, so they queue.
  Future<void> _chain = Future.value();

  final Map<String, Future<BeatMap?>> _inFlight = {};

  final StreamController<String> _analyzed =
      StreamController<String>.broadcast();

  /// Filenames whose map just landed in the cache. A streamed track is only
  /// decodable once its download finished, which can be well after the screen
  /// asked for a map, so consumers re-read when their track shows up here.
  Stream<String> get analyzedFilenames => _analyzed.stream;

  /// Bounds how much speculative work can pile up if the user skips tracks
  /// rapidly. Prefetches beyond this are dropped rather than queued.
  static const int _maxQueuedPrefetch = 2;
  int _queuedPrefetch = 0;

  /// The cached map for [filename], or null if it has not been analysed yet.
  /// Never triggers analysis — for callers that want an instant answer.
  Future<BeatMap?> readCached(String filename) async {
    try {
      final file = await _cacheService.getBeatMapCacheFile(filename);
      if (!await file.exists()) return null;
      final json = jsonDecode(await file.readAsString());
      if (json is! Map<String, dynamic>) return null;
      return BeatMap.fromJson(json);
    } catch (e) {
      debugPrint('BeatAnalysisService: cache read failed for $filename: $e');
      return null;
    }
  }

  /// The [BeatMap] for [song], analysing it if needed.
  ///
  /// A streamed track has no local file to decode and `song.url` is an http
  /// URL, so the map is built from its cached download. The first play of a
  /// track writes that download while it streams, so this waits for it: the
  /// map then arrives seconds into playback instead of never.
  Future<BeatMap?> analyzeSong(Song song) async {
    if (!song.isRemote) return analyze(song.filename, song.url);

    final cached = await readCached(song.filename);
    if (cached != null) return cached;
    final id = song.isYoutube ? song.remoteId : null;
    if (id == null || id.isEmpty) return null;

    final file = await _streamedFile(id);
    if (file == null) return null;
    return analyze(song.filename, file.path);
  }

  /// Speculatively analyses [song] if its audio is already on disk.
  ///
  /// Unlike [analyzeSong] this never waits for a download: it is called on
  /// every track change, including the speculative look-ahead, and a pending
  /// wait per skipped track would pile up.
  void prefetchSong(Song song) {
    if (!song.isRemote) {
      prefetch(song.filename, song.url);
      return;
    }
    final id = song.isYoutube ? song.remoteId : null;
    if (id == null || id.isEmpty || _inFlight.containsKey(song.filename)) {
      return;
    }
    if (_queuedPrefetch >= _maxQueuedPrefetch) return;

    _queuedPrefetch++;
    unawaited(() async {
      try {
        final file = await OnlineAudioCache.instance
            .completeFile(OnlineAudioCache.providerYouTube, id);
        if (file == null) return;
        if (await readCached(song.filename) != null) return;
        await analyze(song.filename, file.path);
      } catch (e) {
        debugPrint(
            'BeatAnalysisService: prefetch failed for ${song.filename}: $e');
      } finally {
        _queuedPrefetch--;
      }
    }());
  }

  /// The complete download for [id], waiting for it to finish when it is still
  /// on its way. Returns null if nothing arrives within [_downloadWait].
  ///
  /// The subscription is opened before the file is checked, so a download that
  /// finishes between the check and the wait cannot be missed.
  Future<File?> _streamedFile(String id) async {
    final cache = OnlineAudioCache.instance;
    final done = Completer<void>();
    late final StreamSubscription<String> sub;
    sub = cache.completions.listen((completed) {
      if (completed != id || done.isCompleted) return;
      done.complete();
      unawaited(sub.cancel());
    });

    Future<File?> finish() async {
      await sub.cancel();
      return cache.completeFile(OnlineAudioCache.providerYouTube, id);
    }

    final existing =
        await cache.completeFile(OnlineAudioCache.providerYouTube, id);
    if (existing != null) return finish();

    try {
      await done.future.timeout(_downloadWait);
    } on TimeoutException {
      await sub.cancel();
      return null;
    }
    return finish();
  }

  /// A track longer than this is not going to finish while it is still worth
  /// analysing; the next play asks again.
  static const Duration _downloadWait = Duration(minutes: 20);

  /// The [BeatMap] for [filename], analysing and caching it if needed.
  ///
  /// Returns null when the file cannot be decoded. Concurrent calls for the same
  /// song share one analysis.
  Future<BeatMap?> analyze(String filename, String path) {
    if (path.isEmpty || path.startsWith('http')) return Future.value(null);

    final existing = _inFlight[filename];
    if (existing != null) return existing;

    final work = _chain.then((_) => _analyze(filename, path));
    // The chain must not break on failure, or every later analysis is dropped.
    _chain = work.then((_) {}, onError: (_) {});
    _inFlight[filename] = work;
    work.whenComplete(() => _inFlight.remove(filename));
    return work;
  }

  /// Speculatively analyses [filename] so it is ready when the track starts.
  /// Cheap to call repeatedly: already-cached songs return immediately.
  void prefetch(String filename, String path) {
    if (path.isEmpty || path.startsWith('http')) return;
    if (_inFlight.containsKey(filename)) return;
    if (_queuedPrefetch >= _maxQueuedPrefetch) return;

    _queuedPrefetch++;
    unawaited(() async {
      try {
        if (await readCached(filename) != null) return;
        await analyze(filename, path);
      } catch (e) {
        debugPrint('BeatAnalysisService: prefetch failed for $filename: $e');
      } finally {
        _queuedPrefetch--;
      }
    }());
  }

  Future<BeatMap?> _analyze(String filename, String path) async {
    final cached = await readCached(filename);
    if (cached != null) return cached;

    File? raw;
    try {
      raw = await _decodeToPcm(path);
      if (raw == null) return null;

      final rawPath = raw.path;
      final map = await _isolateAnalyzeRawFile(rawPath);
      if (map == null) return null;

      await _writeCache(filename, map);
      return map;
    } catch (e) {
      debugPrint('BeatAnalysisService: analysis failed for $filename: $e');
      return null;
    } finally {
      try {
        if (raw != null && await raw.exists()) await raw.delete();
      } catch (_) {}
    }
  }

  /// Decodes any supported audio file to raw mono PCM at the analyser's sample
  /// rate. No audio filters: `-af` filters like compand or loudnorm introduce
  /// lookahead delay, which would shift every detected beat.
  ///
  /// The decode goes through the shared gate so it never runs while a waveform
  /// (or another analysis) is mid-decode of the same file.
  Future<File?> _decodeToPcm(String path) {
    return MediaDecodeGate.run(() async {
      final supportDir = await getSupportDirectory();
      final tempDir = Directory(p.join(supportDir.path, 'beat_analysis_temp'));
      if (!await tempDir.exists()) await tempDir.create(recursive: true);

      final outputPath = p.join(
        tempDir.path,
        'pcm_${DateTime.now().microsecondsSinceEpoch}.raw',
      );

      final result = await FFmpegService.instance.executeFFmpeg([
        '-threads', '1', // leave headroom for the audio callback
        '-i', path,
        '-vn', // ignore cover art and video streams
        '-ac', '1', // mono
        '-ar', '$analysisSampleRate',
        '-f', _pcmFormat,
        '-y', outputPath,
      ]);

      final file = File(outputPath);

      if (!result.isSuccess) {
        if (kDebugMode) {
          debugPrint(
              'BeatAnalysisService: ffmpeg decode failed (${result.returnCode}) for $path\n${result.logs}');
        }
        try {
          if (await file.exists()) await file.delete();
        } catch (_) {}
        return null;
      }

      if (!await file.exists() || await file.length() == 0) return null;
      return file;
    });
  }

  Future<void> _writeCache(String filename, BeatMap map) async {
    try {
      final file = await _cacheService.getBeatMapCacheFile(filename);
      await file.writeAsString(jsonEncode(map.toJson()));
      _analyzed.add(filename);
    } catch (e) {
      debugPrint('BeatAnalysisService: cache write failed for $filename: $e');
    }
  }

  /// Clears every cached beat map. Used by storage management.
  Future<void> clearCache() async {
    await BeatAnalysisService.clearCachedMaps();
  }

  static Future<void> clearCachedMaps() async {
    final supportDir = await getSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'gru_cache_v3'));
    if (!await dir.exists()) return;
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (name.startsWith('beatmap_') && name.endsWith('.json')) {
        try {
          await entity.delete();
        } catch (_) {}
      }
    }
  }

  void dispose() {}
}

/// Runs in a background isolate: reads the decoded PCM and analyses it.
///
/// The file is read here rather than in the caller so the main isolate never
/// holds the ~10 MB sample buffer.
Future<BeatMap?> _isolateAnalyzeRawFile(String rawPath) {
  return Isolate.run(() => _analyzeRawFile(rawPath));
}

BeatMap? _analyzeRawFile(String rawPath) {
  try {
    final bytes = File(rawPath).readAsBytesSync();
    if (bytes.length < 4) return null;

    // Trim any trailing partial frame before viewing as 16-bit, and copy when
    // the buffer is not 2-byte aligned — Int16List.view demands alignment.
    final usable = bytes.length - (bytes.length % 2);
    final Int16List pcm;
    if (bytes.offsetInBytes % 2 == 0) {
      pcm = Int16List.view(bytes.buffer, bytes.offsetInBytes, usable ~/ 2);
    } else {
      pcm = Int16List.view(
        Uint8List.fromList(bytes.sublist(0, usable)).buffer,
      );
    }

    final samples = Float32List(pcm.length);
    for (var i = 0; i < pcm.length; i++) {
      samples[i] = pcm[i] / 32768.0;
    }

    return analyzeBeats(samples);
  } catch (_) {
    return null;
  }
}
