import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../domain/services/native_accel.dart';
import '../models/song.dart';
import 'wispie_cache.dart';
import 'cover_refresh_service.dart';
import 'database_service.dart';
import 'scanner_service.dart';
import 'storage_service.dart';

/// What a repair run changed.
class LibraryRepairReport {
  final int rowsExamined;
  final int coversRepointed;
  final int coversCleared;
  final int urlsReresolved;
  final int rowsDropped;
  final int coverMissesCleared;

  /// Cover paths now backing a different row than before, so their decoded
  /// bitmaps must be evicted.
  final List<String> changedCoverPaths;

  /// Whether pruning was skipped because the music folders couldn't be read.
  final bool pruningSkipped;

  const LibraryRepairReport({
    this.rowsExamined = 0,
    this.coversRepointed = 0,
    this.coversCleared = 0,
    this.urlsReresolved = 0,
    this.rowsDropped = 0,
    this.coverMissesCleared = 0,
    this.changedCoverPaths = const [],
    this.pruningSkipped = false,
  });

  bool get madeChanges =>
      coversRepointed > 0 ||
      coversCleared > 0 ||
      urlsReresolved > 0 ||
      rowsDropped > 0;

  /// A one-line summary for a snackbar or an indexer result.
  String get summary {
    if (rowsExamined == 0) return 'No songs to repair';
    if (!madeChanges) return 'Library links are already correct';
    final parts = <String>[];
    if (coversRepointed > 0) parts.add('re-linked $coversRepointed covers');
    if (coversCleared > 0) parts.add('cleared $coversCleared dead covers');
    if (urlsReresolved > 0) parts.add('relocated $urlsReresolved tracks');
    if (rowsDropped > 0) parts.add('removed $rowsDropped missing tracks');
    return '${parts.first[0].toUpperCase()}${parts.first.substring(1)}'
        '${parts.length > 1 ? ', ${parts.skip(1).join(', ')}' : ''}';
  }
}

/// Reconciles the library table with the filesystem it is actually sitting on.
///
/// Restoring a backup replaces `wispie_data.db` wholesale, so the `song` table
/// arrives describing the device the archive came from: cover paths into a
/// directory that may hold nothing, audio paths that may not exist, and a
/// `cover_miss` table recording failures against files this device has never
/// seen. Nothing downstream notices — the scanner reuses rows it thinks are
/// current, and the lazy cover path gives up the moment a song's `url` doesn't
/// stat — so the covers simply stay missing.
///
/// Probing and every merge/drop decision are native; this class owns the
/// database writes and the image-cache invalidation around them.
class LibraryRepairService {
  static final LibraryRepairService instance = LibraryRepairService._();

  LibraryRepairService._();

  /// Re-links covers and audio paths, and prunes rows whose files are gone.
  ///
  /// [preImportSongs] are rows read before an import overwrote them; they win
  /// on anything describing this filesystem. [importedRows] are library rows an
  /// archive supplied but that were deliberately not written yet, so this pass
  /// is the only thing that ever writes the `song` table on an import path.
  Future<LibraryRepairReport> repairLibrary({
    List<Song>? preImportSongs,
    List<Song>? importedRows,
    bool dropUnresolvable = true,
    void Function(double progress, String label)? onProgress,
  }) async {
    onProgress?.call(0, 'Reading library…');

    final rows = await DatabaseService.instance.getAllSongs();
    if (rows.isEmpty &&
        (preImportSongs?.isEmpty ?? true) &&
        (importedRows?.isEmpty ?? true)) {
      return const LibraryRepairReport();
    }

    final coversDir = await ScannerService.coversDirectory();

    onProgress?.call(0.05, 'Locating music files…');
    final folders = await _readableMusicFolders();

    final plan = NativeAccel.libraryRepairPlan(
      rows: [for (final row in rows) row.toJson()],
      preImportSongs: [
        for (final row in preImportSongs ?? const <Song>[]) row.toJson()
      ],
      importedRows: [
        for (final row in importedRows ?? const <Song>[]) row.toJson()
      ],
      coversDir: coversDir.path,
      musicFolders: folders,
      dropUnresolvable: dropUnresolvable,
    );

    onProgress?.call(0.9, 'Saving…');

    final updates = [
      for (final row in plan['updates'] as List)
        Song.fromJson(Map<String, dynamic>.from(row as Map)),
    ];
    final dropped = [
      for (final name in plan['dropped'] as List) name as String
    ];
    final changedCovers = [
      for (final path in plan['changedCovers'] as List) path as String
    ];

    if (updates.isNotEmpty) {
      // The one caller allowed to null a cover: here a null is a considered
      // finding, not a failure to look.
      await DatabaseService.instance
          .insertSongsBatch(updates, preserveCoverUrl: false);
    }
    if (dropped.isNotEmpty) {
      await DatabaseService.instance.deleteSongsByFilenames(dropped);
    }

    final missesCleared =
        (await DatabaseService.instance.getCoverMisses()).length;
    await DatabaseService.instance.clearAllCoverMisses();
    CoverRefreshService.instance.invalidateMisses();

    // Deliberately not WispieCache.prune: it builds its keep-set
    // from the cover paths currently in the library and deletes everything else
    // under extracted_covers, which after a device change would delete the very
    // files this pass exists to find.

    // Let the next launch run a real scan rather than trusting restored rows.
    await WispieCache.instance.markLibraryChanged();

    for (final path in changedCovers) {
      await CoverRefreshService.evictCoverFromImageCache(path);
    }

    onProgress?.call(1.0, 'Done');

    final rowsExamined = (plan['rowsExamined'] as num).toInt();
    if (rowsExamined == 0) return const LibraryRepairReport();
    return LibraryRepairReport(
      rowsExamined: rowsExamined,
      coversRepointed: (plan['coversRepointed'] as num).toInt(),
      coversCleared: (plan['coversCleared'] as num).toInt(),
      urlsReresolved: (plan['urlsReresolved'] as num).toInt(),
      rowsDropped: dropped.length,
      coverMissesCleared: missesCleared,
      changedCoverPaths: changedCovers,
      pruningSkipped: plan['pruningSkipped'] as bool,
    );
  }

  Future<List<String>> _readableMusicFolders() async {
    try {
      // forceRefresh because the cached list is process-wide and may predate
      // the import that just rewrote it — and this pass decides what to delete.
      final folders =
          await StorageService().getMusicFolders(forceRefresh: true);
      final readable = <String>[];
      for (final folder in folders) {
        final path = folder['path'];
        if (path == null || path.isEmpty) continue;
        if (await Directory(path).exists()) readable.add(path);
      }
      return readable;
    } catch (e) {
      debugPrint('LibraryRepairService: could not read music folders: $e');
      return const [];
    }
  }
}
