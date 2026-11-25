import 'package:flutter/foundation.dart';
import '../rust/native_database.dart';
import 'package:path/path.dart';
import '../../models/song.dart';
import '../../domain/services/native_accel.dart';
import '../../services/wispie_cache.dart';
import '../../services/ffmpeg_service.dart';
import '../../services/lyrics_files_service.dart';
import '../../services/wispie_paths.dart';
import '../models/search_index_entry.dart';
import 'song_repository.dart';

/// Repository for managing the search index database
///
/// The native core stores and searches song metadata and lyrics in a
/// separate cache database.
class SearchIndexRepository {
  final _songs = SongRepository();

  static Database? _database;
  final FFmpegService _ffmpegService = FFmpegService();

  @visibleForTesting
  static String? testDocumentsPath;

  /// Gets the database file path
  Future<String> databasePath() async {
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

    final dbPath = await databasePath();

    _database = await openDatabase(dbPath, schema: DatabaseSchema.searchIndex);
  }

  Future<Map<String, Object?>> _index(String op,
          [Map<String, Object?> fields = const {}]) =>
      _database!.coreCommand('search_index', {'op': op, ...fields});

  /// Rebuilds the entire search index from a list of songs incrementally
  Future<void> rebuildIndex(
    List<Song> songs, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await init();
    if (_database == null || !_database!.isOpen) return;

    final database = _database!;
    final existingEntries = ((await database.coreCommand(
      'search_index',
      {'op': 'entries'},
    ))['rows'] as List)
        .cast<Map<String, Object?>>();

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

    final rows = <Map<String, Object?>>[];
    for (var index = 0; index < songs.length; index++) {
      if (isCancelled?.call() ?? false) break;
      onProgress?.call(index + 1, songs.length);
      final song = songs[index];
      final decision = decisions[index] as Map<String, dynamic>;
      if (decision['skip'] as bool) continue;

      final choice = song.isLocal ? await _songs.getLyricsChoice(song) : null;
      final lyricsContent = choice == null
          ? await _lyricsFor(song, decision)
          : _plainLyrics(choice.text);
      rows.add(NativeAccel.searchIndexRow(
          song: song.toJson(), lyrics: lyricsContent));
    }

    final changed = {...toRemove, for (final row in rows) row['filename']};
    await database.coreCommand('search_index', {
      'op': 'write',
      'remove': toRemove,
      'rows': rows,
      'expected': {
        for (final row in existingEntries)
          if (changed.contains(row['filename'])) row['filename'] as String: row,
      },
      'updated': DateTime.now().millisecondsSinceEpoch,
      'total': songs.length,
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
    return ((await _index('filenames'))['filenames'] as List)
        .cast<String>()
        .toSet();
  }

  /// Updates or inserts a single song into the index
  Future<void> upsertSong(Song song) async {
    await init();
    if (_database == null || !_database!.isOpen) return;

    if (!song.isLocal) {
      await _upsertRow(song, await _cachedRemoteLyrics(song));
      return;
    }

    final chosen = await _songs.getLyricsChoice(song);
    if (chosen != null) {
      await _upsertRow(song, _plainLyrics(chosen.text));
      return;
    }

    final sidecar = await LyricsFilesService.instance.textFor(song);
    final existing =
        ((await _index('entry', {'filename': song.filename}))['rows'] as List)
            .cast<Map<String, Object?>>();

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
    await _index('write', {
      'rows': [
        NativeAccel.searchIndexRow(song: song.toJson(), lyrics: lyricsContent)
      ],
    });
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

    await _index('write', {'rows': rows});
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
      final chosen = await _songs.getLyricsChoice(song);
      if (chosen != null) return _plainLyrics(chosen.text);
      final file = await WispieCache.instance.remoteLyricsFile(song.filename);
      if (!await file.exists()) return null;
      final text = (await file.readAsString()).trim();
      if (text.isEmpty) return null;
      return _plainLyrics(text);
    } on Object catch (error) {
      debugPrint(
          'Search index: could not read cached lyrics for ${song.filename}: '
          '$error');
      return null;
    }
  }

  String? _plainLyrics(String text) {
    final plain = NativeAccel.plainLyricsText(text).toLowerCase().trim();
    return plain.isEmpty ? null : plain;
  }

  /// Removes a song from the index
  Future<void> removeSong(String filename) async {
    await init();
    if (_database == null || !_database!.isOpen) return;

    await _index('remove', {'filename': filename});
  }

  /// Points index rows at new filenames without re-deriving anything.
  ///
  /// A rename changes the key and nothing else — not the title, artist, album,
  /// nor the lyrics we already extracted and stored. A target that already has
  /// its own row is dropped in favour of the incoming one.
  Future<void> renameFiles(List<({String from, String to})> renames) async {
    await init();
    if (_database == null || !_database!.isOpen || renames.isEmpty) return;

    await _index('rename', {
      'renames': [
        for (final entry in renames) {'from': entry.from, 'to': entry.to}
      ],
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

    final reply = await _index('search', {
      'query': query,
      'titles': searchTitles,
      'artists': searchArtists,
      'albums': searchAlbums,
      'lyrics': searchLyrics,
    });

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

    final result = await _index('stats');
    final timestamp = result['updated'] as int?;
    return SearchIndexStats(
      totalEntries: result['total'] as int,
      entriesWithLyrics: result['with_lyrics'] as int,
      totalLyricsChars: result['lyrics_chars'] as int,
      lastUpdated: timestamp == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(timestamp),
    );
  }

  /// Clears the entire search index
  Future<void> clear() async {
    await init();
    if (_database == null || !_database!.isOpen) return;

    await _index('clear');
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

  Future<void> deleteDatabaseFile() async {
    await close();
    await databaseFileCommand('remove', await databasePath());
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
