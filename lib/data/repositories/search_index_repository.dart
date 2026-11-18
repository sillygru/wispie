import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../../models/song.dart';
import '../../domain/services/native_accel.dart';
import '../../services/wispie_cache.dart';
import '../../services/ffmpeg_service.dart';
import '../../services/lyrics_files_service.dart';
import '../../services/wispie_paths.dart';
import '../models/search_index_entry.dart';

/// Repository for managing the search index database
///
/// The search index is stored in a separate SQLite database file that is
/// explicitly excluded from backups. This allows for fast full-text search
/// across song metadata and lyrics. SQLite access lives here; the predicates,
/// lyric text extraction and every refresh decision come from the native core.
class SearchIndexRepository {
  static const String _tableName = 'search_index';
  static const String _metadataTable = 'search_metadata';

  static Database? _database;
  final FFmpegService _ffmpegService = FFmpegService();

  @visibleForTesting
  static String? testDocumentsPath;

  /// Gets the database file path
  Future<String> _getDbPath() async {
    if (testDocumentsPath != null) {
      return join(testDocumentsPath!, 'wispie_search_index.db');
    }
    final wispieDir = await getWispieDirectory();
    return join(wispieDir.path, 'wispie_search_index.db');
  }

  @visibleForTesting
  static void resetDatabase() {
    _database?.close();
    _database = null;
  }

  /// Initializes the search index database
  Future<void> init() async {
    if (_database != null && _database!.isOpen) return;
    _database = null;

    final dbPath = await _getDbPath();

    _database = await openDatabase(
      dbPath,
      version: 1,
      onCreate: (db, version) async {
        await _createTables(db);
      },
    );
  }

  /// Creates the necessary tables for the search index
  Future<void> _createTables(Database db) async {
    // Main search index table
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_tableName (
        filename TEXT PRIMARY KEY,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        lyrics_content TEXT,
        title_length INTEGER NOT NULL DEFAULT 0,
        artist_length INTEGER NOT NULL DEFAULT 0,
        album_length INTEGER NOT NULL DEFAULT 0,
        lyrics_length INTEGER DEFAULT 0,
        last_modified INTEGER NOT NULL
      )
    ''');

    // Metadata table for tracking index stats
    await db.execute('''
      CREATE TABLE IF NOT EXISTS $_metadataTable (
        key TEXT PRIMARY KEY,
        value TEXT
      )
    ''');

    // Create indexes for fast searching
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_title ON $_tableName(title)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_artist ON $_tableName(artist)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_album ON $_tableName(album)
    ''');
    await db.execute('''
      CREATE INDEX IF NOT EXISTS idx_lyrics ON $_tableName(lyrics_content)
    ''');
  }

  /// Rebuilds the entire search index from a list of songs incrementally
  Future<void> rebuildIndex(
    List<Song> songs, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await init();
    if (_database == null || !_database!.isOpen) return;

    final List<Map<String, dynamic>> existingEntries = await _database!.query(
      _tableName,
      columns: [
        'filename',
        'title',
        'artist',
        'album',
        'last_modified',
        'lyrics_content'
      ],
    );

    // One native pass over the sidecar files, rather than one probe per song.
    final sidecarLyrics = <String, String>{};
    final sidecars = await LyricsFilesService.instance.textsFor(songs);
    for (final entry in sidecars.entries) {
      final text = entry.value.text;
      if (text == null) continue;
      final plain = NativeAccel.plainLyricsText(text).toLowerCase().trim();
      if (plain.isNotEmpty) sidecarLyrics[entry.key] = plain;
    }

    final remoteLyrics = <String, String>{};
    for (final song in songs) {
      if (song.isLocal) continue;
      final lyrics = await _cachedRemoteLyrics(song);
      if (lyrics != null) remoteLyrics[song.filename] = lyrics;
    }

    final plan = NativeAccel.searchIndexPlan(
      songs: [for (final song in songs) _songRow(song)],
      existing: existingEntries,
      sidecar: sidecarLyrics,
      remote: remoteLyrics,
    );
    final decisions = plan['decisions'] as List;
    final toRemove = [
      for (final name in plan['remove'] as List) name as String
    ];

    await _database!.transaction((txn) async {
      // Remove songs no longer in the library
      for (var i = 0; i < toRemove.length; i += 999) {
        final chunk = toRemove.sublist(i, (i + 999).clamp(0, toRemove.length));
        await txn.delete(
          _tableName,
          where: 'filename IN (${chunk.map((_) => '?').join(',')})',
          whereArgs: chunk,
        );
      }

      final batch = txn.batch();
      int updateCount = 0;

      var done = 0;
      for (var index = 0; index < songs.length; index++) {
        if (isCancelled?.call() ?? false) break;
        onProgress?.call(++done, songs.length);
        final song = songs[index];
        final decision = decisions[index] as Map<String, dynamic>;
        if (decision['skip'] as bool) continue;

        updateCount++;
        final lyricsContent = await _lyricsFor(song, decision);

        batch.insert(
          _tableName,
          NativeAccel.searchIndexRow(
            song: song.toJson(),
            lyrics: lyricsContent,
          ),
          conflictAlgorithm: ConflictAlgorithm.replace,
        );
      }

      if (updateCount > 0) {
        await batch.commit(noResult: true);
      }

      await txn.insert(
        _metadataTable,
        {
          'key': 'last_updated',
          'value': DateTime.now().millisecondsSinceEpoch.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
      await txn.insert(
        _metadataTable,
        {
          'key': 'total_entries',
          'value': songs.length.toString(),
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    });
  }

  /// The lyrics a decision already resolved, or an extraction when it did not.
  Future<String?> _lyricsFor(
    Song song,
    Map<String, dynamic> decision,
  ) async {
    final known = decision['lyrics'] as String?;
    if (known != null) return known;
    if (decision['source'] != 'extract') return null;

    try {
      final lyrics = await _ffmpegService.getLyrics(song.url);
      if (lyrics == null || lyrics.isEmpty) return null;
      return NativeAccel.plainLyricsText(lyrics).toLowerCase();
    } catch (e) {
      debugPrint('Error reading lyrics for ${song.filename}: $e');
      return null;
    }
  }

  Future<Set<String>> indexedFilenames() async {
    await init();
    if (_database == null || !_database!.isOpen) return {};
    final rows = await _database!.query(_tableName, columns: ['filename']);
    return {for (final r in rows) r['filename'] as String};
  }

  /// Updates or inserts a single song into the index
  Future<void> upsertSong(Song song) async {
    await init();
    if (_database == null || !_database!.isOpen) return;

    if (!song.isLocal) {
      await _upsertRow(song, await _cachedRemoteLyrics(song));
      return;
    }

    final sidecar = await LyricsFilesService.instance.textFor(song);
    final existing = await _database!.query(
      _tableName,
      columns: ['title', 'artist', 'album', 'last_modified', 'lyrics_content'],
      where: 'filename = ?',
      whereArgs: [song.filename],
      limit: 1,
    );

    final decision = NativeAccel.searchIndexRefresh(
      song: _songRow(song),
      existing: existing.isEmpty ? null : existing.first,
      sidecar: sidecar,
    );
    final source = decision['source'] as String;
    String? lyrics;
    if (source == 'sidecar' && sidecar != null) {
      final plain = NativeAccel.plainLyricsText(sidecar).toLowerCase().trim();
      lyrics = plain.isEmpty ? null : plain;
    } else if (source == 'existing') {
      lyrics = existing.first['lyrics_content'] as String?;
    } else if (source == 'extract') {
      lyrics = await _lyricsFor(song, decision);
    }

    await _upsertRow(song, lyrics);
  }

  /// Writes one index row, replacing any previous one for the same filename.
  Future<void> _upsertRow(Song song, String? lyricsContent) async {
    final database = _database;
    if (database == null || !database.isOpen) return;
    await database.insert(
      _tableName,
      NativeAccel.searchIndexRow(song: song.toJson(), lyrics: lyricsContent),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Writes the streamed half of the index in one transaction.
  Future<void> upsertRemoteSongs(Iterable<Song> songs) async {
    await init();
    final database = _database;
    if (database == null || !database.isOpen) return;

    final rows = <Map<String, Object?>>[];
    for (final song in songs) {
      if (song.isLocal) continue;
      rows.add(NativeAccel.searchIndexRow(
        song: song.toJson(),
        lyrics: await _cachedRemoteLyrics(song),
      ));
    }
    if (rows.isEmpty) return;

    final batch = database.batch();
    for (final row in rows) {
      batch.insert(_tableName, row,
          conflictAlgorithm: ConflictAlgorithm.replace);
    }
    await batch.commit(noResult: true);
  }

  /// The native refresh decision's input for one song.
  Map<String, Object?> _songRow(Song song) => {
        'filename': song.filename,
        'title': song.title,
        'artist': song.artist,
        'album': song.album,
        if (song.mtime != null) 'mtime': song.mtime,
        'hasLyrics': song.hasLyrics,
        'isLocal': song.isLocal,
      };

  /// Lyrics already chosen for a streamed track, as searchable text.
  ///
  /// This is what lets a YouTube track saved to the library turn up in a lyric
  /// search: there is no tag in a stream to read, so the player's own `.lrc`
  /// cache is the only copy that exists.
  Future<String?> _cachedRemoteLyrics(Song song) async {
    try {
      final file = await WispieCache.instance.remoteLyricsFile(song.filename);
      if (!await file.exists()) return null;
      final text = (await file.readAsString()).trim();
      if (text.isEmpty) return null;
      final plain = NativeAccel.plainLyricsText(text).toLowerCase().trim();
      return plain.isEmpty ? null : plain;
    } on Object catch (error) {
      debugPrint(
          'Search index: could not read cached lyrics for ${song.filename}: '
          '$error');
      return null;
    }
  }

  /// Removes a song from the index
  Future<void> removeSong(String filename) async {
    await init();
    if (_database == null || !_database!.isOpen) return;

    await _database!.delete(
      _tableName,
      where: 'filename = ?',
      whereArgs: [filename],
    );
  }

  /// Points index rows at new filenames without re-deriving anything.
  ///
  /// A rename changes the key and nothing else — not the title, artist, album,
  /// nor the lyrics we already extracted and stored. A target that already has
  /// its own row is dropped in favour of the incoming one.
  Future<void> renameFiles(List<({String from, String to})> renames) async {
    await init();
    if (_database == null || !_database!.isOpen || renames.isEmpty) return;

    await _database!.transaction((txn) async {
      for (final entry in renames) {
        if (entry.from == entry.to) continue;
        final taken = await txn.query(
          _tableName,
          columns: ['filename'],
          where: 'filename = ?',
          whereArgs: [entry.to],
          limit: 1,
        );
        if (taken.isNotEmpty) {
          await txn
              .delete(_tableName, where: 'filename = ?', whereArgs: [entry.to]);
        }
        await txn.update(
          _tableName,
          {'filename': entry.to},
          where: 'filename = ?',
          whereArgs: [entry.from],
        );
      }
    });
  }

  /// Searches for songs matching the query in specified fields
  Future<List<SearchMatch>> search({
    required String query,
    required bool searchTitles,
    required bool searchArtists,
    required bool searchAlbums,
    required bool searchLyrics,
  }) async {
    await init();
    if (_database == null || !_database!.isOpen || query.isEmpty) {
      return [];
    }

    final lowerQuery = query.toLowerCase();
    final titles = <Map<String, Object?>>[];
    final artists = <Map<String, Object?>>[];
    final albums = <Map<String, Object?>>[];
    final lyrics = <Map<String, Object?>>[];

    Future<bool> collect(
      String column,
      List<Map<String, Object?>> into,
    ) async {
      final criteria = NativeAccel.searchIndexCriteria(
        query: lowerQuery,
        column: column,
        whole: column == 'lyrics_content',
      );
      final rows = await _database!.query(
        _tableName,
        columns: ['filename', column],
        where: criteria['where'] as String,
        whereArgs: (criteria['args'] as List).cast<String>(),
      );
      for (final row in rows) {
        into.add({
          'filename': row['filename'],
          'text': row[column],
        });
      }
      return rows.isNotEmpty;
    }

    if (searchTitles) await collect('title', titles);
    if (searchArtists) await collect('artist', artists);
    if (searchAlbums) await collect('album', albums);
    if (searchLyrics) await collect('lyrics_content', lyrics);

    final reply = NativeAccel.searchIndexMatches(
      query: lowerQuery,
      titles: titles,
      artists: artists,
      albums: albums,
      lyrics: lyrics,
    );

    return [
      for (final match in reply['matches'] as List)
        SearchMatch(
          filename: (match as Map<String, dynamic>)['filename'] as String,
          matchType: _matchType(match['field'] as String),
          matchedText: match['matchedText'] as String,
          fullLine: match['fullLine'] as String?,
        ),
    ];
  }

  static SearchMatchType _matchType(String field) => switch (field) {
        'artist' => SearchMatchType.artist,
        'album' => SearchMatchType.album,
        'lyrics' => SearchMatchType.lyrics,
        _ => SearchMatchType.title,
      };

  /// Gets statistics about the search index
  Future<SearchIndexStats> getStats() async {
    await init();
    if (_database == null || !_database!.isOpen) {
      return SearchIndexStats.empty();
    }

    final countResult =
        await _database!.rawQuery('SELECT COUNT(*) as count FROM $_tableName');
    final totalEntries = Sqflite.firstIntValue(countResult) ?? 0;

    final lyricsCountResult = await _database!.rawQuery(
        'SELECT COUNT(*) as count FROM $_tableName WHERE lyrics_content IS NOT NULL');
    final entriesWithLyrics = Sqflite.firstIntValue(lyricsCountResult) ?? 0;

    final lyricsLengthResult = await _database!
        .rawQuery('SELECT SUM(lyrics_length) as total FROM $_tableName');
    final totalLyricsChars =
        (lyricsLengthResult.first['total'] as num?)?.toInt() ?? 0;

    final metadataResult = await _database!.query(
      _metadataTable,
      where: 'key = ?',
      whereArgs: ['last_updated'],
    );
    DateTime? lastUpdated;
    if (metadataResult.isNotEmpty) {
      final timestamp = int.tryParse(metadataResult.first['value'] as String);
      if (timestamp != null) {
        lastUpdated = DateTime.fromMillisecondsSinceEpoch(timestamp);
      }
    }

    return SearchIndexStats(
      totalEntries: totalEntries,
      entriesWithLyrics: entriesWithLyrics,
      totalLyricsChars: totalLyricsChars,
      lastUpdated: lastUpdated,
    );
  }

  /// Clears the entire search index
  Future<void> clear() async {
    await init();
    if (_database == null || !_database!.isOpen) return;

    await _database!.transaction((txn) async {
      await txn.delete(_tableName);
      await txn.delete(_metadataTable);
    });
  }

  /// Closes the database connection
  Future<void> close() async {
    if (_database != null) {
      if (_database!.isOpen) {
        await _database!.close();
      }
      _database = null;
    }
  }

  /// Gets the database file path (for backup exclusion)
  Future<String?> getDatabaseFilePath() async {
    final path = await _getDbPath();
    final file = File(path);
    if (await file.exists()) {
      return path;
    }
    return null;
  }

  /// Deletes the search index database file
  Future<void> deleteDatabaseFile() async {
    final path = await _getDbPath();
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}

/// Represents a search match result
class SearchMatch {
  final String filename;
  final SearchMatchType matchType;
  final String matchedText;
  final String? fullLine;

  const SearchMatch({
    required this.filename,
    required this.matchType,
    required this.matchedText,
    this.fullLine,
  });
}

/// Type of search match
enum SearchMatchType {
  title,
  artist,
  album,
  lyrics,
}
