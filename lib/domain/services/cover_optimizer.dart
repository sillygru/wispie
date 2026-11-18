import 'dart:typed_data';

import '../../data/rust/wispie_core.dart';

/// Logic and I/O for deduplicating, resizing, and caching cover art.
///
/// The sniff, the SHA-1 content key, the resize/encode and the atomic write all
/// run in the native core.
class CoverOptimizer {
  /// Maximum bounding dimension for cached cover images.
  ///
  /// 1024px gives retina clarity on phone/tablet/desktop screens while capping
  /// memory consumption to ~4MB decoded RGBA bitmap. Mirrored from the core.
  static const int maxCoverDimension = 1024;

  /// Quality level for JPEG encoding (88 provides visually lossless quality).
  static const int jpegQuality = 88;

  /// Threshold under which already-compressed, correctly-sized images skip
  /// re-encoding.
  static const int fastPathByteLimit = 250 * 1024;

  /// Computes a content-addressable hash key for [bytes].
  static String computeContentKey(Uint8List bytes) =>
      WispieCore.helper({'action': 'cover_key'}, bytes: bytes)['key'] as String;

  /// Checks whether a deduplicated cover already exists in [coversDirPath].
  static String? findExistingCover(String coversDirPath, String contentKey) =>
      WispieCore.helper({
        'action': 'cover_find',
        'dir': coversDirPath,
        'key': contentKey,
      })['path'] as String?;

  /// Optimizes and writes [rawBytes] to [coversDirPath] with content-addressable
  /// deduplication.
  ///
  /// If an identical cover image is already cached, returns the existing path
  /// immediately without disk writes or re-encoding.
  static Future<String> saveOptimizedCover(
    Uint8List rawBytes,
    String coversDirPath, {
    String? fallbackExtension,
    int maxDimension = maxCoverDimension,
    int quality = jpegQuality,
  }) async {
    final reply = WispieCore.helper({
      'action': 'cover_save',
      'dir': coversDirPath,
      if (fallbackExtension != null) 'fallbackExtension': fallbackExtension,
      'maxDimension': maxDimension,
      'quality': quality,
    }, bytes: rawBytes);
    return reply['path'] as String;
  }
}
