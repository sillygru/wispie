import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:convert';
import 'dart:isolate';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../domain/services/cover_path.dart';
import '../domain/services/native_accel.dart';
import 'shared_http_client.dart';
import 'wispie_cache.dart';

class ExtractedPalette {
  final Color? used;

  /// The cover's accent, already corrected for legibility by the native core.
  final Color accent;

  /// The cover has no usable chroma, so the theme falls back to its OLED
  /// variant instead of showing an invented hue.
  final bool isNeutral;

  /// Flat average of the swatches. Only meaningful for backdrops and scrims,
  /// where a muddy blend of everything is exactly what is wanted — never as an
  /// accent.
  final Color mixedColor;

  final List<Color> palette;

  Color get color => used ?? accent;

  const ExtractedPalette({
    this.used,
    required this.accent,
    required this.isNeutral,
    required this.mixedColor,
    required this.palette,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! ExtractedPalette) return false;
    if (used != other.used) return false;
    if (accent != other.accent) return false;
    if (isNeutral != other.isNeutral) return false;
    if (mixedColor != other.mixedColor) return false;
    if (palette.length != other.palette.length) return false;
    for (int i = 0; i < palette.length; i++) {
      if (palette[i] != other.palette[i]) return false;
    }
    return true;
  }

  @override
  int get hashCode {
    int hash = Object.hash(used, accent, isNeutral, mixedColor, palette.length);
    for (final color in palette) {
      hash = Object.hash(hash, color);
    }
    return hash;
  }

  ExtractedPalette.single(Color color)
      : used = null,
        accent = color,
        isNeutral = false,
        mixedColor = color,
        palette = [color];

  factory ExtractedPalette.create(
      {Color? used, required NativePalette source}) {
    return ExtractedPalette(
      used: used,
      accent: Color.fromARGB(
        255,
        source.accent.red,
        source.accent.green,
        source.accent.blue,
      ),
      isNeutral: source.isNeutral,
      mixedColor: Color.fromARGB(
        255,
        source.mixedColor.red,
        source.mixedColor.green,
        source.mixedColor.blue,
      ),
      palette: [
        for (final swatch in source.swatches)
          Color.fromARGB(255, swatch.red, swatch.green, swatch.blue),
      ],
    );
  }

  factory ExtractedPalette.fromJson(Map<String, dynamic> json) {
    final paletteList =
        (json['palette'] as List?)?.map((e) => Color(e as int)).toList() ?? [];
    final mixedColor = Color(json['mixedColor'] as int? ?? 0xFF000000);
    return ExtractedPalette(
      used: json['used'] != null ? Color(json['used'] as int) : null,
      accent: Color(json['accent'] as int? ?? 0xFFE0E0E0),
      isNeutral: json['isNeutral'] as bool? ?? true,
      mixedColor: mixedColor,
      palette: paletteList,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'used': used?.toARGB32(),
      'accent': accent.toARGB32(),
      'isNeutral': isNeutral,
      'mixedColor': mixedColor.toARGB32(),
      'palette': palette.map((e) => e.toARGB32()).toList(),
    };
  }
}

/// A cached palette plus the identity of the cover file it came from, so an
/// entry can be invalidated when the artwork behind the path is rewritten
/// (cover refresh, metadata edits, standardisation).
class _CacheEntry {
  final ExtractedPalette palette;
  final int size;
  final int mtimeMs;

  const _CacheEntry({
    required this.palette,
    required this.size,
    required this.mtimeMs,
  });

  bool matches(FileStat stat) =>
      stat.size == size && stat.modified.millisecondsSinceEpoch == mtimeMs;

  Map<String, dynamic> toJson() => {
        'palette': palette.toJson(),
        'size': size,
        'mtimeMs': mtimeMs,
      };

  static _CacheEntry? fromJson(Object? json) {
    if (json is! Map<String, dynamic>) return null;
    final palette = json['palette'];
    if (palette is! Map<String, dynamic>) return null;
    return _CacheEntry(
      palette: ExtractedPalette.fromJson(palette),
      size: json['size'] as int? ?? -1,
      mtimeMs: json['mtimeMs'] as int? ?? -1,
    );
  }
}

class ColorExtractionService {
  /// Bumped whenever the extraction algorithm changes. The persisted cache is
  /// discarded wholesale on a mismatch — without this, every already-scanned
  /// library keeps serving colours computed by the old algorithm forever, and
  /// no fix here would ever reach an existing install.
  static const int _cacheVersion = 4;

  // Insertion-ordered map: most recently accessed keys sit at the end. On
  // each cache hit we re-insert to mark it as fresh, so the head of the
  // map is always the least-recently-used entry we can evict when the cap
  // is hit.
  static LinkedHashMap<String, _CacheEntry> _paletteCache = LinkedHashMap();
  static final Map<String, Future<ExtractedPalette?>> _pendingPalettes = {};
  static File? _cacheFile;
  static bool _initialized = false;
  static Future<void>? _initFuture;
  static Timer? _saveDebounceTimer;
  static const Duration _saveDebounce = Duration(seconds: 5);
  static const int _maxCachedPalettes = 500;

  static Future<void> init() async {
    if (_initialized) return;
    if (_initFuture != null) {
      await _initFuture;
      return;
    }

    _initFuture = _initInternal();
    await _initFuture;
  }

  static Future<void> _initInternal() async {
    try {
      _cacheFile = await WispieCache.instance.paletteIndexFile();

      if (await _cacheFile!.exists()) {
        final Map<String, dynamic> json =
            await compute(_loadPaletteCacheSnapshot, _cacheFile!.path);
        if (json['version'] != _cacheVersion) {
          debugPrint('ColorExtractionService: Discarding stale palette cache '
              '(v${json['version']} != v$_cacheVersion)');
          await _cacheFile!.delete();
        } else {
          final entries = json['entries'];
          final loaded = <String, _CacheEntry>{};
          if (entries is Map<String, dynamic>) {
            entries.forEach((key, value) {
              final entry = _CacheEntry.fromJson(value);
              if (entry != null) loaded[key] = entry;
            });
          }
          _paletteCache = LinkedHashMap.from(loaded);
          debugPrint(
              'ColorExtractionService: Loaded ${_paletteCache.length} cached palettes');
        }
      }
    } catch (e) {
      debugPrint('ColorExtractionService init error: $e');
    } finally {
      _initialized = true;
      _initFuture = null;
    }
  }

  static Future<ExtractedPalette?> extractPalette(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return null;

    await init();

    final cached = _paletteCache[imagePath];
    if (cached != null) {
      if (await _isEntryFresh(imagePath, cached)) {
        // Re-insert to mark as recently used for the LRU eviction policy.
        _paletteCache.remove(imagePath);
        _paletteCache[imagePath] = cached;
        return cached.palette;
      }
      _paletteCache.remove(imagePath);
    }

    final pending = _pendingPalettes[imagePath];
    if (pending != null) {
      return pending;
    }

    final extraction = _extractAndCachePalette(imagePath);
    _pendingPalettes[imagePath] = extraction;
    try {
      return await extraction;
    } catch (e) {
      debugPrint('Error extracting palette from $imagePath: $e');
      return null;
    } finally {
      if (identical(_pendingPalettes[imagePath], extraction)) {
        _pendingPalettes.remove(imagePath);
      }
    }
  }

  /// Palette for a cover that may be a remote URL.
  ///
  /// Artwork for streamed tracks is an https URL, which [extractPalette] cannot
  /// read. It is downloaded once into a small artwork cache and then treated
  /// exactly like a local cover, so the page gets the same accent and the next
  /// visit costs no network.
  static Future<ExtractedPalette?> extractPaletteForCover(String? cover) async {
    if (cover == null || cover.isEmpty) return null;
    if (CoverPath.isLocal(cover)) return extractPalette(cover);
    final uri = Uri.tryParse(cover);
    if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
      return null;
    }
    final file = await _downloadArtwork(uri);
    if (file == null) return null;
    return extractPalette(file.path);
  }

  static Future<File?> _downloadArtwork(Uri uri) async {
    try {
      final file = await WispieCache.instance.remoteArtFile(uri.toString());
      if (await file.exists() && await file.length() > 0) return file;

      final request = await SharedHttpClient.openUrl(
        SharedHttpClient.instance,
        uri,
        timeout: const Duration(seconds: 12),
      );
      final response = await SharedHttpClient.awaitResponse(
        request,
        timeout: const Duration(seconds: 12),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        await response.drain<void>();
        return null;
      }
      final List<int> bytes;
      try {
        bytes = await consolidateHttpClientResponseBytes(response)
            .timeout(const Duration(seconds: 12));
      } on Object {
        // A cover that stopped arriving holds the connection; release it.
        SharedHttpClient.abort(request);
        rethrow;
      }
      if (bytes.isEmpty) return null;
      await file.writeAsBytes(bytes, flush: false);
      return file;
    } on Object catch (error) {
      debugPrint('ColorExtractionService: cover download failed: $error');
      return null;
    }
  }

  /// An entry survives only while the file behind the path is byte-identical to
  /// the one it was computed from. Covers are rewritten in place by metadata
  /// edits and cover refresh, and a path-only key would keep serving the old
  /// artwork's colour.
  static Future<bool> _isEntryFresh(String imagePath, _CacheEntry entry) async {
    if (entry.size < 0) return true;
    try {
      final stat = await File(imagePath).stat();
      if (stat.type == FileSystemEntityType.notFound) return true;
      return entry.matches(stat);
    } catch (_) {
      return true;
    }
  }

  static Future<ExtractedPalette?> _extractAndCachePalette(
    String imagePath,
  ) async {
    final file = File(imagePath);
    if (!await file.exists()) return null;

    final palette = await _extractNativePalette(file);
    if (palette == null || palette.swatches.isEmpty) return null;

    final extractedPalette = ExtractedPalette.create(source: palette);

    final stat = await file.stat();
    _paletteCache[imagePath] = _CacheEntry(
      palette: extractedPalette,
      size: stat.size,
      mtimeMs: stat.modified.millisecondsSinceEpoch,
    );
    // Cap the in-memory cache to avoid unbounded growth in long sessions.
    // Persisted cache on disk keeps the full set so future restarts reload
    // what was previously extracted.
    _enforceMaxSize();
    _scheduleCacheSave();
    return extractedPalette;
  }

  static void _enforceMaxSize() {
    while (_paletteCache.length > _maxCachedPalettes) {
      final oldestKey = _paletteCache.keys.first;
      _paletteCache.remove(oldestKey);
    }
  }

  static Future<NativePalette?> _extractNativePalette(File imageFile) async {
    try {
      return await Isolate.run(
        () => NativeAccel.palette(imageFile.path),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<Color?> extractColor(String? imagePath) async {
    final palette = await extractPalette(imagePath);
    return palette?.color;
  }

  static Future<bool> hasCachedPalette(String? imagePath) async {
    if (imagePath == null || imagePath.isEmpty) return false;
    await init();
    return _paletteCache.containsKey(imagePath);
  }

  static Future<void> pruneCacheToImagePaths(Set<String> imagePaths) async {
    await init();
    final keepPaths = imagePaths.where((path) => path.isNotEmpty).toSet();
    final originalLength = _paletteCache.length;
    _paletteCache.removeWhere((path, _) => !keepPaths.contains(path));
    if (_paletteCache.length != originalLength) {
      _scheduleCacheSave();
    }
  }

  static void _scheduleCacheSave() {
    // Coalesce multiple back-to-back extractions (common during a fresh
    // library scan) into a single disk write. 5 s is a comfortable window
    // for bursts without risking data loss if the process is killed.
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(_saveDebounce, () {
      _saveDebounceTimer = null;
      _saveCacheToDisk();
    });
  }

  static Future<void> _saveCacheToDisk() async {
    if (_cacheFile == null) return;
    try {
      final snapshot = _paletteCache;
      final entries =
          snapshot.map((key, value) => MapEntry(key, value.toJson()));
      await _cacheFile!.writeAsString(jsonEncode({
        'version': _cacheVersion,
        'entries': entries,
      }));
    } catch (e) {
      debugPrint('Error saving palette cache: $e');
    }
  }

  static Future<void> clearCache() async {
    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = null;
    _paletteCache.clear();
    _pendingPalettes.clear();
    if (_cacheFile != null && await _cacheFile!.exists()) {
      await _cacheFile!.delete();
    }
  }

  static int _batchProgress = 0;
  static int _batchTotal = 0;
  static bool _batchCancelled = false;

  static double? get batchProgress =>
      _batchTotal > 0 ? _batchProgress / _batchTotal : null;

  static Future<void> extractAllPalettes(
    List<String> imagePaths, {
    void Function(int progress, int total)? onProgress,
  }) async {
    await init();
    _batchProgress = 0;
    _batchTotal = imagePaths.length;
    _batchCancelled = false;

    for (int i = 0; i < imagePaths.length; i++) {
      if (_batchCancelled) break;

      final path = imagePaths[i];
      if (!_paletteCache.containsKey(path)) {
        await extractPalette(path);
      }

      _batchProgress = i + 1;
      onProgress?.call(_batchProgress, _batchTotal);
    }

    _batchProgress = 0;
    _batchTotal = 0;
  }

  static void cancelBatchExtraction() {
    _batchCancelled = true;
  }
}

Future<Map<String, dynamic>> _loadPaletteCacheSnapshot(String cachePath) async {
  final cacheFile = File(cachePath);
  if (!await cacheFile.exists()) return {};

  final jsonString = await cacheFile.readAsString();
  final decoded = jsonDecode(jsonString);
  if (decoded is Map<String, dynamic>) return decoded;
  return {};
}
