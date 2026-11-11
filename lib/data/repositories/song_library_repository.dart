import 'package:sqflite/sqlite_api.dart';

import '../../models/song.dart';

class SongLibraryRepository {
  static Future<void> writeBatch(
    Database db,
    List<Song> songs, {
    bool preserveCoverUrl = true,
    bool replaceLibrary = false,
  }) async {
    if (songs.isEmpty && !replaceLibrary) return;
    await db.transaction((txn) async {
      final existingMap = <String, Map<String, Object?>>{};
      if (preserveCoverUrl) {
        const chunkSize = 500;
        final filenames = songs.map((s) => s.filename).toList();
        for (var i = 0; i < filenames.length; i += chunkSize) {
          final end = (i + chunkSize).clamp(0, filenames.length);
          final chunk = filenames.sublist(i, end);
          final placeholders = List.filled(chunk.length, '?').join(', ');
          final rows = await txn.query(
            'song',
            columns: ['filename', 'cover_url', 'created_epoch_sec'],
            where: 'filename IN ($placeholders)',
            whereArgs: chunk,
          );
          for (final row in rows) {
            final fn = row['filename'] as String?;
            if (fn != null) {
              existingMap[fn] = row;
            }
          }
        }
      }

      final batch = txn.batch();
      if (replaceLibrary) {
        final scanned = {for (final song in songs) song.filename};
        final rows = await txn.query('song', columns: ['filename']);
        for (final row in rows) {
          final filename = row['filename'] as String;
          if (!scanned.contains(filename)) {
            batch.delete('song', where: 'filename = ?', whereArgs: [filename]);
          }
        }
      }
      for (final song in songs) {
        final existing = existingMap[song.filename];
        final existingCoverUrl = existing?['cover_url'] as String?;
        final existingCreatedEpochSec =
            (existing?['created_epoch_sec'] as num?)?.toDouble();

        // A new cover wins over the old one, but null preserves existing art.
        final effectiveCoverUrl = (preserveCoverUrl && song.coverUrl == null)
            ? existingCoverUrl
            : song.coverUrl;

        // Earliest known date added wins over a later scan.
        final effectiveCreatedEpochSec =
            existingCreatedEpochSec ?? song.createdEpochSec;

        if (preserveCoverUrl) {
          existingMap[song.filename] = {
            'cover_url': effectiveCoverUrl,
            'created_epoch_sec': effectiveCreatedEpochSec,
          };
        }

        final values = <String, Object?>{
          'filename': song.filename,
          'title': song.title,
          'artist': song.artist,
          'album': song.album,
          'url': song.url,
          'cover_url': effectiveCoverUrl,
          'has_lyrics': song.hasLyrics ? 1 : 0,
          'play_count': song.playCount,
          'duration_ms': song.duration?.inMilliseconds,
          'mtime': song.mtime,
          'created_epoch_sec': effectiveCreatedEpochSec,
          'song_date_epoch_sec': song.songDateEpochSec,
        };

        batch.insert(
          'song',
          values,
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }
      await batch.commit(noResult: true);
    });
  }

  static Future<bool> updateCover(Database db, Song song, String path) async {
    final changed = await db.update(
      'song',
      {'cover_url': path},
      where: 'filename = ? AND url = ? AND mtime IS ?',
      whereArgs: [song.filename, song.url, song.mtime],
    );
    return changed > 0;
  }
}
