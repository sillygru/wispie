import '../services/cache_policy.dart';
import '../value_objects/filename.dart';

/// Typed identifier for cover and derived caches.
///
/// Replaces nullable `String? coverUrl` + ad-hoc `file://` normalization
/// scattered across waveform, FFmpeg and blur code with one value object.
/// The filename is the app's primary key for user data, so this key
/// is the sole place that knows how cache file names are derived.
class CoverKey {
  final String filename;

  const CoverKey(this.filename);

  bool get isEmpty => filename.isEmpty;
  bool get isNotEmpty => filename.isNotEmpty;

  /// Stable hash used for cache file names.
  String get hash => cacheKeyFor(filename);

  String waveformCacheName() =>
      '$waveformCachePrefix$hash$waveformCacheExtension';
  String beatMapCacheName() => 'beatmap_$hash.json';
  String blurredCacheName() => 'blurred_$hash.jpg';

  /// Normalized cache key for notification covers (basename of cover file).
  static String notificationKeyForCoverPath(String coverPath) =>
      notificationCoverKey(coverPath);

  /// Normalize a possibly `file://` URI to a filesystem path.
  static String normalizePath(String path) {
    if (path.startsWith('file://')) {
      try {
        return Uri.parse(path).toFilePath();
      } catch (_) {
        return path;
      }
    }
    return path;
  }

  factory CoverKey.fromFilePath(String path) =>
      CoverKey(Filename.fromUrl(normalizePath(path)));

  @override
  bool operator ==(Object other) =>
      other is CoverKey && other.filename == filename;

  @override
  int get hashCode => filename.hashCode;

  @override
  String toString() => 'CoverKey($filename)';
}
