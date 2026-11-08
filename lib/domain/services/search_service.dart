import '../../models/song.dart';
import '../models/search_filter.dart';
import '../models/search_result.dart';
import '../../data/repositories/search_index_repository.dart';
import 'search_fuzzy.dart';
import 'search_ranking.dart';
import 'search_taste.dart';

/// Service for performing searches across the music library
///
/// This service coordinates between the search index repository and
/// the song data to provide fast, filtered search results.
class SearchService {
  final SearchIndexRepository _indexRepository;
  Future<void>? _initFuture;

  /// Streamed filenames the index was last reconciled against, so a search does
  /// not re-read every remote row's lyrics on every keystroke.
  Set<String>? _syncedRemote;

  SearchService({SearchIndexRepository? indexRepository})
      : _indexRepository = indexRepository ?? SearchIndexRepository();

  /// Initializes the search service
  Future<void> init() async {
    _initFuture ??= _indexRepository.init();
    await _initFuture;
  }

  /// Performs a search with the given query and filter state
  ///
  /// Returns a list of search results that match the criteria
  Future<List<SearchResult>> search({
    required String query,
    required SearchFilterState filterState,
    required List<Song> allSongs,
    SearchTaste taste = SearchTaste.empty,
  }) async {
    await init();

    if (query.isEmpty) {
      return [];
    }

    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) {
      return [];
    }
    final tokens = lowerQuery
        .split(RegExp(r'\s+'))
        .where((token) => token.isNotEmpty)
        .toList();

    // Determine which fields to search based on filter state
    final searchTitles = filterState.all || filterState.songs;
    final searchArtists = filterState.all || filterState.artists;
    final searchAlbums = filterState.all || filterState.albums;
    final searchLyrics =
        filterState.all || filterState.songs || filterState.lyrics;

    // Get matches from the index
    final matches = await _indexRepository.search(
      query: lowerQuery,
      searchTitles: searchTitles,
      searchArtists: searchArtists,
      searchAlbums: searchAlbums,
      searchLyrics: searchLyrics,
    );

    // Create a lookup map for songs
    final songMap = {for (var song in allSongs) song.filename: song};

    // Build search results
    var results = <SearchResult>[];
    for (final match in matches) {
      final song = songMap[match.filename];
      if (song == null) continue;

      final matchedFilters = <SearchFilterType>{};

      // Determine which filters matched
      switch (match.matchType) {
        case SearchMatchType.title:
          matchedFilters.add(SearchFilterType.songs);
          break;
        case SearchMatchType.artist:
          matchedFilters.add(SearchFilterType.artists);
          break;
        case SearchMatchType.album:
          matchedFilters.add(SearchFilterType.albums);
          break;
        case SearchMatchType.lyrics:
          matchedFilters.add(SearchFilterType.lyrics);
          break;
      }

      // Create lyrics match if applicable
      LyricsMatch? lyricsMatch;
      if (match.matchType == SearchMatchType.lyrics && match.fullLine != null) {
        lyricsMatch = LyricsMatch(
          matchedText: match.matchedText,
          fullLine: match.fullLine!,
        );
      }

      results.add(SearchResult(
        song: song,
        lyricsMatch: lyricsMatch,
        matchedFilters: matchedFilters,
      ));
    }

    results = rankSearchResults(
      results: results,
      query: lowerQuery,
      taste: taste,
    );

    // Typo tolerance only tops up thin results, so a clean query never gets
    // noise mixed in and the common case pays nothing for it.
    if (results.length < _fuzzyTopUpBelow &&
        lowerQuery.length >= 4 &&
        (searchTitles || searchArtists || searchAlbums)) {
      final seen = {for (final r in results) r.song.filename};
      results.addAll(fuzzyMatches(
        tokens,
        allSongs,
        seen,
        taste: taste,
        titles: searchTitles,
        artists: searchArtists,
        albums: searchAlbums,
      ));
    }

    return results;
  }

  static const int _fuzzyTopUpBelow = 12;

  /// Groups search results by artist
  Map<String, List<SearchResult>> groupByArtist(List<SearchResult> results) {
    final groups = <String, List<SearchResult>>{};
    for (final result in results) {
      final artist = result.song.artist;
      groups.putIfAbsent(artist, () => []).add(result);
    }
    return groups;
  }

  /// Groups search results by album
  Map<String, List<SearchResult>> groupByAlbum(List<SearchResult> results) {
    final groups = <String, List<SearchResult>>{};
    for (final result in results) {
      final album = result.song.album;
      groups.putIfAbsent(album, () => []).add(result);
    }
    return groups;
  }

  /// Rebuilds the search index from a list of songs
  ///
  /// This should be called during library scanning
  Future<void> rebuildIndex(
    List<Song> songs, {
    void Function(int done, int total)? onProgress,
    bool Function()? isCancelled,
  }) async {
    await init();
    await _indexRepository.rebuildIndex(songs,
        onProgress: onProgress, isCancelled: isCancelled);
  }

  Future<Set<String>> indexedFilenames() async {
    await init();
    return _indexRepository.indexedFilenames();
  }

  /// Keeps the index in line with the streamed tracks saved to the library.
  ///
  /// Only `youtube:` rows are touched. The local library is rebuilt by the
  /// scanner, and re-indexing it here would re-extract lyrics from disk on every
  /// search. The set is compared first, so a search after a play costs one set
  /// check rather than a database round trip, and lyrics a track gained since are
  /// picked up by [updateSong] at the moment they are saved.
  Future<void> syncRemoteLibrary(Iterable<Song> songs) async {
    final wanted = {
      for (final song in songs)
        if (!song.isLocal && song.filename.startsWith(Song.youtubePrefix))
          song.filename,
    };
    final previous = _syncedRemote;
    if (previous != null &&
        previous.length == wanted.length &&
        previous.containsAll(wanted)) {
      return;
    }
    _syncedRemote = wanted;
    await init();

    final indexed = await _indexRepository.indexedFilenames();
    final stale = [
      for (final filename in indexed)
        if (!wanted.contains(filename) &&
            filename.startsWith(Song.youtubePrefix))
          filename,
    ];
    for (final filename in stale) {
      await _indexRepository.removeSong(filename);
    }
    // Only rows that were not indexed before: adding one track to the library
    // must not re-read the cached lyrics of every other one.
    await _indexRepository.upsertRemoteSongs([
      for (final song in songs)
        if (wanted.contains(song.filename) &&
            (previous == null || !previous.contains(song.filename)))
          song,
    ]);
  }

  /// Updates a single song in the index
  Future<void> updateSong(Song song) async {
    await init();
    await _indexRepository.upsertSong(song);
  }

  /// Removes a song from the index
  Future<void> removeSong(String filename) async {
    await init();
    await _indexRepository.removeSong(filename);
  }

  /// Moves index rows onto new filenames, keeping their indexed content.
  ///
  /// Preferred over removeSong + updateSong for a batch: the row already holds
  /// everything worth indexing, and re-upserting it under a new key would
  /// re-extract lyrics from disk for no reason.
  Future<void> renameFiles(List<({String from, String to})> renames) async {
    await init();
    await _indexRepository.renameFiles(renames);
  }

  /// Clears the search index.
  ///
  /// The streamed-set memo is dropped with it, so the next search re-indexes the
  /// tracks saved to the library instead of trusting a set that no longer has
  /// any rows behind it.
  Future<void> clearIndex() async {
    await init();
    _syncedRemote = null;
    await _indexRepository.clear();
  }

  /// Gets statistics about the search index
  Future<SearchIndexStats> getIndexStats() async {
    await init();
    final stats = await _indexRepository.getStats();
    return SearchIndexStats(
      totalEntries: stats.totalEntries,
      entriesWithLyrics: stats.entriesWithLyrics,
      totalLyricsChars: stats.totalLyricsChars,
      lastUpdated: stats.lastUpdated,
    );
  }

  /// Disposes of transient service resources
  Future<void> dispose() async {
    _initFuture = null;
  }

  /// Explicitly closes the underlying database connection
  Future<void> closeRepository() async {
    await _indexRepository.close();
    _initFuture = null;
  }
}

/// Statistics about the search index
class SearchIndexStats {
  final int totalEntries;
  final int entriesWithLyrics;
  final int totalLyricsChars;
  final DateTime? lastUpdated;

  const SearchIndexStats({
    required this.totalEntries,
    required this.entriesWithLyrics,
    required this.totalLyricsChars,
    this.lastUpdated,
  });

  factory SearchIndexStats.empty() {
    return const SearchIndexStats(
      totalEntries: 0,
      entriesWithLyrics: 0,
      totalLyricsChars: 0,
      lastUpdated: null,
    );
  }
}
