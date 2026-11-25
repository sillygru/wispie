import 'dart:async';
import 'dart:convert';
import 'package:path/path.dart';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import '../data/rust/native_database.dart';
import '../data/repositories/song_identity_repository.dart';
import '../domain/models/listening_insights.dart';
import '../domain/models/youtube_playlist_link.dart';
import '../domain/services/fun_stats_export.dart';
import '../domain/services/insights_builder.dart';
import '../models/playlist.dart';
import '../models/queue_snapshot.dart';
import '../models/song.dart';
import 'import_options.dart';
import 'sync/hlc.dart';
import 'sync_service.dart';
import 'wispie_paths.dart';

/// DatabaseService handles local SQLite storage.
class DatabaseService {
  static const double _skipRatioThreshold = 0.25;

  static DatabaseService _instance = DatabaseService._init();
  static DatabaseService get instance => _instance;

  @visibleForTesting
  static set instance(DatabaseService mock) => _instance = mock;

  Database? _statsDatabase;
  Database? _userDataDatabase;
  Future<void>? _initFuture;

  DatabaseService._init();

  @visibleForTesting
  DatabaseService.forTest();

  Future<Database> get userDataDb async {
    await _ensureInitialized();
    return _userDataDatabase!;
  }

  Future<void> init() {
    final existing = _initFuture;
    if (existing != null) return existing;
    _initFuture = _initAsync().catchError((Object e) {
      _initFuture = null;
      throw e;
    });
    return _initFuture!;
  }

  Future<void> _initAsync() async {
    try {
      await Hlc.instance.load();
      final stats = await _openDatabase(
        'wispie_stats.db',
        schema: DatabaseSchema.stats,
      );
      try {
        _userDataDatabase = await _openDatabase(
          'wispie_data.db',
          schema: DatabaseSchema.userData,
        );
        _statsDatabase = stats;
      } catch (_) {
        await stats.close();
        rethrow;
      }
    } catch (e) {
      debugPrint('Database initialization failed: $e');
      rethrow;
    }
  }

  // Schema is canonical in rust/wispie_core/src/db.rs; the core runs the
  // create path and the upgrade ladder when a file is opened.

  // ==========================================================================
  // SYNC CHANGE TRACKING HELPERS
  // ==========================================================================

  int _hlcNow() {
    SyncService.instance.notifyLocalWrite();
    return Hlc.instance.now();
  }

  /// Runs one user-list operation in the core, which owns the statements and
  /// the stamp/tombstone rules.
  Future<Map<String, Object?>> _userList(
    String kind,
    String op, {
    String? filename,
    List<String>? filenames,
  }) {
    final fields = <String, Object?>{'kind': kind, 'op': op};
    if (filename != null) fields['filename'] = filename;
    if (filenames != null) fields['filenames'] = filenames;
    if (op != 'list') {
      fields['hlc'] = _hlcNow();
      fields['now'] = DateTime.now().millisecondsSinceEpoch / 1000.0;
    }
    return _userDataDatabase!.coreCommand('user_list', fields);
  }

  Future<Map<String, Object?>> _coverMiss(
    String op, {
    String? filename,
    double? fileMtime,
    List<String>? filenames,
  }) {
    final fields = <String, Object?>{'op': op};
    if (filename != null) fields['filename'] = filename;
    if (fileMtime != null) fields['file_mtime'] = fileMtime;
    if (filenames != null) fields['filenames'] = filenames;
    if (op == 'mark') {
      fields['now'] = DateTime.now().millisecondsSinceEpoch / 1000.0;
    }
    return _userDataDatabase!.coreCommand('cover_miss', fields);
  }

  Future<Map<String, Object?>> _lyricsOffset(
    String op, {
    String? filename,
    double? seconds,
  }) {
    final fields = <String, Object?>{'op': op};
    if (filename != null) fields['filename'] = filename;
    if (seconds != null) fields['seconds'] = seconds;
    return _userDataDatabase!.coreCommand('lyrics_offset', fields);
  }

  Future<Map<String, Object?>> _art(
    String kind,
    String op, {
    Map<String, Object?> fields = const {},
  }) =>
      _userDataDatabase!.coreCommand('art', {
        'kind': kind,
        'op': op,
        ...fields,
      });

  /// Records that a whitelisted setting changed locally so the sync engine can
  /// push it. Values stay in SharedPreferences; only the clock lives here.
  Future<void> stampSettingDirty(String key) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _userDataDatabase!.coreCommand('sync_store', {
      'op': 'setting_write',
      'key': key,
      'hlc': _hlcNow(),
      'dirty': true,
    });
  }

  Future<void> _ensureInitialized() async {
    final f = _initFuture;
    if (f == null) {
      throw Exception('DatabaseService not initialized. Call init() first.');
    }
    return f;
  }

  /// Ensures the database is initialized
  /// Throws if not initialized
  Future<void> ensureInitialized() async {
    await _ensureInitialized();
  }

  /// Gets the stats database connection
  /// Returns null if not initialized
  Database? getStatsDatabase() {
    return _statsDatabase;
  }

  /// Gets the user data database connection
  /// Returns null if not initialized
  Database? getUserDataDatabase() {
    return _userDataDatabase;
  }

  Future<Database> _openDatabase(
    String name, {
    required DatabaseSchema schema,
  }) async {
    final wispieDir = await getWispieDirectory();
    final path = join(wispieDir.path, name);
    // Creation and the version ladder run in the core; the clock is passed in
    // because only the app knows its hybrid-logical-clock position.
    return openDatabase(path, schema: schema, hlc: Hlc.instance.now());
  }

  static Future<List<Map<String, dynamic>>> playbackRows(
    Database database,
    String op, [
    List<Object?> args = const [],
  ]) async {
    final reply =
        await database.coreCommand('playback', {'op': op, 'args': args});
    return (reply['rows'] as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAllPlayEvents() async {
    await _ensureInitialized();
    final db = _statsDatabase;
    if (db == null) return [];
    return playbackRows(db, 'events');
  }

  /// Gets all play sessions ordered by start time (newest first)
  /// Filters out sessions shorter than minDurationSeconds
  Future<List<Map<String, dynamic>>> getPlaySessions(
      {int minDurationSeconds = 30}) async {
    await _ensureInitialized();
    if (_statsDatabase == null) return [];

    try {
      return await playbackRows(
          _statsDatabase!, 'sessions', [minDurationSeconds]);
    } catch (e) {
      debugPrint('Error getting play sessions: $e');
      return [];
    }
  }

  /// Gets all play events for a specific session, ordered by timestamp (oldest first)
  Future<List<Map<String, dynamic>>> getPlayEventsForSession(
      String sessionId) async {
    await _ensureInitialized();
    if (_statsDatabase == null) return [];

    try {
      return await playbackRows(_statsDatabase!, 'session_events', [sessionId]);
    } catch (e) {
      debugPrint('Error getting play events for session: $e');
      return [];
    }
  }

  Future<void> clearStats() => clearAllPlayStats();

  // ==========================================================================
  // QUEUE SNAPSHOT QUERIES
  // ==========================================================================

  /// Inserts a snapshot. Older snapshots with the same source and songs are
  /// removed so replaying a queue moves it to the top with the new time instead
  /// of reviving the old entry.
  Future<void> saveQueueSnapshot(String id, String name, double createdAt,
      String source, List<String> songFilenames) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('queue_snapshot_op', {
      'op': 'save',
      'snapshotId': id,
      'name': name,
      'createdAt': createdAt,
      'source': source,
      'filenames': songFilenames,
      'hlc': _hlcNow(),
    });
  }

  /// Returns false when the snapshot no longer exists (pruned, deleted, or
  /// removed by sync), so the caller can start a new one. Unchanged lists are
  /// not rewritten, which keeps them from churning sync.
  Future<bool> updateQueueSnapshotSongs(
      String id, List<String> songFilenames) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return false;

    final reply = await _userDataDatabase!.coreCommand('queue_snapshot_op', {
      'op': 'update_songs',
      'snapshotId': id,
      'filenames': songFilenames,
      'hlc': _hlcNow(),
    });
    return reply['exists'] == true;
  }

  Future<List<Map<String, dynamic>>> getQueueSnapshots() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];

    try {
      final reply = await _userDataDatabase!
          .coreCommand('queue_snapshot_op', {'op': 'list'});
      return [
        for (final row in reply['snapshots'] as List)
          Map<String, dynamic>.from(row as Map),
      ];
    } catch (e) {
      debugPrint('Error getting queue snapshots: $e');
      return [];
    }
  }

  Future<List<QueueSnapshot>> getQueueHistorySnapshots() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];

    try {
      final reply = await _userDataDatabase!
          .coreCommand('queue_snapshot_op', {'op': 'history'});
      final result = <QueueSnapshot>[];
      for (final entry in reply['history'] as List) {
        final row = (entry as Map).cast<String, Object?>();
        final createdAtRaw = row['created_at'];
        final createdAt = createdAtRaw is num
            ? createdAtRaw.toDouble()
            : double.tryParse(createdAtRaw?.toString() ?? '') ??
                DateTime.now().millisecondsSinceEpoch / 1000.0;
        final nameRaw = row['name']?.toString();
        final name = (nameRaw != null && nameRaw.trim().isNotEmpty)
            ? nameRaw.trim()
            : QueueSnapshot.defaultNameForTimestamp(createdAt);
        result.add(QueueSnapshot(
          id: row['id'] as String,
          name: name,
          createdAt: createdAt,
          songFilenames: [
            for (final song in row['songs'] as List) song as String,
          ],
          source: row['source'] as String? ?? 'unknown',
        ));
      }
      return result;
    } catch (e) {
      debugPrint('Error loading queue history snapshots: $e');
      return [];
    }
  }

  Future<List<String>> getQueueSnapshotSongs(String snapshotId) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];

    try {
      final reply = await _userDataDatabase!.coreCommand('queue_snapshot_op', {
        'op': 'songs',
        'snapshotId': snapshotId,
      });
      return [for (final name in reply['filenames'] as List) name as String];
    } catch (e) {
      debugPrint('Error getting queue snapshot songs: $e');
      return [];
    }
  }

  Future<void> deleteQueueSnapshot(String id) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('queue_snapshot_op', {
      'op': 'delete',
      'snapshotId': id,
      'hlc': _hlcNow(),
    });
  }

  Future<void> clearQueueHistory() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!
        .coreCommand('queue_snapshot_op', {'op': 'clear', 'hlc': _hlcNow()});
  }

  /// Keeps the history bounded; the core retains the most recent entries.
  Future<void> pruneQueueSnapshots() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!
        .coreCommand('queue_snapshot_op', {'op': 'prune', 'hlc': _hlcNow()});
  }

  Future<List<Map<String, dynamic>>> exportQueueHistory() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];

    final reply = await _userDataDatabase!
        .coreCommand('queue_snapshot_op', {'op': 'export'});
    return [
      for (final row in reply['snapshots'] as List)
        Map<String, dynamic>.from(row as Map),
    ];
  }

  /// Rebuilds the synced `songs_json` mirror from `queue_snapshot_song` and
  // ==========================================================================
  // CURRENT QUEUE (synced)
  // ==========================================================================

  Future<void> saveCurrentQueue(Map<String, Object?> queue) async {
    await _ensureInitialized();
    final db = _userDataDatabase;
    if (db == null) return;
    await db.coreCommand('queue_snapshot_op', {
      'op': 'current_save',
      'queueJson': jsonEncode(queue),
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
      'hlc': _hlcNow(),
    });
  }

  Future<Map<String, dynamic>?> loadCurrentQueue() async {
    await _ensureInitialized();
    final db = _userDataDatabase;
    if (db == null) return null;
    final reply =
        await db.coreCommand('queue_snapshot_op', {'op': 'current_load'});
    final raw = reply['queue_json'] as String?;
    if (raw == null) return null;
    try {
      return Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> importQueueHistory(List<Map<String, dynamic>> data) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    final snapshots = <Map<String, Object?>>[];
    for (final snapshot in data) {
      final createdAt = double.tryParse('${snapshot['created_at']}') ??
          DateTime.now().millisecondsSinceEpoch / 1000;
      final id = snapshot['id']?.toString().trim();
      final name = snapshot['name']?.toString().trim();
      snapshots.add({
        'id': (id == null || id.isEmpty)
            ? QueueSnapshot.timestampMarkerFromEpochSeconds(createdAt)
            : id,
        'name': (name == null || name.isEmpty)
            ? QueueSnapshot.defaultNameForTimestamp(createdAt)
            : name,
        'created_at': createdAt,
        'source': snapshot['source'] as String? ?? 'imported',
        'songs': (snapshot['songs'] as List?)
                ?.map((song) => song.toString())
                .toList() ??
            <String>[],
      });
    }
    await _userDataDatabase!.coreCommand('restore', {
      'kind': 'queue_history',
      'snapshots': snapshots,
    });
  }

  // ==========================================================================
  // SONG QUERIES
  // ==========================================================================

  /// Upserts library rows, keyed by [Song.filename].
  ///
  /// With [preserveCoverUrl] — the default — a null incoming `cover_url` leaves
  /// whatever the row already had. That guard is deliberately at this level
  /// rather than in each caller: a scan that couldn't read a file, a cover
  /// rebuild that couldn't resolve one, and an import carrying another device's
  /// rows all produce nulls, and any one of them silently erasing working
  /// artwork is the bug this exists to make unrepresentable. `created_epoch_sec`
  /// is protected the same way so "date added" survives a rescan.
  ///
  /// Only [LibraryRepairService] passes false, because clearing a `cover_url`
  /// that no longer resolves is exactly its job — a null there is a considered
  /// decision, not a failure to look.
  Future<void> insertSongsBatch(
    List<Song> songs, {
    bool preserveCoverUrl = true,
  }) =>
      _writeSongs(songs, preserveCoverUrl: preserveCoverUrl);

  Future<void> replaceLibrarySongs(List<Song> songs) =>
      _writeSongs(songs, replaceLibrary: true);

  Future<void> _writeSongs(
    List<Song> songs, {
    bool preserveCoverUrl = true,
    bool replaceLibrary = false,
  }) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    if (songs.isEmpty && !replaceLibrary) return;
    await _userDataDatabase!.coreCommand('song_op', {
      'op': 'write_batch',
      'preserveCoverUrl': preserveCoverUrl,
      'replaceLibrary': replaceLibrary,
      'songs': [for (final song in songs) _songRow(song)],
    });
  }

  Map<String, Object?> _songRow(Song song) => {
        'filename': song.filename,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'url': song.url,
        'cover_url': song.coverUrl,
        'has_lyrics': song.hasLyrics ? 1 : 0,
        'play_count': song.playCount,
        'duration_ms': song.duration?.inMilliseconds,
        'mtime': song.mtime,
        'created_epoch_sec': song.createdEpochSec,
        'song_date_epoch_sec': song.songDateEpochSec,
      };

  Future<bool> updateSongCover(Song song, String path) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return false;
    final reply = await _userDataDatabase!.coreCommand('song_op', {
      'op': 'update_cover',
      'filename': song.filename,
      'url': song.url,
      'mtime': song.mtime,
      'coverPath': path,
    });
    return reply['changed'] == true;
  }

  /// Songs already probed for cover art and found to have none, keyed by
  /// filename with the file mtime at the time of the probe. A changed mtime
  /// means the file was edited and is worth probing again.
  Future<Map<String, double>> getCoverMisses() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return {};
    final reply = await _coverMiss('list');
    return {
      for (final row in reply['items'] as List? ?? const [])
        (row as Map)['filename'] as String:
            ((row['file_mtime'] as num?)?.toDouble() ?? 0),
    };
  }

  Future<void> markCoverMiss(String filename, double fileMtime) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _coverMiss('mark', filename: filename, fileMtime: fileMtime);
  }

  Future<void> clearCoverMiss(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _coverMiss('clear', filename: filename);
  }

  /// Forgets the negative cache entirely.
  ///
  /// Every entry records "this file had no art" as observed on some device at
  /// some time. After a restore or a cover-cache wipe none of that is still
  /// trustworthy, and re-probing is precisely the behaviour we want back.
  Future<void> clearAllCoverMisses() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _coverMiss('clear_all');
  }

  Future<void> clearCoverMisses(Iterable<String> filenames) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    final list = filenames.toList();
    if (list.isEmpty) return;
    await _coverMiss('clear_many', filenames: list);
  }

  /// Drops every cached cover path without touching the files.
  ///
  /// Pairs with deleting the cover directory: leaving the paths behind is what
  /// makes a "clear cover cache" look like it did nothing, because every row
  /// still points at a hole instead of being null enough for the lazy
  /// extraction path to take over.
  Future<int> clearCoverUrls() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return 0;
    final reply = await _userDataDatabase!
        .coreCommand('song_op', {'op': 'clear_cover_urls'});
    return (reply['changed'] as num?)?.toInt() ?? 0;
  }

  Future<void> deleteSongsByFilenames(Iterable<String> filenames) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    final list = filenames.toList();
    if (list.isEmpty) return;
    await _userDataDatabase!
        .coreCommand('song_op', {'op': 'delete', 'filenames': list});
  }

  /// SQLite caps a statement at 999 variables by default; stay well under it.
  Future<List<Song>> getAllSongs() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];
    final reply =
        await _userDataDatabase!.coreCommand('song_op', {'op': 'all'});
    return [
      for (final row in reply['songs'] as List)
        _mapToSong(Map<String, dynamic>.from(row as Map)),
    ];
  }

  Future<Song?> getSongByFilename(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return null;
    final reply = await _userDataDatabase!
        .coreCommand('song_op', {'op': 'get', 'filename': filename});
    final row = reply['song'];
    if (row == null) return null;
    return _mapToSong(Map<String, dynamic>.from(row as Map));
  }

  Future<void> upsertRemoteSong(Song song) async {
    if (!song.isRemote || song.remoteId == null || song.remoteId!.isEmpty) {
      return;
    }
    await _ensureInitialized();
    final db = _userDataDatabase;
    if (db == null) return;
    await db.coreCommand('song_op', {
      'op': 'remote_upsert',
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
      'song': {
        'filename': song.filename,
        'remote_id': song.remoteId,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        'cover_url': song.coverUrl,
        'duration_ms': song.duration?.inMilliseconds,
        'is_available': song.isAvailable ? 1 : 0,
      },
    });
  }

  /// Streamed tracks the listener saved to the library, by filename.
  Future<Set<String>> getLibraryRemoteFilenames() async {
    await _ensureInitialized();
    final db = _userDataDatabase;
    if (db == null) return <String>{};
    final reply = await db.coreCommand('song_op', {'op': 'remote_library'});
    return {for (final name in reply['filenames'] as List) name as String};
  }

  /// Marks a streamed track as part of the library, or drops it out again.
  ///
  /// The row itself is the metadata, so a track without one cannot be saved:
  /// callers cache it first. Returns false when no row matched.
  Future<bool> setRemoteSongInLibrary(String filename, bool inLibrary) async {
    await _ensureInitialized();
    final db = _userDataDatabase;
    if (db == null) return false;
    final reply = await db.coreCommand('song_op', {
      'op': 'remote_set_library',
      'filename': filename,
      'inLibrary': inLibrary,
    });
    return reply['changed'] == true;
  }

  Future<List<Song>> getRemoteSongs() async {
    await _ensureInitialized();
    final db = _userDataDatabase;
    if (db == null) return [];
    final reply = await db.coreCommand('song_op', {'op': 'remote_all'});
    final rows = [
      for (final row in reply['songs'] as List)
        Map<String, dynamic>.from(row as Map),
    ];
    // The source is not a column: the filename prefix already carries it, and
    // rebuilding through fromJson keeps one parser for every remote track.
    return rows
        .map((row) => Song.fromJson({
              'filename': row['filename'],
              'remote_id': row['remote_id'],
              'title': row['title'],
              'artist': row['artist'],
              'album': row['album'] ?? '',
              'cover_url': row['cover_url'],
              'duration': row['duration_ms'] == null
                  ? null
                  : (row['duration_ms'] as int) / 1000.0,
              'is_available': (row['is_available'] as int? ?? 1) == 1,
            }))
        .toList();
  }

  Future<double> getLyricsTimingOffset(String filename) async {
    await _ensureInitialized();
    final db = _userDataDatabase;
    if (db == null) return 0;
    final reply = await _lyricsOffset('get', filename: filename);
    return (reply['offset'] as num).toDouble();
  }

  Future<void> setLyricsTimingOffset(String filename, double offset) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _lyricsOffset('set', filename: filename, seconds: offset);
  }

  Future<List<Song>> getSongs() => getAllSongs();

  Future<int> getSongCount() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return 0;
    final reply =
        await _userDataDatabase!.coreCommand('song_op', {'op': 'count'});
    return (reply['count'] as num?)?.toInt() ?? 0;
  }

  Future<void> clearSongs() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _userDataDatabase!.coreCommand('song_op', {'op': 'clear'});
  }

  Future<List<String>> getArtists() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];
    final reply =
        await _userDataDatabase!.coreCommand('song_op', {'op': 'artists'});
    return [for (final name in reply['values'] as List) name as String];
  }

  Future<List<String>> getAlbums() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];
    final reply =
        await _userDataDatabase!.coreCommand('song_op', {'op': 'albums'});
    return [for (final name in reply['values'] as List) name as String];
  }

  Song _mapToSong(Map<String, dynamic> r) {
    return Song(
      title: r['title'] as String,
      artist: r['artist'] as String,
      album: r['album'] as String,
      filename: r['filename'] as String,
      url: r['url'] as String,
      coverUrl: r['cover_url'] as String?,
      hasLyrics: (r['has_lyrics'] as int) == 1,
      playCount: r['play_count'] as int,
      duration: r['duration_ms'] != null
          ? Duration(milliseconds: r['duration_ms'] as int)
          : null,
      mtime: (r['mtime'] as num?)?.toDouble(),
      createdEpochSec: (r['created_epoch_sec'] as num?)?.toDouble(),
      songDateEpochSec: (r['song_date_epoch_sec'] as num?)?.toDouble(),
    );
  }

  // ==========================================================================
  // USER DATA QUERIES
  // ==========================================================================

  Future<List<String>> getFavorites() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];
    try {
      final reply = await _userList('favorite', 'list');
      return [
        for (final item in reply['items'] as List? ?? const []) item as String,
      ];
    } catch (e) {
      debugPrint('Error getting favorites: $e');
      return [];
    }
  }

  Future<void> addFavorite(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _userList('favorite', 'add', filename: filename);
  }

  Future<void> removeFavorite(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _userList('favorite', 'remove', filename: filename);
  }

  /// Replaces all local favorites with the given list
  Future<void> setFavorites(List<String> favorites) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userList('favorite', 'set', filenames: favorites);
  }

  Future<List<String>> getSuggestLess() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];
    try {
      final reply = await _userList('suggestless', 'list');
      return [
        for (final item in reply['items'] as List? ?? const []) item as String,
      ];
    } catch (e) {
      debugPrint('Error getting suggestless: $e');
      return [];
    }
  }

  Future<void> addSuggestLess(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _userList('suggestless', 'add', filename: filename);
  }

  Future<void> removeSuggestLess(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _userList('suggestless', 'remove', filename: filename);
  }

  Future<List<String>> getHidden() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];
    try {
      final reply = await _userList('hidden', 'list');
      return [
        for (final item in reply['items'] as List? ?? const []) item as String,
      ];
    } catch (e) {
      debugPrint('Error getting hidden: $e');
      return [];
    }
  }

  Future<void> addHidden(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _userList('hidden', 'add', filename: filename);
  }

  Future<void> removeHidden(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;
    await _userList('hidden', 'remove', filename: filename);
  }

  Future<void> setHidden(List<String> hidden) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userList('hidden', 'set', filenames: hidden);
  }

  // ==========================================================================
  // PLAYLIST QUERIES
  // ==========================================================================

  Future<List<Playlist>> getPlaylists() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];
    try {
      final reply =
          await _userDataDatabase!.coreCommand('playlist_op', {'op': 'list'});
      return [
        for (final row in reply['playlists'] as List)
          Playlist(
            id: row['id'] as String,
            name: row['name'] as String,
            description: row['description'] as String?,
            isRecommendation: (row['is_recommendation'] as int? ?? 0) == 1,
            createdAt: (row['created_at'] as num).toDouble(),
            updatedAt: (row['updated_at'] as num).toDouble(),
            songs: [
              for (final song in row['songs'] as List)
                PlaylistSong.fromJson((song as Map).cast<String, Object?>()),
            ],
          ),
      ];
    } catch (e) {
      debugPrint('Error getting playlists: $e');
      return [];
    }
  }

  Future<void> savePlaylist(Playlist playlist) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('playlist_op', {
      'op': 'save',
      'hlc': _hlcNow(),
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
      'playlist': {
        'id': playlist.id,
        'name': playlist.name,
        'description': playlist.description,
        'is_recommendation': playlist.isRecommendation ? 1 : 0,
        'created_at': playlist.createdAt,
        'updated_at': playlist.updatedAt,
        'songs': [
          for (final song in playlist.songs)
            {'song_filename': song.songFilename, 'added_at': song.addedAt},
        ],
      },
    });
  }

  // Deep validation of all recommendation playlist DB entries.
  // Re-reads every row and every song entry using the same casts as getPlaylists().
  // Returns false if even one field fails to parse correctly, triggering a regeneration.
  Future<bool> validateRecommendationPlaylists() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return false;
    try {
      final reply = await _userDataDatabase!
          .coreCommand('playlist_op', {'op': 'validate'});
      return reply['valid'] == true;
    } catch (e) {
      debugPrint('Recommendation DB validation error: $e');
      return false;
    }
  }

  Future<void> deletePlaylist(String playlistId) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('playlist_op', {
      'op': 'delete',
      'hlc': _hlcNow(),
      'playlistId': playlistId,
    });
  }

  // ==========================================================================
  // YOUTUBE ACCOUNT PLAYLINKS
  // ==========================================================================

  Future<List<YouTubePlaylistLink>> getYouTubePlaylistLinks() async {
    await _ensureInitialized();
    final db = _userDataDatabase;
    if (db == null) return [];
    final reply = await db.coreCommand('youtube_link_op', {'op': 'list'});
    return [
      for (final row in reply['links'] as List)
        YouTubePlaylistLink.fromRow((row as Map).cast<String, Object?>()),
    ];
  }

  Future<void> upsertYouTubePlaylistLink(YouTubePlaylistLink link) async {
    await _ensureInitialized();
    await _userDataDatabase?.coreCommand('youtube_link_op', {
      'op': 'save',
      'link': link.toRow(),
    });
  }

  Future<void> deleteYouTubePlaylistLink(String remotePlaylistId) async {
    await _ensureInitialized();
    await _userDataDatabase?.coreCommand('youtube_link_op', {
      'op': 'delete',
      'remotePlaylistId': remotePlaylistId,
    });
  }

  Future<void> addSongToPlaylist(String playlistId, String songFilename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('playlist_op', {
      'op': 'add_songs',
      'hlc': _hlcNow(),
      'playlistId': playlistId,
      'filenames': [songFilename],
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
      'touchAlways': false,
    });
  }

  Future<void> bulkAddSongsToPlaylist(
      String playlistId, List<String> filenames) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('playlist_op', {
      'op': 'add_songs',
      'hlc': _hlcNow(),
      'playlistId': playlistId,
      'filenames': filenames,
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
      'touchAlways': true,
    });
  }

  Future<void> bulkRemoveSongsFromPlaylist(
      String playlistId, List<String> filenames) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('playlist_op', {
      'op': 'remove_songs',
      'hlc': _hlcNow(),
      'playlistId': playlistId,
      'filenames': filenames,
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  Future<void> removeSongFromPlaylist(
      String playlistId, String songFilename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('playlist_op', {
      'op': 'remove_songs',
      'hlc': _hlcNow(),
      'playlistId': playlistId,
      'filenames': [songFilename],
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  Future<void> updatePlaylistName(String playlistId, String newName) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('playlist_op', {
      'op': 'rename',
      'hlc': _hlcNow(),
      'playlistId': playlistId,
      'name': newName,
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  Future<void> renameFile(String oldFilename, String newFilename) =>
      renameFiles([(from: oldFilename, to: newFilename)]);

  Future<void> renameFiles(List<({String from, String to})> renames) async {
    await _ensureInitialized();
    final data = _userDataDatabase;
    final stats = _statsDatabase;
    if (data == null || stats == null || renames.isEmpty) return;

    final fields = <String, Object?>{
      'renames': [
        for (final entry in renames) {'from': entry.from, 'to': entry.to}
      ],
      'hlc': _hlcNow(),
      'now': DateTime.now().millisecondsSinceEpoch / 1000,
    };
    try {
      await data.renameLibraryFiles(stats, fields);
    } finally {
      SongIdentityRepository.generation++;
    }
  }

  /// Preserves play history when a library file is deleted.
  Future<void> deleteFile(String filename) async {
    await _ensureInitialized();
    final data = _userDataDatabase;
    if (data == null) return;
    await data
        .coreCommand('song_files', {'op': 'delete', 'filename': filename});
    SongIdentityRepository.generation++;
  }

  /// Replaces all local suggestless with the given list
  Future<void> setSuggestLess(List<String> suggestLess) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userList('suggestless', 'set', filenames: suggestLess);
  }

  // ==========================================================================
  // MERGED SONGS QUERIES
  // ==========================================================================

  /// Gets all merged song groups with their filenames and priority info
  /// Returns a map of groupId -> {filenames: [...], priorityFilename: ...}
  Future<Map<String, ({List<String> filenames, String? priorityFilename})>>
      getMergedSongGroups() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return {};

    try {
      final reply =
          await _userDataDatabase!.coreCommand('merged_op', {'op': 'list'});
      final result =
          <String, ({List<String> filenames, String? priorityFilename})>{};
      for (final entry in reply['groups'] as List) {
        final row = (entry as Map).cast<String, Object?>();
        result[row['id'] as String] = (
          filenames: [
            for (final filename in row['filenames'] as List) filename as String,
          ],
          priorityFilename: row['priority_filename'] as String?,
        );
      }
      return result;
    } catch (e) {
      debugPrint('Error fetching merged song groups: $e');
      return {};
    }
  }

  /// Gets the priority filename for a merge group
  Future<String?> getMergedGroupPriority(String groupId) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return null;

    try {
      final reply = await _userDataDatabase!
          .coreCommand('merged_op', {'op': 'priority', 'groupId': groupId});
      return reply['priority_filename'] as String?;
    } catch (e) {
      debugPrint('Error fetching merged group priority: $e');
      return null;
    }
  }

  /// Sets the priority filename for a merge group
  Future<void> setMergedGroupPriority(
      String groupId, String? priorityFilename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    try {
      await _userDataDatabase!.coreCommand('merged_op', {
        'op': 'set_priority',
        'groupId': groupId,
        'priorityFilename': priorityFilename,
      });
      debugPrint('Set priority for group $groupId to $priorityFilename');
    } catch (e) {
      debugPrint('Error setting merged group priority: $e');
    }
  }

  /// Gets the group ID for a specific filename if it's part of a merge group
  Future<String?> getMergedGroupId(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return null;

    try {
      final reply = await _userDataDatabase!
          .coreCommand('merged_op', {'op': 'group_id', 'filename': filename});
      return reply['group_id'] as String?;
    } catch (e) {
      debugPrint('Error fetching merged group id: $e');
      return null;
    }
  }

  /// Gets all filenames in the same merge group as the given filename
  Future<List<String>> getMergedSiblings(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];

    try {
      final reply = await _userDataDatabase!
          .coreCommand('merged_op', {'op': 'siblings', 'filename': filename});
      return [for (final name in reply['filenames'] as List) name as String];
    } catch (e) {
      debugPrint('Error fetching merged siblings: $e');
      return [];
    }
  }

  /// Creates a new merge group with the given filenames
  /// [priorityFilename] is the song that should be prioritized during shuffle
  Future<String> createMergedGroup(List<String> filenames,
      {String? priorityFilename}) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) {
      throw Exception('Database not initialized');
    }

    if (filenames.length < 2) {
      throw Exception('Need at least 2 songs to merge');
    }

    // Validate priority filename is in the list
    final effectivePriority =
        priorityFilename != null && filenames.contains(priorityFilename)
            ? priorityFilename
            : null;

    final groupId = const Uuid().v4();
    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    await _userDataDatabase!.coreCommand('merged_op', {
      'op': 'create',
      'groupId': groupId,
      'filenames': filenames,
      'priorityFilename': effectivePriority,
      'now': now,
      'hlc': _hlcNow(),
    });

    debugPrint(
        'Created merged group $groupId with ${filenames.length} songs, priority: $effectivePriority');
    return groupId;
  }

  /// Adds songs to an existing merge group
  Future<void> addSongsToMergedGroup(
      String groupId, List<String> filenames) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    await _userDataDatabase!.coreCommand('merged_op', {
      'op': 'add_songs',
      'groupId': groupId,
      'filenames': filenames,
      'now': now,
      'hlc': _hlcNow(),
    });

    debugPrint('Added ${filenames.length} songs to merged group $groupId');
  }

  /// Removes a song from its merge group
  Future<void> removeSongFromMergedGroup(String filename) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('merged_op', {
      'op': 'remove_song',
      'filename': filename,
      'hlc': _hlcNow(),
    });

    debugPrint('Removed $filename from merged group');
  }

  /// Deletes an entire merge group
  Future<void> deleteMergedGroup(String groupId) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('merged_op', {
      'op': 'delete',
      'groupId': groupId,
      'hlc': _hlcNow(),
    });

    debugPrint('Deleted merged group $groupId');
  }

  // ==========================================================================
  // RECOMMENDATION PREFERENCE QUERIES
  // ==========================================================================

  Future<Map<String, ({String? customTitle, bool isPinned})>>
      getRecommendationPreferences() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return {};

    try {
      final reply = await _userDataDatabase!
          .coreCommand('recommendation_op', {'op': 'preferences'});
      final prefs = <String, ({String? customTitle, bool isPinned})>{};
      for (final entry in reply['preferences'] as List) {
        final row = (entry as Map).cast<String, Object?>();
        prefs[row['id'] as String] = (
          customTitle: row['custom_title'] as String?,
          isPinned: (row['is_pinned'] as int) == 1,
        );
      }
      return prefs;
    } catch (e) {
      debugPrint('Error getting recommendation preferences: $e');
      return {};
    }
  }

  Future<void> saveRecommendationPreference(String id,
      {String? customTitle, bool? isPinned}) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('recommendation_op', {
      'op': 'save_preference',
      'recommendationId': id,
      'customTitle': customTitle,
      'isPinned': isPinned,
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  Future<List<String>> getRemovedRecommendations() async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return [];

    try {
      final reply = await _userDataDatabase!
          .coreCommand('recommendation_op', {'op': 'removals'});
      return [for (final id in reply['ids'] as List) id as String];
    } catch (e) {
      debugPrint('Error getting removed recommendations: $e');
      return [];
    }
  }

  Future<void> addRecommendationRemoval(String id) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand('recommendation_op', {
      'op': 'add_removal',
      'recommendationId': id,
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  Future<void> removeRecommendationRemoval(String id) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    await _userDataDatabase!.coreCommand(
        'recommendation_op', {'op': 'remove_removal', 'recommendationId': id});
  }

  /// Replaces all merged groups with the given data (used for import/restore)
  /// Each entry should be: groupId -> (filenames: [...], priorityFilename: ...)
  Future<void> setMergedGroups(
      Map<String, ({List<String> filenames, String? priorityFilename})>
          groups) async {
    await _ensureInitialized();
    if (_userDataDatabase == null) return;

    final now = DateTime.now().millisecondsSinceEpoch / 1000.0;

    await _userDataDatabase!.coreCommand('merged_op', {
      'op': 'set_all',
      'hlc': _hlcNow(),
      'now': now,
      'groups': [
        for (final entry in groups.entries)
          if (entry.value.filenames.length >= 2)
            {
              'id': entry.key,
              'priority_filename': entry.value.priorityFilename,
              'filenames': entry.value.filenames,
            },
      ],
    });

    debugPrint('Set ${groups.length} merged groups');
  }

  // ==========================================================================
  // PLAYBACK QUERIES
  // ==========================================================================

  Future<Map<String, int>> getPlayCounts() async {
    await _ensureInitialized();
    if (_statsDatabase == null) return {};
    try {
      final results = await playbackRows(_statsDatabase!, 'counts');
      return {
        for (var r in results) r['song_filename'] as String: r['count'] as int
      };
    } catch (e) {
      debugPrint('Error fetching play counts: $e');
      return {};
    }
  }

  /// Every listen recorded in [queueId], earliest first, one entry per listen.
  ///
  /// Play events carry the queue id, so this is the only record of what a queue
  /// actually played. An index into the live queue cannot answer it: a restored
  /// or reordered queue would count tracks the user skipped past as played.
  ///
  /// One entry per event rather than per track: a song heard at scattered
  /// points in the queue was heard that many times, and collapsing the rows
  /// made the queue's played list disagree with what the listener did.
  Future<List<({String filename, double timestamp})>> getQueueListens(
      String queueId) async {
    await _ensureInitialized();
    final stats = _statsDatabase;
    if (stats == null || queueId.isEmpty) return const [];
    try {
      final rows = await playbackRows(stats, 'queue_listens', [queueId]);
      return [
        for (final row in rows)
          if (row['song_filename'] is String && row['timestamp'] is num)
            (
              filename: row['song_filename'] as String,
              timestamp: (row['timestamp'] as num).toDouble(),
            ),
      ];
    } catch (e) {
      debugPrint('Error reading played songs for a queue: $e');
      return const [];
    }
  }

  Future<Map<String, double>> getLastPlayedTimestamps() async {
    await _ensureInitialized();
    if (_statsDatabase == null) return {};
    try {
      final results = await playbackRows(_statsDatabase!, 'last_played');
      return {
        for (var r in results)
          r['song_filename'] as String: r['last_played'] as double,
      };
    } catch (e) {
      debugPrint('Error fetching last played timestamps: $e');
      return {};
    }
  }

  /// Raw play events for affinity scoring, newest first.
  ///
  /// Unlike [getPlayHistory] this is not capped at a small recent window — the
  /// affinity model needs the whole decay horizon to tell a song someone still
  /// loves from one they burned out on a year ago. Events older than
  /// [sinceDays] contribute so little after decay that fetching them is waste.
  Future<List<({String filename, double timestamp, double playRatio})>>
      getAffinityEvents({int sinceDays = 365}) async {
    await _ensureInitialized();
    if (_statsDatabase == null) return [];
    try {
      final cutoff = DateTime.now()
              .subtract(Duration(days: sinceDays))
              .millisecondsSinceEpoch /
          1000.0;
      final results = await playbackRows(_statsDatabase!, 'affinity', [cutoff]);

      final events =
          <({String filename, double timestamp, double playRatio})>[];
      for (final r in results) {
        final filename = r['song_filename'] as String?;
        final timestamp = (r['timestamp'] as num?)?.toDouble();
        if (filename == null || timestamp == null) continue;

        // Same fallback as getPlayHistory: older rows can predate play_ratio.
        final duration = (r['duration_played'] as num?)?.toDouble() ?? 0.0;
        final totalLength = (r['total_length'] as num?)?.toDouble() ?? 0.0;
        final playRatio = (r['play_ratio'] as num?)?.toDouble() ??
            (totalLength > 0 ? duration / totalLength : 0.0);

        events.add((
          filename: filename,
          timestamp: timestamp,
          playRatio: playRatio,
        ));
      }
      return events;
    } catch (e) {
      debugPrint('Error fetching affinity events: $e');
      return [];
    }
  }

  /// Full event stream for the smart taste model, grouped by session so burst
  /// and co-play detection can walk it in one pass. Timestamps are epoch seconds.
  Future<
      List<
          ({
            String filename,
            double timestamp,
            double ratio,
            double secondsPlayed,
            String? sessionId,
            String? source,
          })>> getTasteEvents({int sinceDays = 365}) async {
    await _ensureInitialized();
    if (_statsDatabase == null) return [];
    try {
      final cutoff = DateTime.now()
              .subtract(Duration(days: sinceDays))
              .millisecondsSinceEpoch /
          1000.0;
      final results = await playbackRows(_statsDatabase!, 'taste', [cutoff]);

      final events = <({
        String filename,
        double timestamp,
        double ratio,
        double secondsPlayed,
        String? sessionId,
        String? source,
      })>[];
      for (final r in results) {
        final filename = r['song_filename'] as String?;
        final timestamp = (r['timestamp'] as num?)?.toDouble();
        if (filename == null || timestamp == null) continue;

        final duration = (r['duration_played'] as num?)?.toDouble() ?? 0.0;
        final totalLength = (r['total_length'] as num?)?.toDouble() ?? 0.0;
        final ratio = (r['play_ratio'] as num?)?.toDouble() ??
            (totalLength > 0 ? duration / totalLength : 0.0);

        events.add((
          filename: filename,
          timestamp: timestamp,
          ratio: ratio,
          secondsPlayed: duration,
          sessionId: r['session_id'] as String?,
          source: r['source'] as String?,
        ));
      }
      return events;
    } catch (e) {
      debugPrint('Error fetching taste events: $e');
      return [];
    }
  }

  Future<Map<String, ({int count, double avgRatio})>> getSkipStats() async {
    await _ensureInitialized();
    if (_statsDatabase == null) return {};
    try {
      // Get count of "immediate skips" and average play ratio for all songs
      final results = await playbackRows(_statsDatabase!, 'skips');
      return {
        for (var r in results)
          r['song_filename'] as String: (
            count: r['skip_count'] as int,
            avgRatio: (r['avg_ratio'] as num).toDouble()
          )
      };
    } catch (e) {
      debugPrint('Error fetching skip stats: $e');
      return {};
    }
  }

  Future<void> insertPlayEvent(Map<String, dynamic> event,
          {bool isSync = false}) =>
      insertPlayEventsBatch([event], isSync: isSync);

  Future<void> insertPlayEventsBatch(List<Map<String, dynamic>> events,
      {bool isSync = false}) async {
    await _ensureInitialized();
    final db = _statsDatabase;
    if (db == null || events.isEmpty) return;
    await db.coreCommand('playback', {
      'op': 'write',
      'events': events,
      'sync': isSync,
      'hlc': _hlcNow(),
    });
  }

  Future<
      List<
          ({
            String filename,
            double timestamp,
            double playRatio,
            String eventType
          })>> getPlayHistory({
    int limit = 200,
  }) async {
    await _ensureInitialized();

    if (_statsDatabase == null) {
      return [];
    }

    try {
      // Get all recent play events with their actual play ratios
      // This allows weighting logic to differentiate between barely-listened and fully-listened songs
      final events = await playbackRows(_statsDatabase!, 'history', [limit]);

      final history = <({
        String filename,
        double timestamp,
        double playRatio,
        String eventType
      })>[];

      for (final e in events) {
        final filename = e['song_filename'] as String?;
        final timestamp = (e['timestamp'] as num?)?.toDouble();
        if (filename == null || timestamp == null) continue;

        final duration = (e['duration_played'] as num?)?.toDouble() ?? 0.0;
        final totalLength = (e['total_length'] as num?)?.toDouble() ?? 0.0;
        final playRatio = (e['play_ratio'] as num?)?.toDouble() ??
            (totalLength > 0 ? duration / totalLength : 0.0);

        history.add((
          filename: filename,
          timestamp: timestamp,
          playRatio: playRatio,
          eventType: playRatio < _skipRatioThreshold ? 'skip' : 'listen',
        ));
      }

      return history;
    } catch (e) {
      debugPrint('Error getting play history: $e');
      return [];
    }
  }

  /// Repairs corrupted playevent rows where duration_played was inflated beyond
  /// actual song lengths (e.g. from repeated sync compounding).
  Future<int> repairCorruptedPlayStats() async {
    await _ensureInitialized();
    if (_statsDatabase == null) return 0;

    try {
      final songs = await getAllSongs();
      final reply = await _statsDatabase!.coreCommand('playback', {
        'op': 'repair',
        'durations': {
          for (final song in songs)
            if (song.duration != null && song.duration!.inMilliseconds > 0)
              song.filename: song.duration!.inMilliseconds / 1000,
        },
      });
      return (reply['count'] as num).toInt();
    } catch (e) {
      debugPrint('Error repairing corrupted play stats: $e');
      return 0;
    }
  }

  /// The lifetime stats payload backups carry, in the shape older builds wrote.
  ///
  /// The aggregation itself lives in the domain layer (`buildInsights`), shared
  /// with the stats screen; this only moves rows in and shapes the result out.
  Future<Map<String, dynamic>> getFunStats() async {
    await _ensureInitialized();

    if (_statsDatabase == null) {
      return {"stats": []};
    }

    try {
      await repairCorruptedPlayStats();
      final rows = await playbackRows(_statsDatabase!, 'samples');
      if (rows.isEmpty) return {"stats": []};

      final songs = await getAllSongs();
      final insights = buildInsights(
        events: rows.map(PlayEventSample.fromRow).toList(growable: false),
        library: {for (final song in songs) song.filename: song},
        favorites: (await getFavorites()).toSet(),
        range: StatsRange.allTime,
        now: DateTime.now(),
      );

      return buildFunStatsPayload(insights, librarySize: songs.length);
    } on DatabaseException catch (e) {
      debugPrint("Error calculating local fun stats: $e");
      return {"stats": []};
    }
  }

  Future<void> importWithOptions({
    required String? statsDbPath,
    required String? dataDbPath,
    required ImportOptions options,
  }) async {
    await _ensureInitialized();
    if (!options.hasDatabaseCategories) return;

    final fields = <String, Object?>{
      'additive': options.additive,
      'hlc': _hlcNow(),
      'now': DateTime.now().millisecondsSinceEpoch / 1000,
    };
    if (statsDbPath != null &&
        options.categories.contains(ImportDataCategory.playHistory)) {
      await _statsDatabase!.coreCommand('restore', {
        ...fields,
        'kind': 'stats',
        'path': statsDbPath,
      });
    }
    if (dataDbPath == null) return;
    await _userDataDatabase!.coreCommand('restore', {
      ...fields,
      'kind': 'userdata',
      'path': dataDbPath,
      'categories': [for (final category in options.categories) category.name],
    });
    SongIdentityRepository.generation++;
  }

  // --- Artist & Album Art Cache Methods ---

  Future<Map<String, String>> getArtistArtMap() async {
    await _ensureInitialized();
    final reply = await _art('artist', 'list');
    return {
      for (final row in reply['items'] as List? ?? const [])
        (row as Map)['key'] as String: row['path'] as String,
    };
  }

  Future<void> saveArtistArt({
    required String artistName,
    required String localPath,
    String? imageUrl,
    String? source,
  }) async {
    await _ensureInitialized();
    await _art('artist', 'save', fields: {
      'name': artistName,
      'local_path': localPath,
      'image_url': imageUrl,
      'source': source,
      'hlc': _hlcNow(),
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  Future<void> deleteArtistArt(String artistName) async {
    await _ensureInitialized();
    await _art('artist', 'delete', fields: {
      'name': artistName,
      'hlc': _hlcNow(),
    });
  }

  Future<void> clearArtistArt() async {
    await _ensureInitialized();
    await _art('artist', 'clear');
  }

  Future<Map<String, String>> getAlbumArtMap() async {
    await _ensureInitialized();
    final reply = await _art('album', 'list');
    return {
      for (final row in reply['items'] as List? ?? const [])
        (row as Map)['key'] as String: row['path'] as String,
    };
  }

  Future<void> saveAlbumArt({
    required String albumKey,
    required String albumName,
    String? artistName,
    required String localPath,
    String? imageUrl,
    String? source,
  }) async {
    await _ensureInitialized();
    await _art('album', 'save', fields: {
      'key': albumKey,
      'album_name': albumName,
      'artist_name': artistName,
      'local_path': localPath,
      'image_url': imageUrl,
      'source': source,
      'hlc': _hlcNow(),
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  Future<void> deleteAlbumArt(String albumKey) async {
    await _ensureInitialized();
    await _art('album', 'delete', fields: {
      'key': albumKey,
      'hlc': _hlcNow(),
    });
  }

  Future<void> clearAlbumArt() async {
    await _ensureInitialized();
    await _art('album', 'clear');
  }

  // ==========================================================================
  // SYNC DATA EXPORT METHODS
  // ==========================================================================

  Future<Map<String, int>> getPlayStatsDeviceBreakdown(
      String currentDeviceId) async {
    await _ensureInitialized();
    if (_statsDatabase == null) {
      return {'localPlayCount': 0, 'remotePlayCount': 0, 'totalPlayCount': 0};
    }
    final reply = await _statsDatabase!.coreCommand('playback', {
      'op': 'device_counts',
      'device': currentDeviceId,
    });
    return reply.cast<String, int>();
  }

  Future<void> clearAllPlayStats() async {
    await _ensureInitialized();
    await _statsDatabase?.coreCommand('playback', {'op': 'clear'});
  }

  Future<String?> getTranslatedLyrics(
    String filename,
    String targetLang, {
    String? sourceContent,
  }) async {
    await _ensureInitialized();
    final reply = await _userDataDatabase!.coreCommand('translated_lyrics_op', {
      'op': 'get',
      'filename': filename,
      'targetLang': targetLang,
      'sourceContent': sourceContent,
    });
    return reply['content'] as String?;
  }

  Future<void> saveTranslatedLyrics(
    String filename,
    String targetLang,
    String content, {
    String? sourceContent,
  }) async {
    await _ensureInitialized();
    await _userDataDatabase!.coreCommand('translated_lyrics_op', {
      'op': 'save',
      'filename': filename,
      'targetLang': targetLang,
      'content': content,
      'sourceContent': sourceContent,
      'now': DateTime.now().millisecondsSinceEpoch / 1000.0,
    });
  }

  Future<void> deleteTranslatedLyrics(String filename,
      [String? targetLang]) async {
    await _ensureInitialized();
    await _userDataDatabase!.coreCommand('translated_lyrics_op', {
      'op': 'delete',
      'filename': filename,
      'targetLang': targetLang,
    });
  }

  Future<void> close() async {
    await _statsDatabase?.close();
    await _userDataDatabase?.close();
    _statsDatabase = null;
    _userDataDatabase = null;
    _initFuture = null;
  }
}
