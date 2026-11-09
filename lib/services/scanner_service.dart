import 'debug_sandbox.dart';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import '../models/song.dart';
import 'database_service.dart';
import '../domain/services/embedded_cover_bytes.dart';
import '../domain/services/media_formats.dart';
import '../domain/services/search_service.dart';
import 'storage_service.dart';
import 'ffmpeg_service.dart';
import 'cover_refresh_service.dart';
import 'media_decode_gate.dart';
import 'permission_service.dart';
import 'storage_probe_service.dart';
import 'media_store_service.dart';
import '../data/rust/rust_library_tasks.dart';

/// Why a scan produced the songs it did.
///
/// The distinction matters because an empty song list is ambiguous: it can mean
/// "the folder really is empty" or "we could not look inside it". Only the
/// former may replace an existing library — every listing/read failure is
/// reported as [ScanStatus.folderUnavailable] instead.
enum ScanStatus {
  /// Every requested folder was listed successfully.
  ok,

  /// Storage permission was not granted, so nothing was listed.
  noPermission,

  /// A folder is missing, unmounted, or failed to list.
  folderUnavailable,
}

class ScanResult {
  final List<Song> songs;
  final ScanStatus status;

  const ScanResult(this.songs, this.status);

  const ScanResult.ok(this.songs) : status = ScanStatus.ok;

  const ScanResult.failed(this.status) : songs = const [];

  bool get trusted => status == ScanStatus.ok;
}

/// Outcome of a native cover sweep.
class CoverSweepResult {
  const CoverSweepResult(this.songs, {required this.completed});

  final List<Song> songs;

  /// False when the sweep stopped early; a caller must not record misses then.
  final bool completed;
}

class _ScanParams {
  final List<String> paths;
  final List<String> excludedFolders;
  final List<Song>? existingSongs;
  final String coversDirPath;
  final Map<String, int> playCounts;
  final SendPort sendPort;
  final bool includeVideos;
  final int minimumFileSizeBytes;
  final bool fastMode;

  _ScanParams({
    required this.paths,
    required this.excludedFolders,
    this.existingSongs,
    required this.coversDirPath,
    required this.playCounts,
    required this.sendPort,
    this.includeVideos = true,
    this.minimumFileSizeBytes = 0,
    this.fastMode = false,
  });
}

class ScannerService {
  /// Whether [path] is a media file the library would index.
  ///
  /// Delegated so the scanner, the storage probe and the folder comparison
  /// cannot disagree about what a song is.
  static bool isSupportedMediaPath(String path) =>
      MediaFormats.isSupportedPath(path);

  static bool _isVideoFile(String path) {
    final ext = p.extension(path).toLowerCase();
    return Song.videoExtensions.contains(ext);
  }

  /// Suffixes a cached cover can carry, in preference order.
  ///
  /// `_ffmpeg.jpg` belongs here as much as the plain extensions do: it is where
  /// the FFmpeg fallback writes, and any probe that omits it decides a song has
  /// no cached cover when it plainly does — then re-extracts, or worse, records
  /// the absence.
  static const List<String> coverExtensionCandidates = [
    '.jpg',
    '.jpeg',
    '.png',
    '.webp',
    '.bmp',
    '_ffmpeg.jpg',
  ];

  /// The one directory cached covers live in, created if missing.
  static Future<Directory> coversDirectory() async {
    final supportDir = await getSupportDirectory();
    final dir = Directory(p.join(supportDir.path, 'extracted_covers'));
    if (!await dir.exists()) {
      await dir.create(recursive: true);
    }
    return dir;
  }

  /// Every path a cached cover for [filename] could occupy, given a covers
  /// directory of [coversDirPath].
  static List<String> coverCandidatePaths(
      String coversDirPath, String filename) {
    final key = coverKeyForFilename(filename);
    return [
      for (final ext in coverExtensionCandidates)
        p.join(coversDirPath, '$key$ext'),
    ];
  }

  static Future<bool> _isValidCoverFile(
    File file, {
    bool requireDecodable = false,
  }) async {
    RandomAccessFile? handle;
    try {
      if (!await file.exists()) return false;
      if (await file.length() <= 0) return false;

      // Cheapest useful check, and the one that catches covers cached by older
      // builds: those hold a real image preceded by the tail of its picture
      // frame's description, so they are the right size but decode as nothing.
      handle = await file.open();
      final head = await handle.read(imageSignatureProbeLength);
      if (!hasImageSignature(head)) return false;
      if (!requireDecodable) return true;

      final bytes = await file.readAsBytes();
      if (bytes.isEmpty) return false;
      final decoded = img.decodeImage(bytes);
      return decoded != null && decoded.width > 0 && decoded.height > 0;
    } catch (_) {
      return false;
    } finally {
      await handle?.close();
    }
  }

  /// Extracts video thumbnails (via FFmpeg frame grab) for any video-format
  /// songs that still have no cover art. This must be called on the main thread
  /// after scanning because FFmpegService uses platform channels.
  ///
  /// Returns a new list of [Song] objects with updated [coverUrl] values.
  /// Songs that already have a cover (or are not video files) are returned
  /// unchanged. [onProgress] receives values in [0, 1].
  Future<List<Song>> postProcessVideoThumbnails(
    List<Song> songs, {
    void Function(double progress)? onProgress,
  }) async {
    final supportDir = await getSupportDirectory();
    final coversDir = Directory(p.join(supportDir.path, 'extracted_covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    // Only process video songs that are missing a cover.
    final toProcess = <int>[];
    for (int i = 0; i < songs.length; i++) {
      final song = songs[i];
      if (!_isVideoFile(song.url)) continue;
      final file = File(song.url);
      if (!await file.exists()) continue;

      final hash = coverKeyForFilename(file.path);

      final existingCoverPath = song.coverUrl;
      if (existingCoverPath != null && existingCoverPath.isNotEmpty) {
        final existing = File(existingCoverPath);
        final isSongScopedCachedCover =
            p.basename(existingCoverPath).startsWith(hash);
        if (isSongScopedCachedCover &&
            await _isValidCoverFile(existing, requireDecodable: true)) {
          continue;
        }
      }
      toProcess.add(i);
    }

    if (toProcess.isEmpty) return songs;

    final updated = List<Song>.from(songs);
    final ffmpeg = FFmpegService();

    for (int j = 0; j < toProcess.length; j++) {
      final idx = toProcess[j];
      final song = updated[idx];
      try {
        final file = File(song.url);
        if (!await file.exists()) continue;

        final hash = coverKeyForFilename(file.path);

        // Check if a cached cover already exists (may have been created by a
        // parallel path we aren't aware of).
        String? existing;
        for (final candidatePath
            in coverCandidatePaths(coversDir.path, file.path)) {
          final candidate = File(candidatePath);
          if (await _isValidCoverFile(candidate, requireDecodable: true)) {
            existing = candidate.path;
            break;
          }
        }

        if (existing != null) {
          updated[idx] = _songWithCover(song, existing);
        } else {
          final outputPath = p.join(coversDir.path, '${hash}_ffmpeg.jpg');
          // Use extractVideoThumbnail — NOT extractCover.
          // extractCover does a stream-copy of 0:v:0 which works for audio
          // files whose video stream is an attached picture, but for real
          // video files that stream is H.264/VP9/etc. and cannot be copied
          // into a JPEG. extractVideoThumbnail grabs the 5th decoded frame
          // instead.
          final result = await _extractVideoThumbnailWithFallback(
            inputPath: file.path,
            outputPath: outputPath,
            ffmpeg: ffmpeg,
          );
          if (result != null) {
            updated[idx] = _songWithCover(song, result);
            debugPrint(
                'postProcessVideoThumbnails: extracted thumbnail for ${song.title}');
          }
        }
      } catch (e) {
        debugPrint('postProcessVideoThumbnails: failed for ${song.title}: $e');
      }

      onProgress?.call((j + 1) / toProcess.length);
    }

    return updated;
  }

  static Song _songWithCover(Song song, String coverPath) {
    return Song(
      title: song.title,
      artist: song.artist,
      album: song.album,
      filename: song.filename,
      url: song.url,
      coverUrl: coverPath,
      hasLyrics: song.hasLyrics,
      playCount: song.playCount,
      duration: song.duration,
      mtime: song.mtime,
      createdEpochSec: song.createdEpochSec,
      songDateEpochSec: song.songDateEpochSec,
    );
  }

  /// Scans a specific directory for audio files (backward compatibility).
  Future<ScanResult> scanDirectory(
    String path, {
    List<Song>? existingSongs,
    String? lyricsPath,
    Map<String, int>? playCounts,
    void Function(double progress)? onProgress,
    void Function(List<Song>)? onComplete,
    void Function(List<Song>)? onSongsDiscovered,
    bool includeVideos = true,
    int minimumFileSizeBytes = 0,
    bool fastMode = false,
  }) async {
    // Check for storage permission
    if (Platform.isAndroid) {
      final hasPermission =
          await PermissionService.instance.hasStoragePermission();
      if (!hasPermission) {
        debugPrint('Storage permissions not granted. Cannot scan directory.');
        return const ScanResult.failed(ScanStatus.noPermission);
      }
    }

    final dir = Directory(path);
    if (!await dir.exists()) {
      debugPrint('Music folder unavailable: $path');
      return const ScanResult.failed(ScanStatus.folderUnavailable);
    }

    // Pre-scan probe: listing may succeed while every read is denied (wrong
    // mount, SD-card volume, legacy permission missing). Importing hundreds
    // of filename-only rows in that state clobbers good metadata and yields
    // unplayable tracks, so refuse to replace the library instead.
    final probe = await StorageProbeService().probeFolder(path);
    if (!probe.listed) {
      debugPrint(
          'Music folder not listable: $path (${probe.listError ?? 'unknown'})');
      return const ScanResult.failed(ScanStatus.folderUnavailable);
    }
    List<String> effectivePaths = [path];
    if (probe.nothingReadable) {
      debugPrint(
          'Music folder lists but reads fail: $path (${probe.readError ?? 'unknown'}). Trying MediaStore fallback.');
      final fallback = await _mediaStoreFallbackPaths(path);
      if (fallback.isEmpty) {
        return const ScanResult.failed(ScanStatus.folderUnavailable);
      }
      effectivePaths = fallback;
    }

    final storage = StorageService();
    final excludedFolders = await storage.getExcludedFolders();
    final effectivePlayCounts =
        playCounts ?? await DatabaseService.instance.getPlayCounts();

    final supportDir = await getSupportDirectory();
    final coversDir = Directory(p.join(supportDir.path, 'extracted_covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final receivePort = ReceivePort();
    final params = _ScanParams(
      paths: effectivePaths,
      excludedFolders: excludedFolders,
      existingSongs: existingSongs,
      coversDirPath: coversDir.path,
      playCounts: effectivePlayCounts,
      sendPort: receivePort.sendPort,
      includeVideos: includeVideos,
      minimumFileSizeBytes: minimumFileSizeBytes,
      fastMode: fastMode,
    );

    await _startScan(params);

    final completer = Completer<ScanResult>();
    final List<Song> allScannedSongs = [];
    // Set if the isolate reports a folder it could not list. A single
    // unreachable folder taints the whole scan so its empty result can never
    // clobber an existing library.
    bool folderUnavailable = false;
    int unreadableFiles = 0;

    receivePort.listen((message) async {
      if (message is double) {
        onProgress?.call(message);
      } else if (message is List<Song>) {
        allScannedSongs.addAll(message);
        // Incremental DB insert to save memory and keep UI responsive
        await DatabaseService.instance.insertSongsBatch(message);
        onSongsDiscovered?.call(message);
      } else if (message is String && message.startsWith('unreachable:')) {
        folderUnavailable = true;
      } else if (message is String && message.startsWith('unreadable:')) {
        unreadableFiles += int.tryParse(message.split(':').last) ?? 0;
      } else if (message == 'done') {
        // Every file listed but none parsed means reads are denied, not that
        // the tags are empty. Report unavailable so the caller never swaps a
        // good library for filename-only rows.
        final allUnreadable = allScannedSongs.isNotEmpty &&
            unreadableFiles >= allScannedSongs.length;
        final status = (folderUnavailable || allUnreadable)
            ? ScanStatus.folderUnavailable
            : ScanStatus.ok;
        if (unreadableFiles > 0) {
          debugPrint(
              'Scanner: $unreadableFiles/${allScannedSongs.length} files fell back to filename (unreadable or untagged)');
        }
        if (!fastMode) {
          try {
            final searchService = SearchService();
            await searchService.init();
            await searchService.rebuildIndex(allScannedSongs);
            debugPrint(
                'Search index rebuilt with ${allScannedSongs.length} songs');
          } catch (e) {
            debugPrint('Error rebuilding search index: $e');
          }
          // Extract thumbnails for video files on the main thread using FFmpeg.
          // This must happen here (not in the isolate) because FFmpegService
          // uses platform channels.
          List<Song> finalSongs = allScannedSongs;
          try {
            finalSongs = await postProcessVideoThumbnails(allScannedSongs);
            // Persist any newly-extracted cover URLs back to the DB.
            final updated = <Song>[];
            for (int i = 0; i < finalSongs.length; i++) {
              if (finalSongs[i].coverUrl != allScannedSongs[i].coverUrl) {
                updated.add(finalSongs[i]);
              }
            }
            if (updated.isNotEmpty) {
              await DatabaseService.instance.insertSongsBatch(updated);
              debugPrint(
                  'Video thumbnails extracted for ${updated.length} songs');
            }
          } catch (e) {
            debugPrint('Error post-processing video thumbnails: $e');
            finalSongs = allScannedSongs;
          }
          onComplete?.call(finalSongs);
          completer.complete(ScanResult(finalSongs, status));
        } else {
          onComplete?.call(allScannedSongs);
          completer.complete(ScanResult(allScannedSongs, status));
        }
        receivePort.close();
      } else if (message is String && message.startsWith('error:')) {
        receivePort.close();
        completer.completeError(message);
      }
    }, onError: (e) {
      receivePort.close();
      completer.completeError(e);
    });

    return completer.future;
  }

  /// MediaStore fallback: distinct readable parent folders under [requestedPath].
  ///
  /// On some devices (Huawei mounts, SD-card volumes) dart:io lists a folder
  /// but every byte read is denied, while MediaStore still knows the real
  /// paths. Returns an empty list when the fallback has nothing usable.
  static Future<List<String>> _mediaStoreFallbackPaths(
      String requestedPath) async {
    if (!Platform.isAndroid) return const [];
    final entries = await MediaStoreService().queryAudioEntries();
    if (entries.isEmpty) return const [];
    final Set<String> parents = {};
    for (final entry in entries) {
      final filePath = entry.filePath;
      if (filePath == null || filePath.isEmpty) continue;
      if (!(p.isWithin(requestedPath, filePath) ||
          p.equals(requestedPath, filePath))) {
        continue;
      }
      final file = File(filePath);
      bool readable = false;
      try {
        readable = await file.exists();
        if (readable) {
          final raf = await file.open(mode: FileMode.read);
          try {
            await raf.readByte();
          } finally {
            await raf.close();
          }
        }
      } on FileSystemException catch (e) {
        debugPrint('MediaStore fallback unreadable $filePath: $e');
        continue;
      } on OSError catch (e) {
        debugPrint('MediaStore fallback unreadable $filePath: $e');
        continue;
      }
      if (readable) parents.add(p.dirname(filePath));
    }
    return parents.toList();
  }

  /// Scans the entire device for audio files, respecting excluded folders.
  Future<List<Song>> scanDevice({
    List<Song>? existingSongs,
    List<Map<String, String>>? lyricsFolders,
    Map<String, int>? playCounts,
    void Function(double progress)? onProgress,
    void Function(List<Song>)? onComplete,
    void Function(List<Song>)? onSongsDiscovered,
    bool fastMode = false,
    bool includeVideos = true,
    int minimumFileSizeBytes = 0,
  }) async {
    // Check for storage access permission
    if (Platform.isAndroid) {
      final hasPermission =
          await PermissionService.instance.hasStoragePermission();
      if (!hasPermission) {
        debugPrint('Storage access permission not granted. Cannot scan.');
        return [];
      }
    }

    final storage = StorageService();
    final excludedFolders = await storage.getExcludedFolders();
    final effectivePlayCounts =
        playCounts ?? await DatabaseService.instance.getPlayCounts();

    // Determine scan paths based on platform
    final List<String> scanPaths = [];
    if (Platform.isAndroid) {
      // Common storage locations on Android
      scanPaths.addAll([
        '/storage/emulated/0',
        '/storage/emulated/0/Music',
        '/storage/emulated/0/Download',
      ]);
    } else if (Platform.isMacOS) {
      scanPaths.addAll([
        '${Platform.environment['HOME']}/Music',
        '/Users',
      ]);
    } else if (Platform.isWindows) {
      scanPaths.addAll([
        Platform.environment['USERPROFILE'] ?? '',
      ]);
    } else if (Platform.isLinux) {
      scanPaths.addAll([
        '${Platform.environment['HOME']}/Music',
        '${Platform.environment['HOME']}',
      ]);
    }

    // Filter to only existing paths
    final validPaths = scanPaths.where((path) {
      if (path.isEmpty) return false;
      final dir = Directory(path);
      return dir.existsSync();
    }).toList();

    if (validPaths.isEmpty) {
      debugPrint('No valid scan paths found.');
      return [];
    }

    final supportDir = await getSupportDirectory();
    final coversDir = Directory(p.join(supportDir.path, 'extracted_covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    final receivePort = ReceivePort();
    final params = _ScanParams(
      paths: validPaths,
      excludedFolders: excludedFolders,
      existingSongs: existingSongs,
      coversDirPath: coversDir.path,
      playCounts: effectivePlayCounts,
      sendPort: receivePort.sendPort,
      fastMode: fastMode,
      includeVideos: includeVideos,
      minimumFileSizeBytes: minimumFileSizeBytes,
    );

    await _startScan(params);

    final completer = Completer<List<Song>>();
    final List<Song> allScannedSongs = [];

    receivePort.listen((message) async {
      if (message is double) {
        onProgress?.call(message);
      } else if (message is List<Song>) {
        allScannedSongs.addAll(message);
        // Incremental DB insert
        await DatabaseService.instance.insertSongsBatch(message);
        onSongsDiscovered?.call(message);
      } else if (message == 'done') {
        if (!fastMode) {
          // Rebuild search index after scanning
          try {
            final searchService = SearchService();
            await searchService.init();
            await searchService.rebuildIndex(allScannedSongs);
            debugPrint(
                'Search index rebuilt with ${allScannedSongs.length} songs');
          } catch (e) {
            debugPrint('Error rebuilding search index: $e');
          }
          // Extract thumbnails for video files on the main thread using FFmpeg.
          List<Song> finalSongs = allScannedSongs;
          try {
            finalSongs = await postProcessVideoThumbnails(allScannedSongs);
            final updated = <Song>[];
            for (int i = 0; i < finalSongs.length; i++) {
              if (finalSongs[i].coverUrl != allScannedSongs[i].coverUrl) {
                updated.add(finalSongs[i]);
              }
            }
            if (updated.isNotEmpty) {
              await DatabaseService.instance.insertSongsBatch(updated);
              debugPrint(
                  'Video thumbnails extracted for ${updated.length} songs');
            }
          } catch (e) {
            debugPrint('Error post-processing video thumbnails: $e');
            finalSongs = allScannedSongs;
          }
          onComplete?.call(finalSongs);
          completer.complete(finalSongs);
        } else {
          onComplete?.call(allScannedSongs);
          completer.complete(allScannedSongs);
        }
        receivePort.close();
      } else if (message is String && message.startsWith('error:')) {
        receivePort.close();
        completer.completeError(message);
      }
    }, onError: (e) {
      receivePort.close();
      completer.completeError(e);
    });

    return completer.future;
  }

  /// Enriches minimal song records and fills in their missing cover art.
  ///
  /// Both come from one open of each file on the native core's workers; only
  /// the DB write and the progress callback stay on this isolate, since sqflite
  /// is not usable from a spawned one.
  static Future<List<Song>> enrichAllMetadata(
    List<Song> songs, {
    void Function(double progress)? onProgress,
    void Function(List<Song> enrichedBatch)? onBatchEnriched,
  }) {
    return _enrichOnCore(songs,
        onProgress: onProgress, onBatchEnriched: onBatchEnriched);
  }

  /// Extracts or repairs cover art for [songs], on the native core.
  ///
  /// A row whose cover file is missing or unusable is re-extracted. The sweep's
  /// [CoverSweepResult.completed] flag is false when it stopped early, so a
  /// caller never records a miss it did not actually establish.
  static Future<CoverSweepResult> extractCoversInBackground(
    List<Song> songs, {
    void Function(double progress)? onProgress,
    void Function(List<Song> updatedSongs)? onBatchExtracted,
  }) {
    return _extractCoversOnCore(songs,
        onProgress: onProgress, onBatchExtracted: onBatchExtracted);
  }

  /// Songs worth sending to a cover sweep: not a video, not a miss recorded for
  /// this exact file version, and without a cover file on disk.
  static Future<List<Song>> coverGaps(List<Song> songs) async {
    Map<String, double> misses;
    try {
      misses = await DatabaseService.instance.getCoverMisses();
    } catch (_) {
      misses = const {};
    }

    Future<bool> present(String path) async {
      try {
        final file = File(path);
        return await file.exists() && await file.length() > 0;
      } catch (_) {
        return false;
      }
    }

    final gaps = <Song>[];
    for (final song in songs) {
      if (_isVideoFile(song.url)) continue;
      final miss = misses[song.filename];
      final mtime = song.mtime;
      if (miss != null && mtime != null && (miss - mtime).abs() < 2.0) continue;
      final cover = song.coverUrl;
      if (cover == null || cover.isEmpty || !await present(cover)) {
        gaps.add(song);
      }
    }
    return gaps;
  }

  /// Extracts cover art for a single song on demand.
  /// Used for lazy cover extraction — only called when a song's cover is
  /// first viewed. Avoids the cost of extracting every cover during scanning.
  static Future<String?> extractCoverOnDemand(Song song) async {
    final file = File(song.url);
    if (!await file.exists()) return null;

    final coversDir = await coversDirectory();
    return extractCoverForFile(
      file,
      coversDir,
      p.basename(file.path),
      useFFmpegFallback: _isVideoFile(song.url),
    );
  }

  /// Extracts cover art from a single song file.
  ///
  /// Audio goes through the native core — the same reader the scan uses, so a
  /// cover found here is one the scan would accept. Videos need FFmpeg frame
  /// grabs, which are platform-channel work and stay on this isolate.
  static Future<String?> extractCoverForFile(
    File file,
    Directory coversDir,
    String filename, {
    bool skipFolderCover = false,
    bool useFFmpegFallback = false,
  }) async {
    if (!await file.exists()) return null;
    final isVideo = _isVideoFile(file.path);

    if (!isVideo) {
      final native = await RustLibraryTasks.coverFor(
        file.path,
        filename,
        coversDir: coversDir.path,
      );
      if (native != null) return native;
      if (useFFmpegFallback) {
        return extractCoverWithFFmpeg(file, coversDir, filename);
      }
      return null;
    }

    final viaFFmpeg = await extractCoverWithFFmpeg(file, coversDir, filename);
    if (viaFFmpeg != null) return viaFFmpeg;
    if (!skipFolderCover) return _findCoverInFolder(p.dirname(file.path));
    return null;
  }

  /// The FFmpeg fallback for cover extraction. Uses platform channels, so it
  /// must run on the main isolate. Call only after the native reader comes up
  /// empty — an FFmpeg invocation per song is expensive.
  ///
  /// Also goes through the shared [MediaDecodeGate]: a song missing its cover
  /// is usually a first-play too, and this must not decode while a waveform or
  /// beat analysis is mid-decode.
  static Future<String?> extractCoverWithFFmpeg(
    File file,
    Directory coversDir,
    String filename,
  ) {
    return MediaDecodeGate.run(() async {
      final hash = coverKeyForFilename(filename);
      try {
        debugPrint(
            'Scanner: Manual extraction failed for ${file.path}, trying FFmpeg fallback...');
        final coverFile = File(p.join(coversDir.path, '${hash}_ffmpeg.jpg'));

        String? extracted;
        if (_isVideoFile(file.path)) {
          extracted = await _extractVideoThumbnailWithFallback(
            inputPath: file.path,
            outputPath: coverFile.path,
          );
        } else {
          extracted = await FFmpegService().extractCover(
            inputPath: file.path,
            outputPath: coverFile.path,
          );
        }

        if (extracted != null) {
          debugPrint('Scanner: FFmpeg fallback success!');
          return extracted;
        }
      } catch (e) {
        debugPrint('Scanner: FFmpeg fallback failed: $e');
      }
      return null;
    });
  }

  /// Re-derives cover art for [songs], keyed by [Song.url].
  ///
  /// A song only appears in the result when a cover was actually resolved.
  /// Absence means "couldn't tell" — an unmounted card, an unreadable file — and
  /// callers must leave whatever cover the row already has alone. Returning a
  /// null for those cases is what let a forced rebuild erase working artwork.
  Future<Map<String, String>> rebuildCoverCache(
    List<Song> songs, {
    void Function(double progress)? onProgress,
    bool force = false,
  }) async {
    final coversDir = await coversDirectory();

    // A force rebuild deliberately does not wipe the directory first: rows
    // still point at those files until their replacements are written, and a
    // kill between the wipe and the write leaves the library with no art at
    // all. `pruneOrphanedCovers` collects the leftovers afterwards.

    // Separate video files from audio files - video thumbnails must be extracted
    // on the main thread via FFmpeg (platform channels don't work in isolates).
    final videoSongs = <Song>[];
    final otherSongs = <Song>[];
    for (final song in songs) {
      if (_isVideoFile(song.url)) {
        videoSongs.add(song);
      } else {
        otherSongs.add(song);
      }
    }

    // Audio covers; video thumbnails stay on the main thread for FFmpeg.
    final coverResults = <String, String>{};
    if (otherSongs.isNotEmpty) {
      coverResults.addAll(await _rebuildCoversOnCore(
        otherSongs,
        coversDirPath: coversDir.path,
        onProgress: (progress) => onProgress?.call(progress * 0.7),
        force: force,
      ));
    }

    // Process video files on main thread via FFmpeg (required for frame extraction)
    if (videoSongs.isNotEmpty) {
      final ffmpeg = FFmpegService();
      for (int i = 0; i < videoSongs.length; i++) {
        final song = videoSongs[i];
        onProgress
            ?.call(0.7 + (i / videoSongs.length) * 0.3); // Video files get 30%

        final file = File(song.url);
        if (!await file.exists()) continue;

        final hash = coverKeyForFilename(file.path);

        // Check existing cache first
        String? existing;
        for (final candidatePath
            in coverCandidatePaths(coversDir.path, file.path)) {
          final candidate = File(candidatePath);
          if (await _isValidCoverFile(candidate, requireDecodable: true)) {
            existing = candidate.path;
            break;
          }
        }

        if (existing != null && !force) {
          coverResults[song.url] = existing;
        } else {
          final outputPath = p.join(coversDir.path, '${hash}_ffmpeg.jpg');
          final result = await _extractVideoThumbnailWithFallback(
            inputPath: file.path,
            outputPath: outputPath,
            ffmpeg: ffmpeg,
          );
          // A failed frame grab says nothing about the cover the row already
          // has; fall back to whatever was cached rather than reporting none.
          final resolved = result ?? existing;
          if (resolved != null) coverResults[song.url] = resolved;
        }
      }
    }

    return coverResults;
  }

  /// Deletes cached cover files no row points at any more.
  ///
  /// Run after a rebuild has written its replacing rows, never before: wiping
  /// first leaves every row pointing at a file that no longer exists.
  static Future<int> pruneOrphanedCovers() async {
    final coversDir = await coversDirectory();
    final keep = <String>{};
    try {
      for (final song in await DatabaseService.instance.getAllSongs()) {
        final cover = song.coverUrl;
        if (cover != null && cover.isNotEmpty) keep.add(p.normalize(cover));
      }
      final artists = await DatabaseService.instance.getArtistArtMap();
      final albums = await DatabaseService.instance.getAlbumArtMap();
      keep.addAll(
          artists.values.where((value) => value.isNotEmpty).map(p.normalize));
      keep.addAll(
          albums.values.where((value) => value.isNotEmpty).map(p.normalize));
    } catch (_) {
      return 0;
    }

    var removed = 0;
    try {
      await for (final entity in coversDir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (keep.contains(p.normalize(entity.path))) continue;
        try {
          await entity.delete();
          removed++;
        } catch (_) {}
      }
    } catch (_) {}
    return removed;
  }

  /// Compacts and deduplicates existing cached covers.
  /// Converts legacy raw/uncompressed cover files to deduplicated, dimension-capped
  /// format and updates song database records.
  static Future<int> compactCoverCache({
    void Function(double progress)? onProgress,
  }) async {
    final songs = await DatabaseService.instance.getSongs();
    final coversDir = await coversDirectory();
    final total = songs.length;
    if (total == 0) return 0;

    final needsCompaction = songs.any((s) =>
        s.coverUrl != null &&
        s.coverUrl!.isNotEmpty &&
        !p.basename(s.coverUrl!).startsWith('c_'));
    if (!needsCompaction) {
      onProgress?.call(1.0);
      return 0;
    }

    final legacy = [
      for (final song in songs)
        if (song.coverUrl != null &&
            song.coverUrl!.isNotEmpty &&
            !p.basename(song.coverUrl!).startsWith('c_'))
          song.coverUrl!,
    ];

    if (legacy.isNotEmpty) {
      final compacted =
          await RustLibraryTasks.compactCovers(coversDir.path, legacy);
      onProgress?.call(1.0);
      if (compacted.isEmpty) return 0;
      final rewrites = <Song>[];
      for (final song in songs) {
        final cover = song.coverUrl;
        final next = cover == null ? null : compacted[cover];
        if (next != null) rewrites.add(song.copyWith(coverUrl: next));
      }
      if (rewrites.isNotEmpty) {
        await DatabaseService.instance.insertSongsBatch(rewrites);
      }
      return rewrites.length;
    }

    onProgress?.call(1.0);
    return 0;
  }

  static Future<String?> _extractVideoThumbnailWithFallback({
    required String inputPath,
    required String outputPath,
    FFmpegService? ffmpeg,
  }) async {
    final service = ffmpeg ?? FFmpegService();
    final ffmpegResult = await service.extractVideoThumbnail(
      inputPath: inputPath,
      outputPath: outputPath,
    );
    if (ffmpegResult != null &&
        await _isValidCoverFile(File(ffmpegResult), requireDecodable: true)) {
      return ffmpegResult;
    }
    return null;
  }

  /// Runs the library scan on the native core.
  static Future<void> _startScan(_ScanParams params) async {
    // Relay keeps the message contract the scan listeners already speak.
    final relay = ReceivePort();
    relay.listen((message) {
      if (message is double || message is List<Song>) {
        params.sendPort.send(message);
      } else if (message is RustTaskDone) {
        for (final root in message.unreachable) {
          params.sendPort.send('unreachable:$root');
        }
        if (message.unreadable > 0) {
          params.sendPort.send('unreadable:${message.unreadable}');
        }
        params.sendPort.send('done');
        relay.close();
      } else if (message is RustTaskError) {
        params.sendPort.send('error: ${message.message}');
        relay.close();
      }
    });

    await RustLibraryTasks.start(RustTaskRequest(
      command: 'scan',
      sendPort: relay.sendPort,
      roots: params.paths,
      excludedFolders: params.excludedFolders,
      coversDir: params.coversDirPath,
      includeVideos: params.includeVideos,
      minFileSizeBytes: params.minimumFileSizeBytes,
      fastMode: params.fastMode,
      existingSongs: params.existingSongs ?? const [],
      playCounts: params.playCounts,
      batchSize: params.fastMode ? 20 : 200,
    ));
  }

  /// Reads everything a single file says about itself, the way a scan would:
  /// tags, duration, embedded lyrics, release year and cover art.
  ///
  /// Exists so a file that reaches the library by some route other than a scan
  /// gets the metadata a scanned file would have had, rather than a second and
  /// subtly different reader quietly disagreeing with the scanner about what a
  /// file contains.
  ///
  /// [existingSong] contributes only what a file cannot know about itself: its
  /// "date added" carries over, and the release year falls back to the existing
  /// one when the file has none. Nothing else is inherited, so a replacement
  /// file with no tags reports that honestly instead of borrowing the row it is
  /// replacing. Play counts are likewise absent — they belong to the caller.
  static Future<Song> readSongMetadata(File file, {Song? existingSong}) async {
    final coversDir = await coversDirectory();
    final base = existingSong ??
        Song(
          title: p.basenameWithoutExtension(file.path),
          artist: 'Unknown Artist',
          album: 'Unknown Album',
          filename: p.basename(file.path),
          url: file.path,
        );
    final row =
        await RustLibraryTasks.readSong(base, coversDir: coversDir.path);
    if (row == null) return base;
    if (row.createdEpochSec != null) return row;
    return Song(
      title: row.title,
      artist: row.artist,
      album: row.album,
      filename: row.filename,
      url: row.url,
      coverUrl: row.coverUrl,
      hasLyrics: row.hasLyrics,
      playCount: row.playCount,
      duration: row.duration,
      mtime: row.mtime,
      createdEpochSec: DateTime.now().millisecondsSinceEpoch / 1000.0,
      songDateEpochSec: row.songDateEpochSec,
    );
  }

  static String coverKeyForFilename(String filename) {
    return sha1.convert(utf8.encode(p.basename(filename))).toString();
  }

  static Future<String?> _findCoverInFolder(String folderPath) async {
    final possibleNames = [
      'cover.jpg',
      'cover.png',
      'folder.jpg',
      'folder.png',
      'album.jpg',
      'album.png',
    ];
    for (final name in possibleNames) {
      final file = File(p.join(folderPath, name));
      if (await file.exists()) return file.path;
    }
    return null;
  }

  /// Native enrichment: parallel tag reads, DB writes on this isolate.
  static Future<List<Song>> _enrichOnCore(
    List<Song> songs, {
    void Function(double progress)? onProgress,
    void Function(List<Song> enrichedBatch)? onBatchEnriched,
  }) async {
    final coversDir = await coversDirectory();
    final relay = ReceivePort();
    final messages = StreamController<dynamic>();
    relay.listen(messages.add, onError: messages.addError);
    final merged = <String, Song>{};

    final worker = () async {
      await for (final message in messages.stream) {
        if (message is List<Song>) {
          for (final song in message) {
            merged[song.filename] = song;
          }
          if (message.isNotEmpty) {
            await DatabaseService.instance.insertSongsBatch(message);
            onBatchEnriched?.call(message);
          }
        } else if (message is double) {
          onProgress?.call(message);
        } else if (message is RustTaskDone || message is RustTaskError) {
          if (message is RustTaskError) {
            debugPrint('Rust enrich failed: ${message.message}');
          }
          await messages.close();
          relay.close();
        }
      }
    }();

    await RustLibraryTasks.start(
      RustTaskRequest(
        command: 'enrich',
        sendPort: relay.sendPort,
        songs: songs,
        coversDir: coversDir.path,
      ),
    );
    await worker;
    return [for (final song in songs) merged[song.filename] ?? song];
  }

  /// Native cover sweep for songs that still have no usable art.
  static Future<CoverSweepResult> _extractCoversOnCore(
    List<Song> songs, {
    void Function(double progress)? onProgress,
    void Function(List<Song> updatedSongs)? onBatchExtracted,
  }) async {
    final coversDir = await coversDirectory();
    final relay = ReceivePort();
    final messages = StreamController<dynamic>();
    relay.listen(messages.add, onError: messages.addError);
    final merged = <String, Song>{};
    var completed = true;

    final worker = () async {
      await for (final message in messages.stream) {
        if (message is List<Song>) {
          for (final song in message) {
            merged[song.filename] = song;
            final cover = song.coverUrl;
            if (cover != null) {
              unawaited(CoverRefreshService.evictCoverFromImageCache(cover));
            }
          }
          if (message.isNotEmpty) {
            await DatabaseService.instance.insertSongsBatch(message);
            onBatchExtracted?.call(message);
          }
        } else if (message is double) {
          onProgress?.call(message);
        } else if (message is RustTaskDone || message is RustTaskError) {
          if (message is RustTaskError) {
            completed = false;
            debugPrint('Rust cover sweep failed: ${message.message}');
          } else if (message is RustTaskDone) {
            completed = !message.cancelled;
          }
          await messages.close();
          relay.close();
        }
      }
    }();

    await RustLibraryTasks.start(RustTaskRequest(
      command: 'extract_covers',
      sendPort: relay.sendPort,
      songs: songs,
      coversDir: coversDir.path,
    ));
    await worker;
    return CoverSweepResult(
      [for (final song in songs) merged[song.filename] ?? song],
      completed: completed,
    );
  }

  /// Native cover rebuild. Only resolved covers are reported.
  static Future<Map<String, String>> _rebuildCoversOnCore(
    List<Song> songs, {
    required String coversDirPath,
    void Function(double progress)? onProgress,
    required bool force,
  }) async {
    final relay = ReceivePort();
    final messages = StreamController<dynamic>();
    relay.listen(messages.add, onError: messages.addError);
    final results = <String, String>{};

    final worker = () async {
      await for (final message in messages.stream) {
        if (message is Map<String, String>) {
          results.addAll(message);
        } else if (message is double) {
          onProgress?.call(message);
        } else if (message is RustTaskDone || message is RustTaskError) {
          if (message is RustTaskError) {
            debugPrint('Rust cover rebuild failed: ${message.message}');
          }
          await messages.close();
          relay.close();
        }
      }
    }();

    await RustLibraryTasks.start(RustTaskRequest(
      command: 'rebuild_covers',
      sendPort: relay.sendPort,
      songs: songs,
      coversDir: coversDirPath,
      force: force,
    ));
    await worker;
    return results;
  }
}
