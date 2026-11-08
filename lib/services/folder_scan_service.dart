import 'dart:isolate';

import '../data/rust/rust_library_tasks.dart';
import '../domain/services/song_match_planner.dart';

/// Listing and tag reads for comparing a folder against the library.
///
/// Both run on the native core. [SongFolderReader] stays the pure-Dart reader
/// the batch-replace planner's probes exercise, but the app does not fall back
/// to it: a build without the core cannot compare folders.
class FolderScanService {
  const FolderScanService._();

  /// Every media file under [root], newest walk order does not matter: sorted.
  static Future<List<String>> listMediaFiles(
    String root, {
    bool recursive = true,
  }) =>
      RustLibraryTasks.listMedia(root, recursive: recursive);

  /// Tags and length for [paths], off the UI isolate.
  ///
  /// [progress] receives the running count as an integer, for the reason the
  /// rename planner sends integers: widget state may only be touched from the
  /// isolate the UI lives on.
  static Future<List<FolderSongRef>> readFacts(
    List<String> paths, {
    SendPort? progress,
  }) async {
    final facts = await RustLibraryTasks.folderFacts(paths, progress: progress);
    return [
      for (final fact in facts)
        FolderSongRef(
          path: fact['path'] as String? ?? '',
          title: _text(fact['title']),
          artist: _text(fact['artist']),
          album: _text(fact['album']),
          duration: _duration(fact['duration']),
        ),
    ];
  }

  static String? _text(Object? raw) {
    final value = raw as String?;
    if (value == null) return null;
    final trimmed = value.trim();
    return trimmed.isEmpty ? null : trimmed;
  }

  static Duration? _duration(Object? raw) {
    final seconds = (raw as num?)?.toDouble();
    if (seconds == null || seconds <= 0) return null;
    return Duration(milliseconds: (seconds * 1000).round());
  }
}
