import '../../models/song.dart';
import '../models/search_filter.dart';
import '../models/search_result.dart';
import '../../data/repositories/search_index_repository.dart';

/// Service for performing searches across the music library
///
/// This service coordinates between the search index repository and
/// the song data to provide fast, filtered search results.
class SearchService {
  final SearchIndexRepository _indexRepository;
  Future<void>? _initFuture;

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
  }) async {
    await init();

    if (query.isEmpty) {
      return [];
    }

    final lowerQuery = query.toLowerCase().trim();
    if (lowerQuery.isEmpty) {
      return [];
    }

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
    final results = <SearchResult>[];
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

    // Sort results: title matches first, then artist, then album, then lyrics.
    // Within the same field, exact word matches (e.g. "hot") rank above
    // substring matches (e.g. "shot", "hotlines").
    results.sort((a, b) {
      final priorityA = _getMatchPriority(a);
      final priorityB = _getMatchPriority(b);
      if (priorityA != priorityB) return priorityA.compareTo(priorityB);

      final wordScoreA = _getWordMatchScore(a, lowerQuery);
      final wordScoreB = _getWordMatchScore(b, lowerQuery);
      if (wordScoreA != wordScoreB) return wordScoreA.compareTo(wordScoreB);

      final posA = _getMatchPosition(a, lowerQuery);
      final posB = _getMatchPosition(b, lowerQuery);
      if (posA != posB) return posA.compareTo(posB);

      return a.song.title.toLowerCase().compareTo(b.song.title.toLowerCase());
    });

    // Typo tolerance only tops up thin results, so a clean query never gets
    // noise mixed in and the common case pays nothing for it.
    if (results.length < _fuzzyTopUpBelow &&
        lowerQuery.length >= 4 &&
        (searchTitles || searchArtists || searchAlbums)) {
      final seen = {for (final r in results) r.song.filename};
      results.addAll(_fuzzyMatches(
        lowerQuery,
        allSongs,
        seen,
        titles: searchTitles,
        artists: searchArtists,
        albums: searchAlbums,
      ));
    }

    return results;
  }

  static const int _fuzzyTopUpBelow = 12;

  List<SearchResult> _fuzzyMatches(
    String query,
    List<Song> songs,
    Set<String> exclude, {
    required bool titles,
    required bool artists,
    required bool albums,
  }) {
    final tokens = query.split(RegExp(r'\s+')).where((t) => t.isNotEmpty);
    final scored = <(int, SearchResult)>[];

    for (final song in songs) {
      if (exclude.contains(song.filename)) continue;
      // Field order is also the rank: a title hit beats an artist hit.
      final fields = <(String, SearchFilterType)>[
        if (titles) (song.title, SearchFilterType.songs),
        if (artists) (song.artist, SearchFilterType.artists),
        if (albums) (song.album, SearchFilterType.albums),
      ];
      for (final (text, type) in fields) {
        final cost = _fuzzyFieldCost(tokens, text.toLowerCase());
        if (cost == null) continue;
        scored.add((
          cost * 10 + type.index,
          SearchResult(song: song, matchedFilters: {type}),
        ));
        break;
      }
    }

    scored.sort((a, b) => a.$1 != b.$1
        ? a.$1.compareTo(b.$1)
        : a.$2.song.title.compareTo(b.$2.song.title));
    return [for (final e in scored.take(30)) e.$2];
  }

  /// Total typo cost if every query token matches some word in [text] within
  /// tolerance, otherwise null.
  int? _fuzzyFieldCost(Iterable<String> tokens, String text) {
    if (text.isEmpty) return null;
    final words = text.split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
      ..removeWhere((w) => w.isEmpty);
    var total = 0;
    for (final token in tokens) {
      final maxCost = token.length <= 3 ? 0 : (token.length <= 7 ? 1 : 2);
      int? best;
      for (final word in words) {
        if (word.length < token.length - maxCost) {
          // Too short even as a prefix match.
          continue;
        }
        // Prefix compare so a half-typed, slightly wrong word still matches.
        final head =
            word.length > token.length ? word.substring(0, token.length) : word;
        final d = _editDistance(token, head, maxCost);
        if (d <= maxCost && (best == null || d < best)) best = d;
      }
      if (best == null) return null;
      total += best;
    }
    return total;
  }

  /// Optimal string alignment distance (a swap counts as one edit), bailing
  /// out early once every cell exceeds [limit].
  int _editDistance(String a, String b, int limit) {
    if ((a.length - b.length).abs() > limit) return limit + 1;
    var prev2 = List<int>.filled(b.length + 1, 0);
    var prev = List<int>.generate(b.length + 1, (j) => j);
    for (var i = 1; i <= a.length; i++) {
      final cur = List<int>.filled(b.length + 1, 0)..[0] = i;
      var rowMin = cur[0];
      for (var j = 1; j <= b.length; j++) {
        final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
        var v = prev[j - 1] + cost;
        if (prev[j] + 1 < v) v = prev[j] + 1;
        if (cur[j - 1] + 1 < v) v = cur[j - 1] + 1;
        if (i > 1 &&
            j > 1 &&
            a.codeUnitAt(i - 1) == b.codeUnitAt(j - 2) &&
            a.codeUnitAt(i - 2) == b.codeUnitAt(j - 1) &&
            prev2[j - 2] + 1 < v) {
          v = prev2[j - 2] + 1;
        }
        cur[j] = v;
        if (v < rowMin) rowMin = v;
      }
      if (rowMin > limit) return limit + 1;
      prev2 = prev;
      prev = cur;
    }
    return prev[b.length];
  }

  /// Gets priority for sorting (lower = higher priority)
  int _getMatchPriority(SearchResult result) {
    if (result.matchedTitle) return 0;
    if (result.matchedArtist) return 1;
    if (result.matchedAlbum) return 2;
    if (result.hasLyricsMatch) return 3;
    return 4;
  }

  /// Returns 0 if query appears as whole word, 1 if only as substring
  int _getWordMatchScore(SearchResult result, String lowerQuery) {
    String text;
    if (result.hasLyricsMatch && result.lyricsMatch != null) {
      text = result.lyricsMatch!.fullLine.toLowerCase();
    } else if (result.matchedTitle) {
      text = result.song.title.toLowerCase();
    } else if (result.matchedArtist) {
      text = result.song.artist.toLowerCase();
    } else if (result.matchedAlbum) {
      text = result.song.album.toLowerCase();
    } else {
      return 1;
    }
    if (text.isEmpty || !text.contains(lowerQuery)) return 1;
    final escaped = RegExp.escape(lowerQuery);
    final wordPattern = RegExp('\\b$escaped\\b');
    return wordPattern.hasMatch(text) ? 0 : 1;
  }

  /// Earliest index of query in matched text, or large value if not found
  int _getMatchPosition(SearchResult result, String lowerQuery) {
    String text;
    if (result.hasLyricsMatch && result.lyricsMatch != null) {
      text = result.lyricsMatch!.fullLine.toLowerCase();
    } else if (result.matchedTitle) {
      text = result.song.title.toLowerCase();
    } else if (result.matchedArtist) {
      text = result.song.artist.toLowerCase();
    } else if (result.matchedAlbum) {
      text = result.song.album.toLowerCase();
    } else {
      return 999999;
    }
    final idx = text.indexOf(lowerQuery);
    return idx == -1 ? 999999 : idx;
  }

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

  /// Clears the search index
  Future<void> clearIndex() async {
    await init();
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
