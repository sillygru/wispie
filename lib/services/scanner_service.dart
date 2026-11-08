import 'debug_sandbox.dart';
import 'dart:io';
import 'dart:async';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;
import 'dart:convert';
import '../models/song.dart';
import 'database_service.dart';
import '../domain/services/cover_optimizer.dart';
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

  /// Enriches minimal song records with metadata (title, artist, album, duration).
  ///
  /// Tag parsing runs on the native core's workers; only the DB write and the
  /// progress callback stay on this isolate, since sqflite is not usable from a
  /// spawned one.
  static Future<List<Song>> enrichAllMetadata(
    List<Song> songs, {
    void Function(double progress)? onProgress,
    void Function(List<Song> enrichedBatch)? onBatchEnriched,
  }) {
    return _enrichOnCore(songs,
        onProgress: onProgress, onBatchEnriched: onBatchEnriched);
  }

  /// Extracts cover art for songs missing covers, on the native core.
  static Future<List<Song>> extractCoversInBackground(
    List<Song> songs, {
    void Function(double progress)? onProgress,
    void Function(List<Song> updatedSongs)? onBatchExtracted,
  }) {
    return _extractCoversOnCore(songs,
        onProgress: onProgress, onBatchExtracted: onBatchExtracted);
  }

  /// Extracts cover art for a single song on demand.
  /// Used for lazy cover extraction — only called when a song's cover is
  /// first viewed. Avoids the cost of extracting every cover during scanning.
  static Future<String?> extractCoverOnDemand(Song song) async {
    final file = File(song.url);
    if (!await file.exists()) return null;

    final isVideo = _isVideoFile(song.url);
    final supportDir = await getSupportDirectory();
    final coversDir = Directory(p.join(supportDir.path, 'extracted_covers'));
    if (!await coversDir.exists()) {
      await coversDir.create(recursive: true);
    }

    return await extractCoverForFile(
      file,
      coversDir,
      p.basename(file.path),
      useFFmpegFallback: isVideo,
    );
  }

  /// The pure-Dart half of cover extraction: embedded picture → folder cover →
  /// manual byte scan. Uses no platform channels, so it is safe to run inside
  /// [Isolate.run] — the byte scan can read the whole audio file and must never
  /// happen on the UI thread.
  ///
  /// Returns null when only the FFmpeg fallback could still succeed.
  static Future<String?> extractCoverWithoutFFmpeg(
    String filePath,
    String coversDirPath,
    String filename, {
    bool skipFolderCover = false,
  }) async {
    final file = File(filePath);
    if (_isVideoFile(filePath)) return null;
    if (!await file.exists()) return null;

    final coversDir = Directory(coversDirPath);

    try {
      // getImage: true is required — the parser skips picture frames
      // otherwise, and this whole cheap path silently never fires.
      final metadata = amr.readMetadata(file, getImage: true);
      if (metadata.pictures.isNotEmpty) {
        final cover = recoverEmbeddedCover(metadata.pictures.first.bytes);
        if (cover != null) {
          return await CoverOptimizer.saveOptimizedCover(
            cover.bytes,
            coversDir.path,
            fallbackExtension: cover.extension,
          );
        }
      }
    } catch (e) {
      debugPrint('extractCoverWithoutFFmpeg: metadata read failed: $e');
    }

    // Folder cover before the manual byte scan — a handful of exists()
    // checks is far cheaper than reading the whole audio file.
    if (!skipFolderCover) {
      final folderCover = await _findCoverInFolder(p.dirname(filePath));
      if (folderCover != null) return folderCover;
    }

    return await _tryManualCoverExtraction(file, coversDir, filename);
  }

  /// Extracts cover art from a single song file using the same logic as the
  /// scanner (metadata reader → folder cover → manual byte extraction →
  /// FFmpeg). Returns the path to the cached cover file, or null if no cover
  /// was found.
  static Future<String?> extractCoverForFile(
    File file,
    Directory coversDir,
    String filename, {
    bool skipFolderCover = false,
    bool useFFmpegFallback = false,
  }) async {
    if (!await file.exists()) return null;
    final isVideo = _isVideoFile(file.path);

    final pureDart = await extractCoverWithoutFFmpeg(
      file.path,
      coversDir.path,
      filename,
      skipFolderCover: skipFolderCover,
    );
    if (pureDart != null) return pureDart;

    if (useFFmpegFallback || isVideo) {
      final viaFFmpeg = await extractCoverWithFFmpeg(file, coversDir, filename);
      if (viaFFmpeg != null) return viaFFmpeg;
    }

    // extractCoverWithoutFFmpeg bails out immediately on video files, so they
    // still need a folder-cover fallback once FFmpeg has failed.
    if (isVideo && !skipFolderCover) {
      return _findCoverInFolder(p.dirname(file.path));
    }

    return null;
  }

  /// The FFmpeg half of cover extraction. Uses platform channels, so it must
  /// run on the main isolate. Call only after [extractCoverWithoutFFmpeg] has
  /// come up empty — an FFmpeg invocation per song is expensive.
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

    if (force) {
      try {
        final keepSet = <String>{};
        try {
          final artists = await DatabaseService.instance.getArtistArtMap();
          final albums = await DatabaseService.instance.getAlbumArtMap();
          keepSet.addAll(
              artists.values.where((p) => p.isNotEmpty).map(p.normalize));
          keepSet.addAll(
              albums.values.where((p) => p.isNotEmpty).map(p.normalize));
        } catch (_) {}
        if (await coversDir.exists()) {
          await for (final entity in coversDir.list(followLinks: false)) {
            if (entity is File && !keepSet.contains(p.normalize(entity.path))) {
              try {
                await entity.delete();
              } catch (_) {}
            }
          }
        }
      } catch (e) {
        debugPrint('Error wiping cover cache before force rebuild: $e');
      }
    }

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
    return _processSingleFile(
      file,
      coversDir,
      <String, String?>{},
      <String, int>{},
      existingSong: existingSong,
    );
  }

  static Future<Song> _processSingleFile(File file, Directory coversDir,
      Map<String, String?> folderCoverCache, Map<String, int> playCounts,
      {double? mtime, Song? existingSong}) async {
    final filename = p.basename(file.path);
    final parentPath = file.parent.path;
    p.extension(file.path).toLowerCase();

    String title = p.basenameWithoutExtension(file.path);
    String artist = 'Unknown Artist';
    String album = 'Unknown Album';
    Duration? duration;
    String? coverUrl;
    bool hasLyrics = false;
    double? songDateEpochSec;
    final fileStat = await file.stat();
    final createdEpochSec = existingSong?.createdEpochSec ??
        DateTime.now().millisecondsSinceEpoch / 1000.0;
    final isVideo = _isVideoFile(file.path);

    // Check for valid cache first
    for (final cachedPath in coverCandidatePaths(coversDir.path, filename)) {
      final cachedFile = File(cachedPath);
      if (await _isValidCoverFile(cachedFile, requireDecodable: isVideo)) {
        coverUrl = cachedFile.path;
        break;
      }
    }

    if (!isVideo) {
      // Only use audio_metadata_reader for non-video files — it can crash or
      // hang on large video containers (MKV, WebM, AVI, etc.).
      try {
        final metadata = amr.readMetadata(file, getImage: coverUrl == null);
        if (metadata.title?.isNotEmpty == true) title = metadata.title!;
        if (metadata.artist?.isNotEmpty == true) artist = metadata.artist!;
        if (metadata.album?.isNotEmpty == true) album = metadata.album!;
        if (metadata.year != null) {
          songDateEpochSec =
              metadata.year!.millisecondsSinceEpoch.toDouble() / 1000.0;
        } else {
          songDateEpochSec = existingSong?.songDateEpochSec;
        }
        duration = metadata.duration;

        // Check for embedded lyrics using audio_metadata_reader
        // Note: FFmpeg is used for actual lyrics reading in the main thread
        if (metadata.lyrics?.isNotEmpty == true) {
          hasLyrics = true;
        }

        if (coverUrl == null && metadata.pictures.isNotEmpty) {
          final cover = recoverEmbeddedCover(metadata.pictures.first.bytes);
          if (cover != null) {
            coverUrl = await CoverOptimizer.saveOptimizedCover(
              cover.bytes,
              coversDir.path,
              fallbackExtension: cover.extension,
            );
          }
        }
      } on FileSystemException catch (e) {
        debugPrint('Scanner: unreadable file $filename: $e');
      } catch (e) {
        debugPrint('Scanner: metadata parse failed for $filename: $e');
      }
    }

    // Folder cover before the manual byte scan — cheap exists() checks beat
    // reading the whole audio file.
    if (coverUrl == null) {
      if (!folderCoverCache.containsKey(parentPath)) {
        folderCoverCache[parentPath] = await _findCoverInFolder(parentPath);
      }
      coverUrl = folderCoverCache[parentPath];
    }

    // Manual byte-level extraction is only used for audio files.
    // Video files are handled later by postProcessVideoThumbnails on the main
    // thread via FFmpeg frame extraction to avoid false-positive embedded data.
    if (!isVideo) {
      coverUrl ??= await _tryManualCoverExtraction(file, coversDir, filename);
    }

    return Song(
      title: title,
      artist: artist,
      album: album,
      filename: filename,
      url: file.path,
      coverUrl: coverUrl,
      hasLyrics: hasLyrics,
      playCount: playCounts[filename] ?? 0,
      duration: duration,
      mtime: mtime ?? fileStat.modified.millisecondsSinceEpoch / 1000.0,
      createdEpochSec: createdEpochSec,
      songDateEpochSec: songDateEpochSec,
    );
  }

  static Future<String?> _tryManualCoverExtraction(
      File file, Directory coversDir, String filename) async {
    RandomAccessFile? raf;
    try {
      raf = await file.open();
      final length = await raf.length();
      final ext = p.extension(file.path).toLowerCase();

      final bool scanEverything = length < 50 * 1024 * 1024;
      final firstScanSize = scanEverything ? length : 15 * 1024 * 1024;

      await raf.setPosition(0);
      final headerChunk = await raf.read(firstScanSize);

      if (ext == '.m4a') {
        final covrResult =
            await _scanForCovrBox(headerChunk, raf, 0, coversDir, filename);
        if (covrResult != null) return covrResult;
      }

      final apicResult =
          await _scanForAPIC(headerChunk, raf, 0, coversDir, filename);
      if (apicResult != null) return apicResult;

      final sigResult = await _scanBufferForSignatures(
          headerChunk, raf, 0, coversDir, filename);
      if (sigResult != null) return sigResult;

      if (!scanEverything && length > firstScanSize) {
        final footerSize = (10 * 1024 * 1024).clamp(0, length - firstScanSize);
        await raf.setPosition(length - footerSize);
        final footerChunk = await raf.read(footerSize);

        final sigFooterResult = await _scanBufferForSignatures(
            footerChunk, raf, length - footerSize, coversDir, filename);
        if (sigFooterResult != null) return sigFooterResult;
      }

      return null;
    } catch (e) {
      return null;
    } finally {
      await raf?.close();
    }
  }

  static Future<String?> _scanForAPIC(List<int> bytes, RandomAccessFile raf,
      int offset, Directory coversDir, String filename) async {
    for (int i = 0; i < bytes.length - 20; i++) {
      if (bytes[i] == 0x41 &&
          bytes[i + 1] == 0x50 &&
          bytes[i + 2] == 0x49 &&
          bytes[i + 3] == 0x43) {
        int tagSize = (bytes[i + 4] << 21) |
            (bytes[i + 5] << 14) |
            (bytes[i + 6] << 7) |
            bytes[i + 7];
        if (tagSize > 5000 && tagSize < 15 * 1024 * 1024) {
          final subChunk =
              bytes.sublist(i, (i + tagSize + 20).clamp(0, bytes.length));
          return await _scanBufferForSignatures(
              subChunk, raf, offset + i, coversDir, filename);
        }
      }
    }
    return null;
  }

  static Future<String?> _scanForCovrBox(List<int> bytes, RandomAccessFile raf,
      int offset, Directory coversDir, String filename) async {
    for (int i = 0; i < bytes.length - 24; i++) {
      if (bytes[i] == 0x63 &&
          bytes[i + 1] == 0x6F &&
          bytes[i + 2] == 0x76 &&
          bytes[i + 3] == 0x72) {
        for (int j = i + 4; j < i + 128 && j < bytes.length - 16; j++) {
          if (bytes[j] == 0x64 &&
              bytes[j + 1] == 0x61 &&
              bytes[j + 2] == 0x74 &&
              bytes[j + 3] == 0x61) {
            final dataSize = (bytes[j - 4] << 24) |
                (bytes[j - 3] << 16) |
                (bytes[j - 2] << 8) |
                bytes[j - 1];
            final imageSize = dataSize - 16;

            if (imageSize > 1024 && imageSize < 15 * 1024 * 1024) {
              final startPos = offset + j + 12;
              await raf.setPosition(startPos);
              final imgData = await raf.read(imageSize);

              String type = 'jpg';
              if (bytes[j + 11] == 14) {
                type = 'png';
              } else if (bytes[j + 11] == 27) {
                type = 'bmp';
              }

              return await CoverOptimizer.saveOptimizedCover(
                imgData,
                coversDir.path,
                fallbackExtension: '.$type',
              );
            }
          }
        }
      }
    }
    return null;
  }

  static Future<String?> _scanBufferForSignatures(
      List<int> bytes,
      RandomAccessFile raf,
      int offset,
      Directory coversDir,
      String filename) async {
    for (int i = 0; i < bytes.length - 8; i++) {
      if (bytes[i] == 0xFF && bytes[i + 1] == 0xD8) {
        final res =
            await _extractImageAt(raf, offset + i, 'jpg', coversDir, filename);
        if (res != null) return res;
      }
      if (bytes[i] == 0x89 &&
          bytes[i + 1] == 0x50 &&
          bytes[i + 2] == 0x4E &&
          bytes[i + 3] == 0x47) {
        final res =
            await _extractImageAt(raf, offset + i, 'png', coversDir, filename);
        if (res != null) return res;
      }
      if (bytes[i] == 0x52 &&
          bytes[i + 1] == 0x49 &&
          bytes[i + 2] == 0x46 &&
          bytes[i + 3] == 0x46) {
        if (i + 12 <= bytes.length &&
            bytes[i + 8] == 0x57 &&
            bytes[i + 9] == 0x45 &&
            bytes[i + 10] == 0x42 &&
            bytes[i + 11] == 0x50) {
          final res = await _extractImageAt(
              raf, offset + i, 'webp', coversDir, filename);
          if (res != null) return res;
        }
      }
    }
    return null;
  }

  static Future<String?> _extractImageAt(RandomAccessFile raf, int pos,
      String type, Directory coversDir, String filename) async {
    await raf.setPosition(pos);
    final data = await raf.read(15 * 1024 * 1024);

    int actualEnd = data.length;
    if (type == 'jpg') {
      int lastFFD9 = -1;
      for (int k = 0; k < data.length - 1; k++) {
        if (data[k] == 0xFF && data[k + 1] == 0xD9) {
          lastFFD9 = k + 2;
          if (k + 4 < data.length) {
            if (data[k + 2] != 0xFF || data[k + 3] == 0x00) {
              actualEnd = lastFFD9;
              break;
            }
          }
        }
      }
      if (lastFFD9 != -1) actualEnd = lastFFD9;
      if (actualEnd == data.length && data.length < 50 * 1024) return null;
    } else if (type == 'png') {
      final pngEnd = [0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82];
      for (int k = 0; k < data.length - pngEnd.length; k++) {
        bool match = true;
        for (int l = 0; l < pngEnd.length; l++) {
          if (data[k + l] != pngEnd[l]) {
            match = false;
            break;
          }
        }
        if (match) {
          actualEnd = k + pngEnd.length;
          break;
        }
      }
    }

    if (actualEnd > 1024) {
      final rawData = Uint8List.fromList(data.sublist(0, actualEnd));
      return await CoverOptimizer.saveOptimizedCover(
        rawData,
        coversDir.path,
        fallbackExtension: '.$type',
      );
    }
    return null;
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
          command: 'enrich', sendPort: relay.sendPort, songs: songs),
    );
    await worker;
    return [for (final song in songs) merged[song.filename] ?? song];
  }

  /// Native cover sweep for songs that still have no art.
  static Future<List<Song>> _extractCoversOnCore(
    List<Song> songs, {
    void Function(double progress)? onProgress,
    void Function(List<Song> updatedSongs)? onBatchExtracted,
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
            debugPrint('Rust cover sweep failed: ${message.message}');
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
    return [for (final song in songs) merged[song.filename] ?? song];
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
