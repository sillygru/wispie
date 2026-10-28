import 'dart:io';
import 'dart:isolate';

import 'package:audio_metadata_reader/audio_metadata_reader.dart' as amr;
import 'package:path/path.dart' as p;

import 'media_formats.dart';
import 'song_match_planner.dart';

/// Reads the songs another folder holds, for comparison against the library.
///
/// Deliberately not the scanner: that one is about building library rows — it
/// extracts and caches cover art, consults play counts and folder covers, and
/// writes files while it reads. Comparing a folder only needs what a file says
/// about itself, so this reads tags and leaves everything else alone.
///
/// Pure and Flutter-free, so the part that decides what the library is compared
/// against can be exercised on its own.
class SongFolderReader {
  const SongFolderReader._();

  /// Stops a whole disk being walked by accident. Past this, the folder is not
  /// a candidate set, it is a mistake.
  static const int maxFiles = 20000;

  /// Deep release trees nest a few levels; nothing legitimate nests twenty.
  static const int maxDepth = 12;

  /// Every media file under [root], sorted deepest last.
  ///
  /// Symbolic links are not followed: a link back up the tree would otherwise
  /// be walked until [maxFiles] stopped it. A directory that cannot be listed
  /// is skipped rather than failing the walk — the comparison still has every
  /// other folder to work with, and the counts the screen reports are where a
  /// short listing shows up.
  static Future<List<String>> listMediaFiles(
    String root, {
    bool recursive = true,
  }) async {
    final directory = Directory(root);
    if (!await directory.exists()) return const [];

    final files = <String>[];
    final pending = <MapEntry<Directory, int>>[MapEntry(directory, 0)];

    while (pending.isNotEmpty && files.length < maxFiles) {
      final entry = pending.removeLast();

      final List<FileSystemEntity> children;
      try {
        children = await entry.key.list(followLinks: false).toList();
      } on FileSystemException {
        continue;
      }

      for (final child in children) {
        if (child is File) {
          if (MediaFormats.isSupportedPath(child.path)) {
            files.add(child.path);
            if (files.length >= maxFiles) break;
          }
        } else if (recursive &&
            child is Directory &&
            entry.value < maxDepth &&
            !p.basename(child.path).startsWith('.')) {
          pending.add(MapEntry(child, entry.value + 1));
        }
      }
    }

    files.sort();
    return files;
  }

  /// Reads tags and length for [paths], on a worker isolate.
  ///
  /// [progress] receives the running count, for the reason the rename planner
  /// sends integers: widget state may only be touched from the isolate the UI
  /// lives on.
  static Future<List<FolderSongRef>> readFacts(
    List<String> paths, {
    SendPort? progress,
  }) =>
      Isolate.run(() => readFactsSync(paths, progress: progress));

  /// The same read, on the calling isolate.
  ///
  /// An unreadable file reports nothing about itself rather than failing: its
  /// name is still a candidate, and the comparison — not this read — is what
  /// decides whether it means anything.
  static List<FolderSongRef> readFactsSync(
    List<String> paths, {
    SendPort? progress,
  }) {
    final facts = <FolderSongRef>[];
    for (var i = 0; i < paths.length; i++) {
      facts.add(readFact(paths[i]));
      progress?.send(i + 1);
    }
    return facts;
  }

  /// What one file says about itself.
  static FolderSongRef readFact(String path) {
    try {
      // No image extraction: a comparison never needs the cover, and decoding
      // one is the expensive half of reading a file's tags.
      final metadata = amr.readMetadata(File(path), getImage: false);
      final title = metadata.title?.trim();
      final artist = metadata.artist?.trim();
      final album = metadata.album?.trim();
      final duration = metadata.duration;
      return FolderSongRef(
        path: path,
        title: title?.isEmpty == true ? null : title,
        artist: artist?.isEmpty == true ? null : artist,
        album: album?.isEmpty == true ? null : album,
        duration:
            duration != null && duration.inMilliseconds > 0 ? duration : null,
      );
    } catch (_) {
      return FolderSongRef(path: path);
    }
  }
}
