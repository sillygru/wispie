import 'package:flutter/foundation.dart';

import '../data/rust/rust_library_tasks.dart';
import '../models/song.dart';
import 'storage_service.dart';

/// Sidecar lyrics: `.lrc` and `.ttml` files named after a song.
///
/// Matching, TTML conversion and renames all run in the native core. This is
/// only the adapter that supplies the lyrics folders the user configured, and
/// that keeps a core failure from taking a lyrics view down with it.
class LyricsFilesService {
  LyricsFilesService._();

  static final LyricsFilesService instance = LyricsFilesService._();

  Future<List<String>> _roots() async {
    final folders = await StorageService().getLyricsFolders();
    return [
      for (final folder in folders)
        if ((folder['path'] ?? '').isNotEmpty) folder['path']!,
    ];
  }

  /// Every match per song filename, best first.
  Future<Map<String, LyricsFileLink>> linksFor(List<Song> songs) {
    final local = [
      for (final song in songs)
        if (song.isLocal) song,
    ];
    return _guard(
      () async => RustLibraryTasks.lyricsLinks(local, roots: await _roots()),
      const {},
    );
  }

  /// The same matches with their lyrics text already read and converted.
  Future<Map<String, LyricsFileLink>> textsFor(List<Song> songs) {
    final local = [
      for (final song in songs)
        if (song.isLocal) song,
    ];
    return _guard(
      () async => RustLibraryTasks.lyricsLinks(
        local,
        roots: await _roots(),
        withText: true,
      ),
      const {},
    );
  }

  /// The lyrics text of [song]'s sidecar file, or null when it has none.
  Future<String?> textFor(Song song) async {
    if (!song.isLocal) return null;
    final text = (await textsFor([song]))[song.filename]?.text?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// One sidecar file, read and converted to LRC.
  Future<String?> textForPath(String path) async {
    final link = await _guard(
      () => RustLibraryTasks.lyricsFileText(path),
      null,
    );
    final text = link?.trim();
    return (text == null || text.isEmpty) ? null : text;
  }

  /// Renames sidecar files, mapping each existing path to its song's new stem.
  Future<Map<String, String>> rename(Map<String, String> newStemByPath) async {
    if (newStemByPath.isEmpty) return const {};
    return _guard(
      () => RustLibraryTasks.renameLyrics(newStemByPath),
      const {},
    );
  }

  Future<T> _guard<T>(Future<T> Function() action, T fallback) async {
    if (!RustLibraryTasks.isAvailable) return fallback;
    try {
      return await action();
    } on Object catch (error) {
      debugPrint('Lyrics files: $error');
      return fallback;
    }
  }
}
