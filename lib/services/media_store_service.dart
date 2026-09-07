import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One audio row from the platform MediaStore (Android only).
class MediaStoreAudioEntry {
  final String? filePath;
  final String contentUri;
  final String displayName;
  final int sizeBytes;

  const MediaStoreAudioEntry({
    required this.filePath,
    required this.contentUri,
    required this.displayName,
    required this.sizeBytes,
  });

  factory MediaStoreAudioEntry.fromMap(Map<String, dynamic> map) {
    return MediaStoreAudioEntry(
      filePath: map['filePath'] as String?,
      contentUri: (map['contentUri'] as String?) ?? '',
      displayName: (map['displayName'] as String?) ?? '',
      sizeBytes: (map['sizeBytes'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Thin wrapper around the native MediaStore query in MainActivity.
/// Used only as a fallback when direct dart:io listing finds files but none
/// are readable (wrong mount, SD-card volume, scoped-storage edge).
class MediaStoreService {
  static const MethodChannel _channel = MethodChannel('wispie/storage');

  Future<List<MediaStoreAudioEntry>> queryAudioEntries() async {
    if (!Platform.isAndroid) return const [];
    try {
      final result =
          await _channel.invokeMethod<List<dynamic>>('queryAudioMedia');
      if (result == null) return const [];
      return result
          .whereType<Map>()
          .map(
              (e) => MediaStoreAudioEntry.fromMap(Map<String, dynamic>.from(e)))
          .where((e) => e.contentUri.isNotEmpty)
          .toList();
    } on PlatformException catch (e) {
      debugPrint('MediaStore query failed: ${e.code} ${e.message}');
      return const [];
    } on MissingPluginException catch (e) {
      debugPrint('MediaStore channel missing: $e');
      return const [];
    }
  }
}
